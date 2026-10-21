import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../models/game_character.dart';
import '../../models/store_catalog.dart';
import '../home/store_screen.dart';
import '../../widgets/adaptive_asset_image.dart';
import '../../widgets/synchronized_character_animation.dart';

/// Character picker and showcase screen matching the dressing room studio
/// reference with standing mirror reflection, 3D golden title, and neon character grid.
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
      _showSnack('تهانينا! تم فتح الشخصية بنجاح 🎉');
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
          backgroundColor: const Color(0xFF140D2B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(
              color: Color(0xFFFFD54F),
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
                    color: const Color(0xFFFFD54F),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66FFD54F),
                      blurRadius: 16,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: ClipOval(
                  child:
                      adaptiveAssetImage(character.asset, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'فتح الشخصية',
                textAlign: TextAlign.center,
                style: TextStyle(
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
          backgroundColor: const Color(0xFF0F0B24),
          resizeToAvoidBottomInset: false,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Studio dressing room background with mirror
              Positioned.fill(
                child: LayoutBuilder(builder: (context, constraints) {
                  if (constraints.maxWidth < constraints.maxHeight) {
                    return const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF241344), Color(0xFF11132E)],
                        ),
                      ),
                    );
                  }
                  return adaptiveAssetImage(
                    'assets/ui/character_select_room.webp',
                    fit: BoxFit.fill,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF261447), Color(0xFF0F0824)],
                        ),
                      ),
                    ),
                  );
                }),
              ),

              // Main content
              LayoutBuilder(
                builder: (context, area) {
                  final isLandscape = area.maxWidth > area.maxHeight;

                  if (isLandscape) {
                    return _buildLandscapeLayout(
                      appState: appState,
                      character: character,
                      unlocked: unlocked,
                      isSelected: isSelected,
                      area: area,
                    );
                  } else {
                    return _buildPortraitLayout(
                      appState: appState,
                      character: character,
                      unlocked: unlocked,
                      isSelected: isSelected,
                      area: area,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout({
    required AppState appState,
    required GameCharacter character,
    required bool unlocked,
    required bool isSelected,
    required BoxConstraints area,
  }) {
    final compact = area.maxHeight < 400;
    final width = area.maxWidth;
    final height = area.maxHeight;

    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: width * 0.44,
          child: _MirrorCharacterStage(
            character: character,
            idleAnimation: _idleAnimation,
            onInspect: _openCharacterInspection,
          ),
        ),
        Positioned(
          left: width * 0.475,
          right: width * 0.065,
          top: height * 0.09,
          height: height * 0.235,
          child: _TitleHeader(height: height * 0.235),
        ),
        Positioned(
          left: width * 0.472,
          right: width * 0.062,
          top: height * 0.335,
          bottom: height * 0.15,
          child: _CharacterGrid(
            appState: appState,
            focused: _focused,
            compact: compact,
            onTap: (index) {
              HapticFeedback.selectionClick();
              setState(() => _focused = index);
            },
          ),
        ),
        Positioned(
          left: width * 0.475,
          right: width * 0.065,
          bottom: height * 0.035,
          height: height * 0.105,
          child: _ActionBar(
            forced: widget.forced,
            busy: _busy,
            character: character,
            unlocked: unlocked,
            isSelected: isSelected,
            compact: true,
            onPressed: _onPrimary,
            onInspect: _openCharacterInspection,
          ),
        ),
        Positioned(
          left: width * 0.04,
          right: width * 0.04,
          top: height * 0.035,
          child: _TopBar(
            forced: widget.forced,
            appState: appState,
            compact: true,
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout({
    required AppState appState,
    required GameCharacter character,
    required bool unlocked,
    required bool isSelected,
    required BoxConstraints area,
  }) {
    return Column(
      children: [
        _TopBar(
          forced: widget.forced,
          appState: appState,
          compact: false,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: _TitleHeader(height: 38),
        ),
        Expanded(
          flex: 4,
          child: _MirrorCharacterStage(
            character: character,
            showRoom: true,
            idleAnimation: _idleAnimation,
            onInspect: _openCharacterInspection,
          ),
        ),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _CharacterGrid(
              appState: appState,
              focused: _focused,
              compact: false,
              onTap: (index) {
                HapticFeedback.selectionClick();
                setState(() => _focused = index);
              },
            ),
          ),
        ),
        _ActionBar(
          forced: widget.forced,
          busy: _busy,
          character: character,
          unlocked: unlocked,
          isSelected: isSelected,
          onPressed: _onPrimary,
          onInspect: _openCharacterInspection,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.forced,
    required this.appState,
    this.compact = false,
  });

  final bool forced;
  final AppState appState;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 2 : 6, 16, compact ? 2 : 4),
      child: Row(
        children: [
          if (!forced)
            _CircleIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'رجوع',
              size: compact ? 34 : 40,
              onTap: () => Navigator.of(context).maybePop(),
            )
          else
            SizedBox(width: compact ? 34 : 42),
          const Spacer(),
          _CurrencyPill(
            icon: Icons.monetization_on_rounded,
            value: _compactNumber(appState.coins),
            color: const Color(0xFFFACC15),
            label: 'كوين',
            compact: compact,
          ),
          const SizedBox(width: 8),
          _CurrencyPill(
            icon: Icons.diamond_rounded,
            value: _compactNumber(appState.gems),
            color: const Color(0xFF38BDF8),
            label: 'جوهرة',
            compact: compact,
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
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: const Color(0xFF261447).withValues(alpha: 0.7),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                width: 1.4,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4400E5FF),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.55),
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
    this.compact = false,
  });

  final IconData icon;
  final String value;
  final Color color;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF140D2B).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: compact ? 14 : 16),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3D Title Header
// ─────────────────────────────────────────────────────────────────────────────

class _TitleHeader extends StatelessWidget {
  const _TitleHeader({this.height = 44});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: adaptiveAssetImage(
        'assets/ui/character_select_title.png',
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Text(
          'اختر شخصيتك',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'NotoSansArabic',
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Color(0xFFFFD54F),
            shadows: [
              Shadow(
                color: Color(0xFFD84315),
                offset: Offset(0, 3),
                blurRadius: 4,
              ),
              Shadow(
                color: Color(0x88FFA000),
                offset: Offset(0, 0),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mirror Stage (Character Standing & Mirror Reflection)
// ─────────────────────────────────────────────────────────────────────────────

class _MirrorCharacterStage extends StatelessWidget {
  const _MirrorCharacterStage({
    required this.character,
    required this.idleAnimation,
    required this.onInspect,
    this.showRoom = false,
  });

  final GameCharacter character;
  final Animation<double> idleAnimation;
  final VoidCallback onInspect;
  final bool showRoom;

  @override
  Widget build(BuildContext context) {
    return SynchronizedCharacterAnimation(
      character: character,
      fallback: (key, {bool reflected = false}) => AnimatedBuilder(
        key: key,
        animation: idleAnimation,
        child: _FullBodyImage(character: character, dimmed: false),
        builder: (context, child) => Transform.scale(
          alignment: Alignment.bottomCenter,
          scale: MediaQuery.disableAnimationsOf(context)
              ? 1
              : 1 + idleAnimation.value * 0.006,
          child: child,
        ),
      ),
      builder: (context, frame) =>
          LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Semantics(
          button: true,
          label: 'استعراض الشخصية',
          child: GestureDetector(
            onTap: onInspect,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (showRoom)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: width / 0.44,
                    child: adaptiveAssetImage(
                      'assets/ui/character_select_room.webp',
                      fit: BoxFit.fill,
                    ),
                  ),
                // Match the glass quadrilateral, so every reflection stays
                // inside the wooden frame at every screen size.
                Positioned.fill(
                  child: ClipPath(
                    clipper: const _MirrorGlassClipper(),
                    child: Stack(
                      children: [
                        Positioned(
                          left: width * 0.53,
                          top: height * 0.17,
                          width: width * 0.30,
                          height: height * 0.68,
                          child: ExcludeSemantics(
                            child: Opacity(
                              opacity: 0.68,
                              child: ColorFiltered(
                                colorFilter: const ColorFilter.mode(
                                    Color(0x668ABEFF), BlendMode.srcATop),
                                child: Transform.rotate(
                                  angle: 0.075,
                                  child: Transform(
                                    alignment: Alignment.center,
                                    transform:
                                        Matrix4.diagonal3Values(-1, 1, 1),
                                    child: frame(
                                        const ValueKey(
                                            'character-mirror-reflection'),
                                        reflected: true),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: width * 0.52,
                          top: height * 0.13,
                          width: width * 0.36,
                          height: height * 0.74,
                          child: const IgnorePointer(
                            child: _MirrorSparklesOverlay(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: width * 0.095,
                  bottom: height * 0.07,
                  width: width * 0.40,
                  height: height * 0.82,
                  child: frame(const ValueKey('character-standing-preview')),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _MirrorGlassClipper extends CustomClipper<Path> {
  const _MirrorGlassClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * 0.584, size.height * 0.141)
    ..lineTo(size.width * 0.877, size.height * 0.117)
    ..lineTo(size.width * 0.812, size.height * 0.865)
    ..lineTo(size.width * 0.525, size.height * 0.827)
    ..close();

  @override
  bool shouldReclip(_MirrorGlassClipper oldClipper) => false;
}

class _MirrorSparklesOverlay extends StatelessWidget {
  const _MirrorSparklesOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklesPainter(),
      size: Size.infinite,
    );
  }
}

class _SparklesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sparkles = [
      (0.20, 0.22, 4.0, const Color(0xFFFFFFFF)),
      (0.35, 0.38, 5.5, const Color(0xFF80D8FF)),
      (0.68, 0.18, 5.0, const Color(0xFFFFD54F)),
      (0.78, 0.42, 6.0, const Color(0xFFFFFFFF)),
      (0.48, 0.55, 4.5, const Color(0xFF80D8FF)),
      (0.22, 0.68, 5.0, const Color(0xFFFFE082)),
      (0.65, 0.75, 4.0, const Color(0xFFFFFFFF)),
      (0.42, 0.82, 6.0, const Color(0xFF80D8FF)),
    ];

    for (final s in sparkles) {
      final center = Offset(s.$1 * size.width, s.$2 * size.height);
      final r = s.$3;
      final color = s.$4;

      // Outer glow
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(center, r * 1.5, glowPaint);

      // 4-pointed diamond star
      final starPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final path = Path();
      path.moveTo(center.dx, center.dy - r);
      path.quadraticBezierTo(center.dx, center.dy, center.dx + r, center.dy);
      path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + r);
      path.quadraticBezierTo(center.dx, center.dy, center.dx - r, center.dy);
      path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - r);
      path.close();
      canvas.drawPath(path, starPaint);

      // Core bright center
      final corePaint = Paint()..color = Colors.white;
      canvas.drawCircle(center, r * 0.25, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    Widget image = adaptiveAssetImage(
      character.fullBodyAsset,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => adaptiveAssetImage(
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

// ─────────────────────────────────────────────────────────────────────────────
// 2-Row Character Avatar Cards Grid
// ─────────────────────────────────────────────────────────────────────────────

class _CharacterGrid extends StatefulWidget {
  const _CharacterGrid({
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
  State<_CharacterGrid> createState() => _CharacterGridState();
}

class _CharacterGridState extends State<_CharacterGrid> {
  final ScrollController _scrollController = ScrollController();
  bool _initialScrollPending = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Column order is visual right-to-left, starting with the reference faces.
    final characters = [
      for (final index in [
        4,
        3,
        1,
        5,
        0,
        2,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15
      ])
        CharacterCatalog.byIndex(index),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final gap = constraints.maxWidth * 0.035;
      final cardWidth = (constraints.maxWidth - gap * 2) / 3;
      final hintHeight = widget.compact ? 24.0 : 28.0;
      final cardHeight = (constraints.maxHeight - hintHeight - 4 - gap) / 2;
      if (_initialScrollPending) {
        _initialScrollPending = false;
        final column =
            characters.indexWhere((c) => c.index == widget.focused) ~/ 2;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          _scrollController.jumpTo(((column - 2) * (cardWidth + gap))
              .clamp(0.0, _scrollController.position.maxScrollExtent));
        });
      }
      return Column(
        children: [
          SizedBox(
            height: hintHeight,
            child: AnimatedBuilder(
              animation: _scrollController,
              builder: (context, _) {
                final attached = _scrollController.hasClients &&
                    _scrollController.position.hasContentDimensions;
                final extent =
                    attached ? _scrollController.position.maxScrollExtent : 0.0;
                final offset = attached ? _scrollController.offset : 0.0;
                final atEnd = attached && offset >= extent - 1;
                final pageCount = (characters.length / 6).ceil();
                final page = extent > 0
                    ? (offset.clamp(0.0, extent) / extent * (pageCount - 1))
                        .round()
                    : 0;
                return _CharacterScrollHint(
                  page: page,
                  pageCount: pageCount,
                  atEnd: atEnd,
                  onPage: (page) {
                    if (!_scrollController.hasClients) return;
                    HapticFeedback.selectionClick();
                    _scrollController.animateTo(
                      (page * 3 * (cardWidth + gap)).clamp(
                          0.0, _scrollController.position.maxScrollExtent),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('character-scroll-rail'),
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var column = 0;
                      column < (characters.length / 2).ceil();
                      column++)
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                          end: column == (characters.length / 2).ceil() - 1
                              ? 0
                              : gap),
                      child: Column(
                        children: [
                          for (var row = 0; row < 2; row++) ...[
                            if (row == 1) SizedBox(height: gap),
                            if (column * 2 + row < characters.length)
                              _CharacterCard(
                                key: ValueKey(
                                    'character-rail-${characters[column * 2 + row].id}'),
                                character: characters[column * 2 + row],
                                unlocked: widget.appState.isCharacterUnlocked(
                                    characters[column * 2 + row]),
                                isSelected:
                                    widget.appState.selectedCharacterIndex ==
                                        characters[column * 2 + row].index,
                                isFocused: widget.focused ==
                                    characters[column * 2 + row].index,
                                width: cardWidth,
                                height: cardHeight,
                                onTap: () => widget
                                    .onTap(characters[column * 2 + row].index),
                              ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _CharacterScrollHint extends StatelessWidget {
  const _CharacterScrollHint({
    required this.page,
    required this.pageCount,
    required this.atEnd,
    required this.onPage,
  });

  final int page;
  final int pageCount;
  final bool atEnd;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xCC211444),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x6658DFFF)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Semantics(
                  button: true,
                  child: GestureDetector(
                    key: const ValueKey('character-swipe-hint'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onPage(atEnd ? page - 1 : page + 1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          atEnd
                              ? Icons.arrow_back_rounded
                              : Icons.arrow_forward_rounded,
                          color: const Color(0xFF7BEAFF),
                          size: 18,
                          textDirection: TextDirection.ltr,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            atEnd ? 'اسحب لليسار للعودة' : 'اسحب لليمين للمزيد',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFE5F9FF),
                              fontSize: 11,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              for (var index = 0; index < pageCount; index++)
                Semantics(
                  button: true,
                  selected: page == index,
                  label: 'مجموعة الشخصيات ${index + 1} من $pageCount',
                  child: GestureDetector(
                    key: ValueKey('character-page-$index'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onPage(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: page == index ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: page == index
                              ? const Color(0xFF7BEAFF)
                              : const Color(0xFF72618E),
                          borderRadius: BorderRadius.circular(999),
                        ),
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
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    super.key,
    required this.character,
    required this.unlocked,
    required this.isSelected,
    required this.isFocused,
    required this.onTap,
    required this.width,
    required this.height,
  });

  final GameCharacter character;
  final bool unlocked;
  final bool isSelected;
  final bool isFocused;
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height * 0.095);
    final borderColor = isSelected
        ? const Color(0xFF76FF03)
        : isFocused
            ? const Color(0xFFFFD54F)
            : const Color(0xFFE16AFF);
    final badgeSize = (height * 0.27).clamp(18.0, 30.0);

    return Semantics(
      button: true,
      selected: isSelected,
      label: character.tagAr,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF64077E),
                  Color(0xFF360A69),
                  Color(0xFF230A50)
                ],
              ),
              border:
                  Border.all(color: borderColor, width: isSelected ? 3 : 2.5),
              boxShadow: [
                const BoxShadow(
                    color: Color(0xCC1A063F),
                    offset: Offset(0, 3),
                    blurRadius: 2),
                BoxShadow(
                  color:
                      borderColor.withValues(alpha: isSelected ? 0.65 : 0.22),
                  blurRadius: isSelected ? 9 : 3,
                  spreadRadius: isSelected ? 1 : 0,
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      minHeight: height * 2.85,
                      maxHeight: height * 2.85,
                      child: FractionalTranslation(
                        translation: const Offset(0, -0.02),
                        child: adaptiveAssetImage(
                          character.fullBodyAsset,
                          fit: BoxFit.fitHeight,
                          alignment: Alignment.topCenter,
                          errorBuilder: (_, __, ___) => adaptiveAssetImage(
                              character.asset,
                              fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    key: ValueKey('character-selected-${character.id}'),
                    top: -badgeSize * 0.25,
                    left: -badgeSize * 0.25,
                    child: Container(
                      width: badgeSize,
                      height: badgeSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF9EFF28), Color(0xFF08B51A)],
                        ),
                        border: Border.all(
                            color: const Color(0xFF176900), width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x99000000),
                              blurRadius: 3,
                              offset: Offset(0, 2))
                        ],
                      ),
                      child: Icon(Icons.check_rounded,
                          color: const Color(0xFF155E08),
                          size: badgeSize * 0.8),
                    ),
                  ),
                if (!unlocked)
                  Positioned(
                    bottom: 3,
                    left: 3,
                    child: _RailLockChip(character: character),
                  ),
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 8.5),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 8,
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
// Primary Action Bar & Controls
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
    this.compact = false,
  });

  final bool forced;
  final bool busy;
  final GameCharacter character;
  final bool unlocked;
  final bool isSelected;
  final VoidCallback onPressed;
  final VoidCallback onInspect;
  final bool compact;

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
      label = forced ? 'ابدأ اللعب' : 'شخصيتك الحالية';
      icon = forced ? Icons.play_arrow_rounded : Icons.check_circle_rounded;
      gradient = const [
        Color(0xFF22CDA3),
        Color(0xFF087E69),
        Color(0xFF075B54)
      ];
    } else {
      label = forced ? 'اختيار وبدء اللعب' : 'اختيار الشخصية';
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

    final btnHeight = compact ? 30.0 : 44.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 2, vertical: compact ? 2 : 4),
      child: Row(
        children: [
          // Tag badge
          Flexible(
            flex: 3,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: compact ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1F0E38).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFBA68C8).withValues(alpha: 0.6),
                ),
              ),
              child: Text(
                character.tagAr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFFE1BEE7),
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Dedicated Inspect button
          Tooltip(
            message: 'استعراض كامل للتفاصيل',
            child: Material(
              color: const Color(0xFF1F0E38).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onInspect,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: btnHeight,
                  height: btnHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFBA68C8).withValues(alpha: 0.7),
                    ),
                  ),
                  child: Icon(
                    Icons.zoom_in_rounded,
                    color: const Color(0xFFE1BEE7),
                    size: compact ? 20 : 24,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Primary Select/Unlock button
          Expanded(
            flex: 5,
            child: Opacity(
              opacity: enabled ? 1.0 : 0.55,
              child: GestureDetector(
                onTap: enabled ? onPressed : null,
                child: Container(
                  height: btnHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF76FF03)
                          : const Color(0xFFFFD54F),
                      width: 1.8,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: gradient,
                    ),
                    boxShadow: enabled
                        ? [
                            BoxShadow(
                              color: gradient.first.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: busy
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: fg,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, color: fg, size: compact ? 18 : 20),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: fg,
                                    fontSize: compact ? 13 : 14,
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

// ─────────────────────────────────────────────────────────────────────────────
// Interactive Full Character Inspection Modal
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
          color: const Color(0xFF0F0B24),
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
                      child: adaptiveAssetImage(character.asset,
                          fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'استعراض الشخصية',
                          style: TextStyle(
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TabButton(
                      label: 'المظهر في اللعبة',
                      icon: Icons.palette_rounded,
                      isActive: _activeTab == 1,
                      accent: accent,
                      onTap: () => setState(() => _activeTab = 1),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: _activeTab == 0
                  ? _buildSkillsAndBioTab(character)
                  : _buildAppearanceTab(character),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsAndBioTab(GameCharacter character) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bio Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.format_quote_rounded,
                        color: Color(0xFFFBBF24), size: 20),
                    SizedBox(width: 6),
                    Text(
                      'نبذة عن المتسابق',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  character.bioAr.isNotEmpty
                      ? character.bioAr
                      : 'متسابق جاهز لخوض منافسات أرض التحدي وتحقيق أعلى المراتب.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Skill Bars
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'المهارات والقدرات',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _SkillBar(
                  title: 'سرعة البديهة وردود الفعل',
                  value: character.speed,
                  color: const Color(0xFFFBBF24),
                  icon: Icons.bolt_rounded,
                ),
                const SizedBox(height: 10),
                _SkillBar(
                  title: 'المعرفة والثقافة العامة',
                  value: character.knowledge,
                  color: const Color(0xFF60A5FA),
                  icon: Icons.auto_stories_rounded,
                ),
                const SizedBox(height: 10),
                _SkillBar(
                  title: 'التركيز تحت الضغط',
                  value: character.focus,
                  color: const Color(0xFF34D399),
                  icon: Icons.crisis_alert_rounded,
                ),
                const SizedBox(height: 10),
                _SkillBar(
                  title: 'الثقة بالنفس والتحدي',
                  value: character.confidence,
                  color: const Color(0xFFF472B6),
                  icon: Icons.military_tech_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceTab(GameCharacter character) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المظهر في اللعبة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 14),
                _AppearanceRow(
                  icon: Icons.stadium_rounded,
                  title: 'منصة مسرح المسابقة',
                  subtitle: 'يظهر في منصة التحدي المباشر أمام المنافسين.',
                ),
                SizedBox(height: 12),
                _AppearanceRow(
                  icon: Icons.emoji_events_rounded,
                  title: 'متصدر قائمة الأبطال',
                  subtitle: 'تتألق صورة الشخصية في لوحة الشرف وصدارة الترتيب.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceRow extends StatelessWidget {
  const _AppearanceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFFFD54F).withValues(alpha: 0.6),
            ),
          ),
          child: Icon(icon, color: const Color(0xFFFFD54F), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
                fontWeight: FontWeight.w900,
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
