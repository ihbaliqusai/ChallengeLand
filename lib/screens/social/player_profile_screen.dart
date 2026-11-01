import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/player_rank.dart';
import '../../core/trophy_league.dart';
import '../../services/social_service.dart';
import '../../widgets/player_profile_theme.dart';

/// A player's published identity and achievements, viewed from the social page.
class PlayerProfileScreen extends StatefulWidget {
  const PlayerProfileScreen(
      {super.key, required this.playerUid, this.initialProfile});

  final String playerUid;
  final Map<String, dynamic>? initialProfile;

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _failed = false;
  int _readGeneration = 0;

  @override
  void initState() {
    super.initState();
    _profile = _initialProfile();
    _load();
  }

  @override
  void didUpdateWidget(covariant PlayerProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerUid != widget.playerUid) {
      _profile = _initialProfile();
      _load();
    }
  }

  Map<String, dynamic>? _initialProfile() {
    final profile = widget.initialProfile;
    if (profile == null ||
        profile['_profileMissing'] == true ||
        (profile['uid'] != null && profile['uid'] != widget.playerUid)) {
      return null;
    }
    return Map<String, dynamic>.unmodifiable(profile);
  }

  Future<void> _load() async {
    final generation = ++_readGeneration;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final profile = await context
          .read<SocialService>()
          .profile(widget.playerUid, forceRefresh: true)
          .timeout(SocialService.profileTimeout);
      if (!mounted || generation != _readGeneration) return;
      if (profile['_profileMissing'] == true ||
          (profile['uid'] != null && profile['uid'] != widget.playerUid)) {
        throw const SocialException('تعذر تحميل ملف اللاعب.');
      }
      setState(() {
        _profile = Map<String, dynamic>.unmodifiable(profile);
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _readGeneration) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  int? _number(Map<String, dynamic> profile, String key) {
    final value = profile[key];
    if (value is! num || !value.isFinite || value < 0) return null;
    return value.toInt();
  }

  int? _level(Map<String, dynamic> profile) {
    final xp = _number(profile, 'xp') ?? _number(profile, 'totalScore');
    if (xp != null) return PlayerRank.levelForXp(xp);
    final level = _number(profile, 'level');
    return level != null && level > 0 ? level : null;
  }

  String _name(Map<String, dynamic> profile) {
    final name = profile['username'];
    return name is String && name.trim().isNotEmpty ? name.trim() : 'لاعب';
  }

  Widget _avatar(Map<String, dynamic> profile, {bool compact = false}) {
    final photo = profile['photoUrl'];
    final uri = photo is String ? Uri.tryParse(photo) : null;
    Widget fallback() => Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF7351B1), Color(0xFF35215F)])),
        alignment: Alignment.center,
        child: Icon(Icons.person_rounded,
            size: compact ? 44 : 66, color: const Color(0xFFF5EBFF)));
    return Container(
        width: compact ? 80 : 120,
        height: compact ? 80 : 120,
        padding: EdgeInsets.all(compact ? 4 : 5),
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF4C3),
                  Color(0xFFE3AE47),
                  Color(0xFFFFDE7A),
                  Color(0xFF9C671E)
                ]),
            borderRadius: BorderRadius.circular(compact ? 24 : 32),
            border: Border.all(color: const Color(0xFF9C702C), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0xFF7D5424), offset: Offset(0, 4)),
              BoxShadow(
                  color: Color(0x44321C45),
                  blurRadius: 20,
                  offset: Offset(0, 10))
            ]),
        child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
                color: const Color(0xFF2B164A),
                borderRadius: BorderRadius.circular(compact ? 19 : 26),
                border: Border.all(color: const Color(0xFFFFE7A1))),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(compact ? 15 : 22),
                child: uri?.scheme == 'https' && uri!.host.isNotEmpty
                    ? Image.network(uri.toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => fallback())
                    : fallback())));
  }

  Widget _identity(Map<String, dynamic> profile, {bool compact = false}) {
    final level = _level(profile);
    final rank = level == null ? null : PlayerRank.tierForLevel(level);
    final trophies = _number(profile, 'trophies');
    final league =
        trophies == null ? null : TrophyProgression.leagueFor(trophies);
    final code = profile['friendCode'];
    return PlayerProfilePanel(
        accent: PlayerProfileTheme.gold,
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 20, vertical: compact ? 16 : 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _avatar(profile, compact: compact),
          SizedBox(height: compact ? 12 : 20),
          Text(_name(profile),
              key: const ValueKey('public-player-name'),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 20 : 25,
                  fontWeight: FontWeight.w900,
                  height: 1.4)),
          if (level != null) ...[
            const SizedBox(height: 12),
            Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  PlayerProfileBadge(
                      label: 'المستوى $level',
                      icon: Icons.star_rounded,
                      color: PlayerProfileTheme.cyan),
                  PlayerProfileBadge(
                      label: rank!.nameAr,
                      icon: rank.icon,
                      color: const Color(0xFFE4D0FF)),
                ]),
          ],
          if (league != null) ...[
            const SizedBox(height: 10),
            PlayerProfileBadge(
                label: 'الدوري ${league.nameAr}', icon: league.icon),
          ],
          if (code is String && code.trim().isNotEmpty) ...[
            SizedBox(height: compact ? 12 : 20),
            Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                    horizontal: 12, vertical: compact ? 8 : 12),
                decoration: PlayerProfileTheme.panelDecoration(
                    accent: PlayerProfileTheme.gold, radius: 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('رمز اللاعب',
                      style: TextStyle(
                          color: PlayerProfileTheme.muted, fontSize: 12)),
                  const SizedBox(height: 4),
                  SelectableText(code.trim(),
                      key: const ValueKey('public-player-code'),
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: PlayerProfileTheme.gold,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8)),
                ])),
          ],
        ]));
  }

  List<({String label, String value, IconData icon})> _stats(
      Map<String, dynamic> profile) {
    final stats = <({String label, String value, IconData icon})>[];
    void add(String label, int? value, IconData icon, {bool percent = false}) {
      if (value == null || (percent && value > 100)) return;
      stats.add(
          (label: label, value: '$value${percent ? '%' : ''}', icon: icon));
    }

    final games =
        _number(profile, 'gamesPlayed') ?? _number(profile, 'totalMatches');
    final wins = _number(profile, 'wins');
    final publishedWinRate = _number(profile, 'winPercent');
    final winRate = publishedWinRate ??
        (games != null && games > 0 && wins != null && wins <= games
            ? (wins * 100 / games).round()
            : null);
    add('الانتصارات', wins, Icons.emoji_events_rounded);
    add('المباريات', games, Icons.sports_esports_rounded);
    add('نسبة الفوز', winRate, Icons.trending_up_rounded, percent: true);
    add('الإجابات الصحيحة', _number(profile, 'correctAnswers'),
        Icons.check_circle_rounded);
    add('الدقة', _number(profile, 'accuracy'), Icons.gps_fixed_rounded,
        percent: true);
    add(
        'أفضل سلسلة',
        _number(profile, 'bestWinStreak') ?? _number(profile, 'bestStreak'),
        Icons.local_fire_department_rounded);
    return stats;
  }

  Widget _statTile(({String label, String value, IconData icon}) stat,
          {bool compact = false}) =>
      PlayerProfileMetric(
          key: ValueKey('public-stat:${stat.label}'),
          icon: stat.icon,
          label: stat.label,
          value: stat.value,
          compact: compact,
          accent: PlayerProfileTheme.cyan);

  Widget _achievements(Map<String, dynamic> profile, {bool compact = false}) {
    final trophies = _number(profile, 'trophies');
    final stats = _stats(profile);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (trophies != null) ...[
        Container(
            padding: EdgeInsets.all(compact ? 12 : 20),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFF0B3),
                      Color(0xFFFFD66E),
                      Color(0xFFEAB34B)
                    ]),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFFFEABD), width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF8B571A), offset: Offset(0, 5)),
                  BoxShadow(
                      color: Color(0x440B0320),
                      blurRadius: 18,
                      offset: Offset(0, 10)),
                ]),
            child: Row(children: [
              Container(
                  width: compact ? 44 : 60,
                  height: compact ? 44 : 64,
                  decoration: BoxDecoration(
                      color: const Color(0xFFAA7020).withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFFFF4CD))),
                  child: Icon(Icons.emoji_events_rounded,
                      color: const Color(0xFF8F5415), size: compact ? 32 : 43)),
              SizedBox(width: compact ? 12 : 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('$trophies',
                        key: const ValueKey('public-player-trophies'),
                        style: TextStyle(
                            color: const Color(0xFF54320D),
                            fontSize: compact ? 26 : 32,
                            height: compact ? 1.1 : null,
                            fontWeight: FontWeight.w900)),
                    Text('الكؤوس',
                        style: TextStyle(
                            color: const Color(0xFF8C602A),
                            fontSize: 13,
                            height: compact ? 1.3 : null,
                            fontWeight: FontWeight.w700)),
                  ])),
            ])),
        SizedBox(height: compact ? 14 : 24),
      ],
      Row(children: [
        const Icon(Icons.bar_chart_rounded,
            color: PlayerProfileTheme.gold, size: 23),
        const SizedBox(width: 8),
        Expanded(
            child: Text('الإحصاءات',
                style: TextStyle(
                    color: PlayerProfileTheme.gold,
                    fontSize: compact ? 17 : 20,
                    fontWeight: FontWeight.w900))),
      ]),
      SizedBox(height: compact ? 10 : 12),
      if (stats.isEmpty)
        const PlayerProfilePanel(
            accent: PlayerProfileTheme.cyan,
            padding: EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.insights_rounded,
                  color: PlayerProfileTheme.cyan, size: 32),
              SizedBox(height: 12),
              Text('لا توجد إحصاءات متاحة لهذا اللاعب بعد.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: PlayerProfileTheme.muted,
                      fontSize: 13,
                      height: 1.7)),
            ]))
      else
        LayoutBuilder(builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final columns = scale > 1.4 || constraints.maxWidth < 250
              ? 1
              : constraints.maxWidth >= (compact ? 380 : 520) && scale <= 1.25
                  ? 3
                  : 2;
          final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final stat in stats)
              SizedBox(width: width, child: _statTile(stat, compact: compact)),
          ]);
        }),
    ]);
  }

  Widget _error({required bool hasProfile}) => PlayerProfilePanel(
      padding: const EdgeInsets.all(20),
      accent: const Color(0xFFFFACA7),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, color: Color(0xFFE7D8F7), size: 32),
        const SizedBox(height: 10),
        Text(hasProfile ? 'تعذر تحديث ملف اللاعب.' : 'تعذر تحميل ملف اللاعب.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, height: 1.6)),
        const SizedBox(height: 14),
        PlayerProfileActionButton(
            onPressed: _load,
            icon: Icons.refresh_rounded,
            label: 'إعادة المحاولة'),
      ]));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final compact =
        size.height < 440 && size.width > size.height && textScale <= 1.25;
    return PlayerProfileShell(
        title: 'ملف اللاعب',
        subtitle: 'إنجازات اللاعب وإحصاءاته',
        onBack: () => Navigator.of(context).maybePop(),
        child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 24),
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_loading) ...[
                            ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: const LinearProgressIndicator(
                                    minHeight: 4,
                                    color: PlayerProfileTheme.gold,
                                    backgroundColor: Color(0xFF4C2E71))),
                            const SizedBox(height: 16),
                          ],
                          if (_profile == null && _loading)
                            const PlayerProfilePanel(
                                accent: PlayerProfileTheme.cyan,
                                padding: EdgeInsets.all(28),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person_search_rounded,
                                          color: PlayerProfileTheme.gold,
                                          size: 40),
                                      SizedBox(height: 14),
                                      Text('جارٍ تحميل ملف اللاعب…',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: PlayerProfileTheme.muted)),
                                    ])),
                          if (_failed) ...[
                            _error(hasProfile: _profile != null),
                            const SizedBox(height: 18),
                          ],
                          if (_profile != null)
                            LayoutBuilder(builder: (context, constraints) {
                              final profile = _profile!;
                              final scale =
                                  MediaQuery.textScalerOf(context).scale(14) /
                                      14;
                              if (constraints.maxWidth >= 660 &&
                                  scale <= 1.35) {
                                return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                          flex: 4,
                                          child: _identity(profile,
                                              compact: compact)),
                                      const SizedBox(width: 20),
                                      Expanded(
                                          flex: 6,
                                          child: _achievements(profile,
                                              compact: compact)),
                                    ]);
                              }
                              return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _identity(profile, compact: compact),
                                    const SizedBox(height: 24),
                                    _achievements(profile, compact: compact)
                                  ]);
                            }),
                        ])))));
  }
}
