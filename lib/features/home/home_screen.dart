import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../models/user_profile.dart';
import '../../state/auth_provider.dart';
import '../../state/home_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  Timer? _countdownTimer;
  Duration _dailyRemaining = _timeToNextDay();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _dailyRemaining = _timeToNextDay());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final user = context.read<AuthProvider>().user;
    final homeProvider = context.read<HomeProvider>();
    Future.microtask(() => homeProvider.load(user));
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final home = context.watch<HomeProvider>();
    final media = MediaQuery.sizeOf(context);
    final compact = media.height < 720;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _StarFieldBackground()),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(18, compact ? 12 : 18, 18, 28),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      _StaggeredEntry(
                        controller: _entryController,
                        order: 0,
                        child: const _Header(),
                      ),
                      const SizedBox(height: 14),
                      _StaggeredEntry(
                        controller: _entryController,
                        order: 1,
                        child: _PlayerPanel(user: user, home: home),
                      ),
                      const SizedBox(height: 12),
                      _StaggeredEntry(
                        controller: _entryController,
                        order: 2,
                        child: const _ChallengeNotice(),
                      ),
                      const SizedBox(height: 18),
                      _StaggeredEntry(
                        controller: _entryController,
                        order: 3,
                        child: const _SectionTitle('اختر وضع اللعب:'),
                      ),
                      const SizedBox(height: 12),
                      _StaggeredEntry(
                        controller: _entryController,
                        order: 4,
                        child: const _GameModesGrid(),
                      ),
                      const SizedBox(height: 20),
                      _StaggeredEntry(
                        controller: _entryController,
                        order: 5,
                        child: _DailyHotChallenge(
                          remaining: _dailyRemaining,
                          onlinePlayers: _onlinePlayers(home),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _StaggeredEntry(
                        controller: _entryController,
                        order: 6,
                        child: const _QuickLinks(),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Duration _timeToNextDay() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    return next.difference(now);
  }

  int _onlinePlayers(HomeProvider home) {
    return 96 + home.recentMatches.length * 7 + DateTime.now().minute % 21;
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.challengeGold, AppColors.challengeOrange],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AppColors.challengeGold.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.emoji_events_rounded,
            color: AppColors.challengeDark,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'أرض التحدي',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontFamilyFallback: ['Tajawal', 'Arial'],
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              color: AppColors.challengeLight,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.quickMatch),
          child: const Text(
            AppStrings.playNow,
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'الإعدادات',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    );
  }
}

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({required this.user, required this.home});

  final UserProfile? user;
  final HomeProvider home;

  @override
  Widget build(BuildContext context) {
    final username = user?.username ?? 'لاعب';
    final level = user?.level ?? 1;
    final xp = user?.xp ?? 0;
    final trophies = user?.trophies ?? home.trophies;
    final coins = user?.coins ?? home.coins;

    return _GlassSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              _Avatar(user: user),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$username 🎯 Level $level',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontFamilyFallback: ['Tajawal', 'Arial'],
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: ((xp % 3000) / 3000).clamp(0.08, 1.0),
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.challengeGold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  icon: Icons.star_rounded,
                  label: '$xp XP',
                  color: AppColors.challengeYellow,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  icon: Icons.emoji_events_rounded,
                  label: '$trophies كأس',
                  color: AppColors.challengeGold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  icon: Icons.monetization_on_rounded,
                  label: '$coins',
                  color: AppColors.challengeGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChallengeNotice extends StatelessWidget {
  const _ChallengeNotice();

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      tint: AppColors.challengeOrange,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.challengeOrange.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: AppColors.challengeOrange,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'صديقك Ahmed يتحداك!',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.friends),
            child: const Text('عرض'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Cairo',
        fontFamilyFallback: ['Tajawal', 'Arial'],
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: AppColors.challengeLight,
      ),
    );
  }
}

class _GameModesGrid extends StatelessWidget {
  const _GameModesGrid();

  @override
  Widget build(BuildContext context) {
    final modes = [
      _ModeData(
        icon: Icons.flash_on_rounded,
        title: 'سريع',
        subtitle: '1v1',
        colors: const [AppColors.challengeCyan, AppColors.challengeBlue],
        route: AppRoutes.quickMatch,
      ),
      _ModeData(
        icon: Icons.home_work_rounded,
        title: 'غرفة',
        subtitle: 'خاصة',
        colors: const [AppColors.challengeGold, AppColors.challengeOrange],
        route: AppRoutes.createRoom,
      ),
      _ModeData(
        icon: Icons.groups_rounded,
        title: 'فرق',
        subtitle: '2v2',
        colors: const [AppColors.challengeGreen, Color(0xFF14B8A6)],
        route: AppRoutes.createRoom,
      ),
      _ModeData(
        icon: Icons.calendar_month_rounded,
        title: 'تحدي',
        subtitle: 'يومي',
        colors: const [AppColors.challengePink, AppColors.challengePurple],
        route: AppRoutes.dailyChallenge,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: modes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.12,
      ),
      itemBuilder: (context, index) => _GameModeTile(data: modes[index]),
    );
  }
}

class _DailyHotChallenge extends StatelessWidget {
  const _DailyHotChallenge({
    required this.remaining,
    required this.onlinePlayers,
  });

  final Duration remaining;
  final int onlinePlayers;

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      padding: const EdgeInsets.all(16),
      tint: AppColors.challengePink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '🔥 تحديات اليوم الساخنة:',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontFamilyFallback: ['Tajawal', 'Arial'],
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
              _OnlineBadge(count: onlinePlayers),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.challengePurple.withValues(alpha: 0.58),
                  AppColors.challengeBlue.withValues(alpha: 0.28),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.challengePurple.withValues(alpha: 0.20),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.psychology_alt_rounded,
                    color: AppColors.challengeGold,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لغز الثقافة العربية',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'أسئلة سريعة، روابط ذكية، ونقاط مضاعفة اليوم.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.challengeGray,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'ينتهي خلال',
                      style: TextStyle(
                        color: AppColors.challengeGray,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDuration(remaining),
                      style: const TextStyle(
                        color: AppColors.challengeGold,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.challengeGold, AppColors.challengeOrange],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.challengeOrange.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: TextButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.dailyChallenge),
                icon: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.challengeDark,
                ),
                label: const Text(
                  'العب الآن',
                  style: TextStyle(
                    color: AppColors.challengeDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LinkButton(
            icon: Icons.leaderboard_rounded,
            label: 'لوحة المتصدرين',
            color: AppColors.challengeCyan,
            route: AppRoutes.leaderboard,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _LinkButton(
            icon: Icons.diversity_3_rounded,
            label: 'الأصدقاء',
            color: AppColors.challengeGreen,
            route: AppRoutes.friends,
          ),
        ),
      ],
    );
  }
}

class _GameModeTile extends StatefulWidget {
  const _GameModeTile({required this.data});

  final _ModeData data;

  @override
  State<_GameModeTile> createState() => _GameModeTileState();
}

class _GameModeTileState extends State<_GameModeTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 90),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.pushNamed(context, widget.data.route),
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.data.colors,
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: widget.data.colors.last.withValues(alpha: 0.30),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.data.icon, color: Colors.white, size: 36),
                const SizedBox(height: 10),
                Text(
                  widget.data.title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontFamilyFallback: ['Tajawal', 'Arial'],
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                    color: Colors.white,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.data.subtitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.86),
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String route;

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      padding: EdgeInsets.zero,
      tint: color,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.pushNamed(context, route),
          child: SizedBox(
            height: 58,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.challengeGreen.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.challengeGreen.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PulseDot(),
          const SizedBox(width: 6),
          Text(
            '$count أونلاين',
            style: const TextStyle(
              color: AppColors.challengeGreen,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.82,
        end: 1.15,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.challengeGreen,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 5),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    final username = user?.username ?? '؟';
    final photoUrl = user?.photoUrl;
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.challengeCyan, AppColors.challengePurple],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.challengeBlue.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: photoUrl == null || photoUrl.isEmpty
            ? ColoredBox(
                color: AppColors.challengeNavy,
                child: Center(
                  child: Text(
                    username.characters.first,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            : Image.network(photoUrl, fit: BoxFit.cover),
      ),
    );
  }
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.tint = AppColors.challengeCyan,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.075),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _StaggeredEntry extends StatelessWidget {
  const _StaggeredEntry({
    required this.controller,
    required this.order,
    required this.child,
  });

  final AnimationController controller;
  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (order * 0.075).clamp(0.0, 0.72);
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(
        start,
        (start + 0.36).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

class _ModeData {
  const _ModeData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final String route;
}

class _StarFieldBackground extends StatelessWidget {
  const _StarFieldBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarFieldPainter());
  }
}

class _StarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final rect = Offset.zero & size;
    paint.shader = const LinearGradient(
      colors: [
        Color(0xFF08111F),
        Color(0xFF17213B),
        Color(0xFF250C33),
        Color(0xFF0A101E),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(rect);
    canvas.drawRect(rect, paint);
    paint.shader = null;

    for (var i = 0; i < 90; i++) {
      final x = (math.sin(i * 12.9898) * 43758.5453).abs() % 1 * size.width;
      final y = (math.sin(i * 78.233) * 24634.6345).abs() % 1 * size.height;
      final radius = 0.6 + (i % 4) * 0.24;
      final alpha = 0.16 + (i % 5) * 0.055;
      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.challengeCyan.withValues(alpha: 0.08);
    for (var i = 0; i < 7; i++) {
      final y = size.height * (0.14 + i * 0.12);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 32), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
