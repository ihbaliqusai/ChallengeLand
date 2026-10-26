import 'support/asset_images.dart';
import 'package:challenge_land/core/shared_assets.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/models/game_character.dart';
import 'package:challenge_land/screens/character/character_select_screen.dart';
import 'package:challenge_land/widgets/game_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:challenge_land/widgets/guide/page_guide.dart';
import 'package:challenge_land/widgets/guide/home_guide_tour_overlay.dart';

class _FakeAppState extends ChangeNotifier implements AppState {
  int _selected = 1;
  int purchaseRequests = 0;
  bool chosen = true;
  final Set<int> _unlocked = {0, 1, 6}; // Khaled, Omar, Sarah unlocked

  @override
  bool isCharacterUnlocked(GameCharacter character) =>
      _unlocked.contains(character.index) || character.unlock.isFree;

  @override
  bool get hasChosenCharacter => chosen;

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
          ..addFont(
              SharedAssets.bundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await (FontLoader('NotoSansArabic')
          ..addFont(
              SharedAssets.bundle.load('assets/fonts/NotoSansArabic.ttf')))
        .load();
    final artwork =
        await SharedAssets.bundle.load('assets/characters/contestant_omar.png');
    expect(artwork.lengthInBytes, greaterThan(0));
  });

  setUp(() => SharedPreferences.setMockInitialValues({
        PageGuide.preferenceKey('characters'): true,
      }));

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(800, 360),
    AppState? state,
    double textScale = 1,
    int? initialIndex,
    bool fixedCanvas = false,
    bool forced = false,
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
            child: fixedCanvas ? GameViewport(child: child!) : child!,
          ),
          theme: ThemeData.dark().copyWith(
            textTheme:
                ThemeData.dark().textTheme.apply(fontFamily: 'NotoSansArabic'),
          ),
          home:
              CharacterSelectScreen(initialIndex: initialIndex, forced: forced),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future.wait([
          for (final image in tester.widgetList<Image>(find.byType(Image)))
            precacheImage(image.image,
                tester.element(find.byType(CharacterSelectScreen))),
        ]));
    await tester.pumpAndSettle();
  }

  for (final (size, forced) in [
    (const Size(960, 540), false),
    (const Size(640, 360), false),
    (const Size(390, 780), false),
    (const Size(960, 540), true),
  ]) {
    testWidgets(
        'character guide explains real controls at $size forced=$forced',
        (tester) async {
      final state = _FakeAppState()..chosen = !forced;
      await mount(tester,
          size: size,
          state: state,
          initialIndex: 2,
          fixedCanvas: true,
          forced: forced);
      final rail = tester
          .widget<SingleChildScrollView>(
              find.byKey(const ValueKey('character-scroll-rail')))
          .controller!;
      final originalOffset = rail.offset;
      expect(find.byTooltip('شرح الصفحة'), findsNothing);
      tester.state<PageGuideState>(find.byType(PageGuide)).start();
      await tester.pump();
      final tour = tester
          .widget<HomeGuideTourOverlay>(find.byType(HomeGuideTourOverlay));
      for (var index = 0; index < tour.steps.length; index++) {
        for (var frame = 0; frame < 5; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull, reason: tour.steps[index].title);
        final speechScroll = tester.state<ScrollableState>(find
            .descendant(
                of: find.byKey(const ValueKey('guide-speech-bubble')),
                matching: find.byType(Scrollable))
            .first);
        expect(speechScroll.position.maxScrollExtent, lessThanOrEqualTo(1),
            reason: tour.steps[index].title);
        final painter = tester
            .widget<CustomPaint>(find.byKey(const ValueKey('guide-spotlight')))
            .painter! as SpotlightPainter;
        if (tour.steps[index].targetKey != null) {
          expect(painter.targetRect, isNotNull,
              reason: tour.steps[index].title);
          final surface = tester.renderObject<RenderBox>(
              find.byKey(const ValueKey('guide-spotlight')));
          final visible = Rect.fromPoints(
              surface.localToGlobal(painter.targetRect!.topLeft),
              surface.localToGlobal(painter.targetRect!.bottomRight));
          expect(
              tester
                  .getRect(find.byKey(const ValueKey('guide-stage')))
                  .overlaps(visible),
              isFalse,
              reason: tour.steps[index].title);
        }
        expect(state.selectedCharacterIndex, 1);
        expect(state.purchaseRequests, 0);
        if (const bool.fromEnvironment('GUIDE_PREVIEW')) {
          await tester.tap(find.byKey(const ValueKey('guide-speech-bubble')));
          await tester.pump(const Duration(milliseconds: 200));
          final images = tester
              .widgetList<Image>(find.byType(Image))
              .map((image) => image.image)
              .toSet();
          await tester.runAsync(() => Future.wait(images.map((image) =>
              precacheImage(
                  image, tester.element(find.byType(CharacterSelectScreen))))));
          await tester.pump();
          final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('character-select-screen')));
          await tester.runAsync(() async {
            final snapshot = await boundary.toImage(pixelRatio: 1.5);
            final bytes =
                await snapshot.toByteData(format: ui.ImageByteFormat.png);
            await File(
                    'build/character-guide-${size.width.toInt()}-$forced-$index.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            snapshot.dispose();
          });
        }
        await tester.tap(find.text(index == tour.steps.length - 1
            ? 'اختر شخصيتك'
            : index == 0
                ? 'ابدأ الجولة'
                : 'التالي'));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(find.byType(HomeGuideTourOverlay), findsNothing);
      expect(find.text('فتح وتفعيل (12K كوين)'), findsOneWidget);
      expect(state.selectedCharacterIndex, 1);
      expect(state.purchaseRequests, 0);
      expect(rail.offset, closeTo(originalOffset, .1));
      expect(state.hasChosenCharacter, !forced);
      if (forced) expect(find.byTooltip('رجوع'), findsNothing);
      expect(
          (await SharedPreferences.getInstance())
              .getBool(PageGuide.preferenceKey('characters')),
          isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    });
  }

  testWidgets(
      'character picker preserves the same arrangement on every display',
      (tester) async {
    for (final size in const [
      Size(640, 320),
      Size(800, 360),
      Size(1280, 800)
    ]) {
      await mount(tester, size: size, textScale: 2, fixedCanvas: true);
      final context = tester.element(find.byType(CharacterSelectScreen));
      final canvas = MediaQuery.sizeOf(context);
      expect(canvas.width / canvas.height,
          closeTo(size.width / size.height, .001));
      expect(tester.getRect(find.byType(Scaffold).first),
          rectMoreOrLessEquals(Offset.zero & size, epsilon: .01));
      final right =
          tester.getRect(find.byKey(const ValueKey('character-rail-mahmoud')));
      final middle =
          tester.getRect(find.byKey(const ValueKey('character-rail-omar')));
      final left =
          tester.getRect(find.byKey(const ValueKey('character-rail-khaled')));
      expect(right.left, greaterThan(middle.right));
      expect(middle.left, greaterThan(left.right));
      expect(right.top, closeTo(left.top, .01));
      await tester.tap(find.byKey(const ValueKey('character-rail-khaled')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('renders stage, rail and allows selecting different characters',
      (tester) async {
    final appState = _FakeAppState();
    await mount(tester, state: appState);

    // Names belong to matches; the picker identifies characters by artwork.
    for (final character in CharacterCatalog.all) {
      expect(find.text(character.nameAr), findsNothing);
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

  testWidgets(
      'swipe hint and dots reveal more characters without selecting them',
      (tester) async {
    final state = _FakeAppState();
    await mount(tester, state: state);
    expect(find.text('اسحب لليمين للمزيد'), findsOneWidget);
    final rail = find.byKey(const ValueKey('character-scroll-rail'));
    final initial =
        tester.getRect(find.byKey(const ValueKey('character-rail-mahmoud')));
    await tester.drag(rail, const Offset(180, 0));
    await tester.pumpAndSettle();
    expect(
        tester
            .getRect(find.byKey(const ValueKey('character-rail-mahmoud')))
            .left,
        greaterThan(initial.left));
    await tester.tap(find.byKey(const ValueKey('character-page-2')));
    await tester.pumpAndSettle();
    expect(find.text('اسحب لليسار للعودة'), findsOneWidget);
    expect(find.byKey(const ValueKey('character-rail-adam')).hitTestable(),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('character-swipe-hint')));
    await tester.pumpAndSettle();
    expect(find.text('اسحب لليمين للمزيد'), findsOneWidget);
    expect(state.selectedCharacterIndex, 1);
    expect(state.purchaseRequests, 0);
    expect(tester.takeException(), isNull);
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

  testWidgets('preview keeps selection and purchase unlocks directly',
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
    expect(find.text('فتح الشخصية'), findsNothing);
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
          AssetImage(character.fullBodyAsset, bundle: SharedAssets.bundle),
          tester.element(find.byType(CharacterSelectScreen))));
      final tile = find.byKey(ValueKey('character-rail-${character.id}'));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text(character.tagAr), findsOneWidget);
      expect(find.textContaining(character.nameAr), findsNothing);
      final artwork = find.descendant(
        of: find.byKey(const ValueKey('character-standing-preview')),
        matching: find.byWidgetPredicate((widget) =>
            widget is Image &&
            underlyingAsset(widget.image) is AssetImage &&
            (underlyingAsset(widget.image) as AssetImage).assetName ==
                character.fullBodyAsset),
      );
      await tester.runAsync(() => Future.wait([
            for (final image in tester.widgetList<Image>(artwork))
              precacheImage(image.image, tester.element(artwork)),
          ]));
      await tester.pump();
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

  testWidgets('reference layout shows three columns and a full-body reflection',
      (tester) async {
    final state = _FakeAppState()
      .._selected = 4
      .._unlocked.add(4);
    await mount(tester, state: state, size: const Size(1100, 454));
    final standing = find.byKey(const ValueKey('character-standing-preview'));
    final reflection =
        find.byKey(const ValueKey('character-mirror-reflection'));
    for (final preview in [standing, reflection]) {
      final artwork = find.descendant(
        of: preview,
        matching: find.byWidgetPredicate((widget) =>
            widget is Image &&
            underlyingAsset(widget.image) is AssetImage &&
            (underlyingAsset(widget.image) as AssetImage).assetName ==
                CharacterCatalog.byIndex(4).fullBodyAsset),
      );
      expect(artwork, findsOneWidget);
      await tester.runAsync(() => precacheImage(
          tester.widget<Image>(artwork).image, tester.element(artwork)));
    }
    final right =
        tester.getRect(find.byKey(const ValueKey('character-rail-mahmoud')));
    final middle =
        tester.getRect(find.byKey(const ValueKey('character-rail-omar')));
    final left =
        tester.getRect(find.byKey(const ValueKey('character-rail-khaled')));
    expect(right.left, greaterThan(middle.right));
    expect(middle.left, greaterThan(left.right));
    expect(left.left, greaterThan(1100 * 0.46));
    expect(right.top, closeTo(middle.top, 0.01));
    expect(right.width, greaterThan(150));
    expect(find.byKey(const ValueKey('character-selected-mahmoud')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('character-select-screen')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build').create(recursive: true);
      await File('build/character-select-reference.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });

  testWidgets('device insets do not shift the characters away from the mirror',
      (tester) async {
    tester.view.padding = const FakeViewPadding(left: 72, right: 24);
    addTearDown(tester.view.resetPadding);
    await mount(tester, size: const Size(1100, 454), initialIndex: 3);
    final standing = tester
        .getRect(find.byKey(const ValueKey('character-standing-preview')));
    final reflection = tester
        .getRect(find.byKey(const ValueKey('character-mirror-reflection')));
    expect(standing.left, closeTo(1100 * 0.44 * 0.095, 0.1));
    expect(standing.bottom, closeTo(454 * 0.93, 0.1));
    expect(reflection.center.dx, inInclusiveRange(1100 * 0.28, 1100 * 0.32));
    expect(standing.right, lessThan(1100 * 0.23));
    expect(tester.takeException(), isNull);
  });

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
