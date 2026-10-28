Add-Type -AssemblyName System.Drawing

$src = "C:\Users\Qusai\Downloads\New folder (7)\6.png"
$bmp = New-Object System.Drawing.Bitmap($src)
$w = $bmp.Width
$h = $bmp.Height

$minX = $w
$minY = $h
$maxX = 0
$maxY = 0

for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
        $pixel = $bmp.GetPixel($x, $y)
        if ($pixel.A -gt 0) {
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}

$cropW = $maxX - $minX + 1
$cropH = $maxY - $minY + 1

Write-Host "Source dimensions: ${w}x${h}"
Write-Host "Alpha bounding box: minX=$minX, minY=$minY, maxX=$maxX, maxY=$maxY"
Write-Host "Crop: $minX, $minY, $cropW, $cropH"

$bmp.Dispose()
