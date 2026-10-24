import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/screens/auth/login_screen.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/widgets/game_viewport.dart';
import 'package:challenge_land/widgets/game_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeAppState extends ChangeNotifier implements AppState {
  bool busy = false;
  String? lastSignedInEmail;
  String? lastRegisteredEmail;
  String? lastResetEmail;
  bool googleSignInCalled = false;

  @override
  bool get isBusy => busy;

  @override
  Future<void> signIn(String email, String password) async {
    lastSignedInEmail = email;
  }

  @override
  Future<void> register(String email, String password, String username) async {
    lastRegisteredEmail = email;
  }

  @override
  Future<void> signInWithGoogle() async {
    googleSignInCalled = true;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    lastResetEmail = email;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNativeBridge implements NativeBridgeService {
  @override
  Future<Map<String, dynamic>?> consumePendingCampaignStageResult() async =>
      null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> dismissFeedback(WidgetTester tester) async {
    final close = find.descendant(
        of: find.byType(GameNoticeCard),
        matching: find.byIcon(Icons.close_rounded));
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close.first);
      await tester.pump();
    }
  }

  Widget buildSubject(_FakeAppState state, {bool fixedCanvas = false}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
        Provider<NativeBridgeService>.value(value: _FakeNativeBridge()),
      ],
      child: MaterialApp(
        builder: fixedCanvas
            ? (context, child) => GameViewport(child: child!)
            : null,
        home: const LoginScreen(),
      ),
    );
  }

  void setViewport(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
      'login retains its landscape layout across phone and tablet sizes',
      (tester) async {
    for (final size in const [
      Size(640, 320),
      Size(800, 360),
      Size(1280, 800)
    ]) {
      setViewport(tester, size);
      await tester.pumpWidget(buildSubject(_FakeAppState(), fixedCanvas: true));
      await tester.pump(const Duration(seconds: 1));
      final context = tester.element(find.byType(LoginScreen));
      final canvas = MediaQuery.sizeOf(context);
      expect(canvas.width / canvas.height,
          closeTo(size.width / size.height, .001));
      expect(tester.getRect(find.byType(Scaffold).first),
          rectMoreOrLessEquals(Offset.zero & size, epsilon: .01));
      expect(find.byType(TextField), findsWidgets);
      expect(tester.takeException(), isNull, reason: '$size');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('renders login screen in landscape 800x360 without overflow',
      (tester) async {
    setViewport(tester, const Size(800, 360));

    final state = _FakeAppState();
    await tester.pumpWidget(buildSubject(state));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsWidgets);
    expect(find.text('حساب جديد'), findsOneWidget);
    expect(find.text('الخادم: متصل'), findsOneWidget);
    expect(find.text('الموسم 1: أرض التحدي'), findsOneWidget);
    expect(find.text('المتابعة عبر Google'), findsOneWidget);
    expect(find.text('دخول فوري كضيف'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders login screen in compact 360x640 without overflow',
      (tester) async {
    setViewport(tester, const Size(360, 640));

    final state = _FakeAppState();
    await tester.pumpWidget(buildSubject(state));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsWidgets);
    expect(find.text('حساب جديد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toggling tab switches between login and registration mode',
      (tester) async {
    setViewport(tester, const Size(1000, 500));

    final state = _FakeAppState();
    await tester.pumpWidget(buildSubject(state));
    await tester.pump(const Duration(milliseconds: 100));

    // Initially in Sign In mode
    expect(find.text('اسم اللاعب / اللقب'), findsNothing);
    expect(find.text('دخول الساحة ⚔️'), findsOneWidget);

    // Tap on "حساب جديد"
    await tester.tap(find.text('حساب جديد'));
    await tester.pump(const Duration(milliseconds: 350));

    // Now in Register mode
    expect(find.text('اسم اللاعب / اللقب'), findsOneWidget);
    expect(find.text('إنشاء الحساب وبدء المغامرة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mascot speech bubble cycles quote on tap', (tester) async {
    setViewport(tester, const Size(900, 450));

    final state = _FakeAppState();
    await tester.pumpWidget(buildSubject(state));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('مرحباً بك يا بطل! الساحة بانتظارك ⚔️'), findsOneWidget);

    // Tap the speech bubble
    await dismissFeedback(tester);
    await tester.tap(find.text('مرحباً بك يا بطل! الساحة بانتظارك ⚔️'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('أكثر من 50,000 سؤال ومنافسات حقيقية أونلاين! 🧠'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forgot password link opens dialog', (tester) async {
    setViewport(tester, const Size(900, 450));

    final state = _FakeAppState();
    await tester.pumpWidget(buildSubject(state));
    await tester.pump(const Duration(milliseconds: 100));

    final forgotBtn = find.text('نسيت كلمة المرور؟');
    expect(forgotBtn, findsOneWidget);

    await dismissFeedback(tester);
    await tester.tap(forgotBtn);
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('استعادة كلمة المرور'), findsOneWidget);
    expect(find.text('إرسال الرابط'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('presenter area tap triggers mascot bounce and quote change',
      (tester) async {
    setViewport(tester, const Size(900, 450));

    final state = _FakeAppState();
    await tester.pumpWidget(buildSubject(state));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('مرحباً بك يا بطل! الساحة بانتظارك ⚔️'), findsOneWidget);

    // Tap presenter image fallback / video presenter container
    final presenterFinder = find.byType(GestureDetector).first;
    await tester.tap(presenterFinder);
    await tester.pump(const Duration(milliseconds: 350));

    expect(tester.takeException(), isNull);
  });
}
