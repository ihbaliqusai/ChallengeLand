import 'dart:convert';
import 'dart:io';

int countWords(String s) {
  var t = s.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).length;
}

void main() {
  final files = [
    File('assets/questions_egyptian_drama_300.json'),
    File('assets/questions_khaleeji_drama_300.json'),
    File('assets/questions.json'),
  ];

  for (final file in files) {
    var text = file.readAsStringSync();
    
    // Egyptian replacements
    text = text.replaceAll('أهو ده اللي صار', 'ليالي الحلمية');
    text = text.replaceAll('خلي بالك من زيزي', 'لعبة نيوتن');
    text = text.replaceAll('رجل في زمن العولمة', 'زمن العولمة');
    text = text.replaceAll('الرجل الذي فقد ذاكرته مرتين', 'فاقد الذاكرة مرتين');
    text = text.replaceAll('خالد نور وولده نور خالد', 'خالد نور وولده');
    text = text.replaceAll('الناس في كفر عسكر', 'كفر عسكر');
    text = text.replaceAll('الرجل الذي فقد ظله', 'فاقد ظله');
    text = text.replaceAll('صابر يا عم صابر', 'صابر ياعم صابر');

    // Khaleeji replacements
    text = text.replaceAll('إلى أبي وأمي مع التحية', 'مع التحية');
    text = text.replaceAll('نور في سماء صافية', 'سماء صافية');
    text = text.replaceAll('أميمة في دار الأيتام', 'أميمة بدار الأيتام');
    text = text.replaceAll('البيض المقلي بالدهن العداني', 'بيض بالدهن العداني');
    text = text.replaceAll('كان في كل زمان', 'كان بكل زمان');
    text = text.replaceAll('سوالف طفاش 3 في جزيرة الهنود', 'جزيرة الهنود');
    text = text.replaceAll('طفاش وجاسوم في باريس', 'طفاش في باريس');
    text = text.replaceAll('طفاش في زمن الكورونا', 'طفاش زمن الكورونا');

    file.writeAsStringSync(text);
  }

  print('Finished Egypt and Khaleeji replacements!');
}
