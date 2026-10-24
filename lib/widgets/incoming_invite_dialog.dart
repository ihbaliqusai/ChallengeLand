import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/invite_service.dart';
import '../core/shared_assets.dart';
import 'game_notice.dart';

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

class _IncomingInviteDialogState extends State<IncomingInviteDialog> {
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.candidate.code));
    HapticFeedback.selectionClick();
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
    final tone = isFriend ? GameNoticeTone.challenge : GameNoticeTone.info;
    final accent = tone.color;
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: GameNoticeCard(
          tone: tone,
          title: Text(candidate.title),
          onClose: widget.onDismiss,
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(isFriend ? '⚔️ تحدي لاعب ضد لاعب' : '🏆 دعوة غرفة جماعية',
                style: TextStyle(
                    color: accent, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(candidate.subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            if (isFriend && candidate.senderName != null)
              _buildChallengerPreview(candidate, accent)
            else if (!isFriend && candidate.roomMode != null)
              _buildRoomPreview(candidate, accent),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF080F21),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(candidate.code,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          color: accent,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                ),
                TextButton.icon(
                  onPressed: _copyCode,
                  icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded,
                      size: 16),
                  label: Text(_copied ? 'تم النسخ!' : 'نسخ'),
                ),
              ]),
            ),
          ]),
          actions: [
            FilledButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                widget.onAccept();
              },
              icon: Icon(
                  isFriend ? Icons.play_arrow_rounded : Icons.login_rounded,
                  size: 20),
              label: Text(isFriend ? 'قبول التحدي ⚔️' : 'انضمام للغرفة 🚀'),
            ),
            OutlinedButton(
                onPressed: widget.onDismiss, child: const Text('تجاهل')),
          ],
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
                      image: AssetImage('assets/ui/user.png',
                          bundle: SharedAssets.bundle),
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
