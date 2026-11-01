import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/app_state.dart';
import '../../core/player_rank.dart';
import '../../core/trophy_league.dart';
import '../../widgets/adaptive_asset_image.dart';
import '../../widgets/game_notice.dart';
import '../../widgets/player_profile_theme.dart';
import '../../widgets/progression_guide.dart';
import '../character/character_select_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      await context.read<AppState>().checkAndAwardXpForGames();
    } catch (_) {
      // Keep the local snapshot available when synchronization fails.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _showEditUsernameDialog() async {
    final app = context.read<AppState>();
    final name = await showDialog<String>(
        context: context,
        builder: (_) =>
            _EditUsernameDialog(initialName: app.user?.displayName ?? ''));
    if (name == null || name.isEmpty || !mounted) return;
    final messenger = GameNoticeMessenger.of(context);
    try {
      await app.updateUsername(name);
      messenger.showSnackBar(const SnackBar(
          content: Text('تم تحديث الاسم بنجاح'),
          backgroundColor: Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('فشل تحديث الاسم، حاول مرة أخرى'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return PlayerProfileShell(
      title: 'الملف الشخصي',
      subtitle: 'رحلتك، إنجازاتك، ومكانك بين الأبطال',
      onBack: () => Navigator.of(context).maybePop(),
      action: IconButton(
          tooltip: 'دليل التقدم والمكافآت',
          color: PlayerProfileTheme.gold,
          onPressed: () {
            AppSettings.playClick();
            showProgressionGuide(context);
          },
          icon: const Icon(Icons.info_outline_rounded)),
      child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: PlayerProfileTheme.gold))
              : _ProfileDashboard(
                  app: app, onEditName: _showEditUsernameDialog)),
    );
  }
}

class _ProfileDashboard extends StatelessWidget {
  const _ProfileDashboard({required this.app, required this.onEditName});
  final AppState app;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    final stats = app.playerStats;
    int value(String key) => stats[key] ?? 0;
    final games = value('gamesPlayed'), wins = value('wins');
    final correct = value('correctAnswers'), wrong = value('wrongAnswers');
    final answered =
        value('totalAnswered') > 0 ? value('totalAnswered') : correct + wrong;
    final accuracy =
        answered > 0 ? (correct * 100 / answered).round().clamp(0, 100) : 0;
    final winRate = games > 0 ? (wins * 100 / games).round().clamp(0, 100) : 0;
    final metrics = [
      (
        Icons.sports_esports_rounded,
        'المباريات',
        _compactNumber(games),
        PlayerProfileTheme.cyan
      ),
      (
        Icons.emoji_events_rounded,
        'الفوز',
        _compactNumber(wins),
        PlayerProfileTheme.gold
      ),
      (
        Icons.flag_rounded,
        'الخسائر',
        _compactNumber(value('losses')),
        const Color(0xFFFFA0BD)
      ),
      (Icons.task_alt_rounded, 'الدقة', '$accuracy%', const Color(0xFF9DFFAF)),
      (
        Icons.balance_rounded,
        'التعادلات',
        _compactNumber(value('draws')),
        PlayerProfileTheme.cyan
      ),
      (
        Icons.local_fire_department_rounded,
        'سلسلة الفوز',
        _compactNumber(value('winStreak')),
        PlayerProfileTheme.gold
      ),
      (
        Icons.exit_to_app_rounded,
        'الانسحابات',
        _compactNumber(value('abandoned')),
        const Color(0xFFFFC28C)
      ),
      (
        Icons.public_rounded,
        'فوز أونلاين',
        _compactNumber(value('onlineWins')),
        PlayerProfileTheme.cyan
      ),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final wide = constraints.maxWidth >= 700 && scale <= 1.35;
      final identity = _IdentityPanel(
          app: app,
          onEditName: onEditName,
          compact: wide && constraints.maxHeight < 350);
      final details =
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _SectionTitle('إحصاءات اللعب', icon: Icons.insights_rounded),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, area) {
          final columns = scale > 1.4 || area.maxWidth < 250
              ? 1
              : area.maxWidth >= 400 && scale <= 1.25
                  ? 4
                  : 2;
          final width = (area.maxWidth - 12 * (columns - 1)) / columns;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final metric in metrics)
              SizedBox(
                  width: width,
                  child: PlayerProfileMetric(
                      icon: metric.$1,
                      label: metric.$2,
                      value: metric.$3,
                      accent: metric.$4,
                      compact: wide)),
          ]);
        }),
        const SizedBox(height: 20),
        _LevelPanel(app: app),
        const SizedBox(height: 20),
        _ProgressionPanel(
            app: app, winRate: winRate, correct: correct, wrong: wrong),
      ]);
      return SingleChildScrollView(
        key: const ValueKey('own-profile-scroll'),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 22),
        child: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            SizedBox(
                                width: constraints.maxWidth >= 900 ? 290 : 244,
                                child: identity),
                            const SizedBox(width: 20),
                            Expanded(child: details)
                          ])
                    : Column(children: [
                        identity,
                        const SizedBox(height: 24),
                        details
                      ]))),
      );
    });
  }
}

class _IdentityPanel extends StatelessWidget {
  const _IdentityPanel(
      {required this.app, required this.onEditName, required this.compact});
  final AppState app;
  final VoidCallback onEditName;
  final bool compact;

  void _chooseCharacter(BuildContext context) {
    AppSettings.playClick();
    Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const CharacterSelectScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final user = app.user;
    final name =
        (user?.displayName ?? user?.email?.split('@').first ?? 'لاعب').trim();
    final rank = PlayerRank.tierForLevel(app.level);
    return PlayerProfilePanel(
      padding:
          EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 12 : 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Tooltip(
            message: 'اختيار الشخصية',
            child: InkWell(
                onTap: () => _chooseCharacter(context),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                    width: compact ? 76 : 106,
                    height: compact ? 76 : 106,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFF4C3),
                              Color(0xFFE3AE47),
                              Color(0xFFFFDE7A),
                              Color(0xFF9C671E)
                            ]),
                        border: Border.all(color: const Color(0xFF9C702C), width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0xFF7D5424), offset: Offset(0, 4))
                        ]),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(23),
                        child: ColoredBox(
                            color: PlayerProfileTheme.purple,
                            child: adaptiveAssetImage(app.selectedCharacter.asset,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                    size: 58))))))),
        SizedBox(height: compact ? 10 : 16),
        Row(children: [
          Expanded(
              child: Text(name.isEmpty ? 'لاعب' : name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 20 : 23,
                      fontWeight: FontWeight.w900,
                      height: 1.35))),
          IconButton(
              tooltip: 'تعديل الاسم',
              onPressed: () {
                AppSettings.playClick();
                onEditName();
              },
              color: PlayerProfileTheme.gold,
              icon: const Icon(Icons.edit_rounded, size: 20)),
        ]),
        const SizedBox(height: 10),
        PlayerProfileBadge(
            label: 'المستوى ${app.level}',
            icon: Icons.star_rounded,
            color: PlayerProfileTheme.cyan),
        const SizedBox(height: 8),
        PlayerProfileBadge(
            label: 'رتبة الخبرة: ${rank.nameAr}',
            icon: rank.icon,
            color: const Color(0xFFE4D0FF)),
        const SizedBox(height: 18),
        const _AccountStrip(),
        const SizedBox(height: 16),
        SizedBox(
            width: double.infinity,
            child: PlayerProfileActionButton(
                label: 'اختيار الشخصية',
                icon: Icons.face_rounded,
                onPressed: () => _chooseCharacter(context))),
      ]),
    );
  }
}

class _LevelPanel extends StatelessWidget {
  const _LevelPanel({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final next = PlayerRank.nextTierForLevel(app.level);
    final progress = app.xpNeededForLevel > 0
        ? (app.xpInCurrentLevel / app.xpNeededForLevel).clamp(0.0, 1.0)
        : 0.0;
    return PlayerProfilePanel(
        accent: PlayerProfileTheme.cyan,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _SectionTitle('رحلة الخبرة', icon: Icons.auto_awesome_rounded),
          const SizedBox(height: 14),
          _ProgressLine(
              title: 'المستوى ${app.level}',
              value: '${app.xpInCurrentLevel}/${app.xpNeededForLevel} XP',
              progress: progress,
              color: PlayerProfileTheme.cyan),
          const SizedBox(height: 10),
          Text('${_compactNumber(app.xp)} XP إجمالي',
              style: const TextStyle(
                  color: PlayerProfileTheme.muted, fontSize: 13)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final tier in PlayerRank.tiers)
              Tooltip(
                  message: '${tier.nameAr} - مستوى ${tier.minLevel}',
                  child: Container(
                      width: 38,
                      height: 38,
                      decoration: PlayerProfileTheme.panelDecoration(
                          accent: app.level >= tier.minLevel
                              ? PlayerProfileTheme.gold
                              : const Color(0xFF9D7DC5),
                          subtle: true,
                          radius: 12),
                      child: Icon(tier.icon,
                          size: 21,
                          color: app.level >= tier.minLevel
                              ? PlayerProfileTheme.gold
                              : const Color(0xFF9D7DC5)))),
          ]),
          const SizedBox(height: 12),
          Text(
              next == null
                  ? 'وصلت إلى أعلى رتبة!'
                  : 'الرتبة القادمة: ${next.nameAr} • المستوى ${next.minLevel}',
              style: const TextStyle(
                  color: PlayerProfileTheme.muted, fontSize: 13, height: 1.5)),
        ]));
  }
}

class _ProgressionPanel extends StatelessWidget {
  const _ProgressionPanel(
      {required this.app,
      required this.winRate,
      required this.correct,
      required this.wrong});
  final AppState app;
  final int winRate, correct, wrong;

  @override
  Widget build(BuildContext context) {
    final league = TrophyProgression.leagueFor(app.trophies);
    final next = TrophyProgression.nextLeagueFor(app.trophies);
    return PlayerProfilePanel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _SectionTitle('دوري الكؤوس', icon: Icons.emoji_events_rounded),
      const SizedBox(height: 16),
      _ProgressLine(
          title: TrophyProgression.divisionLabelFor(app.trophies),
          value: '${_compactNumber(app.trophies)} كأس',
          progress: league.progress(app.trophies),
          color: PlayerProfileTheme.gold),
      const SizedBox(height: 10),
      Text(
          next == null
              ? 'وصلت إلى أعلى دوري!'
              : '${league.trophiesLeft(app.trophies)} كأس للـ ${next.nameAr}',
          style:
              const TextStyle(color: PlayerProfileTheme.muted, fontSize: 13)),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        PlayerProfileBadge(
            label: '$winRate% فوز',
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF9DFFAF)),
        PlayerProfileBadge(
            label: '${_compactNumber(correct)} صحيح',
            icon: Icons.check_circle_rounded,
            color: PlayerProfileTheme.cyan),
        PlayerProfileBadge(
            label: '${_compactNumber(wrong)} خطأ',
            icon: Icons.cancel_rounded,
            color: const Color(0xFFFFA0BD)),
      ]),
      const SizedBox(height: 20),
      Text('الكؤوس • أفضل رصيد ${app.bestTrophies}',
          style: const TextStyle(
              color: PlayerProfileTheme.gold,
              fontSize: 16,
              fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      for (final rule in TrophyProgression.rules) ...[
        Container(
            padding: const EdgeInsets.all(12),
            decoration: PlayerProfileTheme.panelDecoration(
                subtle: true, accent: rule.color, radius: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(rule.icon, color: rule.color, size: 21),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(rule.label,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13, height: 1.5)),
                    const SizedBox(height: 4),
                    Text(rule.value,
                        style: TextStyle(
                            color: rule.color,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1.5)),
                  ])),
            ])),
        if (rule != TrophyProgression.rules.last) const SizedBox(height: 8),
      ],
    ]));
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine(
      {required this.title,
      required this.value,
      required this.progress,
      required this.color});
  final String title, value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              Text(value,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                      color: PlayerProfileTheme.muted, fontSize: 13)),
            ]),
        const SizedBox(height: 9),
        Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
                color: const Color(0xFF190B36),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: .4))),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.transparent,
                    color: color))),
      ]);
}

class _AccountStrip extends StatelessWidget {
  const _AccountStrip();
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final code = app.friendCode, uid = app.user?.uid ?? '';
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: PlayerProfileTheme.panelDecoration(radius: 16),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('كود التحدي',
                    style: TextStyle(
                        color: PlayerProfileTheme.muted, fontSize: 12)),
                const SizedBox(height: 3),
                Text(code.isNotEmpty ? code : (uid.isEmpty ? 'حساب محلي' : uid),
                    textDirection: code.isNotEmpty || uid.isNotEmpty
                        ? TextDirection.ltr
                        : TextDirection.rtl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: PlayerProfileTheme.gold,
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ])),
          if (code.isNotEmpty)
            IconButton(
                tooltip: 'نسخ كود التحدي',
                color: PlayerProfileTheme.gold,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  HapticFeedback.selectionClick();
                  GameNoticeMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('تم نسخ كود التحدي: $code'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating));
                },
                icon: const Icon(Icons.copy_rounded, size: 20)),
        ]));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {required this.icon});
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: PlayerProfileTheme.gold, size: 24),
        const SizedBox(width: 9),
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: PlayerProfileTheme.gold,
                    fontSize: 19,
                    fontWeight: FontWeight.w900))),
      ]);
}

class _EditUsernameDialog extends StatefulWidget {
  const _EditUsernameDialog({required this.initialName});
  final String initialName;
  @override
  State<_EditUsernameDialog> createState() => _EditUsernameDialogState();
}

class _EditUsernameDialogState extends State<_EditUsernameDialog> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                  child: PlayerProfilePanel(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                    const _SectionTitle('تغيير الاسم',
                        icon: Icons.edit_rounded),
                    const SizedBox(height: 18),
                    TextField(
                        controller: _controller,
                        autofocus: true,
                        maxLength: 20,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                            hintText: 'اسم اللاعب الجديد',
                            hintStyle: const TextStyle(
                                color: PlayerProfileTheme.muted),
                            counterStyle: const TextStyle(
                                color: PlayerProfileTheme.muted),
                            filled: true,
                            fillColor: const Color(0xFF22103E),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: PlayerProfileTheme.gold)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFF9069AF))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: PlayerProfileTheme.gold,
                                    width: 2)))),
                    const SizedBox(height: 12),
                    Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          PlayerProfileActionButton(
                              label: 'إلغاء',
                              secondary: true,
                              onPressed: () => Navigator.of(context).pop()),
                          PlayerProfileActionButton(
                              label: 'حفظ',
                              icon: Icons.check_rounded,
                              onPressed: _submit),
                        ]),
                  ]))))));
}

String _compactNumber(int value) {
  final abs = value.abs();
  if (abs >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(abs >= 10000000 ? 0 : 1)}m';
  }
  if (abs >= 1000) {
    return '${(value / 1000).toStringAsFixed(abs >= 10000 ? 0 : 1)}k';
  }
  return '$value';
}
