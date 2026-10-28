Add-Type -AssemblyName System.Drawing

$src = "C:\Users\Qusai\Downloads\New folder (5)\1.png"
$destPng = "d:\millionchallengeonline\ChallengeLand\assets\home\lobby_background.png"
$destJfif = "d:\millionchallengeonline\ChallengeLand\assets\home\lobby_background.jfif"

# Copy original PNG directly
Copy-Item -Path $src -Destination $destPng -Force
$pngInfo = Get-Item $destPng
Write-Host "PNG copied: $($pngInfo.FullName) ($($pngInfo.Length) bytes)"

# Convert to high-quality JFIF (JPEG quality 95)
$img = [System.Drawing.Image]::FromFile($src)
$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.FormatDescription -eq "JPEG" }
$encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]95)
$img.Save($destJfif, $jpegCodec, $encoderParams)
$img.Dispose()

$jfifInfo = Get-Item $destJfif
Write-Host "JFIF generated: $($jfifInfo.FullName) ($($jfifInfo.Length) bytes)"
