using System.Runtime.InteropServices;
using System.Windows.Media;
using SharpGen.Runtime;
using Vortice.Direct3D;
using Vortice.Direct3D11;
using Vortice.DXGI;
using Vortice.Mathematics;
using Color = System.Windows.Media.Color;

namespace PixelPin;

internal sealed class DirectXSampler : IDisposable
{
    private ID3D11Device? device;
    private ID3D11DeviceContext? context;
    private IDXGIOutputDuplication? duplication;
    private ID3D11Texture2D? cached, staging;
    private OutputDescription output;
    private Format textureFormat;
    private int textureWidth, textureHeight;
    private bool hasFrame;
    private long retryAfter, whiteChecked;
    private float whiteScale = 1;
    internal bool IsHdr { get; private set; }
    internal string? LastError { get; private set; }
    internal byte[]? Capture(int x, int y)
    {
        try
        {
            var bounds = output.DesktopCoordinates;
            if (duplication is null || x < bounds.Left || x >= bounds.Right || y < bounds.Top || y >= bounds.Bottom)
            {
                if (Environment.TickCount64 < retryAfter) return null;
                Dispose();
                if (!Initialize(x, y)) { retryAfter = Environment.TickCount64 + 1500; return null; }
            }
            var result = duplication!.AcquireNextFrame(0, out _, out var resource);
            if (result.Success)
            {
                try
                {
                    using var frame = resource.QueryInterface<ID3D11Texture2D>();
                    var description = frame.Description;
                    if (cached is null)
                    {
                        textureFormat = description.Format;
                        if (textureFormat is not (Format.R16G16B16A16_Float or Format.B8G8R8A8_UNorm)) throw new InvalidOperationException("Unsupported desktop format");
                        textureWidth = (int)description.Width; textureHeight = (int)description.Height;
                        description.BindFlags = BindFlags.None; description.MiscFlags = ResourceOptionFlags.None; description.CPUAccessFlags = CpuAccessFlags.None; description.Usage = ResourceUsage.Default;
                        cached = device!.CreateTexture2D(description);
                        description.Width = ScreenSampler.Size; description.Height = ScreenSampler.Size; description.Usage = ResourceUsage.Staging; description.CPUAccessFlags = CpuAccessFlags.Read;
                        staging = device.CreateTexture2D(description);
                    }
                    context!.CopyResource(cached, frame); hasFrame = true;
                }
                finally { resource?.Dispose(); duplication.ReleaseFrame(); }
            }
            else if (result.Code != unchecked((int)0x887A0027)) result.CheckError(); // WAIT_TIMEOUT is normal for a still desktop.
            if (!hasFrame) return null;
            IsHdr = textureFormat == Format.R16G16B16A16_Float;
            if (IsHdr && Environment.TickCount64 - whiteChecked > 2000) { whiteScale = DisplayWhiteLevel.ReadScale(output.DeviceName); whiteChecked = Environment.TickCount64; }
            var center = ToTexture(x, y);
            int sx = Math.Max(0, center.X - 8), sy = Math.Max(0, center.Y - 8);
            int width = Math.Min(textureWidth - sx, 17), height = Math.Min(textureHeight - sy, 17);
            context!.CopySubresourceRegion(staging!, 0, 0, 0, 0, cached!, 0, new Box(sx, sy, 0, sx + width, sy + height, 1));
            context.Map(staging!, 0, MapMode.Read, Vortice.Direct3D11.MapFlags.None, out var mapped).CheckError();
            try
            {
                int bytesPerPixel = IsHdr ? 8 : 4;
                var raw = new byte[checked((int)mapped.RowPitch * height)]; Marshal.Copy(mapped.DataPointer, raw, 0, raw.Length);
                var pixels = new byte[17 * 17 * 4];
                for (int row = 0; row < 17; row++) for (int col = 0; col < 17; col++)
                {
                    int screenX = Math.Clamp(x - 8 + col, output.DesktopCoordinates.Left, output.DesktopCoordinates.Right - 1);
                    int screenY = Math.Clamp(y - 8 + row, output.DesktopCoordinates.Top, output.DesktopCoordinates.Bottom - 1);
                    var point = ToTexture(screenX, screenY);
                    int offset = Math.Clamp(point.Y - sy, 0, height - 1) * (int)mapped.RowPitch + Math.Clamp(point.X - sx, 0, width - 1) * bytesPerPixel;
                    int dest = (row * 17 + col) * 4;
                    if (!IsHdr) Buffer.BlockCopy(raw, offset, pixels, dest, 4);
                    else
                    {
                        Color color = ConvertScRgb((float)BitConverter.ToHalf(raw, offset), (float)BitConverter.ToHalf(raw, offset + 2), (float)BitConverter.ToHalf(raw, offset + 4), whiteScale);
                        pixels[dest] = color.B; pixels[dest + 1] = color.G; pixels[dest + 2] = color.R;
                    }
                }
                LastError = null; return pixels;
            }
            finally { context.Unmap(staging!, 0); }
        }
        catch (Exception ex) when (ex is SharpGenException or COMException or InvalidOperationException or ArgumentException)
        { LastError = ex.Message; Dispose(); retryAfter = Environment.TickCount64 + 1500; return null; }
    }
    private bool Initialize(int x, int y)
    {
        using var factory = DXGI.CreateDXGIFactory1<IDXGIFactory1>();
        for (uint ai = 0; factory.EnumAdapters1(ai, out var adapter).Success; ai++)
        {
            using (adapter)
            for (uint oi = 0; adapter.EnumOutputs(oi, out var monitor).Success; oi++)
            {
                using (monitor)
                {
                    var desc = monitor.Description; var rect = desc.DesktopCoordinates;
                    if (!desc.AttachedToDesktop || x < rect.Left || x >= rect.Right || y < rect.Top || y >= rect.Bottom) continue;
                    using var output5 = monitor.QueryInterfaceOrNull<IDXGIOutput5>();
                    D3D11.D3D11CreateDevice(adapter, DriverType.Unknown, DeviceCreationFlags.BgraSupport, [FeatureLevel.Level_11_0, FeatureLevel.Level_10_1, FeatureLevel.Level_10_0], out device, out context).CheckError();
                    try
                    {
                        if (output5 is not null) duplication = output5.DuplicateOutput1(device!, new[] { Format.R16G16B16A16_Float, Format.B8G8R8A8_UNorm });
                    }
                    catch (SharpGenException) { /* Older drivers can still support DuplicateOutput. */ }
                    if (duplication is null) { using var output1 = monitor.QueryInterface<IDXGIOutput1>(); duplication = output1.DuplicateOutput(device!); }
                    output = desc; return true;
                }
            }
        }
        return false;
    }
    private (int X, int Y) ToTexture(int x, int y)
    {
        int dx = x - output.DesktopCoordinates.Left, dy = y - output.DesktopCoordinates.Top;
        return output.Rotation switch
        {
            ModeRotation.Rotate90 => (dy, textureHeight - 1 - dx),
            ModeRotation.Rotate180 => (textureWidth - 1 - dx, textureHeight - 1 - dy),
            ModeRotation.Rotate270 => (textureWidth - 1 - dy, dx), _ => (dx, dy)
        };
    }
    internal static Color ConvertScRgb(float r, float g, float b, float scale)
    {
        scale = float.IsFinite(scale) && scale >= 1 ? scale : 1;
        r = float.IsFinite(r) ? Math.Max(0, r / scale) : 0;
        g = float.IsFinite(g) ? Math.Max(0, g / scale) : 0;
        b = float.IsFinite(b) ? Math.Max(0, b / scale) : 0;
        // Preserve normal SDR values; compress brighter HDR values into the SDR output range.
        float peak = Math.Max(1, Math.Max(r, Math.Max(g, b))); r /= peak; g /= peak; b /= peak;
        static byte Encode(float v) => (byte)Math.Clamp((int)Math.Round((v <= .0031308f ? 12.92f * v : 1.055f * Math.Pow(v, 1 / 2.4) - .055f) * 255), 0, 255);
        return Color.FromRgb(Encode(r), Encode(g), Encode(b));
    }
    public void Dispose()
    {
        staging?.Dispose(); cached?.Dispose(); duplication?.Dispose(); context?.Dispose(); device?.Dispose();
        staging = cached = null; duplication = null; context = null; device = null; hasFrame = false; IsHdr = false;
    }
}
