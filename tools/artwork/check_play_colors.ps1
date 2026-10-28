Add-Type -AssemblyName System.Drawing

$src = "C:\Users\Qusai\Downloads\New folder (7)\5.png"
$bmp = New-Object System.Drawing.Bitmap($src)
$w = $bmp.Width
$h = $bmp.Height

$minX = $w
$minY = $h
$maxX = 0
$maxY = 0

$sampleColors = @()

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

# Sample 5 pixels near center and borders
$pCenter = $bmp.GetPixel([int]($w/2), [int]($h/2))
$pGoldOrGreen = $bmp.GetPixel($minX + 20, $minY + 20)
Write-Host "Center pixel: R=$($pCenter.R), G=$($pCenter.G), B=$($pCenter.B), A=$($pCenter.A)"
Write-Host "Border pixel: R=$($pGoldOrGreen.R), G=$($pGoldOrGreen.G), B=$($pGoldOrGreen.B), A=$($pGoldOrGreen.A)"

$bmp.Dispose()
