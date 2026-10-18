import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import 'lobby_action_panel.dart';
import 'special_offer_dialog.dart';

class SpecialOfferBadge extends StatelessWidget {
  const SpecialOfferBadge({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (context.select<AppState, bool>((state) => state.isVip)) {
      return const SizedBox.shrink();
    }
    return LobbyActionPanel(
      title: 'نادي الأبطال',
      subtitle: 'استكشف مزايا العضوية',
      icon: Icons.workspace_premium_rounded,
      badge: 'VIP',
      gold: true,
      showNotification: true,
      onPressed: () {
        HapticFeedback.lightImpact();
        SpecialOfferDialog.show(context);
      },
    );
  }
}
