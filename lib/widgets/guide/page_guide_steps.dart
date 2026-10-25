import 'package:flutter/widgets.dart';

import 'home_guide_tour_overlay.dart';
import 'page_guide.dart';

enum ModeGuideTarget { main, group, friend, offline, close }

List<GuideStep> buildModeGuideSteps(Map<ModeGuideTarget, GlobalKey> targets) {
  GuideStep step(ModeGuideTarget target, String title, String text) =>
      GuideStep(title: title, text: text, targetKey: targets[target]);
  return [
    const GuideStep(
        title: 'كيف تريد أن تلعب؟',
        text: 'هذه طرق اللعب المتاحة. سأوضح الفرق بينها لتختار ما يناسبك.'),
    step(ModeGuideTarget.main, 'التحدي الرئيسي',
        'فريقان يتنافسان على الجهاز نفسه. اختر تصنيفات الأسئلة، ثم تناوبا على اختيار الأسئلة والإجابة.'),
    step(ModeGuideTarget.main, 'قبل بدء التحدي',
        'المباراة الكاملة تحتاج مفتاحًا. اختر تصنيفات مفتوحة، أو استخدم تذكرة لتجربة تصنيف مقفل لمباراة واحدة.'),
    step(ModeGuideTarget.group, 'التحدي الجماعي',
        'أنشئ غرفة وشارك رمزها مع أصدقائك، أو ادخل غرفة برمز وصل إليك. هذا الوضع يحتاج اتصالًا بالإنترنت.'),
    step(ModeGuideTarget.friend, 'تحدي صديق',
        'افتح قائمة اللاعبين، واختر صديقًا أو لاعبًا لتدعوه إلى مواجهة عبر الإنترنت.'),
    step(ModeGuideTarget.offline, 'اللعب دون إنترنت',
        'اختر هذا الوضع للعب دون اتصال. يمكنك البدء حتى عندما لا تتوفر شبكة.'),
    step(ModeGuideTarget.close, 'اختر وضعك',
        'بعد إنهاء الشرح، اضغط الوضع الذي تريد لعبه. زر الإغلاق يعيدك إلى الساحة.'),
  ];
}

enum CampaignGuideTarget {
  stage,
  locked,
  boss,
  stars,
  hearts,
  worlds,
  journey,
  continueStage
}

List<GuideStep> buildCampaignGuideSteps(
    Map<CampaignGuideTarget, GlobalKey> targets,
    {required int targetScore,
    required bool hasLockedStage,
    required bool hasBoss,
    bool hasStage = true}) {
  GuideStep step(CampaignGuideTarget target, String title, String text,
          {bool scroll = false}) =>
      GuideStep(
          title: title,
          text: text,
          targetKey: targets[target],
          onEnter: scroll ? () => revealGuideTarget(targets[target]!) : null);
  return [
    const GuideStep(
        title: 'رحلتك تبدأ هنا',
        text:
            'تقدّم عبر المراحل بالترتيب. افز بالمرحلة المفتوحة لفتح التالية، واجمع النجوم من نتائجك.'),
    if (hasStage)
      step(CampaignGuideTarget.stage, 'ابدأ من هنا',
          'اضغط رقم مرحلة مفتوحة لتبدأ اللعب. المرحلة المضيئة هي نقطة متابعتك الحالية.',
          scroll: true),
    if (hasStage)
      step(
          CampaignGuideTarget.stage,
          'كيف تفوز؟',
          targetScore > 0
              ? 'اختر أسئلة من اللوحة واجمع النقاط. هدف هذه المرحلة $targetScore نقطة، وقد توجد أهداف إضافية موضحة أثناء اللعب.'
              : 'اختر أسئلة من اللوحة، وأجب صحيحًا لتحقيق أهداف المرحلة. راقب الهدف والوقت المعروضين أثناء اللعب.',
          scroll: true),
    if (hasLockedStage)
      step(CampaignGuideTarget.locked, 'لماذا هذه المرحلة مقفلة؟',
          'أكمل المرحلة السابقة أولًا. يمكنك إعادة مرحلة سبق أن فزت بها لتحسين نتيجتك ونجومك.',
          scroll: true),
    if (hasBoss)
      step(CampaignGuideTarget.boss, 'مواجهة الزعيم',
          'في كل مرحلة عاشرة تواجه الزعيم. حقق شرط الفوز المعروض أثناء المواجهة لتواصل رحلتك.',
          scroll: true),
    step(CampaignGuideTarget.stars, 'نجوم رحلتك',
        'هذا مجموع نجومك. لكل مرحلة حتى ٣ نجوم؛ النتيجة الأفضل قد تمنحك نجومًا أكثر.'),
    step(CampaignGuideTarget.hearts, 'القلب يعني محاولة',
        'تحتاج قلبًا لبدء مرحلة. يعود القلب إذا فزت، ويُستهلك إذا خسرت. اضغط الرصيد لفتح متجر القلوب.'),
    step(CampaignGuideTarget.worlds, 'التنقل بين العوالم',
        'استخدم الأسهم أو اسحب الخريطة يمينًا ويسارًا لتغيير العالم. المراحل المقفلة تبقى مقفلة حتى تصل إليها.'),
    step(CampaignGuideTarget.journey, 'رحلة اليوم',
        'اضغط هنا لترى أهداف اليوم وتقدمك فيها، ونجوم العالم، والأيام التي لعبت فيها.'),
    step(CampaignGuideTarget.continueStage, 'تابع من مكانك',
        'هذا الزر يفتح المرحلة المقترحة مباشرة. ويمكنك اختيار مرحلة أخرى من الخريطة أو إعادة الشرح من علامة الاستفهام.'),
  ];
}

enum StoreGuideTarget {
  navigation,
  featured,
  rewards,
  coins,
  gems,
  resources,
  keys,
  hearts,
  tickets,
  exchange,
  packs,
  membership,
  collection,
  characters,
  categories,
  footer,
}

enum CharacterGuideTarget {
  preview,
  pages,
  current,
  level,
  coins,
  gems,
  balances,
  inspect,
  confirm
}

List<GuideStep> buildCharacterGuideSteps(
    Map<CharacterGuideTarget, GlobalKey> targets,
    Future<void> Function(CharacterGuideTarget) prepare,
    {required bool forced,
    required bool hasSavedCharacter,
    int? levelRequired,
    int? coinPrice,
    int? gemPrice}) {
  GuideStep step(CharacterGuideTarget target, String title, String text) =>
      GuideStep(
          title: title,
          text: text,
          targetKey: targets[target],
          onEnter: () => prepare(target));
  return [
    const GuideStep(
        title: 'اختر من يمثّلك',
        text:
            'هذه الشخصيات التي يمكنك اللعب بها. عاينها أولًا، ثم أكّد الشخصية التي تريدها.'),
    step(CharacterGuideTarget.preview, 'معاينة الشخصية',
        'اضغط بطاقة لمعاينة الشخصية. لا يتغير اختيارك المحفوظ إلا بعد التأكيد.'),
    step(CharacterGuideTarget.pages, 'شخصيات أخرى',
        'اسحب البطاقات للمزيد، أو اضغط النقاط للتنقل بين صفحات الشخصيات.'),
    if (hasSavedCharacter)
      step(CharacterGuideTarget.current, 'شخصيتك الحالية',
          'علامة الصح لشخصيتك المحفوظة. الإطار المضيء للشخصية التي تعاينها.'),
    if (levelRequired != null)
      step(CharacterGuideTarget.level, 'شخصية تُفتح بالمستوى',
          'تُفتح عند المستوى $levelRequired. العب واجمع الخبرة للوصول إليه؛ لا تحتاج شراءها.'),
    if (coinPrice != null)
      step(CharacterGuideTarget.coins, 'شخصية بسعر عملات',
          'سعرها $coinPrice عملة. «فتح وتفعيل» يخصم السعر، ويفتح الشخصية ويختارها.'),
    if (gemPrice != null)
      step(CharacterGuideTarget.gems, 'شخصية بسعر جواهر',
          'سعرها $gemPrice جوهرة لفتحها دائمًا. المعاينة مجانية ولا تشتري الشخصية.'),
    step(CharacterGuideTarget.balances, 'رصيد الشراء',
        'هذه عملاتك وجواهرك. إذا نقص الرصيد، تخبرك اللعبة بالمبلغ وتتيح زيارة المتجر.'),
    step(CharacterGuideTarget.inspect, 'استعراض التفاصيل',
        'العدسة تعرض نبذة الشخصية وبياناتها ومظهرها داخل اللعبة، دون شراء.'),
    step(
        CharacterGuideTarget.confirm,
        'تأكيد اختيارك',
        forced
            ? 'بعد اختيار شخصية متاحة، اضغط زر بدء اللعب لحفظها والمتابعة.'
            : '«اختيار الشخصية» يحفظ المتاحة. «فتح وتفعيل» يشتري المقفلة ويختارها.'),
  ];
}

List<GuideStep> buildStoreGuideSteps(Map<StoreGuideTarget, GlobalKey> targets,
    Future<void> Function(StoreGuideTarget) prepare,
    {bool hasExchange = true}) {
  GuideStep step(StoreGuideTarget target, String title, String text) =>
      GuideStep(
          title: title,
          text: text,
          targetKey: targets[target],
          onEnter: () => prepare(target));
  return [
    const GuideStep(
        title: 'دليلك إلى المتجر',
        text:
            'سأريك أقسام المتجر ووظيفة كل رصيد. أثناء الشرح سننتقل بين الأقسام دون شراء أي شيء.'),
    step(StoreGuideTarget.navigation, 'اختر قسمًا',
        'الأزرار العلوية تنقلك بين العروض، وأرصدة اللعب، والجواهر، والعضوية، والفئات والشخصيات.'),
    step(StoreGuideTarget.featured, 'العروض المميزة',
        'كل باقة تعرض ما ستأخذه والسعر المطلوب. عند الضغط على الشراء تظهر لك نافذة الدفع لتأكيد العملية.'),
    step(StoreGuideTarget.rewards, 'المكافآت المتاحة',
        'افتح دولاب الحظ للفة مجانية كل يوم، أو أكمل مشاهدة إعلان لتحصل على مكافأته.'),
    step(StoreGuideTarget.coins, 'شحن العملات',
        'اختر باقة عملات لشرائها. ويمكنك هنا تحويل الجواهر إلى عملات بالسعر المعروض.'),
    step(StoreGuideTarget.gems, 'شحن الجواهر',
        'اختر باقة الجواهر المناسبة. الجواهر تُستخدم لشراء العناصر وأرصدة اللعب التي تحمل سعرًا بالجواهر.'),
    step(StoreGuideTarget.keys, 'المفاتيح',
        'كل مباراة كاملة في «التحدي الرئيسي» تحتاج مفتاحًا واحدًا. تُستخدم المفاتيح اليومية أولًا.'),
    step(StoreGuideTarget.hearts, 'القلوب',
        'القلب محاولة في «تحدي المراحل». يعود إذا فزت، ويُستهلك إذا خسرت. هذا الرقم يوضح محاولاتك المتاحة.'),
    step(StoreGuideTarget.tickets, 'تذاكر التصنيفات',
        'تذكرة واحدة تفتح تصنيف أسئلة مقفلًا لمباراة واحدة. امتلاك التصنيف بشكل دائم يغنيك عن استخدام تذكرة له.'),
    step(StoreGuideTarget.resources, 'اليومي والإضافي',
        'اليومي هو ٣ مفاتيح و٣ قلوب تتجدد كل يوم. الإضافي يأتي من المتجر والمكافآت ويبقى لليوم التالي.'),
    if (hasExchange)
      step(StoreGuideTarget.exchange, 'الشراء برصيد اللعبة',
          'اختر الدفع بالعملات أو بالجواهر حسب الزر والسعر المعروضين. هذا الشراء يُخصم من رصيدك داخل اللعبة.'),
    step(StoreGuideTarget.packs, 'الباقات والإعلانات',
        'الباقات المدفوعة تُشترى عبر Google Play. زر الإعلان يمنح المكافأة بعد إكمال المشاهدة، ضمن العدد اليومي المتاح.'),
    step(StoreGuideTarget.membership, 'العضوية',
        'اقرأ المزايا والمدة والسعر قبل الاشتراك. الاشتراك الشهري يتجدد حسب إعدادات حسابك في Google Play.'),
    step(StoreGuideTarget.characters, 'شخصيتك في اللعبة',
        'من هنا تستعرض الشخصيات وتغيّر شخصيتك. بعض الشخصيات متاحة لك، وأخرى تحتاج شراءً أو تحقيق شرط فتحها.'),
    step(StoreGuideTarget.categories, 'طرق فتح التصنيفات',
        'الشراء الدائم يفتح التصنيف دائمًا، والاستئجار للمدة المحددة. التذكرة تفتحه لمباراة واحدة.'),
    step(StoreGuideTarget.footer, 'مشترياتك واشتراكك',
        'استعد مشترياتك الدائمة من هنا. «إدارة الاشتراكات» تتيح مراجعة العضوية وإيقاف تجديدها في Google Play.'),
  ];
}
