import 'dart:convert';
import 'dart:io';

import 'package:challenge_land/models/campaign_stage.dart';
import 'package:challenge_land/services/campaign_defaults.dart';
import 'package:challenge_land/services/campaign_mode_engine.dart';
import 'package:challenge_land/services/native_bridge_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final stages = CampaignDefaults.stages();

  test(
      'each world introduces separate timed, precision and category challenges',
      () {
    for (var world = 0; world < 10; world++) {
      final chapter = stages.skip(world * 10).take(10).toList();
      expect(chapter[0].boardRulesText, contains('فئة واحدة'));
      expect(chapter[1].boardRulesText, contains('فئتين'));
      expect(chapter[2].timeLimitSeconds, 210 - world * 6);
      expect(chapter[5].boardRequiredCategoryCount, 2);
      expect(chapter[5].categoryPolicy, 'worldThemed');
      expect(chapter[6].maxWrongAnswers, world < 5 ? 2 : 1);
      expect(
          chapter[9].bossStyle,
          world >= 7
              ? 'mixed'
              : const ['specialist', 'speed', 'highValue'][world % 3]);
      expect(chapter[8].boardAllowRevealOptions, world < 2);
      expect(chapter[8].boardRequiredCategoryCount, world >= 6 ? 3 : 0);
    }
  });

  test('challenge settings survive cloud serialization and copying', () {
    for (final stage in stages) {
      final restored = CampaignStage.fromMap(stage.toMap()).copyWith();
      expect(restored.boardRequiredCategoryCount,
          stage.boardRequiredCategoryCount);
      expect(restored.bossStyle, stage.bossStyle);
      expect(restored.boardAllowRevealOptions, stage.boardAllowRevealOptions);
      expect(restored.boardDesignVersion, stage.boardDesignVersion);
      expect(restored.timeLimitSeconds, stage.timeLimitSeconds);
      expect(restored.maxWrongAnswers, stage.maxWrongAnswers);
      expect(restored.boardRulesText, stage.boardRulesText);
    }
    final legacy = stages.first.toMap()
      ..remove('boardRequiredCategoryCount')
      ..remove('bossStyle');
    expect(CampaignStage.fromMap(legacy).bossStyle, 'balanced');
    expect(CampaignStage.fromMap(legacy).boardRequiredCategoryCount, 0);
  });

  test('launch config carries rules on the board route, including retry values',
      () {
    const engine = CampaignModeEngine();
    for (final stage in stages) {
      final config = engine.buildLaunchConfig(stage);
      expect(config['campaignMode'], 'board');
      expect(config['timeLimitSeconds'], stage.timeLimitSeconds);
      expect(config['maxWrongAnswers'], stage.maxWrongAnswers ?? 0);
      expect(config['boardRequiredCategoryCount'],
          stage.boardRequiredCategoryCount);
      expect(config['bossStyle'], stage.bossStyle);
      expect(config['boardSoloCols'], stage.boardSoloCols);
      expect(config['boardAllowRevealOptions'], stage.boardAllowRevealOptions);
      if (stage.boardRulesText.isNotEmpty) {
        expect(
            engine.boardObjectiveText(stage), contains(stage.boardRulesText));
      }
    }
  });

  test(
      'all 100 stages have enough real categories and themed questions at their levels',
      () {
    final questions =
        (jsonDecode(File('assets/questions.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>();
    for (final stage in stages) {
      final eligible = <String, List<Map<String, dynamic>>>{};
      for (final question in questions) {
        final category = question['Category'] as String?;
        if (category != null &&
            stage.allowedLevels.contains('${question['Level']}')) {
          eligible.putIfAbsent(category, () => []).add(question);
        }
      }
      // Native filtering needs six cells and two questions at each end of a
      // two-level world's difficulty distribution.
      final available = eligible.entries.where((entry) =>
          entry.value.length >= 6 &&
          (stage.allowedLevels.length != 2 ||
              stage.allowedLevels.every((level) =>
                  entry.value.where((q) => '${q['Level']}' == level).length >=
                  2)));
      expect(available.length, greaterThanOrEqualTo(stage.boardSoloCols),
          reason: stage.id);
      expect(
          available
              .where((entry) => stage.categories.contains(entry.key))
              .length,
          greaterThanOrEqualTo(stage.boardRequiredCategoryCount),
          reason: stage.id);
    }
  });

  test('native bridge forwards the new rules without dropping their values',
      () async {
    // Use the production channel name.
    const channel = 'millionaire/native';
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(channel), (call) async {
      captured = call;
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(channel), null));
    await NativeBridgeService().launchCampaignStage(
      campaignId: 'main_campaign',
      stageId: 'stage_006',
      stageType: 'board',
      questionIds: const [],
      allowedLevels: const ['0', '1'],
      questionCount: 6,
      timeLimitSeconds: 180,
      allow5050: false,
      allowAudience: false,
      allowCall: false,
      maxWrongAnswers: 2,
      campaignBoard: true,
      boardRequiredCategoryCount: 2,
      bossStyle: 'specialist',
      boardSoloCols: 2,
      boardAllowRevealOptions: false,
      boardDesignVersion: 2,
    );
    expect(captured?.method, 'launchCampaignStage');
    final arguments = captured!.arguments as Map;
    expect(arguments['timeLimitSeconds'], 180);
    expect(arguments['maxWrongAnswers'], 2);
    expect(arguments['boardRequiredCategoryCount'], 2);
    expect(arguments['bossStyle'], 'specialist');
    expect(arguments['boardSoloCols'], 2);
    expect(arguments['boardAllowRevealOptions'], false);
    expect(arguments['boardDesignVersion'], 2);
  });
}
