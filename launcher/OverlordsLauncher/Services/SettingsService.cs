using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using OverlordsLauncher.Models;

namespace OverlordsLauncher.Services;

public sealed class SettingsService
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNameCaseInsensitive = true
    };

    private readonly string _appDataDir;
    private readonly string _settingsPath;
    private readonly string _launcherBaseDir;

    public SettingsService(string? launcherBaseDir = null, string? appDataOverride = null)
    {
        _launcherBaseDir = launcherBaseDir ?? AppContext.BaseDirectory;
        _appDataDir = appDataOverride ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "OverlordsXI");
        _settingsPath = Path.Combine(_appDataDir, "settings.json");
    }

    public string SettingsPath => _settingsPath;

    public LauncherSettings Load()
    {
        try
        {
            if (File.Exists(_settingsPath))
            {
                var json = File.ReadAllText(_settingsPath, Encoding.UTF8);
                var loaded = JsonSerializer.Deserialize<LauncherSettings>(json, JsonOptions);
                if (loaded is not null)
                {
                    if (string.IsNullOrWhiteSpace(loaded.AshitaPath))
                    {
                        loaded.AshitaPath = Path.Combine(_launcherBaseDir, "Ashita");
                    }

                    return loaded;
                }
            }
        }
        catch
        {
            // Fall back to defaults if user settings are corrupt.
        }

        return LauncherSettings.CreateDefault(_launcherBaseDir);
    }

    public void Save(LauncherSettings settings, string? plainPassword)
    {
        Directory.CreateDirectory(_appDataDir);

        if (settings.RememberPassword && !string.IsNullOrEmpty(plainPassword))
        {
            settings.EncryptedPasswordBase64 = ProtectPassword(plainPassword);
        }
        else if (!settings.RememberPassword)
        {
            settings.EncryptedPasswordBase64 = string.Empty;
        }

        var json = JsonSerializer.Serialize(settings, JsonOptions);
        File.WriteAllText(_settingsPath, json, Encoding.UTF8);
    }

    public string UnprotectPassword(LauncherSettings settings)
    {
        if (!settings.RememberPassword || string.IsNullOrWhiteSpace(settings.EncryptedPasswordBase64))
        {
            return string.Empty;
        }

        try
        {
            var protectedBytes = Convert.FromBase64String(settings.EncryptedPasswordBase64);
            var rawBytes = ProtectedData.Unprotect(protectedBytes, null, DataProtectionScope.CurrentUser);
            return Encoding.UTF8.GetString(rawBytes);
        }
        catch
        {
            return string.Empty;
        }
    }

    public LocalServerOverride? LoadLocalServerOverride()
    {
        var overridePath = Path.Combine(_launcherBaseDir, "overlords-server.json");
        if (!File.Exists(overridePath))
        {
            return null;
        }

        try
        {
            var json = File.ReadAllText(overridePath, Encoding.UTF8);
            return JsonSerializer.Deserialize<LocalServerOverride>(json, JsonOptions);
        }
        catch
        {
            return null;
        }
    }

    private static string ProtectPassword(string plainPassword)
    {
        var rawBytes = Encoding.UTF8.GetBytes(plainPassword);
        var protectedBytes = ProtectedData.Protect(rawBytes, null, DataProtectionScope.CurrentUser);
        return Convert.ToBase64String(protectedBytes);
    }
}
