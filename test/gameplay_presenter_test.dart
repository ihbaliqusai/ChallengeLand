import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:challenge_land/widgets/guide/host_guide_character.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameplayPresenter Widget Tests', () {
    testWidgets('renders all composite layers and matches native proportions',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: GameplayPresenter(
                height: 160,
                isTalking: false,
                gesture: PresenterGesture.showHand,
                isFlipped: true,
                enableBreathing: false,
                enableBlinking: false,
                enableEyebrows: false,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // GameplayPresenter exists
      expect(find.byType(GameplayPresenter), findsOneWidget);

      // Verify Image widgets are rendered for body, head, and mouth
      final images = tester.widgetList<Image>(find.byType(Image));
      expect(images.length, greaterThanOrEqualTo(3));

      // When silent, mouth should be mouth_05
      final mouthImage = images.firstWhere((img) {
        final asset = (img.image as AssetImage).assetName;
        return asset.contains('mouth_');
      });
      expect(
          (mouthImage.image as AssetImage).assetName, contains('mouth_05.png'));

      // Body should have transitioned to person_06 (showHand gesture)
      final bodyImage = images.firstWhere((img) {
        final asset = (img.image as AssetImage).assetName;
        return asset.contains('person_');
      });
      expect(
          (bodyImage.image as AssetImage).assetName, contains('person_06.png'));
    });

    testWidgets('animates lip-sync mouth frames when talking', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: GameplayPresenter(
                height: 160,
                isTalking: true,
                gesture: PresenterGesture.idle,
                isFlipped: false,
                enableBreathing: false,
                enableBlinking: false,
                enableEyebrows: false,
              ),
            ),
          ),
        ),
      );

      // Initial tick
      await tester.pump(const Duration(milliseconds: 120));

      final images = tester.widgetList<Image>(find.byType(Image));
      final mouthImage = images.firstWhere((img) {
        final asset = (img.image as AssetImage).assetName;
        return asset.contains('mouth_');
      });

      // Talking cycles mouth_01, mouth_02, mouth_03
      final assetName = (mouthImage.image as AssetImage).assetName;
      expect(
        assetName.contains('mouth_01.png') ||
            assetName.contains('mouth_02.png') ||
            assetName.contains('mouth_03.png'),
        isTrue,
      );
    });

    testWidgets('controller triggers eye blinking and eyebrow raise',
        (tester) async {
      final controller = GameplayPresenterController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GameplayPresenter(
                height: 160,
                controller: controller,
                enableBreathing: false,
                enableBlinking: false,
                enableEyebrows: false,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // No closed eyes initially
      expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            (w.image as AssetImage).assetName.contains('closed_eyes.png')),
        findsNothing,
      );

      // Trigger blink
      controller.blink();
      await tester.pump();

      expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            (w.image as AssetImage).assetName.contains('closed_eyes.png')),
        findsOneWidget,
      );

      // Trigger eyebrow raise
      controller.raiseEyebrows();
      await tester.pump();

      expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            (w.image as AssetImage)
                .assetName
                .contains('eyebrows_up_right.png')),
        findsOneWidget,
      );

      // Allow timers to finish
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('blinking does not restart the native 100ms mouth cycle',
        (tester) async {
      final controller = GameplayPresenterController();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: GameplayPresenter(
                  controller: controller,
                  enableBreathing: false,
                  enableBlinking: false,
                  enableEyebrows: false))));
      String mouth() => (tester
              .widgetList<Image>(find.byType(Image))
              .firstWhere((image) =>
                  (image.image as AssetImage).assetName.contains('mouth_'))
              .image as AssetImage)
          .assetName;
      expect(mouth(), contains('mouth_01.png'));
      await tester.pump(const Duration(milliseconds: 150));
      expect(mouth(), contains('mouth_02.png'));
      controller.blink();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(mouth(), contains('mouth_03.png'));
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });

    testWidgets('switching controllers detaches speech and cancels face timers',
        (tester) async {
      final first = GameplayPresenterController();
      final second = GameplayPresenterController()..setTalking(false);
      Widget scene(GameplayPresenterController controller) => MaterialApp(
          home: Scaffold(
              body: GameplayPresenter(
                  controller: controller,
                  enableBreathing: false,
                  enableBlinking: false,
                  enableEyebrows: false)));
      String mouth() => (tester
              .widgetList<Image>(find.byType(Image))
              .firstWhere((image) =>
                  (image.image as AssetImage).assetName.contains('mouth_'))
              .image as AssetImage)
          .assetName;
      await tester.pumpWidget(scene(first));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(scene(second));
      expect(mouth(), contains('mouth_05.png'));
      first.setTalking(false);
      first.setTalking(true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(mouth(), contains('mouth_05.png'));
      second.setTalking(true);
      await tester.pump();
      expect(mouth(), contains('mouth_01.png'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(mouth(), contains('mouth_02.png'));
      second.blink();
      second.raiseEyebrows();
      second.lookAside();
      await tester.pumpWidget(const SizedBox.shrink());
      first.dispose();
      second.dispose();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('HostPodiumPlate renders with title and podium image',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: HostPodiumPlate(
                title: 'أرض التحدي',
                width: 156,
              ),
            ),
          ),
        ),
      );

      expect(find.text('أرض التحدي'), findsOneWidget);
      expect(find.byType(HostPodiumPlate), findsOneWidget);
    });

    testWidgets(
        'HostGuideBubble types text progressively and stops mouth when speech finishes',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: HostGuideBubble(
                title: 'مرحباً',
                text: 'أهلاً بك',
                showHost: true,
                showPodium: true,
                enableBreathing: false,
                enableBlinking: false,
                enableEyebrows: false,
              ),
            ),
          ),
        ),
      );

      // Initially speaking
      await tester.pump(const Duration(milliseconds: 64));
      expect(find.byType(HostPodiumPlate), findsOneWidget);
      expect(find.byType(GameplayPresenter), findsOneWidget);

      // Allow typewriter to complete (7 characters * 32ms = ~224ms)
      await tester.pump(const Duration(milliseconds: 300));

      // After finishing text, mouth should be mouth_05 (silent smile)
      final images = tester.widgetList<Image>(find.byType(Image));
      final mouthImage = images.firstWhere((img) {
        final asset = (img.image as AssetImage).assetName;
        return asset.contains('mouth_');
      });
      expect(
          (mouthImage.image as AssetImage).assetName, contains('mouth_05.png'));

      // Clean up remaining timers
      await tester.pump(const Duration(milliseconds: 1200));
    });
  });
}
