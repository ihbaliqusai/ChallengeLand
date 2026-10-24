import 'dart:io';
import 'dart:ui' as ui;
import 'package:challenge_land/main.dart' as original;
import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/core/shared_assets.dart';
import 'package:challenge_land/features/onboarding/guide_steps.dart';
import 'package:challenge_land/screens/home/home_screen.dart';
import 'package:challenge_land/screens/auth/login_bottom_sheet.dart';
import 'package:challenge_land/screens/auth/first_run_challenge_screen.dart';
import 'package:challenge_land/services/ad_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/services/online_match_flow.dart';
import 'package:challenge_land/state/guest_guide_provider.dart';
import 'package:challenge_land/widgets/home_artwork.dart';
import 'package:challenge_land/widgets/game_modes_artwork.dart';
import 'package:challenge_land/widgets/home_menu_artwork.dart';
import 'package:challenge_land/widgets/support_contact_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OriginalNativeBridge extends NativeBridgeService {
  @override
  bool get supportsAnimatedCharacters => false;
  @override
  Future<Uint8List?> getCharacterArtwork(int index) async => File(
    'android/app/src/main/res/drawable/contestant_green.png',
  ).readAsBytesSync();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('millionaire/native');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  Map<String, dynamic>? trialResult;
  setUpAll(() async {
    for (final font in {
      'Baloo': 'assets/fonts/baloo.ttf',
      'NotoSansArabic': 'assets/fonts/NotoSansArabic.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        font.key,
      )..addFont(SharedAssets.bundle.load(font.value))).load();
    }
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    trialResult = null;
    messenger.setMockMethodCallHandler(native, (call) async {
      calls.add(call);
      if (call.method == 'consumePendingCampaignStageResult') {
        return trialResult;
      }
      if (call.method.startsWith('get')) return <String, dynamic>{};
      if (call.method.startsWith('consume')) return null;
      if (call.method == 'isAppInstalled') return false;
      return true;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(native, null));
  GuestGuideProvider guide() =>
      OnlineMatchFlow.navigatorKey.currentContext!.read<GuestGuideProvider>();
  AppState state() =>
      OnlineMatchFlow.navigatorKey.currentContext!.read<AppState>();
  Future<GlobalKey> open(
    WidgetTester tester, {
    Size size = const Size(960, 540),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    final key = GlobalKey();
    final ads = AdService();
    addTearDown(ads.dispose);
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: SharedAssets.bundle,
        child: RepaintBoundary(
          key: key,
          child: original.ChallengeLandApp(
            adService: ads,
            nativeBridge: _OriginalNativeBridge(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final asset in [
        HomeArtwork.background,
        GameModesArtwork.asset,
        HomeMenuArtwork.asset,
        'assets/images/guide/head.png',
        'assets/images/guide/person_02.png',
        'assets/images/guide/mouth_01.png',
      ]) {
        await precacheImage(
          AssetImage(asset, bundle: SharedAssets.bundle),
          key.currentContext!,
        );
      }
    });
    await tester.pumpAndSettle();
    return key;
  }

  Future<void> press(WidgetTester tester, String key) async {
    final button = find.byKey(ValueKey(key));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    final images = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .toSet();
    await tester.runAsync(
      () => Future.wait(
        images.map((image) => precacheImage(image, key.currentContext!)),
      ),
    );
    await tester.pump();
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('build/$name.png').writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'the real stone lobby and original menu/modes are toured without login',
    (tester) async {
      final image = await open(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(state().user, isNull);
      await capture(tester, image, 'original-guide-welcome');
      for (var index = 0; index < guestGuideSteps.length; index++) {
        expect(guide().stepIndex, index);
        expect(guide().route, guide().step.route, reason: guide().step.target);
        if (index > 0 && !guide().isLast) {
          expect(
            guide().targetContext(),
            isNotNull,
            reason: guide().step.target,
          );
        }
        if (guide().step.target == GuideTargets.profile) {
          expect(find.byType(HomeMenuArtwork), findsOneWidget);
          await capture(tester, image, 'original-guide-menu');
        }
        if (guide().step.target == GuideTargets.group) {
          expect(find.byType(GameModesArtwork), findsOneWidget);
          await capture(tester, image, 'original-guide-modes');
        }
        if (!guide().isLast) await press(tester, 'guest-guide-next');
        expect(find.byType(LoginBottomSheet), findsNothing);
        expect(state().user, isNull);
        expect(tester.takeException(), isNull);
      }
      await capture(tester, image, 'original-guide-choices');
      await press(tester, 'guest-guide-skip');
      expect(
        find.byKey(const ValueKey('guest-guide-minimized')),
        findsOneWidget,
      );
      await capture(tester, image, 'original-guide-compact');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Google remains optional and the presenter stays after cancelling',
    (tester) async {
      await open(tester);
      guide().showChoices();
      await tester.pumpAndSettle();
      await press(tester, 'guest-guide-google');
      expect(find.byType(LoginBottomSheet), findsOneWidget);
      expect(state().user, isNull);
      await press(tester, 'close-login-sheet');
      expect(find.byKey(const ValueKey('guest-guide-bubble')), findsOneWidget);
      await press(tester, 'guest-guide-google');
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await press(tester, 'google-sign-in');
      expect(state().user, isNotNull);
      expect(find.byKey(const ValueKey('guest-guide-minimized')), findsNothing);
      expect(find.byKey(const ValueKey('guest-guide-bubble')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await open(tester);
      expect(state().user, isNotNull);
      expect(find.byKey(const ValueKey('guest-guide-minimized')), findsNothing);
      await state().signOut();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('guest-guide-minimized')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'the trial opens the existing first-run board without a new gameplay screen',
    (tester) async {
      await open(tester);
      guide().showChoices();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('guest-guide-try')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(FirstRunChallengeScreen), findsOneWidget);
      expect(
        tester
            .widget<FirstRunChallengeScreen>(
              find.byType(FirstRunChallengeScreen),
            )
            .guideTrial,
        isTrue,
      );
      expect(
        calls.where((call) => call.method == 'launchCampaignStage'),
        isNotEmpty,
      );
      final launch = calls.lastWhere(
        (call) => call.method == 'launchCampaignStage',
      );
      expect((launch.arguments as Map)['campaignBoard'], isTrue);
      expect((launch.arguments as Map)['campaignEntry'], 'guest_trial');
      expect(state().user, isNull);
      trialResult = {'score': 800, 'completed': true};
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(FirstRunChallengeScreen), findsNothing);
      expect(guide().isLast, isTrue);
      expect(state().user, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'the original question button explains contact and opens the existing support form',
    (tester) async {
      await open(tester);
      await press(tester, 'guest-guide-skip');
      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('home-help-shortcut'))),
      );
      await tester.pumpAndSettle();
      expect(guide().step.target, GuideTargets.help);
      expect(state().user, isNull);
      await tester.tap(find.text('راسل فريق العمل'));
      await tester.pumpAndSettle();
      expect(find.byType(SupportContactSheet), findsOneWidget);
      expect(find.byType(LoginBottomSheet), findsNothing);
      expect(state().user, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test('skipping retains the compact presenter on the next launch', () async {
    final first = GuestGuideProvider();
    await first.initialize();
    expect(first.expanded, isTrue);
    await first.minimize();
    final second = GuestGuideProvider();
    await second.initialize();
    expect(second.expanded, isFalse);
    second.resume();
    expect(second.expanded, isTrue);
    first.dispose();
    second.dispose();
  });
}
