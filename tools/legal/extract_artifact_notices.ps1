$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$noticeRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$noticeInventory = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'runtime-license-inventory.local.json') | ConvertFrom-Json
$noticeRecords = [Collections.Generic.List[object]]::new()
function Read-NoticeZip([IO.Compression.ZipArchive]$archive, [string]$prefix, $module) {
    foreach ($entry in $archive.Entries) {
        if ($entry.FullName -match '(?i)(^|/)([^/]*licen[cs]e[^/]*|[^/]*notice[^/]*|[^/]*copyright[^/]*|pom\.xml)$' -and $entry.FullName -notmatch '\.class$' -and $entry.Length -lt 20000000 -and $entry.Length -gt 0) {
            $bodyStream = [IO.MemoryStream]::new()
            $entryStream = $entry.Open()
            try { $entryStream.CopyTo($bodyStream) } finally { $entryStream.Dispose() }
            $bytes = $bodyStream.ToArray()
            $bodyStream.Dispose()
            $body = [Text.Encoding]::UTF8.GetString($bytes)
            $noticeRecords.Add([pscustomobject]@{
                module = ($module.group + ':' + $module.name + ':' + $module.version)
                entry = ($prefix + $entry.FullName)
                text = $body
                base64 = [Convert]::ToBase64String($bytes)
            })
        }
        if ($entry.FullName -eq 'classes.jar') {
            $memory = [IO.MemoryStream]::new()
            $inputStream = $entry.Open()
            try { $inputStream.CopyTo($memory) } finally { $inputStream.Dispose() }
            $memory.Position = 0
            $nested = [IO.Compression.ZipArchive]::new($memory,[IO.Compression.ZipArchiveMode]::Read)
            try { Read-NoticeZip $nested ($prefix + 'classes.jar!/') $module }
            finally { $nested.Dispose(); $memory.Dispose() }
        }
    }
}
foreach ($module in $noticeInventory.artifacts) {
    $archive = [IO.Compression.ZipFile]::OpenRead($module.file)
    try { Read-NoticeZip $archive '' $module } finally { $archive.Dispose() }
}
$noticeRecords.ToArray() | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 (Join-Path $PSScriptRoot 'artifact-notices.local.json')
Write-Output ('Extracted ' + $noticeRecords.Count + ' embedded license/NOTICE/POM records.')
