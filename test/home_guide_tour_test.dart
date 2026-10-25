import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/widgets/guide/host_guide_character.dart';
import 'package:challenge_land/widgets/guide/guide_presenter_scene.dart';
import 'package:challenge_land/widgets/guide/home_guide_tour_overlay.dart';
import 'package:challenge_land/widgets/guide/guide_assistant_dialog.dart';
import 'package:challenge_land/widgets/guide/persistent_guide_button.dart';

class _MockAppState extends ChangeNotifier implements AppState {
  int signInRequests = 0;
  bool failSignIn = false;
  @override
  Future<void> signInWithGoogle() async {
    signInRequests++;
    if (failSignIn) throw StateError('offline');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HostGuideBubble renders text, title, and speech bubble tail',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HostGuideBubble(
            title: 'مرحباً بك يا بطل!',
            text: 'أنا مرشدك في أرض التحدي',
            showHost: false,
            enableTypewriter: false,
          ),
        ),
      ),
    );

    expect(find.text('مرحباً بك يا بطل!'), findsOneWidget);
    expect(find.text('أنا مرشدك في أرض التحدي'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('PointingHandWidget animates with pointing icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PointingHandWidget(
            direction: AxisDirection.right,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.pan_tool_alt_rounded), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('GuidePromptDialog displays free demo play and google choices',
      (tester) async {
    final appState = _MockAppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(
          home: Scaffold(
            body: GuidePromptDialog(),
          ),
        ),
      ),
    );

    expect(find.text('جرّب التحدي مجانًا'), findsOneWidget);
    expect(find.text('المتابعة بحساب Google'), findsOneWidget);
    expect(find.text('استمرار كزائر'), findsOneWidget);

    // Tap dismiss
    await tester.tap(find.byKey(const ValueKey('close-login-sheet')));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('PersistentGuideButton renders and responds to tap',
      (tester) async {
    final appState = _MockAppState();
    bool restarted = false;

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: Scaffold(
            body: PersistentGuideButton(
              onRestartTour: () => restarted = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('مرشد الساحة'), findsOneWidget);
    await tester.tap(find.text('مرشد الساحة'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(GuideAssistantDialog), findsOneWidget);

    // Tap replay tour in dialog
    await tester.ensureVisible(find.text('إعادة الجولة التعريفية'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('إعادة الجولة التعريفية'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(restarted, isTrue);
  });

  testWidgets('tour speech stays visible until navigation and completes',
      (tester) async {
    final appState = _MockAppState();
    final targetKey = GlobalKey();
    bool completed = false;

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  top: 100,
                  left: 100,
                  child: SizedBox(
                    key: targetKey,
                    width: 80,
                    height: 40,
                  ),
                ),
                Positioned.fill(
                  child: HomeGuideTourOverlay(
                    steps: [
                      GuideStep(
                        title: 'الخطوة 1',
                        text: 'شرح الخطوة الأولى',
                        targetKey: targetKey,
                      ),
                      const GuideStep(
                        title: 'الخطوة 2',
                        text: 'شرح الخطوة الثانية',
                      ),
                      const GuideStep(
                        title: 'الخطوة الأخيرة',
                        text: 'جاهز للتحدي؟',
                        isFinalChoiceStep: true,
                      ),
                    ],
                    onComplete: () => completed = true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('الخطوة 1'), findsOneWidget);
    expect(find.text('ابدأ الجولة'), findsOneWidget);

    Future<void> expectSpeechStaysVisible(String message) async {
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(minutes: 1));
      await tester.pump(const Duration(milliseconds: 200));
      final visibility = tester.widget<FadeTransition>(
          find.byKey(const ValueKey('guide-speech-visibility')));
      expect(visibility.opacity.value, 1);
      final text =
          tester.widget<Text>(find.byKey(const ValueKey('guide-spoken-text')));
      final shown =
          ((text.textSpan! as TextSpan).children!.first as TextSpan).text;
      expect(shown, message);
    }

    await expectSpeechStaysVisible('شرح الخطوة الأولى');
    await tester.tap(find.text('ابدأ الجولة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('الخطوة 2'), findsOneWidget);
    await expectSpeechStaysVisible('شرح الخطوة الثانية');
    await tester.tap(find.text('التالي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('الخطوة الأخيرة'), findsOneWidget);
    expect(find.text('جرّب التحدي مجانًا'), findsOneWidget);
    expect(find.text('المتابعة بحساب Google'), findsOneWidget);
    await expectSpeechStaysVisible('جاهز للتحدي؟');

    // Click Explore freely
    await tester.tap(find.text('استكشف الساحة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(completed, isTrue);
  });

  testWidgets(
      'spotlight follows resize, clears missing targets, and intercepts play',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final targetKey = GlobalKey();
    var underlyingTaps = 0;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!),
      home: Scaffold(
          body: Padding(
              padding: const EdgeInsets.all(28),
              child: Stack(children: [
                Positioned(
                    right: 24,
                    top: 20,
                    child: SizedBox(
                        key: targetKey,
                        width: 90,
                        height: 48,
                        child: FilledButton(
                            onPressed: () => underlyingTaps++,
                            child: const Text('اللعب')))),
                Positioned.fill(
                    child: HomeGuideTourOverlay(steps: [
                  GuideStep(
                      title: 'هدف متحرك',
                      text: 'شرح الزر',
                      targetKey: targetKey),
                  GuideStep(
                      title: 'عنصر غير متاح',
                      text: 'يجب ألا تبقى إضاءة الزر السابق',
                      targetKey: GlobalKey()),
                  const GuideStep(title: 'النهاية', text: 'ابدأ'),
                ], onComplete: () {})),
              ]))),
    ));
    await tester.pump();
    SpotlightPainter painter() => tester
        .widget<CustomPaint>(find.byKey(const ValueKey('guide-spotlight')))
        .painter! as SpotlightPainter;
    expect(painter().targetRect!.width, closeTo(90, .01));
    final before = painter().targetRect!;
    await tester.binding.setSurfaceSize(const Size(700, 420));
    await tester.pump();
    await tester.pump();
    expect(painter().targetRect!.left, lessThan(before.left));
    await tester.tap(find.byKey(const ValueKey('guide-target-action')));
    await tester.pump();
    expect(underlyingTaps, 0);
    expect(find.text('عنصر غير متاح'), findsOneWidget);
    expect(painter().targetRect, isNull);
    await tester.tap(find.text('السابق'));
    await tester.pump();
    expect(painter().targetRect, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'native speech reveals, stays visible and replays above a full torso',
      (tester) async {
    const message = 'أهلا بك في أرض التحدي';
    final speech = GuideSpeechController();
    final speaking = <bool>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
      child: GuidePresenterScene(
          title: 'مرشدك في الساحة',
          text: message,
          width: 320,
          presenterHeight: 190,
          bubbleHeight: 116,
          controller: speech,
          onSpeakingChanged: speaking.add),
    ))));
    String revealed() {
      final text =
          tester.widget<Text>(find.byKey(const ValueKey('guide-spoken-text')));
      return ((text.textSpan! as TextSpan).children!.first as TextSpan).text!;
    }

    String mouth() => (tester
            .widgetList<Image>(find.byType(Image))
            .firstWhere((image) =>
                (image.image as AssetImage).assetName.contains('mouth_'))
            .image as AssetImage)
        .assetName;
    double opacity() => tester
        .widget<FadeTransition>(
            find.byKey(const ValueKey('guide-speech-visibility')))
        .opacity
        .value;
    final presenter =
        tester.getRect(find.byKey(const ValueKey('guide-presenter')));
    final podium = tester.getRect(find.byKey(const ValueKey('guide-podium')));
    final bubble =
        tester.getRect(find.byKey(const ValueKey('guide-speech-bubble')));
    expect(presenter.height, 190);
    expect(podium.width, closeTo(190 * 152 / 141, .01));
    expect(podium.top, closeTo(presenter.bottom - 6, .01));
    expect(podium.bottom, greaterThan(presenter.bottom));
    expect(bubble.bottom, lessThanOrEqualTo(presenter.top + .01));
    expect(revealed(), isEmpty);
    expect(mouth(), contains('mouth_01.png'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(revealed(), isNotEmpty);
    expect(revealed().length, lessThan(message.length));
    expect(mouth(), contains('mouth_02.png'));
    await tester.pump(Duration(milliseconds: message.characters.length * 18));
    expect(revealed(), message);
    expect(mouth(), contains('mouth_05.png'));
    expect(opacity(), 1);
    expect(speaking, [true, false]);
    await tester.pump(const Duration(minutes: 1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(opacity(), 1);
    expect(revealed(), message);
    expect(tester.getRect(find.byKey(const ValueKey('guide-presenter'))),
        presenter);
    expect(tester.getRect(find.byKey(const ValueKey('guide-podium'))), podium);
    speech.replay();
    await tester.pump();
    expect(revealed(), isEmpty);
    expect(mouth(), contains('mouth_01.png'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(revealed(), isNotEmpty);
    expect(opacity(), greaterThan(0));
    speech.reveal();
    await tester.pump();
    expect(revealed(), message);
    expect(mouth(), contains('mouth_05.png'));
    expect(speaking, [true, false, true, false]);
    await tester.pumpWidget(const SizedBox.shrink());
    speech.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'changing the explanation fades the old bubble before the next line',
      (tester) async {
    var title = 'الشرح الأول';
    var message = 'هذه هي الخطوة الأولى';
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: StatefulBuilder(builder: (context, setState) {
        update = setState;
        return GuidePresenterScene(
            title: title,
            text: message,
            width: 320,
            presenterHeight: 190,
            bubbleHeight: 116);
      }),
    ))));
    await tester.pump(const Duration(milliseconds: 200));
    final presenter =
        tester.getRect(find.byKey(const ValueKey('guide-presenter')));
    update(() {
      title = 'الشرح الثاني';
      message = 'والآن تعرّف على رصيدك';
    });
    await tester.pump();
    expect(find.text('الشرح الأول'), findsOneWidget);
    expect(find.text('الشرح الثاني'), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('الشرح الأول'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('الشرح الثاني'), findsOneWidget);
    expect(find.text('الشرح الأول'), findsNothing);
    final text =
        tester.widget<Text>(find.byKey(const ValueKey('guide-spoken-text')));
    final visible =
        ((text.textSpan! as TextSpan).children!.first as TextSpan).text!;
    expect(visible.length, lessThan(message.length));
    expect(tester.getRect(find.byKey(const ValueKey('guide-presenter'))),
        presenter);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled and failed sign-in keep final choices available',
      (tester) async {
    final app = _MockAppState();
    var completed = false;
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
            home: Scaffold(
                body: HomeGuideTourOverlay(steps: const [
          GuideStep(
              title: 'جاهز',
              text: 'اختر طريقة المتابعة',
              isFinalChoiceStep: true)
        ], onComplete: () => completed = true)))));
    await tester.tap(find.text('المتابعة بحساب Google'));
    await tester.pump();
    expect(app.signInRequests, 1);
    expect(completed, isFalse);
    app.failSignIn = true;
    await tester.tap(find.text('المتابعة بحساب Google'));
    await tester.pump();
    expect(app.signInRequests, 2);
    expect(completed, isFalse);
    expect(find.textContaining('تعذّر تسجيل الدخول'), findsOneWidget);
    await tester.tap(find.text('استكشف الساحة'));
    await tester.pump();
    expect(completed, isTrue);
  });
}
