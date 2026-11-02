> تحديث: هذا التقرير يوثق المرحلة السابقة لفحص الهاتف. تفاصيل الخلفية والمقدمة وعرض الشخصية استُبدلت بالتنفيذ والقياسات في [تقرير الهاتف](D:/millionchallengeonline/ChallengeLand/docs/DEVICE_PERFORMANCE_20261102_AR.md). بقية أعمال التنظيف السابقة موثقة أدناه.

# تحسين الأداء وتنظيف ChallengeLand — 2 نوفمبر 2026

نُفذت التغييرات داخل `D:\millionchallengeonline\ChallengeLand` مع الحفاظ على التعديلات السابقة في مساحة العمل. النسخة الناتجة هي **3.8.7، رقم البناء 47، Release لمعمارية ARM64**، وحجم APK هو **113.77 MiB** (119,298,102 بايت). لم تُثبت النسخة على هاتف ولم تُنشر إلى المتجر أو Firebase.

**الرئيسية وبدء التشغيل**

- لم تعد زيارة الرئيسية تحمّل بنك الأسئلة كاملًا. يبدأ تحميله عند طلب اللعب، على خيط خلفي بأولوية منخفضة؛ ينتظر الانتقال الأصلي اكتماله بصورة غير متزامنة، ويتحقق من الحساب وحالة النشاط قبل فتح الشاشة. إلغاء الطلب عند الخروج يمنع إطلاق مباراة قديمة بعد العودة.
- أصبحت موسيقى الرئيسية والخريطة تُحضّر بواسطة `prepareAsync`، مع تنظيف المشغّل عند مغادرة النشاط. أزيل التحضير المتزامن للموسيقى من مسار الدخول.
- أُخذ وقت تهيئة المنصة ضمن مدة المقدمة بدل إضافة 2.4 ثانية كاملة بعده. أصبحت الواجهة جاهزة بعد المحفظة والشخصية، وتتابع مزامنة الإنجازات وXP بعد ذلك. رفض تهيئة المحفظة أو انتهاء مهلتها يبقي العمليات المالية غير جاهزة.
- فُصلت صورة خلفية الرئيسية الثابتة عن المؤثرات المتحركة، وحُدد فك صورتها بعرض 1280. تبدأ المؤثرات بعد عرض إطار الصورة الثابتة، وعدد الجسيمات 32، والضباب ثلاث طبقات، وتحديث الرسم المحيطي 24 مرة في الثانية. الأزرار والتنقل لا يخضعان لهذا الحد.
- أزيلت طبقة الجسيمات الإضافية، وأصبحت تحديثات الرصيد والشخصية والمستوى محلية للجزء المعني. لا يعاد بناء مشهد الرئيسية لمجرد إشعار رصيد لم يتغير.

الملفات الرئيسية: [الخلفية](D:/millionchallengeonline/ChallengeLand/lib/widgets/animated_home_background.dart)، [الرئيسية](D:/millionchallengeonline/ChallengeLand/lib/screens/home/home_screen.dart)، [تهيئة التطبيق](D:/millionchallengeonline/ChallengeLand/lib/main.dart)، [حالة الحساب](D:/millionchallengeonline/ChallengeLand/lib/core/app_state.dart)، [الموسيقى](D:/millionchallengeonline/ChallengeLand/android/app/src/main/java/com/Qi7bali/challengeland/SceneMusicPlayer.java).

**الفيديو والشخصيات الثماني**

بقيت الشخصيات الثماني ومقاطع ردود أفعالها. لم يُفرض حد جديد يجعل شخصية واحدة فقط متحركة. عولجت المقاطع من النسخ الأصلية المحفوظة، لا من النسخة الوسيطة المصغرة.

| القياس | النتيجة |
| --- | ---: |
| مقاطع الشخصيات | 48 مقطعًا بدقة 360×640 |
| فيديو خلفية اللعب | 768×432 |
| معدل الإطارات | 24 إطارًا/ثانية، كما كان |
| مجموع الإطارات المفكوكة | 11,364، دون فقدان إطار |
| حجم المقاطع الـ49 قبل | 16,842,407 بايت = 16.06 MiB |
| حجمها بعد | 8,480,500 بايت = 8.09 MiB |
| التوفير | 8,361,907 بايت = 7.97 MiB، بنسبة 49.65% |

أزيلت المسارات الصوتية من هذه المقاطع التي يشغلها الكود مكتومة أصلًا. صُغرت مخرجات الشخصية في Flutter إلى 360×640، والانعكاس إلى 180×320. تُدمج إشعارات الإطارات المتراكمة ويُتجنب نشر الإطار نفسه مرارًا. أُصلح كذلك سباق إعداد فيديو الخلفية الذي كان قد يبدأ بعد إيقاف النشاط.

هذه قياسات ملفات وإطارات، وليست نسبة انخفاض في إجمالي RAM أو إثباتًا لسرعة الهاتف. روجعت مقارنة بصرية لعينة عند حجم عرض معتاد. بقي حد الأجهزة الضعيفة القديم كما كان؛ لم يُضف تقليل جديد لعدد الشخصيات.

الملفات: [مشغّل الشخصية](D:/millionchallengeonline/ChallengeLand/android/app/src/main/java/com/Qi7bali/challengeland/ChromaVideoView.java)، [مخرجات Flutter](D:/millionchallengeonline/ChallengeLand/android/app/src/main/kotlin/com/Qi7bali/challengeland/CharacterAnimationTextures.kt)، [أداة المعالجة القابلة لإعادة الاستخدام](D:/millionchallengeonline/ChallengeLand/tools/optimize_character_playback.cjs).

**الذاكرة ودورة الحياة والاتصال**

- أُلغيت حلقات الإضاءة والرمش واحتفال العملات عند إيقاف الشاشة أو تدميرها، مع استئناف نسخة واحدة عند العودة، وتنظيف صور العملات والمؤقتات المؤجلة.
- أصبح تحميل خرائط الحملة مسبقًا والعرض يستخدمان موفر الصورة نفسه ودقة فك الترميز نفسها، لتجنب كاش أصل كامل ونسخة عرض منفصلة.
- قائمة الغرف تستخدم استعلامات محدودة، وتثبت اشتراكات الغرف والمضيفين. تجمّع ملفات المضيفين في دفعات حتى 30 مع الحفاظ على التحديث والحذف.
- يعمل العد التنازلي الاجتماعي عند الحاجة فقط ويتوقف في الخلفية، كما تتوقف مؤقتات إعادة محاولة تحميل الإعلانات.

أضيف فهرسان إلى `firestore.indexes.json` ولم يُنشرا. يوجد استعلام بديل محدود عند غياب الفهرس. نافذة توافق الوثائق القديمة ذات الحقول الناقصة محدودة بـ60 وثيقة، وقائمة العرض محدودة كذلك؛ الوصول إلى غرفة محفوظة بالمعرف وإعادة الاتصال مستقلان عنها. نشر الفهارس المحضرة يتم من جذر المشروع بالأمر `firebase deploy --only firestore:indexes` عند إصدار التغيير. [مرجع فهارس Firestore](https://firebase.google.com/docs/firestore/query-data/indexing).

**المراجعة والحذف**

حُذفت **22 من ملفات كود التطبيق** ثبت عدم وصول مسارات التشغيل الحالية إليها: 17 ملف Dart وخمسة ملفات Java. أزيل أيضًا ملفا واجهة Android تابعان لها، واختبار شاشة الدخول القديمة، وأربعة أصول مهجورة. ووُحدت 22 نسخة متطابقة من صور المقدم مع موارد Android، مع إبقاء أسمائها المنطقية في Flutter. إجمالي الملفات الفعلية المحذوفة أو الموحدة **51 ملفًا**، محفوظة جميعًا بنسخ احتياطية وبصمات SHA-256.

أزيل اعتماد `video_player` واعتماد الاختبار التابع له؛ الاستخدام الوحيد له كان شاشة الدخول القديمة المحذوفة. تشغيل الشخصيات الحالي يستخدم الشيفرة الأصلية. كذلك أزيل فيديو الترحيب القديم ومسار قناته غير المستعمل، وتكرار صور المقدم بين المحركين أصبح صفرًا في فحص الملفات المشحونة.

**لم تُحذف `SeriesGameActivity`:** يوجد استدعاء فعلي لها في مسار غرف `series` داخل MainActivity، ووضع السلسلة موجود في واجهات الغرف. احتُفظ أيضًا بمكونات Android/Firebase وFlutter التي تدخل عبر النظام أو XML أو التسجيل التلقائي.

أُعيد فحص 142 ملف Dart و124 ملف Java/Kotlin بعد التنظيف. لم يعثر الفاحص المحافظ على ملفات غير قابلة للوصول ضمن شبكة الاستيراد والمراجع التي يفحصها. هذا لا يثبت أن كل دالة أو فرع داخل ملف مستخدم؛ لم يُنفذ حذف تلقائي اعتمادًا على غياب نص استدعاء واحد. الأداة الجديدة: [تدقيق المراجع](D:/millionchallengeonline/ChallengeLand/tools/audit_runtime_references.cjs).

النسخ الاحتياطية خارج موارد التطبيق في:
`C:\Users\Qusai\Documents\Codex\2026-11-02\d-millionchallengeonline-challengeland\work\performance-20261102\removed-unused`

وأصول الفيديو قبل التصغير في:
`C:\Users\Qusai\Documents\Codex\2026-11-02\d-millionchallengeonline-challengeland\work\performance-20261102\media\originals`

**التحقق النهائي**

- نجح **859 اختبار Flutter**، مع تخطي اختبارين.
- نجح تحليل `lib` و`test` دون ملاحظات، ونجح فحص فروق المسافات.
- نجح تجميع اختبارات Android، بما فيها اختبارات دورة حياة المؤثرات وتشغيل الشخصيات الثماني. لم تُشغّل اختبارات الجهاز لعدم وجود هاتف أو محاكي متصل.
- نجح بناء Release ونسخة ARM64 المنفصلة، والتحقق من توقيع APK.
- فُحص داخل APK وجود 352 من أصول Flutter و128 مسارًا مشتركًا، وبنك أسئلة واحد، وعدم حزم نسخ المقدم المكررة. تطابقت بصمات SHA-256 لجميع المقاطع الـ49 مع الملفات المعالجة.
- نجح فاحص أصول التطبيق وفاحص مراجع المصدر. حُفظت الاختبارات الحالية لتسجيل الدخول والجولات والمكافآت والمحفظة؛ حُذف اختبار شاشة الدخول المهجورة فقط، وأُصلحت تجهيزات اختبارات قديمة كانت تشير لمسارات الصور السابقة.

**التجربة على الهاتف**

ملف التجربة هو `ChallengeLand-3.8.7-performance-arm64.apk` الموجود بجانب هذا التقرير. اختبر الرئيسية والتنقل وأعد الدخول إلى عدة مباريات. لم يُقَس FPS أو زمن الدخول أو PSS على جهاز فعلي، لذلك لا تُنسب نسبة توفير المقاطع إلى تحسن مماثل في سرعة التطبيق. القياس النهائي يكون على الهاتف المستهدف بوضع Profile، ثم التحقق من Release. [مرجع قياس أداء Flutter](https://docs.flutter.dev/perf/ui-performance).

**قائمة الملفات المحذوفة أو الموحدة**

الصور الموسومة «مصدر موحد» ما زالت متاحة للواجهات من المورد الأصلي في Android؛ حُذفت النسخة المتطابقة فقط.

- `D:\millionchallengeonline\ChallengeLand\lib\screens\auth\login_screen.dart`
- `D:\millionchallengeonline\ChallengeLand\lib\screens\auth\offline_welcome_screen.dart`
- `D:\millionchallengeonline\ChallengeLand\lib\screens\campaign\stage_intro_screen.dart`
- `D:\millionchallengeonline\ChallengeLand\lib\screens\campaign\widgets\campaign_header.dart`
- `D:\millionchallengeonline\ChallengeLand\lib\screens\campaign\widgets\campaign_map_background.dart`
- `D:\millionchallengeonline\ChallengeLand\lib\screens\campaign\widgets\campaign_path_painter.dart`
- `D:\millionchallengeonline\ChallengeLand\lib\screens\campaign\widgets\lifeline_rules_row.dart`
- `D:\millionchallengeonline\ChallengeLand\lib\screens\campaign\widgets\result_stars_banner.dart`
- `D:\millionchallengeonline\ChallengeLand\lib\screens\campaign\widgets\result_stat_tile.dart`
- `D:\millionchallengeonline\ChallengeLand\lib\screens\campaign\widgets\save_guest_progress_dialog.dart`
- `D:\millionchallengeonline\ChallengeLand\lib\screens\campaign\widgets\stage_leaderboard_preview.dart`
- `D:\millionchallengeonline\ChallengeLand\lib\screens\campaign\widgets\stage_reward_chip.dart`
- `D:\millionchallengeonline\ChallengeLand\lib\screens\campaign\widgets\star_rating_view.dart`
- `D:\millionchallengeonline\ChallengeLand\lib\widgets\cross_promo_millionaire_badge.dart`
- `D:\millionchallengeonline\ChallengeLand\lib\widgets\game_shell.dart`
- `D:\millionchallengeonline\ChallengeLand\lib\widgets\lobby_action_panel.dart`
- `D:\millionchallengeonline\ChallengeLand\lib\widgets\special_offer_badge.dart`
- `D:\millionchallengeonline\ChallengeLand\android\app\src\main\java\com\Qi7bali\challengeland\Answer.java`
- `D:\millionchallengeonline\ChallengeLand\android\app\src\main\java\com\Qi7bali\challengeland\Fictitious.java`
- `D:\millionchallengeonline\ChallengeLand\android\app\src\main\java\com\Qi7bali\challengeland\LoginActivity.java`
- `D:\millionchallengeonline\ChallengeLand\android\app\src\main\java\com\Qi7bali\challengeland\MatchmakingSplitBackgroundView.java`
- `D:\millionchallengeonline\ChallengeLand\android\app\src\main\java\com\Qi7bali\challengeland\TeamBattleGameActivity.java`
- `D:\millionchallengeonline\ChallengeLand\android\app\src\main\res\layout\activity_login.xml`
- `D:\millionchallengeonline\ChallengeLand\android\app\src\main\res\layout\activity_game_team_battle.xml`
- `D:\millionchallengeonline\ChallengeLand\test\login_screen_test.dart`
- `D:\millionchallengeonline\ChallengeLand\android\app\src\main\res\raw\welcome.mp4`
- `D:\millionchallengeonline\ChallengeLand\assets\videos\welcome.mp4`
- `D:\millionchallengeonline\ChallengeLand\assets\ui\logo.webp`
- `D:\millionchallengeonline\ChallengeLand\assets\ui\person_welcome.webp`
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\podiumhost.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\head.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\person_08.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\person_07.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\person_06.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\person_09.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\person_05.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\person_03.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\person_02.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\person_04.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\person_10.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\person_01.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\mouth_02.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\mouth_01.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\look_aside.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\mouth_06.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\mouth_05.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\mouth_03.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\mouth_04.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\closed_eyes.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\eyebrows_up_left.png` — مصدر موحد في Android
- `D:\millionchallengeonline\ChallengeLand\assets\presenter\eyebrows_up_right.png` — مصدر موحد في Android

