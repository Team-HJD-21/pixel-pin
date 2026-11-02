using System.IO;

namespace PixelPin;

public static class LocalDataFiles
{
    // Write an empty current file before removing legacy data so it cannot be reimported.
    // Only the two known history files are touched; clipboard contents are deliberately unchanged.
    public static bool ClearHistory(string currentPath, string legacyPath)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(currentPath)!);
            File.WriteAllText(currentPath + ".tmp", "[]");
            File.Move(currentPath + ".tmp", currentPath, true);
            File.Delete(legacyPath);
            return true;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException) { return false; }
    }
}
