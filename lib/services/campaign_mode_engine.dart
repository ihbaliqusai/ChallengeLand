import '../models/campaign_stage.dart';

class CampaignModeEngine {
  const CampaignModeEngine();

  String modeLabelArabic(CampaignMode mode) {
    switch (mode) {
      case CampaignMode.classic:
        return 'كلاسيكي';
      case CampaignMode.blitz:
        return 'سباق ضد الوقت';
      case CampaignMode.elimination:
        return 'إقصاء';
      case CampaignMode.survival:
        return 'نجاة';
      case CampaignMode.noLifeline:
        return 'بدون مساعدات';
      case CampaignMode.battle:
        return 'تنافسي';
      case CampaignMode.rival:
        return 'مطاردة';
      case CampaignMode.series:
        return 'سلسلة جولات';
      case CampaignMode.teamBattle:
        return 'معركة فريق';
      case CampaignMode.bossBattle:
        return 'مواجهة زعيم';
    }
  }

  String winConditionLabelArabic(CampaignWinCondition condition) {
    switch (condition) {
      case CampaignWinCondition.completeQuestions:
        return 'إنهاء الأسئلة';
      case CampaignWinCondition.finishBeforeTime:
        return 'الإنهاء قبل انتهاء الوقت';
      case CampaignWinCondition.survive:
        return 'النجاة حتى النهاية';
      case CampaignWinCondition.noMistakes:
        return 'تجنب الإقصاء';
      case CampaignWinCondition.beatOpponent:
        return 'هزيمة الخصم';
      case CampaignWinCondition.beatTargetScore:
        return 'تجاوز نتيجة الهدف';
      case CampaignWinCondition.winSeries:
        return 'الفوز بالسلسلة';
      case CampaignWinCondition.teamScore:
        return 'تفوق نتيجة الفريق';
      case CampaignWinCondition.defeatBoss:
        return 'هزيمة الزعيم';
    }
  }

  String objectiveText(CampaignStage stage) {
    switch (stage.campaignMode) {
      case CampaignMode.classic:
      case CampaignMode.noLifeline:
        return 'أجب عن ${stage.questionCount} أسئلة';
      case CampaignMode.blitz:
        return 'أنهِ ${stage.questionCount} أسئلة قبل انتهاء الوقت';
      case CampaignMode.elimination:
        return 'لا تتجاوز عدد الأخطاء المسموح';
      case CampaignMode.survival:
        final lives = stage.lives ?? 3;
        return 'لديك $lives أرواح';
      case CampaignMode.battle:
        return 'اجمع نقاطًا أكثر من الخصم';
      case CampaignMode.rival:
        return 'تجاوز نتيجة الهدف';
      case CampaignMode.series:
        return 'اربح السلسلة';
      case CampaignMode.teamBattle:
        return 'اجعل فريقك يتفوق بالنقاط';
      case CampaignMode.bossBattle:
        return 'اهزم الزعيم لفتح الطريق التالي';
    }
  }

  CampaignWinCondition defaultWinConditionForMode(CampaignMode mode) {
    return defaultWinConditionForCampaignMode(mode);
  }

  CampaignMode inferCampaignModeFromLegacyType(CampaignStageType type) {
    return campaignModeFromLegacyType(type);
  }

  bool shouldRequireOpponent(CampaignMode mode) {
    switch (mode) {
      case CampaignMode.battle:
      case CampaignMode.series:
      case CampaignMode.bossBattle:
        return true;
      case CampaignMode.classic:
      case CampaignMode.blitz:
      case CampaignMode.elimination:
      case CampaignMode.survival:
      case CampaignMode.noLifeline:
      case CampaignMode.rival:
      case CampaignMode.teamBattle:
        return false;
    }
  }

  bool isCompetitiveMode(CampaignMode mode) {
    switch (mode) {
      case CampaignMode.battle:
      case CampaignMode.rival:
      case CampaignMode.series:
      case CampaignMode.teamBattle:
      case CampaignMode.bossBattle:
        return true;
      case CampaignMode.classic:
      case CampaignMode.blitz:
      case CampaignMode.elimination:
      case CampaignMode.survival:
      case CampaignMode.noLifeline:
        return false;
    }
  }

  bool isBossMode(CampaignMode mode) => mode == CampaignMode.bossBattle;

  /// Every تحدي المراحل stage now plays the التحدي board. We pass `stageType` /
  /// `campaignMode` as `'board'` so the native side runs the board engine (not the
  /// legacy single-question / boss flow), plus the board params (solo target or boss
  /// bots) and the world's themed category set.
  Map<String, dynamic> buildLaunchConfig(CampaignStage stage) {
    final bool isBoss = stage.isBossStage;
    return <String, dynamic>{
      'campaignId': stage.campaignId,
      'stageId': stage.id,
      'stageType': 'board',
      'campaignMode': 'board',
      'winCondition': isBoss ? 'beatOpponent' : 'beatTargetScore',
      'questionCount': stage.questionCount,
      'timeLimitSeconds': stage.timeLimitSeconds,
      'maxWrongAnswers': stage.maxWrongAnswers ?? 0,
      'boardRequiredCategoryCount': stage.boardRequiredCategoryCount,
      'bossStyle': stage.bossStyle,
      'boardAllowRevealOptions': stage.boardAllowRevealOptions,
      'boardDesignVersion': stage.boardDesignVersion,
      'allowedLevels': stage.allowedLevels,
      'allow5050': false,
      'allowAudience': false,
      'allowCall': false,
      // تحدي المراحل board params
      'campaignBoard': true,
      'boardKind': isBoss ? 'boss' : 'solo',
      'boardTargetScore': stage.boardTargetScore,
      'boardTwoStarScore': stage.starRules.twoStarsMinScore,
      'boardThreeStarScore': stage.starRules.threeStarsMinScore,
      'boardSoloPicks': stage.boardSoloPicks,
      'boardSoloCols': stage.boardSoloCols,
      'boardBotCount': stage.botCount,
      'boardBotIntelligence': stage.botIntelligence,
      'categoryPolicy': stage.categoryPolicy,
      'worldCategories': stage.categories,
    };
  }

  /// Short objective shown on the stage intro, in board terms.
  String boardObjectiveText(CampaignStage stage) {
    final rules = stage.boardRulesText;
    final suffix = rules.isEmpty ? '' : '\n$rules';
    if (stage.isBossStage) {
      final n = stage.botCount > 0 ? stage.botCount : 1;
      return n == 1
          ? 'تغلّب على الزعيم على اللوحة$suffix'
          : 'تغلّب على $n زعماء على اللوحة$suffix';
    }
    return 'اجمع ${stage.boardTargetScore} نقطة على اللوحة$suffix';
  }
}
