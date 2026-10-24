import 'dart:convert';
import 'dart:io';

void main() {
  final name = 'باب الحارة';
  final b64 = base64Encode(utf8.encode(name));
  print('Base64 for $name: $b64');

  final srcPath = r'C:\Users\Admin\.gemini\antigravity-ide\brain\175d552f-2849-4699-9df4-84a8864665db\bab_alhara_category_art_1792838085095.jpg';

  final psScript = '''
Add-Type -AssemblyName System.Drawing
\$catNameBytes = [System.Convert]::FromBase64String('$b64')
\$catName = [System.Text.Encoding]::UTF8.GetString(\$catNameBytes)
\$srcPath = '$srcPath'
\$destPath1 = Join-Path (Get-Location) "assets\\categories\\\$catName.png"
\$destPath2 = Join-Path (Get-Location) "android\\app\\src\\main\\assets\\categories\\\$catName.png"

\$srcImg = [System.Drawing.Image]::FromFile(\$srcPath)
Write-Host "Source dimensions: \$(\$srcImg.Width)x\$(\$srcImg.Height)"

\$targetWidth = 352
\$targetHeight = 352
\$bmp = New-Object System.Drawing.Bitmap(\$targetWidth, \$targetHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
\$g = [System.Drawing.Graphics]::FromImage(\$bmp)
\$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
\$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
\$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
\$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
\$g.DrawImage(\$srcImg, 0, 0, \$targetWidth, \$targetHeight)
\$g.Dispose()
\$srcImg.Dispose()

\$bmp.Save(\$destPath1, [System.Drawing.Imaging.ImageFormat]::Png)
\$bmp.Save(\$destPath2, [System.Drawing.Imaging.ImageFormat]::Png)
\$bmp.Dispose()
Write-Host "Saved PNG successfully to: \$destPath1 and \$destPath2"
''';

  final psFile = File('tools/convert_bab_alhara_image_b64.ps1');
  psFile.writeAsStringSync(psScript, encoding: utf8);
  print('Generated tools/convert_bab_alhara_image_b64.ps1');

  final result = Process.runSync('powershell', ['-ExecutionPolicy', 'Bypass', '-File', psFile.path]);
  print('PowerShell output:');
  print(result.stdout);
  print(result.stderr);

  final f1 = File('assets/categories/$name.png');
  final f2 = File('android/app/src/main/assets/categories/$name.png');
  print('File 1 exists: ${f1.existsSync()} (${f1.existsSync() ? f1.lengthSync() : 0} bytes)');
  print('File 2 exists: ${f2.existsSync()} (${f2.existsSync() ? f2.lengthSync() : 0} bytes)');

  if (psFile.existsSync()) psFile.deleteSync();
}
