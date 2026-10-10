import 'dart:async';

import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/services/cross_promo_service.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/widgets/cross_promo_millionaire_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Bridge extends NativeBridgeService {
  Future<String?> Function() launch = () async => 'opened_market';
  int launchCount = 0;
  @override
  Future<bool> isAppInstalled(String packageName) async => false;
  @override
  Future<String?> launchAppOrPlayStore({
    required String packageName,
    String? playStoreUrl,
  }) {
    expect(packageName, CrossPromoService.millionairePackage);
    launchCount++;
    return launch();
  }
}

class _AppState extends ChangeNotifier implements AppState {
  @override
  get currentUser => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Promo extends CrossPromoService {
  _Promo({this.installed = false}) : super(bridge: _Bridge());
  final bool installed;
  final installation = Completer<bool>();
  final rewardCheck = Completer<bool>();
  final opening = Completer<String?>();
  int opens = 0;
  @override
  bool get isMillionaireInstalled => installed;
  @override
  Future<bool> checkInstallation() => installation.future;
  @override
  Future<bool> checkRewardClaimed({String? uid}) => rewardCheck.future;
  @override
  Future<String?> openMillionaireApp() {
    opens++;
    return opening.future;
  }

  @override
  Future<CrossPromoClaimResult> claimDownloadReward(
          BuildContext context) async =>
      CrossPromoClaimResult.failed;
}

Future<void> _showPromo(WidgetTester tester, _Promo promo) async {
  await tester.binding.setSurfaceSize(const Size(460, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final state = _AppState();
  addTearDown(state.dispose);
  addTearDown(promo.dispose);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AppState>.value(value: state),
      ChangeNotifierProvider<CrossPromoService>.value(value: promo),
    ],
    child: MaterialApp(home: Scaffold(body: Builder(builder: (context) {
      return TextButton(
        onPressed: () => CrossPromoMillionaireDialog.show(context),
        child: const Text('عرض اللعبة المقترحة'),
      );
    }))),
  ));
  await tester.tap(find.text('عرض اللعبة المقترحة'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('simultaneous launch requests open one destination and allow retry',
      () async {
    final bridge = _Bridge();
    final pending = Completer<String?>();
    bridge.launch = () => pending.future;
    final service = CrossPromoService(bridge: bridge);
    final first = service.openMillionaireApp();
    final second = service.openMillionaireApp();
    expect(identical(first, second), isTrue);
    expect(bridge.launchCount, 1);
    pending.complete('opened_web');
    expect(await first, 'opened_web');
    expect(await second, 'opened_web');
    bridge.launch = () async => 'launched_app';
    expect(await service.openMillionaireApp(), 'launched_app');
    expect(bridge.launchCount, 2);
    // Allow the optional local bookkeeping to complete before disposal.
    await Future<void>.delayed(Duration.zero);
    service.dispose();
  });

  testWidgets('a stalled native launch times out and can be retried',
      (tester) async {
    final bridge = _Bridge();
    bridge.launch = () => Completer<String?>().future;
    final service = CrossPromoService(bridge: bridge);
    String? result = 'pending';
    service.openMillionaireApp().then((value) => result = value);
    await tester.pump(const Duration(seconds: 8));
    expect(result, isNull);
    bridge.launch = () async => 'opened_market';
    final retry = service.openMillionaireApp();
    await tester.pump();
    expect(await retry, 'opened_market');
    expect(bridge.launchCount, 2);
    service.dispose();
  });

  testWidgets(
      'opening remains available while installation and rewards are pending',
      (tester) async {
    final promo = _Promo();
    await _showPromo(tester, promo);
    final button = find.byType(ElevatedButton);
    expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    await tester.pump();
    expect(promo.opens, 1);
    expect(find.text('جاري الفتح...'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    promo.opening.complete('opened_market');
    await tester.pump();
    expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('installed game opens independently of its unclaimed reward',
      (tester) async {
    final promo = _Promo(installed: true);
    await _showPromo(tester, promo);
    promo.installation.complete(true);
    await tester.pump();
    expect(find.text('فتح اللعبة واللعب الآن 🎮'), findsOneWidget);
    expect(find.text('استلام 80 جوهرة الآن! 💎'), findsOneWidget);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(promo.opens, 1);
    promo.opening.complete('launched_app');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CrossPromoMillionaireDialog), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'launch failure is visible and leaves the button available for retry',
      (tester) async {
    final promo = _Promo();
    await _showPromo(tester, promo);
    await tester.tap(find.byType(ElevatedButton));
    promo.opening.complete(null);
    await tester.pump();
    expect(find.text('تعذّر فتح اللعبة أو المتجر. حاول مرة أخرى.'),
        findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull);
    expect(find.byType(CrossPromoMillionaireDialog), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
