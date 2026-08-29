Add-Type -AssemblyName System.Drawing

function Optimize-DrawablePng([string]$path, [int]$maxDimension) {
    if (-not (Test-Path $path)) { return }
    $src = $null
    try {
        $src = [System.Drawing.Image]::FromFile($path)
        $w = $src.Width
        $h = $src.Height
        if ($w -le $maxDimension -and $h -le $maxDimension) {
            $src.Dispose()
            return
        }
        $ratio = [Math]::Min([double]$maxDimension / $w, [double]$maxDimension / $h)
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
        $src = $null
        $g.Dispose()
        
        $tmp = $path + ".tmp.png"
        $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        
        Move-Item -Path $tmp -Destination $path -Force
        $newLen = (Get-Item $path).Length
        Write-Host "Optimized $path -> ${newW}x${newH} ($([Math]::Round($newLen / 1KB, 1)) KB)"
    } catch {
        Write-Host "Error optimizing $path : $_"
        if ($src -ne $null) { $src.Dispose() }
    }
}

Write-Host "Optimizing drawables..."

# Optimize contestant full-body drawables (max height 1080)
$contestants = Get-ChildItem -Path "D:\millionchallengeonline\ChallengeLand\android\app\src\main\res\drawable" -Filter "*contestant*.png"
foreach ($f in $contestants) {
    Optimize-DrawablePng $f.FullName 1080
}

# Optimize backgrounds (max 1280)
$bgs = Get-ChildItem -Path "D:\millionchallengeonline\ChallengeLand\android\app\src\main\res\drawable" -Filter "*bg*.png"
foreach ($f in $bgs) {
    Optimize-DrawablePng $f.FullName 1280
}

# Optimize podium, board
Optimize-DrawablePng "D:\millionchallengeonline\ChallengeLand\android\app\src\main\res\drawable\podium.png" 720
Optimize-DrawablePng "D:\millionchallengeonline\ChallengeLand\android\app\src\main\res\drawable\board.png" 720
Optimize-DrawablePng "D:\millionchallengeonline\ChallengeLand\android\app\src\main\res\drawable\board1.png" 720

# Optimize emotes (face avatars, max 300)
$emotes = Get-ChildItem -Path "D:\millionchallengeonline\ChallengeLand\android\app\src\main\res\drawable" -Filter "emote_*.png"
foreach ($f in $emotes) {
    Optimize-DrawablePng $f.FullName 300
}

# Optimize characters in assets/characters/ (max 300)
$charAssets = Get-ChildItem -Path "D:\millionchallengeonline\ChallengeLand\assets\characters" -Filter "*.png"
foreach ($f in $charAssets) {
    Optimize-DrawablePng $f.FullName 300
}

Write-Host "Drawables optimization complete."
