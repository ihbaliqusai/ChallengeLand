import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/player_rank.dart';
import '../../core/trophy_league.dart';
import '../../services/social_service.dart';

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
  static const _gold = Color(0xFFFFD46B);
  static const _ink = Color(0xFF352348);
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

  Widget _avatar(Map<String, dynamic> profile) {
    final photo = profile['photoUrl'];
    final uri = photo is String ? Uri.tryParse(photo) : null;
    Widget fallback() => Container(
        color: const Color(0xFF72538E),
        alignment: Alignment.center,
        child: const Icon(Icons.person_rounded,
            size: 58, color: Color(0xFFECE4F5)));
    return Container(
        width: 106,
        height: 106,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: const Color(0xFF311E43),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _gold, width: 2),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x44321C45),
                  blurRadius: 18,
                  offset: Offset(0, 8))
            ]),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: uri?.scheme == 'https' && uri!.host.isNotEmpty
                ? Image.network(uri.toString(),
                    fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback())
                : fallback()));
  }

  Widget _badge(String label, IconData icon, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
          color: const Color(0xFF2B183C).withValues(alpha: .45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .35))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 6),
        Flexible(
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w700)))
      ]));

  Widget _identity(Map<String, dynamic> profile) {
    final level = _level(profile);
    final rank = level == null ? null : PlayerRank.tierForLevel(level);
    final trophies = _number(profile, 'trophies');
    final league =
        trophies == null ? null : TrophyProgression.leagueFor(trophies);
    final code = profile['friendCode'];
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF735192), Color(0xFF4A2B66)]),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFF9A79B7)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33301A42),
                  blurRadius: 20,
                  offset: Offset(0, 8))
            ]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _avatar(profile),
          const SizedBox(height: 16),
          Text(_name(profile),
              key: const ValueKey('public-player-name'),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.4)),
          if (level != null) ...[
            const SizedBox(height: 12),
            Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _badge('المستوى $level', Icons.star_rounded,
                      const Color(0xFFE4D0FF)),
                  _badge(rank!.nameAr, rank.icon, const Color(0xFFE4D0FF)),
                ]),
          ],
          if (league != null) ...[
            const SizedBox(height: 10),
            _badge('الدوري ${league.nameAr}', league.icon, _gold),
          ],
          if (code is String && code.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('رمز اللاعب',
                style: TextStyle(color: Color(0xFFD9C8E8), fontSize: 12)),
            const SizedBox(height: 4),
            SelectableText(code.trim(),
                key: const ValueKey('public-player-code'),
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8)),
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

  Widget _statTile(({String label, String value, IconData icon}) stat) =>
      Container(
          key: ValueKey('public-stat:${stat.label}'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
              color: const Color(0xFFEDF3FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFC7D5F4)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x143A234D),
                    blurRadius: 8,
                    offset: Offset(0, 3))
              ]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(stat.icon, color: const Color(0xFF8052AA), size: 24),
            const SizedBox(height: 5),
            Text(stat.value,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                    color: _ink, fontSize: 25, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(stat.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF725781), fontSize: 12, height: 1.4)),
          ]));

  Widget _achievements(Map<String, dynamic> profile) {
    final trophies = _number(profile, 'trophies');
    final stats = _stats(profile);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (trophies != null) ...[
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFFE7A6), Color(0xFFFFD36A)]),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFFFEABD))),
            child: Row(children: [
              const Icon(Icons.emoji_events_rounded,
                  color: Color(0xFF966220), size: 42),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('$trophies',
                        key: const ValueKey('public-player-trophies'),
                        style: const TextStyle(
                            color: Color(0xFF54320D),
                            fontSize: 30,
                            fontWeight: FontWeight.w800)),
                    const Text('الكؤوس',
                        style: TextStyle(
                            color: Color(0xFF8C602A),
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ])),
            ])),
        const SizedBox(height: 22),
      ],
      const Text('الإحصاءات',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      if (stats.isEmpty)
        Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                color: const Color(0xFF604078),
                borderRadius: BorderRadius.circular(20)),
            child: const Text('لا توجد إحصاءات متاحة لهذا اللاعب بعد.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFFE5D7F1), fontSize: 13, height: 1.7)))
      else
        LayoutBuilder(builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final columns = constraints.maxWidth >= 520 && scale <= 1.25 ? 3 : 2;
          final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final stat in stats)
              SizedBox(width: width, child: _statTile(stat)),
          ]);
        }),
    ]);
  }

  Widget _error({required bool hasProfile}) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xFF56336E),
          borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, color: Color(0xFFE7D8F7), size: 32),
        const SizedBox(height: 10),
        Text(hasProfile ? 'تعذر تحديث ملف اللاعب.' : 'تعذر تحميل ملف اللاعب.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, height: 1.6)),
        const SizedBox(height: 14),
        FilledButton.icon(
            onPressed: _load,
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: _ink),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('إعادة المحاولة')),
      ]));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Theme(
            data: theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'Baloo')),
            child: Container(
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF3D234F), Color(0xFF644282)])),
                child: Scaffold(
                    backgroundColor: Colors.transparent,
                    appBar: AppBar(
                        title: const Text('ملف اللاعب',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        surfaceTintColor: Colors.transparent),
                    body: SafeArea(
                        top: false,
                        child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                            child: Center(
                                child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 960),
                                    child: Column(children: [
                                      if (_loading) ...[
                                        const LinearProgressIndicator(
                                            color: _gold,
                                            backgroundColor: Color(0xFF79588F)),
                                        const SizedBox(height: 16),
                                      ],
                                      if (_profile == null && _loading)
                                        const Padding(
                                            padding: EdgeInsets.all(32),
                                            child: Text(
                                                'جارٍ تحميل ملف اللاعب…',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    color: Colors.white))),
                                      if (_failed) ...[
                                        _error(hasProfile: _profile != null),
                                        const SizedBox(height: 18),
                                      ],
                                      if (_profile != null)
                                        LayoutBuilder(
                                            builder: (context, constraints) {
                                          final profile = _profile!;
                                          final scale =
                                              MediaQuery.textScalerOf(context)
                                                      .scale(14) /
                                                  14;
                                          if (constraints.maxWidth >= 660 &&
                                              scale <= 1.35) {
                                            return Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                      flex: 4,
                                                      child:
                                                          _identity(profile)),
                                                  const SizedBox(width: 20),
                                                  Expanded(
                                                      flex: 6,
                                                      child: _achievements(
                                                          profile)),
                                                ]);
                                          }
                                          return Column(children: [
                                            _identity(profile),
                                            const SizedBox(height: 24),
                                            _achievements(profile)
                                          ]);
                                        }),
                                    ])))))))));
  }
}
