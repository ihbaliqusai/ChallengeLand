import '../../widgets/game_back_button.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/app_state.dart';
import '../../core/lucky_wheel_motion.dart';
import '../../models/game_character.dart';
import '../../models/lucky_wheel_prize.dart';
import '../../models/store_catalog.dart';
import '../../services/in_app_purchase_service.dart';
import '../../widgets/lucky_wheel_artwork.dart';
import '../../widgets/lucky_wheel_controls.dart';

/// Spins toward a prize only after the server has saved its daily receipt.
class LuckyWheelScreen extends StatefulWidget {
  const LuckyWheelScreen({super.key});
  @override
  State<LuckyWheelScreen> createState() => _LuckyWheelScreenState();
}

class _LuckyWheelScreenState extends State<LuckyWheelScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _lights;
  late final AnimationController _rotation;
  late final AnimationController _reveal;
  late final Ticker _pointerTicker;
  final _pointerSpring = LuckyWheelPointerSpring();
  final _pointerAngle = ValueNotifier<double>(0);
  Duration _pointerElapsed = Duration.zero;
  double _pointerPreviousTurns = 0;
  double _pointerSettlingSeconds = 0;
  Completer<void>? _pointerSettled;
  Duration _lastTickSound = const Duration(milliseconds: -100);
  Animation<double> _turns = const AlwaysStoppedAnimation(0);
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _loading = true;
  bool _busy = false;
  bool _buying = false;
  bool _syncingPurchase = false;
  InAppPurchaseService? _iap;
  String? _error;
  LuckyWheelSpin? _result;
  int? _winningSlot;
  GameCharacter? _spinCharacter;
  bool _spinCharacterCompensation = false;
  int _lastTick = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lights = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _rotation =
        AnimationController(vsync: this, duration: luckyWheelSpinDuration)
          ..addListener(_onWheelTick);
    _pointerTicker = createTicker(_onPointerFrame);
    _reveal = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _iap = context.read<InAppPurchaseService?>();
      _iap?.addDeliveryListener(_onPurchaseDelivered);
      if (_iap != null) unawaited(_iap!.loadProducts());
      if (!MediaQuery.of(context).disableAnimations) _lights.repeat();
      _tick();
      unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    if (!mounted || _busy) return;
    try {
      final app = context.read<AppState>();
      await Future.wait([app.loadLevelData(), app.loadEconomy()])
          .timeout(const Duration(seconds: 8));
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'تعذّر تحديث الدولاب. تحقق من الاتصال وأعد المحاولة.';
        });
      }
    }
  }

  void _onPurchaseDelivered(String productId) {
    if (StoreCatalog.canonicalId(productId) == StoreCatalog.wheelSpinPack.id) {
      unawaited(_syncPurchasedSpins());
    }
  }

  Future<void> _syncPurchasedSpins() async {
    if (!mounted || _syncingPurchase) return;
    setState(() => _syncingPurchase = true);
    final app = context.read<AppState>();
    try {
      await app.refreshWheelPurchases();
      if (mounted) {
        setState(() => _error = app.economyError == null
            ? null
            : 'تعذّرت مزامنة اللفات. أعد التحقق من مشترياتك.');
      }
    } finally {
      if (mounted) setState(() => _syncingPurchase = false);
    }
  }

  Future<void> _buySpins() async {
    final app = context.read<AppState>();
    final iap = _iap;
    if (iap == null ||
        _busy ||
        _buying ||
        iap.isPurchasing ||
        !app.isCommerceReady) {
      return;
    }
    setState(() {
      _buying = true;
      _error = null;
    });
    try {
      // A launched payment sheet is not delivery; verified events refresh credit.
      final launched = await iap.buyProduct(StoreCatalog.wheelSpinPack.id);
      if (!launched && mounted) {
        setState(
            () => _error = iap.getExplanation(StoreCatalog.wheelSpinPack.id));
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _retryPurchases() async {
    final iap = _iap;
    if (iap == null || _buying || _syncingPurchase) return;
    setState(() => _error = null);
    await iap.restorePurchases();
    if (!mounted) return;
    await _syncPurchasedSpins();
  }

  void _tick() {
    if (!mounted) return;
    final now = DateTime.now();
    final app = context.read<AppState>();
    final nextFreeMillis = app.economyWallet.nextFreeWheelSpinMillis;
    Duration remaining = Duration.zero;
    if (nextFreeMillis > 0) {
      final nextFree = DateTime.fromMillisecondsSinceEpoch(nextFreeMillis);
      if (nextFree.isAfter(now)) {
        remaining = nextFree.difference(now);
      }
    } else if (!app.isLuckyWheelFreeAvailable) {
      final nowUtc = now.toUtc();
      remaining = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day + 1)
          .difference(nowUtc);
    }
    final hadCooldown = _remaining > Duration.zero;
    setState(() => _remaining = remaining);
    if (hadCooldown && remaining == Duration.zero && !_busy) {
      unawaited(_refresh());
    }
  }

  void _onWheelTick() {
    // The pins are between sectors. At rest the pointer is over a prize's
    // center, so the first contact is half a sector after the spin begins.
    final tick = (_turns.value * luckyWheelSlots.length + .5).floor();
    if (tick <= _lastTick) return;
    _lastTick = tick;
    final elapsed = _rotation.lastElapsedDuration ?? Duration.zero;
    if (mounted &&
        _rotation.isAnimating &&
        !MediaQuery.of(context).disableAnimations &&
        elapsed - _lastTickSound >= const Duration(milliseconds: 40)) {
      _lastTickSound = elapsed;
      _haptic('light');
      _sfx('wheel_tick');
    }
  }

  void _onPointerFrame(Duration elapsed) {
    final delta = (elapsed - _pointerElapsed).inMicroseconds / 1000000;
    _pointerElapsed = elapsed;
    if (delta <= 0) return;
    final turns = _turns.value;
    final speed = math.max(0.0, (turns - _pointerPreviousTurns) / delta);
    _pointerPreviousTurns = turns;
    _pointerSpring.step(
        elapsedSeconds: delta, turns: turns, turnsPerSecond: speed);
    _pointerAngle.value = _pointerSpring.angle;
    if (!_rotation.isAnimating) {
      _pointerSettlingSeconds += delta;
      if ((_pointerSpring.angle.abs() < .001 &&
              _pointerSpring.angularVelocity.abs() < .015) ||
          _pointerSettlingSeconds >= .65) {
        _stopPointer();
      }
    }
  }

  void _preparePointer(double turns) {
    _stopPointer();
    _pointerElapsed = Duration.zero;
    _pointerPreviousTurns = turns;
    _pointerSettlingSeconds = 0;
    _pointerSettled = Completer<void>();
    _pointerSpring.step(elapsedSeconds: 0, turns: turns, turnsPerSecond: 0);
    _lastTick = (turns * luckyWheelSlots.length + .5).floor();
    _lastTickSound = const Duration(milliseconds: -100);
  }

  void _stopPointer() {
    _pointerTicker.stop();
    _pointerSpring.reset();
    _pointerAngle.value = 0;
    final pending = _pointerSettled;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tick();
      unawaited(_refresh());
    }
  }

  Future<void> _spin() async {
    final app = context.read<AppState>();
    if (_busy ||
        _loading ||
        _buying ||
        _syncingPurchase ||
        app.spinningLuckyWheel ||
        !app.canSpinLuckyWheel) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _winningSlot = null;
      _spinCharacter = app.wheelPrizeCharacter;
      _spinCharacterCompensation = _spinCharacter == null;
    });
    LuckyWheelSpin? result;
    try {
      result = await app.spinLuckyWheel();
    } catch (_) {
      // A retry recovers the same receipt after an interrupted request.
    }
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _busy = false;
        _error = app.luckyWheelError ?? 'تعذّر إتمام اللفة. حاول مجددًا.';
      });
      return;
    }
    if (result.prize.kind == LuckyWheelPrizeKind.character) {
      // Another device may have won the previewed character before this request.
      // The character committed by the server is what the winning wedge shows.
      _spinCharacter = result.characterIndex == null
          ? null
          : CharacterCatalog.byIndex(result.characterIndex!);
      _spinCharacterCompensation = result.compensation;
    }
    final slot = luckyWheelSlots.indexOf(result.prize.index);
    final start = _turns.value;
    final end = start.floorToDouble() +
        6 +
        (luckyWheelSlots.length - slot) / luckyWheelSlots.length;
    _turns = Tween<double>(begin: start, end: end).animate(
        _rotation.drive(CurveTween(curve: const LuckyWheelSpinCurve())));
    _preparePointer(start);
    if (MediaQuery.of(context).disableAnimations) {
      _rotation.value = 1;
      _stopPointer();
    } else {
      try {
        final spin = _rotation.forward(from: 0);
        _pointerTicker.start();
        await spin.orCancel;
        // Let the last peg release the needle before the reward covers it.
        await _pointerSettled!.future;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      _winningSlot = slot;
      _busy = false;
    });
    _haptic('medium');
    _sfx('wheel_win');
    if (MediaQuery.of(context).disableAnimations) {
      _reveal.value = 1;
    } else {
      unawaited(_reveal.forward(from: 0));
    }
  }

  void _haptic(String style) {
    final settings = context.read<AppSettings?>();
    if (settings != null) {
      unawaited(settings.playHaptic(style: style).catchError((_) => false));
    }
  }

  void _sfx(String effect) {
    final settings = context.read<AppSettings?>();
    if (settings != null) {
      unawaited(
          settings.playSoundEffect(effect: effect).catchError((_) => false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _iap?.removeDeliveryListener(_onPurchaseDelivered);
    _timer?.cancel();
    _lights.dispose();
    _rotation.dispose();
    _reveal.dispose();
    _stopPointer();
    _pointerTicker.dispose();
    _pointerAngle.dispose();
    super.dispose();
  }

  String get _countdown {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(_remaining.inHours)}:${two(_remaining.inMinutes % 60)}:${two(_remaining.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final busy = _busy || app.spinningLuckyWheel;
    return PopScope(
      canPop: !busy && !_buying,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFF211057),
          body: RepaintBoundary(
            key: const ValueKey('lucky-wheel-page'),
            child: LuckyWheelStageBackground(
              child: SafeArea(
                child: LayoutBuilder(builder: (context, box) {
                  return Stack(children: [
                    Positioned.fill(
                      child: box.maxWidth > box.maxHeight * 1.2
                          ? _landscape(box, app, busy)
                          : _portrait(box, app, busy),
                    ),
                    if (_result != null)
                      Positioned.fill(
                          child: FadeTransition(
                        opacity: _reveal,
                        child: _PrizeReveal(
                          result: _result!,
                          animation: _reveal,
                          onClose: () => setState(() => _result = null),
                        ),
                      )),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: GameBackButton(
                        key: const ValueKey('lucky-wheel-back'),
                        onPressed: busy || _buying
                            ? null
                            : () => Navigator.maybePop(context),
                      ),
                    ),
                  ]);
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wheel(double diameter) {
    final character = _busy || _result != null
        ? _spinCharacter
        : context.read<AppState>().wheelPrizeCharacter;
    return SizedBox.square(
      dimension: diameter,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rotation, _lights, _pointerAngle]),
        builder: (_, __) => LuckyWheelArtwork(
            turns: _turns.value,
            pulse: _lights.value,
            pointerAngle: _pointerAngle.value,
            winningSlot: _winningSlot,
            character: character,
            characterCompensation: _busy || _result != null
                ? _spinCharacterCompensation
                : character == null),
      ),
    );
  }

  Widget _landscape(BoxConstraints box, AppState app, bool busy) {
    final width = math.min(box.maxWidth, box.maxHeight * 16 / 9);
    final height = math.min(box.maxHeight, box.maxWidth * 9 / 16);
    final scale = width / 960;
    final diameter = math.min(height - 24 * scale, width * .57);
    return Center(
        child: SizedBox(
            width: width,
            height: height,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: width * .045),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _wheel(math.max(120, diameter)),
                  SizedBox(width: width * .025),
                  Flexible(
                      child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 330 * scale),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                          vertical: 10 * scale, horizontal: 10 * scale),
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          LuckyWheelTitle(scale: scale),
                          SizedBox(height: 7 * scale),
                          Text('لفّ الدولاب واكتشف جائزتك!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: const Color(0xFFFFF2D5),
                                  fontSize: 15 * scale,
                                  fontWeight: FontWeight.w700,
                                  shadows: const [
                                    Shadow(
                                        color: Color(0xFF120622),
                                        offset: Offset(0, 2))
                                  ])),
                          SizedBox(height: 20 * scale),
                          _controls(app, busy, scale: scale.clamp(.82, 1.4)),
                          SizedBox(height: 12 * scale),
                          LuckyWheelPrizeLegend(
                              character: app.wheelPrizeCharacter,
                              scale: scale.clamp(.8, 1.3)),
                        ]),
                      ),
                    ),
                  )),
                ]),
              ),
            )));
  }

  Widget _portrait(BoxConstraints box, AppState app, bool busy) {
    final diameter =
        math.min(box.maxWidth * .96, math.max(180.0, box.maxHeight - 218));
    return SingleChildScrollView(
        child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: box.maxHeight),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(height: 14),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 38),
            child: LuckyWheelTitle()),
        const SizedBox(height: 10),
        _wheel(diameter),
        const SizedBox(height: 10),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 44),
            child: _controls(app, busy)),
        const SizedBox(height: 14),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 38),
            child: LuckyWheelPrizeLegend(character: app.wheelPrizeCharacter)),
        const SizedBox(height: 20),
      ]),
    ));
  }

  Widget _controls(AppState app, bool busy, {double scale = 1}) {
    final iap = context.watch<InAppPurchaseService?>();
    final details = iap?.getProductDetails(StoreCatalog.wheelSpinPack.id);
    final canSpin = app.canSpinLuckyWheel;
    final checkoutBusy =
        _buying || _syncingPurchase || (iap?.isPurchasing ?? false);
    final ready = !_loading && !busy && !checkoutBusy;
    final spinReady = !_loading && !busy && !_buying && !_syncingPurchase;
    final canBuy = ready &&
        app.isCommerceReady &&
        (iap?.isAvailable ?? false) &&
        details != null &&
        details.available &&
        details.price.isNotEmpty;
    final relevantStatus =
        iap?.activeProductId == StoreCatalog.wheelSpinPack.id ||
            (iap?.isRestoring ?? false);
    final label = busy
        ? (_rotation.isAnimating ? 'يلفّ الدولاب…' : 'جارٍ التحضير…')
        : _loading
            ? 'جارٍ التحميل…'
            : !canSpin && checkoutBusy
                ? 'جارٍ تأكيد الشراء…'
                : canSpin
                    ? (app.hasPendingLuckyWheelSpin
                        ? 'استعادة اللفة'
                        : _error != null
                            ? 'إعادة المحاولة'
                            : 'لفّ الدولاب')
                    : '3 لفات إضافية';
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(
          animation: _lights,
          builder: (_, __) => LuckyWheelActionButton(
                label: label,
                pulse: _lights.value,
                scale: scale,
                subtitle: !canSpin && !busy && !checkoutBusy && !_loading
                    ? details?.price ??
                        ((iap?.isLoading ?? false)
                            ? 'جارٍ تحميل السعر…'
                            : 'السعر غير متاح حاليًا')
                    : null,
                onPressed: spinReady && canSpin
                    ? _spin
                    : !canSpin && canBuy
                        ? _buySpins
                        : null,
                badge: canSpin && spinReady && !app.hasPendingLuckyWheelSpin
                    ? (app.isLuckyWheelFreeAvailable
                        ? 1 + app.purchasedWheelSpins
                        : app.purchasedWheelSpins)
                    : 0,
              )),
      const SizedBox(height: 10),
      if (app.purchasedWheelSpins > 0)
        Text('لفاتك الإضافية: ${app.purchasedWheelSpins}',
            key: const ValueKey('lucky-wheel-paid-balance'),
            style: const TextStyle(
                color: Color(0xFFFFE693),
                fontSize: 14,
                fontWeight: FontWeight.w800)),
      if (_error != null)
        Text(_error!,
            key: const ValueKey('lucky-wheel-error'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFFD1DD), fontSize: 13)),
      if (relevantStatus && iap != null && iap.statusMessage.isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(iap.statusMessage,
                textAlign: TextAlign.center,
                key: const ValueKey('lucky-wheel-purchase-status'),
                style:
                    const TextStyle(color: Color(0xFFE8D4FF), fontSize: 12))),
      const SizedBox(height: 4),
      Text(
          !app.isLuckyWheelFreeAvailable
              ? 'اللفة المجانية التالية خلال'
              : 'لفة مجانية كل 24 ساعة',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Color(0xFFF8E8FF),
              fontSize: 13,
              fontWeight: FontWeight.w700)),
      if (!app.isLuckyWheelFreeAvailable)
        Directionality(
            textDirection: TextDirection.ltr,
            child: Text(_countdown,
                key: const ValueKey('lucky-wheel-countdown'),
                style: const TextStyle(
                    color: Color(0xFFFFE68D),
                    fontSize: 23,
                    height: 1.2,
                    fontWeight: FontWeight.w900))),
      if (!canSpin && iap != null && !checkoutBusy && details == null)
        TextButton(
            onPressed: () {
              AppSettings.playClick();
              iap.loadProducts();
            },
            child: const Text('تحديث السعر',
                style: TextStyle(color: Color(0xFFFFE693)))),
      if (iap != null && !app.isLuckyWheelFreeAvailable)
        TextButton(
            onPressed: busy || _buying || _syncingPurchase
                ? null
                : () {
                    AppSettings.playClick();
                    _retryPurchases();
                  },
            child: const Text('التحقق من المشتريات',
                style: TextStyle(color: Color(0xFFE5C8F6), fontSize: 12))),
      TextButton(
          onPressed: busy || _buying
              ? null
              : () {
                  AppSettings.playClick();
                  _showPrizeDetails();
                },
          child: const Text('الجوائز وفرص الفوز',
              style: TextStyle(color: Color(0xFFE5C8F6), fontSize: 12))),
    ]);
  }

  Future<void> _showPrizeDetails() => showDialog<void>(
        context: context,
        builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: const Color(0xFF251044),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: Color(0xFFE7C27C), width: 1.6)),
              titleTextStyle: const TextStyle(
                  color: Color(0xFFFFE7A6),
                  fontFamily: 'Baloo',
                  fontSize: 22,
                  fontWeight: FontWeight.w900),
              title: const Text('الجوائز وفرص الفوز'),
              scrollable: true,
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('كل خانة لها فرصة متساوية: 1 من 12 (نحو 8.33%).',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                for (final prize in LuckyWheelPrize.catalog)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox.square(
                        dimension: 38,
                        child: LuckyWheelPrizeIcon(
                            prize: prize,
                            character:
                                context.read<AppState>().wheelPrizeCharacter,
                            characterCompensation:
                                context.read<AppState>().wheelPrizeCharacter ==
                                    null)),
                    title: Text(prize.kind == LuckyWheelPrizeKind.character
                        ? context.read<AppState>().wheelPrizeCharacter == null
                            ? '100 جوهرة — اكتملت الشخصيات'
                            : 'شخصية ${context.read<AppState>().wheelPrizeCharacter!.nameAr}'
                        : prize.displayTitle),
                    trailing:
                        Text('${prize.probabilityPercent.toStringAsFixed(2)}%'),
                    subtitle: prize.kind == LuckyWheelPrizeKind.chest
                        ? const Text('1000 نقود + 20 جوهرة + مفتاحان + تذكرتان')
                        : prize.kind == LuckyWheelPrizeKind.character
                            ? const Text(
                                'تتبدّل بعد الفوز إلى شخصية أخرى غير مملوكة. إذا اكتملت الشخصيات تحصل على 100 جوهرة.')
                            : null,
                  ),
              ]),
              actions: [
                TextButton(
                    onPressed: () {
                      AppSettings.playClick();
                      Navigator.pop(context);
                    },
                    child: const Text('حسنًا'))
              ],
            )),
      );
}

class _PrizeReveal extends StatelessWidget {
  const _PrizeReveal(
      {required this.result, required this.onClose, required this.animation});
  final LuckyWheelSpin result;
  final VoidCallback onClose;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xC211052B),
        child: Center(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ScaleTransition(
            scale: Tween<double>(begin: .65, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
            child: Container(
              key: const ValueKey('lucky-wheel-result'),
              width: 360,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF643AC0), Color(0xFF2E126C)]),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFFFE693), width: 3),
                  boxShadow: const [
                    BoxShadow(color: Color(0x88591CCE), blurRadius: 30)
                  ]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('مبروك!',
                    style: TextStyle(
                        color: Color(0xFFFFE693),
                        fontSize: 34,
                        fontWeight: FontWeight.w900)),
                SizedBox(
                    height: 98,
                    width: 116,
                    child: LuckyWheelPrizeIcon(
                        prize: result.prize,
                        character: result.characterIndex == null
                            ? null
                            : CharacterCatalog.byIndex(result.characterIndex!),
                        characterCompensation: result.compensation)),
                Text(
                    result.characterIndex != null
                        ? 'شخصية ${CharacterCatalog.byIndex(result.characterIndex!).nameAr}'
                        : result.compensation
                            ? '100 جوهرة'
                            : result.prize.displayTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(
                    result.compensation
                        ? 'كل الشخصيات لديك! حصلت على 100 جوهرة بدلًا منها'
                        : 'أُضيفت جائزتك إلى حسابك',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFFE8D4FF), fontSize: 13)),
                const SizedBox(height: 10),
                Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      for (final entry in result.grants.entries)
                        if (entry.value > 0)
                          Text(
                              '+${entry.value} ${switch (entry.key) {
                                'coins' => 'نقود',
                                'gems' => 'جواهر',
                                'keys' => 'مفاتيح',
                                'tickets' => 'تذاكر',
                                _ => entry.key,
                              }}',
                              style: const TextStyle(
                                  color: Color(0xFFFFE693), fontSize: 14)),
                    ]),
                const SizedBox(height: 16),
                LuckyWheelActionButton(
                    label: 'رائع، متابعة', onPressed: onClose),
              ]),
            ),
          ),
        )),
      );
}
