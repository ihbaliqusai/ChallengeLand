# تشغيل متجر النسخة الجديدة ومعالجة فشل الشراء

## نتيجة الفحص في 3 أكتوبر 2026

النسخة المنشورة سابقاً تستخدم مسار دفع مختلفاً. نجاح شراء باقة البداية فيها يؤكد أن هذا المنتج ونظام دفع Google Play يعملان، لكنه لا يثبت تشغيل خادم التحقق الذي أُضيف للنسخة الجديدة.

الفحص المباشر لمشروع `challengeland` أعاد:

| الفحص | النتيجة |
| --- | --- |
| Cloud Billing | `billingEnabled: false` |
| Cloud Functions API | `DISABLED` |
| Google Play Android Developer API | `DISABLED` |
| Cloud Run API | `DISABLED` |
| Pub/Sub API | `ENABLED` |
| `restoreCommercePurchases` | HTTP 404 |
| `verifyPlayPurchase` | HTTP 404 |

هذه النتيجة تفسر فشل الاستعادة والتحقق في النسخة الجديدة. يجب إكمال الإعداد أدناه قبل اختبارها بدفع حقيقي. بناء نسخة Android وحده لا ينشر وظائف Firebase.

النسخة المصححة تتحقق من وصول حساب اللعبة إلى خدمة الاستعادة قبل فتح الدفع لكل المنتجات، بما فيها العملات والجواهر. غياب الخدمة يمنع فتح نافذة الدفع ويعرض سبب الإعداد المفقود. إعادة تحميل الأسعار لا تمحو خطأ التحقق، وزر إعادة المحاولة يعيد الاستعادة أيضاً.

## إعداد الخادم

1. افتح [مشروع Firebase](https://console.firebase.google.com/project/challengeland/overview)، واربط حساب فوترة واختر خطة Blaze. هذه خطوة صاحب الحساب لأن الوظائف تستخدم موارد سحابية مدفوعة بحسب الاستعمال. راجع [خطة Firebase](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans).
2. فعّل [Google Play Android Developer API](https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com?project=challengeland). أثناء نشر Functions، تطلب أداة Firebase تفعيل واجهات Functions وCloud Run وCloud Build وArtifact Registry وغيرها من متطلبات الجيل الثاني. لا تُلغِ هذه المتطلبات.
3. أنشئ موضوع Pub/Sub باسم `play-billing-rtdn` داخل المشروع `challengeland`، وامنح `google-play-developer-notifications@system.gserviceaccount.com` دور Pub/Sub Publisher على الموضوع. هذا البريد خاص بإرسال إشعارات Play؛ حساب تشغيل وظائف التحقق حساب آخر.
4. داخل `functions` نفّذ `npm ci`، وراجع إعدادات `.env.example`. القيم الافتراضية هي الحزمة `com.qi7bali.landchallengeonline` والموضوع `play-billing-rtdn`. اترك `COMMERCE_ENFORCE_APP_CHECK=false` حتى يُضاف دعم App Check إلى العميل. لا تضف معرّفات VIP قديمة إلى `COMMERCE_LEGACY_VIP_IDS` إلا إذا كانت اشتراكات حقيقية.
5. من جذر المشروع نفّذ:

   ```powershell
   firebase deploy --only functions:commerce,firestore:rules --project challengeland
   ```

6. بعد النشر، افتح إعدادات تشغيل الوظائف في Google Cloud وتعرّف على البريد الفعلي لحساب الخدمة الذي يعمل به `verifyPlayPurchase`. امنحه دور Cloud Datastore User (`roles/datastore.user`) إن لم يكن لديه وصول Firestore مكافئ.
7. في Play Console، افتح Users and permissions وامنح حساب الخدمة وصولاً إلى اللعبة وصلاحيتي View financial data وManage orders and subscriptions. لا تستخدم بريد ناشر إشعارات Play الوارد في الخطوة 3 لهذا الغرض. راجع [إعداد Developer API](https://developers.google.com/android-publisher/getting_started).
8. في Monetization setup ضع الموضوع `projects/challengeland/topics/play-billing-rtdn`، واختر جميع إشعارات الاشتراكات والمنتجات والعمليات الملغاة، ثم أرسل اختباراً وتأكد من وصوله إلى `playBillingNotifications`. راجع [إعداد RTDN](https://developer.android.com/google/play/billing/getting-ready).
9. تأكد أن `firebase functions:list --project challengeland` يعرض وظائف التحقق والاستعادة والإشعارات والتحديث اليومي. طلب POST دون مصادقة إلى وظيفة callable المنشورة يفترض أن يعيد خطأ مصادقة JSON، وليس صفحة HTML برمز 404.

## المنتجات الجديدة غير المتاحة

إنشاء Product ID لا يكفي. افتح كل منتج جديد، خصوصاً `coins_5000` و`coins_25000` و`coins_100000` و`category_all_access`، وتأكد من:

- وجود خيار شراء نشط بنوع Buy، متاح في بلد حساب Google Play المستخدم، وله سعر في ذلك البلد.
- مطابقة المعرّف للكود حرفياً. معرّف خيار الشراء المقترح `standard`، ومعرّف المنتج يبقى كما هو في الكتالوج.
- إيقاف شراء عدة وحدات في العملية الواحدة؛ المتجر الحالي يسلّم وحدة واحدة لكل معاملة.
- تفعيل الخطة الشهرية المتجددة `monthly` للمنتج `vip_monthly` وتحديد سعرها ودولها.
- استخدام حساب اختبار مُضاف إلى مسار الاختبار وLicense testing، وتثبيت AAB الجديد من Google Play. لا يُعد مجرد وجود نسخة منشورة قديمة اختباراً للنسخة الجديدة.

الكود المحدّث يقرأ قائمة خيارات الشراء الجديدة ويختار خيار الشراء الأساسي المتاح، ويستخدم رمزه نفسه للسعر ونافذة الدفع. إذا لم يعرض Google Play المنتج لهذا الحساب، يبقى الشراء معطّلاً وتظهر رسالة تخص توفر المنتج. راجع [خيارات المنتجات الجديدة](https://developer.android.com/google/play/billing/one-time-product-multi-purchase-options-offers).

## الاستعادة وإدارة الاشتراك

- الاستعادة تتحقق من الحقوق الدائمة والاشتراك ومشتريات Play التي لم تُستهلك بعد. لا تمنح العملات المستهلكة مرة ثانية؛ الرصيد المحفوظ للحساب يُحمّل عبر مزامنة اللعبة.
- شراء باقة البداية عملية دفع واحدة، لذلك يظهر في سجل الطلبات. صفحة إدارة الاشتراكات تعرض الاشتراكات المتجددة. ظهور صفحة فارغة ممكن إذا لم توجد عضوية في حساب Google Play المحدد.
- عند وجود عضوية نشطة، يفتح الرابط المنتج المرتبط بالاشتراك مع اسم الحزمة؛ وعند غياب عضوية يفتح صفحة الاشتراكات العامة. راجع [روابط إدارة الاشتراكات](https://developer.android.com/google/play/billing/subscriptions).
- مشتريات النسخ القديمة التي لم ترتبط بمعرّف حساب Firebase تحتاج مراجعة ملكية إدارية إذا عُرضت رسالة شراء قديم. لا تُفسّر صورة طلب أو علم محلي على أنه إذن بمنح مكافأة ثانية. تفاصيل الترحيل في `functions/README.md`.

## التحقق بعد النشر

اختبر أسعار المنتجات الجديدة، شراء باقة تجريبية وتسليمها مرة واحدة، الاستعادة بعد إعادة التشغيل، العضوية وإدارة إلغائها، وعدم تكرار المكافأة بعد الاستعادة. استخدم وسائل الدفع التجريبية لحساب License tester. بعد هذه الاختبارات يمكن تقييم جاهزية النسخة للنشر العام.
