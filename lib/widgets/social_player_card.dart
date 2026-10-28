import 'package:flutter/material.dart';
import '../core/app_settings.dart';
import 'social_artwork.dart';

/// Compact player identity; tapping opens the screen's player options.
class SocialPlayerCard extends StatelessWidget {
  const SocialPlayerCard({
    super.key,
    required this.profile,
    required this.status,
    required this.onTap,
    this.online = false,
    this.inMatch = false,
    this.loading = false,
    this.profileUnavailable = false,
    this.selected = false,
  });

  final Map<String, dynamic> profile;
  final String status;
  final VoidCallback onTap;
  final bool online, inMatch, loading, profileUnavailable, selected;

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF6540A5);
    const gold = Color(0xFFE7AF28);
    final accent = online
        ? inMatch
            ? const Color(0xFFF1B52D)
            : const Color(0xFF24B778)
        : const Color(0xFF8693A7);
    final rawName = profile['username']?.toString().trim() ?? '';
    final name = loading
        ? 'جارٍ تحميل اللاعب…'
        : rawName.isEmpty
            ? 'لاعب'
            : rawName;
    final rawPhoto = profile['photoUrl']?.toString().trim() ?? '';
    final photo = Uri.tryParse(rawPhoto);
    final hasPhoto = !loading &&
        photo != null &&
        photo.scheme == 'https' &&
        photo.host.isNotEmpty;
    final level = _number(profile['level'], fallback: 1).clamp(1, 999999);
    final subtitle = loading
        ? 'جارٍ تحميل البيانات…'
        : profileUnavailable
            ? 'تعذر تحميل بيانات اللاعب'
            : 'المستوى $level · $status';
    final trophies = loading || profileUnavailable
        ? '—'
        : _number(profile['trophies']).toString();
    final trophyDescription =
        trophies == '—' ? 'عدد الكؤوس غير متاح' : '$trophies كأس';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Semantics(
        button: true,
        selected: selected,
        label: '$name، $subtitle، $trophyDescription',
        hint: 'عرض خيارات اللاعب',
        onTap: onTap,
        excludeSemantics: true,
        child: Tooltip(
          message: 'خيارات $name',
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: (selected ? gold : purple).withValues(alpha: .30),
                  offset: const Offset(0, 3),
                  blurRadius: 3,
                )
              ],
            ),
            child: Material(
              color: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(13),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: selected
                        ? const [Color(0xFFFFF1C5), Color(0xFFE0E7EF)]
                        : const [Color(0xFFF1F5FA), Color(0xFFCAD5E2)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                      color: selected ? gold : socialGold, width: 2.5),
                ),
                child: Stack(children: [
                  const Positioned.fill(child: SocialPlayerArtwork()),
                  InkWell(
                    onTap: () {
                      AppSettings.playClick();
                      onTap();
                    },
                    borderRadius: BorderRadius.circular(13),
                    splashColor: purple.withValues(alpha: .12),
                    focusColor: gold.withValues(alpha: .22),
                    child: ConstrainedBox(
                      // Ink adds the 5 px border, producing a 76 px row face.
                      constraints: const BoxConstraints(minHeight: 71),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: Stack(clipBehavior: Clip.none, children: [
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: socialGold, width: 1.5),
                                  ),
                                  padding: const EdgeInsets.all(1.5),
                                  child: ClipOval(
                                    child: hasPhoto
                                        ? Image.network(rawPhoto,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _avatar())
                                        : _avatar(),
                                  ),
                                ),
                              ),
                              PositionedDirectional(
                                bottom: -1,
                                end: -1,
                                child: Container(
                                  key: const ValueKey('player-status-dot'),
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: const Color(0xFFEAF0F6),
                                        width: 2),
                                  ),
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Color(0xFF25243D),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        height: 1.2)),
                                const SizedBox(height: 4),
                                Text(subtitle,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Color(0xFF586178),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        height: 1.3)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 44,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.emoji_events_rounded,
                                      color: Color(0xFFC58B12), size: 20),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(trophies,
                                        textDirection: TextDirection.ltr,
                                        maxLines: 1,
                                        style: const TextStyle(
                                            color: Color(0xFF675227),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            height: 1.2)),
                                  ),
                                ]),
                          ),
                          const SizedBox(width: 5),
                          Icon(Icons.chevron_left_rounded,
                              color: purple.withValues(alpha: .75), size: 18),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static int _number(dynamic value, {int fallback = 0}) =>
      value is num && value.isFinite
          ? value.toInt().clamp(0, 2147483647)
          : fallback;

  Widget _avatar() => const ColoredBox(
        color: Color(0xFFD6DCEC),
        child: Center(
            child:
                Icon(Icons.person_rounded, color: Color(0xFF74618F), size: 28)),
      );
}
