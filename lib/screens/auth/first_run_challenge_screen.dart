import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../models/campaign_stage.dart';
import '../../models/game_character.dart';
import '../../services/campaign_defaults.dart';
import '../../services/campaign_mode_engine.dart';
import '../../services/campaign_result_handler.dart';
import '../../services/native_bridge_service.dart';

class FirstRunChallengeScreen extends StatefulWidget {
  const FirstRunChallengeScreen({super.key});

  @override
  State<FirstRunChallengeScreen> createState() =>
      _FirstRunChallengeScreenState();
}

class _FirstRunChallengeScreenState extends State<FirstRunChallengeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final CampaignModeEngine _modeEngine = const CampaignModeEngine();

  late final AnimationController _pulseCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _particlesCtrl;

  bool _launching = false;
  bool _waitingForResult = false;
  String? _error;

  int _selectedCharacterIndex = 1; // Default to Omar (index 1)
  int _countdownSeconds = 5;
  Timer? _countdownTimer;
  bool _countdownActive = true;

  CampaignStage get _firstStage => CampaignDefaults.stages().first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _particlesCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Check if character already chosen in state
    final appState = context.read<AppState>();
    if (appState.selectedCharacterIndex >= 0) {
      _selectedCharacterIndex = appState.selectedCharacterIndex;
    }

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_countdownActive) return;

      if (_countdownSeconds > 1) {
        setState(() => _countdownSeconds--);
      } else {
        timer.cancel();
        _launchStage();
      }
    });
  }

  void _pauseCountdown() {
    setState(() {
      _countdownActive = false;
    });
    _countdownTimer?.cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    _particlesCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_launching && !_waitingForResult && mounted) {
        setState(() => _waitingForResult = true);
      }
      _consumePendingResult();
    }
  }

  Future<void> _consumePendingResult() async {
    if (!mounted) return;
    final handled =
        await CampaignResultHandler.consumeAndHandlePendingCampaignResult(
      context: context,
    );
    if (!mounted) return;
    if (handled) {
      setState(() {
        _launching = false;
        _waitingForResult = false;
      });
      return;
    }
    if (_launching) {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (mounted && _launching) _consumePendingResult();
      });
    }
  }

  Future<void> _selectCharacter(int index) async {
    if (_selectedCharacterIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedCharacterIndex = index);

    final nativeBridge = context.read<NativeBridgeService>();
    try {
      await nativeBridge.setSelectedCharacter(index);
    } catch (_) {}
  }

  Future<void> _launchStage() async {
    if (_launching) return;
    _countdownTimer?.cancel();
    HapticFeedback.heavyImpact();

    setState(() {
      _launching = true;
      _waitingForResult = false;
      _error = null;
    });

    final stage = _firstStage;
    final nativeBridge = context.read<NativeBridgeService>();

    try {
      const questionIds = <int>[];
      final effectiveAllowedLevels = stage.allowedLevels
          .where((level) => level.trim().isNotEmpty)
          .toList(growable: false);

      if (kDebugMode) {
        debugPrint(
          'First run campaign board stage=${stage.id} '
          'target=${stage.boardTargetScore} policy=${stage.categoryPolicy}',
        );
      }

      final launchConfig = _modeEngine.buildLaunchConfig(stage);
      await nativeBridge.launchCampaignStage(
        campaignId: launchConfig['campaignId'] as String? ?? stage.campaignId,
        stageId: launchConfig['stageId'] as String? ?? stage.id,
        stageType: launchConfig['stageType'] as String? ?? stage.type.value,
        campaignMode:
            launchConfig['campaignMode'] as String? ?? stage.campaignMode.value,
        winCondition:
            launchConfig['winCondition'] as String? ?? stage.winCondition.value,
        questionIds: questionIds,
        allowedLevels: effectiveAllowedLevels,
        questionCount:
            launchConfig['questionCount'] as int? ?? stage.questionCount,
        timeLimitSeconds:
            launchConfig['timeLimitSeconds'] as int? ?? stage.timeLimitSeconds,
        allow5050: launchConfig['allow5050'] as bool? ?? stage.allow5050,
        allowAudience:
            launchConfig['allowAudience'] as bool? ?? stage.allowAudience,
        allowCall: launchConfig['allowCall'] as bool? ?? stage.allowCall,
        bossBotName: launchConfig['bossBotName'] as String? ?? '',
        bossBotIntelligence: launchConfig['bossBotIntelligence'] as int? ?? 0,
        lives: launchConfig['lives'] as int? ?? 0,
        maxWrongAnswers: launchConfig['maxWrongAnswers'] as int? ?? 0,
        targetScore: launchConfig['targetScore'] as int? ?? 0,
        opponentName: launchConfig['opponentName'] as String? ?? '',
        opponentAccuracy: launchConfig['opponentAccuracy'] as int? ?? 0,
        opponentStartScore: launchConfig['opponentStartScore'] as int? ?? 0,
        seriesRounds: launchConfig['seriesRounds'] as int? ?? 0,
        seriesWinsRequired: launchConfig['seriesWinsRequired'] as int? ?? 0,
        teamAllyName: launchConfig['teamAllyName'] as String? ?? '',
        teamEnemyName: launchConfig['teamEnemyName'] as String? ?? '',
        campaignBoard: launchConfig['campaignBoard'] as bool? ?? true,
        boardKind: launchConfig['boardKind'] as String? ?? 'solo',
        boardTargetScore: launchConfig['boardTargetScore'] as int? ?? 0,
        boardTwoStarScore: launchConfig['boardTwoStarScore'] as int? ?? 0,
        boardThreeStarScore: launchConfig['boardThreeStarScore'] as int? ?? 0,
        boardSoloPicks: launchConfig['boardSoloPicks'] as int? ?? 6,
        boardSoloCols: launchConfig['boardSoloCols'] as int? ?? 4,
        boardBotCount: launchConfig['boardBotCount'] as int? ?? 0,
        boardBotIntelligence: launchConfig['boardBotIntelligence'] as int? ?? 0,
        categoryPolicy:
            launchConfig['categoryPolicy'] as String? ?? 'playerPick',
        worldCategories: (launchConfig['worldCategories'] as List<dynamic>? ??
                const <dynamic>[])
            .map((dynamic e) => e.toString())
            .toList(growable: false),
      );
      if (mounted) setState(() => _waitingForResult = true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _launching = false;
        _waitingForResult = false;
        _error = 'تعذر تجهيز التحدي السريع. حاول مرة أخرى.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF030818),
        body: Stack(
          children: [
            // ── Thematic World Background ────────────────────────────────
            Positioned.fill(
              child: Image.asset(
                'assets/images/campaign/worlds/world_01_forest.webp',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/ui/bg_login.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // ── Atmospheric Gradient Overlay ─────────────────────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF061033).withValues(alpha: 0.82),
                      const Color(0xFF020617).withValues(alpha: 0.94),
                    ],
                  ),
                ),
              ),
            ),

            // ── Floating Embers / Sparkles ────────────────────────────────
            AnimatedBuilder(
              animation: _particlesCtrl,
              builder: (_, __) => CustomPaint(
                size: size,
                painter: _EmbersPainter(_particlesCtrl.value),
              ),
            ),

            // ── Main UI Content ───────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  // ── Top Navigation & VIP Header ─────────────────────────
                  _buildTopBar(),

                  // ── Main Content Area (Responsive Split or Column) ──────
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: isLandscape
                              ? _buildLandscapeContent()
                              : _buildPortraitContent(),
                        ),
                      ),
                    ),
                  ),

                  // ── Bottom Action & Launch Bar ──────────────────────────
                  _buildBottomBar(),
                ],
              ),
            ),

            // ── Launching / Loading Overlay ───────────────────────────────
            if (_launching)
              Positioned.fill(
                child: _buildLaunchingOverlay(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                _countdownTimer?.cancel();
                Navigator.of(context).maybePop();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1E4A).withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Row(
              children: [
                Text(
                  'غرفة تجهيز المعركة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(width: 8),
                _VipBadge(text: '⚡ تجربة بطل مجانية'),
              ],
            ),
          ),
          if (_countdownActive && !_launching)
            GestureDetector(
              onTap: _pauseCountdown,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFACC15).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFACC15).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_rounded,
                        color: Color(0xFFFACC15), size: 16),
                    const SizedBox(width: 5),
                    Text(
                      'انطلاق خلال $_countdownSeconds ث',
                      style: const TextStyle(
                        color: Color(0xFFFACC15),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.pause_rounded,
                        color: Colors.white70, size: 14),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLandscapeContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Intel & Spoils
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _buildIntelCard(),
              const SizedBox(height: 12),
              _buildSpoilsCard(),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Right Column: Character Selection & Showcase
        Expanded(
          flex: 6,
          child: _buildHeroPickerCard(),
        ),
      ],
    );
  }

  Widget _buildPortraitContent() {
    return Column(
      children: [
        _buildHeroPickerCard(),
        const SizedBox(height: 12),
        _buildIntelCard(),
        const SizedBox(height: 12),
        _buildSpoilsCard(),
      ],
    );
  }

  Widget _buildIntelCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF07143D).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.forest_rounded,
                  color: Color(0xFF38BDF8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'المرحلة 1 • غابة البداية',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'لوحة التحدي',
                  style: TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _MissionDetailRow(
            icon: Icons.track_changes_rounded,
            title: 'الهدف المطلوب',
            value: '500+ نقطة لنيل الـ 3 نجوم',
            color: Color(0xFFFFD700),
          ),
          const SizedBox(height: 6),
          const _MissionDetailRow(
            icon: Icons.touch_app_rounded,
            title: 'طريقة اللعب',
            value: '6 اختيارات حرة من لوحة الأسئلة',
            color: Color(0xFF38BDF8),
          ),
          const SizedBox(height: 6),
          const _MissionDetailRow(
            icon: Icons.category_rounded,
            title: 'المجالات',
            value: 'معلومات عامة، حيوانات، رياضة، نباتات',
            color: Color(0xFFA78BFA),
          ),
        ],
      ),
    );
  }

  Widget _buildSpoilsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF281802).withValues(alpha: 0.8),
            const Color(0xFF15102A).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _floatCtrl,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, -3 + _floatCtrl.value * 6),
              child: child,
            ),
            child: Image.asset(
              'assets/ui/box1.png',
              width: 54,
              height: 54,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.card_giftcard_rounded,
                color: Color(0xFFFACC15),
                size: 40,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'غنائم النصر بانتظارك! 🎁',
                  style: TextStyle(
                    color: Color(0xFFFFE082),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '+500 ذهب 🪙 • +50 جوهرة 💎 • 3 نجوم ⭐',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'تُحجز وتُضاف إلى حسابك فور حفظ تقدمك بعد المعركة.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPickerCard() {
    final availableCharacters = [
      CharacterCatalog.byIndex(1), // عمر (Free)
      CharacterCatalog.byIndex(6), // سارة (Free)
      CharacterCatalog.byIndex(0), // خالد
      CharacterCatalog.byIndex(2), // فهد
      CharacterCatalog.byIndex(3), // مازن
      CharacterCatalog.byIndex(7), // تاليا
    ];

    final currentHero = CharacterCatalog.byIndex(_selectedCharacterIndex);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF08153A).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.person_pin_rounded,
                  color: Color(0xFFFACC15), size: 20),
              const SizedBox(width: 6),
              const Text(
                'اختر بطلك للانطلاق:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${currentHero.nameAr} (${currentHero.tagAr})',
                style: TextStyle(
                  color: currentHero.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Character Selection Bar
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: availableCharacters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final hero = availableCharacters[index];
                final isSelected = hero.index == _selectedCharacterIndex;

                return GestureDetector(
                  onTap: () {
                    _pauseCountdown();
                    _selectCharacter(hero.index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 76,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? hero.color.withValues(alpha: 0.22)
                          : const Color(0xFF0F1E4A).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? hero.color
                            : Colors.white.withValues(alpha: 0.14),
                        width: isSelected ? 2.2 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: hero.color.withValues(alpha: 0.35),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipOval(
                          child: Image.asset(
                            hero.asset,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.account_circle_rounded,
                              size: 44,
                              color: hero.color,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hero.nameAr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Short Motivational Tagline
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: currentHero.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, color: currentHero.color, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'تم اختيار ${currentHero.nameAr}! جهز معلوماتك واثبت ذكاءك في ساحة التحدي.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFCA5A5),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
          ],
          SizedBox(
            width: double.infinity,
            height: 56,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, child) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(
                        alpha: 0.35 + _pulseCtrl.value * 0.25,
                      ),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: child,
              ),
              child: FilledButton.icon(
                onPressed: _launching ? null : _launchStage,
                icon: const Icon(Icons.sports_esports_rounded, size: 24),
                label: Text(
                  _countdownActive
                      ? '🚀 انطلق للميدان الآن ($_countdownSeconds)'
                      : '🚀 انطلق للميدان الآن',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFACC15),
                  foregroundColor: const Color(0xFF1E1B4B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
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

  Widget _buildLaunchingOverlay() {
    return Container(
      color: const Color(0xFF020617).withValues(alpha: 0.92),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF091438),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFACC15).withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, child) => Transform.scale(
                  scale: 0.95 + _pulseCtrl.value * 0.1,
                  child: child,
                ),
                child: const SizedBox(
                  width: 52,
                  height: 52,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    color: Color(0xFFFACC15),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _waitingForResult
                    ? 'جارٍ استلام نتيجتك وحساب النجوم...'
                    : 'جارٍ فتح لوحة التحدي وخلط الأسئلة...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _waitingForResult
                    ? 'لحظات ونعرض صندوق جوائزك الأسطوري!'
                    : 'استعد للتركيز واختيار الإجابات الصحيحة 🧠',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VipBadge extends StatelessWidget {
  const _VipBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFACC15).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFACC15).withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFACC15),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MissionDetailRow extends StatelessWidget {
  const _MissionDetailRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          '$title: ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmbersPainter extends CustomPainter {
  _EmbersPainter(this.t);
  final double t;

  static final _particles = List.generate(24, (i) {
    final rand = (i * 137.508) % 1.0;
    return (
      x: (i * 79 % 100) / 100.0,
      speed: 0.03 + rand * 0.05,
      size: 2.0 + rand * 4.5,
      phase: rand,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final progress = (t * p.speed + p.phase) % 1.0;
      final opacity = progress < 0.15
          ? progress / 0.15
          : progress > 0.85
              ? (1 - progress) / 0.15
              : 1.0;

      canvas.drawCircle(
        Offset(p.x * size.width, size.height * (1 - progress)),
        p.size / 2,
        Paint()
          ..color = const Color(0xFFFACC15).withValues(alpha: opacity * 0.38),
      );
    }
  }

  @override
  bool shouldRepaint(_EmbersPainter old) => old.t != t;
}
