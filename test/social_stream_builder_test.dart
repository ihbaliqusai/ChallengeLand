import 'dart:async';
import 'package:challenge_land/widgets/social_stream_builder.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'silent connection stops loading, supports retry and recovers on late data',
      (tester) async {
    final source = StreamController<int>.broadcast();
    var retries = 0;
    await tester.pumpWidget(MaterialApp(
        home: SocialStreamBuilder<int>(
      stream: source.stream,
      onRetry: () => retries++,
      builder: (_, snapshot) => Text('value:${snapshot.data}'),
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    expect(retries, 1);
    source.add(42);
    await tester.pump();
    await tester.pump();
    expect(find.text('value:42'), findsOneWidget);
    await tester.pump(const Duration(minutes: 2));
    expect(find.text('value:42'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await source.close();
  });

  for (final code in ['permission-denied', 'failed-precondition']) {
    testWidgets('$code is actionable rather than an infinite spinner',
        (tester) async {
      final source = StreamController<int>.broadcast();
      await tester.pumpWidget(MaterialApp(
          home: SocialStreamBuilder<int>(
        stream: source.stream,
        onRetry: () {},
        builder: (_, snapshot) => Text('${snapshot.data}'),
      )));
      source.addError(FirebaseException(plugin: 'cloud_firestore', code: code));
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      expect(
          find.textContaining(code == 'permission-denied'
              ? 'غير متاحة لهذا الحساب'
              : 'قيد التهيئة'),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await source.close();
    });
  }
}
