using System.Globalization;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Windows.Media;

namespace PixelPin;

public enum ThemeMode { System, Light, Dark }
public enum UiLanguage { Korean, English, Chinese }
public enum ColorFormat { Hex, Rgb, Hsl, Hsv, Cmyk }
public sealed record AppSettings
{
    public ThemeMode Theme { get; init; } = ThemeMode.System;
    public UiLanguage Language { get; init; } = UiLanguage.Korean;
    public ColorFormat Format { get; init; } = ColorFormat.Hex;
    public bool MiniMode { get; init; }
}

public static class SettingsStore
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true, Converters = { new JsonStringEnumConverter() } };
    private static readonly string FilePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PixelPin", "settings.json");
    public static AppSettings Current { get; private set; } = new();
    public static event Action? Changed;
    public static bool Reset() => Update(new AppSettings());
    public static void Load()
    {
        try
        {
            var value = File.Exists(FilePath) ? JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(FilePath), JsonOptions) : null;
            if (value is not null && Enum.IsDefined(value.Theme) && Enum.IsDefined(value.Language) && Enum.IsDefined(value.Format)) Current = value;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or JsonException) { }
    }
    public static bool Update(AppSettings settings)
    {
        if (!Enum.IsDefined(settings.Theme) || !Enum.IsDefined(settings.Language) || !Enum.IsDefined(settings.Format)) return false;
        Current = settings;
        Localization.Apply(); ThemeManager.Apply(); Changed?.Invoke();
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
            File.WriteAllText(FilePath + ".tmp", JsonSerializer.Serialize(Current, JsonOptions));
            File.Move(FilePath + ".tmp", FilePath, true);
            return true;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException) { return false; }
    }
}

public static class ColorFormatting
{
    public static string Hex(Color color) => $"#{color.R:X2}{color.G:X2}{color.B:X2}";
    public static string Format(Color color, ColorFormat format)
    {
        if (format == ColorFormat.Hex) return Hex(color);
        if (format == ColorFormat.Rgb) return $"rgb({color.R}, {color.G}, {color.B})";
        double r = color.R / 255d, g = color.G / 255d, b = color.B / 255d;
        double max = Math.Max(r, Math.Max(g, b)), min = Math.Min(r, Math.Min(g, b)), delta = max - min;
        static string Number(double value) => Math.Round(value, 1).ToString("0.#", CultureInfo.InvariantCulture);
        if (format == ColorFormat.Cmyk)
        {
            // Unprofiled reference conversion, not a press/ICC color separation.
            double c = max == 0 ? 0 : (max - r) / max;
            double m = max == 0 ? 0 : (max - g) / max;
            double y = max == 0 ? 0 : (max - b) / max;
            return $"cmyk({Number(c * 100)}%, {Number(m * 100)}%, {Number(y * 100)}%, {Number((1 - max) * 100)}%)";
        }
        double h = delta == 0 ? 0 : max == r ? 60 * (((g - b) / delta) % 6) : max == g ? 60 * ((b - r) / delta + 2) : 60 * ((r - g) / delta + 4);
        if (h < 0) h += 360;
        h = Math.Round(h, 1) % 360;
        double lightness = (max + min) / 2;
        double saturation = format == ColorFormat.Hsv ? (max == 0 ? 0 : delta / max) : (delta == 0 ? 0 : delta / (1 - Math.Abs(2 * lightness - 1)));
        return $"{(format == ColorFormat.Hsv ? "hsv" : "hsl")}({Number(h)}, {Number(saturation * 100)}%, {Number((format == ColorFormat.Hsv ? max : lightness) * 100)}%)";
    }
    public static Brush TextBrush(Color color)
    {
        static double Linear(byte c) { double v = c / 255d; return v <= .04045 ? v / 12.92 : Math.Pow((v + .055) / 1.055, 2.4); }
        double luminance = .2126 * Linear(color.R) + .7152 * Linear(color.G) + .0722 * Linear(color.B);
        return luminance > .179 ? Brushes.Black : Brushes.White;
    }
}
