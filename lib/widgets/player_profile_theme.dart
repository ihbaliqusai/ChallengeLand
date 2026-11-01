import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import 'game_back_button.dart';
import 'social_artwork.dart';

/// Shared surfaces for the player's profile and profiles opened from friends.
abstract final class PlayerProfileTheme {
  static const gold = socialGold;
  static const muted = Color(0xFFD8CBEF);
  static const cyan = Color(0xFF73DEFF);
  static const ink = Color(0xFF30213F);
  static const purple = Color(0xFF281448);

  static BoxDecoration panelDecoration({
    Color? accent,
    bool subtle = false,
    double radius = 22,
  }) {
    final edge = accent ?? gold;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: subtle
            ? const [Color(0xCC3C2465), Color(0xD924143F)]
            : const [
                Color(0xF04C2A7A),
                Color(0xF02C164F),
                Color(0xF01D1039),
              ],
      ),
      border: Border.all(
        color: edge.withValues(alpha: subtle ? .4 : .9),
        width: subtle ? 1 : 1.6,
      ),
      boxShadow: [
        const BoxShadow(
          color: Color(0x850B0421),
          offset: Offset(0, 4),
          blurRadius: 2,
        ),
        if (!subtle)
          BoxShadow(color: edge.withValues(alpha: .1), blurRadius: 15),
      ],
    );
  }
}

class PlayerProfileShell extends StatelessWidget {
  const PlayerProfileShell({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    required this.onBack,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileTheme = theme.copyWith(
      brightness: Brightness.dark,
      colorScheme: theme.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: PlayerProfileTheme.gold,
        onPrimary: PlayerProfileTheme.ink,
        secondary: PlayerProfileTheme.cyan,
        surface: PlayerProfileTheme.purple,
        onSurface: Colors.white,
      ),
      textTheme: theme.textTheme.apply(
        fontFamily: 'Baloo',
        fontFamilyFallback: const ['NotoSansArabic'],
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: profileTheme,
        child: Scaffold(
          backgroundColor: const Color(0xFF160D36),
          body: SocialArtworkFrame(
            child: SafeArea(
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    GameBackButton(onPressed: onBack),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Semantics(
                            namesRoute: true,
                            header: true,
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: PlayerProfileTheme.gold,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                height: 1.3,
                                shadows: [
                                  Shadow(
                                    color: Color(0xFF63391C),
                                    offset: Offset(0, 2),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: PlayerProfileTheme.muted,
                                fontSize: 11,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ]),
                      ),
                    ),
                    SizedBox(width: 48, child: action),
                  ]),
                ),
                const SizedBox(height: 9),
                Expanded(child: child),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerProfilePanel extends StatelessWidget {
  const PlayerProfilePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Container(
        decoration: PlayerProfileTheme.panelDecoration(
          accent: accent,
        ),
        child: Container(
          margin: const EdgeInsets.all(3),
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: .12),
            ),
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: child,
          ),
        ),
      );
}

class PlayerProfileMetric extends StatelessWidget {
  const PlayerProfileMetric({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accent = PlayerProfileTheme.gold,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 8 : 16,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF416EC0),
              Color(0xFF294596),
              Color(0xFF382166),
            ],
          ),
          border: Border.all(color: accent.withValues(alpha: .65), width: 1.4),
          boxShadow: const [
            BoxShadow(color: Color(0xFF110828), offset: Offset(0, 4)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: EdgeInsets.all(compact ? 4 : 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x55200B45),
              border: Border.all(color: accent.withValues(alpha: .35)),
            ),
            child: Icon(icon, color: accent, size: compact ? 18 : 24),
          ),
          SizedBox(height: compact ? 4 : 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 22 : 28,
                fontWeight: FontWeight.w900,
                height: 1.25,
                shadows: const [
                  Shadow(color: Color(0xFF122655), offset: Offset(0, 2)),
                ],
              ),
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFFE7E9FF),
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              height: compact ? 1.4 : 1.5,
            ),
          ),
        ]),
      );
}

class PlayerProfileBadge extends StatelessWidget {
  const PlayerProfileBadge({
    super.key,
    required this.label,
    required this.icon,
    this.color = PlayerProfileTheme.gold,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF352051),
          border: Border.all(color: color.withValues(alpha: .5)),
          boxShadow: const [
            BoxShadow(color: Color(0x5514072A), offset: Offset(0, 2)),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ]),
      );
}

class PlayerProfileActionButton extends StatelessWidget {
  const PlayerProfileActionButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.secondary = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final colors = !enabled
        ? const [Color(0xFF706182), Color(0xFF42344F)]
        : secondary
            ? const [Color(0xFF51CFFF), Color(0xFF2876D1), Color(0xFF293A91)]
            : const [Color(0xFF72E45E), Color(0xFF29A950), Color(0xFF176332)];
    return Semantics(
      button: true,
      enabled: enabled,
      child: Container(
        padding: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: colors.last,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x850E0525),
              offset: Offset(0, 4),
              blurRadius: 3,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: enabled ? .45 : .15),
                width: 1.5,
              ),
            ),
            child: InkWell(
              onTap: !enabled
                  ? null
                  : () {
                      AppSettings.playClick();
                      onPressed!();
                    },
              borderRadius: BorderRadius.circular(15),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 23),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: enabled ? Colors.white : Colors.white60,
                            fontSize: 16,
                            height: 1.4,
                            fontWeight: FontWeight.w900,
                            shadows: const [
                              Shadow(
                                color: Color(0x8021183B),
                                offset: Offset(0, 2),
                                blurRadius: 1,
                              ),
                            ],
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
      ),
    );
  }
}
