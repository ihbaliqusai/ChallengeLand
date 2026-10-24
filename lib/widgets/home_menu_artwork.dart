import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'adaptive_asset_image.dart';
import '../features/onboarding/guide_target.dart';

/// The supplied menu frame and five buttons, with live account data and controls.
class HomeMenuArtwork extends StatelessWidget {
  const HomeMenuArtwork({
    super.key,
    required this.username,
    required this.rankTitle,
    required this.rankColor,
    required this.photoUrl,
    required this.isOnline,
    required this.dailyReady,
    required this.pendingRewards,
    required this.ratingEntry,
    required this.onProfile,
    required this.onClose,
    required this.onLeaderboard,
    required this.onRewards,
    required this.onStats,
    required this.onAchievements,
    required this.onSettings,
    required this.onUnavailable,
  });

  static const asset = 'assets/ui/home_menu.webp';
  static const _frame = Rect.fromLTRB(.021, .056, .979, .938);
  static const aspectRatio = (2752 * .958) / (1536 * .882);
  final String username;
  final String rankTitle;
  final Color rankColor;
  final String? photoUrl;
  final bool isOnline;
  final bool dailyReady;
  final int pendingRewards;
  final Widget ratingEntry;
  final VoidCallback onProfile;
  final VoidCallback onClose;
  final VoidCallback onLeaderboard;
  final VoidCallback onRewards;
  final VoidCallback onStats;
  final VoidCallback onAchievements;
  final VoidCallback onSettings;
  final VoidCallback onUnavailable;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: RepaintBoundary(
      key: const ValueKey('home-menu-artwork'),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: LayoutBuilder(
          builder: (context, area) {
            Rect map(Rect rect) => Rect.fromLTRB(
              (rect.left - _frame.left) / _frame.width * area.maxWidth,
              (rect.top - _frame.top) / _frame.height * area.maxHeight,
              (rect.right - _frame.left) / _frame.width * area.maxWidth,
              (rect.bottom - _frame.top) / _frame.height * area.maxHeight,
            );
            Widget action(
              Rect rect,
              String label,
              VoidCallback onTap, {
              bool enabled = true,
              String? badge,
            }) {
              final bounds = map(rect);
              final target = Rect.fromCenter(
                center: bounds.center,
                width: math.max(48, bounds.width),
                height: math.max(48, bounds.height),
              );
              return guidedArtworkPosition(
                label: label,
                rect: target,
                child: Tooltip(
                  message: label,
                  child: Semantics(
                    label: label,
                    button: true,
                    enabled: enabled,
                    child: ExcludeSemantics(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (!enabled)
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .38),
                                  borderRadius: BorderRadius.circular(
                                    bounds.height * .23,
                                  ),
                                ),
                              ),
                            ),
                          Positioned.fill(
                            child: TextButton(
                              onPressed: enabled ? onTap : onUnavailable,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    bounds.height * .23,
                                  ),
                                ),
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          if (!enabled)
                            Positioned(
                              top: 3,
                              left: 4,
                              child: Icon(
                                Icons.lock_rounded,
                                color: Colors.white70,
                                size: (area.maxHeight * .055).clamp(12.0, 20.0),
                              ),
                            ),
                          if (badge != null)
                            Positioned(
                              top: -3,
                              right: -3,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  shape: BoxShape.rectangle,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  badge,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(area.maxWidth * .035),
                    child: const _MenuSlice(_frame),
                  ),
                ),
                Positioned.fromRect(
                  rect: map(const Rect.fromLTRB(.65, .128, .830, .323)),
                  child: const _AccountBackground(),
                ),
                Positioned.fromRect(
                  rect: map(const Rect.fromLTRB(.840, .147, .932, .312)),
                  child: ClipOval(
                    child: photoUrl?.isNotEmpty == true
                        ? Image.network(
                            photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallbackAvatar(),
                          )
                        : _fallbackAvatar(),
                  ),
                ),
                Positioned.fromRect(
                  rect: map(const Rect.fromLTRB(.64, .156, .814, .293)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              username,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 12,
                                color: isOnline
                                    ? const Color(0xFF44F5BE)
                                    : const Color(0xFF8995AD),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                rankTitle,
                                style: TextStyle(
                                  color: rankColor,
                                  fontSize: 21,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                action(
                  const Rect.fromLTRB(.64, .125, .945, .324),
                  'الملف الشخصي',
                  onProfile,
                ),
                action(
                  const Rect.fromLTRB(.071, .148, .148, .288),
                  'إغلاق',
                  onClose,
                ),
                action(
                  const Rect.fromLTRB(.665, .366, .944, .546),
                  'الصدارة',
                  onLeaderboard,
                  enabled: isOnline,
                ),
                action(
                  const Rect.fromLTRB(.368, .366, .647, .546),
                  'المكافآت',
                  onRewards,
                  enabled: isOnline,
                  badge: dailyReady ? '!' : null,
                ),
                action(
                  const Rect.fromLTRB(.070, .366, .350, .546),
                  'الإحصائيات',
                  onStats,
                ),
                action(
                  const Rect.fromLTRB(.665, .611, .944, .790),
                  'الإنجازات',
                  onAchievements,
                  badge: pendingRewards > 0
                      ? (pendingRewards > 9 ? '9+' : '$pendingRewards')
                      : null,
                ),
                action(
                  const Rect.fromLTRB(.368, .611, .647, .790),
                  'الإعدادات',
                  onSettings,
                ),
                Positioned.fromRect(
                  rect: map(const Rect.fromLTRB(.074, .616, .346, .785)),
                  child: ratingEntry,
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _fallbackAvatar() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF365A8B), Color(0xFF141D39)],
      ),
    ),
    child: const FittedBox(
      child: Icon(Icons.person_rounded, color: Colors.white70),
    ),
  );
}

class _AccountBackground extends StatelessWidget {
  const _AccountBackground();
  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (rect) => const LinearGradient(
      colors: [
        Colors.transparent,
        Colors.white,
        Colors.white,
        Colors.transparent,
      ],
      stops: [0, .15, .94, 1],
    ).createShader(rect),
    child: ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [0, .12, .9, 1],
      ).createShader(rect),
      child: const _MenuSlice(Rect.fromLTRB(.65, .128, .66, .323)),
    ),
  );
}

class _MenuSlice extends StatelessWidget {
  const _MenuSlice(this.source);
  final Rect source;
  @override
  Widget build(BuildContext context) => ClipRect(
    child: LayoutBuilder(
      builder: (context, area) => Stack(
        children: [
          Positioned(
            left: -source.left / source.width * area.maxWidth,
            top: -source.top / source.height * area.maxHeight,
            width: area.maxWidth / source.width,
            height: area.maxHeight / source.height,
            child: adaptiveAssetImage(
              HomeMenuArtwork.asset,
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
          ),
        ],
      ),
    ),
  );
}
