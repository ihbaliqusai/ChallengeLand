# تخفيف الصور وتوحيد الموارد — 21 أكتوبر 2026

نُفّذت معالجة استهلاك الصور للذاكرة وإزالة تكرار الموارد بين Flutter وAndroid.
الأرقام التالية تخص ملفات APK فعلية من نوع Release ولمعمارية ARM64، بإعدادات بناء واحدة.

| القياس | قبل | بعد |
| --- | ---: | ---: |
| APK | 155.01 MiB | 118.77 MiB |
| ملفات المشروع المشحونة في Flutter، قبل ضغط ZIP | 76.18 MiB | 40.44 MiB |
| عدد هذه الملفات | 174 | 80 |

التوفير الفعلي في APK: **38,006,914 بايت، أي 36.25 MiB بنسبة 23.38%**.
هذا قياس حجم APK؛ لا يمثل حجم تنزيل Google Play أو الذاكرة الكلية للتطبيق.

## الصور

- صُغّرت 44 صورة مشحونة في المتجر والرئيسية والقائمة والمكافآت، وقلّ حجم ملفاتها مجتمعةً بنحو 19.51 MiB.
- حُفظت النسخ السابقة في `tools/design_sources/lightness/assets/`، كما بقيت مصادر PNG الأصلية الموجودة خارج قائمة الشحن.
- يستخدم `adaptiveAssetImage` الأبعاد الفعلية للصورة وحجم العرض وكثافة الشاشة لتحديد دقة فك الضغط، مع منع التكبير فوق دقة الأصل.
- تستخدم أجزاء الصورة المقتطعة ومناطق تغطية النص حجم فك ضغط مشتركًا للصورة نفسها؛ تمديد شريط صغير لا ينشئ صورة هائلة في الذاكرة.
- تُقرّب أحجام فك الضغط إلى مضاعفات 32 بكسل لتقليل إنشاء نسخ متقاربة في كاش الصور.

| مثال | الأبعاد السابقة | الأبعاد الجديدة | ذاكرة RGBA عند فك الصورة كاملةً، قبل ← بعد |
| --- | --- | --- | --- |
| الاشتراك | 3168×1344 | 1600×679 | 16.24 ← 4.14 MiB |
| القائمة | 2752×1536 | 1600×893 | 16.12 ← 5.45 MiB |
| المكافأة الأسبوعية | 2752×1536 | 1600×893 | 16.12 ← 5.45 MiB |
| المفاتيح | 1608×872 | 512×278 | 5.35 ← 0.54 MiB |

هذه حسابات للصورة الواحدة وليست وعدًا بنسبة انخفاض إجمالي RAM. قد تُفك الصور بدقة أصغر أيضًا حسب الشاشة.
رُوجعت بطاقة الاشتراك بصريًا قبل التصغير وبعده. المقارنة محفوظة في `build/lightness-audit/membership-before-after.png`.

## مصدر واحد لكل مورد مشترك

- تُشحن الأسئلة مرة واحدة في Flutter؛ يفتحها `LocalQuestions` مباشرةً من الحزمة نفسها.
- يعرض `SharedAssetBundle` مسارات 88 موردًا من موارد Android الموجودة، تشمل الشخصيات والفئات والخط والأيقونات والفيديو.
- تنفذ قناة `challengeland/shared-assets` قراءة الملفات على طابور خلفي. لا يُحتفظ بنسخة دائمة من البيانات المضغوطة في Dart.
- يُسجّل خط Baloo من مورد Android بواسطة `FontLoader` أثناء التجهيز.
- يشغّل Flutter الفيديو الترحيبي من `android.resource://` بدل تضمين ملف MP4 إضافي.
- بقيت أسماء الصور التي تستخدمها الواجهات كما هي. يحيط `DefaultAssetBundle` بالتطبيق، وتستخدم الصور المشتركة الحزمة المشتركة صراحةً أيضًا.
- أُزيلت نسخة أسئلة Android الزائدة واسم فئة أنمي المكرر، واستُبعدت ست صور غير مستخدمة من قائمة الشحن.
- أصبحت النسخ المتطابقة المشحونة بين Flutter وAndroid **صفرًا** في فحص المصادر والحزمة.

المصدر المرجعي للمسارات هو `tools/shared_assets.json`. يولّد `tools/prepare_shared_assets.cjs` خريطتي Dart وJava؛ المراجع الصريحة في Java تحافظ على الموارد أثناء تصغير Release.
يمنع فحص Gradle `verifySharedAssetManifest` إعادة إضافة الموارد المشتركة إلى `pubspec.yaml`، بما فيها إضافتها عبر مجلد كامل، ويتحقق من بقاء الملفات الأصلية المطلوبة.

## التحقق

- نجحت الاختبارات الـ460، بما فيها تحميل الموارد المشتركة وفك صور الشخصيات والفئات وتحميل الخط، وفحص دقة الصور الصغيرة واتساق أحجام صور الواجهات المقتطعة.
- نجح بناء Release / ARM64.
- نجح بناء AAB النهائي بحجم 146.58 MiB لجميع المعماريات؛ لا يساوي هذا حجم تنزيل المستخدم من المتجر.
- جرى التحقق من توقيع APK، ومن وجود 80 ملف Flutter و88 مسارًا مشتركًا وبنك أسئلة واحد في AAB أيضًا.
- تحقق فاحص APK من 80 ملف Flutter و88 مسارًا مشتركًا ومن وجود بنك أسئلة واحد.
- يتتبع الفاحص أسماء موارد Android عبر `aapt2` لأن Release يختصر أسماء الملفات داخل ZIP، ويقرأ أسماء الفئات العربية بترميز UTF-8.
- نجح التحليل الساكن دون أخطاء أو تحذيرات عند تشغيل `--no-fatal-infos`؛ تبقى ملاحظات أسلوبية في الملفات القائمة.
- لم يُقَس بعدُ إجمالي استهلاك RAM أو زمن الإطارات على جهاز بنسخة Release.

لإعادة التحقق من إضافة موارد جديدة:

```powershell
node tools/prepare_shared_assets.cjs --sync-manifest
node tools/artwork_inventory.cjs
node tools/prepare_shared_assets.cjs --check
node tools/audit_app_size.cjs build/lightness-audit/after.json --check
flutter test --no-pub
flutter analyze --no-pub --no-fatal-infos
flutter build apk --release --target-platform android-arm64 --no-pub
./tools/verify_apk_assets.ps1 -Apk build/app/outputs/flutter-apk/app-release.apk -Inventory build/lightness-audit/after.json
./tools/measure_apk_size.ps1 -Apk build/app/outputs/flutter-apk/app-release.apk -Report build/lightness-audit/after-apk.json
flutter build appbundle --release --no-pub
```

حُفظ APK المقارنة في `build/lightness-audit/before-arm64.apk`، وتقارير القياس والاختبارات في المجلد نفسه.
إضافة صور جديدة إلى دليل الموارد المشتركة تستلزم تحديث `tools/shared_assets.json` وتوليد الخرائط مجددًا؛ لا تُعد إضافتها إلى قائمة شحن Flutter.

المراجع الفنية: [فك الصور بدقة محددة في Flutter](https://api.flutter.dev/flutter/widgets/Image/Image.asset.html)،
[قياس حجم التطبيق](https://docs.flutter.dev/perf/app-size)،
[قراءة فيديو من مورد Android](https://developer.android.com/reference/androidx/media3/datasource/RawResourceDataSource).
