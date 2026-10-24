// ===== أدوار اللاعبين =====

enum PlayerRole {
  host, // صاحب الغرفة - يتحكم في الإعدادات
  describer, // المُوصِف - يصف أو يمثّل
  guesser, // المُخمِّن - يخمّن الكلمة
  spectator, // متفرج - زملاء المُوصِف في نظام الفرق
  judge, // حكم - يحكم صحة الإجابة (اختياري)
}

// ===== نوع اللعبة =====

enum GameType {
  quick1v1, // لاعب ضد لاعب سريع
  teams2v2, // فريقان (2 في 2)
  teams3v3, // فريقان (3 في 3)
  party, // حفلة - 4 إلى 8 لاعبين بدون فرق
}

// ===== مرحلة اللعبة =====

enum GamePhase {
  lobby, // الانتظار - اللاعبون يجتمعون
  describing, // الوصف/التمثيل - المُوصِف يصف
  guessing, // التخمين - الفريق يخمّن
  roundResult, // نتيجة الجولة - عرض النقاط
  gameOver, // نهاية اللعبة - الفائز
}

// ===== نتيجة تحديث النقاط =====

class ScoreUpdate {
  const ScoreUpdate({
    required this.describerUid,
    this.guesserUid,
    required this.describerDelta,
    required this.guesserDelta,
    required this.teamDeltas,
    required this.isCorrect,
    required this.isSkip,
  });

  final String describerUid;
  final String? guesserUid; // null عند التخطي
  final int describerDelta; // +2 صحيح | -1 تخطي
  final int guesserDelta; // +3 صحيح | 0 تخطي
  final Map<String, int> teamDeltas; // teamId → نقاط تُضاف
  final bool isCorrect;
  final bool isSkip;

  static const int correctDescriberPoints = 2;
  static const int correctGuesserPoints = 3;
  static const int correctTeamPoints = 5;
  static const int skipDescriberPenalty = -1;

  factory ScoreUpdate.correct({
    required String describerUid,
    required String guesserUid,
    String? describingTeamId,
    String? teamId,
  }) {
    final scoringTeamId = teamId ?? describingTeamId;
    return ScoreUpdate(
      describerUid: describerUid,
      guesserUid: guesserUid,
      describerDelta: correctDescriberPoints,
      guesserDelta: correctGuesserPoints,
      teamDeltas: scoringTeamId == null
          ? {}
          : {scoringTeamId: correctTeamPoints},
      isCorrect: true,
      isSkip: false,
    );
  }

  factory ScoreUpdate.skip({
    required String describerUid,
    required String? describingTeamId,
  }) {
    return ScoreUpdate(
      describerUid: describerUid,
      guesserUid: null,
      describerDelta: skipDescriberPenalty,
      guesserDelta: 0,
      teamDeltas: const {},
      isCorrect: false,
      isSkip: true,
    );
  }

  int get totalPoints => describerDelta + guesserDelta;
}

// ===== دوال مساعدة للـ Enums =====

extension PlayerRoleX on PlayerRole {
  String get nameAr {
    switch (this) {
      case PlayerRole.host:
        return 'مضيف';
      case PlayerRole.describer:
        return 'مُوصِف';
      case PlayerRole.guesser:
        return 'مُخمِّن';
      case PlayerRole.spectator:
        return 'متفرج';
      case PlayerRole.judge:
        return 'حكم';
    }
  }

  String get emoji {
    switch (this) {
      case PlayerRole.host:
        return '👑';
      case PlayerRole.describer:
        return '🎭';
      case PlayerRole.guesser:
        return '🤔';
      case PlayerRole.spectator:
        return '👀';
      case PlayerRole.judge:
        return '⚖️';
    }
  }

  bool get isActiveInRound =>
      this == PlayerRole.describer || this == PlayerRole.guesser;
}

extension GameTypeX on GameType {
  String get nameAr {
    switch (this) {
      case GameType.quick1v1:
        return 'لاعب ضد لاعب';
      case GameType.teams2v2:
        return 'فرق 2 ضد 2';
      case GameType.teams3v3:
        return 'فرق 3 ضد 3';
      case GameType.party:
        return 'حفلة جماعية';
    }
  }

  int get maxPlayers {
    switch (this) {
      case GameType.quick1v1:
        return 2;
      case GameType.teams2v2:
        return 4;
      case GameType.teams3v3:
        return 6;
      case GameType.party:
        return 8;
    }
  }

  int get minPlayers {
    switch (this) {
      case GameType.quick1v1:
        return 2;
      case GameType.teams2v2:
        return 4;
      case GameType.teams3v3:
        return 6;
      case GameType.party:
        return 4;
    }
  }

  bool get isTeamMode => this == GameType.teams2v2 || this == GameType.teams3v3;

  int get teamCount => isTeamMode ? 2 : 0;

  static GameType fromString(String s) {
    switch (s) {
      case 'quick1v1':
        return GameType.quick1v1;
      case 'teams2v2':
        return GameType.teams2v2;
      case 'teams3v3':
        return GameType.teams3v3;
      case 'party':
        return GameType.party;
      default:
        return GameType.quick1v1;
    }
  }
}

extension GamePhaseX on GamePhase {
  String get nameAr {
    switch (this) {
      case GamePhase.lobby:
        return 'الانتظار';
      case GamePhase.describing:
        return 'جولة الوصف';
      case GamePhase.guessing:
        return 'جولة التخمين';
      case GamePhase.roundResult:
        return 'نتيجة الجولة';
      case GamePhase.gameOver:
        return 'انتهت اللعبة';
    }
  }

  bool get isActiveRound =>
      this == GamePhase.describing || this == GamePhase.guessing;

  bool get isOver => this == GamePhase.gameOver;

  static GamePhase fromString(String s) {
    switch (s) {
      case 'lobby':
        return GamePhase.lobby;
      case 'describing':
        return GamePhase.describing;
      case 'guessing':
        return GamePhase.guessing;
      case 'roundResult':
        return GamePhase.roundResult;
      case 'gameOver':
        return GamePhase.gameOver;
      default:
        return GamePhase.lobby;
    }
  }
}
