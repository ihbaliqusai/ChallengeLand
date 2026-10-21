Add-Type -AssemblyName System.Drawing

$srcPath = "assets/icon/icon.png"
$radius512 = 76

# Load source square bitmap
$src = [System.Drawing.Bitmap]::FromFile($srcPath)
$w = $src.Width
$h = $src.Height

# Create 512x512 rounded icon
$dest512 = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($dest512)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.Clear([System.Drawing.Color]::Transparent)

$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$d = $radius512 * 2
$path.AddArc(0, 0, $d, $d, 180, 90)
$path.AddArc($w - $d, 0, $d, $d, 270, 90)
$path.AddArc($w - $d, $h - $d, $d, $d, 0, 90)
$path.AddArc(0, $h - $d, $d, $d, 90, 90)
$path.CloseFigure()

$g.SetClip($path)
$g.DrawImage($src, 0, 0, $w, $h)

$g.Dispose()
$src.Dispose()
$path.Dispose()

# Save rounded 512x512 to assets/icon/icon.png
$tempPath = "assets/icon/icon_rounded_tmp.png"
$dest512.Save($tempPath, [System.Drawing.Imaging.ImageFormat]::Png)
Move-Item -Force $tempPath $srcPath
Write-Output "Updated assets/icon/icon.png with rounded corners (radius=$radius512)"

# Mipmap sizes
$mipmaps = @{
    "mipmap-mdpi"    = 48
    "mipmap-hdpi"    = 72
    "mipmap-xhdpi"   = 96
    "mipmap-xxhdpi"  = 144
    "mipmap-xxxhdpi" = 192
}

foreach ($entry in $mipmaps.GetEnumerator()) {
    $folder = $entry.Key
    $size = $entry.Value
    $targetDir = "android/app/src/main/res/$folder"
    if (!(Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    $targetFile = "$targetDir/ic_launcher.png"

    $scaled = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $sg = [System.Drawing.Graphics]::FromImage($scaled)
    $sg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $sg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $sg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $sg.Clear([System.Drawing.Color]::Transparent)
    $sg.DrawImage($dest512, 0, 0, $size, $size)
    $sg.Dispose()

    $scaled.Save($targetFile, [System.Drawing.Imaging.ImageFormat]::Png)
    $scaled.Dispose()
    Write-Output "Generated $targetFile ($size x $size)"
}

$dest512.Dispose()
Write-Output "All icons successfully generated."
