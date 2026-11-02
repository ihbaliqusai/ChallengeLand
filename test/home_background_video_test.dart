import 'dart:async';

import 'package:challenge_land/widgets/home_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const factory = MethodChannel('challengeland/home-background');
  const session = MethodChannel('challengeland/home-background/42');
  final calls = <MethodCall>[];
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> nativeEvent(String method) async {
    await binding.defaultBinaryMessenger.handlePlatformMessage(
        session.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
        (_) {});
  }

  Future<void> mount(WidgetTester tester,
      {bool visible = true, bool reducedMotion = false}) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: TickerMode(
          enabled: visible,
          child: const HomeBackground(child: Text('Home controls')),
        ),
      ),
    ));
    await tester.pump();
  }

  setUp(() {
    calls.clear();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(factory, (_) async => 42);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(session,
        (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(factory, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(session, null);
  });

  testWidgets(
      'poster remains until a frame is ready; hidden/background video pauses',
      (tester) async {
    await mount(tester);
    expect(find.byType(Texture), findsNothing);
    expect(find.text('Home controls'), findsOneWidget);
    expect(calls.single.method, 'start');
    expect(calls.single.arguments, false);
    await nativeEvent('ready');
    await tester.pump();
    expect(tester.widget<Texture>(find.byType(Texture)).textureId, 42);
    await mount(tester, visible: false);
    expect(calls.last.method, 'setPaused');
    expect(calls.last.arguments, true);
    await mount(tester);
    expect(calls.last.arguments, false);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(calls.last.arguments, true);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls.last.arguments, false);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(calls.last.method, 'dispose');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a decoder created after leaving home is released without starting',
      (tester) async {
    final pending = Completer<int>();
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(factory, (_) => pending.future);
    await mount(tester);
    await tester.pumpWidget(const SizedBox());
    pending.complete(42);
    await tester.pump();
    expect(calls.map((c) => c.method), ['dispose']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'decoder failure releases the video and keeps usable home controls',
      (tester) async {
    await mount(tester);
    await nativeEvent('failed');
    await tester.pump();
    expect(calls.last.method, 'dispose');
    expect(find.byType(Texture), findsNothing);
    expect(find.text('Home controls'), findsOneWidget);
    await nativeEvent('ready');
    await tester.pump();
    expect(find.byType(Texture), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion avoids opening a decoder and can enable it later',
      (tester) async {
    await mount(tester, reducedMotion: true);
    expect(calls, isEmpty);
    await mount(tester);
    await tester.pump();
    expect(calls.single.method, 'start');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
