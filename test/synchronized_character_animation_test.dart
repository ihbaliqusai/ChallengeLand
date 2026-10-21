import 'dart:async';

import 'package:challenge_land/models/game_character.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:challenge_land/widgets/synchronized_character_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _AnimatedBridge extends NativeBridgeService {
  @override
  bool get supportsAnimatedCharacters => true;
}

void main() {
  const factory = MethodChannel('challengeland/character-animation');
  const original = ValueKey('original');
  const reflection = ValueKey('reflection');

  testWidgets('one decoder supplies independent preview textures and lifecycle',
      (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    final created = <int>[];
    final calls = <(int, String, Object?)>[];
    var nextTexture = 80;
    messenger.setMockMethodCallHandler(factory, (call) async {
      created.add((call.arguments as Map)['index'] as int);
      final id = nextTexture++;
      messenger.setMockMethodCallHandler(
          MethodChannel('challengeland/character-animation/$id'), (call) async {
        calls.add((id, call.method, call.arguments));
        return null;
      });
      return {'original': id, 'reflection': id + 100};
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(factory, null);
      for (var id = 80; id < nextTexture; id++) {
        messenger.setMockMethodCallHandler(
            MethodChannel('challengeland/character-animation/$id'), null);
      }
    });

    final settings = ValueNotifier((index: 3, paused: false, reduced: false));
    addTearDown(settings.dispose);
    await tester.pumpWidget(Provider<NativeBridgeService>(
      create: (_) => _AnimatedBridge(),
      child: MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: settings,
          builder: (context, value, _) => MediaQuery(
            data: MediaQueryData(disableAnimations: value.reduced),
            child: TickerMode(
              enabled: !value.paused,
              child: SynchronizedCharacterAnimation(
                character: CharacterCatalog.byIndex(value.index),
                fallback: (key, {bool reflected = false}) =>
                    SizedBox(key: key, child: const Text('loading')),
                builder: (context, frame) => Row(children: [
                  SizedBox(width: 180, height: 300, child: frame(original)),
                  SizedBox(
                      width: 150,
                      height: 260,
                      child: frame(reflection, reflected: true)),
                ]),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(created, [3]);
    expect(calls.single.$1, 80);
    expect(calls.single.$2, 'start');
    expect(calls.single.$3, {'paused': false});
    expect(find.text('loading'), findsNWidgets(2));
    expect(find.byType(Texture), findsNothing);

    Future<void> ready(int id) async {
      final channel = MethodChannel('challengeland/character-animation/$id');
      await messenger.handlePlatformMessage(channel.name,
          channel.codec.encodeMethodCall(const MethodCall('ready')), (_) {});
      await tester.pump();
    }

    await ready(80);
    expect(find.text('loading'), findsNothing);
    expect(
        tester
            .widgetList<Texture>(find.byType(Texture))
            .map((t) => t.textureId),
        [80, 180]);

    // Ordinary rebuilds must retain both output identities without repeatedly
    // sending MediaPlayer.start() while playback is already active.
    final callsBeforeRebuild = calls.length;
    settings.value = (index: 3, paused: false, reduced: true);
    settings.value = (index: 3, paused: false, reduced: false);
    await tester.pumpAndSettle();
    expect(created, [3]);
    expect(calls.length, callsBeforeRebuild);
    expect(
        tester
            .widgetList<Texture>(find.byType(Texture))
            .map((t) => t.textureId),
        [80, 180]);

    settings.value = (index: 3, paused: true, reduced: false);
    await tester.pumpAndSettle();
    expect(calls.last, (80, 'setPaused', true));
    settings.value = (index: 3, paused: false, reduced: false);
    await tester.pumpAndSettle();
    expect(calls.last, (80, 'setPaused', false));

    settings.value = (index: 9, paused: false, reduced: false);
    await tester.pumpAndSettle();
    expect(created, [3, 9]);
    expect(calls, contains((80, 'dispose', null)));
    expect(find.text('loading'), findsNWidgets(2));
    await ready(81);
    expect(
        tester
            .widgetList<Texture>(find.byType(Texture))
            .map((t) => t.textureId),
        [81, 181]);

    settings.value = (index: 9, paused: false, reduced: true);
    await tester.pumpAndSettle();
    expect(find.byType(Texture), findsNothing);
    expect(calls, contains((81, 'dispose', null)));
    expect(find.text('loading'), findsNWidgets(2));
    settings.value = (index: 9, paused: false, reduced: false);
    await tester.pumpAndSettle();
    await ready(82);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(calls, contains((82, 'dispose', null)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('late texture creation is disposed after leaving the screen',
      (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    final pending = Completer<Map<String, int>>();
    final calls = <String>[];
    const session = MethodChannel('challengeland/character-animation/99');
    messenger.setMockMethodCallHandler(factory, (_) => pending.future);
    messenger.setMockMethodCallHandler(session, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(factory, null);
      messenger.setMockMethodCallHandler(session, null);
    });
    await tester.pumpWidget(Provider<NativeBridgeService>(
      create: (_) => _AnimatedBridge(),
      child: MaterialApp(
        home: SynchronizedCharacterAnimation(
          character: CharacterCatalog.byIndex(1),
          fallback: (key, {bool reflected = false}) => SizedBox(key: key),
          builder: (context, frame) => frame(original),
        ),
      ),
    ));
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete({'original': 99, 'reflection': 199});
    await tester.pumpAndSettle();
    expect(calls, ['dispose']);
    expect(tester.takeException(), isNull);
  });
}
