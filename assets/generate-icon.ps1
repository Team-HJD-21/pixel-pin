$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$canvas = [System.Drawing.Bitmap]::new(1024, 1024)
$drawing = [System.Drawing.Graphics]::FromImage($canvas)
$drawing.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$drawing.ScaleTransform(4, 4)

function New-Brush([string] $hex) { [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($hex)) }
function Fill-Rectangle([string] $hex, [single] $x, [single] $y, [single] $w, [single] $h) {
    $brush = New-Brush $hex
    try { $drawing.FillRectangle($brush, $x, $y, $w, $h) } finally { $brush.Dispose() }
}

$tile = [System.Drawing.Drawing2D.GraphicsPath]::new()
$tile.AddArc(8, 8, 108, 108, 180, 90)
$tile.AddArc(140, 8, 108, 108, 270, 90)
$tile.AddArc(140, 140, 108, 108, 0, 90)
$tile.AddArc(8, 140, 108, 108, 90, 90)
$tile.CloseFigure()
$navy = New-Brush '#202B40'
$drawing.FillPath($navy, $tile)
$navy.Dispose()
$tile.Dispose()

$lens = [System.Drawing.Drawing2D.GraphicsPath]::new()
$lens.AddEllipse(51, 51, 118, 118)
$saved = $drawing.Save()
$drawing.SetClip($lens)
Fill-Rectangle '#80ACFF' 45 45 65 65
Fill-Rectangle '#BCA4F5' 110 45 65 65
Fill-Rectangle '#6DD4B0' 45 110 65 65
Fill-Rectangle '#FFBE8B' 110 110 65 65
$grid = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#202B40'), 5)
$drawing.DrawLine($grid, 110, 45, 110, 175)
$drawing.DrawLine($grid, 45, 110, 175, 110)
$grid.Dispose()
$drawing.Restore($saved)
$lens.Dispose()

$handle = [System.Drawing.Pen]::new([System.Drawing.Color]::White, 21)
$handle.StartCap = $handle.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$drawing.DrawLine($handle, 156, 156, 201, 201)
$handle.Dispose()
$ring = [System.Drawing.Pen]::new([System.Drawing.Color]::White, 11)
$drawing.DrawEllipse($ring, 46, 46, 128, 128)
$ring.Dispose()
$drawing.Dispose()

$sizes = @(16, 20, 24, 32, 40, 48, 64, 128, 256)
$frames = @()
foreach ($size in $sizes) {
    $image = [System.Drawing.Bitmap]::new($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($image)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.DrawImage($canvas, 0, 0, $size, $size)
    $graphics.Dispose()
    $stream = [System.IO.MemoryStream]::new()
    $image.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $frames += ,$stream.ToArray()
    if ($size -eq 256) { $image.Save((Join-Path $PSScriptRoot 'app-icon.png'), [System.Drawing.Imaging.ImageFormat]::Png) }
    $stream.Dispose()
    $image.Dispose()
}
$canvas.Dispose()
$file = [System.IO.File]::Create((Join-Path $PSScriptRoot 'app.ico'))
$writer = [System.IO.BinaryWriter]::new($file)
try {
    $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$sizes.Count)
    $offset = 6 + 16 * $sizes.Count
    for ($index = 0; $index -lt $sizes.Count; $index++) {
        $dimension = if ($sizes[$index] -eq 256) { 0 } else { $sizes[$index] }
        $writer.Write([byte]$dimension); $writer.Write([byte]$dimension)
        $writer.Write([byte]0); $writer.Write([byte]0)
        $writer.Write([uint16]1); $writer.Write([uint16]32)
        $writer.Write([uint32]$frames[$index].Length); $writer.Write([uint32]$offset)
        $offset += $frames[$index].Length
    }
    foreach ($frame in $frames) { $writer.Write([byte[]]$frame) }
} finally { $writer.Dispose(); $file.Dispose() }
Write-Output 'Generated app.ico with 9 sizes (16–256 px), app-icon.png'
