using System.Runtime.InteropServices;
namespace PixelPin;

// Coordinates and captured bytes are physical desktop pixels, including negative monitor coordinates.
internal sealed class ScreenSampler : IDisposable
{
    private readonly DirectXSampler directX = new();
    internal string CaptureMode { get; private set; } = "Compatibility";
    internal const int Size = 17;
    private readonly IntPtr desktop, memory, bitmap, previous;
    private readonly byte[] pixels = new byte[Size * Size * 4];
    private bool disposed;
    public ScreenSampler()
    {
        desktop = Native.GetDC(IntPtr.Zero);
        memory = Native.CreateCompatibleDC(desktop);
        bitmap = Native.CreateCompatibleBitmap(desktop, Size, Size);
        if (desktop == IntPtr.Zero || memory == IntPtr.Zero || bitmap == IntPtr.Zero)
        {
            Dispose();
            throw new InvalidOperationException("화면을 읽을 수 없습니다.");
        }
        previous = Native.SelectObject(memory, bitmap);
    }
    internal byte[]? Capture(int x, int y)
    {
        var directPixels = directX.Capture(x, y);
        if (directPixels is not null) { CaptureMode = directX.IsHdr ? "Hdr" : "DirectX"; return directPixels; }
        CaptureMode = "Compatibility";
        // Stretch edge pixels into the magnifier rather than reading beyond the virtual screen.
        int left = Native.GetSystemMetrics(76), top = Native.GetSystemMetrics(77);
        int right = left + Native.GetSystemMetrics(78) - 1;
        int bottom = top + Native.GetSystemMetrics(79) - 1;
        int sx = Math.Max(left, x - Size / 2), sy = Math.Max(top, y - Size / 2);
        int width = Math.Min(right, x + Size / 2) - sx + 1;
        int height = Math.Min(bottom, y + Size / 2) - sy + 1;
        if (width <= 0 || height <= 0 || !Native.BitBlt(memory, 0, 0, width, height, desktop, sx, sy, 0x40CC0020)) return null;
        var info = new Native.BitmapInfo { Size = 40, Width = Size, Height = -Size, Planes = 1, BitCount = 32 };
        Native.SelectObject(memory, previous);
        int read;
        try { read = Native.GetDIBits(memory, bitmap, 0, Size, pixels, ref info, 0); }
        finally { Native.SelectObject(memory, bitmap); }
        if (read != Size) return null;
        var result = new byte[pixels.Length];
        for (int row = 0; row < Size; row++)
        for (int col = 0; col < Size; col++)
        {
            int px = Math.Clamp(x - Size / 2 + col, sx, sx + width - 1) - sx;
            int py = Math.Clamp(y - Size / 2 + row, sy, sy + height - 1) - sy;
            Buffer.BlockCopy(pixels, (py * Size + px) * 4, result, (row * Size + col) * 4, 4);
        }
        return result;
    }
    public void Dispose()
    {
        if (disposed) return;
        disposed = true;
        directX.Dispose();
        if (previous != IntPtr.Zero && memory != IntPtr.Zero) Native.SelectObject(memory, previous);
        if (bitmap != IntPtr.Zero) Native.DeleteObject(bitmap);
        if (memory != IntPtr.Zero) Native.DeleteDC(memory);
        if (desktop != IntPtr.Zero) Native.ReleaseDC(IntPtr.Zero, desktop);
    }
}

internal static class Native
{
    [DllImport("user32.dll")] internal static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")] internal static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
    internal delegate IntPtr MouseHookProc(int code, IntPtr message, IntPtr data);
    [DllImport("user32.dll", SetLastError = true)] internal static extern IntPtr SetWindowsHookEx(int id, MouseHookProc callback, IntPtr module, uint thread);
    [DllImport("user32.dll")] internal static extern bool UnhookWindowsHookEx(IntPtr hook);
    [DllImport("user32.dll")] internal static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr message, IntPtr data);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] internal static extern IntPtr GetModuleHandle(string? name);
    [StructLayout(LayoutKind.Sequential)] internal struct Point { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] internal struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] internal struct MonitorInfo { public int Size; public Rect Monitor, Work; public uint Flags; }
    [DllImport("user32.dll")] internal static extern IntPtr MonitorFromWindow(IntPtr window, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] internal static extern bool GetMonitorInfo(IntPtr monitor, ref MonitorInfo info);
    [StructLayout(LayoutKind.Sequential)] internal struct BitmapInfo
    {
        public uint Size; public int Width, Height; public ushort Planes, BitCount;
        public uint Compression, ImageSize; public int XPels, YPels; public uint Used, Important;
    }
    [DllImport("user32.dll")] internal static extern bool GetCursorPos(out Point point);
    [DllImport("user32.dll")] internal static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] internal static extern IntPtr GetDC(IntPtr hwnd);
    [DllImport("user32.dll")] internal static extern int ReleaseDC(IntPtr hwnd, IntPtr dc);
    [DllImport("user32.dll")] internal static extern int GetSystemMetrics(int index);
    [DllImport("gdi32.dll")] internal static extern IntPtr CreateCompatibleDC(IntPtr dc);
    [DllImport("gdi32.dll")] internal static extern IntPtr CreateCompatibleBitmap(IntPtr dc, int width, int height);
    [DllImport("gdi32.dll")] internal static extern IntPtr SelectObject(IntPtr dc, IntPtr obj);
    [DllImport("gdi32.dll")] internal static extern bool BitBlt(IntPtr dest, int x, int y, int w, int h, IntPtr src, int sx, int sy, uint rop);
    [DllImport("gdi32.dll")] internal static extern int GetDIBits(IntPtr dc, IntPtr bitmap, uint start, uint lines, byte[] bits, ref BitmapInfo info, uint usage);
    [DllImport("gdi32.dll")] internal static extern bool DeleteObject(IntPtr obj);
    [DllImport("gdi32.dll")] internal static extern bool DeleteDC(IntPtr dc);
    [DllImport("user32.dll", SetLastError = true)] internal static extern bool RegisterHotKey(IntPtr hwnd, int id, uint modifiers, uint key);
    [DllImport("user32.dll")] internal static extern bool UnregisterHotKey(IntPtr hwnd, int id);
    [DllImport("dwmapi.dll")] internal static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
}
