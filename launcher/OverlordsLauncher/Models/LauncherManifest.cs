using System.Text.Json.Serialization;

namespace OverlordsLauncher.Models;

public sealed class LauncherManifest
{
    [JsonPropertyName("schemaVersion")]
    public int SchemaVersion { get; set; } = 1;

    [JsonPropertyName("serverName")]
    public string ServerName { get; set; } = "OverlordsXI";

    [JsonPropertyName("tagline")]
    public string Tagline { get; set; } = string.Empty;

    [JsonPropertyName("defaultHost")]
    public string DefaultHost { get; set; } = "127.0.0.1";

    [JsonPropertyName("useHairpin")]
    public bool UseHairpin { get; set; }

    [JsonPropertyName("ports")]
    public ManifestPorts Ports { get; set; } = new();

    [JsonPropertyName("repo")]
    public ManifestRepo Repo { get; set; } = new();

    [JsonPropertyName("bootstrap")]
    public ManifestBootstrap Bootstrap { get; set; } = new();

    [JsonPropertyName("files")]
    public List<ManifestFileEntry> Files { get; set; } = [];

    [JsonPropertyName("news")]
    public List<ManifestNewsItem> News { get; set; } = [];
}

public sealed class ManifestPorts
{
    [JsonPropertyName("lobby")]
    public int Lobby { get; set; } = 54231;

    [JsonPropertyName("auth")]
    public int Auth { get; set; } = 54001;

    [JsonPropertyName("search")]
    public int Search { get; set; } = 54002;
}

public sealed class ManifestRepo
{
    [JsonPropertyName("owner")]
    public string Owner { get; set; } = "Infomatictek";

    [JsonPropertyName("name")]
    public string Name { get; set; } = "overlordsxi";

    [JsonPropertyName("branch")]
    public string Branch { get; set; } = "main";

    [JsonPropertyName("rawBaseUrl")]
    public string RawBaseUrl { get; set; } = "https://raw.githubusercontent.com/Infomatictek/overlordsxi/main";
}

public sealed class ManifestBootstrap
{
    [JsonPropertyName("ashitaZipUrl")]
    public string AshitaZipUrl { get; set; } = "https://github.com/AshitaXI/Ashita-v4beta/archive/refs/heads/main.zip";

    [JsonPropertyName("xiloaderLatestApiUrl")]
    public string XiloaderLatestApiUrl { get; set; } = "https://api.github.com/repos/LandSandBoat/xiloader/releases/latest";

    [JsonPropertyName("xipivotLatestApiUrl")]
    public string XipivotLatestApiUrl { get; set; } = "https://api.github.com/repos/HealsCodes/XIPivot/releases/latest";
}

public sealed class ManifestFileEntry
{
    [JsonPropertyName("category")]
    public string Category { get; set; } = string.Empty;

    [JsonPropertyName("sourcePath")]
    public string SourcePath { get; set; } = string.Empty;

    [JsonPropertyName("targetPath")]
    public string TargetPath { get; set; } = string.Empty;

    [JsonPropertyName("sha256")]
    public string Sha256 { get; set; } = string.Empty;

    [JsonPropertyName("size")]
    public long Size { get; set; }
}

public sealed class ManifestNewsItem
{
    [JsonPropertyName("date")]
    public string Date { get; set; } = string.Empty;

    [JsonPropertyName("title")]
    public string Title { get; set; } = string.Empty;

    [JsonPropertyName("body")]
    public string Body { get; set; } = string.Empty;
}
