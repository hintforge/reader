# markup.ps1 -- circle and label spots on a screenshot for the Hintforge reader (Windows only).
#
# Usage:
#   pwsh -NoProfile -File markup.ps1 -In <png> -Out <png> -Mark "x,y,radius,label|x,y,radius,label" [-Color "#FFD400"]
#
# -Mark   One or more spots separated by "|": pixel x and y of the centre, circle radius in
#         pixels, and the label text (may be empty). The label may contain commas; everything after
#         the third comma is the label. When the guide defines a map grid, put the grid cell in the
#         label ("Cache -- C4").
# -Color  Circle, line and label-border colour, as a name or #RRGGBB. Default: #FFD400 (yellow).
#
# Each mark draws a circle, a label box beside it and a leader line between them. The label sits
# up and to the right of the circle and flips to the other side near an image edge. Uses only the
# .NET drawing library that ships with Windows; nothing to install.
#
# Exit codes: 0 ok (prints the output path), 2 bad arguments or unreadable input.
param(
    [Parameter(Mandatory = $true)][string]$In,
    [Parameter(Mandatory = $true)][string]$Out,
    [Parameter(Mandatory = $true)][string]$Mark,
    [string]$Color = '#FFD400'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $In)) { Write-Output "Input image not found: $In"; exit 2 }
try { $col = [System.Drawing.ColorTranslator]::FromHtml($Color) } catch { Write-Output "Not a colour: $Color"; exit 2 }

$marks = foreach ($m in ($Mark.Split('|') | Where-Object { $_.Trim() })) {
    $p = $m.Split(',', 4)
    if ($p.Count -lt 4) { Write-Output "A mark needs x,y,radius,label: $m"; exit 2 }
    $nx = 0; $ny = 0; $nr = 0
    if (-not ([int]::TryParse($p[0].Trim(), [ref]$nx) -and [int]::TryParse($p[1].Trim(), [ref]$ny) -and [int]::TryParse($p[2].Trim(), [ref]$nr)) -or $nr -le 0) {
        Write-Output "x, y and radius must be whole numbers (radius above 0): $m"; exit 2
    }
    [pscustomobject]@{ X = $nx; Y = $ny; R = $nr; Label = $p[3].Trim() }
}

# Load through a copy so the input file is not locked and may equal -Out.
$src = [System.Drawing.Image]::FromFile((Resolve-Path $In).Path)
$bmp = New-Object System.Drawing.Bitmap $src.Width, $src.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.DrawImage($src, 0, 0, $src.Width, $src.Height)
$src.Dispose()
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias

$scale = [Math]::Max(1.0, [Math]::Min($bmp.Width, $bmp.Height) / 720.0)
$pen = New-Object System.Drawing.Pen $col, ([float](3 * $scale))
$shadow = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(160, 0, 0, 0)), ([float](6 * $scale))
$font = New-Object System.Drawing.Font 'Segoe UI', ([float](14 * $scale)), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$boxBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(215, 0, 0, 0))
$textBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
$pad = [float](6 * $scale)
$gap = [float](28 * $scale)

foreach ($m in $marks) {
    $g.DrawEllipse($shadow, [float]($m.X - $m.R), [float]($m.Y - $m.R), [float](2 * $m.R), [float](2 * $m.R))
    $g.DrawEllipse($pen, [float]($m.X - $m.R), [float]($m.Y - $m.R), [float](2 * $m.R), [float](2 * $m.R))
    if (-not $m.Label) { continue }
    $size = $g.MeasureString($m.Label, $font)
    $bw = $size.Width + 2 * $pad; $bh = $size.Height + 2 * $pad
    $dx = 0.7071 * $m.R; $dy = 0.7071 * $m.R
    $right = ($m.X + $dx + $gap + $bw) -le $bmp.Width
    $up = ($m.Y - $dy - $gap - $bh) -ge 0
    $sx = if ($right) { $m.X + $dx } else { $m.X - $dx }
    $sy = if ($up) { $m.Y - $dy } else { $m.Y + $dy }
    $bx = if ($right) { $sx + $gap } else { $sx - $gap - $bw }
    $by = if ($up) { $sy - $gap - $bh } else { $sy + $gap }
    $bx = [Math]::Max(0, [Math]::Min($bx, $bmp.Width - $bw)); $by = [Math]::Max(0, [Math]::Min($by, $bmp.Height - $bh))
    $ex = if ($right) { $bx } else { $bx + $bw }
    $ey = if ($up) { $by + $bh } else { $by }
    $g.DrawLine($shadow, [float]$sx, [float]$sy, [float]$ex, [float]$ey)
    $g.DrawLine($pen, [float]$sx, [float]$sy, [float]$ex, [float]$ey)
    $g.FillRectangle($boxBrush, [float]$bx, [float]$by, [float]$bw, [float]$bh)
    $g.DrawRectangle($pen, [float]$bx, [float]$by, [float]$bw, [float]$bh)
    $g.DrawString($m.Label, $font, $textBrush, [float]($bx + $pad), [float]($by + $pad))
}

$g.Dispose(); $pen.Dispose(); $shadow.Dispose(); $font.Dispose(); $boxBrush.Dispose(); $textBrush.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output $Out
exit 0
