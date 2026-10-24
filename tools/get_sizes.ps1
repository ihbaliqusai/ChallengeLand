$assetsSize = (Get-ChildItem -Path "assets" -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
$resSize = (Get-ChildItem -Path "android\app\src\main\res" -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB

Write-Host "========================================="
Write-Host ("Total Assets Folder: {0:N2} MB" -f $assetsSize)
Write-Host ("Total Android Res Folder: {0:N2} MB" -f $resSize)
Write-Host "========================================="

Write-Host "`n--- Assets breakdown by directory ---"
Get-ChildItem -Path "assets" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $dirSize = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host ("  {0,-20} : {1,8:N2} MB" -f $_.Name, $dirSize)
}

Write-Host "`n--- Android Res breakdown ---"
Get-ChildItem -Path "android\app\src\main\res" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $dirSize = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host ("  {0,-20} : {1,8:N2} MB" -f $_.Name, $dirSize)
}

Write-Host "`n--- Assets breakdown by File Extension ---"
Get-ChildItem -Path "assets", "android\app\src\main\res" -Recurse -File -ErrorAction SilentlyContinue | Group-Object Extension | ForEach-Object {
    $extSize = ($_.Group | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host ("  {0,-10} ({1,4} files) : {2,8:N2} MB" -f $_.Name, $_.Count, $extSize)
}

Write-Host "`n--- Checking APK / AAB builds ---"
$builds = Get-ChildItem -Path "android", "build", "." -Include *.apk, *.aab -File -Recurse -ErrorAction SilentlyContinue
if ($builds) {
    foreach ($b in $builds) {
        Write-Host ("  {0,-35} : {1,8:N2} MB" -f $b.Name, ($b.Length / 1MB))
    }
} else {
    Write-Host "  No APK / AAB files found."
}
