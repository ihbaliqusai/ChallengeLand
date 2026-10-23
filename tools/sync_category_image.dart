import 'dart:io';

void main() {
  final src = File('assets/categories/لاعبين كرة قدم.png');
  final dest = File('android/app/src/main/assets/categories/لاعبين كرة قدم.png');
  src.copySync(dest.path);
  print('Copied to: ${dest.path}');
}
