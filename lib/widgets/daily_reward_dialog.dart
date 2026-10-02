import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_settings.dart';
import '../core/app_state.dart';
import 'currency_reward_overlay.dart';

/// نافذة المكافآت اليومية الفاخرة ذات التصميم العالمي وحركة فتح الصندوق الخارقة
class DailyRewardDialog extends StatefulWidget {
  const DailyRewardDialog({
    super.key,
    this.autoOpen = false,
  });

  final bool autoOpen;

  static bool _isShowing = false;

  /// إظهار نافذة المكافأة اليومية مع حماية ضد التكرار وانتقال سلس ومبهر
  static Future<void> show(
    BuildContext context, {
    bool autoOpen = false,
  }) async {
    if (_isShowing) return;
    _isShowing = true;

    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'DailyRewardDialog',
        barrierColor: Colors.black.withValues(alpha: 0.85),
        transitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (ctx, anim1, anim2) => DailyRewardDialog(autoOpen: autoOpen),
        transitionBuilder: (ctx, anim1, anim2, child) {
          final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
          return ScaleTransition(
            scale: Tween<double>(begin: 0.75, end: 1.0).animate(curve),
            child: FadeTransition(
              opacity: anim1,
              child: child,
            ),
          );
        },
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<DailyRewardDialog> createState() => _DailyRewardDialogState();
}

enum _ChestState {
  closed, // الصندوق مقفل ينتظر النقر
  shaking, // اهتزاز عنيف ورنين قبل الانفجار
  bursting, // وميض وانفجار الجزيئات والصندوق يفتح
  revealed, // خروج الجوائز وتصاعد الأرقام
  alreadyClaimed, // تم الاستلام مسبقاً لهذا اليوم
}

class _DailyRewardDialogState extends State<DailyRewardDialog>
    with TickerProviderStateMixin {
  late final AnimationController _ambientCtrl;
  late final AnimationController _shakeCtrl;
  late final AnimationController _revealCtrl;
  late final AnimationController _flashCtrl;

  _ChestState _state = _ChestState.closed;
  int _awardedCoins = 0;
  int _awardedGems = 0;
  int _streakDay = 1;
  bool _isClaiming = false;

  Timer? _countdownTimer;
  Duration _timeLeftUntilTomorrow = Duration.zero;

  // جسيمات انفجار الصندوق الاحترافية
  final List<_LootParticle> _particles = <_LootParticle>[];
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();

    // 1. تحكم المؤثرات المحيطية (دوران الأشعة، طفو الصندوق، لمعان الوشاح)
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // 2. تحكم الاهتزاز العنيف عند فتح الصندوق
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    // 3. تحكم ظهور الجوائز والأرقام التصاعدية
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // 4. تحكم الوميض الضوئي الساطع لحظة فتح الصندوق
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    final appState = context.read<AppState>();
    _streakDay = appState.streakDay > 0 ? appState.streakDay : 1;
    final reward = appState.todayReward;
    _awardedCoins = reward['coins'] ?? 100;
    _awardedGems = reward['gems'] ?? 0;

    if (appState.claimedToday) {
      _state = _ChestState.alreadyClaimed;
      _updateCountdown();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) _updateCountdown();
      });
    } else {
      _state = _ChestState.closed;
    }

    _spawnParticles();
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final diff = tomorrow.difference(now);
    setState(() {
      _timeLeftUntilTomorrow = diff.isNegative ? Duration.zero : diff;
    });
  }

  void _spawnParticles() {
    _particles.clear();
    const colors = [
      Color(0xFFFFD700), // Gold
      Color(0xFFF59E0B), // Amber
      Color(0xFF38BDF8), // Diamond Cyan
      Color(0xFFA855F7), // Purple Jewel
      Color(0xFFFFFFFF), // White Sparkle
      Color(0xFF22C55E), // Green
      Color(0xFFEF4444), // Ruby Red
    ];

    for (int i = 0; i < 55; i++) {
      final angle = _rng.nextDouble() * 2 * math.pi;
      final speed = 160.0 + _rng.nextDouble() * 280.0;
      _particles.add(
        _LootParticle(
          x: 0,
          y: 0,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed - 60.0, // اندفاع للأعلى قليلاً
          size: 4.0 + _rng.nextDouble() * 6.5,
          color: colors[_rng.nextInt(colors.length)],
          rotation: _rng.nextDouble() * 2 * math.pi,
          rotationSpeed: (_rng.nextDouble() - 0.5) * 8.0,
          shape: _rng.nextInt(4), // 0: Star, 1: Circle, 2: Diamond, 3: Rect
        ),
      );
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ambientCtrl.dispose();
    _shakeCtrl.dispose();
    _revealCtrl.dispose();
    _flashCtrl.dispose();
    super.dispose();
  }

  /// تنفيذ حركة فتح الصندوق بالكامل بمراحل سينمائية متتابعة
  Future<void> _handleOpenChest() async {
    if (_state != _ChestState.closed || _isClaiming) return;
    _isClaiming = true;

    // هزة البداية اللطيفة
    HapticFeedback.mediumImpact();
    try {
      context.read<AppSettings>().playHaptic(style: 'medium');
    } catch (_) {}

    setState(() {
      _state = _ChestState.shaking;
    });

    // تشغيل الاهتزاز العنيف مع نبضات متزامنة
    _shakeCtrl.forward(from: 0.0);

    // نبضات لمسية حركية متسارعة مع اهتزاز الصندوق
    unawaited(Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) HapticFeedback.selectionClick();
    }));
    unawaited(Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) HapticFeedback.mediumImpact();
    }));
    unawaited(Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) HapticFeedback.heavyImpact();
    }));

    // أثناء الاهتزاز يتم تسجيل الجائزة برمجياً في الخلفية
    final appState = context.read<AppState>();
    final claimResult = await appState.claimDailyStreak();
    if (claimResult != null) {
      _awardedCoins = claimResult['coins'] ?? _awardedCoins;
      _awardedGems = claimResult['gems'] ?? _awardedGems;
    }

    // الانتظار حتى اكتمال الهزة المشوقة
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    // لحظة الانفجار الساطع
    _spawnParticles();
    HapticFeedback.heavyImpact();
    try {
      context.read<AppSettings>().playHaptic(style: 'heavy');
    } catch (_) {}

    setState(() {
      _state = _ChestState.bursting;
    });

    // وميض الشاشة الذهبي
    _flashCtrl.forward(from: 0.0).then((_) {
      if (mounted) _flashCtrl.reverse();
    });

    // ظهور الجوائز مع منحنى Spring ارتدادي فائق الروعة
    _revealCtrl.forward(from: 0.0);

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    setState(() {
      _state = _ChestState.revealed;
      _isClaiming = false;
    });
  }

  /// إتمام الاستلام وإغلاق النافذة مع إطلاق الـ Currency Reward Overlay
  void _handleClaimAndClose() {
    HapticFeedback.mediumImpact();
    try {
      context.read<AppSettings>().playHaptic(style: 'medium');
    } catch (_) {}

    Navigator.of(context).pop();

    if (_awardedCoins > 0 || _awardedGems > 0) {
      showCurrencyRewardOverlay(
        context,
        coins: _awardedCoins,
        gems: _awardedGems,
      );
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _getChestImage(int streakDay, bool opened) {
    if (opened) return 'assets/ui/box4.png';
    // تنويع الصناديق حسب فئة اليوم
    final dayIndexInWeek = (streakDay - 1) % 7 + 1;
    if (dayIndexInWeek == 7) {
      return 'assets/ui/box3.png'; // الصندوق الذهبي الملكي لليوم السابع
    } else if (dayIndexInWeek >= 4) {
      return 'assets/ui/box2.png'; // الصندوق الفضي المتطور
    } else {
      return 'assets/ui/box1.png'; // الصندوق البرونزي الأساسي
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLandscape =
        media.orientation == Orientation.landscape || media.size.height < 520;

    // عرض النافذة متناسق تماماً مع شاشات اللعبة الأفقية بدون أي overflow
    final dialogWidth = isLandscape
        ? (media.size.width * 0.74).clamp(440.0, 680.0)
        : (media.size.width * 0.94).clamp(320.0, 420.0);

    final isChestOpen = _state == _ChestState.bursting ||
        _state == _ChestState.revealed ||
        _state == _ChestState.alreadyClaimed;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: isLandscape ? 4 : 8,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogWidth,
                maxHeight: media.size.height * 0.96,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: SizedBox(
                  width: dialogWidth,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _ambientCtrl,
                      _shakeCtrl,
                      _revealCtrl,
                      _flashCtrl,
                    ]),
                    builder: (context, _) {
                      return Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // 1. البطاقة الأساسية الملكية
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // الوشاح العلوي المذهب
                              _buildHeaderRibbon(isLandscape),

                              const SizedBox(height: 3),

                              // الصندوق الرئيسي والمحتوى
                              _buildMainCard(
                                context,
                                isLandscape,
                                isChestOpen,
                              ),
                            ],
                          ),

                          // 2. وميض الانفجار الأبيض/الذهبي الساطع عند الفتح
                          if (_flashCtrl.value > 0.01)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.white.withValues(
                                          alpha: (_flashCtrl.value * 0.9)
                                              .clamp(0.0, 1.0),
                                        ),
                                        const Color(0xFFFFD700).withValues(
                                          alpha: (_flashCtrl.value * 0.6)
                                              .clamp(0.0, 1.0),
                                        ),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.45, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// الوشاح العلوي الملكي بتصميم ثلاثي الأبعاد مع زر الإغلاق X
  Widget _buildHeaderRibbon(bool isLandscape) {
    final bannerHeight = isLandscape ? 38.0 : 42.0;
    final closeBtnSize = isLandscape ? 32.0 : 36.0;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // شريط العنوان المقوس الذهبي والياقوتي
        Container(
          height: bannerHeight,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF3B0764),
                Color(0xFF1E1B4B),
                Color(0xFF0F172A),
                Color(0xFF1E1B4B),
                Color(0xFF3B0764),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFFD700),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              // لمعان متحرك على الوشاح
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CustomPaint(
                    painter: _RibbonSheenPainter(t: _ambientCtrl.value),
                  ),
                ),
              ),

              // العنوان وأيقونة الهدية
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.card_giftcard_rounded,
                      color: Color(0xFFFFD700),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'المكافأة اليومية',
                      style: TextStyle(
                        fontFamily: 'Baloo',
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 4,
                            offset: Offset(0, 1.5),
                          ),
                          Shadow(
                            color: Color(0xFFFFD700),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // شارة السلسلة الحالية
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFFF97316)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEA580C)
                                .withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '🔥',
                            style: TextStyle(fontSize: 11),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'اليوم $_streakDay',
                            style: const TextStyle(
                              fontFamily: 'Baloo',
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // زر X للإغلاق ثلاثي الأبعاد بتصميم ألعاب فاخر
        Positioned(
          left: 4,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: Container(
              width: closeBtnSize,
              height: closeBtnSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.25, -0.3),
                  radius: 0.9,
                  colors: [
                    Color(0xFFEF4444),
                    Color(0xFFB91C1C),
                    Color(0xFF7F1D1D),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFFFFE4E6),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.7),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// البطاقة الأساسية التي تحتوي مسار الـ 7 أيام ومسرح فتح الصندوق
  Widget _buildMainCard(
    BuildContext context,
    bool isLandscape,
    bool isChestOpen,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF0A0F24),
            Color(0xFF13112E),
            Color(0xFF050816),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF59E0B),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // خلفية النجوم والجسيمات العائمة المستمرة
            Positioned.fill(
              child: CustomPaint(
                painter: _AmbientStarsPainter(t: _ambientCtrl.value),
              ),
            ),

            // محتوى البطاقة
            Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                isLandscape ? 8 : 12,
                14,
                isLandscape ? 10 : 14,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. مسار الـ 7 أيام المصغر (Mini 7-Day Timeline)
                  _buildSevenDayTrack(isLandscape),

                  SizedBox(height: isLandscape ? 8 : 12),

                  // 2. مسرح الصندوق البطولي والجوائز
                  _buildHeroChestStage(isLandscape, isChestOpen),

                  SizedBox(height: isLandscape ? 8 : 12),

                  // 3. زر الإجراء التفاعلي (افتح الصندوق أو استلام الجائزة أو الوقت المتبقي)
                  _buildActionButton(isLandscape, isChestOpen),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// مسار مكافآت الـ 7 أيام المصغر بتصميم تفاعلي
  Widget _buildSevenDayTrack(bool isLandscape) {
    // حساب الأيام للأسبوع الحالي
    final currentWeekStart = ((_streakDay - 1) ~/ 7) * 7 + 1;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: isLandscape ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final day = currentWeekStart + i;
          final isPast = day < _streakDay ||
              (day == _streakDay && _state == _ChestState.alreadyClaimed);
          final isToday = day == _streakDay;
          final isMilestone = (i + 1) == 7;

          final reward = AppState.getRewardForDay(day);
          final coins = reward['coins'] ?? 100;
          final gems = reward['gems'] ?? 0;

          // نبض لطيف ليوم اليوم المتاح
          final todayPulse = isToday && _state == _ChestState.closed
              ? (1.0 + math.sin(_ambientCtrl.value * 2 * math.pi) * 0.05)
              : 1.0;

          return Transform.scale(
            scale: todayPulse,
            child: Container(
              width: isLandscape ? 52 : 42,
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
              decoration: BoxDecoration(
                gradient: isToday
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF78350F),
                          Color(0xFFB45309),
                          Color(0xFFD97706),
                        ],
                      )
                    : isPast
                        ? LinearGradient(
                            colors: [
                              const Color(0xFF065F46).withValues(alpha: 0.6),
                              const Color(0xFF047857).withValues(alpha: 0.8),
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.06),
                              Colors.white.withValues(alpha: 0.03),
                            ],
                          ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isToday
                      ? const Color(0xFFFFD700)
                      : isPast
                          ? const Color(0xFF34D399)
                          : isMilestone
                              ? const Color(0xFFA855F7)
                              : Colors.white.withValues(alpha: 0.15),
                  width: isToday ? 1.8 : 1.0,
                ),
                boxShadow: isToday
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFD700)
                              .withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // اسم اليوم
                  Text(
                    isToday ? 'اليوم' : 'يوم $day',
                    style: TextStyle(
                      fontFamily: 'Baloo',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: isToday
                          ? const Color(0xFFFEF08A)
                          : isPast
                              ? const Color(0xFF6EE7B7)
                              : Colors.white.withValues(alpha: 0.7),
                    ),
                  ),

                  const SizedBox(height: 2),

                  // أيقونة الحالة (صح للمستلم، أو هدية، أو قفل)
                  if (isPast)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF34D399),
                      size: 16,
                    )
                  else if (isMilestone)
                    const Text('👑', style: TextStyle(fontSize: 13))
                  else
                    Icon(
                      gems > 0
                          ? Icons.diamond_rounded
                          : Icons.monetization_on_rounded,
                      color: gems > 0
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFFFACC15),
                      size: 14,
                    ),

                  const SizedBox(height: 1),

                  // قيمة الجائزة
                  Text(
                    gems > 0 ? '+$gems 💎' : '+$coins',
                    style: TextStyle(
                      fontFamily: 'Baloo',
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: isToday
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  /// مسرح الصندوق البطولي والرسوم المتحركة ثلاثية الأبعاد
  Widget _buildHeroChestStage(bool isLandscape, bool isChestOpen) {
    final chestImage = _getChestImage(_streakDay, isChestOpen);

    // حساب اهتزاز الصندوق العنيف
    double shakeOffsetX = 0.0;
    double shakeRotate = 0.0;
    double chestScale = 1.0;

    if (_state == _ChestState.shaking) {
      final s = _shakeCtrl.value;
      // تردد اهتزاز سريع جداً
      shakeOffsetX = math.sin(s * 28 * math.pi) * 9.0;
      shakeRotate = math.sin(s * 22 * math.pi) * 0.08;
      // انضغاط تمددي (Squash & Stretch)
      chestScale = 0.94 + math.sin(s * 14 * math.pi) * 0.12;
    } else if (_state == _ChestState.bursting || _state == _ChestState.revealed) {
      // قفزة الارتداد (Elastic Pop) عند الفتح
      final popVal = Curves.elasticOut.transform(_revealCtrl.value);
      chestScale = 0.85 + popVal * 0.22;
    } else {
      // طفو لطيف أثناء الانتظار
      shakeOffsetX = 0;
      shakeRotate = 0;
      chestScale = 1.0;
    }
    final floatOffset = _state == _ChestState.closed
        ? math.sin(_ambientCtrl.value * 2 * math.pi) * 5.0
        : 0.0;

    final stageHeight = isLandscape ? 130.0 : 160.0;

    return SizedBox(
      height: stageHeight,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. أشعة الضوء الشمسية الدوارة خلف الصندوق
          Positioned.fill(
            child: CustomPaint(
              painter: _SunburstRaysPainter(
                angle: _ambientCtrl.value * 2 * math.pi * (_state == _ChestState.shaking ? 4.0 : 1.0),
                color: isChestOpen
                    ? const Color(0xFFFFD700)
                    : const Color(0xFFF59E0B),
                intensity: _state == _ChestState.shaking ? 0.45 : 0.24,
              ),
            ),
          ),

          // 2. الهالة والمنصة المضيئة تحت الصندوق
          Positioned(
            bottom: 6,
            child: Container(
              width: isLandscape ? 160 : 180,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(
                  Radius.elliptical(isLandscape ? 160 : 180, 28),
                ),
                gradient: RadialGradient(
                  colors: [
                    (isChestOpen
                            ? const Color(0xFFFFD700)
                            : const Color(0xFFF59E0B))
                        .withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 3. جسيمات الانفجار الفيزيائية عند الفتح
          if (_state == _ChestState.bursting || _state == _ChestState.revealed)
            Positioned.fill(
              child: CustomPaint(
                painter: _ExplosionParticlesPainter(
                  progress: _revealCtrl.value,
                  particles: _particles,
                ),
              ),
            ),

          // 4. الصندوق القابل للنقر مع الاهتزاز والطفو
          GestureDetector(
            onTap: _state == _ChestState.closed ? _handleOpenChest : null,
            child: Transform.translate(
              offset: Offset(shakeOffsetX, floatOffset),
              child: Transform.rotate(
                angle: shakeRotate,
                child: Transform.scale(
                  scale: chestScale,
                  child: Image.asset(
                    chestImage,
                    height: isLandscape ? 98 : 118,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // 5. بطاقات الجوائز الصاعدة من داخل الصندوق عند الفتح
          if (isChestOpen)
            Positioned(
              top: isLandscape ? -8 : -14,
              child: _buildEmergingLootCards(isLandscape),
            ),

          // 6. نص التوجيه التشويقي في حالة الإغلاق
          if (_state == _ChestState.closed)
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'المس الصندوق لفتحه! ✨👆',
                      style: TextStyle(
                        fontFamily: 'Baloo',
                        color: Color(0xFFFDE047),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// بطاقات الجوائز الصاعدة من الصندوق بالأرقام التدريجية
  Widget _buildEmergingLootCards(bool isLandscape) {
    final revealVal = _revealCtrl.value;
    final scale = _state == _ChestState.alreadyClaimed
        ? 1.0
        : Curves.elasticOut.transform(revealVal);
    final countMultiplier = _state == _ChestState.alreadyClaimed
        ? 1.0
        : Curves.easeOutCubic.transform(revealVal);

    final displayCoins = (_awardedCoins * countMultiplier).toInt();
    final displayGems = (_awardedGems * countMultiplier).toInt();

    return Transform.scale(
      scale: scale.clamp(0.0, 1.15),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // بطاقة الذهب
          _buildLootChip(
            icon: Icons.monetization_on_rounded,
            iconColor: const Color(0xFFFACC15),
            borderColor: const Color(0xFFFFD700),
            gradientColors: const [Color(0xFF78350F), Color(0xFFB45309)],
            label: '+$displayCoins',
            subLabel: 'ذهب',
            isLandscape: isLandscape,
          ),

          // بطاقة الجواهر (إذا كانت تحتوي على جواهر)
          if (_awardedGems > 0) ...[
            const SizedBox(width: 10),
            _buildLootChip(
              icon: Icons.diamond_rounded,
              iconColor: const Color(0xFF38BDF8),
              borderColor: const Color(0xFF38BDF8),
              gradientColors: const [Color(0xFF0C4A6E), Color(0xFF0284C7)],
              label: '+$displayGems',
              subLabel: 'جواهر',
              isLandscape: isLandscape,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLootChip({
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
    required List<Color> gradientColors,
    required String label,
    required String subLabel,
    required bool isLandscape,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 10 : 12,
        vertical: isLandscape ? 4 : 5,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.45),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: isLandscape ? 18 : 22),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Baloo',
                  color: Colors.white,
                  fontSize: isLandscape ? 14 : 16,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 4),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// زر الإجراء الذهبي الفاخر
  Widget _buildActionButton(bool isLandscape, bool isChestOpen) {
    if (_state == _ChestState.alreadyClaimed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // عداد الوقت المتبقي لليوم التالي
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: Color(0xFF38BDF8),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'الصندوق التالي متاح خلال: ${_formatDuration(_timeLeftUntilTomorrow)}',
                  style: const TextStyle(
                    fontFamily: 'Baloo',
                    color: Color(0xFFBAE6FD),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // زر إغلاق أنيق
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: Container(
              height: isLandscape ? 36 : 40,
              width: 160,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF93C5FD),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'رائع!',
                  style: TextStyle(
                    fontFamily: 'Baloo',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (isChestOpen) {
      // زر استلام الجائزة الذهبي المشع
      return GestureDetector(
        onTap: _handleClaimAndClose,
        child: Container(
          height: isLandscape ? 38 : 44,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFF59E0B),
                Color(0xFFEAB308),
                Color(0xFFFACC15),
                Color(0xFFF59E0B),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white,
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'استلام المكافأة 🎉',
                style: TextStyle(
                  fontFamily: 'Baloo',
                  color: Color(0xFF451A03),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // زر افتح الصندوق المبدئي
    return GestureDetector(
      onTap: _handleOpenChest,
      child: Container(
        height: isLandscape ? 38 : 44,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFDC2626),
              Color(0xFFEA580C),
              Color(0xFFF59E0B),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFFD700),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEA580C).withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_open_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'افتح الصندوق الآن 🎁',
              style: TextStyle(
                fontFamily: 'Baloo',
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(color: Colors.black45, blurRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// نموذج جسيمات الانفجار الفيزيائية
// ─────────────────────────────────────────────────────────────────────────────
class _LootParticle {
  _LootParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
    required this.shape,
  });

  double x;
  double y;
  double vx;
  double vy;
  final double size;
  final Color color;
  double rotation;
  final double rotationSpeed;
  final int shape; // 0: star, 1: circle, 2: diamond, 3: rect
}

// ─────────────────────────────────────────────────────────────────────────────
// رسام انفجار الجسيمات
// ─────────────────────────────────────────────────────────────────────────────
class _ExplosionParticlesPainter extends CustomPainter {
  _ExplosionParticlesPainter({
    required this.progress,
    required this.particles,
  });

  final double progress;
  final List<_LootParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    final alpha = (1.0 - progress * progress).clamp(0.0, 1.0);

    for (final p in particles) {
      // تطبيق الجاذبية والمقاومة الهوائية
      final t = progress;
      final px = center.dx + p.vx * t * 0.7;
      final py = center.dy + (p.vy * t + 0.5 * 380.0 * t * t) * 0.7;
      final currentRotation = p.rotation + p.rotationSpeed * t;

      paint.color = p.color.withValues(alpha: alpha);

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(currentRotation);

      if (p.shape == 1) {
        // دائرة (عملة)
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else if (p.shape == 2) {
        // معين (جوهرة)
        final path = Path()
          ..moveTo(0, -p.size)
          ..lineTo(p.size * 0.7, 0)
          ..lineTo(0, p.size)
          ..lineTo(-p.size * 0.7, 0)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        // شريط أو نجمة
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ExplosionParticlesPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// رسام أشعة الشمس الدوارة
// ─────────────────────────────────────────────────────────────────────────────
class _SunburstRaysPainter extends CustomPainter {
  _SunburstRaysPainter({
    required this.angle,
    required this.color,
    required this.intensity,
  });

  final double angle;
  final Color color;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(size.width, size.height);
    const rayCount = 14;
    const step = 2 * math.pi / rayCount;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: intensity),
          color.withValues(alpha: intensity * 0.4),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    for (int i = 0; i < rayCount; i++) {
      if (i % 2 == 0) {
        final a1 = i * step;
        final a2 = a1 + step * 0.55;
        final path = Path()
          ..moveTo(0, 0)
          ..lineTo(math.cos(a1) * radius, math.sin(a1) * radius)
          ..lineTo(math.cos(a2) * radius, math.sin(a2) * radius)
          ..close();
        canvas.drawPath(path, paint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SunburstRaysPainter oldDelegate) =>
      oldDelegate.angle != angle || oldDelegate.intensity != intensity;
}

// ─────────────────────────────────────────────────────────────────────────────
// رسام النجوم العائمة المستمرة
// ─────────────────────────────────────────────────────────────────────────────
class _AmbientStarsPainter extends CustomPainter {
  _AmbientStarsPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 28; i++) {
      final seed = i * 49287;
      final fx = ((seed ^ (seed >> 8)) % 1000) / 1000.0;
      final fy = ((seed ^ (seed >> 16)) % 1000) / 1000.0;

      final currentY = ((fy - t * 0.4) % 1.0) * size.height;
      final currentX = fx * size.width;
      final blink = (math.sin((t * 4 + i) * math.pi) + 1.0) / 2.0;

      paint.color = const Color(0xFFFFD700).withValues(alpha: 0.15 + blink * 0.35);
      canvas.drawCircle(Offset(currentX, currentY), 1.2 + blink * 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientStarsPainter oldDelegate) =>
      oldDelegate.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// رسام بريق الوشاح العلوي
// ─────────────────────────────────────────────────────────────────────────────
class _RibbonSheenPainter extends CustomPainter {
  _RibbonSheenPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final sweepProgress = (t * 2.0) % 2.5;
    if (sweepProgress > 1.2) return;

    final x = (sweepProgress - 0.2) * size.width;
    final rect = Rect.fromLTWH(x, 0, 40, size.height);

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.25),
          Colors.transparent,
        ],
      ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _RibbonSheenPainter oldDelegate) =>
      oldDelegate.t != t;
}
