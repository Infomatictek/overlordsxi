using System.Windows;
using System.Windows.Controls;
using OverlordsLauncher.ViewModels;

namespace OverlordsLauncher;

public partial class MainWindow : Window
{
    private readonly MainViewModel _viewModel;
    private bool _syncingPassword;

    public MainWindow()
    {
        InitializeComponent();
        _viewModel = new MainViewModel();
        DataContext = _viewModel;

        Loaded += MainWindow_Loaded;
    }

    private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        _syncingPassword = true;
        AccountPasswordBox.Password = _viewModel.PlainPassword;
        _syncingPassword = false;

        await _viewModel.InitializeAsync();
    }

    private void AccountPasswordBox_OnPasswordChanged(object sender, RoutedEventArgs e)
    {
        if (_syncingPassword || sender is not PasswordBox box)
        {
            return;
        }

        _viewModel.PlainPassword = box.Password;
    }

    private void MinimizeClick(object sender, RoutedEventArgs e) => WindowState = WindowState.Minimized;

    private void CloseClick(object sender, RoutedEventArgs e) => Close();
}
