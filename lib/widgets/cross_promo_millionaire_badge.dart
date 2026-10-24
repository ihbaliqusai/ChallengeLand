import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../services/cross_promo_service.dart';
import 'cross_promo_millionaire_dialog.dart';
import 'lobby_action_panel.dart';

class CrossPromoMillionaireBadge extends StatefulWidget {
  const CrossPromoMillionaireBadge({super.key, this.compact = false});
  final bool compact;

  @override
  State<CrossPromoMillionaireBadge> createState() =>
      _CrossPromoMillionaireBadgeState();
}

class _CrossPromoMillionaireBadgeState extends State<CrossPromoMillionaireBadge>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final promo = context.read<CrossPromoService>();
    final uid = context.read<AppState>().currentUser?.uid;
    await Future.wait([
      promo.checkInstallation(),
      promo.checkRewardClaimed(uid: uid),
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Consumer<CrossPromoService>(
        builder: (context, promo, _) => LobbyActionPanel(
          title: 'تحدي المليون',
          subtitle: promo.isRewardClaimed
              ? (promo.isMillionaireInstalled
                  ? 'العب الآن'
                  : 'جرّب الآن مجاناً')
              : (promo.isMillionaireInstalled
                  ? 'استلم 80 جوهرة الآن'
                  : 'حمّل واحصل على 80 جوهرة'),
          icon: Icons.emoji_events_outlined,
          badge: promo.isRewardClaimed ? null : '+80',
          showNotification: !promo.isRewardClaimed,
          onPressed: () => CrossPromoMillionaireDialog.show(context),
        ),
      );
}
