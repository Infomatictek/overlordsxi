using System.IO.Compression;
using System.Net.Http;
using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;
using OverlordsLauncher.Models;

namespace OverlordsLauncher.Services;

public sealed class SyncProgress
{
    public string Message { get; init; } = string.Empty;
    public double Percent { get; init; }
}

public sealed class ManifestUpdateService
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    private readonly HttpClient _http;

    public ManifestUpdateService(HttpClient? httpClient = null)
    {
        _http = httpClient ?? CreateDefaultHttpClient();
    }

    public static HttpClient CreateDefaultHttpClient()
    {
        var client = new HttpClient
        {
            Timeout = TimeSpan.FromSeconds(60)
        };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("OverlordsLauncher/1.0 (+https://github.com/Infomatictek/overlordsxi)");
        return client;
    }

    public LauncherManifest LoadEmbeddedManifest()
    {
        var assembly = Assembly.GetExecutingAssembly();
        var resourceName = assembly.GetManifestResourceNames()
            .FirstOrDefault(n => n.EndsWith("manifest.json", StringComparison.OrdinalIgnoreCase));

        if (resourceName is null)
        {
            return new LauncherManifest();
        }

        using var stream = assembly.GetManifestResourceStream(resourceName);
        if (stream is null)
        {
            return new LauncherManifest();
        }

        return JsonSerializer.Deserialize<LauncherManifest>(stream, JsonOptions) ?? new LauncherManifest();
    }

    public async Task<(LauncherManifest Manifest, bool FromRemote)> FetchManifestAsync(
        LauncherManifest fallback,
        LocalServerOverride? localOverride,
        CancellationToken cancellationToken = default)
    {
        var manifest = fallback;
        var fromRemote = false;

        var rawBase = fallback.Repo.RawBaseUrl.TrimEnd('/');
        if (!string.IsNullOrWhiteSpace(rawBase))
        {
            try
            {
                using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
                cts.CancelAfter(TimeSpan.FromSeconds(10));
                var url = $"{rawBase}/launcher/manifest.json?t={DateTimeOffset.UtcNow.ToUnixTimeSeconds()}";
                var json = await _http.GetStringAsync(url, cts.Token).ConfigureAwait(false);
                var remote = JsonSerializer.Deserialize<LauncherManifest>(json, JsonOptions);
                if (remote is not null && remote.Files.Count > 0)
                {
                    manifest = remote;
                    fromRemote = true;
                }
            }
            catch
            {
                // Fall back cleanly to embedded manifest when offline or unreachable.
            }
        }

        ApplyLocalOverride(manifest, localOverride);
        return (manifest, fromRemote);
    }

    public static void ApplyLocalOverride(LauncherManifest manifest, LocalServerOverride? localOverride)
    {
        if (localOverride is null)
        {
            return;
        }

        if (!string.IsNullOrWhiteSpace(localOverride.ServerName))
        {
            manifest.ServerName = localOverride.ServerName.Trim();
        }

        if (!string.IsNullOrWhiteSpace(localOverride.DefaultHost))
        {
            manifest.DefaultHost = localOverride.DefaultHost.Trim();
        }

        if (localOverride.UseHairpin.HasValue)
        {
            manifest.UseHairpin = localOverride.UseHairpin.Value;
        }

        if (localOverride.LobbyPort is > 0)
        {
            manifest.Ports.Lobby = localOverride.LobbyPort.Value;
        }

        if (localOverride.AuthPort is > 0)
        {
            manifest.Ports.Auth = localOverride.AuthPort.Value;
        }

        if (localOverride.SearchPort is > 0)
        {
            manifest.Ports.Search = localOverride.SearchPort.Value;
        }
    }

    public static string ResolveTargetFilePath(LauncherSettings settings, ManifestFileEntry entry)
    {
        var relative = entry.TargetPath.Replace('/', Path.DirectorySeparatorChar);
        return entry.Category.Equals("dat", StringComparison.OrdinalIgnoreCase)
            ? Path.Combine(settings.AshitaPath, "polplugins", "DATs", AshitaConfigGenerator.OverlayFolderName, relative)
            : Path.Combine(settings.AshitaPath, "addons", relative);
    }

    public List<ManifestFileEntry> GetOutdatedFiles(
        LauncherManifest manifest,
        LauncherSettings settings,
        bool forceAll = false)
    {
        var pending = new List<ManifestFileEntry>();
        foreach (var entry in manifest.Files)
        {
            var dest = ResolveTargetFilePath(settings, entry);
            if (forceAll || !FileMatchesHash(dest, entry.Sha256))
            {
                pending.Add(entry);
                continue;
            }

            if (entry.Category.Equals("dat", StringComparison.OrdinalIgnoreCase) &&
                settings.SyncToCustomDatFolder &&
                !string.IsNullOrWhiteSpace(settings.CustomDatOverlayPath))
            {
                var customDest = Path.Combine(settings.CustomDatOverlayPath, entry.TargetPath.Replace('/', Path.DirectorySeparatorChar));
                if (!FileMatchesHash(customDest, entry.Sha256))
                {
                    pending.Add(entry);
                }
            }
        }

        return pending;
    }

    public async Task<int> SyncOverlordsFilesAsync(
        LauncherManifest manifest,
        LauncherSettings settings,
        bool forceAll,
        IProgress<SyncProgress>? progress = null,
        CancellationToken cancellationToken = default)
    {
        var pending = GetOutdatedFiles(manifest, settings, forceAll);
        if (pending.Count == 0)
        {
            progress?.Report(new SyncProgress { Message = "All OverlordsXI client files are up to date.", Percent = 100 });
            return 0;
        }

        var rawBase = manifest.Repo.RawBaseUrl.TrimEnd('/');
        var completed = 0;

        foreach (var entry in pending)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var pct = (double)completed / pending.Count * 100.0;
            progress?.Report(new SyncProgress
            {
                Message = $"Downloading {entry.TargetPath} ({completed + 1}/{pending.Count})...",
                Percent = pct
            });

            var destPath = ResolveTargetFilePath(settings, entry);
            var destDir = Path.GetDirectoryName(destPath)!;
            Directory.CreateDirectory(destDir);

            var url = $"{rawBase}/{entry.SourcePath.TrimStart('/')}";
            var tempPath = destPath + ".download";

            await DownloadFileAsync(url, tempPath, cancellationToken).ConfigureAwait(false);

            if (!string.IsNullOrWhiteSpace(entry.Sha256))
            {
                var actualHash = ComputeSha256(tempPath);
                if (!actualHash.Equals(entry.Sha256, StringComparison.OrdinalIgnoreCase))
                {
                    File.Delete(tempPath);
                    throw new InvalidDataException(
                        $"Checksum mismatch for {entry.TargetPath}. Expected {entry.Sha256}, got {actualHash}.");
                }
            }

            File.Move(tempPath, destPath, overwrite: true);

            if (entry.Category.Equals("dat", StringComparison.OrdinalIgnoreCase) &&
                settings.SyncToCustomDatFolder &&
                !string.IsNullOrWhiteSpace(settings.CustomDatOverlayPath))
            {
                var customDest = Path.Combine(settings.CustomDatOverlayPath, entry.TargetPath.Replace('/', Path.DirectorySeparatorChar));
                Directory.CreateDirectory(Path.GetDirectoryName(customDest)!);
                File.Copy(destPath, customDest, overwrite: true);
            }

            completed++;
        }

        progress?.Report(new SyncProgress
        {
            Message = $"Synced {completed} OverlordsXI file(s).",
            Percent = 100
        });

        return completed;
    }

    public async Task EnsureAshitaAndToolsAsync(
        LauncherManifest manifest,
        LauncherSettings settings,
        IProgress<SyncProgress>? progress = null,
        CancellationToken cancellationToken = default)
    {
        var ashitaDir = settings.AshitaPath;
        Directory.CreateDirectory(ashitaDir);

        if (!File.Exists(Path.Combine(ashitaDir, "Ashita-cli.exe")))
        {
            progress?.Report(new SyncProgress { Message = "Downloading Ashita v4...", Percent = 10 });
            await InstallAshitaAsync(manifest.Bootstrap.AshitaZipUrl, ashitaDir, cancellationToken).ConfigureAwait(false);
        }

        if (string.IsNullOrEmpty(FfxiInstallDetector.ResolveXiloaderPath(ashitaDir)))
        {
            progress?.Report(new SyncProgress { Message = "Downloading latest xiloader.exe...", Percent = 45 });
            await InstallLatestXiloaderAsync(manifest.Bootstrap.XiloaderLatestApiUrl, ashitaDir, cancellationToken).ConfigureAwait(false);
        }

        if (settings.EnablePivotOverlay && !File.Exists(Path.Combine(ashitaDir, "polplugins", "pivot.dll")))
        {
            progress?.Report(new SyncProgress { Message = "Downloading XIPivot plugin for Ashita v4...", Percent = 75 });
            await InstallLatestXipivotAsync(manifest.Bootstrap.XipivotLatestApiUrl, ashitaDir, cancellationToken).ConfigureAwait(false);
        }

        progress?.Report(new SyncProgress { Message = "Ashita v4 prerequisites verified.", Percent = 100 });
    }

    private async Task InstallAshitaAsync(string zipUrl, string ashitaDir, CancellationToken cancellationToken)
    {
        var tempZip = Path.Combine(Path.GetTempPath(), $"overlords_ashita_{Guid.NewGuid():N}.zip");
        try
        {
            await DownloadFileAsync(zipUrl, tempZip, cancellationToken).ConfigureAwait(false);

            using var archive = ZipFile.OpenRead(tempZip);
            foreach (var entry in archive.Entries)
            {
                if (string.IsNullOrEmpty(entry.Name))
                {
                    continue;
                }

                // Strip leading repository folder name (e.g. Ashita-v4beta-main/)
                var parts = entry.FullName.Split(['/', '\\'], 2);
                var relPath = parts.Length == 2 ? parts[1] : parts[0];
                if (string.IsNullOrWhiteSpace(relPath))
                {
                    continue;
                }

                var dest = Path.GetFullPath(Path.Combine(ashitaDir, relPath.Replace('/', Path.DirectorySeparatorChar)));
                var rootFull = Path.GetFullPath(ashitaDir);
                if (!dest.StartsWith(rootFull, StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                Directory.CreateDirectory(Path.GetDirectoryName(dest)!);
                entry.ExtractToFile(dest, overwrite: true);
            }
        }
        finally
        {
            TryDeleteFile(tempZip);
        }
    }

    private async Task InstallLatestXiloaderAsync(string latestApiUrl, string ashitaDir, CancellationToken cancellationToken)
    {
        var releaseJson = await _http.GetStringAsync(latestApiUrl, cancellationToken).ConfigureAwait(false);
        using var doc = JsonDocument.Parse(releaseJson);
        if (!doc.RootElement.TryGetProperty("assets", out var assets))
        {
            throw new InvalidOperationException("No release assets found for xiloader.");
        }

        string? exeUrl = null;
        string? zipUrl = null;

        foreach (var asset in assets.EnumerateArray())
        {
            var name = asset.GetProperty("name").GetString() ?? string.Empty;
            var url = asset.GetProperty("browser_download_url").GetString();
            if (string.IsNullOrWhiteSpace(url))
            {
                continue;
            }

            if (name.Equals("xiloader.exe", StringComparison.OrdinalIgnoreCase))
            {
                exeUrl = url;
                break;
            }

            if (name.Contains("xiloader", StringComparison.OrdinalIgnoreCase) &&
                name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
            {
                zipUrl = url;
            }
        }

        var bootloaderDir = Path.Combine(ashitaDir, "bootloader");
        Directory.CreateDirectory(bootloaderDir);
        var targetExe = Path.Combine(bootloaderDir, "xiloader.exe");

        if (exeUrl is not null)
        {
            await DownloadFileAsync(exeUrl, targetExe, cancellationToken).ConfigureAwait(false);
            return;
        }

        if (zipUrl is not null)
        {
            var tempZip = Path.Combine(Path.GetTempPath(), $"overlords_xiloader_{Guid.NewGuid():N}.zip");
            try
            {
                await DownloadFileAsync(zipUrl, tempZip, cancellationToken).ConfigureAwait(false);
                using var archive = ZipFile.OpenRead(tempZip);
                var exeEntry = archive.Entries.FirstOrDefault(e =>
                    e.Name.Equals("xiloader.exe", StringComparison.OrdinalIgnoreCase));
                if (exeEntry is null)
                {
                    throw new InvalidOperationException("xiloader.exe was not found inside release archive.");
                }

                exeEntry.ExtractToFile(targetExe, overwrite: true);
                return;
            }
            finally
            {
                TryDeleteFile(tempZip);
            }
        }

        throw new InvalidOperationException("Could not find xiloader.exe in latest LandSandBoat/xiloader release.");
    }

    private async Task InstallLatestXipivotAsync(string latestApiUrl, string ashitaDir, CancellationToken cancellationToken)
    {
        var releaseJson = await _http.GetStringAsync(latestApiUrl, cancellationToken).ConfigureAwait(false);
        using var doc = JsonDocument.Parse(releaseJson);
        if (!doc.RootElement.TryGetProperty("assets", out var assets))
        {
            throw new InvalidOperationException("No release assets found for XIPivot.");
        }

        string? ashita4ZipUrl = null;
        string? fallbackZipUrl = null;
        foreach (var asset in assets.EnumerateArray())
        {
            var name = asset.GetProperty("name").GetString() ?? string.Empty;
            var url = asset.GetProperty("browser_download_url").GetString();
            if (string.IsNullOrWhiteSpace(url) || !name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            fallbackZipUrl ??= url;

            if (name.Contains("Ashita_v4", StringComparison.OrdinalIgnoreCase) ||
                name.Contains("Ashita4", StringComparison.OrdinalIgnoreCase) ||
                name.Contains("v4", StringComparison.OrdinalIgnoreCase))
            {
                ashita4ZipUrl = url;
                break;
            }
        }

        var downloadUrl = ashita4ZipUrl ?? fallbackZipUrl;
        if (downloadUrl is null)
        {
            throw new InvalidOperationException("Could not find Ashita v4 archive in latest XIPivot release.");
        }

        var tempZip = Path.Combine(Path.GetTempPath(), $"overlords_xipivot_{Guid.NewGuid():N}.zip");
        try
        {
            await DownloadFileAsync(downloadUrl, tempZip, cancellationToken).ConfigureAwait(false);
            using var archive = ZipFile.OpenRead(tempZip);
            var polPluginsDir = Path.Combine(ashitaDir, "polplugins");
            Directory.CreateDirectory(polPluginsDir);

            var pivotEntries = archive.Entries
                .Where(e => !string.IsNullOrEmpty(e.Name) &&
                            e.Name.Equals("pivot.dll", StringComparison.OrdinalIgnoreCase))
                .ToList();

            var chosen = pivotEntries.FirstOrDefault(e =>
                             e.FullName.Contains("v4", StringComparison.OrdinalIgnoreCase) ||
                             e.FullName.Contains("polplugins", StringComparison.OrdinalIgnoreCase))
                         ?? pivotEntries.FirstOrDefault();

            if (chosen is null)
            {
                throw new InvalidOperationException("pivot.dll was not found inside XIPivot archive.");
            }

            chosen.ExtractToFile(Path.Combine(polPluginsDir, "pivot.dll"), overwrite: true);
        }
        finally
        {
            TryDeleteFile(tempZip);
        }
    }

    private async Task DownloadFileAsync(string url, string destinationPath, CancellationToken cancellationToken)
    {
        using var response = await _http.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, cancellationToken).ConfigureAwait(false);
        response.EnsureSuccessStatusCode();

        await using var src = await response.Content.ReadAsStreamAsync(cancellationToken).ConfigureAwait(false);
        await using var dst = new FileStream(destinationPath, FileMode.Create, FileAccess.Write, FileShare.None, 81920, useAsync: true);
        await src.CopyToAsync(dst, cancellationToken).ConfigureAwait(false);
    }

    public static bool FileMatchesHash(string filePath, string expectedSha256)
    {
        if (!File.Exists(filePath))
        {
            return false;
        }

        if (string.IsNullOrWhiteSpace(expectedSha256))
        {
            return true;
        }

        return ComputeSha256(filePath).Equals(expectedSha256, StringComparison.OrdinalIgnoreCase);
    }

    public static string ComputeSha256(string filePath)
    {
        using var stream = File.OpenRead(filePath);
        var hash = SHA256.HashData(stream);
        return Convert.ToHexString(hash).ToLowerInvariant();
    }

    private static void TryDeleteFile(string path)
    {
        try
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
        catch
        {
            // Ignore cleanup errors.
        }
    }
}
