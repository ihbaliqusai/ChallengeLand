import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:challenge_land/models/game_character.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = 'android/app/src/main/java/com/Qi7bali/challengeland';
  final pack =
      (jsonDecode(File('tools/characters/pack.json').readAsStringSync())
              as List)
          .cast<Map<String, dynamic>>();

  test('existing saved indices remain stable and new identities are complete',
      () {
    expect(CharacterCatalog.all.take(8).map((c) => c.id), [
      'khaled',
      'omar',
      'fahad',
      'mazen',
      'mahmoud',
      'ellen',
      'sarah',
      'talia',
    ]);
    expect(CharacterCatalog.all.length, 16);
    expect(
        CharacterCatalog.all.map((c) => c.index), List.generate(16, (i) => i));
    expect(CharacterCatalog.all.map((c) => c.id).toSet().length, 16);
    for (final source in pack) {
      final character = CharacterCatalog.byIndex(source['index'] as int);
      expect(character.id, source['id']);
      expect(character.nameAr, source['name']);
      expect(character.isFemale, source['female']);
      expect(character.unlock.kind.name, source['kind']);
      expect(character.unlock.value, source['value']);
      expect(character.tagAr, isNotEmpty);
      expect(character.bioAr.length, greaterThan(40));
      expect(character.quoteAr, isNotEmpty);
      for (final stat in [
        character.speed,
        character.knowledge,
        character.focus,
        character.confidence
      ]) {
        expect(stat, inInclusiveRange(0, 100));
      }
    }
  });

  test('Flutter, native gameplay, reactions and home share one roster order',
      () {
    final gameplay = File('$native/GameOfflineContestantsController.java')
        .readAsStringSync();
    final home = File(
            'android/app/src/main/kotlin/com/Qi7bali/challengeland/HomeCharacterViewFactory.kt')
        .readAsStringSync();
    final bridge = File(
            'android/app/src/main/kotlin/com/Qi7bali/challengeland/MainActivity.kt')
        .readAsStringSync();
    List<String> array(String name) {
      final body = RegExp('$name\\s*=\\s*\\{([^}]+)\\}', dotAll: true)
          .firstMatch(gameplay)!
          .group(1)!;
      return RegExp(r'R\.(?:drawable|raw)\.(\w+)')
          .allMatches(body)
          .map((m) => m.group(1)!)
          .toList();
    }

    expect(array('CONTESTANT_DRAWABLES'),
        CharacterCatalog.all.map((c) => 'contestant_${c.id}'));
    expect(array('EMOTE_DRAWABLES'),
        CharacterCatalog.all.map((c) => 'emote_${c.id}'));
    expect(array('CONTESTANT_VIDEOS'),
        CharacterCatalog.all.map((c) => 'video_${c.id}'));
    final homeClips =
        RegExp(r'R\.raw\.video_(\w+)').allMatches(home).map((m) => m.group(1)!);
    expect(homeClips, CharacterCatalog.all.map((c) => c.id));
    final bridgeArt = RegExp(r'R\.drawable\.contestant_(\w+)')
        .allMatches(bridge)
        .map((m) => m.group(1)!);
    expect(bridgeArt, CharacterCatalog.all.map((c) => c.id));
    for (final character in CharacterCatalog.all) {
      expect(gameplay, contains('"${character.nameAr}"'));
      for (final suffix in ['CORRECT', 'WRONG']) {
        expect(
            gameplay,
            matches(RegExp(
                'CONTESTANT_VIDEOS_$suffix\\[${character.index}\\]\\s*=\\s*R.raw.video_${character.id}_${suffix.toLowerCase()}')));
      }
    }
    for (final female in [false, true]) {
      final name = female ? 'FEMALE_FIGURES' : 'MALE_FIGURES';
      final body =
          RegExp('$name\\s*=\\s*\\{([^}]+)\\}').firstMatch(gameplay)!.group(1)!;
      final indices =
          RegExp(r'\d+').allMatches(body).map((m) => int.parse(m.group(0)!));
      expect(
          indices,
          CharacterCatalog.all
              .where((c) => c.isFemale == female)
              .map((c) => c.index));
    }
  });

  test('new transparent WebP assets decode and every reaction clip is packaged',
      () async {
    for (final character in CharacterCatalog.all.skip(8)) {
      for (final avatar in [false, true]) {
        final path = avatar ? character.asset : character.fullBodyAsset;
        final nativeName =
            avatar ? 'emote_${character.id}' : 'contestant_${character.id}';
        final bytes = File(path).readAsBytesSync();
        expect(
            File('android/app/src/main/res/drawable/$nativeName.webp')
                .readAsBytesSync(),
            bytes);
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.height, lessThanOrEqualTo(avatar ? 256 : 960));
        final rgba =
            await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
        expect(rgba!.getUint8(3), 0,
            reason: '$path must have a transparent backdrop');
        frame.image.dispose();
        codec.dispose();
      }
      for (final suffix in ['', '_correct', '_wrong']) {
        final clip = File(
            'android/app/src/main/res/raw/video_${character.id}$suffix.mp4');
        expect(clip.existsSync(), isTrue);
        expect(clip.lengthSync(), inInclusiveRange(1000, 2 * 1024 * 1024));
      }
    }
  });
}
