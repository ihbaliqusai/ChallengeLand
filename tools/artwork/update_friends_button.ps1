Add-Type -AssemblyName System.Drawing

$srcPath = "C:\Users\Qusai\Downloads\New folder (7)\6.png"
$destPath = "d:\millionchallengeonline\ChallengeLand\assets\home\sidebar\friends.png"

$src = New-Object System.Drawing.Bitmap($srcPath)
$rect = New-Object System.Drawing.Rectangle(12, 11, 481, 99)
$cropped = $src.Clone($rect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

# Save cropped PNG
$cropped.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)

$cropped.Dispose()
$src.Dispose()

$srcHash = (Get-FileHash -Path $srcPath -Algorithm SHA256).Hash.ToLower()
$destHash = (Get-FileHash -Path $destPath -Algorithm SHA256).Hash.ToLower()
$destSize = (Get-Item $destPath).Length

Write-Host "Source SHA-256: $srcHash"
Write-Host "Dest SHA-256:   $destHash ($destSize bytes)"
