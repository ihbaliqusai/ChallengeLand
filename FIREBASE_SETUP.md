# Firebase Setup

TODO: Update Firebase project to match new package name.

1. Create a Firebase project named for your app.
2. Add Android and iOS apps with your final package IDs.
3. Install and run FlutterFire CLI:

```powershell
dart pub global activate flutterfire_cli
flutterfire configure
```

4. Enable Firebase Auth providers:
   - Anonymous
   - Google
5. Enable Cloud Firestore in production or test mode, then publish `firestore.rules`.
6. Enable Firebase Storage for future media questions.
7. Prepare Firebase Cloud Messaging for future invites and daily challenge reminders.
8. Set `AppConfig.useMockData = false` in `lib/core/constants/app_config.dart`.

TODO: Add `firebase_options.dart` imports to `lib/main.dart` after FlutterFire CLI generates the file.
