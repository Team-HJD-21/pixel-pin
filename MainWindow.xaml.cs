using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
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
    private IntPtr hwnd;
    private HwndSource? source;
    private IntPtr mouseHook;
    private Native.MouseHookProc? mouseHookCallback;
    private bool frozen, hasSample, registeredCopy, registeredFreeze;
    private Color current = Color.FromRgb(84, 124, 240);
    private string Hex => $"#{current.R:X2}{current.G:X2}{current.B:X2}";

    public MainWindow()
    {
        InitializeComponent();
        Height = Math.Min(Height, SystemParameters.WorkArea.Height);
        Loupe.Source = preview;
        RenderColor();
        LoadHistory();
        timer.Tick += (_, _) => Sample();
        noticeTimer.Tick += (_, _) => { NoticeText.Text = "READY TO PICK"; CopyButton.Content = "HEX 복사"; noticeTimer.Stop(); };
        SourceInitialized += (_, _) => InitializeNative();
        Closed += (_, _) => Cleanup();
    }
    private void InitializeNative()
    {
        hwnd = new WindowInteropHelper(this).Handle;
        source = HwndSource.FromHwnd(hwnd);
        source?.AddHook(WindowMessage);
        int corners = 2;
        Native.DwmSetWindowAttribute(hwnd, 33, ref corners, sizeof(int));
        const uint modifiers = 0x4000 | 0x0002 | 0x0004; // no repeat, Ctrl, Shift
        registeredCopy = Native.RegisterHotKey(hwnd, 1, modifiers, 0x43);
        registeredFreeze = Native.RegisterHotKey(hwnd, 2, modifiers, 0x20);
        mouseHookCallback = OnMouseEvent;
        mouseHook = Native.SetWindowsHookEx(14, mouseHookCallback, Native.GetModuleHandle(null), 0);
        if (mouseHook == IntPtr.Zero) Notice("클릭 감지 불가 · 고정 버튼 사용");
        if (!registeredCopy || !registeredFreeze)
        {
            Notice("단축키 충돌 · 버튼 사용");
            NoticeText.ToolTip = "다른 프로그램에서 단축키를 사용하고 있습니다. 복사/고정 버튼은 정상적으로 동작합니다.";
        }
        try { sampler = new ScreenSampler(); timer.Start(); }
        catch (InvalidOperationException ex) { StatusText.Text = ex.Message; }
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
        if (frozen || sampler is null) return;
        if (!Native.GetCursorPos(out var point)) return;
        SampleAt(point.X, point.Y);
    }
    private bool IsInsideWindow(int x, int y) => WindowState != WindowState.Minimized && Native.GetWindowRect(hwnd, out var rect) &&
        x >= rect.Left && x < rect.Right && y >= rect.Top && y < rect.Bottom;

    private IntPtr OnMouseEvent(int code, IntPtr message, IntPtr data)
    {
        if (code >= 0 && message.ToInt32() == 0x0201)
        {
            var point = System.Runtime.InteropServices.Marshal.PtrToStructure<Native.Point>(data);
            if (!IsInsideWindow(point.X, point.Y))
            {
                // The hook never swallows input. Capture at the original click coordinates,
                // even if the cursor moves before the dispatcher processes this request.
                Dispatcher.BeginInvoke(DispatcherPriority.Input, new Action(() =>
                {
                    if (frozen) ToggleFreeze();
                    else if (SampleAt(point.X, point.Y)) ToggleFreeze();
                }));
            }
        }
        return Native.CallNextHookEx(mouseHook, code, message, data);
    }
    private bool SampleAt(int x, int y)
    {
        if (sampler is null) return false;
        if (IsInsideWindow(x, y))
        {
            SetStatus("화면 위로 커서를 옮겨보세요", "#98A2B2");
            return false;
        }
        var bytes = sampler.Capture(x, y);
        if (bytes is null) { SetStatus("이 화면을 읽을 수 없습니다", "#D49C39"); return false; }
        preview.WritePixels(new Int32Rect(0, 0, ScreenSampler.Size, ScreenSampler.Size), bytes, ScreenSampler.Size * 4, 0);
        int center = ((ScreenSampler.Size / 2) * ScreenSampler.Size + ScreenSampler.Size / 2) * 4;
        current = Color.FromRgb(bytes[center + 2], bytes[center + 1], bytes[center]);
        hasSample = true;
        RenderColor();
        PositionText.Text = $"X {x}   Y {y}";
        SetStatus("실시간 측정", "#32AE7A");
        return true;
    }
    private void RenderColor()
    {
        Swatch.Background = new SolidColorBrush(current);
        HexText.Text = SwatchHex.Text = Hex;
        RedText.Text = $"R {current.R,3}"; GreenText.Text = $"G {current.G,3}"; BlueText.Text = $"B {current.B,3}";
        // Relative luminance chooses the more legible black or white label.
        static double Linear(byte channel) { double value = channel / 255.0; return value <= .04045 ? value / 12.92 : Math.Pow((value + .055) / 1.055, 2.4); }
        double luminance = .2126 * Linear(current.R) + .7152 * Linear(current.G) + .0722 * Linear(current.B);
        var textBrush = luminance > .179 ? Brushes.Black : Brushes.White;
        SwatchHex.Foreground = SwatchLabel.Foreground = textBrush;
        CopyButton.Background = new SolidColorBrush(current);
        CopyButton.Foreground = textBrush;
    }
    private void SetStatus(string text, string color)
    {
        StatusText.Text = text;
        StatusDot.Fill = (Brush)new BrushConverter().ConvertFromString(color)!;
    }
    private void ToggleFreeze()
    {
        if (!hasSample) { Notice("먼저 화면의 색을 골라주세요"); return; }
        frozen = !frozen;
        InstructionText.Text = frozen
            ? "화면을 다시 클릭하면 실시간 측정이 재개됩니다."
            : "화면 클릭으로 색상 고정 · 다시 클릭하면 측정 재개";
        FreezeLabel.Text = frozen ? "실시간 측정 재개" : "색상 고정";
        PauseIcon.Visibility = frozen ? Visibility.Collapsed : Visibility.Visible;
        PlayIcon.Visibility = frozen ? Visibility.Visible : Visibility.Collapsed;
        System.Windows.Automation.AutomationProperties.SetName(FreezeButton, FreezeLabel.Text);
        FreezeButton.Background = (Brush)new BrushConverter().ConvertFromString(frozen ? "#E9EEFC" : "#FFFFFF")!;
        if (frozen) SetStatus("색상 고정됨", "#547CF0"); else Sample();
    }
    private void CopyCurrent()
    {
        if (!hasSample) { Notice("먼저 화면의 색을 골라주세요"); return; }
        CopyHex(Hex);
    }
    private void CopyHex(string hex)
    {
        try { Clipboard.SetText(hex); }
        catch (System.Runtime.InteropServices.COMException) { Notice("복사 재시도 필요"); return; }
        history.Remove(hex); history.Insert(0, hex);
        if (history.Count > 8) history.RemoveRange(8, history.Count - 8);
        RenderHistory(); SaveHistory();
        CopyButton.Content = "복사 완료 ✓"; Notice("클립보드에 복사됨");
    }
    private void RenderHistory()
    {
        HistoryPanel.Children.Clear();
        HistoryEmpty.Visibility = history.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
        foreach (string hex in history.ToArray())
        {
            var button = new Button { Background = (Brush)new BrushConverter().ConvertFromString(hex)!, Margin = new Thickness(0, 0, 6, 0), Padding = new Thickness(0), BorderBrush = new SolidColorBrush(Color.FromArgb(30, 0, 0, 0)), ToolTip = $"{hex} · 클릭하여 복사" };
            System.Windows.Automation.AutomationProperties.SetName(button, $"{hex} 복사");
            button.Click += (_, _) => CopyHex(hex);
            HistoryPanel.Children.Add(button);
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
        RenderHistory();
    }
    private void SaveHistory()
    {
        try { Directory.CreateDirectory(Path.GetDirectoryName(historyPath)!); File.WriteAllText(historyPath, JsonSerializer.Serialize(history)); }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException) { Notice("복사 완료 · 기록 저장 실패"); }
    }
    private void Notice(string text) { NoticeText.Text = text; noticeTimer.Stop(); noticeTimer.Start(); }
    private void Freeze_Click(object sender, RoutedEventArgs e) => ToggleFreeze();
    private void Copy_Click(object sender, RoutedEventArgs e) => CopyCurrent();
    private void TeamHjd_RequestNavigate(object sender, System.Windows.Navigation.RequestNavigateEventArgs e)
    {
        e.Handled = true;
        try { System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("https://teamhjd.com/") { UseShellExecute = true }); }
        catch (Exception ex) when (ex is System.ComponentModel.Win32Exception or InvalidOperationException)
        { Notice("브라우저를 열 수 없습니다"); }
    }
    private void Minimize_Click(object sender, RoutedEventArgs e) => WindowState = WindowState.Minimized;
    private void Close_Click(object sender, RoutedEventArgs e) => Close();
    private void Cleanup()
    {
        timer.Stop(); noticeTimer.Stop();
        if (registeredCopy) Native.UnregisterHotKey(hwnd, 1);
        if (registeredFreeze) Native.UnregisterHotKey(hwnd, 2);
        if (mouseHook != IntPtr.Zero) Native.UnhookWindowsHookEx(mouseHook);
        source?.RemoveHook(WindowMessage);
        sampler?.Dispose();
    }
}
