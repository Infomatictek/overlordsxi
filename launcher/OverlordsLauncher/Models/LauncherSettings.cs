namespace OverlordsLauncher.Models;

public enum WindowModeOption
{
    Borderless = 3,
    Windowed = 1,
    Fullscreen = 0
}

public sealed class LauncherSettings
{
    public bool UseCustomServer { get; set; }
    public string CustomServerHost { get; set; } = "127.0.0.1";
    public bool CustomUseHairpin { get; set; }
    public int CustomLobbyPort { get; set; } = 54231;
    public int CustomSearchPort { get; set; } = 54002;

    public string FfxiPath { get; set; } = string.Empty;
    public string AshitaPath { get; set; } = string.Empty;
    public bool SyncToCustomDatFolder { get; set; }
    public string CustomDatOverlayPath { get; set; } = @"C:\DATs\Overlords";

    public string Username { get; set; } = string.Empty;
    public bool RememberPassword { get; set; }
    public string EncryptedPasswordBase64 { get; set; } = string.Empty;
    public bool AutoLogin { get; set; }

    public WindowModeOption WindowMode { get; set; } = WindowModeOption.Borderless;
    public int WindowWidth { get; set; } = 1920;
    public int WindowHeight { get; set; } = 1080;
    public int BackgroundWidth { get; set; } = 2048;
    public int BackgroundHeight { get; set; } = 2048;
    public int MenuWidth { get; set; } = 1920;
    public int MenuHeight { get; set; } = 1080;
    public int MipMapping { get; set; } = 6;
    public bool BumpMapping { get; set; }
    public bool UncompressedTextures { get; set; } = true;
    public bool UncompressedMaps { get; set; } = true;
    public bool HighQualityFonts { get; set; } = true;
    public bool HardwareMouse { get; set; } = true;
    public bool ShowOpeningMovie { get; set; }
    public bool SoundEnabled { get; set; } = true;
    public bool BackgroundSound { get; set; } = true;
    public int FpsCap { get; set; } = 60;
    public string Language { get; set; } = "US";

    public bool EnablePivotOverlay { get; set; } = true;
    public bool AutoLoadTalentsAddon { get; set; } = true;
    public bool AutoCloseOnLaunch { get; set; }
    public bool AutoCheckUpdatesOnStartup { get; set; } = true;

    public static LauncherSettings CreateDefault(string baseDir)
    {
        return new LauncherSettings
        {
            AshitaPath = Path.Combine(baseDir, "Ashita")
        };
    }
}

public sealed class LocalServerOverride
{
    public string? ServerName { get; set; }
    public string? DefaultHost { get; set; }
    public bool? UseHairpin { get; set; }
    public int? LobbyPort { get; set; }
    public int? AuthPort { get; set; }
    public int? SearchPort { get; set; }
}
