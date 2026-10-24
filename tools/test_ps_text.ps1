Add-Type -AssemblyName System.Drawing

$fontPath = Join-Path (Get-Location) "assets\fonts\baloo.ttf"
$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$pfc.AddFontFile($fontPath)
$fontFamily = $pfc.Families[0]
$font = New-Object System.Drawing.Font($fontFamily, 28, [System.Drawing.FontStyle]::Bold)

$bmp = New-Object System.Drawing.Bitmap(352, 352, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::FromArgb(26, 90, 89)) # teal background

$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Center
$sf.LineAlignment = [System.Drawing.StringAlignment]::Center
$sf.FormatFlags = [System.Drawing.StringFormatFlags]::DirectionRightToLeft

$rect = New-Object System.Drawing.RectangleF(0, 0, 352, 352)
$g.DrawString("دراما سورية", $font, $brush, $rect, $sf)

$g.Dispose()
$bmp.Save("tools/test_ps_arabic.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "Saved tools/test_ps_arabic.png"
