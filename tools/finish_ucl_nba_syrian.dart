import 'dart:convert';
import 'dart:io';

int countWords(String text) {
  final cleaned = text.trim();
  if (cleaned.isEmpty) return 0;
  return cleaned.split(RegExp(r'\s+')).length;
}

void main() {
  // Fix UCL
  final uclFile = File('assets/questions_ucl_300.json');
  var uclText = uclFile.readAsStringSync();
  uclText = uclText.replaceAll('بي إس في آيندهوفن', 'نادي آيندهوفن');
  uclText = uclText.replaceAll('بايرن ميونخ ومانشستر سيتي', 'بايرن ومانشستر سيتي');
  uclText = uclText.replaceAll('دوني فان دي بيك', 'فان دي بيك');
  uclText = uclText.replaceAll('سي إف آر كلوج', 'نادي كلوج');
  uclText = uclText.replaceAll('إدوين فان دير سار', 'فان دير سار');
  uclFile.writeAsStringSync(uclText);

  // Fix NBA
  final nbaFile = File('assets/questions_nba_300.json');
  var nbaText = nbaFile.readAsStringSync();
  nbaText = nbaText.replaceAll('بيك آند رول المزدوج', 'بيك آند رول');
  nbaText = nbaText.replaceAll('7 ثوانٍ أو أقل', 'سبع ثوانٍ فقط');
  nbaFile.writeAsStringSync(nbaText);

  // Fix Syrian drama
  final syrianFile = File('assets/questions_syrian_drama_300.json');
  var syrianText = syrianFile.readAsStringSync();
  syrianText = syrianText.replaceAll('هجرة القلوب إلى القلوب', 'هجرة القلوب');
  syrianText = syrianText.replaceAll('بطل من هذا الزمان', 'بطل هذا الزمان');
  syrianText = syrianText.replaceAll('بو مالحة وبو قعقور', 'بومالحة وبوققعور');
  syrianText = syrianText.replaceAll('بو نايف وبو راشد', 'بونايف وبوراشد');
  syrianText = syrianText.replaceAll('الموت القادم إلى الشرق', 'الموت القادم');
  syrianFile.writeAsStringSync(syrianText);

  // Check counts
  final uclList = jsonDecode(uclFile.readAsStringSync()) as List;
  final nbaList = jsonDecode(nbaFile.readAsStringSync()) as List;
  final syrianList = jsonDecode(syrianFile.readAsStringSync()) as List;

  int uclLong = 0, nbaLong = 0, syrianLong = 0;
  for (var q in uclList) {
    if ([countWords(q['R']), countWords(q['W1']), countWords(q['W2']), countWords(q['W3'])].reduce((a, b) => a > b ? a : b) > 3) uclLong++;
  }
  for (var q in nbaList) {
    if ([countWords(q['R']), countWords(q['W1']), countWords(q['W2']), countWords(q['W3'])].reduce((a, b) => a > b ? a : b) > 3) nbaLong++;
  }
  for (var q in syrianList) {
    if ([countWords(q['R']), countWords(q['W1']), countWords(q['W2']), countWords(q['W3'])].reduce((a, b) => a > b ? a : b) > 3) syrianLong++;
  }

  print('=== Final Check for 3 Categories ===');
  print('دوري أبطال أوروبا: $uclLong');
  print('NBA: $nbaLong');
  print('دراما سورية: $syrianLong');

  // Update in questions.json
  final mainFile = File('assets/questions.json');
  final mainList = jsonDecode(mainFile.readAsStringSync()) as List;

  for (int i = 0; i < mainList.length; i++) {
    final cat = mainList[i]['Category'];
    if (cat == 'دوري أبطال أوروبا') {
      final qText = mainList[i]['Q'];
      final m = uclList.firstWhere((x) => x['Q'] == qText, orElse: () => null);
      if (m != null) mainList[i] = m;
    } else if (cat == 'NBA') {
      final qText = mainList[i]['Q'];
      final m = nbaList.firstWhere((x) => x['Q'] == qText, orElse: () => null);
      if (m != null) mainList[i] = m;
    } else if (cat == 'دراما سورية') {
      final qText = mainList[i]['Q'];
      final m = syrianList.firstWhere((x) => x['Q'] == qText, orElse: () => null);
      if (m != null) mainList[i] = m;
    }
  }

  mainFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(mainList));
  print('main questions.json updated successfully!');
}
