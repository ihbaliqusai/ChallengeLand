import '../models/campaign_stage.dart';

/// تحدي المراحل stages — every stage now plays the التحدي board.
///
/// * Normal stages (order not a multiple of 10): a SOLO board. The lone player
///   takes [CampaignStage.boardSoloPicks] picks and must reach
///   [CampaignStage.boardTargetScore] (which rises each stage) to pass.
/// * Boss stages (every 10th): a competitive board against [CampaignStage.botCount]
///   bots (= world number, capped at 7). Worlds 8-10 keep 7 bots but stronger.
///   Win = finish strictly first (beat every boss).
///
/// Stars are score based (see [StageStarRules] thresholds). All stages use the
/// neutral `classic` type/mode so the native + Flutter completion path simply
/// honours the board result (no legacy single-question / boss-defeat gate).
class CampaignDefaults {
  static const String mainCampaignId = 'main_campaign';

  static const List<String> worldNames = <String>[
    'غابة البداية',
    'تلال المعرفة',
    'طريق المليون',
    'صحراء الذكاء',
    'مدينة العباقرة',
    'جبل الأسئلة',
    'بحر المعرفة',
    'مختبر العباقرة',
    'بوابة الأساطير',
    'قصر المليون',
  ];

  /// Themed category set per world (names MUST match the question pool keys in
  /// assets/questions.json). Used for boss stages (worldThemed) and curated solo
  /// stages; the board tops up with random categories when more columns are needed.
  static const List<List<String>> worldCategories = <List<String>>[
    <String>[
      'معلومات عامة',
      'حيوانات',
      'نباتات',
      'طعام وشراب',
      'منوعات',
      'رياضة',
      'خمن الأكلة'
    ],
    <String>[
      'جغرافيا',
      'عواصم',
      'دول',
      'تاريخ',
      'لغات',
      'سياحة وسفر',
      'خمن المدينة او الدولة'
    ],
    <String>[
      'رياضة',
      'كأس العالم',
      'سيارات',
      'فنون وسينما',
      'أفلام عربية',
      'أفلام أجنبية',
      'مسلسلات عربية',
      'مسلسلات أجنبية',
      'مسلسل Friends',
      'خمن الاسم',
      'فيروز',
      'الأنمي',
      'خمن الأغنية'
    ],
    <String>[
      'ألغاز',
      'معلومات عامة',
      'لغة وادب',
      'أمثال',
      'منوعات',
      'خمن الصورة',
      'زووم',
      'وضح شوي',
      'ركز شوي'
    ],
    <String>['علوم وفضاء', 'تقنية', 'اختراعات', 'جسم الإنسان', 'صحة'],
    <String>[
      'تاريخ',
      'جغرافيا',
      'دول',
      'عواصم',
      'سيرة ذاتية',
      'عملات',
      'خمن المدينة او الدولة'
    ],
    <String>[
      'علوم وفضاء',
      'جغرافيا',
      'حيوانات',
      'نباتات',
      'سياحة وسفر',
      'جسم الإنسان'
    ],
    <String>[
      'علوم وفضاء',
      'تقنية',
      'اختراعات',
      'جسم الإنسان',
      'صحة',
      'معلومات عامة'
    ],
    <String>[
      'تاريخ',
      'دين وإسلاميات',
      'قصص الأنبياء',
      'سيرة ذاتية',
      'أمثال',
      'كلثوميات',
      'فيروز',
      'خمن الاسم'
    ],
    <String>[
      'لغة وادب',
      'ألغاز',
      'علوم وفضاء',
      'تاريخ',
      'أفلام عربية',
      'أفلام أجنبية',
      'معلومات عامة',
      'كلثوميات',
      'فيروز',
      'خمن الصورة',
      'خمن الاسم',
      'خمن الأكلة',
      'خمن المدينة او الدولة',
      'زووم',
      'وضح شوي',
      'ركز شوي',
      'الأنمي',
      'خمن الأغنية'
    ],
  ];

  /// Allowed difficulty levels (questions.json Level strings) per world.
  static const List<List<String>> worldLevels = <List<String>>[
    <String>['0', '1'],
    <String>['0', '1', '2'],
    <String>['1', '2'],
    <String>['2', '4'],
    <String>['2', '5'],
    <String>['4', '5'],
    <String>['5', '6'],
    <String>['6', '7'],
    <String>['7', '8'],
    <String>['3', '8'],
  ];

  static List<CampaignStage> stages({String campaignId = mainCampaignId}) {
    return <CampaignStage>[
      for (var order = 1; order <= 100; order++)
        _boardStage(campaignId: campaignId, order: order),
    ];
  }

  static CampaignStage _boardStage({
    required String campaignId,
    required int order,
  }) {
    final world = (order - 1) ~/ 10; // 0..9
    final worldNum = world + 1; // 1..10
    final isBoss = order % 10 == 0;
    final levels = worldLevels[world];
    final themed = worldCategories[world];
    final picks = isBoss ? 6 : soloPicksForOrder(order);
    final target = _targetFor(order, picks);
    // Bosses scale with the world but the board caps at 8 players (you + 7 bots).
    final botCount = isBoss ? (worldNum > 7 ? 7 : worldNum) : 0;
    final botIntelligence = isBoss ? _bossIntelligenceFor(worldNum) : 0;
    final policy = isBoss
        ? 'worldThemed'
        : (worldNum <= 2
            ? 'playerPick'
            : (worldNum <= 6 ? 'curated' : 'random'));

    return CampaignStage(
      id: 'stage_${order.toString().padLeft(3, '0')}',
      campaignId: campaignId,
      order: order,
      title: _titleFor(order, isBoss, worldNum),
      subtitle: _subtitleFor(worldNum, isBoss, target, botCount),
      type: CampaignStageType.classic,
      campaignMode: CampaignMode.classic,
      winCondition: isBoss
          ? CampaignWinCondition.beatOpponent
          : CampaignWinCondition.beatTargetScore,
      questionCount: picks,
      timeLimitSeconds: 0,
      categories: themed,
      allowedLevels: levels,
      minDifficulty: _minLevel(levels),
      maxDifficulty: _maxLevel(levels),
      unlockRequirementStars: 0,
      allow5050: false,
      allowAudience: false,
      allowCall: false,
      rewardCoins: 100 + order * 22 + (isBoss ? 400 : 0),
      rewardGems: isBoss ? (4 + worldNum) : (order % 3 == 0 ? 1 : 0),
      rewardXp: 70 + order * 18 + (isBoss ? 300 : 0),
      boardKind: isBoss ? 'boss' : 'solo',
      boardTargetScore: target,
      boardSoloPicks: picks,
      boardSoloCols: 4,
      botCount: botCount,
      botIntelligence: botIntelligence,
      categoryPolicy: policy,
      starRules: _boardStarRules(
        target,
        maxScoreForBoard(columns: isBoss ? botCount + 1 : 4, picks: picks),
      ),
    );
  }

  /// Reference maximum for a standard six-pick, four-column solo board.
  /// Use [maxScoreForBoard] for shorter, longer and boss boards.
  static const int maxBoardScore = 6 * 600;

  /// Score thresholds. 1★ is granted on completion (reaching the pass target);
  /// 2★/3★ require scoring further above it. The correct-answer thresholds are
  /// disabled (set very high) so stars are purely score driven for the board.
  static StageStarRules _boardStarRules(int target, int maxScore) {
    final two = (target * 1.25).round().clamp(target, maxScore - 400);
    final three = (target * 1.55).round().clamp(two + 100, maxScore - 200);
    return StageStarRules(
      oneStarMinScore: 1,
      twoStarsMinScore: two,
      threeStarsMinScore: three,
      oneStarMinCorrectAnswers: 999,
      twoStarsMinCorrectAnswers: 999,
      threeStarsMinCorrectAnswers: 999,
      completedRequired: true,
    );
  }

  /// A steeper climb toward the million: later stages demand a near-perfect board
  /// to clear. Boss stages ask for a little more. Rounded to 20 and held below
  /// [maxBoardScore] so every stage stays winnable.
  static int _targetFor(int order, int picks) {
    final base = (500 + order * 22 + (order % 10 == 0 ? 180 : 0)) * picks / 6;
    final rounded = (base / 20).round() * 20;
    final ceiling = maxScoreForBoard(columns: 4, picks: picks) - 600;
    return rounded > ceiling ? ceiling : rounded;
  }

  /// Two cells per value (200/400/600) in each column. Cells cannot be reused.
  static int maxScoreForBoard({required int columns, required int picks}) {
    var remaining = picks.clamp(0, columns * 6);
    var total = 0;
    for (final value in const [600, 400, 200]) {
      final taken = remaining.clamp(0, columns * 2);
      total += taken * value;
      remaining -= taken;
    }
    return total;
  }

  /// Short tactical boards and longer exploration boards break up the journey.
  static int soloPicksForOrder(int order) {
    switch (order % 10) {
      case 3:
      case 7:
        return 5;
      case 5:
      case 8:
        return 7;
      default:
        return 6;
    }
  }

  /// Boss bot skill rises with the world; worlds 8-10 (capped at 7 bots) get a
  /// difficulty bump to compensate for not adding more bots. Clamped to 95.
  static int _bossIntelligenceFor(int worldNum) {
    final base = 60 + worldNum * 4; // world1=64 ... world7=88
    final boosted = worldNum >= 8 ? base + 4 : base;
    return boosted > 95 ? 95 : boosted;
  }

  static String _titleFor(int order, bool isBoss, int worldNum) {
    if (isBoss) return 'زعيم ${worldNames[worldNum - 1]}';
    if (soloPicksForOrder(order) == 5) {
      return 'المرحلة $order • اختيارات محسوبة';
    }
    if (soloPicksForOrder(order) == 7) return 'المرحلة $order • رحلة الاستكشاف';
    return 'المرحلة $order';
  }

  static String _subtitleFor(
      int worldNum, bool isBoss, int target, int botCount) {
    final world = worldNames[worldNum - 1];
    if (isBoss) {
      return botCount <= 1
          ? '$world - واجه الزعيم على لوحة التحدي.'
          : '$world - واجه $botCount زعماء على لوحة التحدي.';
    }
    return '$world - اجمع $target نقطة على اللوحة.';
  }

  static List<String> allowedLevelsForOrder(int order) {
    final world = ((order - 1) ~/ 10).clamp(0, worldLevels.length - 1);
    return worldLevels[world];
  }

  static int _minLevel(List<String> levels) => levels
      .map((level) => int.tryParse(level) ?? 0)
      .reduce((a, b) => a < b ? a : b);

  static int _maxLevel(List<String> levels) => levels
      .map((level) => int.tryParse(level) ?? 0)
      .reduce((a, b) => a > b ? a : b);
}
