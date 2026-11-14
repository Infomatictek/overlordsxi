using System.Diagnostics;

namespace OverlordsLauncher.Services;

public sealed class GameLaunchService
{
    public Process LaunchAshita(string ashitaDir, string bootConfigFileName = AshitaConfigGenerator.BootConfigFileName)
    {
        var ashitaCliPath = Path.Combine(ashitaDir, "Ashita-cli.exe");
        if (!File.Exists(ashitaCliPath))
        {
            throw new FileNotFoundException("Ashita-cli.exe was not found in the configured Ashita folder.", ashitaCliPath);
        }

        var startInfo = new ProcessStartInfo
        {
            FileName = ashitaCliPath,
            Arguments = bootConfigFileName,
            WorkingDirectory = ashitaDir,
            UseShellExecute = true
        };

        var process = Process.Start(startInfo);
        return process ?? throw new InvalidOperationException("Failed to start Ashita-cli.exe.");
    }
}
