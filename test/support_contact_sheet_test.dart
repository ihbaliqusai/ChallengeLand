import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/widgets/support_contact_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _User implements User {
  @override
  String get uid => 'support-player';
  @override
  String get displayName => 'لاعب تجريبي';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _State extends ChangeNotifier implements AppState {
  @override
  User get user => _User();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const channel = MethodChannel('millionaire/native');
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final requests = <MethodCall>[];
  var canOpen = true;
  String? clipboard;

  setUp(() {
    requests.clear();
    canOpen = true;
    clipboard = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      requests.add(call);
      return canOpen;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> openContact(WidgetTester tester) async {
    final state = _State();
    addTearDown(state.dispose);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
        Provider<NativeBridgeService>(create: (_) => NativeBridgeService()),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showSupportContact(context),
                child: const Text('تواصل معنا'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('تواصل معنا'));
    await tester.pumpAndSettle();
  }

  Future<void> continueEmail(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('support-open-email'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('empty messages stay in the form without opening an email app',
      (tester) async {
    await openContact(tester);
    await continueEmail(tester);
    expect(find.text('اكتب رسالتك أولاً'), findsOneWidget);
    expect(requests, isEmpty);
    expect(find.byType(SupportContactSheet), findsOneWidget);
  });

  testWidgets(
      'problem reports prepare a draft for the team and retain the text',
      (tester) async {
    await openContact(tester);
    await tester.tap(find.text('مشكلة'));
    const message = 'حدث خطأ في المباراة؟ النتيجة: 2 & 3 + 5\nأرجو المساعدة.';
    await tester.enterText(
        find.byKey(const ValueKey('support-message')), message);
    await continueEmail(tester);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'composeSupportEmail');
    final args = requests.single.arguments as Map;
    expect(args['recipient'], SupportContactSheet.email);
    expect(args['subject'], 'أرض التحدي - مشكلة');
    expect(args['body'], contains(message));
    expect(args['body'], contains('معرّف اللاعب: support-player'));
    expect(args['body'], contains('اسم اللاعب: لاعب تجريبي'));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        message);
    expect(find.textContaining('أكمل الإرسال من هناك'), findsOneWidget);
    expect(find.text('تم إرسال الرسالة'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing email apps allow copying the suggestion and team email',
      (tester) async {
    canOpen = false;
    await openContact(tester);
    await tester.tap(find.text('اقتراح'));
    await tester.enterText(find.byKey(const ValueKey('support-message')),
        'أقترح إضافة تحديات جديدة');
    await continueEmail(tester);
    expect(find.textContaining('تعذر فتح تطبيق البريد'), findsOneWidget);
    expect(find.textContaining('أكمل الإرسال من هناك'), findsNothing);
    final copy = find.text('نسخ البريد والرسالة');
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(clipboard, contains(SupportContactSheet.email));
    expect(clipboard, contains('أرض التحدي - اقتراح'));
    expect(clipboard, contains('أقترح إضافة تحديات جديدة'));
    expect(find.text('تم نسخ البريد والرسالة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contact form stays usable in compact windows with a keyboard',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    for (final size in [const Size(800, 360), const Size(320, 640)]) {
      tester.view.physicalSize = size;
      tester.view.viewInsets = const FakeViewPadding(bottom: 150);
      await openContact(tester);
      await tester.enterText(find.byKey(const ValueKey('support-message')),
          'سؤالي حول حسابي في اللعبة');
      await continueEmail(tester);
      expect(find.textContaining('أكمل الإرسال من هناك'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  test('native launch failures return a copy fallback to the form', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'EMAIL_UNAVAILABLE');
    });
    expect(
        await NativeBridgeService().composeSupportEmail(
          recipient: SupportContactSheet.email,
          subject: 'أرض التحدي - سؤال',
          body: 'كيف أستعيد حسابي؟',
        ),
        isFalse);
  });
}
