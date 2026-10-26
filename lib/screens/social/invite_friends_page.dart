import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_state.dart';
import '../../services/referral_service.dart';
import 'invite_friends_screen.dart';
import 'social_screen.dart';

/// Connects the presentation to the authenticated, server-owned referral ledger.
class InviteFriendsPage extends StatelessWidget {
  const InviteFriendsPage({super.key, this.initialCode});
  final String? initialCode;

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final uid = appState.currentUser?.uid;
    const service = ReferralService();

    InviteFriendsData toData(Map<String, dynamic> result) {
      final state = Map<String, dynamic>.from(result['state'] as Map);
      int amount(dynamic value) => (value as num?)?.toInt() ?? 0;
      return InviteFriendsData(
        code: state['code'] as String? ?? '',
        qualifiedCount: amount(state['qualifiedCount']),
        earnedCoins: amount(state['totalCoins']),
        earnedGems: amount(state['totalGems']),
        acceptedCode: state['acceptedCode'] as String?,
        canAccept: state['canAccept'] == true,
        milestones: [
          for (final milestone in state['milestones'] as List? ?? const [])
            if (milestone is Map)
              InviteFriendsMilestone(
                count: amount(milestone['count']),
                coins: amount(milestone['coins']),
                gems: amount(milestone['gems']),
                claimed: milestone['claimed'] == true,
              ),
        ],
      );
    }

    Future<InviteFriendsData> resolve(
        Future<Map<String, dynamic>> request, {bool isAccept = false}) async {
      final result = await request;
      if (appState.currentUser?.uid != uid) {
        throw StateError('تغيّر الحساب. افتح شاشة الدعوات مجددًا.');
      }
      final data = toData(result);
      if (isAccept) {
        await appState.refreshReferralWallet();
      } else {
        unawaited(appState.refreshReferralWallet());
      }
      return data;
    }

    final syncCached = uid != null && uid.isNotEmpty
        ? ReferralService.getCachedStateSync(uid)
        : null;

    return InviteFriendsScreen(
      initialCode: initialCode,
      initialData: syncCached != null ? toData(syncCached) : null,
      loadCached: uid != null && uid.isNotEmpty
          ? () async {
              final cached = await ReferralService.loadCachedState(uid);
              return cached != null ? toData(cached) : null;
            }
          : null,
      load: () => resolve(service.load(uid ?? '')),
      accept: (code) =>
          resolve(service.accept(uid ?? '', code), isAccept: true),
      share: (code) async {
        final box = context.findRenderObject() as RenderBox?;
        await Share.share(ReferralService.shareMessage(code),
            subject: 'هدية لك في أرض التحدي',
            sharePositionOrigin:
                box == null ? null : box.localToGlobal(Offset.zero) & box.size);
      },
      onPlayWithFriends: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const SocialScreen())),
    );
  }
}
