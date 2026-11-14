using Microsoft.Win32;
using OverlordsLauncher.Models;

namespace OverlordsLauncher.Services;

public sealed class FfxiInstallDetector
{
    private static readonly (string KeyPath, string Region)[] RegistryInstallKeys =
    [
        (@"SOFTWARE\PlayOnlineUS\InstallFolder", "US"),
        (@"SOFTWARE\PlayOnlineEU\InstallFolder", "EU"),
        (@"SOFTWARE\PlayOnline\InstallFolder", "JP")
    ];

    public InstallDiagnostics Inspect(LauncherSettings settings, LauncherManifest manifest)
    {
        var diag = new InstallDiagnostics();

        var (detectedFfxi, detectedPol, region) = DetectFfxiFromRegistryOrCommonPaths();
        if (!string.IsNullOrWhiteSpace(settings.FfxiPath) && Directory.Exists(settings.FfxiPath))
        {
            diag.FfxiDetected = File.Exists(Path.Combine(settings.FfxiPath, "FFXiMain.dll")) ||
                                Directory.Exists(Path.Combine(settings.FfxiPath, "ROM"));
            diag.DetectedFfxiPath = settings.FfxiPath;
            diag.DetectedPolPath = detectedPol;
            diag.FfxiRegion = region != "Unknown" ? region : settings.Language;
        }
        else if (!string.IsNullOrWhiteSpace(detectedFfxi))
        {
            diag.FfxiDetected = true;
            diag.DetectedFfxiPath = detectedFfxi;
            diag.DetectedPolPath = detectedPol;
            diag.FfxiRegion = region;
        }

        var ashitaDir = settings.AshitaPath;
        diag.AshitaInstalled = !string.IsNullOrWhiteSpace(ashitaDir) &&
                               File.Exists(Path.Combine(ashitaDir, "Ashita-cli.exe"));

        diag.XiloaderPath = ResolveXiloaderPath(ashitaDir);
        diag.XiloaderInstalled = !string.IsNullOrEmpty(diag.XiloaderPath);

        diag.PivotPluginInstalled = !string.IsNullOrWhiteSpace(ashitaDir) &&
                                    File.Exists(Path.Combine(ashitaDir, "polplugins", "pivot.dll"));

        diag.TalentsAddonSynced = !string.IsNullOrWhiteSpace(ashitaDir) &&
                                  File.Exists(Path.Combine(ashitaDir, "addons", "overlords_talents", "overlords_talents.lua"));

        var datFiles = manifest.Files.Where(f => f.Category == "dat").ToList();
        diag.DatOverlaySynced = !string.IsNullOrWhiteSpace(ashitaDir) &&
                                datFiles.Count > 0 &&
                                datFiles.All(f => File.Exists(Path.Combine(
                                    ashitaDir,
                                    "polplugins",
                                    "DATs",
                                    AshitaConfigGenerator.OverlayFolderName,
                                    f.TargetPath.Replace('/', Path.DirectorySeparatorChar))));

        diag.DirectPlayEnabled = CheckDirectPlayPresent();
        diag.VcRedistX86Present = CheckVcRedistX86Present();

        return diag;
    }

    public static string ResolveXiloaderPath(string ashitaDir)
    {
        if (string.IsNullOrWhiteSpace(ashitaDir))
        {
            return string.Empty;
        }

        var candidates = new[]
        {
            Path.Combine(ashitaDir, "bootloader", "xiloader.exe"),
            Path.Combine(ashitaDir, "xiloader.exe"),
            Path.Combine(AppContext.BaseDirectory, "xiloader.exe")
        };

        return candidates.FirstOrDefault(File.Exists) ?? string.Empty;
    }

    private static (string FfxiPath, string PolPath, string Region) DetectFfxiFromRegistryOrCommonPaths()
    {
        foreach (var view in new[] { RegistryView.Registry32, RegistryView.Registry64 })
        {
            foreach (var (keyPath, region) in RegistryInstallKeys)
            {
                try
                {
                    using var baseKey = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, view);
                    using var subKey = baseKey.OpenSubKey(keyPath);
                    if (subKey is null)
                    {
                        continue;
                    }

                    var ffxi = (subKey.GetValue("0001") as string)?.TrimEnd('\\', '/');
                    var pol = (subKey.GetValue("1000") as string)?.TrimEnd('\\', '/');
                    if (!string.IsNullOrWhiteSpace(ffxi) && Directory.Exists(ffxi))
                    {
                        return (ffxi, pol ?? string.Empty, region);
                    }
                }
                catch
                {
                    // Ignore registry access exceptions.
                }
            }
        }

        var commonDirs = new[]
        {
            @"C:\Program Files (x86)\PlayOnline\SquareEnix\FINAL FANTASY XI",
            @"C:\PlayOnline\SquareEnix\FINAL FANTASY XI",
            @"D:\PlayOnline\SquareEnix\FINAL FANTASY XI"
        };

        foreach (var dir in commonDirs)
        {
            if (Directory.Exists(dir))
            {
                return (dir, string.Empty, "US");
            }
        }

        return (string.Empty, string.Empty, "Unknown");
    }

    private static bool CheckDirectPlayPresent()
    {
        try
        {
            var sysWow64 = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "SysWOW64", "dplayx.dll");
            var sys32 = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "dplayx.dll");
            if (File.Exists(sysWow64) || File.Exists(sys32))
            {
                return true;
            }

            using var key = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry32)
                .OpenSubKey(@"SOFTWARE\Microsoft\DirectPlay");
            return key is not null;
        }
        catch
        {
            return false;
        }
    }

    private static bool CheckVcRedistX86Present()
    {
        try
        {
            var sysWow64 = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "SysWOW64", "vcruntime140.dll");
            var sys32 = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "vcruntime140.dll");
            return File.Exists(sysWow64) || File.Exists(sys32);
        }
        catch
        {
            return false;
        }
    }
}
