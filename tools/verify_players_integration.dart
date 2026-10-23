import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('assets/questions.json');
  if (!file.existsSync()) {
    print('Error: assets/questions.json does not exist');
    exit(1);
  }
  
  final content = file.readAsStringSync();
  final List<dynamic> questions = jsonDecode(content);
  print('Total questions in questions.json: ${questions.length}');
  
  final Set<String> allCats = {};
  for (var i = 15420; i < questions.length; i++) {
    allCats.add(questions[i]['category'].toString());
  }
  print('Categories in last items: $allCats');
  if (questions.isNotEmpty) {
    print('Sample last item: ${questions.last}');
  }
  
  final playerQuestions = questions.where((q) => q['Category'].toString().trim() == 'لاعبين كرة قدم').toList();
  print('Matching questions under "لاعبين كرة قدم": ${playerQuestions.length}');
  
  final Map<String, int> levelCounts = {};
  final Set<String> questionTexts = {};
  int duplicateQuestions = 0;
  int missingFields = 0;
  int invalidOptions = 0;
  int levelNotString = 0;
  
  for (final q in playerQuestions) {
    if (q['Level'] is! String) {
      levelNotString++;
    }
    final level = q['Level'].toString();
    levelCounts[level] = (levelCounts[level] ?? 0) + 1;
    
    final qText = (q['Q'] ?? '').toString().trim();
    if (questionTexts.contains(qText)) {
      duplicateQuestions++;
    }
    questionTexts.add(qText);
    
    final r = q['R']?.toString().trim();
    final w1 = q['W1']?.toString().trim();
    final w2 = q['W2']?.toString().trim();
    final w3 = q['W3']?.toString().trim();
    if (r == null || w1 == null || w2 == null || w3 == null || qText.isEmpty) {
      missingFields++;
    }
    final opts = {r, w1, w2, w3};
    if (opts.length != 4) {
      invalidOptions++;
    }
  }
  
  print('Level breakdown: $levelCounts');
  print('Duplicate questions: $duplicateQuestions');
  print('Missing fields: $missingFields');
  print('Invalid options (or duplicate answers): $invalidOptions');
  print('Level not string: $levelNotString');
  
  
  final imgPath1 = File('assets/categories/لاعبين كرة قدم.png');
  final imgPath2 = File('android/app/src/main/assets/categories/لاعبين كرة قدم.png');
  print('Flutter category image exists: ${imgPath1.existsSync()} (${imgPath1.lengthSync()} bytes)');
  print('Android category image exists: ${imgPath2.existsSync()} (${imgPath2.lengthSync()} bytes)');
}
