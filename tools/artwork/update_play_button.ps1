Add-Type -AssemblyName System.Drawing

$srcPath = "C:\Users\Qusai\Downloads\New folder (7)\5.png"
$destSidebarPath = "d:\millionchallengeonline\ChallengeLand\assets\home\sidebar\play.png"
$destHomePath = "d:\millionchallengeonline\ChallengeLand\assets\home\play.png"

$src = New-Object System.Drawing.Bitmap($srcPath)
$rect = New-Object System.Drawing.Rectangle(4, 5, 489, 179)
$cropped = $src.Clone($rect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

# Save cropped PNG for sidebar
$cropped.Save($destSidebarPath, [System.Drawing.Imaging.ImageFormat]::Png)

# Also save to assets/home/play.png
$cropped.Save($destHomePath, [System.Drawing.Imaging.ImageFormat]::Png)

$cropped.Dispose()
$src.Dispose()

$srcHash = (Get-FileHash -Path $srcPath -Algorithm SHA256).Hash.ToLower()
$destSidebarHash = (Get-FileHash -Path $destSidebarPath -Algorithm SHA256).Hash.ToLower()
$destHomeHash = (Get-FileHash -Path $destHomePath -Algorithm SHA256).Hash.ToLower()

Write-Host "Source SHA-256:        $srcHash"
Write-Host "Sidebar Play SHA-256:  $destSidebarHash"
Write-Host "Home Play SHA-256:     $destHomeHash"
