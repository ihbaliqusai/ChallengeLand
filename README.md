# أرض التحدي

Challenge Land

Arabic-first Flutter quiz and challenge MVP. Version 1 uses only free gameplay rewards; coins are earned through play and no real-money flow is implemented.

## Open In VS Code

1. Open this folder in VS Code.
2. Install the recommended extensions when prompted: Dart and Flutter.
3. Select an Android emulator, connected Android device, or iOS simulator.
4. Run the `Flutter Debug` launch configuration from `.vscode/launch.json`.

## Common Commands

```powershell
flutter pub get
dart format .
flutter analyze
flutter test
flutter run
```

Android emulator: start an emulator from Android Studio or VS Code, then run `flutter run`.

iOS simulator: on macOS with Xcode installed, start a simulator and run `flutter run -d ios`.

## Mock/Dev Mode

Mock mode is enabled in `lib/core/constants/app_config.dart`:

```dart
static const bool useMockData = true;
```

When true, the app runs without Firebase. Guest login works, the home screen shows mock stats, quick match starts against a local bot, categories/questions load from local JSON, and leaderboards/friends/history use sample data.

## Connect Firebase

1. Create a Firebase project.
2. Enable Authentication, Cloud Firestore, Firebase Storage, and later Cloud Messaging.
3. Run FlutterFire CLI and generate `firebase_options.dart`.
4. Set `AppConfig.useMockData = false`.
5. Add Firebase config files:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
6. Publish `firestore.rules` after reviewing the MVP security notes.

See `FIREBASE_SETUP.md`, `FIRESTORE_SCHEMA.md`, and `SECURITY_NOTES.md`.

## Implemented MVP

- Arabic RTL app shell and routing.
- Guest/mock login and Google login placeholder.
- Original widget-built game home scene with HUD, unlock banner, mascot, play button, and bottom navigation.
- Game mode selection.
- Mock quick match and playable timed quiz flow.
- Score calculation with speed bonus.
- Final result screen with XP/progress summary.
- Private room create/join/lobby basics.
- Team setup placeholder with auto distribution.
- Daily challenge entry.
- Rewards, leaderboard, profile, friends, search, requests, settings screens.
- Firebase-ready services and Firestore constants.

## MVP Limitations

- Online matchmaking, room validation, answer validation, and leaderboard writes are client-shaped placeholders until Cloud Functions are added.
- Google Sign-In needs Firebase project configuration before real use.
- Notifications are structured as TODOs; no FCM dependency is active yet.
- Friend challenges create the service path but do not send push notifications yet.
- No real media question upload flow yet, only Storage preparation.

## Next Steps

- Move answer validation and scoring to Cloud Functions.
- Add real Google Sign-In configuration.
- Add Firestore indexes for public profile search and leaderboards.
- Add FCM invite notifications.
- Add production anti-cheat checks and server timestamps.
- Expand artwork, sounds, localization, and accessibility testing.
