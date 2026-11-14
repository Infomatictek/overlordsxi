using System.Globalization;
using System.Windows;
using System.Windows.Data;
using System.Windows.Media;

namespace OverlordsLauncher.Converters;

public sealed class BoolToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        var flag = value is bool b && b;
        if (parameter is string s && s.Equals("Invert", StringComparison.OrdinalIgnoreCase))
        {
            flag = !flag;
        }

        return flag ? Visibility.Visible : Visibility.Collapsed;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) =>
        value is Visibility v && v == Visibility.Visible;
}

public sealed class BoolToStatusBrushConverter : IValueConverter
{
    private static readonly Brush OnlineBrush = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#2DD4BF"));
    private static readonly Brush OfflineBrush = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#F87171"));

    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) =>
        value is true ? OnlineBrush : OfflineBrush;

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}

public sealed class BoolToReadyTextConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) =>
        value is true ? "READY" : "MISSING";

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}

public sealed class FpsCapLabelConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) =>
        value switch
        {
            60 => "60 FPS (Smooth)",
            30 => "30 FPS (Classic)",
            0 => "Uncapped",
            _ => value?.ToString() ?? string.Empty
        };

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}
