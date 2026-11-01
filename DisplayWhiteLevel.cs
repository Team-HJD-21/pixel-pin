using System.Runtime.InteropServices;
namespace PixelPin;

internal static class DisplayWhiteLevel
{
    // SDRWhiteLevel is expressed in units of 80/1000 nits. scRGB 1.0 is 80 nits.
    internal static float ReadScale(string deviceName)
    {
        if (GetDisplayConfigBufferSizes(2, out uint pathCount, out uint modeCount) != 0) return 1;
        var paths = new PathInfo[pathCount];
        IntPtr modes = Marshal.AllocHGlobal(checked((int)modeCount * 64));
        try
        {
            if (QueryDisplayConfig(2, ref pathCount, paths, ref modeCount, modes, IntPtr.Zero) != 0) return 1;
            foreach (var path in paths.Take((int)pathCount))
            {
                var name = new SourceName { Header = new Header { Type = 1, Size = (uint)Marshal.SizeOf<SourceName>(), Adapter = path.Source.Adapter, Id = path.Source.Id }, DeviceName = "" };
                if (GetSourceName(ref name) != 0 || !string.Equals(name.DeviceName, deviceName, StringComparison.OrdinalIgnoreCase)) continue;
                var white = new WhiteLevel { Header = new Header { Type = 11, Size = (uint)Marshal.SizeOf<WhiteLevel>(), Adapter = path.Target.Adapter, Id = path.Target.Id } };
                if (GetWhiteLevel(ref white) == 0 && white.Level >= 1000) return white.Level / 1000f;
            }
            return 1;
        }
        finally { Marshal.FreeHGlobal(modes); }
    }
    [StructLayout(LayoutKind.Sequential)] private struct Luid { public uint Low; public int High; }
    [StructLayout(LayoutKind.Sequential)] private struct Header { public uint Type, Size; public Luid Adapter; public uint Id; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] private struct SourceName { public Header Header; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName; }
    [StructLayout(LayoutKind.Sequential)] private struct WhiteLevel { public Header Header; public uint Level; }
    [StructLayout(LayoutKind.Sequential)] private struct SourceInfo { public Luid Adapter; public uint Id, ModeIndex, Status; }
    [StructLayout(LayoutKind.Sequential)] private struct TargetInfo { public Luid Adapter; public uint Id, ModeIndex, Technology, Rotation, Scaling, RefreshNumerator, RefreshDenominator, Scanline; public int Available; public uint Status; }
    [StructLayout(LayoutKind.Sequential)] private struct PathInfo { public SourceInfo Source; public TargetInfo Target; public uint Flags; }
    [DllImport("user32.dll")] private static extern int GetDisplayConfigBufferSizes(uint flags, out uint pathCount, out uint modeCount);
    [DllImport("user32.dll")] private static extern int QueryDisplayConfig(uint flags, ref uint pathCount, [Out] PathInfo[] paths, ref uint modeCount, IntPtr modes, IntPtr topology);
    [DllImport("user32.dll", EntryPoint = "DisplayConfigGetDeviceInfo")] private static extern int GetSourceName(ref SourceName info);
    [DllImport("user32.dll", EntryPoint = "DisplayConfigGetDeviceInfo")] private static extern int GetWhiteLevel(ref WhiteLevel info);
}
