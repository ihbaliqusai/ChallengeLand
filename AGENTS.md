# AGENTS.md

## تعليمات دائمة لـ Codex

- هذا مشروع Flutter/Dart باسم `challenge_land` لتطبيق لعبة أسئلة وتحديات عربية باتجاه RTL.
- لا تعيد بناء المشروع من الصفر إلا إذا طُلب ذلك صراحة.
- حافظ على البنية الحالية:
  - `lib/core`
  - `lib/models`
  - `lib/services`
  - `lib/state`
  - `lib/features`
- استخدم `Provider` كحل إدارة الحالة الحالي.
- كل النصوص الظاهرة للمستخدم يجب أن تكون عربية ومركزية قدر الإمكان في `AppStrings` أو نظام localization واضح.
- التطبيق Version 1 مجاني بالكامل:
  - ممنوع إضافة تدفقات أموال حقيقية.
  - ممنوع أسعار حقيقية.
  - ممنوع أنظمة شراء داخل التطبيق.
  - ممنوع حزم فوترة أو SDKs مالية.
  - أي متجر يجب أن يكون مكافآت مجانية أو عناصر تجميلية قابلة للفتح باللعب فقط.
- حافظ على Mock/dev mode بحيث يعمل التطبيق بدون Firebase عندما `AppConfig.useMockData = true`.
- عند تعديل Flutter code شغّل عند الإمكان:
  - `dart format .`
  - `flutter analyze`
  - `flutter test`
- إذا لم تكن Flutter SDK متاحة، اذكر ذلك بوضوح في التقرير النهائي ولا تدّعي أنك شغّلت الأوامر.
- لا تضف dependencies جديدة إلا عند الحاجة الواضحة، واشرح السبب.
- لا تضع أسرار Firebase أو مفاتيح API داخل المستودع.
- أي scoring أو leaderboard إنتاجي يجب أن ينتقل لاحقًا إلى Cloud Functions، ولا تعتمد على client-side scoring في الإنتاج.
- اجعل كل مرحلة صغيرة وقابلة للمراجعة.

## Persistent Instructions For Codex

- This is a Flutter/Dart project named `challenge_land` for an Arabic RTL quiz and challenge game.
- Do not rebuild the project from scratch unless explicitly requested.
- Preserve the current architecture:
  - `lib/core`
  - `lib/models`
  - `lib/services`
  - `lib/state`
  - `lib/features`
- Use `Provider` as the current state management solution.
- All user-facing text should be Arabic and centralized as much as possible in `AppStrings` or a clear localization system.
- Version 1 is fully free:
  - Do not add real-money flows.
  - Do not add real-money amounts.
  - Do not add app checkout flows.
  - Do not add money-related SDKs.
  - Any shop must be free rewards or cosmetic items unlockable through gameplay only.
- Keep Mock/dev mode working without Firebase when `AppConfig.useMockData = true`.
- When editing Flutter code, run when possible:
  - `dart format .`
  - `flutter analyze`
  - `flutter test`
- If the Flutter SDK is unavailable, state that clearly in the final report and do not claim the commands were run.
- Do not add new dependencies unless clearly needed, and explain why.
- Do not commit Firebase secrets or API keys to the repository.
- Production scoring or leaderboards should later move to Cloud Functions; do not rely on client-side scoring in production.
- Keep each phase small and reviewable.
