import 'dart:io';

void main() {
  for (final path in ['assets/questions_pokemon_300.json', 'assets/questions.json']) {
    final file = File(path);
    var text = file.readAsStringSync();
    text = text.replaceAll('ترش الماء البارد عليهم', 'ترش الماء عليهم');
    file.writeAsStringSync(text);
  }
  print('Fixed jigglypuff!');
}
