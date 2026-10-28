Add-Type -AssemblyName System.Drawing

$srcPath = "C:\Users\Qusai\Downloads\New folder (7)\5.png"
$existingPath = "d:\millionchallengeonline\ChallengeLand\assets\home\sidebar\play.png"
$testCropPath = "d:\millionchallengeonline\ChallengeLand\scratch\play_cropped_test.png"

$src = New-Object System.Drawing.Bitmap($srcPath)
$rect = New-Object System.Drawing.Rectangle(4, 5, 489, 179)
$cropped = $src.Clone($rect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$cropped.Save($testCropPath, [System.Drawing.Imaging.ImageFormat]::Png)

$cropped.Dispose()
$src.Dispose()

$hashExisting = (Get-FileHash -Path $existingPath -Algorithm SHA256).Hash.ToLower()
$hashTest = (Get-FileHash -Path $testCropPath -Algorithm SHA256).Hash.ToLower()

Write-Host "Existing play.png hash:  $hashExisting"
Write-Host "Test cropped hash:       $hashTest"
Write-Host "Are they identical bytes? $( $hashExisting -eq $hashTest )"
