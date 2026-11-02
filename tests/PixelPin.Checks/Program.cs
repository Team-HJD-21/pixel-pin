using System.IO;
using System.Reflection;
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
            Console.WriteLine("PASS: clear current/legacy history, preserve unrelated files, repeat clear, write-failure safety; settings XAML and new labels in 3 languages × 2 themes. User settings were not written; no windows were shown.");
        }
        finally
        {
            string absolute=Path.GetFullPath(testRoot), temp=Path.GetFullPath(Path.GetTempPath()).TrimEnd(Path.DirectorySeparatorChar)+Path.DirectorySeparatorChar;
            if(!absolute.StartsWith(temp,StringComparison.OrdinalIgnoreCase)||!Path.GetFileName(absolute).StartsWith("PixelPinChecks-",StringComparison.Ordinal))throw new IOException("Unsafe test cleanup path");
            Directory.Delete(absolute,true);
        }
    }
}
