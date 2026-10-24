Add-Type -AssemblyName System.Drawing

$path = "D:\millionchallengeonline\ChallengeLand\assets\ui\bg_main.png"
$img = [System.Drawing.Image]::FromFile($path)
Write-Host "bg_main.png dimensions: $($img.Width)x$($img.Height)"
$w = $img.Width
$h = $img.Height
if ($w -gt 1280 -or $h -gt 720) {
    $ratio = [Math]::Min(1280.0 / $w, 720.0 / $h)
    $newW = [int]($w * $ratio)
    $newH = [int]($h * $ratio)
    $bmp = New-Object System.Drawing.Bitmap($newW, $newH, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($img, 0, 0, $newW, $newH)
    $img.Dispose()
    $g.Dispose()
    $tmp = $path + ".tmp.png"
    $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Move-Item -Path $tmp -Destination $path -Force
    Write-Host "Resized to ${newW}x${newH}, new size: $((Get-Item $path).Length)"
} else {
    $img.Dispose()
}
