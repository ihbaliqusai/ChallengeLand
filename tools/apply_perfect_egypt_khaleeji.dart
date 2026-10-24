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
  final egyptFile = File('assets/questions_egyptian_drama_300.json');
  final khaleejiFile = File('assets/questions_khaleeji_drama_300.json');
  final mainFile = File('assets/questions.json');

  final List<dynamic> egyptList = jsonDecode(egyptFile.readAsStringSync());
  final List<dynamic> khaleejiList = jsonDecode(khaleejiFile.readAsStringSync());
  final List<dynamic> mainList = jsonDecode(mainFile.readAsStringSync());

  void fixEgypt(Map<String, dynamic> q) {
    q['R'] = cleanSimple(q['R'] ?? '');
    q['W1'] = cleanSimple(q['W1'] ?? '');
    q['W2'] = cleanSimple(q['W2'] ?? '');
    q['W3'] = cleanSimple(q['W3'] ?? '');

    final qText = (q['Q'] ?? '').toString();

    if (qText.contains('4 زوجات') || qText.contains('عائلة الحاج متولي')) {
      q['W1'] = 'جلباب أبي';
    }
    if (qText.contains('بكيزة وزغلول')) {
      q['Q'] = 'من لعبت دور بكيزة هانم الدرملي أمام إسعاد يونس في بكيزة وزغلول؟';
      q['R'] = 'سهير البابلي';
      q['W1'] = 'يسرا';
      q['W2'] = 'عبلة كامل';
      q['W3'] = 'ميرفت أمين';
    }
    if (qText.contains('جمعة الشوان')) {
      q['R'] = 'دموع بعيون وقحة';
      q['W3'] = 'السقوط ببئر سبع';
    }
    if (qText.contains('ريا وسكينة عام 2005')) {
      q['Q'] = 'من النجمة التي جسدت دور ريا أمام سمية الخشاب في مسلسل ريا وسكينة؟';
      q['R'] = 'عبلة كامل';
      q['W1'] = 'يسرا';
      q['W2'] = 'غادة عبدالرازق';
      q['W3'] = 'نادية الجندي';
    }
    if (qText.contains('أرابيسك')) {
      q['W2'] = 'جلال عبدالقوي';
    }
    if (qText.contains('بوابة الحلواني')) {
      q['W1'] = 'ليالي الحلمية';
    }
    if (qText.contains('تحت السيطرة عام 2015')) {
      q['R'] = 'علاج مرض الإدمان';
    }
    if (qText.contains('محرم بك بالإسكندرية') || qText.contains('أهو ده اللي صار')) {
      q['R'] = 'ليالي أوجيني';
      q['W1'] = 'جراند أوتيل';
      q['W2'] = 'حارة اليهود';
      q['W3'] = 'واحة الغروب';
      q['Q'] = 'ما اسم المسلسل الذي دارت أحداثه في فندق تاريخي ببورسعيد عام 2018 بطولة ظافر العابدين؟';
    }
    if (qText.contains('حارة اليهود') && qText.contains('التعايش بين الأديان')) {
      q['W1'] = 'فرقة ناجي عطاالله';
    }
    if (qText.contains('حارة اليهود بدور علي وليلى')) {
      q['Q'] = 'من النجم الذي لعب دور الضابط علي أمام منة شلبي في مسلسل حارة اليهود؟';
      q['R'] = 'إياد نصار';
      q['W1'] = 'عمرو يوسف';
      q['W2'] = 'آسر ياسين';
      q['W3'] = 'أحمد عز';
    }
    if (qText.contains('فرقة ناجي عطا الله')) {
      q['R'] = 'فرقة ناجي عطاالله';
    }
    if (qText.contains('الهرشة السابعة')) {
      q['W1'] = 'لعبة نيوتن';
    }
    if (qText.contains('نصف ربيع الآخر ومسلسل الليل وآخره')) {
      q['R'] = 'جلال عبدالقوي';
    }
    if (qText.contains('الأصدقاء')) {
      q['W3'] = 'زمن العولمة';
    }
    if (qText.contains('الرجل الذي فقد ذاكرته مرتين')) {
      q['Q'] = 'ما اسم مسلسل أحمد زكي ونيللي عام 1981 عن فاقد الذاكرة مرتين؟';
      q['R'] = 'فاقد الذاكرة مرتين';
    }
    if (qText.contains('حي غمام في عشرينيات القرن الماضي')) {
      q['W2'] = 'ليالي الحلمية';
    }
    if (qText.contains('أشغال شقة')) {
      q['W2'] = 'خالد نور وولده';
    }
    if (qText.contains('خالد نور وولده نور خالد')) {
      q['Q'] = 'ما اسم مسلسل شيكو وكريم محمود عبد العزيز الفانتازي عام 2024؟';
      q['R'] = 'خالد نور وولده';
    }
    if (qText.contains('كفر عسكر')) {
      q['R'] = 'كفر عسكر';
    }
    if (qText.contains('فاطمة تعلبة عام 1996')) {
      q['W2'] = 'حديث الصباح والمساء';
    }
    if (qText.contains('إبراهيم الطاير')) {
      q['W1'] = 'دموع بعيون وقحة';
      q['W2'] = 'أستاذ ورئيس قسم';
      q['W3'] = 'فرقة ناجي عطاالله';
    }
    if (qText.contains('زينب والعرش')) {
      q['W1'] = 'ليالي الحلمية';
    }
    if (qText.contains('صابر يا عم صابر')) {
      q['W2'] = 'البخيل وأنا';
    }
    if (qText.contains('أخو البنات')) {
      q['W2'] = 'صابر ياعم صابر';
    }
  }

  void fixKhaleeji(Map<String, dynamic> q) {
    q['R'] = cleanSimple(q['R'] ?? '');
    q['W1'] = cleanSimple(q['W1'] ?? '');
    q['W2'] = cleanSimple(q['W2'] ?? '');
    q['W3'] = cleanSimple(q['W3'] ?? '');

    final qText = (q['Q'] ?? '').toString();

    if (qText.contains('طاش ما طاش على مدار عقود')) {
      q['Q'] = 'من هما بطلا السلسلة الكوميدية السعودية الشهيرة طاش ما طاش؟';
      q['R'] = 'القصبي والسدحان';
      q['W1'] = 'المالكي وعسيري';
      q['W2'] = 'العلي والمدفع';
      q['W3'] = 'الحبيب ومطرب';
    }
    if (qText.contains('إلى أبي وأمي مع التحية') && qText.contains('المسلسل التربوي')) {
      q['Q'] = 'من الفنانة القديرة التي لعبت دور الأم عائشة في إلى أبي وأمي مع التحية؟';
      q['R'] = 'حياة الفهد';
      q['W1'] = 'سعاد عبدالله';
      q['W2'] = 'مريم الغضبان';
      q['W3'] = 'هدى حسين';
    }
    if (qText.contains('سليمة التي قدمتها الفنانة هدى حسين في المسلسل الشهير كف ودفوف')) {
      q['R'] = 'طقاقة شعبية';
    }
    if (qText.contains('فضة قلبها أبيض')) {
      q['W1'] = 'سماء صافية';
    }
    if (qText.contains('أميمة في دار الأيتام')) {
      q['R'] = 'أميمة بدار الأيتام';
    }
    if (qText.contains('العاصوف') && qText.contains('1979')) {
      q['R'] = 'حادثة اقتحام الحرم';
      q['W3'] = 'افتتاح جسر فهد';
    }
    if (qText.contains('صفقة الأحذية المستوردة في درب الزلق')) {
      q['R'] = 'كلها فردة يسرى';
      q['W1'] = 'كلها فردة يمنى';
    }
    if (qText.contains('الدهن العداني')) {
      q['R'] = 'بيض بالدهن العداني';
    }
    if (qText.contains('لحوم الكلاب لحسين بن عاقول')) {
      q['R'] = 'التاجر سميث ومساعده';
    }
    if (qText.contains('إقلاع اضطراري')) {
      q['Q'] = 'ما هي الفكرة الأساسية لحلقة طاش ما طاش الشهيرة إقلاع اضطراري؟';
      q['R'] = 'عطل طائرة جوي';
      q['W1'] = 'ضياع حقائب المطار';
      q['W2'] = 'سرقة طائرة بالصحراء';
      q['W3'] = 'هبوط بجزيرة نائية';
    }
    if (qText.contains('زوارة خميس بشأن ثنيان')) {
      q['Q'] = 'ما الصدمة التي هزت العائلة في نهاية زوارة خميس بشأن ثنيان؟';
      q['R'] = 'زواجه من نادية';
      q['W1'] = 'إفلاسه وسرقة أمواله';
      q['W2'] = 'هجرته خارج البلاد';
      q['W3'] = 'إصابته بالزهايمر';
    }
    if (qText.contains('أم البنات') && qText.contains('المشروع التجاري')) {
      q['Q'] = 'ما المشروع المنزلي الناجح لشريفة وبناتها في أم البنات؟';
      q['R'] = 'إعداد المأكولات المنزلية';
      q['W1'] = 'تصميم العباءات والفساتين';
      q['W2'] = 'صالون تجميل وعناية';
      q['W3'] = 'متجر بيع الزهور';
    }
    if (qText.contains('ساهر الليل') && qText.contains('ناصر ولولوه')) {
      q['Q'] = 'من أدى دور الحبيب ناصر في الجزء الأول من المسلسل الرومانسي ساهر الليل؟';
      q['R'] = 'حسين المهدي';
      q['W1'] = 'عبدالله بوشهري';
      q['W2'] = 'فؤاد علي';
      q['W3'] = 'محمود بوشهري';
    }
    if (qText.contains('خيوط المعازيب') && qText.contains('الحرفة التراثية')) {
      q['R'] = 'حياكة البشوت الأحسائية';
    }
    if (qText.contains('مهنة الأب سعود التي كان يمارسها')) {
      q['R'] = 'موظف حكومي ومربٍّ';
    }
    if (qText.contains('ملح وسمرة لعام 2023')) {
      q['Q'] = 'ما القضية النفسية المركزية التي فجرها مسلسل ملح وسمرة لعام 2023؟';
      q['R'] = 'التحرش في الطفولة';
      q['W1'] = 'تجارة الأدوية الممنوعة';
      q['W2'] = 'غسيل الأموال الإلكتروني';
      q['W3'] = 'تفكك الأسرة والهجرة';
    }
    if (qText.contains('ساق البامبو')) {
      q['W1'] = 'كان بكل زمان';
    }
    if (qText.contains('كان في كل زمان')) {
      q['R'] = 'كان بكل زمان';
    }
    if (qText.contains('سوالف طفاش 3') || qText.contains('جزيرة الهنود')) {
      q['R'] = 'جزيرة الهنود';
      q['W1'] = 'طفاش في باريس';
      q['W2'] = 'زمن الكورونا';
    }
  }

  void commonNormalize(Map<String, dynamic> q) {
    for (final key in ['R', 'W1', 'W2', 'W3']) {
      var s = q[key].toString();
      s = s.replaceAll('عبد الحسين', 'عبدالحسين');
      s = s.replaceAll('عبد الرضا', 'عبدالرضا');
      s = s.replaceAll('عبد الكريم', 'عبدالكريم');
      s = s.replaceAll('عبد القادر', 'عبدالقادر');
      s = s.replaceAll('عبد العزيز', 'عبدالعزيز');
      s = s.replaceAll('عبد اللطيف', 'عبداللطيف');
      s = s.replaceAll('عبد الرحمن', 'عبدالرحمن');
      s = s.replaceAll('عبد الله', 'عبدالله');
      s = s.replaceAll('عبد الإمام', 'عبدالإمام');
      s = s.replaceAll('عبد القدوس', 'عبدالقدوس');
      s = s.replaceAll('علي بابا', 'علي‌بابا');
      s = s.replaceAll('ناجي عطا الله', 'ناجي عطاالله');
      q[key] = s;
    }
  }

  for (var q in egyptList) {
    fixEgypt(q);
    commonNormalize(q);
  }

  for (var q in khaleejiList) {
    fixKhaleeji(q);
    commonNormalize(q);
  }

  egyptFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(egyptList));
  khaleejiFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(khaleejiList));

  // Sync to main
  int egIdx = 0, khIdx = 0;
  for (int i = 0; i < mainList.length; i++) {
    if (mainList[i]['Category'] == 'دراما مصرية') {
      if (egIdx < egyptList.length) mainList[i] = egyptList[egIdx++];
    } else if (mainList[i]['Category'] == 'دراما خليجية') {
      if (khIdx < khaleejiList.length) mainList[i] = khaleejiList[khIdx++];
    }
  }

  mainFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(mainList));
  print('Applied perfect fixes to Egypt and Khaleeji!');
}
