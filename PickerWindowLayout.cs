using System.Windows;

namespace PixelPin;

public static class PickerWindowLayout
{
    public static Size MiniSize => new(340, 184);

    // Keep the existing top-left corner when possible, including negative-coordinate monitors.
    public static Rect Fit(Rect requested, Rect workArea)
    {
        double width = Math.Min(requested.Width, workArea.Width);
        double height = Math.Min(requested.Height, workArea.Height);
        return new Rect(Math.Clamp(requested.X, workArea.Left, workArea.Right - width),
            Math.Clamp(requested.Y, workArea.Top, workArea.Bottom - height), width, height);
    }
}
