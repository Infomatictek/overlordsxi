namespace OverlordsLauncher.Models;

public sealed class InstallDiagnostics
{
    public bool FfxiDetected { get; set; }
    public string FfxiRegion { get; set; } = "Unknown";
    public string DetectedFfxiPath { get; set; } = string.Empty;
    public string DetectedPolPath { get; set; } = string.Empty;

    public bool AshitaInstalled { get; set; }
    public bool XiloaderInstalled { get; set; }
    public string XiloaderPath { get; set; } = string.Empty;
    public bool PivotPluginInstalled { get; set; }
    public bool TalentsAddonSynced { get; set; }
    public bool DatOverlaySynced { get; set; }

    public bool DirectPlayEnabled { get; set; }
    public bool VcRedistX86Present { get; set; }
}
