$ffmpeg = "C:\Program Files (x86)\CoolerMaster\MasterPlus\ffmpeg.exe"
$in = "android\app\src\main\res\raw\video_ellen.mp4"

Write-Host "Running video compression benchmarks..."

# Test 1: CRF 28, same resolution 720x1280, audio 64k
& $ffmpeg -y -i $in -c:v libx264 -crf 28 -preset slow -c:a aac -b:a 64k -movflags +faststart test_crf28.mp4 2>$null
$s1 = (Get-Item test_crf28.mp4).Length / 1MB

# Test 2: CRF 26, scaled to 540x960, audio 64k
& $ffmpeg -y -i $in -vf "scale=540:960" -c:v libx264 -crf 26 -preset slow -c:a aac -b:a 64k -movflags +faststart test_540p.mp4 2>$null
$s2 = (Get-Item test_540p.mp4).Length / 1MB

# Test 3: CRF 28, scaled to 540x960, audio 64k
& $ffmpeg -y -i $in -vf "scale=540:960" -c:v libx264 -crf 28 -preset slow -c:a aac -b:a 64k -movflags +faststart test_540p_crf28.mp4 2>$null
$s3 = (Get-Item test_540p_crf28.mp4).Length / 1MB

# Test 4: CRF 30, scaled to 480x854, audio 48k
& $ffmpeg -y -i $in -vf "scale=480:854" -c:v libx264 -crf 30 -preset slow -c:a aac -b:a 48k -movflags +faststart test_480p.mp4 2>$null
$s4 = (Get-Item test_480p.mp4).Length / 1MB

$s0 = (Get-Item $in).Length / 1MB

Write-Host ("Original: {0:N2} MB" -f $s0)
Write-Host ("Test 1 (720p CRF 28) : {0:N2} MB (وفر {1:N0}%)" -f $s1, ((1 - $s1/$s0)*100))
Write-Host ("Test 2 (540p CRF 26) : {0:N2} MB (وفر {1:N0}%)" -f $s2, ((1 - $s2/$s0)*100))
Write-Host ("Test 3 (540p CRF 28) : {0:N2} MB (وفر {1:N0}%)" -f $s3, ((1 - $s3/$s0)*100))
Write-Host ("Test 4 (480p CRF 30) : {0:N2} MB (وفر {1:N0}%)" -f $s4, ((1 - $s4/$s0)*100))

Remove-Item test_crf28.mp4, test_540p.mp4, test_540p_crf28.mp4, test_480p.mp4 -ErrorAction SilentlyContinue
