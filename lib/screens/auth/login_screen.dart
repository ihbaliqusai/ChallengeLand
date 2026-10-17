import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_state.dart';
import '../../services/campaign_result_handler.dart';
import 'first_run_challenge_screen.dart';

/// Next-Generation AAA Gaming Login & Registration Screen for ChallengeLand.
///
/// Features:
/// - Cinematic Dual-Stage Landscape layout (Hero Arena Showcase + Cyber-Glass Command Portal)
/// - Seamless adaptive fall-through for compact / vertical views
/// - Animated interactive Mascot with dynamic speech bubble & tap reactions
/// - Segmented gaming tab switcher (دخول الساحة / حساب بطل جديد)
/// - Password visibility toggles (eye icons) & modern glowing inputs
/// - Interactive Forgot Password (استعادة كلمة المرور) dialog via Firebase Auth
/// - Instant Guest Play hero card with rewards highlight (+500 ذهب، 50 جوهرة)
/// - Google Play / Google Sign-In button with gaming hover/scale animation
/// - Cosmic floating stardust particles & ambient radial light orbs
/// - Privacy Policy & Terms of Service modal
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isRegister = false;
  bool _obscurePassword = true;

  // ── Video Presenter Controller ──────────────────────────────────
  VideoPlayerController? _videoController;
  bool _isVideoReady = false;

  // ── Animation Controllers ───────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final AnimationController _particlesCtrl;
  late final AnimationController _glowPulseCtrl;
  late final AnimationController _mascotTapCtrl;

  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  // Mascot dynamic speech bubble quotes
  final List<String> _mascotQuotes = const [
    'مرحباً بك يا بطل! الساحة بانتظارك ⚔️',
    'أكثر من 50,000 سؤال ومنافسات حقيقية أونلاين! 🧠',
    'سجّل دخولك لحفظ كؤوسك والترقي في الدوري الذهبي! 🏆',
    'أو جرب التحدي السريع فوراً بدون تسجيل! 🚀',
    'صناديق ذهبية وجواهر ومكافآت يومية بانتظارك! 🎁',
    'هل تستطيع تصدر لوحة الشرف العالمية؟ 🔥',
  ];
  int _currentQuoteIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initVideoPresenter();

    // Entrance animation
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.04, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOutCubic,
    ));

    // Ambient particles animation (continuous loop)
    _particlesCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Glow pulse for accents
    _glowPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Mascot tap bounce
    _mascotTapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingGuestCampaignResult();
    });
  }

  Future<void> _initVideoPresenter() async {
    try {
      final controller =
          VideoPlayerController.asset('assets/videos/welcome.mp4');
      _videoController = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1.0);
      await controller.play();
      if (mounted) {
        setState(() {
          _isVideoReady = true;
        });
      }
    } catch (_) {
      // In test environments or unsupported platforms, fallback gracefully to static mascot image
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController?.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _entranceCtrl.dispose();
    _particlesCtrl.dispose();
    _glowPulseCtrl.dispose();
    _mascotTapCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _consumePendingGuestCampaignResult();
      if (_videoController?.value.isInitialized == true) {
        _videoController?.play();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _videoController?.pause();
    }
  }

  Future<void> _consumePendingGuestCampaignResult() async {
    if (!mounted) return;
    try {
      await CampaignResultHandler.consumeAndHandlePendingCampaignResult(
        context: context,
      );
    } catch (_) {
      // Ignored if NativeBridgeService not provided in environment
    }
  }

  void _cycleMascotQuote() {
    HapticFeedback.lightImpact();
    _mascotTapCtrl.forward(from: 0.0);
    if (_videoController != null && _videoController!.value.isInitialized) {
      _videoController!.seekTo(Duration.zero);
      _videoController!.play();
    }
    setState(() {
      _currentQuoteIndex = (_currentQuoteIndex + 1) % _mascotQuotes.length;
    });
  }

  void _switchTab(bool isRegister) {
    if (_isRegister == isRegister) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isRegister = isRegister;
    });
  }

  String? _validate() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final username = _usernameController.text.trim();

    if (email.isEmpty) return 'يرجى إدخال البريد الإلكتروني';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }
    if (password.isEmpty) return 'يرجى إدخال كلمة المرور';
    if (password.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    if (_isRegister && username.isEmpty) return 'يرجى إدخال اسم اللاعب / اللقب';
    return null;
  }

  static String _arabicFirebaseError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('wrong-password') ||
        lower.contains('invalid-credential')) {
      return 'كلمة المرور أو البريد الإلكتروني غير صحيح';
    }
    if (lower.contains('user-not-found')) {
      return 'لا يوجد حساب مسجل بهذا البريد الإلكتروني';
    }
    if (lower.contains('email-already-in-use')) {
      return 'هذا البريد الإلكتروني مستخدم بالفعل بحساب آخر';
    }
    if (lower.contains('invalid-email')) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }
    if (lower.contains('weak-password')) {
      return 'كلمة المرور ضعيفة جداً، استخدم 6 أحرف على الأقل';
    }
    if (lower.contains('too-many-requests')) {
      return 'تم تجاوز عدد المحاولات المسموح بها، يرجى المحاولة لاحقاً';
    }
    if (lower.contains('network-request-failed')) {
      return 'تعذر الاتصال بالخادم، تحقق من اتصال الإنترنت';
    }
    if (lower.contains('operation-not-allowed')) {
      return 'طريقة تسجيل الدخول هذه غير مفعلة حالياً';
    }
    return 'حدث خطأ أثناء المحاولة، يرجى المحاولة مرة أخرى';
  }

  Future<void> _submit(AppState state) async {
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();

    final validationError = _validate();
    if (validationError != null) {
      _showSnack(validationError, isError: true);
      return;
    }

    try {
      if (_isRegister) {
        await state.register(
          _emailController.text.trim(),
          _passwordController.text,
          _usernameController.text.trim(),
        );
      } else {
        await state.signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(_arabicFirebaseError(e.toString()), isError: true);
    }
  }

  Future<void> _handleGoogleSignIn(AppState state) async {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    try {
      await state.signInWithGoogle();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (!msg.contains('cancelled') && !msg.contains('إلغاء')) {
        _showSnack(_arabicFirebaseError(msg), isError: true);
      }
    }
  }

  void _openGuestChallenge() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const FirstRunChallengeScreen(),
      ),
    );
  }

  void _openForgotPasswordDialog() {
    HapticFeedback.lightImpact();
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _ForgotPasswordDialog(
        initialEmail: _emailController.text.trim(),
      ),
    );
  }

  void _openLegalDialog() {
    HapticFeedback.lightImpact();
    showDialog<void>(
      context: context,
      builder: (ctx) => const _LegalDialog(),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: isError ? const Color(0xFFF87171) : const Color(0xFF4ADE80),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isError
                ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                : const Color(0xFF22C55E).withValues(alpha: 0.5),
            width: 1.2,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width >= 680;

    return Consumer<AppState>(
      builder: (context, state, _) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: const Color(0xFF040714),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ── 1. Cosmic Background Image ──────────────────────────
              const Image(
                image: AssetImage('assets/ui/bg_login.webp'),
                fit: BoxFit.cover,
              ),

              // ── 2. Cinematic Multi-Layer Vignette ───────────────────
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF070F28).withValues(alpha: 0.88),
                      const Color(0xFF040714).withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),

              // ── 3. Radial Ambient Light Spotlights ───────────────────
              Positioned(
                left: isLandscape ? screenSize.width * 0.15 : screenSize.width * 0.5,
                top: screenSize.height * 0.2,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFACC15).withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: isLandscape ? screenSize.width * 0.2 : 0,
                bottom: screenSize.height * 0.1,
                child: Container(
                  width: 360,
                  height: 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF6366F1).withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // ── 4. Floating Cosmic Stardust Particles ────────────────
              AnimatedBuilder(
                animation: _particlesCtrl,
                builder: (_, __) => CustomPaint(
                  size: screenSize,
                  painter: _CosmicParticlesPainter(_particlesCtrl.value),
                ),
              ),

              // ── 5. Main Content Area (Adaptive Landscape / Portrait) ──
              Positioned.fill(
                child: SafeArea(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: isLandscape
                          ? _buildLandscapeLayout(state)
                          : _buildCompactLayout(state),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  Landscape Layout (Grand Dual-Stage Arena)
  // ────────────────────────────────────────────────────────────────
  Widget _buildLandscapeLayout(AppState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Hero Arena & Mascot Stage
          Expanded(
            flex: 9,
            child: _buildHeroArenaStage(state),
          ),

          const SizedBox(width: 16),

          // Right: Cyber-Glass Command Portal
          Expanded(
            flex: 11,
            child: _buildPortalConsole(state),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  Compact Layout (Graceful Fallback for narrow views)
  // ────────────────────────────────────────────────────────────────
  Widget _buildCompactLayout(AppState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = math.max(0.0, constraints.maxWidth - 32);
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SizedBox(
            width: contentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mascot speech bubble
                _buildSpeechBubble(compact: true),
                const SizedBox(height: 12),

                // Command Portal
                _buildPortalConsole(state, scrollable: false),
              ],
            ),
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  Hero Arena Stage (Left Stage in Landscape)
  // ────────────────────────────────────────────────────────────────
  Widget _buildHeroArenaStage(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Live Server & League Status Pills
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildBadge(
              icon: Icons.fiber_manual_record_rounded,
              iconColor: const Color(0xFF22C55E),
              label: 'الخادم: متصل',
              badgeColor: const Color(0xFF22C55E),
            ),
            _buildBadge(
              icon: Icons.military_tech_rounded,
              iconColor: const Color(0xFFFACC15),
              label: 'الموسم 1: أرض التحدي',
              badgeColor: const Color(0xFFFACC15),
            ),
          ],
        ),

        const Spacer(),

        // Dynamic Interactive Speech Bubble
        _buildSpeechBubble(),

        const SizedBox(height: 6),

        // Mascot / Presenter Character (Fixed, steady stage presence)
        Expanded(
          flex: 8,
          child: GestureDetector(
            onTap: _cycleMascotQuote,
            behavior: HitTestBehavior.opaque,
            child: _buildPresenterVisual(),
          ),
        ),

        const Spacer(),

        // Quick Guest CTA button below mascot
        _buildQuickHeroPlayButton(state),

        const SizedBox(height: 6),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  Presenter Video / Mascot Visual (Transparent Keyed & Steady)
  // ────────────────────────────────────────────────────────────────
  Widget _buildPresenterVisual() {
    final hasVideo = _isVideoReady &&
        _videoController != null &&
        _videoController!.value.isInitialized;

    if (hasVideo) {
      return Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio > 0
              ? _videoController!.value.aspectRatio
              : (9 / 16),
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              1.0, 0.0, 0.0, 0.0, 0.0,
              0.0, 1.0, 0.0, 0.0, 0.0,
              0.0, 0.0, 1.0, 0.0, 0.0,
              2.0, 2.0, 2.0, 0.0, -25.0,
            ]),
            child: VideoPlayer(_videoController!),
          ),
        ),
      );
    }

    // Fallback to static mascot image
    return Image.asset(
      'assets/ui/person_welcome.webp',
      fit: BoxFit.contain,
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  Speech Bubble
  // ────────────────────────────────────────────────────────────────
  Widget _buildSpeechBubble({bool compact = false}) {
    return GestureDetector(
      onTap: _cycleMascotQuote,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(anim),
            child: child,
          ),
        ),
        child: Container(
          key: ValueKey(_currentQuoteIndex),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFACC15).withValues(alpha: 0.6),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFACC15).withValues(alpha: 0.18),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.touch_app_rounded,
                size: 14,
                color: Color(0xFFFACC15),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _mascotQuotes[_currentQuoteIndex],
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  Quick Hero Play Button on Hero Arena Side
  // ────────────────────────────────────────────────────────────────
  Widget _buildQuickHeroPlayButton(AppState state) {
    return GestureDetector(
      onTap: state.isBusy ? null : _openGuestChallenge,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E1065), Color(0xFF1E1B4B)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
              blurRadius: 12,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt_rounded, color: Color(0xFF38BDF8), size: 18),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'دخول سريع كبطل • ابدأ المعركة',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFFE0F2FE),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  Cyber-Glass Command Portal Console (Right Side in Landscape)
  // ────────────────────────────────────────────────────────────────
  Widget _buildPortalConsole(AppState state, {bool scrollable = true}) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
                // 1. Futuristic Mode Switcher Tabs
                _buildSegmentedTabBar(),

                const SizedBox(height: 12),

                // 2. Animated Form Fields
                _buildFormFields(),

                // 3. Forgot Password Link (Only in Sign In mode)
                if (!_isRegister)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: state.isBusy ? null : _openForgotPasswordDialog,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'نسيت كلمة المرور؟',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                // 4. Primary Glowing CTA Button
                _buildPrimaryButton(state),

                const SizedBox(height: 10),

                // 5. Divider with Glowing Line
                _buildDivider(),

                const SizedBox(height: 10),

                // 6. Google Sign-In Button
                _buildGoogleButton(state),

                const SizedBox(height: 10),

                // 7. Instant Guest Play Mini-Card with Spoils
                _buildGuestSpoilsCard(state),

                const SizedBox(height: 8),

                // 8. Footer Links (Privacy Policy & Server Ping)
                _buildConsoleFooter(),
              ],
            );

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0F172A).withValues(alpha: 0.88),
                const Color(0xFF1E1B4B).withValues(alpha: 0.78),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF7DD3FC).withValues(alpha: 0.45),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: scrollable
              ? SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: content,
                )
              : Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: content,
                ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  Segmented Mode Switcher Tabs
  // ────────────────────────────────────────────────────────────────
  Widget _buildSegmentedTabBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF080D1F).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              title: 'تسجيل الدخول',
              icon: Icons.login_rounded,
              active: !_isRegister,
              onTap: () => _switchTab(false),
            ),
          ),
          Expanded(
            child: _buildTabButton(
              title: 'حساب جديد',
              icon: Icons.person_add_alt_1_rounded,
              active: _isRegister,
              onTap: () => _switchTab(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: active
              ? const LinearGradient(
                  colors: [Color(0xFFFACC15), Color(0xFFF59E0B)],
                )
              : null,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? const Color(0xFF1E1B4B) : Colors.white60,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: TextStyle(
                    color: active ? const Color(0xFF1E1B4B) : Colors.white70,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  Form Fields
  // ────────────────────────────────────────────────────────────────
  Widget _buildFormFields() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Username field (Only for Register)
          if (_isRegister) ...[
            _GamingTextField(
              controller: _usernameController,
              label: 'اسم اللاعب / اللقب',
              hint: 'مثال: الفارس_العربي',
              icon: Icons.badge_rounded,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
          ],

          // Email Field
          _GamingTextField(
            controller: _emailController,
            label: 'البريد الإلكتروني',
            hint: 'player@example.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 8),

          // Password Field with Visibility Toggle
          _GamingTextField(
            controller: _passwordController,
            label: 'كلمة المرور',
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(context.read<AppState>()),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: Colors.white54,
                size: 20,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  Primary Action Button
  // ────────────────────────────────────────────────────────────────
  Widget _buildPrimaryButton(AppState state) {
    final busy = state.isBusy;
    return _AnimatedPressButton(
      onPressed: busy ? null : () => _submit(state),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFFFACC15), Color(0xFFF59E0B)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF1E1B4B),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isRegister
                          ? Icons.rocket_launch_rounded
                          : Icons.sports_martial_arts_rounded,
                      color: const Color(0xFF1E1B4B),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isRegister
                              ? 'إنشاء الحساب وبدء المغامرة'
                              : 'دخول الساحة ⚔️',
                          style: const TextStyle(
                            color: Color(0xFF1E1B4B),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  Divider
  // ────────────────────────────────────────────────────────────────
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.2),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'أو المتابعة السريعة',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  Google Sign-In Button
  // ────────────────────────────────────────────────────────────────
  Widget _buildGoogleButton(AppState state) {
    return _AnimatedPressButton(
      onPressed: state.isBusy ? null : () => _handleGoogleSignIn(state),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/ui/google.png', width: 20, height: 20),
            const SizedBox(width: 8),
            const Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'المتابعة عبر Google',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  Instant Guest Play Mini-Card with Spoils
  // ────────────────────────────────────────────────────────────────
  Widget _buildGuestSpoilsCard(AppState state) {
    return GestureDetector(
      onTap: state.isBusy ? null : _openGuestChallenge,
      child: AnimatedBuilder(
        animation: _glowPulseCtrl,
        builder: (context, child) {
          final glowVal = _glowPulseCtrl.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF090D24).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFACC15).withValues(
                  alpha: 0.4 + glowVal * 0.4,
                ),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFACC15).withValues(
                    alpha: 0.12 + glowVal * 0.12,
                  ),
                  blurRadius: 14,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFFACC15).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.sports_esports_rounded,
                color: Color(0xFFFACC15),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(
                        'دخول فوري كضيف',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '• بدون تسجيل',
                        style: TextStyle(
                          color: Color(0xFFFACC15),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      _buildMiniChip(
                        icon: Icons.monetization_on_rounded,
                        color: const Color(0xFFFACC15),
                        label: '+500 ذهب',
                      ),
                      _buildMiniChip(
                        icon: Icons.diamond_rounded,
                        color: const Color(0xFF38BDF8),
                        label: '+50 جوهرة',
                      ),
                      _buildMiniChip(
                        icon: Icons.card_giftcard_rounded,
                        color: const Color(0xFFA78BFA),
                        label: 'صندوق ترحيبي',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFFFACC15),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniChip({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  Footer
  // ────────────────────────────────────────────────────────────────
  Widget _buildConsoleFooter() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        TextButton(
          onPressed: _openLegalDialog,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'سياسة الخصوصية والشروط',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        Text(
          'إصدار 3.6.6 • 24ms',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
//  Gaming Input Field Widget
// ────────────────────────────────────────────────────────────────
class _GamingTextField extends StatelessWidget {
  const _GamingTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.28),
          fontSize: 13,
        ),
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFFFACC15), size: 18),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF0B132B).withValues(alpha: 0.8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFFACC15),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
//  Interactive Animated Press Button
// ────────────────────────────────────────────────────────────────
class _AnimatedPressButton extends StatefulWidget {
  const _AnimatedPressButton({
    required this.child,
    required this.onPressed,
  });

  final Widget child;
  final VoidCallback? onPressed;

  @override
  State<_AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<_AnimatedPressButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 150),
          child: widget.child,
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
//  Floating Cosmic Particles Painter
// ────────────────────────────────────────────────────────────────
class _CosmicParticlesPainter extends CustomPainter {
  _CosmicParticlesPainter(this.progress);

  final double progress;

  static final _particles = List.generate(24, (i) {
    final rand = (i * 123.456) % 1.0;
    return (
      x: ((i * 73) % 100) / 100.0,
      speed: 0.05 + rand * 0.08,
      size: 2.0 + rand * 4.5,
      phase: rand,
      isGold: i % 2 == 0,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final currentY = (progress * p.speed + p.phase) % 1.0;
      final opacity = currentY < 0.15
          ? currentY / 0.15
          : currentY > 0.85
              ? (1 - currentY) / 0.15
              : 1.0;

      final paint = Paint()
        ..color = (p.isGold ? const Color(0xFFFACC15) : const Color(0xFF38BDF8))
            .withValues(alpha: opacity * 0.45);

      final dx = p.x * size.width + math.sin(currentY * math.pi * 2) * 12;
      final dy = size.height * (1.0 - currentY);

      canvas.drawCircle(Offset(dx, dy), p.size / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_CosmicParticlesPainter old) => old.progress != progress;
}

// ────────────────────────────────────────────────────────────────
//  Forgot Password Dialog (World-Class Firebase Auth Password Reset)
// ────────────────────────────────────────────────────────────────
class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({this.initialEmail = ''});

  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailCtrl;
  bool _loading = false;
  String? _error;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      setState(() => _error = 'يرجى إدخال بريد إلكتروني صالح');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final appState = context.read<AppState>();
      await appState.sendPasswordResetEmail(email);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _LoginScreenState._arabicFirebaseError(e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFACC15).withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: _sent ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Icon
        Center(
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFACC15).withValues(alpha: 0.15),
              border: Border.all(
                color: const Color(0xFFFACC15).withValues(alpha: 0.5),
              ),
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              color: Color(0xFFFACC15),
              size: 28,
            ),
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'استعادة كلمة المرور',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'أدخل بريدك الإلكتروني المسجل، وسنرسل لك رابطاً لإعادة تعيين كلمة المرور فوراً.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 16),

        _GamingTextField(
          controller: _emailCtrl,
          label: 'البريد الإلكتروني',
          hint: 'player@example.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),

        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(
              color: Color(0xFFF87171),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _loading ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                ),
                child: const Text('إلغاء'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _loading ? null : _sendReset,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFACC15),
                  foregroundColor: const Color(0xFF1E1B4B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1E1B4B),
                        ),
                      )
                    : const Text(
                        'إرسال الرابط',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF22C55E).withValues(alpha: 0.15),
              border: Border.all(
                color: const Color(0xFF22C55E).withValues(alpha: 0.6),
              ),
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: Color(0xFF22C55E),
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'تم إرسال الرابط بنجاح! ✉️',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'يرجى تفقد بريدك الوارد (أو مجلد الرسائل غير المرغوب فيها) والضغط على الرابط لتعيين كلمة مرور جديدة.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFACC15),
            foregroundColor: const Color(0xFF1E1B4B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'حسناً، فهمت',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────
//  Legal & Fair Play Dialog
// ────────────────────────────────────────────────────────────────
class _LegalDialog extends StatelessWidget {
  const _LegalDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.policy_rounded, color: Color(0xFF38BDF8), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'سياسة الخصوصية وقواعد اللعب النظيف',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '• نحرص على حماية بياناتك وخصوصيتك بأعلى معايير الأمان العالمية.\n'
                '• حسابك وبيانات تقدمك في اللعبة يتم حفظها ومزامنتها سحابياً بشكل آمن.\n'
                '• نلتزم بتوفير بيئة تنافسية عادلة ونزيهة خالية من الغش لجميع اللاعبين.\n'
                '• تسجيل الدخول يمكنك من الحفاظ على كؤوسك والجوائز التي تحققها عبر أي جهاز.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12.5,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'إغلاق',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
