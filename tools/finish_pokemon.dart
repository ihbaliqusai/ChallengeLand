import 'dart:convert';
import 'dart:io';

void main() {
  final files = [
    File('assets/questions_pokemon_300.json'),
    File('assets/questions.json'),
  ];

  for (final file in files) {
    var text = file.readAsStringSync();

    // 1. Catch 'Em All
    text = text.replaceAll("Gotta Catch 'Em All!", "Catch 'Em All");
    text = text.replaceAll("Gotta Catch 'Em All", "Catch 'Em All");

    // 2. Jigglypuff
    text = text.replaceAll("ترسم على وجوههم باللون الأسود بقلمها الميكروفون", "ترسم على وجوههم");

    // 3. Red and Blue
    text = text.replaceAll("Pokémon Red and Blue", "Red and Blue");
    text = text.replaceAll("Pokémon Gold and Silver", "Gold and Silver");
    text = text.replaceAll("Pokémon Diamond and Pearl", "Diamond and Pearl");
    text = text.replaceAll("Pokémon Ruby and Sapphire", "Ruby and Sapphire");

    // 4. Great ball
    text = text.replaceAll("أصفر مع خطوط سوداء", "أصفر بخطوط سوداء");

    // 5. Indigo League
    text = text.replaceAll("دوري إنديغو في كانتو", "دوري إنديغو");

    // 6. Red & Green
    text = text.replaceAll("بوكيت مونسترز: ريد وغرين", "ريد وغرين باليابان");

    // 7. Adamant
    text = text.replaceAll("زيادة الهجوم الجسدي بنسبة 10% وإنقاص الهجوم الخاص بنسبة 10%", "زيادة الهجوم الجسدي");
    text = text.replaceAll("زيادة الهجوم الخاص وإنقاص الدفاع", "زيادة الهجوم الخاص");
    text = text.replaceAll("زيادة السرعة وإنقاص الدفاع الخاص", "زيادة السرعة القصوى");
    text = text.replaceAll("زيادة الدفاع الخاص وإنقاص الهجوم", "زيادة الدفاع الخاص");

    // 8. Flame body
    text = text.replaceAll("جسم اللهب أو درع الحمم", "جسم اللهب");

    file.writeAsStringSync(text);
  }

  print('Finished final 8 Pokemon questions!');
}
