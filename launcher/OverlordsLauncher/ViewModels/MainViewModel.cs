using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Windows;
using System.Windows.Input;
using Microsoft.Win32;
using OverlordsLauncher.Models;
using OverlordsLauncher.Services;

namespace OverlordsLauncher.ViewModels;

public sealed class MainViewModel : INotifyPropertyChanged
{
    private readonly SettingsService _settingsService;
    private readonly ManifestUpdateService _manifestService;
    private readonly FfxiInstallDetector _detector;
    private readonly AshitaConfigGenerator _configGenerator;
    private readonly ServerStatusService _statusService;
    private readonly GameLaunchService _launchService;

    private LauncherSettings _settings;
    private LauncherManifest _manifest;
    private InstallDiagnostics _diagnostics = new();
    private ServerStatus _serverStatus = new();

    private string _selectedTab = "Play";
    private bool _isBusy;
    private string _statusMessage = "Ready";
    private double _progressPercent;
    private int _pendingUpdatesCount;
    private string _plainPassword = string.Empty;

    public MainViewModel()
    {
        _settingsService = new SettingsService();
        _manifestService = new ManifestUpdateService();
        _detector = new FfxiInstallDetector();
        _configGenerator = new AshitaConfigGenerator();
        _statusService = new ServerStatusService();
        _launchService = new GameLaunchService();

        _manifest = _manifestService.LoadEmbeddedManifest();
        ManifestUpdateService.ApplyLocalOverride(_manifest, _settingsService.LoadLocalServerOverride());

        _settings = _settingsService.Load();
        _plainPassword = _settingsService.UnprotectPassword(_settings);

        NewsItems = new ObservableCollection<ManifestNewsItem>(_manifest.News);
        ActivityLog = new ObservableCollection<string>();

        SelectTabCommand = new RelayCommand(p => SelectedTab = p?.ToString() ?? "Play");
        PlayCommand = new AsyncRelayCommand(PlayAsync, () => !IsBusy);
        CheckUpdatesCommand = new AsyncRelayCommand(() => SyncUpdatesAsync(forceAll: false), () => !IsBusy);
        RepairFilesCommand = new AsyncRelayCommand(() => SyncUpdatesAsync(forceAll: true), () => !IsBusy);
        InstallPrerequisitesCommand = new AsyncRelayCommand(InstallPrerequisitesAsync, () => !IsBusy);
        RefreshStatusCommand = new AsyncRelayCommand(RefreshServerStatusAsync);
        RefreshDiagnosticsCommand = new RelayCommand(RefreshDiagnostics);
        SaveSettingsCommand = new RelayCommand(SaveCurrentSettings);

        BrowseFfxiCommand = new RelayCommand(BrowseFfxiFolder);
        BrowseAshitaCommand = new RelayCommand(BrowseAshitaFolder);
        BrowseCustomDatCommand = new RelayCommand(BrowseCustomDatFolder);
        OpenAshitaFolderCommand = new RelayCommand(OpenAshitaFolder);
        ExportServerOverrideCommand = new RelayCommand(ExportShareableServerJson);
        ApplyResolutionPresetCommand = new RelayCommand(ApplyResolutionPreset);
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public ObservableCollection<ManifestNewsItem> NewsItems { get; }
    public ObservableCollection<string> ActivityLog { get; }

    public ICommand SelectTabCommand { get; }
    public ICommand PlayCommand { get; }
    public ICommand CheckUpdatesCommand { get; }
    public ICommand RepairFilesCommand { get; }
    public ICommand InstallPrerequisitesCommand { get; }
    public ICommand RefreshStatusCommand { get; }
    public ICommand RefreshDiagnosticsCommand { get; }
    public ICommand SaveSettingsCommand { get; }
    public ICommand BrowseFfxiCommand { get; }
    public ICommand BrowseAshitaCommand { get; }
    public ICommand BrowseCustomDatCommand { get; }
    public ICommand OpenAshitaFolderCommand { get; }
    public ICommand ExportServerOverrideCommand { get; }
    public ICommand ApplyResolutionPresetCommand { get; }

    public string SelectedTab
    {
        get => _selectedTab;
        set
        {
            if (SetField(ref _selectedTab, value))
            {
                OnPropertyChanged(nameof(IsPlayTab));
                OnPropertyChanged(nameof(IsSettingsTab));
                OnPropertyChanged(nameof(IsSetupTab));
                OnPropertyChanged(nameof(IsGuideTab));
            }
        }
    }

    public bool IsPlayTab => SelectedTab == "Play";
    public bool IsSettingsTab => SelectedTab == "Settings";
    public bool IsSetupTab => SelectedTab == "Setup";
    public bool IsGuideTab => SelectedTab == "Guide";

    public string ServerName => _manifest.ServerName;
    public string Tagline => _manifest.Tagline;

    public string EffectiveHost => _settings.UseCustomServer && !string.IsNullOrWhiteSpace(_settings.CustomServerHost)
        ? _settings.CustomServerHost.Trim()
        : _manifest.DefaultHost;

    public bool EffectiveUseHairpin => _settings.UseCustomServer ? _settings.CustomUseHairpin : _manifest.UseHairpin;
    public int EffectiveLobbyPort => _settings.UseCustomServer ? _settings.CustomLobbyPort : _manifest.Ports.Lobby;
    public int EffectiveSearchPort => _settings.UseCustomServer ? _settings.CustomSearchPort : _manifest.Ports.Search;

    public bool IsBusy
    {
        get => _isBusy;
        set
        {
            if (SetField(ref _isBusy, value))
            {
                OnPropertyChanged(nameof(PlayButtonText));
                RelayCommand.RaiseCanExecuteChanged();
            }
        }
    }

    public string PlayButtonText => IsBusy
        ? "PREPARING..."
        : PendingUpdatesCount > 0
            ? $"UPDATE & PLAY ({PendingUpdatesCount})"
            : "PLAY OVERLORDSXI";

    public string StatusMessage
    {
        get => _statusMessage;
        set => SetField(ref _statusMessage, value);
    }

    public double ProgressPercent
    {
        get => _progressPercent;
        set => SetField(ref _progressPercent, value);
    }

    public int PendingUpdatesCount
    {
        get => _pendingUpdatesCount;
        set
        {
            if (SetField(ref _pendingUpdatesCount, value))
            {
                OnPropertyChanged(nameof(PlayButtonText));
                OnPropertyChanged(nameof(UpdateBadgeText));
            }
        }
    }

    public string UpdateBadgeText => PendingUpdatesCount == 0
        ? "Client files up to date"
        : $"{PendingUpdatesCount} file update(s) ready";

    public ServerStatus ServerStatus
    {
        get => _serverStatus;
        private set => SetField(ref _serverStatus, value);
    }

    public InstallDiagnostics Diagnostics
    {
        get => _diagnostics;
        private set => SetField(ref _diagnostics, value);
    }

    public string PlainPassword
    {
        get => _plainPassword;
        set => SetField(ref _plainPassword, value);
    }

    // Settings Pass-Through Properties
    public bool UseCustomServer
    {
        get => _settings.UseCustomServer;
        set
        {
            if (_settings.UseCustomServer != value)
            {
                _settings.UseCustomServer = value;
                OnPropertyChanged();
                NotifyEffectiveServerChanged();
            }
        }
    }

    public string CustomServerHost
    {
        get => _settings.CustomServerHost;
        set
        {
            if (_settings.CustomServerHost != value)
            {
                _settings.CustomServerHost = value;
                OnPropertyChanged();
                NotifyEffectiveServerChanged();
            }
        }
    }

    public bool CustomUseHairpin
    {
        get => _settings.CustomUseHairpin;
        set
        {
            if (_settings.CustomUseHairpin != value)
            {
                _settings.CustomUseHairpin = value;
                OnPropertyChanged();
                NotifyEffectiveServerChanged();
            }
        }
    }

    public int CustomLobbyPort
    {
        get => _settings.CustomLobbyPort;
        set
        {
            if (_settings.CustomLobbyPort != value)
            {
                _settings.CustomLobbyPort = value;
                OnPropertyChanged();
                NotifyEffectiveServerChanged();
            }
        }
    }

    public int CustomSearchPort
    {
        get => _settings.CustomSearchPort;
        set
        {
            if (_settings.CustomSearchPort != value)
            {
                _settings.CustomSearchPort = value;
                OnPropertyChanged();
                NotifyEffectiveServerChanged();
            }
        }
    }

    public string FfxiPath
    {
        get => _settings.FfxiPath;
        set
        {
            if (_settings.FfxiPath != value)
            {
                _settings.FfxiPath = value;
                OnPropertyChanged();
            }
        }
    }

    public string AshitaPath
    {
        get => _settings.AshitaPath;
        set
        {
            if (_settings.AshitaPath != value)
            {
                _settings.AshitaPath = value;
                OnPropertyChanged();
            }
        }
    }

    public bool SyncToCustomDatFolder
    {
        get => _settings.SyncToCustomDatFolder;
        set
        {
            if (_settings.SyncToCustomDatFolder != value)
            {
                _settings.SyncToCustomDatFolder = value;
                OnPropertyChanged();
            }
        }
    }

    public string CustomDatOverlayPath
    {
        get => _settings.CustomDatOverlayPath;
        set
        {
            if (_settings.CustomDatOverlayPath != value)
            {
                _settings.CustomDatOverlayPath = value;
                OnPropertyChanged();
            }
        }
    }

    public string Username
    {
        get => _settings.Username;
        set
        {
            if (_settings.Username != value)
            {
                _settings.Username = value;
                OnPropertyChanged();
            }
        }
    }

    public bool RememberPassword
    {
        get => _settings.RememberPassword;
        set
        {
            if (_settings.RememberPassword != value)
            {
                _settings.RememberPassword = value;
                OnPropertyChanged();
            }
        }
    }

    public bool AutoLogin
    {
        get => _settings.AutoLogin;
        set
        {
            if (_settings.AutoLogin != value)
            {
                _settings.AutoLogin = value;
                OnPropertyChanged();
            }
        }
    }

    public IReadOnlyList<WindowModeOption> WindowModes { get; } =
    [
        WindowModeOption.Borderless,
        WindowModeOption.Windowed,
        WindowModeOption.Fullscreen
    ];

    public WindowModeOption SelectedWindowMode
    {
        get => _settings.WindowMode;
        set
        {
            if (_settings.WindowMode != value)
            {
                _settings.WindowMode = value;
                OnPropertyChanged();
            }
        }
    }

    public int WindowWidth
    {
        get => _settings.WindowWidth;
        set { if (_settings.WindowWidth != value) { _settings.WindowWidth = value; OnPropertyChanged(); } }
    }

    public int WindowHeight
    {
        get => _settings.WindowHeight;
        set { if (_settings.WindowHeight != value) { _settings.WindowHeight = value; OnPropertyChanged(); } }
    }

    public int BackgroundWidth
    {
        get => _settings.BackgroundWidth;
        set { if (_settings.BackgroundWidth != value) { _settings.BackgroundWidth = value; OnPropertyChanged(); } }
    }

    public int BackgroundHeight
    {
        get => _settings.BackgroundHeight;
        set { if (_settings.BackgroundHeight != value) { _settings.BackgroundHeight = value; OnPropertyChanged(); } }
    }

    public int MenuWidth
    {
        get => _settings.MenuWidth;
        set { if (_settings.MenuWidth != value) { _settings.MenuWidth = value; OnPropertyChanged(); } }
    }

    public int MenuHeight
    {
        get => _settings.MenuHeight;
        set { if (_settings.MenuHeight != value) { _settings.MenuHeight = value; OnPropertyChanged(); } }
    }

    public int MipMapping
    {
        get => _settings.MipMapping;
        set { if (_settings.MipMapping != value) { _settings.MipMapping = value; OnPropertyChanged(); } }
    }

    public bool BumpMapping
    {
        get => _settings.BumpMapping;
        set { if (_settings.BumpMapping != value) { _settings.BumpMapping = value; OnPropertyChanged(); } }
    }

    public bool UncompressedTextures
    {
        get => _settings.UncompressedTextures;
        set { if (_settings.UncompressedTextures != value) { _settings.UncompressedTextures = value; OnPropertyChanged(); } }
    }

    public bool UncompressedMaps
    {
        get => _settings.UncompressedMaps;
        set { if (_settings.UncompressedMaps != value) { _settings.UncompressedMaps = value; OnPropertyChanged(); } }
    }

    public bool HighQualityFonts
    {
        get => _settings.HighQualityFonts;
        set { if (_settings.HighQualityFonts != value) { _settings.HighQualityFonts = value; OnPropertyChanged(); } }
    }

    public bool HardwareMouse
    {
        get => _settings.HardwareMouse;
        set { if (_settings.HardwareMouse != value) { _settings.HardwareMouse = value; OnPropertyChanged(); } }
    }

    public bool ShowOpeningMovie
    {
        get => _settings.ShowOpeningMovie;
        set { if (_settings.ShowOpeningMovie != value) { _settings.ShowOpeningMovie = value; OnPropertyChanged(); } }
    }

    public bool SoundEnabled
    {
        get => _settings.SoundEnabled;
        set { if (_settings.SoundEnabled != value) { _settings.SoundEnabled = value; OnPropertyChanged(); } }
    }

    public bool BackgroundSound
    {
        get => _settings.BackgroundSound;
        set { if (_settings.BackgroundSound != value) { _settings.BackgroundSound = value; OnPropertyChanged(); } }
    }

    public IReadOnlyList<int> FpsCapOptions { get; } = [60, 30, 0];

    public int SelectedFpsCap
    {
        get => _settings.FpsCap;
        set { if (_settings.FpsCap != value) { _settings.FpsCap = value; OnPropertyChanged(); } }
    }

    public IReadOnlyList<string> LanguageOptions { get; } = ["US", "EU", "JP"];

    public string SelectedLanguage
    {
        get => _settings.Language;
        set { if (_settings.Language != value) { _settings.Language = value; OnPropertyChanged(); } }
    }

    public bool EnablePivotOverlay
    {
        get => _settings.EnablePivotOverlay;
        set { if (_settings.EnablePivotOverlay != value) { _settings.EnablePivotOverlay = value; OnPropertyChanged(); } }
    }

    public bool AutoLoadTalentsAddon
    {
        get => _settings.AutoLoadTalentsAddon;
        set { if (_settings.AutoLoadTalentsAddon != value) { _settings.AutoLoadTalentsAddon = value; OnPropertyChanged(); } }
    }

    public bool AutoCloseOnLaunch
    {
        get => _settings.AutoCloseOnLaunch;
        set { if (_settings.AutoCloseOnLaunch != value) { _settings.AutoCloseOnLaunch = value; OnPropertyChanged(); } }
    }

    public bool AutoCheckUpdatesOnStartup
    {
        get => _settings.AutoCheckUpdatesOnStartup;
        set { if (_settings.AutoCheckUpdatesOnStartup != value) { _settings.AutoCheckUpdatesOnStartup = value; OnPropertyChanged(); } }
    }

    public async Task InitializeAsync()
    {
        RefreshDiagnostics();
        if (string.IsNullOrWhiteSpace(_settings.FfxiPath) && !string.IsNullOrWhiteSpace(Diagnostics.DetectedFfxiPath))
        {
            FfxiPath = Diagnostics.DetectedFfxiPath;
            if (Diagnostics.FfxiRegion is "US" or "EU" or "JP")
            {
                SelectedLanguage = Diagnostics.FfxiRegion;
            }
        }

        Log($"Launcher initialized. Ashita path: {AshitaPath}");
        await RefreshServerStatusAsync();

        if (_settings.AutoCheckUpdatesOnStartup)
        {
            await CheckUpdatesOnlyAsync();
        }
    }

    private async Task CheckUpdatesOnlyAsync()
    {
        try
        {
            StatusMessage = "Checking OverlordsXI manifest...";
            var embedded = _manifestService.LoadEmbeddedManifest();
            var (manifest, fromRemote) = await _manifestService.FetchManifestAsync(
                embedded,
                _settingsService.LoadLocalServerOverride());

            _manifest = manifest;
            OnPropertyChanged(nameof(ServerName));
            OnPropertyChanged(nameof(Tagline));
            NotifyEffectiveServerChanged();

            NewsItems.Clear();
            foreach (var item in _manifest.News)
            {
                NewsItems.Add(item);
            }

            var pending = _manifestService.GetOutdatedFiles(_manifest, _settings);
            PendingUpdatesCount = pending.Count;
            RefreshDiagnostics();

            StatusMessage = fromRemote
                ? (pending.Count == 0 ? "All OverlordsXI client files are up to date." : $"{pending.Count} update(s) available.")
                : "Using bundled manifest (offline or GitHub unreachable).";
            Log(StatusMessage);
        }
        catch (Exception ex)
        {
            StatusMessage = $"Update check failed: {ex.Message}";
            Log(StatusMessage);
        }
    }

    private async Task SyncUpdatesAsync(bool forceAll)
    {
        IsBusy = true;
        ProgressPercent = 0;
        try
        {
            var embedded = _manifestService.LoadEmbeddedManifest();
            var (manifest, _) = await _manifestService.FetchManifestAsync(
                embedded,
                _settingsService.LoadLocalServerOverride());
            _manifest = manifest;

            var progress = new Progress<SyncProgress>(p =>
            {
                StatusMessage = p.Message;
                ProgressPercent = p.Percent;
            });

            var count = await _manifestService.SyncOverlordsFilesAsync(_manifest, _settings, forceAll, progress);
            PendingUpdatesCount = _manifestService.GetOutdatedFiles(_manifest, _settings).Count;
            RefreshDiagnostics();

            Log(count > 0 ? $"Updated {count} OverlordsXI client file(s)." : "No file updates required.");
        }
        catch (Exception ex)
        {
            StatusMessage = $"Sync error: {ex.Message}";
            Log(StatusMessage);
            MessageBox.Show(ex.Message, "OverlordsXI Sync Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            IsBusy = false;
        }
    }

    private async Task InstallPrerequisitesAsync()
    {
        IsBusy = true;
        ProgressPercent = 0;
        try
        {
            var progress = new Progress<SyncProgress>(p =>
            {
                StatusMessage = p.Message;
                ProgressPercent = p.Percent;
            });

            await _manifestService.EnsureAshitaAndToolsAsync(_manifest, _settings, progress);
            await _manifestService.SyncOverlordsFilesAsync(_manifest, _settings, forceAll: false, progress);
            PendingUpdatesCount = _manifestService.GetOutdatedFiles(_manifest, _settings).Count;
            RefreshDiagnostics();
            Log("Ashita v4, xiloader, XIPivot, and OverlordsXI files are ready.");
        }
        catch (Exception ex)
        {
            StatusMessage = $"Setup error: {ex.Message}";
            Log(StatusMessage);
            MessageBox.Show(ex.Message, "OverlordsXI Setup Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            IsBusy = false;
        }
    }

    private async Task PlayAsync()
    {
        if (_settings.AutoLogin && (string.IsNullOrWhiteSpace(_settings.Username) || string.IsNullOrEmpty(PlainPassword)))
        {
            MessageBox.Show(
                "Auto-login is enabled, so please enter both a username and password (or uncheck Auto-login to use the xiloader prompt).",
                "Missing Credentials",
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
            return;
        }

        IsBusy = true;
        ProgressPercent = 0;

        try
        {
            _settingsService.Save(_settings, PlainPassword);

            var progress = new Progress<SyncProgress>(p =>
            {
                StatusMessage = p.Message;
                ProgressPercent = p.Percent;
            });

            StatusMessage = "Checking Ashita v4 prerequisites...";
            await _manifestService.EnsureAshitaAndToolsAsync(_manifest, _settings, progress);

            StatusMessage = "Checking OverlordsXI files...";
            var embedded = _manifestService.LoadEmbeddedManifest();
            var (manifest, _) = await _manifestService.FetchManifestAsync(
                embedded,
                _settingsService.LoadLocalServerOverride());
            _manifest = manifest;

            await _manifestService.SyncOverlordsFilesAsync(_manifest, _settings, forceAll: false, progress);
            PendingUpdatesCount = _manifestService.GetOutdatedFiles(_manifest, _settings).Count;

            var xiloaderPath = FfxiInstallDetector.ResolveXiloaderPath(_settings.AshitaPath);
            if (string.IsNullOrEmpty(xiloaderPath))
            {
                throw new FileNotFoundException("xiloader.exe could not be located or downloaded.");
            }

            StatusMessage = "Writing Ashita v4 & Pivot configurations...";
            _configGenerator.WriteAllConfigs(
                _settings.AshitaPath,
                _settings,
                EffectiveHost,
                EffectiveUseHairpin,
                PlainPassword,
                xiloaderPath);

            RefreshDiagnostics();

            StatusMessage = $"Launching Ashita v4 -> {EffectiveHost}...";
            Log(StatusMessage);
            _launchService.LaunchAshita(_settings.AshitaPath);

            if (_settings.AutoCloseOnLaunch)
            {
                Application.Current.Shutdown();
            }
        }
        catch (Exception ex)
        {
            StatusMessage = $"Launch failed: {ex.Message}";
            Log(StatusMessage);
            MessageBox.Show(ex.Message, "Launch Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            IsBusy = false;
        }
    }

    private async Task RefreshServerStatusAsync()
    {
        ServerStatus = new ServerStatus
        {
            Host = EffectiveHost,
            IsOnline = false,
            SummaryText = $"Checking {EffectiveHost}..."
        };

        var result = await _statusService.CheckAsync(EffectiveHost, EffectiveLobbyPort, EffectiveSearchPort);
        ServerStatus = result;
    }

    private void RefreshDiagnostics()
    {
        Diagnostics = _detector.Inspect(_settings, _manifest);
        PendingUpdatesCount = _manifestService.GetOutdatedFiles(_manifest, _settings).Count;
    }

    private void SaveCurrentSettings()
    {
        _settingsService.Save(_settings, PlainPassword);
        StatusMessage = "Settings saved.";
        Log($"Settings saved to {_settingsService.SettingsPath}");
        _ = RefreshServerStatusAsync();
    }

    private void BrowseFfxiFolder()
    {
        var dialog = new OpenFolderDialog
        {
            Title = "Select FINAL FANTASY XI Installation Folder",
            InitialDirectory = Directory.Exists(FfxiPath) ? FfxiPath : @"C:\"
        };
        if (dialog.ShowDialog() == true)
        {
            FfxiPath = dialog.FolderName;
            RefreshDiagnostics();
        }
    }

    private void BrowseAshitaFolder()
    {
        var dialog = new OpenFolderDialog
        {
            Title = "Select Ashita v4 Folder",
            InitialDirectory = Directory.Exists(AshitaPath) ? AshitaPath : AppContext.BaseDirectory
        };
        if (dialog.ShowDialog() == true)
        {
            AshitaPath = dialog.FolderName;
            RefreshDiagnostics();
        }
    }

    private void BrowseCustomDatFolder()
    {
        var dialog = new OpenFolderDialog
        {
            Title = "Select Custom DAT Overlay Folder",
            InitialDirectory = Directory.Exists(CustomDatOverlayPath) ? CustomDatOverlayPath : @"C:\"
        };
        if (dialog.ShowDialog() == true)
        {
            CustomDatOverlayPath = dialog.FolderName;
        }
    }

    private void OpenAshitaFolder()
    {
        Directory.CreateDirectory(AshitaPath);
        Process.Start(new ProcessStartInfo
        {
            FileName = AshitaPath,
            UseShellExecute = true
        });
    }

    private void ExportShareableServerJson()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "overlords-server.json");
        var payload = new LocalServerOverride
        {
            ServerName = _manifest.ServerName,
            DefaultHost = EffectiveHost,
            UseHairpin = EffectiveUseHairpin,
            LobbyPort = EffectiveLobbyPort,
            SearchPort = EffectiveSearchPort
        };

        var json = JsonSerializer.Serialize(payload, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(path, json);
        StatusMessage = $"Exported {path}";
        Log($"Exported shareable server config: {path}");
        MessageBox.Show(
            $"Saved server config to:\n{path}\n\nDistribute OverlordsLauncher.exe alongside this file so players automatically connect to {EffectiveHost}.",
            "Shareable Config Exported",
            MessageBoxButton.OK,
            MessageBoxImage.Information);
    }

    private void ApplyResolutionPreset(object? parameter)
    {
        var preset = parameter?.ToString();
        switch (preset)
        {
            case "1080p":
                WindowWidth = 1920;
                WindowHeight = 1080;
                MenuWidth = 1920;
                MenuHeight = 1080;
                BackgroundWidth = 2048;
                BackgroundHeight = 2048;
                break;
            case "1440p":
                WindowWidth = 2560;
                WindowHeight = 1440;
                MenuWidth = 1920;
                MenuHeight = 1080;
                BackgroundWidth = 4096;
                BackgroundHeight = 4096;
                break;
            case "4k":
                WindowWidth = 3840;
                WindowHeight = 2160;
                MenuWidth = 1920;
                MenuHeight = 1080;
                BackgroundWidth = 4096;
                BackgroundHeight = 4096;
                break;
            case "720p":
                WindowWidth = 1280;
                WindowHeight = 720;
                MenuWidth = 1280;
                MenuHeight = 720;
                BackgroundWidth = 2048;
                BackgroundHeight = 2048;
                break;
        }
    }

    private void NotifyEffectiveServerChanged()
    {
        OnPropertyChanged(nameof(EffectiveHost));
        OnPropertyChanged(nameof(EffectiveUseHairpin));
        OnPropertyChanged(nameof(EffectiveLobbyPort));
        OnPropertyChanged(nameof(EffectiveSearchPort));
    }

    private void Log(string message)
    {
        var line = $"[{DateTime.Now:HH:mm:ss}] {message}";
        if (Application.Current?.Dispatcher is { } dispatcher && !dispatcher.CheckAccess())
        {
            dispatcher.Invoke(() => ActivityLog.Insert(0, line));
        }
        else
        {
            ActivityLog.Insert(0, line);
        }
    }

    private bool SetField<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return false;
        }

        field = value;
        OnPropertyChanged(propertyName);
        return true;
    }

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
}
