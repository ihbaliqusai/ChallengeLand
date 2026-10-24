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
  final hpFile = File('assets/questions_harry_potter_300.json');
  final mainFile = File('assets/questions.json');

  final List<dynamic> hpList = jsonDecode(hpFile.readAsStringSync());
  final List<dynamic> mainList = jsonDecode(mainFile.readAsStringSync());

  for (var q in hpList) {
    q['R'] = cleanSimple(q['R'] ?? '');
    q['W1'] = cleanSimple(q['W1'] ?? '');
    q['W2'] = cleanSimple(q['W2'] ?? '');
    q['W3'] = cleanSimple(q['W3'] ?? '');

    final qText = (q['Q'] ?? '').toString();

    if (qText.contains('طعن هاري بوتر مذكرات توم ريدل')) {
      q['R'] = 'بناب الباسيليسك المسموم';
      q['W1'] = 'بسيف جريفندور';
      q['W2'] = 'بنار الوايلد فاير';
      q['W3'] = 'بتعويذة أفادا كدافرا';
    }
    if (qText.contains('حرر هاري بوتر الجني المنزلي دوبي')) {
      q['Q'] = 'كيف حرر هاري بوتر الجني المنزلي دوبي من عائلة مالفوي؟';
      q['R'] = 'بإهدائه جورباً قذراً';
      q['W1'] = 'بدفع مائة جاليون';
      q['W2'] = 'بتعويذة تحرير الأقزام';
      q['W3'] = 'بقرار من دمبلدور';
    }
    if (qText.contains('تحولت هيرميون جرانجر عن طريق الخطأ')) {
      q['Q'] = 'إلى ماذا تحولت هيرميون بالخطأ بعد شرب جرعة البوليجوس بسبب شعر قطة؟';
      q['R'] = 'مخلوقة نصف قطة';
      q['W1'] = 'ضفدعة صغيرة';
      q['W2'] = 'كلب صيد صغير';
      q['W3'] = 'بومة بنية';
    }
    if (qText.contains('غيلدروي لوكهارت ببراعة ومحا بها ذكريات')) {
      q['R'] = 'تعويذة أوبليفايات';
      q['W1'] = 'تعويذة أكيو';
      q['W2'] = 'تعويذة إنسومنيا';
      q['W3'] = 'تعويذة ريديولوس';
    }
    if (qText.contains('دموع طائر الفينيق')) {
      q['Q'] = 'ما الخاصية الطبية الخارقة لدموع طائر الفينيق في عالم السحر؟';
      q['R'] = 'شفاء الجروح والسموم';
      q['W1'] = 'إعادة الموتى للحياة';
      q['W2'] = 'منح القدرة للطيران';
      q['W3'] = 'تحويل الماء لإكسير';
    }
    if (qText.contains('التنين النرويجي الصغير')) {
      q['R'] = 'التنين النرويجي نوربرت';
      q['W1'] = 'التنين السويدي';
      q['W2'] = 'التنين الصيني';
      q['W3'] = 'التنين الويلزي';
    }
    if (qText.contains('عصير الماندريك')) {
      q['Q'] = 'ما فائدة استخدام عصير الماندريك في السنة الثانية لهاري بوتر؟';
      q['R'] = 'علاج الطلاب المتحجرين';
      q['W1'] = 'صنع جرعة البوليجوس';
      q['W2'] = 'تدمير أنياب الباسيليسك';
      q['W3'] = 'إيقاظ طائر الفينيق';
    }
    if (qText.contains('الشطرنج الساحر')) {
      q['R'] = 'شطرنج السحرة العملاق';
    }
    if (qText.contains('قبلة الديمنتور')) {
      q['Q'] = 'ما هي عقوبة قبلة الديمنتور الأكثر رعباً في عالم السحر؟';
      q['R'] = 'امتصاص روح الضحية';
      q['W1'] = 'تجميد دم الضحية';
      q['W2'] = 'محو ذكريات الضحية';
      q['W3'] = 'تحويل الجسد لهيكل';
    }
    if (qText.contains('البوجارت عندما واجهه هاري بوتر')) {
      q['R'] = 'كائن ديمنتور عائم';
      q['W1'] = 'لورد فولدمورت بكامل قوته';
      q['W2'] = 'ثعبان باسيليسك عملاق';
      q['W3'] = 'جثة والديه بالتابوت';
    }
    if (qText.contains('سيريوس بلاك (Padfoot) التحول إليه')) {
      q['R'] = 'كلب أسود ضخم';
      q['W1'] = 'ذئب رمادي بري';
      q['W2'] = 'غراب أسود عملاق';
      q['W3'] = 'غزال جبلي سريع';
    }
    if (qText.contains('خريطة اللصوص في هوجورتس')) {
      q['Q'] = 'أي من هؤلاء لم يكن من الأصدقاء الأربعة صناع خريطة اللصوص؟';
      q['R'] = 'سنيب';
      q['W1'] = 'موني';
      q['W2'] = 'وورمتيل';
      q['W3'] = 'بادفوت';
    }
    if (qText.contains('طائر الهيبوجريف')) {
      q['Q'] = 'ما القاعدة الأساسية التي علمها هاجريد للتعامل مع طائر الهيبوجريف؟';
      q['R'] = 'الانحناء والتواصل البصري';
      q['W1'] = 'إطعامه لحماً نيئاً';
      q['W2'] = 'التربيت على منقاره';
      q['W3'] = 'الاقتراب من خلفه';
    }
    if (qText.contains('بطولة السحرة في الجزء الرابع')) {
      q['Q'] = 'أي من هؤلاء لم يكن من أبطال بطولة السحرة الثلاثية في الجزء الرابع؟';
      q['R'] = 'دراكو مالفوي';
      q['W1'] = 'هاري بوتر';
      q['W2'] = 'سيدريك ديجوري';
      q['W3'] = 'فيكتور كرام';
    }
    if (qText.contains('التنين المجري ذو الذيل القرني')) {
      q['R'] = 'التنين المجري القرني';
    }
    if (qText.contains('التعاويذ الثلاث التي لا تُغتفر')) {
      q['Q'] = 'أي من هذه التعاويذ ليست من التعاويذ الثلاث التي لا تُغتفر؟';
      q['R'] = 'إكسبليارموس';
      q['W1'] = 'أفادا كدافرا';
      q['W2'] = 'كروشيانتوس';
      q['W3'] = 'إمبريو';
    }
  }

  // General pass to trim any options > 3 words:
  for (var q in hpList) {
    for (final key in ['R', 'W1', 'W2', 'W3']) {
      var s = q[key].toString().trim();
      if (countWords(s) > 3) {
        final words = s.split(RegExp(r'\s+'));
        q[key] = words.sublist(0, 3).join(' ');
      }
    }
  }

  hpFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(hpList));

  // Sync to main
  int hpIdx = 0;
  for (int i = 0; i < mainList.length; i++) {
    if (mainList[i]['Category'] == 'Harry Potter') {
      if (hpIdx < hpList.length) mainList[i] = hpList[hpIdx++];
    }
  }

  mainFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(mainList));
  print('Harry Potter updated and synced!');
}
