using OverlordsLauncher.Models;
using OverlordsLauncher.Services;
using Xunit;

namespace OverlordsLauncher.Tests;

public sealed class AshitaConfigGeneratorTests
{
    private readonly AshitaConfigGenerator _generator = new();

    [Fact]
    public void BuildXiloaderCommand_IncludesHostAndHairpin_WhenEnabled()
    {
        var cmd = _generator.BuildXiloaderCommand(
            serverHost: " play.overlordsxi.example ",
            useHairpin: true,
            username: "hero",
            password: "secret",
            autoLogin: false,
            language: "US");

        Assert.Equal("--server play.overlordsxi.example --hairpin", cmd);
    }

    [Fact]
    public void BuildXiloaderCommand_IncludesQuotedCredentialsAndLanguage_WhenAutoLoginEnabled()
    {
        var cmd = _generator.BuildXiloaderCommand(
            serverHost: "127.0.0.1",
            useHairpin: false,
            username: "hero name",
            password: "p@ss \"word\"",
            autoLogin: true,
            language: "EU");

        Assert.Equal("--server 127.0.0.1 --lang EU --user \"hero name\" --pass \"p@ss \\\"word\\\"\"", cmd);
    }

    [Fact]
    public void BuildXiloaderCommand_OmitsCredentials_WhenPasswordEmpty()
    {
        var cmd = _generator.BuildXiloaderCommand(
            serverHost: "127.0.0.1",
            useHairpin: false,
            username: "hero",
            password: "",
            autoLogin: true,
            language: "JP");

        Assert.Equal("--server 127.0.0.1 --lang JP", cmd);
    }

    [Fact]
    public void BuildBootIniContent_WritesExpectedSectionsAndWindowMode()
    {
        var settings = new LauncherSettings
        {
            WindowMode = WindowModeOption.Borderless,
            WindowWidth = 2560,
            WindowHeight = 1440,
            BackgroundWidth = 4096,
            BackgroundHeight = 4096,
            MenuWidth = 1920,
            MenuHeight = 1080,
            Language = "US",
            EnablePivotOverlay = true,
            AutoCloseOnLaunch = true
        };

        var ini = _generator.BuildBootIniContent(
            settings,
            serverHost: "play.example.com",
            useHairpin: true,
            password: null,
            xiloaderPath: @"C:\Ashita\bootloader\xiloader.exe");

        Assert.Contains("[ashita.launcher]", ini);
        Assert.Contains("autoclose = 1", ini);
        Assert.Contains("file = C:\\Ashita\\bootloader\\xiloader.exe", ini);
        Assert.Contains("command = --server play.example.com --hairpin", ini);
        Assert.Contains("script = overlordsxi.txt", ini);
        Assert.Contains("pivot = 1", ini);
        Assert.Contains("pivot = overlordsxi", ini);
        Assert.Contains("0001 = 2560", ini);
        Assert.Contains("0002 = 1440", ini);
        Assert.Contains("0003 = 4096", ini);
        Assert.Contains("0034 = 3", ini);
        Assert.Contains("0037 = 1920", ini);
        Assert.Contains("0038 = 1080", ini);
    }

    [Fact]
    public void BuildBootIniContent_OmitsPivotPlugin_WhenDisabled()
    {
        var settings = new LauncherSettings
        {
            EnablePivotOverlay = false,
            WindowMode = WindowModeOption.Fullscreen
        };

        var ini = _generator.BuildBootIniContent(
            settings,
            serverHost: "127.0.0.1",
            useHairpin: false,
            password: null,
            xiloaderPath: "xiloader.exe");

        Assert.DoesNotContain("pivot = 1", ini);
        Assert.DoesNotContain("pivot = overlordsxi", ini);
        Assert.Contains("0034 = 0", ini);
    }

    [Fact]
    public void BuildPivotIniContent_SetsRootPathAndOverlayName()
    {
        var pivotIni = _generator.BuildPivotIniContent(@"C:\Ashita\polplugins\DATs");

        Assert.Contains("[settings]", pivotIni);
        Assert.Contains(@"root_path=C:\Ashita\polplugins\DATs", pivotIni);
        Assert.Contains("[overlays]", pivotIni);
        Assert.Contains("0=overlordsxi", pivotIni);
    }

    [Theory]
    [InlineData(60, "/fps 1")]
    [InlineData(30, "/fps 2")]
    [InlineData(0, "/fps 0")]
    public void MergeBootScriptContent_UpdatesFpsAndPreservesUserLines(int fpsCap, string expectedFpsLine)
    {
        var existing = string.Join(Environment.NewLine,
            "# custom script",
            "/load addons",
            "/addon load custom_addon",
            "/fps 2",
            "/addon load overlords_talents");

        var settings = new LauncherSettings
        {
            AutoLoadTalentsAddon = true,
            FpsCap = fpsCap
        };

        var merged = _generator.MergeBootScriptContent(existing, settings);

        Assert.Contains("/addon load custom_addon", merged);
        Assert.Contains("/addon load fps", merged);
        Assert.Contains(expectedFpsLine, merged);
        Assert.Single(
            merged.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries),
            line => line.Trim().Equals("/addon load overlords_talents", StringComparison.OrdinalIgnoreCase));
        Assert.Single(
            merged.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries),
            line => line.Trim().StartsWith("/fps ", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void MergeBootScriptContent_RemovesTalentsAddon_WhenDisabled()
    {
        var existing = string.Join(Environment.NewLine,
            "/load addons",
            "/addon load overlords_talents",
            "/fps 1");

        var settings = new LauncherSettings
        {
            AutoLoadTalentsAddon = false,
            FpsCap = 60
        };

        var merged = _generator.MergeBootScriptContent(existing, settings);

        Assert.DoesNotContain("overlords_talents", merged);
        Assert.Contains("/fps 1", merged);
    }
}
