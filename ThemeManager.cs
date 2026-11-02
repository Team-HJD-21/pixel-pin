using System.Windows;
using System.Windows.Media;
using Microsoft.Win32;

namespace PixelPin;

public static class ThemeManager
{
    public static bool IsDark { get; private set; }
    public static void Apply()
    {
        bool systemDark;
        try { systemDark = Registry.GetValue(@"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme", 1) is int value && value == 0; }
        catch (Exception ex) when (ex is System.Security.SecurityException or UnauthorizedAccessException or System.IO.IOException) { systemDark = false; }
        IsDark = SettingsStore.Current.Theme == ThemeMode.Dark || (SettingsStore.Current.Theme == ThemeMode.System && systemDark);
        string[][] palette =
        [
            ["Canvas", "#F6F7F9", "#141923"], ["Surface", "#FFFFFF", "#1E2633"],
            ["Ink", "#202730", "#E9EDF5"], ["Muted", "#596579", "#A4AFC1"],
            ["Stroke", "#E1E5EB", "#344054"], ["Inset", "#EDF0F4", "#273142"],
            ["Selected", "#E9EEFC", "#2C3C62"], ["Accent", "#3B5FCB", "#92B0FF"],
            ["Footer", "#596579", "#A4AFC1"], ["Error", "#B34A32", "#FFB29A"],
        ];
        foreach (var entry in palette) Application.Current.Resources[entry[0]] = new SolidColorBrush((Color)ColorConverter.ConvertFromString(entry[IsDark ? 2 : 1]));
    }
}
