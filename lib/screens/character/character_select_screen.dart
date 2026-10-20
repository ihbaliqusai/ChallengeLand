import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../models/game_character.dart';
import '../../models/store_catalog.dart';
import '../home/store_screen.dart';

/// Character picker and showcase screen.
///
/// Shows a violet podium, full-body previews, descriptive character attributes,
/// an inspection sheet, and a roster that adapts to the screen orientation.
class CharacterSelectScreen extends StatefulWidget {
  const CharacterSelectScreen(
      {super.key, this.forced = false, this.initialIndex});

  /// When true, the screen is rendered by AuthGate as a mandatory initial step
  /// (no back button, primary action starts the journey). When false, it is
  /// opened from the profile or store with a back button.
  final bool forced;

  /// Opens a store preview without committing the player's saved selection.
  final int? initialIndex;

  @override
  State<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends State<CharacterSelectScreen>
    with SingleTickerProviderStateMixin {
  int _focused = CharacterCatalog.defaultIndex;
  bool _busy = false;

  late final AnimationController _idleController;
  late final Animation<double> _idleAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    final appState = context.read<AppState>();
    _focused = CharacterCatalog.byIndex(widget.initialIndex ??
            (appState.hasChosenCharacter
                ? appState.selectedCharacterIndex
                : CharacterCatalog.defaultIndex))
        .index;

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _idleAnimation = CurvedAnimation(
      parent: _idleController,
      curve: Curves.easeInOutSine,
    );

    final isTest = Platform.environment.containsKey('FLUTTER_TEST') ||
        WidgetsBinding.instance.runtimeType
            .toString()
            .contains('TestWidgetsFlutterBinding');
    if (isTest) {
      _idleController.value = 0.5;
    } else {
      _idleController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _idleController.dispose();
    super.dispose();
  }

  GameCharacter get _character => CharacterCatalog.byIndex(_focused);

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor:
              isError ? const Color(0xFFB91C1C) : const Color(0xFF0F766E),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  Future<void> _onPrimary() async {
    if (_busy) return;
    final appState = context.read<AppState>();
    final character = _character;

    // Locked by level
    if (!appState.isCharacterUnlocked(character) &&
        character.unlock.isLevelGated) {
      _showSnack(
        'تُفتح الشخصية عند وصولك إلى المستوى ${character.unlock.value}',
        isError: true,
      );
      return;
    }

    // Locked by purchase (Coins or Gems)
    if (!appState.isCharacterUnlocked(character)) {
      final isCoins = character.unlock.kind == CharacterUnlockKind.coins;
      final balance = isCoins ? appState.coins : appState.gems;
      if (balance < character.unlock.value) {
        final shortfall = character.unlock.value - balance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تحتاج إلى $shortfall ${isCoins ? 'عملة' : 'جوهرة'} إضافية لفتح هذه الشخصية.',
              textDirection: TextDirection.rtl,
            ),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'زيارة المتجر',
              textColor: const Color(0xFFFACC15),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => StoreScreen(
                    initialKind: isCoins
                        ? StoreProductKind.coins
                        : StoreProductKind.gems,
                  ),
                ));
              },
            ),
          ),
        );
        return;
      }

      final confirmed = await _confirmPurchase(character);
      if (confirmed != true || !mounted) return;

      setState(() => _busy = true);
      final bought = await appState.purchaseCharacter(character);
      if (!mounted) return;
      setState(() => _busy = false);

      if (!bought) {
        _showSnack('تعذّر الشراء — يرجى التحقق من رصيدك.', isError: true);
        return;
      }
      _showSnack('تهانينا! تم فتح شخصية ${character.nameAr} بنجاح 🎉');
    }

    // Commit character selection
    setState(() => _busy = true);
    final ok = await appState.selectCharacter(character.index);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!ok) {
      _showSnack('تعذّر اختيار الشخصية.', isError: true);
      return;
    }

    if (!widget.forced && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<bool?> _confirmPurchase(GameCharacter character) {
    final isCoins = character.unlock.kind == CharacterUnlockKind.coins;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0A152C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: character.color.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
          title: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: character.color.withValues(alpha: 0.16),
                  border: Border.all(
                    color: character.color.withValues(alpha: 0.6),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: character.color.withValues(alpha: 0.35),
                      blurRadius: 16,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: ClipOval(
                  child: Image.asset(character.asset, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'فتح شخصية ${character.nameAr}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Text(
            'هل تريد فتح هذه الشخصية بشكل دائم مقابل '
            '${_compactNumber(character.unlock.value)} '
            '${isCoins ? 'كوين' : 'جوهرة'}؟',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.5,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white60,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text(
                'إلغاء',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: Icon(
                isCoins ? Icons.monetization_on_rounded : Icons.diamond_rounded,
                size: 20,
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    isCoins ? const Color(0xFFFACC15) : const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF111827),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
              label: Text(
                'فتح مقابل ${_compactNumber(character.unlock.value)}',
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCharacterInspection() {
    final appState = context.read<AppState>();
    final character = _character;
    final isSelected = appState.selectedCharacterIndex == _focused;
    final isUnlocked = appState.isCharacterUnlocked(character);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CharacterInspectionModal(
        character: character,
        isSelected: isSelected,
        isUnlocked: isUnlocked,
        playerLevel: appState.level,
        idleAnimation: _idleAnimation,
        onChoose: () {
          Navigator.of(ctx).pop();
          _onPrimary();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final character = _character;
    final unlocked = appState.isCharacterUnlocked(character);
    final isSelected = appState.selectedCharacterIndex == _focused;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RepaintBoundary(
        key: const ValueKey('character-select-screen'),
        child: Scaffold(
          backgroundColor: const Color(0xFF11132E),
          resizeToAvoidBottomInset: false,
          body: Stack(fit: StackFit.expand, children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Image.asset('assets/ui/bg_main.webp', fit: BoxFit.cover),
            ),
            const DecoratedBox(
                decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x6633295D),
                    Color(0x8A35315F),
                    Color(0xE60D1029)
                  ],
                  stops: [
                    0,
                    .55,
                    1
                  ]),
            )),
            SafeArea(child: LayoutBuilder(builder: (context, area) {
              final compact = area.maxWidth > area.maxHeight;
              final stage = _HeroStage(
                character: character,
                unlocked: unlocked,
                isSelected: isSelected,
                playerLevel: appState.level,
                idleAnimation: _idleAnimation,
                onInspect: _openCharacterInspection,
                compact: compact,
                stageHeight:
                    compact ? 160 : (area.maxHeight * .24).clamp(156, 300),
              );
              final rail = _CharacterRail(
                appState: appState,
                focused: _focused,
                compact: compact,
                onTap: (index) {
                  HapticFeedback.selectionClick();
                  setState(() => _focused = index);
                },
              );
              return Column(children: [
                _TopBar(
                    forced: widget.forced,
                    appState: appState,
                    compact: compact),
                if (!compact) const _ScreenHeader(),
                Expanded(
                  child: compact
                      ? Row(children: [
                          rail,
                          Expanded(
                              child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 6, 8, 8),
                            child: LayoutBuilder(
                                builder: (context, body) => Center(
                                      child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: SizedBox(
                                              width: body.maxWidth,
                                              child: stage)),
                                    )),
                          )),
                        ])
                      : LayoutBuilder(
                          builder: (context, body) => SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 10),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                      minHeight: (body.maxHeight - 20)
                                          .clamp(0, double.infinity)),
                                  child: Center(
                                      child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 760),
                                    child: stage,
                                  )),
                                ),
                              )),
                ),
                if (!compact) rail,
                _ActionBar(
                  forced: widget.forced,
                  busy: _busy,
                  character: character,
                  unlocked: unlocked,
                  isSelected: isSelected,
                  onPressed: _onPrimary,
                  onInspect: _openCharacterInspection,
                ),
              ]);
            })),
          ]),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar(
      {required this.forced, required this.appState, this.compact = false});

  final bool forced;
  final AppState appState;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          if (!forced)
            _CircleIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'رجوع',
              onTap: () => Navigator.of(context).maybePop(),
            )
          else
            const SizedBox(width: 42),
          if (compact)
            const Expanded(child: _ScreenHeader(compact: true))
          else
            const Spacer(),
          _CurrencyPill(
            icon: Icons.monetization_on_rounded,
            value: _compactNumber(appState.coins),
            color: const Color(0xFFFACC15),
            label: 'كوين',
          ),
          const SizedBox(width: 8),
          _CurrencyPill(
            icon: Icons.diamond_rounded,
            value: _compactNumber(appState.gems),
            color: const Color(0xFF38BDF8),
            label: 'جوهرة',
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _CurrencyPill extends StatelessWidget {
  const _CurrencyPill({
    required this.icon,
    required this.value,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final String value;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF091328).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'اختر شخصيتك وتألق',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFFFFD99C),
              fontSize: compact ? 17 : 23,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              shadows: const [
                Shadow(
                    color: Color(0xFF614022),
                    offset: Offset(0, 2),
                    blurRadius: 3)
              ],
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 4),
            const Text(
              'شخصيتك تمثلك في كل أطوار اللعب والتحديات المباشرة',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Main Hero Stage Showcase
// ─────────────────────────────────────────────────────────────────────────────

class _HeroStage extends StatelessWidget {
  const _HeroStage({
    required this.character,
    required this.unlocked,
    required this.isSelected,
    required this.playerLevel,
    required this.idleAnimation,
    required this.onInspect,
    this.compact = false,
    this.stageHeight = 200,
  });
  final GameCharacter character;
  final bool unlocked;
  final bool isSelected;
  final int playerLevel;
  final Animation<double> idleAnimation;
  final VoidCallback onInspect;
  final bool compact;
  final double stageHeight;
  static const _violet = Color(0xFFB69AFA);

  @override
  Widget build(BuildContext context) {
    final badges = Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 5,
      children: [
        _TagBadge(label: character.tagAr, color: _violet),
        if (isSelected) const _SelectedBadge(),
        if (!compact) _InspectBadge(accent: _violet, onTap: onInspect),
      ],
    );
    final stage = Semantics(
      button: true,
      label: 'استعراض شخصية ${character.nameAr}',
      child: InkWell(
        onTap: onInspect,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
            height: stageHeight,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _StageBody(
                key: ValueKey(character.index),
                character: character,
                unlocked: unlocked,
                idleAnimation: idleAnimation,
              ),
            )),
      ),
    );
    final name = Text(character.nameAr,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Color(0xFFB986FF), blurRadius: 14)]));
    final details = Column(mainAxisSize: MainAxisSize.min, children: [
      if (compact) ...[badges, const SizedBox(height: 6)],
      name,
      const SizedBox(height: 8),
      _MiniStatRow(character: character),
      const SizedBox(height: 6),
      const Text('سمات وصفية للشخصية؛ قواعد اللعب متساوية للجميع.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFBDB8D6), fontSize: 10)),
      const SizedBox(height: 10),
      _HeroStatusBanner(
          character: character,
          unlocked: unlocked,
          isSelected: isSelected,
          playerLevel: playerLevel),
    ]);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFC4B7FA), Color(0xFF7166AC), Color(0xFFA69AE1)]),
        boxShadow: const [
          BoxShadow(color: Color(0x5C8C60E4), blurRadius: 30, spreadRadius: 1)
        ],
      ),
      child: Container(
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(27),
          border:
              Border.all(color: const Color(0xFFDBCBFF).withValues(alpha: .6)),
          gradient: const RadialGradient(
              center: Alignment(0, -.3),
              radius: 1.2,
              colors: [
                Color(0xF23A304F),
                Color(0xF0202446),
                Color(0xF02B224B)
              ]),
        ),
        child: compact
            ? Row(children: [
                Expanded(flex: 3, child: details),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: stage)
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                badges,
                const SizedBox(height: 10),
                stage,
                const SizedBox(height: 6),
                details
              ]),
      ),
    );
  }
}

class _StageBody extends StatelessWidget {
  const _StageBody(
      {super.key,
      required this.character,
      required this.unlocked,
      required this.idleAnimation});
  final GameCharacter character;
  final bool unlocked;
  final Animation<double> idleAnimation;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, area) {
        final width = (area.maxHeight * .95).clamp(110.0, area.maxWidth);
        return Stack(alignment: Alignment.center, children: [
          Positioned.fill(
              child: DecoratedBox(
                  decoration: BoxDecoration(
            gradient: RadialGradient(
                center: const Alignment(0, .65),
                radius: .65,
                colors: [
                  const Color(0xFFAD53F1).withValues(alpha: .5),
                  Colors.transparent
                ]),
          ))),
          Positioned(
              bottom: 0,
              child: SizedBox(
                  width: width,
                  height: area.maxHeight * .26,
                  child: const CustomPaint(painter: _ShowcasePodium()))),
          Positioned.fill(
            bottom: area.maxHeight * .16,
            child: AnimatedBuilder(
              animation: idleAnimation,
              child: _FullBodyImage(character: character, dimmed: false),
              builder: (context, child) => Transform.translate(
                offset: Offset(
                    0,
                    MediaQuery.disableAnimationsOf(context)
                        ? 0
                        : -3 * idleAnimation.value),
                child: child,
              ),
            ),
          ),
        ]);
      });
}

class _ShowcasePodium extends CustomPainter {
  const _ShowcasePodium();
  @override
  void paint(Canvas canvas, Size size) {
    for (var tier = 0; tier < 3; tier++) {
      final inset = tier * size.width * .065;
      final top = size.height * (.40 - tier * .15);
      final rect =
          Rect.fromLTWH(inset, top, size.width - 2 * inset, size.height * .58);
      canvas.drawOval(rect.shift(const Offset(0, 5)),
          Paint()..color = const Color(0xFF0C0822));
      canvas.drawOval(
          rect,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFDED0FF), Color(0xFF8E46D8), Color(0xFF39205F)],
            ).createShader(rect));
      final rim = Rect.fromLTWH(inset, top, rect.width, size.height * .37);
      canvas.drawOval(
          rim,
          Paint()
            ..color = const Color(0xFFBE63FF)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
      canvas.drawOval(
          rim,
          Paint()
            ..shader = const RadialGradient(
                    colors: [Color(0xFFB37DF1), Color(0xFF8B3EC6)])
                .createShader(rim));
      canvas.drawOval(
          rim.deflate(3),
          Paint()
            ..color = const Color(0xFFF4D8FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_ShowcasePodium oldDelegate) => false;
}

class _FullBodyImage extends StatelessWidget {
  const _FullBodyImage({
    required this.character,
    required this.dimmed,
  });

  final GameCharacter character;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      character.fullBodyAsset,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Image.asset(
        character.asset,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.person_rounded,
          color: character.color,
          size: 90,
        ),
      ),
    );

    if (dimmed) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          0.65,
          0,
        ]),
        child: image,
      );
    }

    return image;
  }
}

class _MiniStatRow extends StatelessWidget {
  const _MiniStatRow({required this.character});

  final GameCharacter character;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _MiniStatPill(
                icon: Icons.bolt_rounded,
                label: 'السرعة',
                value: '${character.speed}%',
                color: const Color(0xFFFBBF24),
              ),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _MiniStatPill(
                icon: Icons.auto_stories_rounded,
                label: 'المعرفة',
                value: '${character.knowledge}%',
                color: const Color(0xFF60A5FA),
              ),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _MiniStatPill(
                icon: Icons.crisis_alert_rounded,
                label: 'التركيز',
                value: '${character.focus}%',
                color: const Color(0xFF34D399),
              ),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _MiniStatPill(
                icon: Icons.military_tech_rounded,
                label: 'الثقة',
                value: '${character.confidence}%',
                color: const Color(0xFFF472B6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatPill extends StatelessWidget {
  const _MiniStatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          '$label $value',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge();

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF34D399);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: green.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: green.withValues(alpha: 0.6)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: green, size: 14),
          SizedBox(width: 5),
          Text(
            'شخصيتك الحالية',
            style: TextStyle(
              color: green,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectBadge extends StatelessWidget {
  const _InspectBadge({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.zoom_in_rounded, color: Colors.white, size: 15),
              SizedBox(width: 4),
              Text(
                'استعراض',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroStatusBanner extends StatelessWidget {
  const _HeroStatusBanner({
    required this.character,
    required this.unlocked,
    required this.isSelected,
    required this.playerLevel,
  });

  final GameCharacter character;
  final bool unlocked;
  final bool isSelected;
  final int playerLevel;

  @override
  Widget build(BuildContext context) {
    if (unlocked) {
      return _StatusContainer(
        icon: isSelected ? Icons.verified_rounded : Icons.check_circle_rounded,
        color: const Color(0xFF34D399),
        title: isSelected ? 'شخصيتك المعتمدة' : 'متاحة للعب فورًا',
        subtitle: isSelected
            ? 'تشارك معك في التحديات الفردية والجماعية'
            : 'اضغط اختيار بالأسفل لتفعيلها لشخصيتك',
      );
    }

    switch (character.unlock.kind) {
      case CharacterUnlockKind.level:
        final progress = (playerLevel / character.unlock.value).clamp(0.0, 1.0);
        return _StatusContainer(
          icon: Icons.lock_clock_rounded,
          color: const Color(0xFF60A5FA),
          title: 'تُفتح عند المستوى ${character.unlock.value}',
          subtitle:
              'مستواك الحالي: $playerLevel (${(progress * 100).toInt()}%)',
          trailing: SizedBox(
            width: 70,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF60A5FA)),
                minHeight: 6,
              ),
            ),
          ),
        );
      case CharacterUnlockKind.coins:
        return _StatusContainer(
          icon: Icons.monetization_on_rounded,
          color: const Color(0xFFFACC15),
          title: '${_compactNumber(character.unlock.value)} كوين',
          subtitle: 'فتح دائم لجميع أطوار اللعب',
        );
      case CharacterUnlockKind.gems:
        return _StatusContainer(
          icon: Icons.diamond_rounded,
          color: const Color(0xFF38BDF8),
          title: '${_compactNumber(character.unlock.value)} جوهرة',
          subtitle: 'فتح دائم لشخصية مميزة ونادرة',
        );
      case CharacterUnlockKind.free:
        return const _StatusContainer(
          icon: Icons.check_circle_rounded,
          color: Color(0xFF34D399),
          title: 'متاحة مجانًا',
          subtitle: 'جاهزة للاختيار واللعب',
        );
    }
  }
}

class _StatusContainer extends StatelessWidget {
  const _StatusContainer({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Interactive Full Character Inspection Modal
// ─────────────────────────────────────────────────────────────────────────────

class _CharacterInspectionModal extends StatefulWidget {
  const _CharacterInspectionModal({
    required this.character,
    required this.isSelected,
    required this.isUnlocked,
    required this.playerLevel,
    required this.idleAnimation,
    required this.onChoose,
  });

  final GameCharacter character;
  final bool isSelected;
  final bool isUnlocked;
  final int playerLevel;
  final Animation<double> idleAnimation;
  final VoidCallback onChoose;

  @override
  State<_CharacterInspectionModal> createState() =>
      _CharacterInspectionModalState();
}

class _CharacterInspectionModalState extends State<_CharacterInspectionModal> {
  int _activeTab = 0; // 0: Stats & Bio, 1: In-game Appearance

  @override
  Widget build(BuildContext context) {
    final character = widget.character;
    final accent = character.color;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.88,
        decoration: BoxDecoration(
          color: const Color(0xFF070E1F),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(
            color: accent.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.25),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Modal grab handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),

            // Modal Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.2),
                      border: Border.all(color: accent, width: 1.5),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: ClipOval(
                      child: Image.asset(character.asset, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'استعراض المتسابق: ${character.nameAr}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          character.tagAr,
                          style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CircleIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'إغلاق',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab Switcher
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      label: 'المهارات والبيانات',
                      icon: Icons.analytics_rounded,
                      isActive: _activeTab == 0,
                      accent: accent,
                      onTap: () => setState(() => _activeTab = 0),
                    ),
                  ),
                  Expanded(
                    child: _TabButton(
                      label: 'المظهر في اللعبة',
                      icon: Icons.visibility_rounded,
                      isActive: _activeTab == 1,
                      accent: accent,
                      onTap: () => setState(() => _activeTab = 1),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tab Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _activeTab == 0
                    ? _buildBioTab(character, accent)
                    : _buildAppearanceTab(character, accent),
              ),
            ),

            // Bottom CTA inside Modal
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: widget.onChoose,
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.isSelected
                        ? const Color(0xFF059669)
                        : (widget.isUnlocked
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF2563EB)),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.isSelected
                            ? Icons.check_circle_rounded
                            : (widget.isUnlocked
                                ? Icons.play_arrow_rounded
                                : Icons.lock_open_rounded),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.isSelected
                            ? 'هذه شخصيتك الحالية'
                            : (widget.isUnlocked
                                ? 'تأكيد واختيار ${character.nameAr}'
                                : 'فتح الشخصية وتفعيلها'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBioTab(GameCharacter character, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Center Stage Preview
        Center(
          child: SizedBox(
            height: 170,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: 140,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: accent.withValues(alpha: 0.25),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.4),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                _FullBodyImage(
                  character: character,
                  dimmed: !widget.isUnlocked,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Character Quote Card
        if (character.quoteAr.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.format_quote_rounded, color: accent, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '"${character.quoteAr}"',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 14),

        // Biography Section
        const Text(
          'نبذة عن المتسابق',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          character.bioAr.isNotEmpty
              ? character.bioAr
              : 'متسابق متميز ومشارك في مسابقة أرض التحدي.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 13,
            height: 1.55,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 18),

        // Skill Breakdown Section
        const Text(
          'المهارات والقدرات',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        const Text('هذه سمات وصفية للاستعراض ولا تمنح أفضلية في المباراة.',
            style: TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 10),

        _SkillBar(
          title: 'سرعة البديهة وردود الفعل',
          value: character.speed,
          color: const Color(0xFFFBBF24),
          icon: Icons.bolt_rounded,
        ),
        const SizedBox(height: 10),
        _SkillBar(
          title: 'المعرفة العامة والعلوم',
          value: character.knowledge,
          color: const Color(0xFF60A5FA),
          icon: Icons.auto_stories_rounded,
        ),
        const SizedBox(height: 10),
        _SkillBar(
          title: 'الهدوء والتركيز تحت الضغط',
          value: character.focus,
          color: const Color(0xFF34D399),
          icon: Icons.crisis_alert_rounded,
        ),
        const SizedBox(height: 10),
        _SkillBar(
          title: 'الثقة وحضور المنصة',
          value: character.confidence,
          color: const Color(0xFFF472B6),
          icon: Icons.military_tech_rounded,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAppearanceTab(GameCharacter character, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'معاينة ظهور الشخصية أثناء اللعب',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'هكذا ستبدو شخصيتك في منصة التحدي وقوائم المتصدرين:',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12.5,
          ),
        ),

        const SizedBox(height: 16),

        // In-game Match Podium Mockup
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1B35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              const Text(
                'منصة مسرح المسابقة',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.2),
                      border: Border.all(color: accent, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(6),
                    child: ClipOval(
                      child: Image.asset(character.asset, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        character.nameAr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          character.tagAr,
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: Colors.amber, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'النتيجة: 1,000,000 نقطة',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Leaderboard Row Mockup
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0C172E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber,
                ),
                child: const Text(
                  '1',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 18,
                backgroundColor: accent.withValues(alpha: 0.25),
                backgroundImage: AssetImage(character.asset),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أنت (${character.nameAr})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'متصدر قائمة الأبطال',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.emoji_events_rounded,
                      color: Colors.amber, size: 18),
                  SizedBox(width: 4),
                  Text(
                    'المركز الأول',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? accent.withValues(alpha: 0.28) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? accent : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : Colors.white60,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white60,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillBar extends StatelessWidget {
  const _SkillBar({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '$value%',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value / 100.0,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 7,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Character Roster Carousel Rail
// ─────────────────────────────────────────────────────────────────────────────

class _CharacterRail extends StatefulWidget {
  const _CharacterRail({
    required this.appState,
    required this.focused,
    required this.onTap,
    this.compact = false,
  });

  final AppState appState;
  final int focused;
  final ValueChanged<int> onTap;
  final bool compact;

  @override
  State<_CharacterRail> createState() => _CharacterRailState();
}

class _CharacterRailState extends State<_CharacterRail> {
  static const double _itemExtent = 84;
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerFocused(false));
  }

  @override
  void didUpdateWidget(covariant _CharacterRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focused != widget.focused) _centerFocused(true);
  }

  void _centerFocused(bool animate) {
    if (!_controller.hasClients) return;
    final position = _railPosition(widget.focused);
    final viewport = _controller.position.viewportDimension;
    final target =
        (position * _itemExtent) - (viewport / 2) + (_itemExtent / 2);
    final clamped =
        target.clamp(0.0, _controller.position.maxScrollExtent).toDouble();
    if (animate) {
      _controller.animateTo(
        clamped,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _controller.jumpTo(clamped);
    }
  }

  int _railPosition(int characterIndex) {
    for (var i = 0; i < CharacterCatalog.all.length; i += 1) {
      if (CharacterCatalog.all[i].index == characterIndex) return i;
    }
    return 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.compact ? 80 : null,
      height: widget.compact ? null : 108,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: _controller,
            scrollDirection: widget.compact ? Axis.vertical : Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: widget.compact
                  ? BoxConstraints(minHeight: constraints.maxHeight)
                  : BoxConstraints(minWidth: constraints.maxWidth),
              child: Flex(
                direction: widget.compact ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final character in CharacterCatalog.all)
                    SizedBox(
                      width: widget.compact ? 80 : _itemExtent,
                      height: widget.compact ? _itemExtent : null,
                      child: _RailItem(
                        key: ValueKey('character-rail-${character.id}'),
                        character: character,
                        unlocked:
                            widget.appState.isCharacterUnlocked(character),
                        isSelected: widget.appState.selectedCharacterIndex ==
                            character.index,
                        isFocused: widget.focused == character.index,
                        compact: widget.compact,
                        onTap: () => widget.onTap(character.index),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    super.key,
    required this.character,
    required this.unlocked,
    required this.isSelected,
    required this.isFocused,
    required this.onTap,
    this.compact = false,
  });

  final GameCharacter character;
  final bool unlocked;
  final bool isSelected;
  final bool isFocused;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ringColor = isFocused
        ? const Color(0xFFBE93FF)
        : isSelected
            ? const Color(0xFF34D399)
            : Colors.white.withValues(alpha: 0.16);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: compact ? 44 : (isFocused ? 62 : 52),
            height: compact ? 44 : (isFocused ? 62 : 52),
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF09142A),
              border: Border.all(
                color: ringColor,
                width: isFocused ? 2.5 : 1.4,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: const Color(0xFFBE93FF).withValues(alpha: 0.6),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child: Image.asset(
                    character.asset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person_rounded,
                      color: Colors.white38,
                    ),
                  ),
                ),
                if (!unlocked)
                  Positioned(
                    bottom: -3,
                    child: _RailLockChip(character: character),
                  ),
                if (isSelected)
                  const Positioned(
                    top: -4,
                    right: -4,
                    child: _SelectedTick(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            character.nameAr,
            style: TextStyle(
              color: isFocused ? Colors.white : Colors.white60,
              fontSize: 11.5,
              fontWeight: isFocused ? FontWeight.w900 : FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SelectedTick extends StatelessWidget {
  const _SelectedTick();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF05172C),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF34D399), width: 1.6),
        boxShadow: const [
          BoxShadow(color: Color(0xFF34D399), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: const Icon(
        Icons.check_rounded,
        color: Color(0xFF34D399),
        size: 11,
      ),
    );
  }
}

class _RailLockChip extends StatelessWidget {
  const _RailLockChip({required this.character});

  final GameCharacter character;

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final String label;
    late final Color color;
    switch (character.unlock.kind) {
      case CharacterUnlockKind.level:
        icon = Icons.lock_rounded;
        label = '${character.unlock.value}';
        color = const Color(0xFF93C5FD);
        break;
      case CharacterUnlockKind.coins:
        icon = Icons.monetization_on_rounded;
        label = _compactNumber(character.unlock.value);
        color = const Color(0xFFFACC15);
        break;
      case CharacterUnlockKind.gems:
        icon = Icons.diamond_rounded;
        label = _compactNumber(character.unlock.value);
        color = const Color(0xFF38BDF8);
        break;
      case CharacterUnlockKind.free:
        icon = Icons.check_rounded;
        label = '';
        color = const Color(0xFF34D399);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 9),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Primary Action Bar
// ─────────────────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.forced,
    required this.busy,
    required this.character,
    required this.unlocked,
    required this.isSelected,
    required this.onPressed,
    required this.onInspect,
  });

  final bool forced;
  final bool busy;
  final GameCharacter character;
  final bool unlocked;
  final bool isSelected;
  final VoidCallback onPressed;
  final VoidCallback onInspect;

  @override
  Widget build(BuildContext context) {
    final bool levelLocked = !unlocked && character.unlock.isLevelGated;

    String label;
    IconData icon;
    List<Color> gradient;

    if (!unlocked && character.unlock.isPurchasable) {
      final isCoins = character.unlock.kind == CharacterUnlockKind.coins;
      label =
          'فتح وتفعيل (${_compactNumber(character.unlock.value)} ${isCoins ? 'كوين' : 'جوهرة'})';
      icon = Icons.lock_open_rounded;
      gradient = const [Color(0xFFFACC15), Color(0xFFF59E0B)];
    } else if (levelLocked) {
      label = 'تُفتح عند المستوى ${character.unlock.value}';
      icon = Icons.lock_rounded;
      gradient = const [Color(0xFF374151), Color(0xFF1F2937)];
    } else if (isSelected) {
      label = forced ? 'ابدأ اللعب' : 'شخصيتك الحالية (تم الاختيار)';
      icon = forced ? Icons.play_arrow_rounded : Icons.check_circle_rounded;
      gradient = const [
        Color(0xFF22CDA3),
        Color(0xFF087E69),
        Color(0xFF075B54)
      ];
    } else {
      label = forced ? 'اختيار وبدء اللعب' : 'اختيار ${character.nameAr}';
      icon = Icons.check_rounded;
      gradient = const [
        Color(0xFF22CDA3),
        Color(0xFF087E69),
        Color(0xFF075B54)
      ];
    }

    final enabled = !busy && !levelLocked;
    final dark = gradient.first.computeLuminance() > 0.5;
    final fg = dark ? const Color(0xFF111827) : Colors.white;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF101328).withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          // Dedicated Inspect button
          Tooltip(
            message: 'استعراض كامل للتفاصيل',
            child: Material(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: onInspect,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF9A76DA).withValues(alpha: 0.7),
                    ),
                  ),
                  child: const Icon(
                    Icons.zoom_in_rounded,
                    color: Color(0xFFB48BF5),
                    size: 26,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Primary Select/Unlock button
          Expanded(
            child: Opacity(
              opacity: enabled ? 1.0 : 0.55,
              child: GestureDetector(
                onTap: enabled ? onPressed : null,
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: const Color(0xFFE5BE79), width: 2.5),
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: gradient),
                    boxShadow: enabled
                        ? [
                            BoxShadow(
                              color: gradient.first.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: busy
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: fg,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, color: fg, size: 22),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: fg,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _compactNumber(int value) {
  final abs = value.abs();
  if (abs >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value.abs() >= 10000000 ? 0 : 1)}M';
  }
  if (abs >= 1000) {
    return '${(value / 1000).toStringAsFixed(value.abs() >= 10000 ? 0 : 1)}K';
  }
  return '$value';
}
