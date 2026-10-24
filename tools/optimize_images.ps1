Add-Type -AssemblyName System.Drawing

function Resize-ImagePng([string]$srcPath, [int]$maxSize) {
    if (-not (Test-Path $srcPath)) { return }
    $src = [System.Drawing.Image]::FromFile($srcPath)
    $w = $src.Width
    $h = $src.Height
    if ($w -le $maxSize -and $h -le $maxSize) {
        $src.Dispose()
        return
    }
    $ratio = [Math]::Min($maxSize / $w, $maxSize / $h)
    $newW = [int]($w * $ratio)
    $newH = [int]($h * $ratio)
    
    $bmp = New-Object System.Drawing.Bitmap($newW, $newH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.DrawImage($src, 0, 0, $newW, $newH)
    
    $src.Dispose()
    $g.Dispose()
    
    $tmpPath = $srcPath + '.tmp.png'
    $bmp.Save($tmpPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    
    Move-Item -Path $tmpPath -Destination $srcPath -Force
    $len = (Get-Item $srcPath).Length
    Write-Host "Resized $srcPath to ${newW}x${newH}, new size: $len bytes"
}

Write-Host "Starting PNG optimization..."
Resize-ImagePng "D:\millionchallengeonline\ChallengeLand\assets\ui\logo.png" 512
Resize-ImagePng "D:\millionchallengeonline\ChallengeLand\assets\icon\foreground.png" 512
Resize-ImagePng "D:\millionchallengeonline\ChallengeLand\assets\icon\icon.png" 512
Resize-ImagePng "D:\millionchallengeonline\ChallengeLand\assets\Logo.png" 512
Resize-ImagePng "D:\millionchallengeonline\ChallengeLand\assets\ui\bg_main.png" 1280
Resize-ImagePng "D:\millionchallengeonline\ChallengeLand\android\app\src\main\res\drawable\game_contestant_green.png" 720
Write-Host "PNG optimization complete."
