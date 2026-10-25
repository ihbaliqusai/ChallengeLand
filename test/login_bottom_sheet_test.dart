import 'dart:async';

import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/core/shared_assets.dart';
import 'package:challenge_land/screens/auth/login_bottom_sheet.dart';
import 'package:challenge_land/widgets/sign_in_required_action.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _User implements User {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _State extends ChangeNotifier implements AppState {
  @override
  User? user;
  @override
  bool isOnline = true;
  @override
  bool isBusy = false;
  int requests = 0;
  Object? failure;
  Completer<void>? pending;

  @override
  Future<void> signInWithGoogle() async {
    requests++;
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
    user = _User();
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    for (final font in ['Baloo', 'NotoSansArabic']) {
      await (FontLoader(font)
            ..addFont(SharedAssets.bundle.load(font == 'Baloo'
                ? 'assets/fonts/baloo.ttf'
                : 'assets/fonts/NotoSansArabic.ttf')))
          .load();
    }
  });

  Future<void> showSheet(WidgetTester tester, _State state,
      {VoidCallback? onAction}) async {
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            fontFamily: 'Baloo'),
        home: Scaffold(
          body: Center(
            child: SignInRequiredAction(
              child: TextButton(
                  onPressed: onAction ?? () {}, child: const Text('العب')),
            ),
          ),
        ),
      ),
    ));
    await tester.tapAt(tester.getCenter(find.text('العب')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('Google sign-in unlocks the home action directly',
      (tester) async {
    final state = _State();
    addTearDown(state.dispose);
    var actions = 0;
    await showSheet(tester, state, onAction: () => actions++);
    expect(actions, 0);
    await tester.tap(find.byKey(const ValueKey('google-sign-in')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.requests, 1);
    expect(find.byType(LoginBottomSheet), findsNothing);
    await tester.tap(find.text('العب'));
    expect(actions, 1);
    expect(find.byType(LoginBottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline sign-in stays on the home and can retry after reconnect',
      (tester) async {
    final state = _State()..isOnline = false;
    addTearDown(state.dispose);
    await showSheet(tester, state);
    await tester.tap(find.byKey(const ValueKey('google-sign-in')));
    await tester.pump();
    expect(state.requests, 0);
    expect(find.text('تحقق من اتصال الإنترنت ثم حاول مجدداً'), findsOneWidget);
    state.isOnline = true;
    await tester.tap(find.byKey(const ValueKey('google-sign-in')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.requests, 1);
    expect(find.byType(LoginBottomSheet), findsNothing);
  });

  testWidgets('cancelled Google picker stays open and permits another attempt',
      (tester) async {
    final state = _State()..failure = FirebaseAuthException(code: 'cancelled');
    addTearDown(state.dispose);
    await showSheet(tester, state);
    await tester.tap(find.byKey(const ValueKey('google-sign-in')));
    await tester.pump();
    expect(find.byType(LoginBottomSheet), findsOneWidget);
    expect(
        find.text('تعذر تسجيل الدخول. يرجى المحاولة مرة أخرى'), findsNothing);
    state.failure = null;
    await tester.tap(find.byKey(const ValueKey('google-sign-in')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.requests, 2);
    expect(find.byType(LoginBottomSheet), findsNothing);
  });

  testWidgets(
      'pending login prevents duplicate requests and tolerates dismissal',
      (tester) async {
    final state = _State()..pending = Completer<void>();
    addTearDown(state.dispose);
    await showSheet(tester, state);
    final google = find.byKey(const ValueKey('google-sign-in'));
    await tester.tap(google);
    await tester.pump();
    await tester.tap(google);
    await tester.pump();
    expect(state.requests, 1);
    await tester.tap(find.byKey(const ValueKey('close-login-sheet')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    state.pending!.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(LoginBottomSheet), findsNothing);
  });

  testWidgets('sheet fits landscape and portrait windows at the bottom',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [
      const Size(800, 360),
      const Size(320, 640),
      const Size(1200, 800),
    ]) {
      await tester.binding.setSurfaceSize(size);
      final state = _State();
      await showSheet(tester, state);
      final bounds = tester.getRect(find.byType(LoginBottomSheet));
      expect(bounds.bottom, size.height);
      expect(bounds.width, lessThanOrEqualTo(440));
      if (size.width >= 440) expect(bounds.width, 440);
      expect(bounds.top, greaterThanOrEqualTo(0));
      expect(find.byKey(const ValueKey('google-sign-in')).hitTestable(),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    }
  });
}
