import 'package:challenge_land/widgets/guide/gameplay_presenter.dart';
import 'package:challenge_land/widgets/guide/guide_presenter_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _shownText(WidgetTester tester) {
  final text =
      tester.widget<Text>(find.byKey(const ValueKey('guide-spoken-text')));
  return ((text.textSpan! as TextSpan).children!.first as TextSpan).text!;
}

GameplayPresenter _presenter(WidgetTester tester) =>
    tester.widget<GameplayPresenter>(find.byType(GameplayPresenter));

Future<void> _disposeScene(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}

void main() {
  testWidgets('app resume cannot restart speech under a covered route',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var routeActive = true;
    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        rebuild = setState;
        return TickerMode(
          enabled: routeActive,
          child: const Center(
            child: GuidePresenterScene(
              title: 'شرح الجولة',
              text:
                  'تعرّف على أزرار الساحة والأرصدة التي تساعدك في رحلتك. يمكنك متابعة الشرح أو الرجوع إلى الخطوة السابقة.',
              width: 360,
              presenterHeight: 150,
              bubbleHeight: 168,
            ),
          ),
        );
      }),
    ));
    await tester.pump(const Duration(milliseconds: 180));
    expect(_shownText(tester), isNotEmpty);
    expect(_presenter(tester).isTalking, isTrue);

    rebuild(() => routeActive = false);
    await tester.pump();
    final pausedText = _shownText(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    expect(_shownText(tester), pausedText);
    expect(_presenter(tester).isTalking, isFalse);

    rebuild(() => routeActive = true);
    await tester.pump();
    expect(_presenter(tester).isTalking, isTrue);
    await tester.pump(const Duration(milliseconds: 180));
    expect(_shownText(tester).length, greaterThan(pausedText.length));
    expect(tester.takeException(), isNull);
    await _disposeScene(tester);
  });

  testWidgets('route changes cannot start speech while the app is inactive',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    var routeActive = true;
    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        rebuild = setState;
        return TickerMode(
          enabled: routeActive,
          child: const Center(
            child: GuidePresenterScene(
              title: 'بداية الشرح',
              text:
                  'لن يبدأ المقدم الشرح إلا عندما تعود إلى اللعبة وتكون الجولة ظاهرة أمامك.',
              width: 360,
              presenterHeight: 150,
              bubbleHeight: 168,
            ),
          ),
        );
      }),
    ));
    await tester.pump(const Duration(milliseconds: 180));
    expect(_shownText(tester), isEmpty);
    expect(_presenter(tester).isTalking, isFalse);

    rebuild(() => routeActive = false);
    await tester.pump();
    rebuild(() => routeActive = true);
    await tester.pump(const Duration(seconds: 1));
    expect(_shownText(tester), isEmpty);
    expect(_presenter(tester).isTalking, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 180));
    expect(_shownText(tester), isNotEmpty);
    expect(_presenter(tester).isTalking, isTrue);
    expect(tester.takeException(), isNull);
    await _disposeScene(tester);
  });

  testWidgets('completed speech stays visible across route and app resumes',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var routeActive = true;
    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        rebuild = setState;
        return TickerMode(
          enabled: routeActive,
          child: const Center(
            child: GuidePresenterScene(
              title: 'أهلًا بك',
              text: 'مرحبًا',
              width: 360,
              presenterHeight: 150,
              bubbleHeight: 120,
            ),
          ),
        );
      }),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_shownText(tester), 'مرحبًا');
    expect(_presenter(tester).isTalking, isFalse);
    rebuild(() => routeActive = false);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 10));
    double opacity() => tester
        .widget<FadeTransition>(
            find.byKey(const ValueKey('guide-speech-visibility')))
        .opacity
        .value;
    expect(opacity(), 1);

    rebuild(() => routeActive = true);
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(opacity(), 1);
    expect(_shownText(tester), 'مرحبًا');
    expect(_presenter(tester).isTalking, isFalse);
    expect(tester.takeException(), isNull);
    await _disposeScene(tester);
  });
}
