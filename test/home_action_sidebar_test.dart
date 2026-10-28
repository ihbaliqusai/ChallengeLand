import 'dart:ui' as ui;

import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/models/campaign_home_progress.dart';
import 'package:challenge_land/widgets/guide/home_guide_steps.dart';
import 'package:challenge_land/widgets/home_action_sidebar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _SidebarUser implements User {
  @override
  String get uid => 'sidebar-player';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _SidebarState extends ChangeNotifier implements AppState {
  _SidebarState(this.vip);
  final bool vip;

  @override
  User get user => _SidebarUser();

  @override
  bool get isVip => vip;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Lets the test advance the supplied lobby animation without a running ticker.
class _ManualAnimation extends Animation<double> {
  double _value = 0;
  final _listeners = <VoidCallback>{};

  @override
  double get value => _value;

  @override
  AnimationStatus get status => AnimationStatus.forward;

  void advance(double value) {
    _value = value;
    for (final listener in _listeners.toList()) {
      listener();
    }
  }

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}
}

const _actions = {
  'المتصدرون': 'leaderboard',
  'تحدي المراحل': 'campaign',
  'نادي الأبطال': 'vip',
  'أوضاع اللعب': 'modes',
  'الأصدقاء واللاعبون': 'friends',
  'العب': 'play',
};

Future<GlobalKey> _mount(
  WidgetTester tester, {
  required List<String> calls,
  Size panelSize = const Size(320, 480),
  bool vip = false,
  int? leaderboardRank = 7,
  CampaignHomeProgress? campaignProgress,
  bool reducedMotion = false,
  bool rotatePromotions = true,
  ValueNotifier<bool>? tickerEnabled,
  GlobalKey<NavigatorState>? navigatorKey,
  Duration initialPump = const Duration(seconds: 1),
  Animation<double> animation = const AlwaysStoppedAnimation(0),
}) async {
  await tester.binding
      .setSurfaceSize(Size(panelSize.width + 32, panelSize.height + 32));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final state = _SidebarState(vip);
  addTearDown(state.dispose);
  final previewKey = GlobalKey();
  final guideTargets = {
    for (final target in HomeGuideTarget.values) target: GlobalKey(),
  };
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      navigatorKey: navigatorKey,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Scaffold(
          backgroundColor: const Color(0xFF0A2A30),
          body: Center(
            child: TooltipVisibility(
              visible: false,
              child: RepaintBoundary(
                key: previewKey,
                child: SizedBox.fromSize(
                  size: panelSize,
                  child: AnimatedBuilder(
                    animation: tickerEnabled ?? const AlwaysStoppedAnimation(0),
                    builder: (context, _) => TickerMode(
                      enabled: tickerEnabled?.value ?? true,
                      child: HomeActionSidebar(
                        animation: animation,
                        leaderboardRank: leaderboardRank,
                        campaignProgress: campaignProgress,
                        trophies: 238,
                        isOnline: true,
                        isVip: vip,
                        guideTargets: guideTargets,
                        rotatePromotions: rotatePromotions,
                        onLeaderboard: () => calls.add('leaderboard'),
                        onCampaign: () => calls.add('campaign'),
                        onVip: () => calls.add('vip'),
                        onLuckyWheel: () => calls.add('wheel'),
                        onModes: () => calls.add('modes'),
                        onFriends: () => calls.add('friends'),
                        onPlay: () => calls.add('play'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.runAsync(() => Future.wait([
        for (final asset in HomeActionSidebar.assets)
          precacheImage(AssetImage(asset), previewKey.currentContext!),
      ]));
  await tester.pump();
  await tester.pump(initialPump);
  expect(tester.takeException(), isNull);
  return previewKey;
}

Future<Uint8List> _pixels(WidgetTester tester, GlobalKey previewKey) async {
  return (await tester.runAsync(() async {
    final boundary =
        previewKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }))!;
}

void main() {
  setUpAll(() async {
    await (FontLoader('Leaderboard')
          ..addFont(
              rootBundle.load('assets/fonts/BarlowCondensed-SemiBold.ttf')))
        .load();
  });

  testWidgets('club and wheel alternate in the same slot every five seconds',
      (tester) async {
    final calls = <String>[];
    await _mount(tester, calls: calls, initialPump: Duration.zero);
    final club = find.byKey(const ValueKey('home-vip-button'));
    final wheel = find.byKey(const ValueKey('home-wheel-button'));
    await tester.pump(const Duration(milliseconds: 4999));
    expect(club, findsOneWidget);
    expect(wheel, findsNothing);
    final slot = tester.getRect(club);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(club, findsNothing);
    expect(wheel, findsOneWidget);
    expect(tester.getRect(wheel), slot);
    expect(find.byTooltip('دولاب الحظ'), findsOneWidget);
    final artwork = tester.widget<Image>(
        find.descendant(of: wheel, matching: find.byType(Image)));
    expect(artwork.image.toString(), contains('lucky_wheel.png'));
    await tester.tap(wheel);
    expect(calls, ['wheel']);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(wheel, findsNothing);
    expect(club, findsOneWidget);
    expect(tester.getRect(club), slot);
    await tester.tap(club);
    expect(calls, ['wheel', 'vip']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('outgoing promotion cannot receive taps or duplicate semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _mount(tester, calls: [], initialPump: Duration.zero);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('home-vip-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-vip-button')).hitTestable(),
          findsNothing);
      expect(find.bySemanticsLabel('نادي الأبطال'), findsNothing);
      expect(find.bySemanticsLabel('دولاب الحظ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
      'holding the promotion keeps its action stable across the interval',
      (tester) async {
    final calls = <String>[];
    await _mount(tester, calls: calls);
    await tester.pump(const Duration(milliseconds: 3900));
    final club = find.byKey(const ValueKey('home-vip-button'));
    final gesture = await tester.startGesture(tester.getCenter(club));
    await tester.pump(const Duration(seconds: 1));
    expect(club, findsOneWidget);
    expect(find.byKey(const ValueKey('home-wheel-button')), findsNothing);
    await gesture.up();
    await tester.pump();
    expect(calls, ['vip']);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('home-wheel-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ticker-disabled promotion resumes with a fresh five-second display',
      (tester) async {
    final enabled = ValueNotifier(true);
    addTearDown(enabled.dispose);
    await _mount(tester, calls: [], tickerEnabled: enabled);
    enabled.value = false;
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(find.byKey(const ValueKey('home-vip-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-wheel-button')), findsNothing);
    enabled.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4999));
    expect(find.byKey(const ValueKey('home-wheel-button')), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('home-wheel-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('promotion stays stable while explaining the home controls',
      (tester) async {
    await _mount(tester, calls: [], rotatePromotions: false);
    await tester.pump(const Duration(seconds: 15));
    expect(find.byKey(const ValueKey('home-vip-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-wheel-button')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('backgrounded promotion pauses and resumes its display timer',
      (tester) async {
    await _mount(tester, calls: []);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(find.byKey(const ValueKey('home-wheel-button')), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('home-wheel-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('covered home route pauses the promotion', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await _mount(tester, calls: [], navigatorKey: navigator);
    navigator.currentState!.push<void>(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Covered'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 10));
    expect(find.byKey(const ValueKey('home-wheel-button'), skipOffstage: false),
        findsNothing);
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('home-vip-button')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('home-wheel-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion swaps promotion instantly after five seconds',
      (tester) async {
    await _mount(tester,
        calls: [], reducedMotion: true, initialPump: Duration.zero);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.byKey(const ValueKey('home-vip-button')), findsNothing);
    expect(find.byKey(const ValueKey('home-wheel-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('campaign card shows reached stage in left-to-right order',
      (tester) async {
    await _mount(tester,
        calls: [],
        campaignProgress:
            const CampaignHomeProgress(reachedStage: 5, totalStages: 100));
    final progress = find.byKey(const ValueKey('home-campaign-progress'));
    final label = tester.widget<Text>(
        find.descendant(of: progress, matching: find.byType(Text)));
    expect(label.data, '5/100');
    expect(label.textDirection, TextDirection.ltr);
    expect(find.textContaining('اجمع النجوم'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(190, 280), const Size(320, 480)]) {
    for (final rank in [6, 123]) {
      testWidgets('rank $rank stays centered in the medal at $size',
          (tester) async {
        await _mount(tester, calls: [], panelSize: size, leaderboardRank: rank);
        final button = tester
            .getRect(find.byKey(const ValueKey('home-leaderboard-button')));
        // The circular face is at x346..398, y54..106 in the supplied 461x142
        // artwork, independently of the badge's crown and surrounding leaves.
        final face = Rect.fromLTWH(
            button.left + button.width * 346 / 461,
            button.top + button.height * 54 / 142,
            button.width * 52 / 461,
            button.height * 52 / 142);
        final label = find.byKey(const ValueKey('home-leaderboard-rank'));
        expect(tester.widget<Text>(label).data, '$rank');
        final number = tester.getRect(label);
        expect(number.center.dx, closeTo(face.center.dx, .1));
        expect(number.center.dy, closeTo(face.center.dy, .1));
        expect(face.inflate(.1).contains(number.topLeft), isTrue);
        expect(face.inflate(.1).contains(number.bottomRight), isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('unknown leaderboard rank displays a dash instead of a level',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _mount(tester, calls: [], leaderboardRank: null);
      final label = find.byKey(const ValueKey('home-leaderboard-rank'));
      expect(tester.widget<Text>(label).data, '—');
      expect(
          find.bySemanticsLabel('المتصدرون، الترتيب غير متاح'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('all six sidebar controls invoke their own action',
      (tester) async {
    final calls = <String>[];
    await _mount(tester, calls: calls);
    for (final action in _actions.entries) {
      await tester.tap(find.byTooltip(action.key));
      expect(calls.last, action.value);
    }
    expect(calls, _actions.values.toList());
    expect(tester.takeException(), isNull);
  });

  testWidgets('active VIP membership retains its club entry and action',
      (tester) async {
    final calls = <String>[];
    await _mount(tester, calls: calls, vip: true);
    for (final label in _actions.keys) {
      expect(find.byTooltip(label), findsOneWidget);
    }
    await tester.tap(find.byTooltip('نادي الأبطال'));
    expect(calls, ['vip']);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(190, 280), const Size(320, 480)]) {
    testWidgets('sidebar keeps separate full touch targets in $size',
        (tester) async {
      await _mount(tester, calls: [], panelSize: size);
      final panel = tester.getRect(find.byType(HomeActionSidebar));
      final controls = {
        for (final label in _actions.keys)
          label: tester.getRect(find.byTooltip(label)),
      };
      for (final control in controls.entries) {
        expect(control.value.shortestSide, greaterThanOrEqualTo(48),
            reason: '${control.key} needs a full touch target');
        expect(panel.inflate(.01).contains(control.value.topLeft), isTrue);
        expect(panel.inflate(.01).contains(control.value.bottomRight), isTrue);
      }
      final rects = controls.entries.toList();
      for (var first = 0; first < rects.length; first++) {
        for (var second = first + 1; second < rects.length; second++) {
          expect(rects[first].value.overlaps(rects[second].value), isFalse,
              reason: '${rects[first].key} overlaps ${rects[second].key}');
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('play frame animates while its label remains steady',
      (tester) async {
    final animation = _ManualAnimation();
    final previewKey = await _mount(tester, calls: [], animation: animation);
    final label = find.text('العب');
    final labelBounds = tester.getRect(label);
    final before = await _pixels(tester, previewKey);
    animation.advance(.5);
    await tester.pump();
    final after = await _pixels(tester, previewKey);
    expect(listEquals(before, after), isFalse,
        reason: 'The play frame should respond to the supplied animation');
    expect(tester.getRect(label), labelBounds,
        reason: 'The animated light must leave the play label steady');
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps the play frame and pressed artwork steady',
      (tester) async {
    final animation = _ManualAnimation();
    final calls = <String>[];
    final previewKey = await _mount(tester,
        calls: calls, animation: animation, reducedMotion: true);
    final before = await _pixels(tester, previewKey);
    animation.advance(.5);
    await tester.pump(const Duration(milliseconds: 250));
    final after = await _pixels(tester, previewKey);
    expect(listEquals(before, after), isTrue,
        reason: 'The ambient lobby animation must not move the play frame');

    final play = find.byTooltip('العب');
    final artwork = find.descendant(of: play, matching: find.byType(Image));
    final restingBounds = tester.getRect(artwork);
    final gesture = await tester.startGesture(tester.getCenter(play));
    await tester.pump(const Duration(milliseconds: 200));
    final pressedBounds = tester.getRect(artwork);
    expect(pressedBounds, restingBounds,
        reason: 'Reduced motion must also suppress the press scale transform');
    await gesture.up();
    await tester.pump();
    expect(calls, ['play']);
    expect(tester.takeException(), isNull);
  });
}
