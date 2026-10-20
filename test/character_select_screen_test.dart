import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/models/game_character.dart';
import 'package:challenge_land/screens/character/character_select_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeAppState extends ChangeNotifier implements AppState {
  int _selected = 1;
  int purchaseRequests = 0;
  final Set<int> _unlocked = {0, 1, 6}; // Khaled, Omar, Sarah unlocked

  @override
  bool isCharacterUnlocked(GameCharacter character) =>
      _unlocked.contains(character.index) || character.unlock.isFree;

  @override
  bool get hasChosenCharacter => true;

  @override
  int get selectedCharacterIndex => _selected;

  @override
  int get level => 5;

  @override
  int get coins => 25000;

  @override
  int get gems => 500;

  @override
  Future<bool> selectCharacter(int index) async {
    _selected = index;
    notifyListeners();
    return true;
  }

  @override
  Future<bool> purchaseCharacter(GameCharacter character) async {
    purchaseRequests++;
    _unlocked.add(character.index);
    notifyListeners();
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await (FontLoader('NotoSansArabic')
          ..addFont(rootBundle.load('assets/fonts/NotoSansArabic.ttf')))
        .load();
    final artwork =
        await rootBundle.load('assets/characters/contestant_omar.png');
    expect(artwork.lengthInBytes, greaterThan(0));
  });

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(800, 360),
    AppState? state,
    double textScale = 1,
    int? initialIndex,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final appState = state ?? _FakeAppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          theme: ThemeData.dark().copyWith(
            textTheme:
                ThemeData.dark().textTheme.apply(fontFamily: 'NotoSansArabic'),
          ),
          home: CharacterSelectScreen(initialIndex: initialIndex),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders stage, rail and allows selecting different characters',
      (tester) async {
    final appState = _FakeAppState();
    await mount(tester, state: appState);

    // Names belong to matches; the picker identifies characters by artwork.
    for (final character in CharacterCatalog.all) {
      expect(find.textContaining(character.nameAr), findsNothing);
    }
    expect(find.text('شخصيتك الحالية'), findsAtLeastNWidgets(1));

    // Tap Khaled in the rail
    final khaled = find.byKey(const ValueKey('character-rail-khaled'));
    await tester.ensureVisible(khaled);
    await tester.tap(khaled);
    await tester.pumpAndSettle();

    expect(find.text('المنافس الهادئ'), findsAtLeastNWidgets(1));

    // Tap Choose button for Khaled
    await tester.ensureVisible(find.text('اختيار الشخصية'));
    await tester.tap(find.text('اختيار الشخصية'));
    await tester.pumpAndSettle();

    expect(appState.selectedCharacterIndex, 0);
  });

  testWidgets('opening character inspection sheet reveals bio and skills',
      (tester) async {
    await mount(tester);

    // Tap the Inspect button
    final inspectBtn = find.byIcon(Icons.zoom_in_rounded).first;
    await tester.ensureVisible(inspectBtn);
    await tester.tap(inspectBtn);
    await tester.pumpAndSettle();

    // Inspection modal is open
    expect(find.text('نبذة عن المتسابق'), findsOneWidget);
    expect(find.text('المهارات والقدرات'), findsOneWidget);
    expect(find.text('سرعة البديهة وردود الفعل'), findsOneWidget);
    expect(find.textContaining('عمر'), findsNothing);

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('character-select-screen')),
    );
    await tester.runAsync(() async {
      final rendered = await boundary.toImage(pixelRatio: 2);
      final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build').create(recursive: true);
      await File('build/character-inspect-sheet.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      rendered.dispose();
    });

    // Switch to appearance tab
    await tester.tap(find.text('المظهر في اللعبة'));
    await tester.pumpAndSettle();

    expect(find.text('منصة مسرح المسابقة'), findsOneWidget);
    expect(find.text('متصدر قائمة الأبطال'), findsOneWidget);
    expect(find.textContaining('عمر'), findsNothing);

    // Close the modal
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('نبذة عن المتسابق'), findsNothing);
  });

  testWidgets('preview and cancelled purchase keep the current character',
      (tester) async {
    final state = _FakeAppState();
    await mount(tester, state: state);
    final fahad = find.byKey(const ValueKey('character-rail-fahad'));
    await tester.ensureVisible(fahad);
    await tester.tap(fahad);
    await tester.pumpAndSettle();
    expect(state.selectedCharacterIndex, 1);
    expect(state.purchaseRequests, 0);
    final unlock = find.text('فتح وتفعيل (12K كوين)');
    await tester.tap(unlock);
    await tester.pumpAndSettle();
    expect(find.text('فتح الشخصية'), findsOneWidget);
    expect(find.textContaining('فهد'), findsNothing);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(state.selectedCharacterIndex, 1);
    expect(state.purchaseRequests, 0);
    await tester.tap(unlock);
    await tester.pumpAndSettle();
    await tester.tap(find.text('فتح مقابل 12K'));
    await tester.pumpAndSettle();
    expect(state.selectedCharacterIndex, 2);
    expect(state.purchaseRequests, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('level-locked character remains previewable without selecting it',
      (tester) async {
    final state = _FakeAppState();
    await mount(tester, state: state);
    final mazen = find.byKey(const ValueKey('character-rail-mazen'));
    await tester.ensureVisible(mazen);
    await tester.tap(mazen);
    await tester.pumpAndSettle();
    expect(find.text('تُفتح عند المستوى 8'), findsAtLeastNWidgets(1));
    await tester.tap(find.byIcon(Icons.zoom_in_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('استعراض الشخصية'), findsOneWidget);
    expect(find.textContaining('مازن'), findsNothing);
    expect(state.selectedCharacterIndex, 1);
    expect(state.purchaseRequests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'all eight additions preview without changing the saved character',
      (tester) async {
    final state = _FakeAppState();
    await mount(tester, state: state);
    for (final character in CharacterCatalog.all.skip(8)) {
      await tester.runAsync(() => precacheImage(
          AssetImage(character.fullBodyAsset),
          tester.element(find.byType(CharacterSelectScreen))));
      final tile = find.byKey(ValueKey('character-rail-${character.id}'));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text(character.tagAr), findsOneWidget);
      expect(find.textContaining(character.nameAr), findsNothing);
      final artwork = find.byWidgetPredicate((widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == character.fullBodyAsset);
      expect(
          tester
              .widget<RawImage>(
                  find.descendant(of: artwork, matching: find.byType(RawImage)))
              .image,
          isNotNull);
      expect(state.selectedCharacterIndex, 1);
      expect(state.purchaseRequests, 0);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('فتح وتفعيل (16K كوين)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فتح مقابل 16K'));
    await tester.pumpAndSettle();
    expect(state.selectedCharacterIndex, 15);
    expect(state.purchaseRequests, 1);
    expect(tester.takeException(), isNull);
    ScaffoldMessenger.of(tester.element(find.byType(CharacterSelectScreen)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('character-select-screen')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('build/character-select-new-pack.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });

  testWidgets('store preview focuses its character before a purchase',
      (tester) async {
    final state = _FakeAppState();
    await mount(tester, state: state, initialIndex: 14);
    expect(find.text('المبدع التقني'), findsOneWidget);
    expect(state.selectedCharacterIndex, 1);
    expect(state.purchaseRequests, 0);
    expect(find.text('فتح وتفعيل (650 جوهرة)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(360, 640), const Size(640, 320)]) {
    testWidgets('character controls remain reachable with larger text at $size',
        (tester) async {
      await mount(tester, size: size, textScale: 1.5);
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.zoom_in_rounded).last.hitTestable(),
          findsOneWidget);
      final khaled = find.byKey(const ValueKey('character-rail-khaled'));
      await tester.ensureVisible(khaled);
      await tester.tap(khaled);
      await tester.pumpAndSettle();
      expect(find.text('اختيار الشخصية').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [
    const Size(800, 360), // standard landscape
    const Size(640, 320), // compact landscape
    const Size(390, 844), // mobile portrait
  ]) {
    testWidgets('character select screen fits size $size without overflow',
        (tester) async {
      await mount(tester, size: size);
      expect(tester.takeException(), isNull);

      // Export rendered preview image
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('character-select-screen')),
      );
      final name = size.width > size.height ? 'landscape' : 'portrait';
      final previousShadows = debugDisableShadows;
      debugDisableShadows = false;
      boundary.markNeedsPaint();
      await tester.pump();
      try {
        await tester.runAsync(() async {
          final rendered = await boundary.toImage(pixelRatio: 2);
          final bytes =
              await rendered.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build').create(recursive: true);
          await File('build/character-select-$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          rendered.dispose();
        });
      } finally {
        debugDisableShadows = previousShadows;
      }
    });
  }
}
