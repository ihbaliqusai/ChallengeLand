Add-Type -AssemblyName System.Drawing

$srcPath = 'C:\Users\Admin\.gemini\antigravity-ide\brain\eb173c6d-e6c2-4bef-b9e9-46c6227a9a2d\football_players_category_1792696091951.jpg'
$catNameBytes = [System.Convert]::FromBase64String('2YTYp9i52KjZitmGINmD2LHYqSDZgtiv2YU=')
$catName = [System.Text.Encoding]::UTF8.GetString($catNameBytes)
$destPath = Join-Path (Get-Location) "assets\categories\$catName.png"

$srcImg = [System.Drawing.Image]::FromFile($srcPath)
Write-Host "Source dimensions: $($srcImg.Width)x$($srcImg.Height)"

$targetWidth = 352
$targetHeight = 352
$bmp = New-Object System.Drawing.Bitmap($targetWidth, $targetHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
$g.DrawImage($srcImg, 0, 0, $targetWidth, $targetHeight)
$g.Dispose()
$srcImg.Dispose()

$bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "Saved PNG successfully to: $destPath"
