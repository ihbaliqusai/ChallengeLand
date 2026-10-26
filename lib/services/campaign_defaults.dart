import '../models/campaign_stage.dart';

/// تحدي المراحل stages — every stage now plays the التحدي board.
///
/// * Normal stages (order not a multiple of 10): a SOLO board. The lone player
///   takes [CampaignStage.boardSoloPicks] picks and must reach
///   [CampaignStage.boardTargetScore], scaled to the board and its constraints.
/// * Boss stages (every 10th): a competitive board against [CampaignStage.botCount]
///   bots (= world number, capped at 7). Worlds 8-10 keep 7 bots but stronger.
///   Win = finish strictly first (beat every boss).
///
/// Stars are score based (see [StageStarRules] thresholds). All stages use the
/// neutral `classic` type/mode so the native + Flutter completion path simply
/// honours the board result (no legacy single-question / boss-defeat gate).
class CampaignDefaults {
  static const String mainCampaignId = 'main_campaign';
  static const int boardDesignVersion = 2;
  static const int rewardEconomyVersion = 1;

  /// Maximum lifetime currency per stage, shared across all star upgrades.
  /// Ordinary wins require saving for resources (500/600/800 coins per unit
  /// in triple packs); only bosses award premium currency.
  static int coinsForOrder(int order) {
    final world = (order.clamp(1, 100) - 1) ~/ 10;
    return order % 10 == 0
        ? 180 + world * 20
        : 50 + world * 10 + (order - 1) % 10 * 5;
  }

  static int gemsForOrder(int order) {
    if (order % 10 != 0) return 0;
    final world = (order.clamp(1, 100) - 1) ~/ 10 + 1;
    return world <= 3 ? 1 : (world <= 7 ? 2 : 3);
  }

  /// Upgrade only stock campaign rewards; gameplay and already reserved claims
  /// keep their saved values. Explicitly versioned custom economies are kept.
  static CampaignStage withCurrentEconomy(CampaignStage stage) {
    if (stage.campaignId != mainCampaignId ||
        stage.order < 1 ||
        stage.order > 100 ||
        stage.id != 'stage_${stage.order.toString().padLeft(3, '0')}' ||
        stage.rewardEconomyVersion >= rewardEconomyVersion) {
      return stage;
    }
    return stage.copyWith(
      rewardCoins: coinsForOrder(stage.order),
      rewardGems: gemsForOrder(stage.order),
      rewardEconomyVersion: rewardEconomyVersion,
    );
  }

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
      'دوري أبطال أوروبا',
      'NBA',
      'سيارات',
      'فنون وسينما',
      'أفلام عربية',
      'أفلام أجنبية',
      'مسلسلات عربية',
      'مسلسلات أجنبية',
      'مسلسلات تركية',
      'دراما خليجية',
      'دراما سورية',
      'دراما مصرية',
      'باب الحارة',
      'مسلسل Friends',
      'Game Of Thrones',
      'Breaking Bad',
      'Harry Potter',
      'خمن الاسم',
      'فيروز',
      'الأنمي',
      'Pokémon',
      'Demon Slayer',
      'Hunter × Hunter',
      'One Piece',
      'Attack on Titan',
      'Naruto',
      'بنات وبس',
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
    final columns =
        isBoss ? (worldNum > 7 ? 8 : worldNum + 1) : soloColumnsForOrder(order);
    final chapterPosition = order % 10;
    // Introduce one rule at a time; the first two stages remain introductory.
    final finalTrial = chapterPosition == 9 && worldNum >= 7;
    final timed = !isBoss && (chapterPosition == 3 || finalTrial);
    final precision = !isBoss && (chapterPosition == 7 || finalTrial);
    final categoryChallenge = !isBoss && (chapterPosition == 6 || finalTrial);
    final allowReveal = chapterPosition != 9 || worldNum < 3;
    final bossStyle = isBoss
        ? (worldNum >= 8
            ? 'mixed'
            : const ['specialist', 'speed', 'highValue'][(worldNum - 1) % 3])
        : 'balanced';
    // Bosses scale with the world but the board caps at 8 players (you + 7 bots).
    final botCount = isBoss ? (worldNum > 7 ? 7 : worldNum) : 0;
    final botIntelligence = isBoss ? _bossIntelligenceFor(worldNum) : 0;
    final policy = categoryPolicyForOrder(order);
    final maximum = maxScoreForBoard(
        columns: columns, picks: picks, bossStyle: isBoss ? bossStyle : null);
    // Compare difficulty as a fraction of this board's attainable score rather
    // than a fixed score shared by boards with different category counts.
    final pressure = 0.30 +
        world * 0.038 +
        (chapterPosition == 0 ? 9 : chapterPosition - 1) * 0.006;
    final adjustment = isBoss
        ? 0.06
        : finalTrial
            ? -0.07
            : timed || precision
                ? -0.04
                : !allowReveal
                    ? -0.03
                    : 0.0;
    final target = _scoreThreshold(maximum, pressure + adjustment);

    return CampaignStage(
      id: 'stage_${order.toString().padLeft(3, '0')}',
      campaignId: campaignId,
      order: order,
      title: _titleFor(order, isBoss, worldNum),
      subtitle: '${_subtitleFor(worldNum, isBoss, target, botCount)} '
          '${policy == 'playerPick' ? 'اختيارك' : 'اختيار الكمبيوتر'}: $columns فئات.',
      type: CampaignStageType.classic,
      campaignMode: CampaignMode.classic,
      winCondition: isBoss
          ? CampaignWinCondition.beatOpponent
          : CampaignWinCondition.beatTargetScore,
      questionCount: picks,
      timeLimitSeconds: timed ? (finalTrial ? picks * 32 : 210 - world * 6) : 0,
      maxWrongAnswers: precision ? (finalTrial || worldNum <= 5 ? 2 : 1) : null,
      boardRequiredCategoryCount:
          categoryChallenge ? (finalTrial ? columns : 2) : 0,
      bossStyle: bossStyle,
      boardAllowRevealOptions: allowReveal,
      boardDesignVersion: boardDesignVersion,
      categories: themed,
      allowedLevels: levels,
      minDifficulty: _minLevel(levels),
      maxDifficulty: _maxLevel(levels),
      unlockRequirementStars: 0,
      allow5050: false,
      allowAudience: false,
      allowCall: false,
      rewardCoins: coinsForOrder(order),
      rewardGems: gemsForOrder(order),
      rewardEconomyVersion: rewardEconomyVersion,
      rewardXp: 70 + order * 18 + (isBoss ? 300 : 0),
      boardKind: isBoss ? 'boss' : 'solo',
      boardTargetScore: target,
      boardSoloPicks: picks,
      boardSoloCols: columns,
      botCount: botCount,
      botIntelligence: botIntelligence,
      categoryPolicy: policy,
      starRules: _boardStarRules(target, maximum, world),
    );
  }

  /// Reference maximum for a standard six-pick, four-column solo board.
  /// Use [maxScoreForBoard] for shorter, longer and boss boards.
  static const int maxBoardScore = 6 * 600;

  /// Score thresholds. 1★ is granted on completion (reaching the pass target);
  /// 2★/3★ require scoring further above it. The correct-answer thresholds are
  /// disabled (set very high) so stars are purely score driven for the board.
  static StageStarRules _boardStarRules(int target, int maxScore, int world) {
    final two = _scoreThreshold(maxScore, 0.65 + world * 0.02)
        .clamp(target + 200, maxScore - 200);
    final three = _scoreThreshold(maxScore, 0.85 + world * 0.01)
        .clamp(two + 200, maxScore);
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

  /// Keep every threshold on the board's 200-point scoring lattice.
  static int _scoreThreshold(int maximum, double fraction) =>
      (maximum * fraction / 200).ceil() * 200;

  /// Two cells per value (200/400/600) in each column. Cells cannot be reused.
  static int maxScoreForBoard(
      {required int columns, required int picks, String? bossStyle}) {
    // With one column per contestant and all bots choosing the highest value,
    // each round consumes one complete value band. The player can take only
    // two 600s, two 400s and two 200s over the six boss rounds.
    if (bossStyle == 'highValue') {
      final values = [600, 600, 400, 400, 200, 200];
      return values
          .take(picks.clamp(0, 6))
          .fold(0, (sum, value) => sum + value);
    }
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
    final world = (order - 1) ~/ 10;
    switch (order % 10) {
      case 1:
      case 4:
        return world < 3
            ? 4
            : world < 7
                ? 5
                : 6;
      case 3:
      case 7:
        return 5;
      case 5:
        return 7;
      case 8:
        return world < 3 ? 7 : 8;
      default:
        return 6;
    }
  }

  static int soloColumnsForOrder(int order) {
    switch (order % 10) {
      case 1:
      case 4:
      case 7:
        return 1;
      case 2:
      case 3:
      case 6:
        return 2;
      case 5:
        return 3;
      case 8:
        return 4;
      case 9:
        return order <= 60 ? 2 : 3;
      default:
        return 4;
    }
  }

  static String categoryPolicyForOrder(int order) {
    switch (order % 10) {
      case 1:
      case 2:
      case 5:
      case 7:
        return 'playerPick';
      case 8:
        return 'random';
      default:
        return 'worldThemed';
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
    if (order % 10 == 3) return 'المرحلة $order • سباق الوقت';
    if (order % 10 == 6) return 'المرحلة $order • تحدي الفئات';
    if (order % 10 == 7) return 'المرحلة $order • دقة الإجابة';
    if (order % 10 == 1) return 'المرحلة $order • فئتك المفضلة';
    if (order % 10 == 2) return 'المرحلة $order • ثنائي المعرفة';
    if (order % 10 == 4) return 'المرحلة $order • اختيار الكمبيوتر';
    if (order % 10 == 8) return 'المرحلة $order • اللوحة المفاجئة';
    if (order % 10 == 9) {
      return 'المرحلة $order • ${worldNum < 3 ? 'الاستعداد للزعيم' : worldNum < 7 ? 'خبير بلا خيارات' : 'الاختبار الشامل'}';
    }
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
