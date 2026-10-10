import 'dart:io';

import 'package:challenge_land/services/campaign_defaults.dart';

/// Run: dart run tools/export_campaign_balance.dart
void main() {
  final output = StringBuffer('''# توزيع المراحل المئة

تُولّد هذه الوثيقة من إعدادات اللعبة: `dart run tools/export_campaign_balance.dart`.
النقاط محسوبة من عدد الفئات والاختيارات، مع خليتين لكل قيمة: 200 و400 و600.
مواجهات صيّادي النقاط تحسب السقف 2400 بسبب استهلاك المنافسين للخلايا الأعلى قيمة؛ باقي اللوحات تستخدم الحد النظري المتاح للاعب.
هدف النجاح والنجوم على مضاعفات 200؛ يتصاعد المطلوب بين العوالم مع تخفيف هدف التحديات المقيدة.
الفوز في الزعماء يتطلب التفوق على جميع المنافسين؛ عمود الهدف مرجع نقاط، والنجوم تعتمد على النقاط بعد الفوز.
اختيار الكمبيوتر يستخدم الفئات المفتوحة الصالحة فقط، ويثبت عند إعادة المحاولة ما دامت الفئات المتاحة نفسها.
عدد الفئات إلزامي؛ عند نقص الفئات المفتوحة يتوقف البدء حتى فتحها دون تسجيل خسارة.
المحاولات المحفوظة تحتفظ بقواعدها وأهدافها السابقة.

داخل كل عالم: فئتك المفضلة، ثنائي المعرفة، سباق الوقت، اختيار الكمبيوتر، الاستكشاف، تحدي الفئات، الدقة، اللوحة المفاجئة، اختبار ما قبل الزعيم، مواجهة الزعيم.
من العالم الثالث: المرحلة التاسعة بلا كشف خيارات. من العالم السابع: تجمع الوقت وخطأين كحد أقصى والإجابة الصحيحة في ثلاث فئات. آخر ثلاثة زعماء يمزجون أساليب المنافسين.
إعدادات السحابة القديمة تُحدّث آليًا عند القراءة؛ لتثبيت تصميم مخصص اضبط `boardDesignVersion: 2`.
هذه موازنة حسابية تحتاج متابعة نتائج اللعب الفعلية لضبط صعوبة الأسئلة ومعدل النجاح.

| العالم | المرحلة | الفئات | الاختيار | الاختيارات | أقصى نقاط | هدف النجاح | نجمتان | ثلاث نجوم | القواعد |
|---|---|---|---|---|---|---|---|---|---|
''');
  final csv = StringBuffer(
      'world,stage,categories,policy,picks,maximum,target,twoStars,threeStars,seconds,maxErrors,categoryWins,revealOptions,bossStyle\n');
  for (final stage in CampaignDefaults.stages()) {
    final world = (stage.order - 1) ~/ 10 + 1;
    final columns =
        stage.isBossStage ? stage.botCount + 1 : stage.boardSoloCols;
    final maximum = CampaignDefaults.maxScoreForBoard(
        columns: columns,
        picks: stage.boardSoloPicks,
        bossStyle: stage.isBossStage ? stage.bossStyle : null);
    final rules = <String>[
      if (stage.timeLimitSeconds > 0) '${stage.timeLimitSeconds} ثانية',
      if ((stage.maxWrongAnswers ?? 0) > 0)
        '${stage.maxWrongAnswers} أخطاء مسموحة',
      if (stage.boardRequiredCategoryCount > 0)
        'صحيح في ${stage.boardRequiredCategoryCount} فئات من العالم',
      if (!stage.boardAllowRevealOptions) 'بلا كشف خيارات',
      if (stage.isBossStage) '${stage.botCount} زعماء: ${stage.bossStyle}',
    ];
    output.writeln(
        '| $world | ${stage.order} | $columns | ${stage.categoryPolicy == 'playerPick' ? 'اللاعب' : 'الكمبيوتر'} | ${stage.boardSoloPicks} | $maximum | ${stage.boardTargetScore} | ${stage.starRules.twoStarsMinScore} | ${stage.starRules.threeStarsMinScore} | ${rules.isEmpty ? 'تحدي النقاط' : rules.join('؛ ')} |');
    csv.writeln(
        '$world,${stage.order},$columns,${stage.categoryPolicy},${stage.boardSoloPicks},$maximum,${stage.boardTargetScore},${stage.starRules.twoStarsMinScore},${stage.starRules.threeStarsMinScore},${stage.timeLimitSeconds},${stage.maxWrongAnswers ?? 0},${stage.boardRequiredCategoryCount},${stage.boardAllowRevealOptions},${stage.bossStyle}');
  }
  Directory('docs').createSync(recursive: true);
  File('docs/campaign_balance.md').writeAsStringSync(output.toString());
  File('docs/campaign_balance.csv').writeAsStringSync(csv.toString());
}
