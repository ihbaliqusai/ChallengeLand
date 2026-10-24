import 'dart:async';

import 'package:challenge_land/widgets/startup_gate.dart';
import 'package:challenge_land/screens/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'splash tolerates the zero size before Android measures its window',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size.zero),
        child: SplashScreen(),
      ),
    ));
    expect(tester.takeException(), isNull);
    final logo = tester.widget<Image>(find.byType(Image).last);
    expect((logo.image as ResizeImage).width, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('draws the loading window while platform startup is pending',
      (tester) async {
    final initialization = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(StartupGate(
      initialize: () {
        calls++;
        return initialization.future;
      },
      loading: const MaterialApp(home: Text('loading')),
      ready: const MaterialApp(home: Text('ready')),
    ));
    expect(find.text('loading'), findsOneWidget);
    expect(find.text('ready'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('loading'), findsOneWidget);
    expect(calls, 1);
    initialization.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('late startup completion does not update a disposed window',
      (tester) async {
    final initialization = Completer<void>();
    await tester.pumpWidget(StartupGate(
      initialize: () => initialization.future,
      loading: const MaterialApp(home: SizedBox()),
      ready: const MaterialApp(home: Text('ready')),
    ));
    await tester.pumpWidget(const SizedBox());
    initialization.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
