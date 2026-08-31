# دليل تركيب الترويج المتبادل داخل لعبة "من سيربح المليون 2024" 🚀

هذا المجلد يحتوي على حزمة جاهزة بالكامل لترويج لعبة **"أرض التحدي - أونلاين"** (`com.qi7bali.landchallengeonline`) داخل لعبة **"من سيربح المليون 2024"** (`net.androidgaming.millionaire2024`).

---

## 1️⃣ إذا كانت لعبة "من سيربح المليون" مبنية بـ Android Native (Java / Kotlin):

### الخطوة 1: نسخ الملفات
1. انسخ ملف `CrossPromoChallengeLandDialog.java` إلى مسار مشروعك:
   `app/src/main/java/net/androidgaming/millionaire2024/` (أو مسار الباكيج الخاص بك).
2. انسخ ملف `dialog_cross_promo_challengeland.xml` إلى:
   `app/src/main/res/layout/`
3. انسخ الملفين `bg_cross_promo_card.xml` و `btn_promo_gradient.xml` إلى:
   `app/src/main/res/drawable/`

### الخطوة 2: استدعاء النافذة في اللعبة
يمكنك إظهار نافذة الترويج بلمسة واحدة في أي مكان (مثلاً عند النقر على زر "ألعابنا الأخرى"، أو في شاشة القائمة الرئيسية، أو بعد نهاية الجولة/Game Over):

```java
CrossPromoChallengeLandDialog.show(MainActivity.this);
```

### الخطوة 3: إضافة Package Queries في `AndroidManifest.xml` (مهم لأندرويد 11 فما فوق):
أضف داخل وسم `<manifest>` في ملف `AndroidManifest.xml`:
```xml
<queries>
    <package android:name="com.qi7bali.landchallengeonline" />
    <package android:name="com.android.vending" />
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="market" />
    </intent>
</queries>
```

---

## 2️⃣ إذا كانت اللعبة مبنية بمحرك Unity:
1. انسخ ملف `CrossPromoChallengeLand.cs` وضعه داخل مجلد `Assets/Scripts/`.
2. أضف السكربت إلى أي GameObject أو زر في الواجهة.
3. اربط حدث `OnClick` بالدالة `CrossPromoChallengeLand.OnClickPromote()`.

---

## 3️⃣ إذا كانت اللعبة مبنية بـ Flutter:
1. انسخ ملف `cross_promo_challengeland_dialog.dart` إلى مجلد `widgets` في مشروعك.
2. استدعِ النافذة في أي زر أو حدث:
```dart
CrossPromoChallengeLandDialog.show(context);
```

---

## 🎯 النتيجة:
- عندما يضغط اللاعب، سيتعرف النظام تلقائياً عما إذا كانت "أرض التحدي" مثبتة على جهازه ليفتحها فوراً، أو يوجهه إلى صفحة التحميل على Google Play!
