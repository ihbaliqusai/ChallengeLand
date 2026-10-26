import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/app_state.dart';
import '../../models/game_character.dart';
import '../../models/lucky_wheel_prize.dart';
import '../../models/store_catalog.dart';
import '../../services/in_app_purchase_service.dart';
import '../../widgets/adaptive_asset_image.dart';
import '../../widgets/lucky_wheel_artwork.dart';

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
  Animation<double> _turns = const AlwaysStoppedAnimation(0);
  Timer? _timer;
  DateTime _day = _utcDay();
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

  static DateTime _utcDay() {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lights = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _rotation = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3800))
      ..addListener(_onWheelTick);
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
    final now = DateTime.now().toUtc();
    final today = _utcDay();
    setState(() => _remaining =
        DateTime.utc(now.year, now.month, now.day + 1).difference(now));
    if (_day != today && !_busy) {
      _day = today;
      setState(() {
        _result = null;
        _winningSlot = null;
        _error = null;
        _loading = true;
      });
      unawaited(_refresh());
    }
  }

  void _onWheelTick() {
    final tick = (_turns.value * luckyWheelSlots.length).floor();
    if (tick == _lastTick) return;
    _lastTick = tick;
    if (mounted && !MediaQuery.of(context).disableAnimations) {
      _haptic('light');
    }
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
        CurvedAnimation(parent: _rotation, curve: Curves.easeOutQuint));
    if (MediaQuery.of(context).disableAnimations) {
      _rotation.value = 1;
    } else {
      try {
        await _rotation.forward(from: 0).orCancel;
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _iap?.removeDeliveryListener(_onPurchaseDelivered);
    _timer?.cancel();
    _lights.dispose();
    _rotation.dispose();
    _reveal.dispose();
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
                      left: 8,
                      top: 8,
                      child: IconButton(
                        key: const ValueKey('lucky-wheel-back'),
                        tooltip: 'رجوع',
                        onPressed: busy || _buying
                            ? null
                            : () => Navigator.maybePop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0x55200B45),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded,
                            textDirection: TextDirection.ltr,
                            size: 30,
                            color: Colors.white),
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
        animation: Listenable.merge([_rotation, _lights]),
        builder: (_, __) => LuckyWheelArtwork(
            turns: _turns.value,
            pulse: _lights.value,
            winningSlot: _winningSlot,
            character: character,
            characterCompensation: _busy || _result != null
                ? _spinCharacterCompensation
                : character == null),
      ),
    );
  }

  Widget _landscape(BoxConstraints box, AppState app, bool busy) {
    final diameter = math.min(box.maxHeight - 12, box.maxWidth * .55);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: box.maxWidth * .055),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _wheel(math.max(120, diameter)),
          SizedBox(width: box.maxWidth * .035),
          Flexible(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const _WheelTitle(),
                  const SizedBox(height: 10),
                  const Text('لفّ الدولاب واكتشف جائزتك!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFF7DFFF), fontSize: 16)),
                  const SizedBox(height: 22),
                  _controls(app, busy),
                  const SizedBox(height: 16),
                  _PrizeLegend(character: app.wheelPrizeCharacter),
                ]),
              ),
            ),
          )),
        ]),
      ),
    );
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
            child: _WheelTitle()),
        const SizedBox(height: 10),
        _wheel(diameter),
        const SizedBox(height: 10),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 44),
            child: _controls(app, busy)),
        const SizedBox(height: 20),
      ]),
    ));
  }

  Widget _controls(AppState app, bool busy) {
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
      _SpinButton(
        label: label,
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
            ? (app.claimedToday ? app.purchasedWheelSpins : 1)
            : 0,
      ),
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
          app.claimedToday
              ? 'اللفة المجانية التالية خلال'
              : 'لفة مجانية كل يوم',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Color(0xFFF8E8FF),
              fontSize: 13,
              fontWeight: FontWeight.w700)),
      if (app.claimedToday)
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
            onPressed: () => iap.loadProducts(),
            child: const Text('تحديث السعر',
                style: TextStyle(color: Color(0xFFFFE693)))),
      if (iap != null && app.claimedToday)
        TextButton(
            onPressed:
                busy || _buying || _syncingPurchase ? null : _retryPurchases,
            child: const Text('التحقق من المشتريات',
                style: TextStyle(color: Color(0xFFE5C8F6), fontSize: 12))),
      TextButton(
          onPressed: busy || _buying ? null : _showPrizeDetails,
          child: const Text('الجوائز وفرص الفوز',
              style: TextStyle(color: Color(0xFFE5C8F6), fontSize: 12))),
    ]);
  }

  Future<void> _showPrizeDetails() => showDialog<void>(
        context: context,
        builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
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
                    onPressed: () => Navigator.pop(context),
                    child: const Text('حسنًا'))
              ],
            )),
      );
}

class _WheelTitle extends StatelessWidget {
  const _WheelTitle();
  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Transform.rotate(
            angle: -.045,
            child: Stack(children: [
              Text('دولاب الحظ',
                  style: TextStyle(
                      fontSize: 48,
                      height: 1.5,
                      fontWeight: FontWeight.w900,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 7
                        ..color = const Color(0xFF54124E),
                      shadows: const [
                        Shadow(color: Color(0xFFEB55AC), offset: Offset(0, 5))
                      ])),
              const Text('دولاب الحظ',
                  style: TextStyle(
                      color: Color(0xFFFFF5D5),
                      fontSize: 48,
                      height: 1.5,
                      fontWeight: FontWeight.w900)),
            ])),
      );
}

class _SpinButton extends StatelessWidget {
  const _SpinButton(
      {required this.label,
      required this.onPressed,
      this.badge = 0,
      this.subtitle});
  final String label;
  final String? subtitle;
  final VoidCallback? onPressed;
  final int badge;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 224,
        height: 66,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
              child: DecoratedBox(
                  decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: onPressed != null
                ? const Color(0xFF2A9B00)
                : const Color(0xFF334B36),
            boxShadow: const [
              BoxShadow(color: Color(0xFF180D3E), offset: Offset(0, 4))
            ],
          ))),
          Positioned.fill(
              bottom: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: onPressed != null
                            ? [const Color(0xFF91FF08), const Color(0xFF4FE000)]
                            : [
                                const Color(0xFF617D4D),
                                const Color(0xFF385B38)
                              ]),
                    border: Border.all(
                        color: onPressed != null
                            ? const Color(0xFFB7FF66)
                            : const Color(0xFF6B805B),
                        width: 1.5)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey('lucky-wheel-spin'),
                    onTap: onPressed,
                    borderRadius: BorderRadius.circular(12),
                    child: Center(
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(label,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 27,
                                          fontWeight: FontWeight.w900,
                                          shadows: [
                                            Shadow(
                                                color: Color(0xFF285118),
                                                offset: Offset(0, 2),
                                                blurRadius: 2)
                                          ])),
                                  if (subtitle != null)
                                    Text(subtitle!,
                                        textDirection: TextDirection.ltr,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            height: 1.1,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700)),
                                ]),
                          )),
                    ),
                  ),
                ),
              )),
          if (badge > 0)
            Positioned(
                right: -8,
                top: -9,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: const Color(0xFFFC3949),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2)),
                  child: Text(badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          height: 1,
                          fontWeight: FontWeight.w900)),
                )),
        ]),
      );
}

class _PrizeLegend extends StatelessWidget {
  const _PrizeLegend({required this.character});
  final GameCharacter? character;
  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 6,
        children: [
          for (final prize in LuckyWheelPrize.catalog.take(6))
            Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox.square(
                  dimension: 23,
                  child: LuckyWheelPrizeIcon(
                      prize: prize,
                      character: character,
                      characterCompensation: character == null)),
              const SizedBox(width: 4),
              Text(prize.title,
                  style:
                      const TextStyle(color: Color(0xFFE5C8F6), fontSize: 11)),
            ]),
        ],
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
                    child: result.characterIndex != null
                        ? adaptiveAssetImage(
                            CharacterCatalog.byIndex(result.characterIndex!)
                                .asset,
                            width: 116,
                            height: 98,
                            fit: BoxFit.contain)
                        : LuckyWheelPrizeIcon(
                            prize: result.prize,
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
                _SpinButton(label: 'رائع، متابعة', onPressed: onClose),
              ]),
            ),
          ),
        )),
      );
}
