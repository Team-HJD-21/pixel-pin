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
        Loaded += (_, _) =>
        {
            var workArea = Owner is MainWindow main ? main.WorkArea : SystemParameters.WorkArea;
            var bounds = PickerWindowLayout.Fit(new Rect(Left, Top, Width, Height), workArea);
            MinHeight = Math.Min(MinHeight, bounds.Height);
            Width = bounds.Width; Height = bounds.Height; Left = bounds.Left; Top = bounds.Top;
        };
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
            WindowModeChoice.ItemsSource = new[] { new SettingOption<bool>(false, Localization.Get("StandardMode")), new(true, Localization.Get("MiniMode")) };
            ThemeChoice.SelectedValue = SettingsStore.Current.Theme; LanguageChoice.SelectedValue = SettingsStore.Current.Language; FormatChoice.SelectedValue = SettingsStore.Current.Format;
            WindowModeChoice.SelectedValue = SettingsStore.Current.MiniMode;
            SaveHint.SetResourceReference(TextBlock.TextProperty, "L.AutoSaved"); SaveHint.SetResourceReference(TextBlock.ForegroundProperty, "Muted");
            FormatHintText.SetResourceReference(TextBlock.TextProperty, SettingsStore.Current.Format switch { ColorFormat.Cmyk => "L.CmykHint", ColorFormat.Hsv => "L.HsvHint", _ => "L.FormatHint" });
        }
        finally { refreshing = false; }
    }
    private void Choice_Changed(object sender, SelectionChangedEventArgs e)
    {
        if (refreshing || !IsInitialized) return;
        if (ThemeChoice?.SelectedValue is not ThemeMode theme || LanguageChoice?.SelectedValue is not UiLanguage language || FormatChoice?.SelectedValue is not ColorFormat format) return;
        if (WindowModeChoice?.SelectedValue is not bool miniMode) return;
        if (!SettingsStore.Update(SettingsStore.Current with { Theme = theme, Language = language, Format = format, MiniMode = miniMode }))
        { SaveHint.SetResourceReference(TextBlock.TextProperty, "L.SettingsSaveFailed"); SaveHint.SetResourceReference(TextBlock.ForegroundProperty, "Error"); }
    }
    private void Close_Click(object sender, RoutedEventArgs e) => Close();
    private void ClearHistory_Click(object sender, RoutedEventArgs e)
    {
        if (MessageBox.Show(this, Localization.Get("ClearHistoryConfirm"), Localization.Get("ClearHistory"), MessageBoxButton.YesNo, MessageBoxImage.Question, MessageBoxResult.No) != MessageBoxResult.Yes) return;
        bool saved = Owner is MainWindow main && main.ClearRecentColors();
        ShowDataResult(saved, "HistoryCleared");
    }
    private void ResetSettings_Click(object sender, RoutedEventArgs e)
    {
        if (MessageBox.Show(this, Localization.Get("ResetSettingsConfirm"), Localization.Get("ResetSettings"), MessageBoxButton.YesNo, MessageBoxImage.Question, MessageBoxResult.No) != MessageBoxResult.Yes) return;
        ShowDataResult(SettingsStore.Reset(), "SettingsReset");
    }
    private void ShowDataResult(bool success, string successKey)
    {
        DataResult.Text = Localization.Get(success ? successKey : "DataClearFailed");
        DataResult.SetResourceReference(TextBlock.ForegroundProperty, success ? "Muted" : "Error");
    }
    private void Policy_Click(object sender, RoutedEventArgs e)
    {
        string suffix = (sender as Button)?.Tag as string ?? "privacy";
        if (suffix is not ("privacy" or "terms" or "support")) return;
        string language = SettingsStore.Current.Language switch { UiLanguage.English => "en/", UiLanguage.Chinese => "zh-CN/", _ => "" };
        try { System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo($"https://pixelpin.teamhjd.com/{language}{suffix}/") { UseShellExecute = true }); }
        catch (Exception ex) when (ex is System.ComponentModel.Win32Exception or InvalidOperationException) { DataResult.Text = Localization.Get("BrowserFailed"); }
    }
}
