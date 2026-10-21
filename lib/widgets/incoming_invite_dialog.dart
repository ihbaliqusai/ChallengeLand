import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/invite_service.dart';
import '../core/shared_assets.dart';

/// A premium, AAA game-styled incoming challenge / room invitation dialog.
class IncomingInviteDialog extends StatefulWidget {
  const IncomingInviteDialog({
    super.key,
    required this.candidate,
    required this.onAccept,
    required this.onDismiss,
  });

  final InviteCandidate candidate;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  State<IncomingInviteDialog> createState() => _IncomingInviteDialogState();
}

class _IncomingInviteDialogState extends State<IncomingInviteDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _glowAnimation;
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _copyCode() {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: widget.candidate.code));
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final candidate = widget.candidate;
    final isFriend = candidate.type == InviteType.friendChallenge;
    final primaryColor =
        isFriend ? const Color(0xFFFFD700) : const Color(0xFF38BDF8);
    final secondaryColor =
        isFriend ? const Color(0xFFF59E0B) : const Color(0xFF0284C7);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 580),
          child: AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0D1738),
                      Color(0xFF070B1E),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: _glowAnimation.value),
                    width: 1.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(
                        alpha: _glowAnimation.value * 0.45,
                      ),
                      blurRadius: 28,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Top Crest with Glowing Halo ────────────────────────────
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor.withValues(alpha: 0.12),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                      ),
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [primaryColor, secondaryColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.45),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          isFriend
                              ? Icons.sports_esports_rounded
                              : Icons.emoji_events_rounded,
                          color:
                              isFriend ? const Color(0xFF070E24) : Colors.white,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Type Pill ──────────────────────────────────────────────
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isFriend ? '⚔️ تحدي لاعب ضد لاعب' : '🏆 دعوة غرفة جماعية',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Title & Subtitle ───────────────────────────────────────
                  Text(
                    candidate.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    candidate.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Challenger / Room Details Card ─────────────────────────
                  if (isFriend && candidate.senderName != null)
                    _buildChallengerPreview(candidate, primaryColor)
                  else if (!isFriend && candidate.roomMode != null)
                    _buildRoomPreview(candidate, primaryColor),

                  const SizedBox(height: 14),

                  // ── Code Plaque with One-Tap Copy ──────────────────────────
                  GestureDetector(
                    onTap: _copyCode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF050B1B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.vpn_key_rounded,
                            size: 18,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isFriend ? 'رمز تحدي الصديق' : 'رمز الغرفة',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  candidate.code,
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _copied
                                  ? const Color(0xFF10B981)
                                      .withValues(alpha: 0.2)
                                  : primaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _copied
                                    ? const Color(0xFF10B981)
                                    : primaryColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _copied
                                      ? Icons.check_circle_rounded
                                      : Icons.copy_rounded,
                                  size: 14,
                                  color: _copied
                                      ? const Color(0xFF10B981)
                                      : primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _copied ? 'تم النسخ!' : 'نسخ',
                                  style: TextStyle(
                                    color: _copied
                                        ? const Color(0xFF10B981)
                                        : primaryColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Actions Row ───────────────────────────────────────────
                  Row(
                    children: [
                      // Dismiss / Ignore
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onDismiss,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF94A3B8),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'تجاهل',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Accept / Join CTA
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isFriend
                                  ? [
                                      const Color(0xFFFFD700),
                                      const Color(0xFFF59E0B),
                                    ]
                                  : [
                                      const Color(0xFF38BDF8),
                                      const Color(0xFF0284C7),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: (isFriend
                                        ? const Color(0xFFFFD700)
                                        : const Color(0xFF38BDF8))
                                    .withValues(alpha: 0.4),
                                blurRadius: 14,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              widget.onAccept();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: isFriend
                                  ? const Color(0xFF070E24)
                                  : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: Icon(
                              isFriend
                                  ? Icons.play_arrow_rounded
                                  : Icons.login_rounded,
                              size: 20,
                            ),
                            label: Text(
                              isFriend ? 'قبول التحدي ⚔️' : 'انضمام للغرفة 🚀',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChallengerPreview(InviteCandidate candidate, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A132C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color, width: 1.5),
              image: candidate.senderPhoto != null
                  ? DecorationImage(
                      image: NetworkImage(candidate.senderPhoto!),
                      fit: BoxFit.cover,
                    )
                  : DecorationImage(
                      image: AssetImage('assets/ui/user.png', bundle: SharedAssets.bundle),
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate.senderName ?? 'لاعب منافس',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (candidate.senderLevel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Lv.${candidate.senderLevel}',
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const Expanded(
                      child: Text(
                        'يتحداك الآن في مواجهة مباشرة',
                        style: TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomPreview(InviteCandidate candidate, Color color) {
    final modeName =
        InviteService.translateRoomMode(candidate.roomMode ?? 'battle');
    final count = candidate.roomPlayerCount ?? 1;
    final max = candidate.roomMaxPlayers ?? 4;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A132C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
            child: Icon(Icons.groups_rounded, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المضيف: ${candidate.senderName ?? 'غرفة التحدي'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        modeName,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$count/$max لاعبين',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
