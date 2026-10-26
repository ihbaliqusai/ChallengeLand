import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_settings.dart';
import '../../core/app_state.dart';
import '../../screens/auth/first_run_challenge_screen.dart';
import '../../screens/auth/login_bottom_sheet.dart';
import '../../screens/campaign/campaign_map_screen.dart';
import '../../screens/character/character_select_screen.dart';
import '../../screens/home/store_screen.dart';
import '../../services/ad_service.dart';
import '../../services/cross_promo_service.dart';
import '../../services/in_app_purchase_service.dart';
import '../game_modes_artwork.dart';
import 'guest_tour_preview_state.dart';
import 'guide_presenter_scene.dart';
import 'home_guide_tour_overlay.dart';
import 'home_guide_steps.dart';
import 'page_guide.dart';
import 'page_guide_steps.dart';

/// The core game sections unified into the guest tour.
enum UnifiedTourSection {
  home('الرئيسية', Icons.home_rounded, Color(0xFF60A5FA)),
  modes('الأوضاع', Icons.dashboard_rounded, Color(0xFF38BDF8)),
  campaign('المراحل', Icons.map_rounded, Color(0xFFFACC15)),
  store('المتجر', Icons.storefront_rounded, Color(0xFFA855F7)),
  characters('الشخصيات', Icons.person_rounded, Color(0xFF34D399));

  const UnifiedTourSection(this.label, this.icon, this.accentColor);
  final String label;
  final IconData icon;
  final Color accentColor;
}

/// A single step in the unified tour, tied to a specific preview page or home screen.
class UnifiedTourStep {
  const UnifiedTourStep({
    required this.section,
    required this.title,
    required this.text,
    this.targetKey,
    this.previewIndex,
    this.onEnter,
    this.isFinalChoiceStep = false,
  });

  final UnifiedTourSection section;
  final String title;
  final String text;
  final GlobalKey? targetKey;
  final int? previewIndex;
  final Future<void> Function()? onEnter;
  final bool isFinalChoiceStep;

  bool get isPreview => previewIndex != null;
}

/// The unified guest tour overlay that starts from the Home Screen, enters each section preview
/// sequentially (Modes, Campaign, Store, Characters), and presents Google sign-in at completion.
class UnifiedGuestTourOverlay extends StatefulWidget {
  const UnifiedGuestTourOverlay({
    super.key,
    required this.onComplete,
    required this.rootContext,
    this.onSkip,
    this.homeTargets,
  });

  final VoidCallback onComplete;
  final VoidCallback? onSkip;
  final BuildContext rootContext;
  final Map<HomeGuideTarget, GlobalKey>? homeTargets;

  static const String completedPrefKey = 'has_completed_unified_guest_tour';
  static const String legacyHomePrefKey = 'has_completed_home_onboarding_guide';

  @override
  State<UnifiedGuestTourOverlay> createState() => _UnifiedGuestTourOverlayState();
}

class _UnifiedGuestTourOverlayState extends State<UnifiedGuestTourOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _surfaceKey = GlobalKey();
  final _speech = GuideSpeechController();
  late final AnimationController _pulse;

  // Read-only preview services
  late final GuestTourPreviewState _previewState;
  late final GuestTourPreviewPurchases _previewPurchases;
  late final GuestTourPreviewAds _previewAds;
  late final GuestTourPreviewSettings _previewSettings;
  late final GuestTourPreviewPromo _previewPromo;

  // Controllers to capture real steps & targets from preview screens
  final _campaignGuideController = GuidePageController();
  final _storeGuideController = GuidePageController();
  final _characterGuideController = GuidePageController();

  // Target keys for Modes
  final _modeTargets = {
    for (final target in ModeGuideTarget.values) target: GlobalKey(),
  };

  int _stepIndex = 0;
  Rect? _target;
  bool _measurementPending = false;
  bool _signingIn = false;
  bool _finished = false;
  bool _preparing = false;
  String? _signInError;

  bool get _busy => _signingIn || _preparing;

  // Complete list of steps
  late List<UnifiedTourStep> _steps;

  UnifiedTourStep get _currentStep =>
      _steps[_stepIndex.clamp(0, _steps.length - 1)];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _previewState = GuestTourPreviewState();
    _previewPurchases = GuestTourPreviewPurchases();
    _previewAds = GuestTourPreviewAds();
    _previewSettings = GuestTourPreviewSettings();
    _previewPromo = GuestTourPreviewPromo();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addListener(_scheduleMeasurement);

    _buildSteps();
    _listenToControllers();

    _scheduleMeasurement();
  }

  void _buildSteps() {
    final steps = <UnifiedTourStep>[];

    // ── 1. Home Section (الساحة الرئيسية) ──────────────────────────
    steps.addAll([
      // Step 1: Welcome to the Arena - No target spotlight
      const UnifiedTourStep(
        section: UnifiedTourSection.home,
        title: 'أهلًا بك في أرض التحدي',
        text:
            'هذه ساحتك الرئيسية للانطلاق إلى المنافسات وتطوير حسابك. سنأخذك في جولة سريعة وممتعة للتعرف على أركان اللعبة.',
        targetKey: null,
        previewIndex: null,
      ),
      // Step 2: Play Button - What it is and its purpose
      UnifiedTourStep(
        section: UnifiedTourSection.home,
        title: 'زر بدء اللعب',
        text:
            'من هنا تنطلق لخوض مباريات وتحديات مباشرة وسريعة ضد منافسين آخرين، حيث تختار رهان العملات وتتنافس على الفوز.',
        targetKey: widget.homeTargets?[HomeGuideTarget.play],
        previewIndex: null,
      ),
      // Step 3: Coins
      UnifiedTourStep(
        section: UnifiedTourSection.home,
        title: 'العملات الذهبية',
        text:
            'رصيدك من العملات الذهبية يُستخدم لدخول المباريات والتحديات الكبرى، وشراء العناصر والتصنيفات من المتجر.',
        targetKey: widget.homeTargets?[HomeGuideTarget.coins],
        previewIndex: null,
      ),
      // Step 4: Gems
      UnifiedTourStep(
        section: UnifiedTourSection.home,
        title: 'الجواهر الثمينة',
        text:
            'رصيد ثمين لفتح الشخصيات النادرة والحصول على ميزات استثنائية وعضويات، ويمكنك تحويلها إلى عملات عند الحاجة.',
        targetKey: widget.homeTargets?[HomeGuideTarget.gems],
        previewIndex: null,
      ),
      // Step 5: Keys
      UnifiedTourStep(
        section: UnifiedTourSection.home,
        title: 'مفاتيح التحدي',
        text:
            'كل مباراة كاملة تحتاج مفتاحًا واحدًا. مفاتيحك اليومية تتجدد مجانًا كل يوم لضمان استمرارك في اللعب والمنافسة.',
        targetKey: widget.homeTargets?[HomeGuideTarget.keys],
        previewIndex: null,
      ),
      // Step 6: Tickets
      UnifiedTourStep(
        section: UnifiedTourSection.home,
        title: 'تذاكر التصنيفات',
        text:
            'تتيح لك كل تذكرة تجربة تصنيف أسئلة مقفل لمباراة واحدة، لتستكشف فئات ومجالات جديدة قبل اقتنائها بشكل دائم.',
        targetKey: widget.homeTargets?[HomeGuideTarget.tickets],
        previewIndex: null,
      ),
    ]);

    // ── 2. Modes Section (الأوضاع) ──────────────────────────────
    steps.add(
      UnifiedTourStep(
        section: UnifiedTourSection.modes,
        title: 'زر أوضاع اللعب',
        text:
            'هذا زر أوضاع اللعب في الساحة. يتيح لك التنافس في التحدي الرئيسي، التحدي الجماعي، تحدي صديق، واللعب دون إنترنت.',
        targetKey: widget.homeTargets?[HomeGuideTarget.modes],
        previewIndex: null,
      ),
    );

    // ── 3. Campaign Section (المراحل) ────────────────────────────
    steps.addAll([
      UnifiedTourStep(
        section: UnifiedTourSection.campaign,
        title: 'زر مغامرة المراحل',
        text:
            'هذا زر مغامرة المراحل. اضغط هنا أو اضغط «التالي» للدخول واستكشاف خريطة العوالم والتحديات الفردية.',
        targetKey: widget.homeTargets?[HomeGuideTarget.campaign],
        previewIndex: null,
      ),
      const UnifiedTourStep(
        section: UnifiedTourSection.campaign,
        title: 'رحلتك تبدأ هنا',
        text:
            'تقدّم عبر المراحل بالترتيب. افز بالمرحلة المفتوحة لفتح التالية، واجمع النجوم من نتائجك.',
        previewIndex: 1,
      ),
      const UnifiedTourStep(
        section: UnifiedTourSection.campaign,
        title: 'ابدأ من هنا',
        text:
            'اضغط رقم مرحلة مفتوحة لتبدأ اللعب. المرحلة المضيئة هي نقطة متابعتك الحالية.',
        previewIndex: 1,
      ),
      const UnifiedTourStep(
        section: UnifiedTourSection.campaign,
        title: 'كيف تفوز؟',
        text:
            'اختر أسئلة من اللوحة، وأجب صحيحًا لتحقيق أهداف المرحلة. راقب الهدف والوقت المعروضين أثناء اللعب.',
        previewIndex: 1,
      ),
      const UnifiedTourStep(
        section: UnifiedTourSection.campaign,
        title: 'مواجهة الزعيم',
        text:
            'في كل مرحلة عاشرة تواجه الزعيم. حقق شرط الفوز المعروض أثناء المواجهة لتواصل رحلتك.',
        previewIndex: 1,
      ),
      const UnifiedTourStep(
        section: UnifiedTourSection.campaign,
        title: 'القلب يعني محاولة',
        text:
            'تحتاج قلبًا لبدء مرحلة. يعود القلب إذا فزت، ويُستهلك إذا خسرت. لديك ٣ قلوب يومية تتجدد مجانًا كل يوم.',
        previewIndex: 1,
      ),
    ]);

    // ── 4. Store Section (المتجر) ────────────────────────────────
    steps.addAll([
      UnifiedTourStep(
        section: UnifiedTourSection.store,
        title: 'زر المتجر',
        text:
            'هذا زر المتجر في الساحة. اضغط هنا أو اضغط «التالي» للدخول واستعراض باقات العملات والجواهر والميزات.',
        targetKey: widget.homeTargets?[HomeGuideTarget.store],
        previewIndex: null,
      ),
      const UnifiedTourStep(
        section: UnifiedTourSection.store,
        title: 'دليلك إلى المتجر',
        text:
            'هنا تجد كل ما يلزمك لتطوير حسابك: شحن العملات والجواهر، شراء الشخصيات، وتفعيل التصنيفات والعضويات المميزة.',
        previewIndex: 2,
      ),
      const UnifiedTourStep(
        section: UnifiedTourSection.store,
        title: 'اختر قسمًا',
        text:
            'الأزرار العلوية تنقلك بين العروض، وأرصدة اللعب، والجواهر، والعضوية، والفئات والشخصيات.',
        previewIndex: 2,
      ),
      const UnifiedTourStep(
        section: UnifiedTourSection.store,
        title: 'الباقات والإعلانات',
        text:
            'الباقات المدفوعة تُشترى عبر Google Play. زر الإعلان يمنح المكافأة بعد إكمال المشاهدة، ضمن العدد اليومي المتاح.',
        previewIndex: 2,
      ),
    ]);

    // ── 5. Character Section (الشخصيات) ──────────────────────────
    steps.addAll([
      UnifiedTourStep(
        section: UnifiedTourSection.characters,
        title: 'شخصيتك في الساحة',
        text:
            'هذا زر بطلك في الساحة. اضغط هنا أو اضغط «التالي» للدخول واختيار بطلك ومعاينة حركاته وتعبيرات الفوز.',
        targetKey: widget.homeTargets?[HomeGuideTarget.character],
        previewIndex: null,
      ),
      const UnifiedTourStep(
        section: UnifiedTourSection.characters,
        title: 'اختر من يمثّلك',
        text:
            'هذه الشخصيات التي يمكنك اللعب بها. عاينها أولًا، ثم أكّد الشخصية التي تريدها.',
        previewIndex: 3,
      ),
      const UnifiedTourStep(
        section: UnifiedTourSection.characters,
        title: 'معاينة الشخصية',
        text:
            'اضغط بطاقة لمعاينة الشخصية. لا يتغير اختيارك المحفوظ إلا بعد التأكيد.',
        previewIndex: 3,
      ),
      const UnifiedTourStep(
        section: UnifiedTourSection.characters,
        title: 'أنت الآن جاهز للتحدي!',
        text:
            'أكملت الجولة التعريفية الشاملة! سجّل دخولك بحساب Google الآن لحفظ إنجازاتك والمنافسة أونلاين، أو تابع كزائر.',
        isFinalChoiceStep: true,
        previewIndex: null,
      ),
    ]);

    _steps = steps;
  }

  void _listenToControllers() {
    _campaignGuideController.ready.then((_) {
      if (!mounted) return;
      _mergePageSteps(
          UnifiedTourSection.campaign, _campaignGuideController.steps);
    });
    _storeGuideController.ready.then((_) {
      if (!mounted) return;
      _mergePageSteps(UnifiedTourSection.store, _storeGuideController.steps);
    });
    _characterGuideController.ready.then((_) {
      if (!mounted) return;
      _mergePageSteps(
          UnifiedTourSection.characters, _characterGuideController.steps);
    });
  }

  void _mergePageSteps(UnifiedTourSection section, List<GuideStep> pageSteps) {
    if (pageSteps.isEmpty) return;

    final updated = List<UnifiedTourStep>.from(_steps);
    var changed = false;

    for (var i = 0; i < updated.length; i++) {
      final s = updated[i];
      if (s.section != section ||
          s.previewIndex == null ||
          s.isFinalChoiceStep) {
        continue;
      }
      final matchIndex = pageSteps.indexWhere((p) => p.title == s.title);
      if (matchIndex != -1) {
        final pStep = pageSteps[matchIndex];
        if (s.targetKey != pStep.targetKey || s.onEnter != pStep.onEnter) {
          updated[i] = UnifiedTourStep(
            section: s.section,
            title: s.title,
            text: pStep.text.isNotEmpty ? pStep.text : s.text,
            targetKey: pStep.targetKey ?? s.targetKey,
            previewIndex: s.previewIndex,
            onEnter: pStep.onEnter ?? s.onEnter,
            isFinalChoiceStep: s.isFinalChoiceStep,
          );
          changed = true;
        }
      }
    }

    if (changed) {
      setState(() {
        _steps = updated;
      });
      _scheduleMeasurement();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = .5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
    _scheduleMeasurement();
  }

  @override
  void didChangeMetrics() => _scheduleMeasurement();

  void _scheduleMeasurement() {
    if (_measurementPending) return;
    _measurementPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementPending = false;
      if (!mounted) return;
      final measured = _readTargetRect();
      if (measured != _target) setState(() => _target = measured);
    });
  }

  Rect? _readTargetRect() {
    final surface = _surfaceKey.currentContext?.findRenderObject();
    final targetKey = _currentStep.targetKey;
    final object = targetKey?.currentContext?.findRenderObject();
    Rect? measured;
    if (surface is RenderBox &&
        surface.hasSize &&
        object is RenderBox &&
        object.attached &&
        object.hasSize &&
        !object.size.isEmpty) {
      final rect = MatrixUtils.transformRect(
          object.getTransformTo(surface), Offset.zero & object.size);
      final visible = rect.intersect(Offset.zero & surface.size);
      if (visible.isFinite && !visible.isEmpty) measured = visible;
    }
    return measured;
  }

  Future<void> _move(int offset) async {
    if (_busy || _finished) return;
    final next = _stepIndex + offset;
    if (next < 0 || next >= _steps.length) return;

    final prepare = _steps[next].onEnter;
    if (prepare != null) {
      setState(() {
        _preparing = true;
        _target = null;
      });
      try {
        await prepare().timeout(const Duration(milliseconds: 200));
      } catch (_) {}
      if (!mounted) return;
      _preparing = false;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _stepIndex = next;
      _target = _readTargetRect();
      _signInError = null;
    });
    _scheduleMeasurement();
  }

  Future<void> _persistTourCompletion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(UnifiedGuestTourOverlay.completedPrefKey, true);
      await prefs.setBool(UnifiedGuestTourOverlay.legacyHomePrefKey, true);
    } catch (_) {}
  }

  void _finish({bool skipped = false}) {
    if (_finished) return;
    _finished = true;
    _preparing = false;
    _signingIn = false;
    HapticFeedback.lightImpact();
    unawaited(_persistTourCompletion());
    (skipped ? widget.onSkip ?? widget.onComplete : widget.onComplete)();
  }

  void _demo() {
    final navigator = Navigator.of(context);
    _finish();
    navigator.push(MaterialPageRoute<void>(
      builder: (_) => const FirstRunChallengeScreen(),
    ));
  }

  Future<void> _handleGoogleSignIn() async {
    if (_signingIn) return;
    final rootAppState = widget.rootContext.read<AppState>();
    HapticFeedback.lightImpact();

    setState(() {
      _signingIn = true;
      _signInError = null;
    });

    try {
      await rootAppState.signInWithGoogle();
      if (!mounted) return;
      setState(() => _signingIn = false);

      if (rootAppState.user != null) {
        _finish();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _signingIn = false;
          _signInError = e is FirebaseAuthException && e.code == 'cancelled'
              ? null
              : 'تعذّر تسجيل الدخول. حاول مجددًا أو استمر كزائر.';
        });
      }
    }
  }

  void _openOtherLoginOptions() {
    HapticFeedback.lightImpact();
    _finish(skipped: true);
    LoginBottomSheet.show(widget.rootContext);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulse.dispose();
    _speech.dispose();
    _campaignGuideController.dispose();
    _storeGuideController.dispose();
    _characterGuideController.dispose();
    _previewState.dispose();
    _previewPurchases.dispose();
    _previewAds.dispose();
    _previewSettings.dispose();
    _previewPromo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFinalStep =
        _stepIndex == _steps.length - 1 || _currentStep.isFinalChoiceStep;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            if (_stepIndex > 0) {
              _move(-1);
            } else {
              _finish(skipped: true);
            }
          }
        },
        child: BlockSemantics(
          child: Material(
            key: _surfaceKey,
            color: Colors.transparent,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── 1. Read-Only Preview Pages (Under MultiProvider) ──
                Offstage(
                  offstage: _currentStep.previewIndex == null,
                  child: MultiProvider(
                    providers: [
                      ChangeNotifierProvider<AppState>.value(
                          value: _previewState),
                      ChangeNotifierProvider<InAppPurchaseService>.value(
                          value: _previewPurchases),
                      ChangeNotifierProvider<AdService>.value(value: _previewAds),
                      ChangeNotifierProvider<AppSettings>.value(
                          value: _previewSettings),
                      ChangeNotifierProvider<CrossPromoService>.value(
                          value: _previewPromo),
                    ],
                    child: AbsorbPointer(
                      absorbing: true,
                      child: IndexedStack(
                        index: _currentStep.previewIndex ?? 0,
                        children: [
                          // Page 0: Modes Preview
                          _ModesPreviewPage(guideTargets: _modeTargets),
                          // Page 1: Campaign Map Preview
                          CampaignMapScreen(
                            guideController: _campaignGuideController,
                          ),
                          // Page 2: Store Preview
                          StoreScreen(
                            guideController: _storeGuideController,
                          ),
                          // Page 3: Character Select Preview
                          CharacterSelectScreen(
                            guideController: _characterGuideController,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── 2. Spotlight & Presentation Overlay ──
                LayoutBuilder(
                  builder: (context, area) {
                    final padding = MediaQuery.paddingOf(context);
                    final unit = (View.of(context).devicePixelRatio /
                            MediaQuery.devicePixelRatioOf(context))
                        .clamp(1.0, 3.0);
                    final bounds = Rect.fromLTRB(
                      padding.left + 12 * unit,
                      (padding.top + 12) * unit,
                      area.maxWidth - padding.right - 12 * unit,
                      area.maxHeight - 12 * unit,
                    );
                    final stage = GuideTourPlacement.panelFor(
                      bounds,
                      _target,
                      unit: unit,
                      allowShortPanel: true,
                      finalStep: isFinalStep,
                    );

                    return Stack(
                      children: [
                        // Dark Spotlight Mask
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _pulse,
                            builder: (_, __) => CustomPaint(
                              painter: SpotlightPainter(
                                targetRect: _target,
                                panelRect: stage,
                                animationValue: _pulse.value,
                              ),
                            ),
                          ),
                        ),

                        // Intercept touches
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {},
                          ),
                        ),

                        // Target Tap Area
                        if (_target != null && !isFinalStep)
                          Positioned.fromRect(
                            rect: _target!,
                            child: Semantics(
                              button: true,
                              label: 'متابعة شرح ${_currentStep.title}',
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _move(1),
                              ),
                            ),
                          ),

                        // Presenter Stage Card
                        Positioned.fromRect(
                          rect: stage,
                          child: SizedBox(
                            child: FittedBox(
                              fit: BoxFit.fill,
                              child: SizedBox(
                                width: stage.width / unit,
                                height: stage.height / unit,
                                child: _buildStage(
                                  stage.size / unit,
                                  isFinalStep,
                                  _target != null &&
                                      _target!.center.dx > stage.center.dx,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStage(Size size, bool finalStep, bool flipped) {
    final landscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final compact = landscape && size.height < 430;
    final sideBySide = finalStep && size.width >= 620;

    final controlsWidth = compact && finalStep
        ? math.min(300.0, size.width * .44)
        : 0.0;
    final sceneWidth = compact
        ? size.width - controlsWidth - 12
        : sideBySide
            ? 340.0
            : size.width;

    final choicesHeight = finalStep && !sideBySide && !compact
        ? (_signInError == null ? 124.0 : 158.0)
        : 0.0;
    final available = compact ? size.height : size.height - choicesHeight;

    final bubbleHeight = math.max(
      compact ? 124.0 : 156.0,
      GuidePresenterScene.bubbleHeightFor(
        _currentStep.title,
        _currentStep.text,
        sceneWidth,
        showTitle: true,
        extraHeight: 74.0,
      ),
    );
    final hostHeight = math.min(
      math.min(210.0, sceneWidth * 141 / 208),
      math.max(1.0, (available - bubbleHeight - 6) / (1 + 64 / 141)),
    );

    final scene = GuidePresenterScene(
      title: _currentStep.title,
      text: _currentStep.text,
      width: sceneWidth,
      presenterHeight: hostHeight,
      bubbleHeight: bubbleHeight,
      flipped: flipped,
      showTitle: true,
      controller: _speech,
      bubbleHeader: _buildBubbleHeader(),
      bubbleFooter: _buildBubbleFooter(finalStep),
    );

    if (compact) {
      return Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          scene,
          if (finalStep) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: controlsWidth,
              child: _buildFinalChoicesCard(),
            ),
          ],
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: sideBySide
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    scene,
                    const SizedBox(width: 16),
                    Expanded(child: _buildFinalChoicesCard()),
                  ],
                )
              : Align(alignment: Alignment.center, child: scene),
        ),
        if (finalStep && !sideBySide)
          SizedBox(height: choicesHeight, child: _buildFinalChoicesCard()),
      ],
    );
  }

  Widget _buildBubbleHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Corner button: Exit/Skip (✕)
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: IconButton(
            tooltip: 'تخطي الجولة',
            iconSize: 15,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
            onPressed: _busy ? null : () => _finish(skipped: true),
          ),
        ),

        // Center: Section & Step Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x55FFD878), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currentStep.section.label,
                style: TextStyle(
                  fontFamily: 'NotoSansArabic',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _currentStep.section.accentColor,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                '•',
                style: TextStyle(fontSize: 10, color: Colors.white38, height: 1.1),
              ),
              const SizedBox(width: 5),
              Text(
                '${_stepIndex + 1} من ${_steps.length}',
                style: const TextStyle(
                  fontFamily: 'NotoSansArabic',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD878),
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),

        // Corner button: Replay speech (⟲)
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: IconButton(
            tooltip: 'إعادة الشرح',
            iconSize: 15,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            icon: const Icon(Icons.replay_rounded, color: Color(0xFF2563EB)),
            onPressed: _busy ? null : _speech.replay,
          ),
        ),
      ],
    );
  }

  Widget _buildBubbleFooter(bool finalStep) {
    final canGoBack = _stepIndex > 0 && !_busy;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Corner button: Previous (السابق)
        SizedBox(
          height: 32,
          child: OutlinedButton(
            onPressed: canGoBack ? () => _move(-1) : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              disabledForegroundColor: const Color(0xFF94A3B8),
              backgroundColor: const Color(0xFFF8FAFC),
              disabledBackgroundColor: const Color(0xFFF1F5F9),
              side: BorderSide(
                color: canGoBack
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_forward_rounded, size: 14),
                SizedBox(width: 4),
                Text(
                  'السابق',
                  style: TextStyle(
                    fontFamily: 'NotoSansArabic',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Corner button: Next (التالي / إنهاء وبدء اللعب)
        SizedBox(
          height: 32,
          child: FilledButton(
            onPressed: _busy
                ? null
                : finalStep
                    ? () => _finish()
                    : () => _move(1),
            style: FilledButton.styleFrom(
              backgroundColor: finalStep
                  ? const Color(0xFF10B981)
                  : const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(horizontal: finalStep ? 14 : 12),
              elevation: 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  finalStep ? 'إنهاء وبدء اللعب' : 'التالي',
                  style: const TextStyle(
                    fontFamily: 'NotoSansArabic',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  finalStep
                      ? Icons.check_circle_rounded
                      : Icons.arrow_back_rounded,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinalChoicesCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xF20F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFACC15).withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Primary Google Sign-in Button
          FilledButton.icon(
            onPressed: _busy ? null : _handleGoogleSignIn,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _signingIn
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.g_mobiledata_rounded, size: 28),
            label: const Text(
              'المتابعة بحساب Google',
              style: TextStyle(
                fontFamily: 'NotoSansArabic',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Secondary Demo Button
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _demo,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF34D399),
                    side: const BorderSide(color: Color(0xFF059669)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text(
                    'جرّب التحدي',
                    style: TextStyle(fontFamily: 'NotoSansArabic', fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextButton(
                  onPressed: _openOtherLoginOptions,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF94A3B8),
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  ),
                  child: const Text(
                    'خيارات أخرى',
                    style: TextStyle(fontFamily: 'NotoSansArabic', fontSize: 12),
                  ),
                ),
              ),
            ],
          ),

          if (_signInError != null) ...[
            const SizedBox(height: 4),
            Text(
              _signInError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFB8B8),
                fontSize: 10,
                fontFamily: 'NotoSansArabic',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Standalone container for GameModesArtwork inside the unified tour.
class _ModesPreviewPage extends StatelessWidget {
  const _ModesPreviewPage({required this.guideTargets});

  final Map<ModeGuideTarget, GlobalKey> guideTargets;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = math.min(
      900.0,
      math.min(
        media.size.width - media.padding.horizontal - 24,
        (media.size.height - media.padding.vertical - 24) *
            GameModesArtwork.aspectRatio,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF090D1A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.1,
            colors: [Color(0xFF141F36), Color(0xFF070B14)],
          ),
        ),
        child: Center(
          child: SizedBox(
            width: width,
            child: GameModesArtwork(
              guideTargets: guideTargets,
              isOnline: true,
              onClose: () {},
              onMainChallenge: () {},
              onGroupChallenge: () {},
              onFriendChallenge: () {},
              onOffline: () {},
              onUnavailable: () {},
            ),
          ),
        ),
      ),
    );
  }
}
