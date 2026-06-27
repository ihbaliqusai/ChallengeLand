import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../models/game_character.dart';

/// Character picker. Shown forced on first entry (no back, must choose) and as a
/// normal editable route from the profile (with a back button).
///
/// Layout: a status bar with the player's currencies, a large animated "hero"
/// showcase of the focused character, a horizontal roster rail, and a primary
/// action that selects / unlocks the character.
class CharacterSelectScreen extends StatefulWidget {
  const CharacterSelectScreen({super.key, this.forced = false});

  /// When true the screen is rendered by the AuthGate as a mandatory first step
  /// (no back button, the action bar starts the game). When false it is a pushed
  /// route opened from the profile (back button + "save & close").
  final bool forced;

  @override
  State<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends State<CharacterSelectScreen> {
  int _focused = CharacterCatalog.defaultIndex;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final appState = context.read<AppState>();
    _focused = appState.hasChosenCharacter
        ? appState.selectedCharacterIndex
        : CharacterCatalog.defaultIndex;
  }

  GameCharacter get _character => CharacterCatalog.byIndex(_focused);

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textDirection: TextDirection.rtl),
          backgroundColor:
              isError ? const Color(0xFFB91C1C) : const Color(0xFF0F766E),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _onPrimary() async {
    if (_busy) return;
    final appState = context.read<AppState>();
    final character = _character;

    // Locked by level — cannot be chosen yet.
    if (!appState.isCharacterUnlocked(character) &&
        character.unlock.isLevelGated) {
      _showSnack('تُفتح ${character.nameAr} عند المستوى ${character.unlock.value}',
          isError: true);
      return;
    }

    // Locked by purchase — buy first, then select.
    if (!appState.isCharacterUnlocked(character)) {
      final confirmed = await _confirmPurchase(character);
      if (confirmed != true || !mounted) return;
      setState(() => _busy = true);
      final bought = await appState.purchaseCharacter(character);
      if (!mounted) return;
      setState(() => _busy = false);
      if (!bought) {
        _showSnack('تعذّر الشراء — تحقّق من رصيدك.', isError: true);
        return;
      }
      _showSnack('تم فتح ${character.nameAr}!');
    }

    // Commit the selection.
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
    // In forced mode the AuthGate rebuilds to the home screen automatically.
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
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: character.color.withValues(alpha: 0.35)),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
          title: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: character.color.withValues(alpha: 0.14),
                  border:
                      Border.all(color: character.color.withValues(alpha: 0.4)),
                ),
                padding: const EdgeInsets.all(6),
                child: _CharacterImage(character: character),
              ),
              const SizedBox(height: 12),
              Text(
                'فتح ${character.nameAr}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                ),
              ),
            ],
          ),
          content: Text(
            'هل تريد فتح ${character.nameAr} مقابل '
            '${_compactNumber(character.unlock.value)} '
            '${isCoins ? 'كوين' : 'جوهرة'}؟',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: const Text('إلغاء',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: Icon(isCoins
                  ? Icons.monetization_on_rounded
                  : Icons.diamond_rounded),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFACC15),
                foregroundColor: const Color(0xFF111827),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              label: Text('فتح مقابل ${_compactNumber(character.unlock.value)}',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final character = _character;
    final unlocked = appState.isCharacterUnlocked(character);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF050B18),
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/ui/bg_main.png', fit: BoxFit.cover),
            // Dark vignette + a soft wash of the focused character's color so the
            // whole screen subtly reacts to the selection.
            AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    character.color.withValues(alpha: 0.20),
                    const Color(0xFF050B18).withValues(alpha: 0.86),
                    const Color(0xFF050B18),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _TopBar(forced: widget.forced, appState: appState),
                  const _ScreenTitle(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 540),
                          child: _HeroPreview(
                            character: character,
                            unlocked: unlocked,
                            isSelected:
                                appState.selectedCharacterIndex == _focused,
                            playerLevel: appState.level,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CharacterRail(
                    appState: appState,
                    focused: _focused,
                    onTap: (i) => setState(() => _focused = i),
                  ),
                  _ActionBar(
                    forced: widget.forced,
                    busy: _busy,
                    character: character,
                    unlocked: unlocked,
                    isSelected: appState.selectedCharacterIndex == _focused,
                    onPressed: _onPrimary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top bar (back + currencies) ───────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.forced, required this.appState});

  final bool forced;
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
      child: Row(
        children: [
          if (!forced)
            _CircleButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            )
          else
            const SizedBox(width: 40),
          const Spacer(),
          _CurrencyChip(
            icon: Icons.monetization_on_rounded,
            value: _compactNumber(appState.coins),
            color: const Color(0xFFFACC15),
          ),
          const SizedBox(width: 8),
          _CurrencyChip(
            icon: Icons.diamond_rounded,
            value: _compactNumber(appState.gems),
            color: const Color(0xFF38BDF8),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1429).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenTitle extends StatelessWidget {
  const _ScreenTitle();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(18, 6, 18, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'اختر شخصيتك',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'ستظهر شخصيتك في كل أطوار اللعب',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Hero showcase ─────────────────────────────────────────────────────────────

class _HeroPreview extends StatelessWidget {
  const _HeroPreview({
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
    final accent = character.color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.22),
            const Color(0xFF0A1326).withValues(alpha: 0.92),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 34,
            spreadRadius: -6,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _TagPill(label: character.tagAr, color: accent),
              const Spacer(),
              if (isSelected) const _SelectedPill(),
            ],
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.85, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: _HeroPortrait(
                key: ValueKey<int>(character.index),
                character: character,
                unlocked: unlocked,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            character.nameAr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          _HeroStatus(
            character: character,
            unlocked: unlocked,
            isSelected: isSelected,
            playerLevel: playerLevel,
          ),
        ],
      ),
    );
  }
}

class _HeroPortrait extends StatelessWidget {
  const _HeroPortrait({
    super.key,
    required this.character,
    required this.unlocked,
  });

  final GameCharacter character;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Accent halo behind the portrait.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      character.color.withValues(alpha: 0.5),
                      character.color.withValues(alpha: 0.0),
                    ],
                    stops: const [0.1, 0.72],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _CharacterImage(character: character, dimmed: !unlocked),
            ),
          ),
          if (!unlocked)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child:
                  const Icon(Icons.lock_rounded, color: Colors.white, size: 26),
            ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _SelectedPill extends StatelessWidget {
  const _SelectedPill();

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF34D399);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: green.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: green.withValues(alpha: 0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: green, size: 15),
          SizedBox(width: 5),
          Text(
            'شخصيتك',
            style: TextStyle(
              color: green,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// The contextual line under the hero name: owned / level requirement / price.
class _HeroStatus extends StatelessWidget {
  const _HeroStatus({
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
      return _StatusBox(
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF34D399),
        title: isSelected ? 'شخصيتك الحالية' : 'متاحة وجاهزة',
        subtitle: isSelected ? 'تظهر في كل أطوار اللعب' : 'اضغط للاختيار',
      );
    }

    switch (character.unlock.kind) {
      case CharacterUnlockKind.level:
        return _StatusBox(
          icon: Icons.lock_rounded,
          color: const Color(0xFF93C5FD),
          title: 'تُفتح عند المستوى ${character.unlock.value}',
          subtitle: 'مستواك الحالي: $playerLevel',
        );
      case CharacterUnlockKind.coins:
        return _StatusBox(
          icon: Icons.monetization_on_rounded,
          color: const Color(0xFFFACC15),
          title: '${_compactNumber(character.unlock.value)} كوين',
          subtitle: 'اشترِها لفتحها نهائيًا',
        );
      case CharacterUnlockKind.gems:
        return _StatusBox(
          icon: Icons.diamond_rounded,
          color: const Color(0xFF38BDF8),
          title: '${_compactNumber(character.unlock.value)} جوهرة',
          subtitle: 'اشترِها لفتحها نهائيًا',
        );
      case CharacterUnlockKind.free:
        return const _StatusBox(
          icon: Icons.check_circle_rounded,
          color: Color(0xFF34D399),
          title: 'متاحة',
          subtitle: 'اضغط للاختيار',
        );
    }
  }
}

class _StatusBox extends StatelessWidget {
  const _StatusBox({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 19),
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
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Roster rail ───────────────────────────────────────────────────────────────

class _CharacterRail extends StatefulWidget {
  const _CharacterRail({
    required this.appState,
    required this.focused,
    required this.onTap,
  });

  final AppState appState;
  final int focused;
  final ValueChanged<int> onTap;

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
    final target = (position * _itemExtent) - (viewport / 2) + (_itemExtent / 2);
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

  /// Visual position of a catalog index within the rail (catalog order).
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
    // Centered roster: the row hugs the middle when it fits the viewport, and
    // scrolls (keeping the focused character centered) when it overflows.
    return SizedBox(
      height: 112,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final character in CharacterCatalog.all)
                    SizedBox(
                      width: _itemExtent,
                      child: _RailItem(
                        character: character,
                        unlocked:
                            widget.appState.isCharacterUnlocked(character),
                        isSelected: widget.appState.selectedCharacterIndex ==
                            character.index,
                        isFocused: widget.focused == character.index,
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
    required this.character,
    required this.unlocked,
    required this.isSelected,
    required this.isFocused,
    required this.onTap,
  });

  final GameCharacter character;
  final bool unlocked;
  final bool isSelected;
  final bool isFocused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ringColor = isFocused
        ? character.color
        : isSelected
            ? character.color.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.12);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: isFocused ? 68 : 60,
            height: isFocused ? 68 : 60,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0A1326).withValues(alpha: 0.9),
              border: Border.all(color: ringColor, width: isFocused ? 2.4 : 1.2),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: character.color.withValues(alpha: 0.45),
                        blurRadius: 16,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child: _CharacterImage(
                    character: character,
                    dimmed: !unlocked,
                  ),
                ),
                if (!unlocked)
                  Positioned(
                    bottom: -2,
                    child: _LockChip(character: character),
                  ),
                if (isSelected)
                  const Positioned(
                    top: -3,
                    right: -3,
                    child: _SelectedTick(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            character.nameAr,
            style: TextStyle(
              color: isFocused
                  ? Colors.white
                  : unlocked
                      ? Colors.white70
                      : Colors.white38,
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
        color: const Color(0xFF071126),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF34D399), width: 1.5),
      ),
      padding: const EdgeInsets.all(1),
      child: const Icon(Icons.check_rounded, color: Color(0xFF34D399), size: 13),
    );
  }
}

class _LockChip extends StatelessWidget {
  const _LockChip({required this.character});

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
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CharacterImage extends StatelessWidget {
  const _CharacterImage({
    required this.character,
    this.dimmed = false,
  });

  final GameCharacter character;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      character.asset,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.person_rounded,
        color: Colors.white.withValues(alpha: 0.5),
        size: 40,
      ),
    );
    if (!dimmed) return image;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(
        Color(0xAA0B1220),
        BlendMode.saturation,
      ),
      child: Opacity(opacity: 0.55, child: image),
    );
  }
}

// ── Primary action ────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.forced,
    required this.busy,
    required this.character,
    required this.unlocked,
    required this.isSelected,
    required this.onPressed,
  });

  final bool forced;
  final bool busy;
  final GameCharacter character;
  final bool unlocked;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool levelLocked = !unlocked && character.unlock.isLevelGated;

    String label;
    IconData icon;
    List<Color> gradient;
    if (!unlocked && character.unlock.isPurchasable) {
      label = 'فتح وتفعيل';
      icon = Icons.lock_open_rounded;
      gradient = const [Color(0xFFF8D34C), Color(0xFFF59E0B)];
    } else if (levelLocked) {
      label = 'تُفتح عند المستوى ${character.unlock.value}';
      icon = Icons.lock_rounded;
      gradient = const [Color(0xFF3A4A66), Color(0xFF2A3650)];
    } else if (isSelected) {
      label = forced ? 'ابدأ اللعب' : 'هذه شخصيتك';
      icon = forced ? Icons.play_arrow_rounded : Icons.check_rounded;
      gradient = const [Color(0xFF34D399), Color(0xFF059669)];
    } else {
      label = forced ? 'اختيار وبدء اللعب' : 'اختيار';
      icon = Icons.check_rounded;
      gradient = const [Color(0xFFF8D34C), Color(0xFFF59E0B)];
    }

    final enabled = !busy && !levelLocked;
    final dark = gradient.first.computeLuminance() > 0.5;
    final fg = dark ? const Color(0xFF1F2937) : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: GestureDetector(
          onTap: enabled ? onPressed : null,
          child: Container(
            height: 58,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: gradient),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: gradient.last.withValues(alpha: 0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: busy
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: fg,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: fg, size: 23),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: fg,
                              fontSize: 17,
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
