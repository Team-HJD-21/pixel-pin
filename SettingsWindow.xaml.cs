using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;

namespace PixelPin;
public sealed record SettingOption<T>(T Value, string Label) { public override string ToString() => Label; }
public partial class SettingsWindow : Window
{
    private bool refreshing;
    public SettingsWindow()
    {
        InitializeComponent(); Height = Math.Min(Height, SystemParameters.WorkArea.Height);
        SettingsStore.Changed += RefreshChoices;
        Closed += (_, _) => SettingsStore.Changed -= RefreshChoices;
        SourceInitialized += (_, _) => { int corners = 2; Native.DwmSetWindowAttribute(new WindowInteropHelper(this).Handle, 33, ref corners, sizeof(int)); };
        RefreshChoices();
    }
    private void RefreshChoices()
    {
        refreshing = true;
        try
        {
            Language = Localization.LanguageTag;
            ThemeChoice.ItemsSource = new[] { new SettingOption<ThemeMode>(global::PixelPin.ThemeMode.System, Localization.Get("System")), new(global::PixelPin.ThemeMode.Light, Localization.Get("Light")), new(global::PixelPin.ThemeMode.Dark, Localization.Get("Dark")) };
            LanguageChoice.ItemsSource = new[] { new SettingOption<UiLanguage>(UiLanguage.Korean, "한국어"), new(UiLanguage.English, "English"), new(UiLanguage.Chinese, "简体中文") };
            FormatChoice.ItemsSource = new[] { new SettingOption<ColorFormat>(ColorFormat.Hex, "HEX · #RRGGBB"), new(ColorFormat.Rgb, "RGB · rgb(255, 128, 0)"), new(ColorFormat.Hsl, "HSL · hsl(30, 100%, 50%)"), new(ColorFormat.Hsv, "HSV · hsv(30, 100%, 100%)"), new(ColorFormat.Cmyk, Localization.Get("CmykOption")) };
            ThemeChoice.SelectedValue = SettingsStore.Current.Theme; LanguageChoice.SelectedValue = SettingsStore.Current.Language; FormatChoice.SelectedValue = SettingsStore.Current.Format;
            SaveHint.SetResourceReference(TextBlock.TextProperty, "L.AutoSaved"); SaveHint.SetResourceReference(TextBlock.ForegroundProperty, "Muted");
            FormatHintText.SetResourceReference(TextBlock.TextProperty, SettingsStore.Current.Format switch { ColorFormat.Cmyk => "L.CmykHint", ColorFormat.Hsv => "L.HsvHint", _ => "L.FormatHint" });
        }
        finally { refreshing = false; }
    }
    private void Choice_Changed(object sender, SelectionChangedEventArgs e)
    {
        if (refreshing || !IsInitialized) return;
        if (ThemeChoice?.SelectedValue is not ThemeMode theme || LanguageChoice?.SelectedValue is not UiLanguage language || FormatChoice?.SelectedValue is not ColorFormat format) return;
        if (!SettingsStore.Update(new AppSettings { Theme = theme, Language = language, Format = format }))
        { SaveHint.SetResourceReference(TextBlock.TextProperty, "L.SettingsSaveFailed"); SaveHint.SetResourceReference(TextBlock.ForegroundProperty, "Error"); }
    }
    private void Close_Click(object sender, RoutedEventArgs e) => Close();
}
