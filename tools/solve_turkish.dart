import 'dart:convert';
import 'dart:io';

int countWords(String s) {
  var t = s.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).length;
}

String cleanSimple(String s) {
  var t = s.trim();
  t = t.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
  t = t.replaceAll(RegExp(r'\s*/\s*.*$'), '');
  t = t.replaceAll('"', '').replaceAll('«', '').replaceAll('»', '');
  return t.trim();
}

void main() {
  final turkishFile = File('assets/questions_turkish_series_300.json');
  final mainFile = File('assets/questions.json');

  final List<dynamic> turkishList = jsonDecode(turkishFile.readAsStringSync());
  final List<dynamic> mainList = jsonDecode(mainFile.readAsStringSync());

  for (var q in turkishList) {
    q['R'] = cleanSimple(q['R'] ?? '');
    q['W1'] = cleanSimple(q['W1'] ?? '');
    q['W2'] = cleanSimple(q['W2'] ?? '');
    q['W3'] = cleanSimple(q['W3'] ?? '');

    final qText = (q['Q'] ?? '').toString();

    if (qText.contains('جيهانغير المفجعة')) {
      q['R'] = 'حزناً على مصطفى';
      q['W1'] = 'طعنه بسهم طائش';
      q['W2'] = 'غرق سفينته بالدردنيل';
      q['W3'] = 'سقوطه من الشرفة';
    }
    if (qText.contains('هرب إليها الأمير بيازيد')) {
      q['R'] = 'الدولة الصفوية';
      q['W1'] = 'إمبراطورية النمسا';
      q['W2'] = 'مملكة فرنسا';
      q['W3'] = 'دوقية البندقية';
    }
    if (qText.contains('النهاية الفاجعة للأمير بيازيد')) {
      q['R'] = 'إعدامهم خنقاً بالوتر';
      q['W1'] = 'حرقهم بقصر الشاه';
      q['W2'] = 'نفيهم إلى القوقاز';
      q['W3'] = 'تسميمهم على المائدة';
    }
    if (qText.contains('المشرف التاريخي والمدقق الذي رافق كتابة مسلسل حريم السلطان')) {
      q['Q'] = 'من الجهة الأكاديمية التي شاركت بالتدقيق التاريخي لمسلسل حريم السلطان؟';
      q['R'] = 'مؤرخو جامعات إسطنبول';
      q['W1'] = 'معهد الفنون بباريس';
      q['W2'] = 'قسم الآثار ببرلين';
      q['W3'] = 'وزارة الثقافة النمساوية';
    }
    if (qText.contains('أخفى بها الصدر الأعظم سوكولو موت السلطان سليمان')) {
      q['R'] = 'تحنيط جثمانه بعربته';
      q['W1'] = 'إعلان أنه مريض';
      q['W2'] = 'إرسال شبيه له';
      q['W3'] = 'دفنه سراً بالغابة';
    }
    if (qText.contains('مدير أعمال وكاتب أجزاء وادي الذئاب')) {
      q['R'] = 'راجي وبهادير';
      q['W1'] = 'تيمور وعمر';
      q['W2'] = 'كرم وعثمان';
      q['W3'] = 'أولوتش وسيردار';
    }
    if (qText.contains('ظهر كضيف شرف في الحلقة الأخيرة من الجزء الثاني لوادي الذئاب')) {
      q['R'] = 'غارسيا وشارون ستون';
      q['W1'] = 'باتشينو وميريل ستريب';
      q['W2'] = 'دي نيرو وأنجلينا';
      q['W3'] = 'كيج وسلمى حايك';
    }
    if (qText.contains('طبيب الشرير في فيلم وادي الذئاب العراق')) {
      q['Q'] = 'من الممثل الأمريكي الذي لعب دور الطبيب الشرير في فيلم وادي الذئاب العراق؟';
      q['R'] = 'غاري بوسي';
      q['W1'] = 'مورغان فريمان';
      q['W2'] = 'توم هانكس';
      q['W3'] = 'بروس ويليس';
    }
    if (qText.contains('سليمان شاكر في جلسة كبار المافيا بمجلس الذئاب')) {
      q['R'] = 'مسدسه وخنجره';
      q['W1'] = 'سيفه الذهبي';
      q['W2'] = 'عكازته الفضية';
      q['W3'] = 'مسبحته العاجية';
    }
    if (qText.contains('الشارع التركي عند مقتل شخصية سليمان شاكر')) {
      q['Q'] = 'ماذا فعل الجمهور بالشارع التركي عند مقتل شخصية سليمان شاكر؟';
      q['R'] = 'أقاموا صلاة الغائب';
      q['W1'] = 'إضراب عمال النقل';
      q['W2'] = 'مظاهرات أمام البرلمان';
      q['W3'] = 'إغلاق القنوات التلفزيونية';
    }
    if (qText.contains('قطاع الطرق لن يحكموا العالم')) {
      q['R'] = 'قطاع الطرق';
    }
    if (qText.contains('خاتم البارون محمد قره خانلي')) {
      q['Q'] = 'ما السر في خاتم البارون محمد قره خانلي في وادي الذئاب؟';
      q['R'] = 'ختم فرسان الهيكل';
      q['W1'] = 'مفتاح خزنة سويسرا';
      q['W2'] = 'كبسولة سم قاتل';
      q['W3'] = 'إحداثيات مستودع أسلحة';
    }
    if (qText.contains('أغنية Mihriban')) {
      q['R'] = 'أغنية Mihriban';
    }
    if (qText.contains('مسلسل القضاء (Yargı)')) {
      q['Q'] = 'من صاحبة السيناريو الأصلي لمسلسل القضاء Yargı؟';
      q['R'] = 'سيما إرجينيكون';
      q['W1'] = 'أجاثا كريستي';
      q['W2'] = 'ميراي دانر';
      q['W3'] = 'إيجه يورينتش';
    }
    if (qText.contains('كوخ البحيرة ليعبر عن حبه الأبدي لها')) {
      q['Q'] = 'ما الهدية التذكارية التي تركها مهند لنور في كوخ البحيرة؟';
      q['R'] = 'مجسم خشبي بحرفيهما';
      q['W1'] = 'مفتاح قصر البوسفور';
      q['W2'] = 'تذكرة سفر لإيطاليا';
      q['W3'] = 'ساعة جيب ذهبية';
    }
    if (qText.contains('السيارة الكلاسيكية الفاخرة التي كان يقودها إيزيل')) {
      q['R'] = 'مازيراتي ومايباخ';
      q['W1'] = 'فورد موستانغ';
      q['W2'] = 'بي إم دبليو';
      q['W3'] = 'فولكس فاجن بيتل';
    }
    if (qText.contains('الخال رامز عن القدر والخيانة')) {
      q['Q'] = 'من صاحب المقولة الفلسفية الشهيرة: "إن كل إنسان يقتل ما يحب"؟';
      q['R'] = 'الخال رامز';
      q['W1'] = 'كنان بيركان';
      q['W2'] = 'علي القرش';
      q['W3'] = 'إيزيل بيرقدار';
    }
  }

  // Ensure all options <= 3 words:
  for (var q in turkishList) {
    for (final key in ['R', 'W1', 'W2', 'W3']) {
      var s = q[key].toString().trim();
      if (countWords(s) > 3) {
        final words = s.split(RegExp(r'\s+'));
        q[key] = words.sublist(0, 3).join(' ');
      }
    }
  }

  turkishFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(turkishList));

  // Sync to main
  int tIdx = 0;
  for (int i = 0; i < mainList.length; i++) {
    if (mainList[i]['Category'] == 'مسلسلات تركية') {
      if (tIdx < turkishList.length) mainList[i] = turkishList[tIdx++];
    }
  }

  mainFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(mainList));
  print('Turkish series updated and synced!');
}
