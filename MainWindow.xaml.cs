using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;

namespace PixelPin;

public partial class MainWindow : Window
{
    private readonly DispatcherTimer timer = new() { Interval = TimeSpan.FromMilliseconds(50) };
    private readonly DispatcherTimer noticeTimer = new() { Interval = TimeSpan.FromSeconds(2) };
    private readonly WriteableBitmap preview = new(ScreenSampler.Size, ScreenSampler.Size, 96, 96, PixelFormats.Bgr32, null);
    private readonly List<string> history = [];
    private readonly string historyPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PixelPin", "history.json");
    private readonly string legacyHistoryPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DigitalColorMeter", "history.json");
    private ScreenSampler? sampler;
    private IntPtr hwnd, mouseHook;
    private HwndSource? source;
    private Native.MouseHookProc? mouseHookCallback;
    private SettingsWindow? settingsWindow;
    private bool frozen, hasSample, registeredCopy, registeredFreeze, copiedIndicator;
    private bool miniMode;
    private Size standardSize;
    private Color current = Color.FromRgb(84, 124, 240);
    private string statusKey = "Live", noticeKey = "Ready";
    private string Hex => ColorFormatting.Hex(current);
    private string FormatName => SettingsStore.Current.Format.ToString().ToUpperInvariant();

    public MainWindow() : this(true) { }
    internal MainWindow(bool restoreHistory)
    {
        InitializeComponent();
        Height = Math.Min(Height, SystemParameters.WorkArea.Height);
        standardSize = new Size(Width, Height);
        Loupe.Source = preview;
        if (restoreHistory) LoadHistory();
        SettingsStore.Changed += ApplyPreferences;
        ApplyPreferences();
        timer.Tick += (_, _) => Sample();
        noticeTimer.Tick += (_, _) => { copiedIndicator = false; noticeKey = "Ready"; ApplyLabels(); noticeTimer.Stop(); };
        SourceInitialized += (_, _) => InitializeNative();
        Loaded += (_, _) => FitWindowToWorkArea();
        PreviewKeyDown += (_, e) =>
        {
            if (e.Key == Key.M && Keyboard.Modifiers == (ModifierKeys.Control | ModifierKeys.Shift))
            { ToggleMiniMode(); e.Handled = true; }
        };
        Closed += (_, _) => Cleanup();
    }
    private void InitializeNative()
    {
        hwnd = new WindowInteropHelper(this).Handle;
        source = HwndSource.FromHwnd(hwnd); source?.AddHook(WindowMessage);
        int corners = 2; Native.DwmSetWindowAttribute(hwnd, 33, ref corners, sizeof(int));
        const uint modifiers = 0x4000 | 0x0002 | 0x0004;
        registeredCopy = Native.RegisterHotKey(hwnd, 1, modifiers, 0x43);
        registeredFreeze = Native.RegisterHotKey(hwnd, 2, modifiers, 0x20);
        mouseHookCallback = OnMouseEvent;
        mouseHook = Native.SetWindowsHookEx(14, mouseHookCallback, Native.GetModuleHandle(null), 0);
        if (mouseHook == IntPtr.Zero) Notice("ClickUnavailable");
        if (!registeredCopy || !registeredFreeze) { Notice("HotkeyConflict"); NoticeText.ToolTip = Localization.Get("HotkeyHint"); }
        try { sampler = new ScreenSampler(); timer.Start(); }
        catch (InvalidOperationException) { SetStatus("CaptureFailed", "#D49C39"); }
    }
    private IntPtr WindowMessage(IntPtr window, int message, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (message == 0x0312)
        {
            if (wParam.ToInt32() == 1) { Sample(); CopyCurrent(); handled = true; }
            if (wParam.ToInt32() == 2) { if (!frozen) Sample(); ToggleFreeze(); handled = true; }
        }
        return IntPtr.Zero;
    }
    private void Sample()
    {
        if (!frozen && sampler is not null && Native.GetCursorPos(out var point)) SampleAt(point.X, point.Y);
    }
    private static bool IsInsideWindow(int x, int y)
    {
        // Includes the settings window and native ComboBox popup windows.
        IntPtr target = Native.WindowFromPoint(new Native.Point { X = x, Y = y });
        if (target == IntPtr.Zero) return false;
        Native.GetWindowThreadProcessId(target, out uint processId);
        return processId == Environment.ProcessId;
    }
    private IntPtr OnMouseEvent(int code, IntPtr message, IntPtr data)
    {
        if (code >= 0 && message.ToInt32() == 0x0201)
        {
            var point = System.Runtime.InteropServices.Marshal.PtrToStructure<Native.Point>(data);
            if (!IsInsideWindow(point.X, point.Y)) Dispatcher.BeginInvoke(DispatcherPriority.Input, new Action(() =>
            {
                if (frozen) ToggleFreeze(); else if (SampleAt(point.X, point.Y)) ToggleFreeze();
            }));
        }
        return Native.CallNextHookEx(mouseHook, code, message, data);
    }
    private bool SampleAt(int x, int y)
    {
        if (sampler is null) return false;
        if (IsInsideWindow(x, y)) { SetStatus("MoveOutside", "#98A2B2"); return false; }
        var bytes = sampler.Capture(x, y);
        if (bytes is null) { SetStatus("CaptureFailed", "#D49C39"); return false; }
        preview.WritePixels(new Int32Rect(0, 0, ScreenSampler.Size, ScreenSampler.Size), bytes, ScreenSampler.Size * 4, 0);
        int center = ((ScreenSampler.Size / 2) * ScreenSampler.Size + ScreenSampler.Size / 2) * 4;
        current = Color.FromRgb(bytes[center + 2], bytes[center + 1], bytes[center]); hasSample = true;
        RenderColor(); PositionText.Text = $"X {x}   Y {y}"; SetStatus("Live", "#32AE7A"); return true;
    }
    private void ApplyPreferences()
    {
        Language = Localization.LanguageTag;
        ApplyLabels(); RenderColor(); RenderHistory();
        ApplyWindowMode();
        FreezeButton.SetResourceReference(BackgroundProperty, frozen ? "Selected" : "Surface");
        MiniFreezeButton.SetResourceReference(BackgroundProperty, frozen ? "Selected" : "Surface");
    }
    private void ApplyLabels()
    {
        InstructionText.Text = Localization.Get(frozen ? "InstructionFrozen" : "InstructionLive");
        FreezeLabel.Text = Localization.Get(frozen ? "Resume" : "Pin");
        System.Windows.Automation.AutomationProperties.SetName(FreezeButton, FreezeLabel.Text);
        CopyButton.Content = copiedIndicator ? Localization.Get("Copied") : Localization.Get("CopyFormat", FormatName);
        System.Windows.Automation.AutomationProperties.SetName(HexText, Localization.Get("CurrentColor") + " " + FormatName);
        StatusText.Text = Localization.Get(statusKey); NoticeText.Text = Localization.Get(noticeKey);
        FormatLabel.Text = FormatName;
        MiniFormatLabel.Text = FormatName;
        MiniFreezeLabel.Text = Localization.Get(frozen ? "ResumeShort" : "PinShort");
        MiniFreezeButton.ToolTip = FreezeLabel.Text + " · Ctrl + Shift + Space";
        System.Windows.Automation.AutomationProperties.SetName(MiniFreezeButton, FreezeLabel.Text);
        MiniCopyButton.ToolTip = (copiedIndicator ? Localization.Get("Copied") : Localization.Get("CopyFormat", FormatName)) + " · Ctrl + Shift + C";
        System.Windows.Automation.AutomationProperties.SetName(MiniCopyButton, copiedIndicator ? Localization.Get("Copied") : Localization.Get("CopyFormat", FormatName));
        System.Windows.Automation.AutomationProperties.SetName(MiniValueText, Localization.Get("CurrentColor") + " " + FormatName);
        string modeAction = Localization.Get(SettingsStore.Current.MiniMode ? "ExitMiniMode" : "EnterMiniMode");
        MiniModeButton.ToolTip = modeAction + " · Ctrl + Shift + M";
        System.Windows.Automation.AutomationProperties.SetName(MiniModeButton, modeAction);
        UpdateMiniStatus();
        FormatLabel.ToolTip = SettingsStore.Current.Format == ColorFormat.Cmyk ? Localization.Get("CmykHint") : null;
        UpdateCaptureInfo();
    }
    private void RenderColor()
    {
        Swatch.Background = new SolidColorBrush(current); SwatchHex.Text = Hex;
        HexText.Text = ColorFormatting.Format(current, SettingsStore.Current.Format);
        MiniValueText.Text = HexText.Text;
        MiniValueText.ToolTip = HexText.Text;
        MiniValueText.FontSize = SettingsStore.Current.Format == ColorFormat.Hex ? 20 : SettingsStore.Current.Format == ColorFormat.Cmyk ? 11 : 12;
        MiniSwatch.Background = new SolidColorBrush(current);
        HexText.FontSize = SettingsStore.Current.Format switch { ColorFormat.Hex => 34, ColorFormat.Rgb => 20, ColorFormat.Cmyk => 13.5, _ => 15.5 };
        RedText.Text = $"R {current.R,3}"; GreenText.Text = $"G {current.G,3}"; BlueText.Text = $"B {current.B,3}";
        var textBrush = ColorFormatting.TextBrush(current);
        SwatchHex.Foreground = SwatchLabel.Foreground = textBrush;
        CopyButton.Background = new SolidColorBrush(current); CopyButton.Foreground = textBrush;
        MiniCopyButton.Background = CopyButton.Background; MiniCopyButton.Foreground = textBrush;
        UpdateCaptureInfo();
    }
    private void UpdateCaptureInfo()
    {
        string? mode = sampler?.CaptureMode;
        ScreenInfoText.Text = Localization.Get(mode == "Hdr" ? "HdrRgb" : mode == "Compatibility" ? "CompatibilityRgb" : "ScreenRgb");
        ScreenInfoText.ToolTip = mode == "Hdr" ? Localization.Get("HdrHint") : mode == "Compatibility" ? Localization.Get("CompatibilityHint") : null;
    }
    private void SetStatus(string key, string color)
    {
        statusKey = key; StatusText.Text = Localization.Get(key);
        StatusDot.Fill = (Brush)new BrushConverter().ConvertFromString(color)!;
        MiniStatusDot.Fill = StatusDot.Fill;
        UpdateMiniStatus();
    }
    private void ToggleFreeze()
    {
        if (!hasSample) { Notice("PickFirst"); return; }
        frozen = !frozen;
        PauseIcon.Visibility = frozen ? Visibility.Collapsed : Visibility.Visible;
        PlayIcon.Visibility = frozen ? Visibility.Visible : Visibility.Collapsed;
        MiniPauseIcon.Visibility = PauseIcon.Visibility;
        MiniPlayIcon.Visibility = PlayIcon.Visibility;
        FreezeButton.SetResourceReference(BackgroundProperty, frozen ? "Selected" : "Surface");
        MiniFreezeButton.SetResourceReference(BackgroundProperty, frozen ? "Selected" : "Surface");
        SetStatus(frozen ? "Frozen" : "Live", frozen ? "#547CF0" : "#32AE7A"); ApplyLabels();
        if (!frozen) Sample();
    }
    private void CopyCurrent()
    {
        if (!hasSample) { Notice("PickFirst"); return; }
        CopyColor(current);
    }
    private void CopyColor(Color color)
    {
        try { Clipboard.SetText(ColorFormatting.Format(color, SettingsStore.Current.Format)); }
        catch (System.Runtime.InteropServices.COMException) { Notice("CopyFailed"); return; }
        string hex = ColorFormatting.Hex(color); history.Remove(hex); history.Insert(0, hex);
        if (history.Count > 8) history.RemoveRange(8, history.Count - 8);
        RenderHistory(); copiedIndicator = true; Notice(SaveHistory() ? "CopiedNotice" : "HistorySaveFailed"); ApplyLabels();
    }
    private void RenderHistory()
    {
        HistoryPanel.Children.Clear(); HistoryEmpty.Visibility = history.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
        foreach (string hex in history.ToArray())
        {
            Color color = (Color)ColorConverter.ConvertFromString(hex);
            string value = ColorFormatting.Format(color, SettingsStore.Current.Format);
            var button = new Button { Background = new SolidColorBrush(color), Margin = new Thickness(0, 0, 6, 0), Padding = new Thickness(0), BorderBrush = new SolidColorBrush(Color.FromArgb(45, 130, 140, 160)), ToolTip = Localization.Get("HistoryTooltip", value) };
            System.Windows.Automation.AutomationProperties.SetName(button, Localization.Get("CopyFormat", value));
            button.Click += (_, _) => CopyColor(color); HistoryPanel.Children.Add(button);
        }
    }
    private void LoadHistory()
    {
        try
        {
            string sourcePath = File.Exists(historyPath) ? historyPath : legacyHistoryPath;
            if (File.Exists(sourcePath))
            {
                history.AddRange((JsonSerializer.Deserialize<List<string>>(File.ReadAllText(sourcePath)) ?? []).Where(h => h is not null && System.Text.RegularExpressions.Regex.IsMatch(h, "^#[0-9A-F]{6}$")).Distinct().Take(8));
                if (sourcePath == legacyHistoryPath && history.Count > 0) SaveHistory();
            }
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or JsonException) { }
    }
    private bool SaveHistory()
    {
        try { Directory.CreateDirectory(Path.GetDirectoryName(historyPath)!); File.WriteAllText(historyPath, JsonSerializer.Serialize(history)); return true; }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException) { return false; }
    }
    private void Notice(string key) { noticeKey = key; NoticeText.Text = Localization.Get(key); UpdateMiniStatus(); noticeTimer.Stop(); noticeTimer.Start(); }
    private void UpdateMiniStatus()
    {
        MiniStatusText.Text = Localization.Get(noticeKey == "Ready" ? statusKey : noticeKey);
        MiniStatusText.ToolTip = MiniStatusText.Text;
    }
    private void ApplyWindowMode()
    {
        bool requested = SettingsStore.Current.MiniMode;
        StandardPanel.Visibility = BrandFooter.Visibility = requested ? Visibility.Collapsed : Visibility.Visible;
        MiniPanel.Visibility = requested ? Visibility.Visible : Visibility.Collapsed;
        MiniModeIcon.Data = Geometry.Parse(requested ? "M3,5 L21,5 L21,19 L3,19 Z M3,9 L21,9 M8,9 L8,19" : "M3,5 L21,5 L21,19 L3,19 Z M12,12 L18,12 L18,16 L12,16 Z");
        if (miniMode == requested) return;
        if (requested) standardSize = new Size(Width, Height);
        miniMode = requested;
        var size = requested ? PickerWindowLayout.MiniSize : standardSize;
        MinWidth = requested ? PickerWindowLayout.MiniSize.Width : 440;
        MinHeight = requested ? PickerWindowLayout.MiniSize.Height : Math.Min(480, CurrentWorkArea().Height);
        Width = size.Width; Height = size.Height;
        if (IsLoaded) FitWindowToWorkArea();
    }
    private Rect CurrentWorkArea()
    {
        var info = new Native.MonitorInfo { Size = System.Runtime.InteropServices.Marshal.SizeOf<Native.MonitorInfo>() };
        if (hwnd != IntPtr.Zero && Native.GetMonitorInfo(Native.MonitorFromWindow(hwnd, 2), ref info) && source?.CompositionTarget is { } target)
        {
            var origin = target.TransformFromDevice.Transform(new Point(info.Work.Left, info.Work.Top));
            var extent = target.TransformFromDevice.Transform(new Point(info.Work.Right, info.Work.Bottom));
            return new Rect(origin, extent);
        }
        return SystemParameters.WorkArea;
    }
    internal Rect WorkArea => CurrentWorkArea();
    private void FitWindowToWorkArea()
    {
        var bounds = PickerWindowLayout.Fit(new Rect(Left, Top, Width, Height), CurrentWorkArea());
        MinWidth = Math.Min(MinWidth, bounds.Width); MinHeight = Math.Min(MinHeight, bounds.Height);
        Width = bounds.Width; Height = bounds.Height; Left = bounds.Left; Top = bounds.Top;
    }
    private void ToggleMiniMode()
    {
        if (!SettingsStore.Update(SettingsStore.Current with { MiniMode = !SettingsStore.Current.MiniMode })) Notice("SettingsSaveFailed");
    }
    private void MiniMode_Click(object sender, RoutedEventArgs e) => ToggleMiniMode();
    public bool ClearRecentColors()
    {
        bool saved = LocalDataFiles.ClearHistory(historyPath, legacyHistoryPath);
        history.Clear(); copiedIndicator = false; RenderHistory(); ApplyLabels();
        Notice(saved ? "HistoryCleared" : "DataClearFailed");
        return saved;
    }
    private void Settings_Click(object sender, RoutedEventArgs e)
    {
        if (settingsWindow is { IsVisible: true }) { settingsWindow.Activate(); return; }
        settingsWindow = new SettingsWindow { Owner = this };
        settingsWindow.Closed += (_, _) => settingsWindow = null;
        settingsWindow.Show();
    }
    private void Freeze_Click(object sender, RoutedEventArgs e) => ToggleFreeze();
    private void Copy_Click(object sender, RoutedEventArgs e) => CopyCurrent();
    private void TeamHjd_RequestNavigate(object sender, System.Windows.Navigation.RequestNavigateEventArgs e)
    {
        e.Handled = true;
        try { System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("https://teamhjd.com/") { UseShellExecute = true }); }
        catch (Exception ex) when (ex is System.ComponentModel.Win32Exception or InvalidOperationException) { Notice("BrowserFailed"); }
    }
    private void Minimize_Click(object sender, RoutedEventArgs e) => WindowState = WindowState.Minimized;
    private void Close_Click(object sender, RoutedEventArgs e) => Close();
    private void Cleanup()
    {
        SettingsStore.Changed -= ApplyPreferences;
        settingsWindow?.Close(); timer.Stop(); noticeTimer.Stop();
        if (registeredCopy) Native.UnregisterHotKey(hwnd, 1);
        if (registeredFreeze) Native.UnregisterHotKey(hwnd, 2);
        if (mouseHook != IntPtr.Zero) Native.UnhookWindowsHookEx(mouseHook);
        source?.RemoveHook(WindowMessage); sampler?.Dispose();
    }
}
