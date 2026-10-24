import 'dart:io';

void main() {
  final brainDir = r'C:\Users\Admin\.gemini\antigravity-ide\brain\175d552f-2849-4699-9df4-84a8864665db';

  final mapping = {
    'دوري أبطال أوروبا': 'ucl_transparent.png',
    'NBA': 'nba_transparent.png',
    'بنات وبس': 'girls_transparent.png',
    'باب الحارة': 'bab_alhara_transparent.png',
    'مسلسلات تركية': 'turkish_series_transparent.png',
  };

  for (final entry in mapping.entries) {
    final src = File('assets/categories/${entry.key}.png');
    final dest = File('$brainDir\\${entry.value}');
    dest.writeAsBytesSync(src.readAsBytesSync());
    print('Copied ${entry.key} -> ${dest.path} (${dest.lengthSync()} bytes)');
  }
}
