import 'dart:convert';
import 'dart:io';

void main() {
  print('--- Applying V2 Category Artworks Matching the Original Design System ---');

  final items = [
    {
      'name': 'دوري أبطال أوروبا',
      'src': r'C:\Users\Admin\.gemini\antigravity-ide\brain\175d552f-2849-4699-9df4-84a8864665db\ucl_category_v2_1792839614311.jpg',
    },
    {
      'name': 'NBA',
      'src': r'C:\Users\Admin\.gemini\antigravity-ide\brain\175d552f-2849-4699-9df4-84a8864665db\nba_category_v2_1792839641970.jpg',
    },
    {
      'name': 'بنات وبس',
      'src': r'C:\Users\Admin\.gemini\antigravity-ide\brain\175d552f-2849-4699-9df4-84a8864665db\girls_category_v2_1792839707514.jpg',
    },
    {
      'name': 'باب الحارة',
      'src': r'C:\Users\Admin\.gemini\antigravity-ide\brain\175d552f-2849-4699-9df4-84a8864665db\bab_alhara_v2_1792839736396.jpg',
    },
    {
      'name': 'مسلسلات تركية',
      'src': r'C:\Users\Admin\.gemini\antigravity-ide\brain\175d552f-2849-4699-9df4-84a8864665db\turkish_series_v2_1792839766604.jpg',
    },
  ];

  for (int i = 0; i < items.length; i++) {
    final name = items[i]['name']!;
    final src = items[i]['src']!;
    final b64 = base64Encode(utf8.encode(name));

    final script = '''
Add-Type -AssemblyName System.Drawing
\$catNameBytes = [System.Convert]::FromBase64String('$b64')
\$catName = [System.Text.Encoding]::UTF8.GetString(\$catNameBytes)
\$srcPath = '$src'
\$destPath1 = Join-Path (Get-Location) "assets\\categories\\\$catName.png"
\$destPath2 = Join-Path (Get-Location) "android\\app\\src\\main\\assets\\categories\\\$catName.png"

\$srcImg = [System.Drawing.Image]::FromFile(\$srcPath)
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
Write-Host "Item $i saved successfully."
''';

    final psFile = File('tools/apply_single_$i.ps1');
    psFile.writeAsStringSync(script, encoding: utf8);

    final res = Process.runSync('powershell', ['-ExecutionPolicy', 'Bypass', '-File', psFile.path]);
    if (res.exitCode != 0 || res.stderr.toString().isNotEmpty) {
      print('Error on $name: ${res.stderr}');
    } else {
      print('Converted $name successfully: ${res.stdout.toString().trim()}');
    }

    if (psFile.existsSync()) psFile.deleteSync();
  }

  // Verification
  print('\n--- Verification of Overwritten Categories ---');
  for (final item in items) {
    final name = item['name']!;
    final f1 = File('assets/categories/$name.png');
    final f2 = File('android/app/src/main/assets/categories/$name.png');
    print('$name:');
    print('  Flutter asset: ${f1.existsSync()} (${f1.existsSync() ? f1.lengthSync() : 0} bytes)');
    print('  Android asset: ${f2.existsSync()} (${f2.existsSync() ? f2.lengthSync() : 0} bytes)');
    if (!f1.existsSync() || !f2.existsSync()) {
      throw Exception('Missing file for $name');
    }
  }

  print('\n>>> ALL 5 CATEGORY ARTWORKS CONVERTED AND APPLIED! <<<');
}
