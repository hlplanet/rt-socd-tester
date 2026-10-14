# Draws the keycap icon at several sizes and writes them into one .ico file (PNG-compressed entries).
param([string]$Out = (Join-Path $PSScriptRoot '..\src\app.ico'))
Add-Type -AssemblyName System.Drawing

function RoundedRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

function Draw-Icon([int]$size) {
    $s = [float]$size
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.Clear([System.Drawing.Color]::Transparent)
    $bg = RoundedRect 0 0 ($s - 1) ($s - 1) ($s * 0.22)
    $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 15, 18, 24))), $bg)
    $m = $s * 0.16
    $base = RoundedRect $m ($m + $s * 0.06) ($s - 2 * $m) ($s - 2 * $m) ($s * 0.14)
    $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 0, 140, 100))), $base)
    $topRect = New-Object System.Drawing.RectangleF $m, $m, ($s - 2 * $m), ($s - 2 * $m - $s * 0.06)
    $top = RoundedRect $topRect.X $topRect.Y $topRect.Width $topRect.Height ($s * 0.13)
    $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush $topRect, ([System.Drawing.Color]::FromArgb(255, 0, 196, 255)), ([System.Drawing.Color]::FromArgb(255, 0, 255, 170)), 45
    $g.FillPath($grad, $top)
    if ($size -ge 32) {
        $font = New-Object System.Drawing.Font 'Segoe UI', ($s * 0.26), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
        $fmt = New-Object System.Drawing.StringFormat
        $fmt.Alignment = 'Center'
        $fmt.LineAlignment = 'Center'
        $g.DrawString('RT', $font, (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 4, 19, 14))), $topRect, $fmt)
    }
    $g.Dispose()
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    return , $ms.ToArray()
}

$sizes = 16, 24, 32, 48, 64, 128, 256
$images = foreach ($s in $sizes) { , (Draw-Icon $s) }

$ico = New-Object System.IO.MemoryStream
$w = New-Object System.IO.BinaryWriter -ArgumentList $ico
$w.Write([UInt16]0); $w.Write([UInt16]1); $w.Write([UInt16]$sizes.Count)   # ICONDIR
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {                                  # ICONDIRENTRY per size
    $s = $sizes[$i]
    $dim = if ($s -ge 256) { 0 } else { $s }                               # 0 means 256
    $w.Write([byte]$dim); $w.Write([byte]$dim); $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([UInt16]1); $w.Write([UInt16]32)
    $w.Write([UInt32]$images[$i].Length); $w.Write([UInt32]$offset)
    $offset += $images[$i].Length
}
foreach ($img in $images) { $w.Write($img) }
$w.Flush()
$target = [System.IO.Path]::GetFullPath($Out)
[System.IO.File]::WriteAllBytes($target, $ico.ToArray())
Write-Host "Wrote $target ($($ico.Length) bytes, sizes: $($sizes -join ', '))"
