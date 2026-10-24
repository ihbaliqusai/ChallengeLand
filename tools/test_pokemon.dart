import 'dart:io';

void main() {
  print('Step 1: start');
  final maskFile = File('assets/categories/لاعبين كرة قدم.png');
  print('Step 2: maskFile exists = ${maskFile.existsSync()}');
  final srcFile = File(r'C:\Users\Admin\.gemini\antigravity-ide\brain\175d552f-2849-4699-9df4-84a8864665db\edge_pokemon_raw.png');
  print('Step 3: srcFile exists = ${srcFile.existsSync()}');
}
