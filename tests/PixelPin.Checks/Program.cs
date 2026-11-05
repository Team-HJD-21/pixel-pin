using System.IO;
using System.Reflection;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using PixelPin;
using ThemeMode = PixelPin.ThemeMode;
using Localization = PixelPin.Localization;

internal static class Program
{
    static void Check(bool condition, string message) { if (!condition) throw new Exception(message); }
    [STAThread] static void Main(string[] args)
    {
        string testRoot = Path.Combine(Path.GetTempPath(), "PixelPinChecks-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(testRoot);
        try
        {
            string current=Path.Combine(testRoot,"current","history.json"),legacy=Path.Combine(testRoot,"legacy.json"),sentinel=Path.Combine(testRoot,"untouched.txt");
            File.WriteAllText(legacy,"[\"#FFFFFF\"]");File.WriteAllText(sentinel,"keep");
            Check(LocalDataFiles.ClearHistory(current,legacy),"Clear failed");
            Check(File.ReadAllText(current)=="[]"&&!File.Exists(legacy),"History or legacy data remains");
            Check(File.ReadAllText(sentinel)=="keep","Unrelated file changed");
            Check(LocalDataFiles.ClearHistory(current,legacy),"Repeated clear failed");
            string blocked=Path.Combine(testRoot,"blocked.json");Directory.CreateDirectory(blocked+".tmp");
            File.WriteAllText(legacy,"keep on failure");
            Check(!LocalDataFiles.ClearHistory(blocked,legacy),"Failure incorrectly reported as success");
            Check(File.ReadAllText(legacy)=="keep on failure","Legacy removed before current write succeeded");
            var app=new App();app.InitializeComponent();
            var backing=typeof(SettingsStore).GetField("<Current>k__BackingField",BindingFlags.Static|BindingFlags.NonPublic)!;
            var flags=BindingFlags.Instance|BindingFlags.NonPublic;
            var settings=new SettingsWindow();
            foreach(var language in Enum.GetValues<UiLanguage>())foreach(var theme in new[]{ThemeMode.Light,ThemeMode.Dark})
            {
                backing.SetValue(null,new AppSettings{Language=language,Theme=theme});Localization.Apply();ThemeManager.Apply();
                typeof(SettingsWindow).GetMethod("RefreshChoices",flags)!.Invoke(settings,null);
                foreach(var key in new[]{"LocalData","LocalDataHint","ClearHistory","ClearHistoryConfirm","HistoryCleared","ResetSettings","ResetSettingsConfirm","SettingsReset","DataClearFailed","Privacy","Terms","SupportPolicy"})Check(Localization.Get(key)!=key,"Missing translation "+key);
                var choices=(ComboBox)settings.FindName("LanguageChoice");
                Check(choices.Items.Count==3,"Language choices missing");
                if(args.Length>0)
                {
                    var surface=(Grid)settings.Content;surface.Background=settings.Background;surface.Measure(new Size(420,760));surface.Arrange(new Rect(0,0,420,760));surface.UpdateLayout();
                    var bitmap=new RenderTargetBitmap(840,1520,192,192,PixelFormats.Pbgra32);bitmap.Render(surface);var png=new PngBitmapEncoder();png.Frames.Add(BitmapFrame.Create(bitmap));
                    using var file=File.Create(Path.Combine(args[0],$"settings-{language}-{theme}.png"));png.Save(file);
                }
            }
            settings.Close();
            CheckMiniMode(backing, flags, args.FirstOrDefault());
            Console.WriteLine("PASS: clear current/legacy history, preserve unrelated files, repeat clear, write-failure safety; settings XAML and new labels in 3 languages × 2 themes. User settings were not written; no windows were shown.");
        }
        finally
        {
            string absolute=Path.GetFullPath(testRoot), temp=Path.GetFullPath(Path.GetTempPath()).TrimEnd(Path.DirectorySeparatorChar)+Path.DirectorySeparatorChar;
            if(!absolute.StartsWith(temp,StringComparison.OrdinalIgnoreCase)||!Path.GetFileName(absolute).StartsWith("PixelPinChecks-",StringComparison.Ordinal))throw new IOException("Unsafe test cleanup path");
            Directory.Delete(absolute,true);
        }
    }

    private static void CheckMiniMode(FieldInfo settingsBacking, BindingFlags flags, string? previewDirectory)
    {
        var jsonOptions = new JsonSerializerOptions { Converters = { new JsonStringEnumConverter() } };
        Check(!JsonSerializer.Deserialize<AppSettings>("{}", jsonOptions)!.MiniMode, "Old settings must open in standard mode");
        var saved = new AppSettings { MiniMode = true, Language = UiLanguage.Chinese, Format = ColorFormat.Cmyk };
        Check(JsonSerializer.Deserialize<AppSettings>(JsonSerializer.Serialize(saved, jsonOptions), jsonOptions) == saved, "Mini preference did not round-trip with other settings");
        var negativeMonitor = new Rect(-1920, 0, 1920, 1040);
        var fitted = PickerWindowLayout.Fit(new Rect(-50, 900, 440, 800), negativeMonitor);
        Check(negativeMonitor.Contains(fitted) && fitted.Right <= 0, "Expanding on a secondary monitor moved off-screen");
        var shortMonitor = new Rect(0, 0, 640, 360);
        Check(shortMonitor.Contains(PickerWindowLayout.Fit(new Rect(600, 300, 440, 800), shortMonitor)), "Short work area did not contain the fitted window");

        settingsBacking.SetValue(null, new AppSettings());
        Localization.Apply(); ThemeManager.Apply();
        // The test constructor skips history migration; no window is shown or capture hook started.
        var window = (MainWindow)Activator.CreateInstance(typeof(MainWindow), flags, null, [false], null)!;
        var originalSize = new Size(window.Width, window.Height);
        var color = Color.FromRgb(12, 123, 234);
        typeof(MainWindow).GetField("current", flags)!.SetValue(window, color);
        typeof(MainWindow).GetField("hasSample", flags)!.SetValue(window, true);
        typeof(MainWindow).GetMethod("ToggleFreeze", flags)!.Invoke(window, null);
        foreach (var language in Enum.GetValues<UiLanguage>())
        foreach (var theme in new[] { ThemeMode.Light, ThemeMode.Dark })
        foreach (var format in Enum.GetValues<ColorFormat>())
        {
            settingsBacking.SetValue(null, new AppSettings { MiniMode = true, Language = language, Theme = theme, Format = format });
            Localization.Apply(); ThemeManager.Apply();
            typeof(MainWindow).GetMethod("ApplyPreferences", flags)!.Invoke(window, null);
            Check(window.Width == PickerWindowLayout.MiniSize.Width && window.Height == PickerWindowLayout.MiniSize.Height, "Mini dimensions were not applied");
            Check(((Grid)window.FindName("MiniPanel")).Visibility == Visibility.Visible && ((ScrollViewer)window.FindName("StandardPanel")).Visibility == Visibility.Collapsed, "Wrong picker content visible");
            Check(((TextBox)window.FindName("MiniValueText")).Text == ColorFormatting.Format(color, format), "Mini value differs from the sampled color/format");
            Check((bool)typeof(MainWindow).GetField("frozen", flags)!.GetValue(window)!, "Changing mode/appearance unpinned the sample");
            Check(((TextBlock)window.FindName("MiniFreezeLabel")).Text == Localization.Get("ResumeShort"), "Mini freeze control lost its state");
            foreach (string key in new[] { "WindowMode", "StandardMode", "MiniMode", "EnterMiniMode", "ExitMiniMode", "PinShort", "ResumeShort" })
                Check(Localization.Get(key) != key, "Missing mini mode translation " + key);
            var surface = (Grid)window.Content;
            surface.Background = window.Background;
            surface.Measure(new Size(window.Width, window.Height));
            surface.Arrange(new Rect(0, 0, window.Width, window.Height));
            surface.UpdateLayout();
            Check(((TextBox)window.FindName("MiniValueText")).ActualHeight <= 52, "Formatted value overflows its mini row");
            if (previewDirectory is not null && format is ColorFormat.Hex or ColorFormat.Cmyk)
            {
                var bitmap = new RenderTargetBitmap((int)window.Width * 2, (int)window.Height * 2, 192, 192, PixelFormats.Pbgra32);
                bitmap.Render(surface);
                var png = new PngBitmapEncoder(); png.Frames.Add(BitmapFrame.Create(bitmap));
                using var file = File.Create(Path.Combine(previewDirectory, $"mini-{language}-{theme}-{format}.png")); png.Save(file);
            }
        }
        settingsBacking.SetValue(null, new AppSettings());
        Localization.Apply(); ThemeManager.Apply();
        typeof(MainWindow).GetMethod("ApplyPreferences", flags)!.Invoke(window, null);
        Check(window.Width == originalSize.Width && window.Height == originalSize.Height, "Returning from mini mode lost the standard size");
        Check(((Grid)window.FindName("MiniPanel")).Visibility == Visibility.Collapsed, "Mini content remains in standard mode");
        Check((bool)typeof(MainWindow).GetField("frozen", flags)!.GetValue(window)!, "Returning to standard mode lost the pinned color");
        settingsBacking.SetValue(null, new AppSettings { MiniMode = true });
        typeof(MainWindow).GetMethod("ApplyPreferences", flags)!.Invoke(window, null);
        ((Button)window.FindName("MiniFreezeButton")).RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
        Check(!(bool)typeof(MainWindow).GetField("frozen", flags)!.GetValue(window)!, "Mini resume button did not resume the shared picker");
        Check(((StackPanel)window.FindName("MiniPauseIcon")).Visibility == Visibility.Visible, "Mini resume did not update the pause icon");
        ((Button)window.FindName("MiniFreezeButton")).RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
        Check((bool)typeof(MainWindow).GetField("frozen", flags)!.GetValue(window)!, "Mini pin button did not pin the shared picker");
        window.Close();
        Console.WriteLine("PASS: mini mode in 3 languages × 2 themes × 5 formats; preference compatibility, pinned state, size restoration, and secondary/short-monitor bounds. No capture or clipboard access.");
    }
}
