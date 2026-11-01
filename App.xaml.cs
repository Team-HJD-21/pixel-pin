using System.Windows;
using Microsoft.Win32;
namespace PixelPin;
public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        SettingsStore.Load(); Localization.Apply(); ThemeManager.Apply();
        SystemEvents.UserPreferenceChanged += OnSystemPreferenceChanged;
        base.OnStartup(e);
    }
    private void OnSystemPreferenceChanged(object sender, UserPreferenceChangedEventArgs e)
    {
        if (SettingsStore.Current.Theme == global::PixelPin.ThemeMode.System)
            Dispatcher.BeginInvoke(new Action(ThemeManager.Apply));
    }
    protected override void OnExit(ExitEventArgs e)
    {
        SystemEvents.UserPreferenceChanged -= OnSystemPreferenceChanged;
        base.OnExit(e);
    }
}
