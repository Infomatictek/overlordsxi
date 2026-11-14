using System.Text;
using OverlordsLauncher.Models;
using OverlordsLauncher.Services;
using Xunit;

namespace OverlordsLauncher.Tests;

public sealed class ManifestTests
{
    [Fact]
    public void LoadEmbeddedManifest_ContainsExpectedFilesAndDefaults()
    {
        var service = new ManifestUpdateService();
        var manifest = service.LoadEmbeddedManifest();

        Assert.Equal("OverlordsXI", manifest.ServerName);
        Assert.Equal("Infomatictek", manifest.Repo.Owner);
        Assert.Equal("overlordsxi", manifest.Repo.Name);
        Assert.True(manifest.Files.Count >= 5);
        Assert.Contains(manifest.Files, f =>
            f.Category == "addon" &&
            f.TargetPath == "overlords_talents/overlords_talents.lua" &&
            !string.IsNullOrWhiteSpace(f.Sha256));
        Assert.Contains(manifest.Files, f =>
            f.Category == "dat" &&
            f.TargetPath == "ROM/118/108.DAT" &&
            !string.IsNullOrWhiteSpace(f.Sha256));
    }

    [Fact]
    public void ApplyLocalOverride_UpdatesProvidedFieldsAndPreservesOthers()
    {
        var manifest = new LauncherManifest
        {
            ServerName = "OverlordsXI",
            DefaultHost = "127.0.0.1",
            UseHairpin = false,
            Ports = new ManifestPorts { Lobby = 54231, Auth = 54001, Search = 54002 }
        };

        var localOverride = new LocalServerOverride
        {
            ServerName = " OverlordsXI Live ",
            DefaultHost = " play.overlordsxi.net ",
            UseHairpin = true,
            LobbyPort = 54235
        };

        ManifestUpdateService.ApplyLocalOverride(manifest, localOverride);

        Assert.Equal("OverlordsXI Live", manifest.ServerName);
        Assert.Equal("play.overlordsxi.net", manifest.DefaultHost);
        Assert.True(manifest.UseHairpin);
        Assert.Equal(54235, manifest.Ports.Lobby);
        Assert.Equal(54001, manifest.Ports.Auth);
        Assert.Equal(54002, manifest.Ports.Search);
    }

    [Fact]
    public void ResolveTargetFilePath_RoutesDatAndAddonCategoriesCorrectly()
    {
        var settings = new LauncherSettings
        {
            AshitaPath = Path.Combine("C:", "Games", "Ashita")
        };

        var datEntry = new ManifestFileEntry
        {
            Category = "dat",
            TargetPath = "ROM/118/108.DAT"
        };
        var addonEntry = new ManifestFileEntry
        {
            Category = "addon",
            TargetPath = "overlords_talents/overlords_talents.lua"
        };

        var datDest = ManifestUpdateService.ResolveTargetFilePath(settings, datEntry);
        var addonDest = ManifestUpdateService.ResolveTargetFilePath(settings, addonEntry);

        Assert.Equal(
            Path.Combine("C:", "Games", "Ashita", "polplugins", "DATs", "overlordsxi", "ROM", "118", "108.DAT"),
            datDest);
        Assert.Equal(
            Path.Combine("C:", "Games", "Ashita", "addons", "overlords_talents", "overlords_talents.lua"),
            addonDest);
    }

    [Fact]
    public void FileMatchesHash_And_GetOutdatedFiles_DetectMissingAndModifiedFiles()
    {
        var tempRoot = Path.Combine(Path.GetTempPath(), $"overlords_launcher_test_{Guid.NewGuid():N}");
        Directory.CreateDirectory(tempRoot);

        try
        {
            var settings = new LauncherSettings
            {
                AshitaPath = tempRoot
            };

            var sampleFile = Path.Combine(tempRoot, "addons", "overlords_talents", "overlords_talents.lua");
            Directory.CreateDirectory(Path.GetDirectoryName(sampleFile)!);
            File.WriteAllText(sampleFile, "-- overlords test", Encoding.UTF8);

            var expectedHash = ManifestUpdateService.ComputeSha256(sampleFile);
            Assert.True(ManifestUpdateService.FileMatchesHash(sampleFile, expectedHash));
            Assert.False(ManifestUpdateService.FileMatchesHash(sampleFile, "0000000000000000"));

            var manifest = new LauncherManifest
            {
                Files =
                [
                    new ManifestFileEntry
                    {
                        Category = "addon",
                        TargetPath = "overlords_talents/overlords_talents.lua",
                        Sha256 = expectedHash
                    },
                    new ManifestFileEntry
                    {
                        Category = "dat",
                        TargetPath = "ROM/118/108.DAT",
                        Sha256 = "deadbeef"
                    }
                ]
            };

            var service = new ManifestUpdateService();
            var outdated = service.GetOutdatedFiles(manifest, settings, forceAll: false);
            Assert.Single(outdated);
            Assert.Equal("ROM/118/108.DAT", outdated[0].TargetPath);

            var forced = service.GetOutdatedFiles(manifest, settings, forceAll: true);
            Assert.Equal(2, forced.Count);
        }
        finally
        {
            if (Directory.Exists(tempRoot))
            {
                Directory.Delete(tempRoot, recursive: true);
            }
        }
    }
}
