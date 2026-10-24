import 'dart:io';

void main() {
  final psScript = '''
Add-Type -AssemblyName System.Drawing

\$files = @(
    "assets\\categories\\رياضة.png",
    "assets\\categories\\لاعبين كرة قدم.png",
    "assets\\categories\\مسيرة لاعب.png"
)

foreach (\$f in \$files) {
    \$path = Join-Path (Get-Location) \$f
    if (Test-Path \$path) {
        \$bmp = New-Object System.Drawing.Bitmap(\$path)
        Write-Host "File: \$f"
        Write-Host "  Size: \$(\$bmp.Width) x \$(\$bmp.Height)"
        
        # Sample top background color (x=176, y=50)
        \$cBg = \$bmp.GetPixel(176, 50)
        Write-Host "  Top BG Color: R=\$(\$cBg.R), G=\$(\$cBg.G), B=\$(\$cBg.B), Hex=#(\$cBg.R.ToString('X2'))(\$cBg.G.ToString('X2'))(\$cBg.B.ToString('X2'))"
        
        # Sample bottom bar color (x=176, y=320)
        \$cBar = \$bmp.GetPixel(176, 320)
        Write-Host "  Bottom Bar Color: R=\$(\$cBar.R), G=\$(\$cBar.G), B=\$(\$cBar.B), Hex=#(\$cBar.R.ToString('X2'))(\$cBar.G.ToString('X2'))(\$cBar.B.ToString('X2'))"
        
        # Find bottom bar top Y:
        for (\$y = 200; \$y -lt \$bmp.Height; \$y++) {
            \$p = \$bmp.GetPixel(176, \$y)
            if (\$p.R -eq \$cBar.R -and \$p.G -eq \$cBar.G -and \$p.B -eq \$cBar.B) {
                Write-Host "  Bottom Bar starts at Y: \$y"
                break
            }
        }
        
        \$bmp.Dispose()
    }
}
''';

  final psFile = File('tools/inspect_cards.ps1');
  psFile.writeAsStringSync(psScript);
  final res = Process.runSync('powershell', ['-ExecutionPolicy', 'Bypass', '-File', psFile.path]);
  print(res.stdout);
  print(res.stderr);
  if (psFile.existsSync()) psFile.deleteSync();
}
