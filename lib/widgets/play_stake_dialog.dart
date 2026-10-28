import 'game_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_settings.dart';
import '../core/app_state.dart';
import '../services/online_match_flow.dart';
import '../screens/social/social_screen.dart';
import 'play_stake_artwork.dart';

/// Modal dialog for the "العب" (Play) button:
/// Allows selecting match stake (coins), dynamically displays bot difficulty scaling,
/// and allows launching a random online match or choosing a player in the arena.
class PlayStakeDialog extends StatefulWidget {
  const PlayStakeDialog({super.key});

  static const List<int> stakeTiers = [0, 50, 100, 250, 500, 1000, 2500, 5000];

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xB8000000),
      builder: (ctx) => const PlayStakeDialog(),
    );
  }

  @override
  State<PlayStakeDialog> createState() => _PlayStakeDialogState();
}

class _PlayStakeDialogState extends State<PlayStakeDialog> {
  int _selectedStake = 50;
  bool _isLaunching = false;

  static const _green = Color(0xFF10B981);
  static const _ruby = Color(0xFFEF4444);

  ({String label, String badge, Color color, int level}) _getBotDifficulty(
      int stake) {
    if (stake <= 0) {
      return (
        label: 'متكافئ وتدريبي',
        badge: 'مستوى 5 🟢',
        color: _green,
        level: 5
      );
    } else if (stake <= 100) {
      return (
        label: 'متمرس وجاد',
        badge: 'مستوى 6-7 🟡',
        color: const Color(0xFFFBBF24),
        level: 7
      );
    } else if (stake <= 500) {
      return (
        label: 'قوي ومحترف',
        badge: 'مستوى 8 🟠',
        color: const Color(0xFFF97316),
        level: 8
      );
    } else if (stake <= 2000) {
      return (label: 'خبير وسريع', badge: 'مستوى 9 🔴', color: _ruby, level: 9);
    } else {
      return (
        label: 'بطل خارق (دقة قصوى)',
        badge: 'مستوى 10 👑',
        color: const Color(0xFFEC4899),
        level: 10
      );
    }
  }

  Future<void> _startRandomMatch(AppState appState) async {
    if (_isLaunching) return;

    if (!appState.isOnline) {
      _showToast('يتطلب هذا الوضع اتصالاً بالإنترنت');
      return;
    }

    if (_selectedStake > 0 && appState.coins < _selectedStake) {
      _showToast(
          'رصيدك من القطع لا يكفي لهذا الرهان! رصيدك: ${appState.coins}');
      return;
    }

    setState(() => _isLaunching = true);
    HapticFeedback.mediumImpact();

    try {
      if (!await OnlineMatchFlow.prepare(context, appState.user?.uid ?? '')) {
        if (mounted) setState(() => _isLaunching = false);
        return;
      }
      await appState.openRandomMatch(stakeCoins: _selectedStake);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isLaunching = false);
        _showToast('تعذر بدء البحث: $e');
      }
    }
  }

  void _chooseArenaOpponent(AppState appState) {
    if (_isLaunching) return;

    if (!appState.isOnline) {
      _showToast('يتطلب هذا الوضع اتصالاً بالإنترنت');
      return;
    }

    if (_selectedStake > 0 && appState.coins < _selectedStake) {
      _showToast(
          'رصيدك من القطع لا يكفي لهذا الرهان! رصيدك: ${appState.coins}');
      return;
    }

    HapticFeedback.lightImpact();
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SocialScreen(initialTab: 0, initialStake: _selectedStake),
      ),
    );
  }

  void _showToast(String msg) {
    GameNoticeMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1E1038),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final difficulty = _getBotDifficulty(_selectedStake);
    return PlayStakeArtwork(
      coins: appState.coins,
      selectedStake: _selectedStake,
      stakes: PlayStakeDialog.stakeTiers,
      difficulty: difficulty.label,
      level: 'مستوى ${difficulty.level}',
      launching: _isLaunching,
      onStakeChanged: (stake) {
        AppSettings.playClick();
        HapticFeedback.selectionClick();
        setState(() => _selectedStake = stake);
      },
      onRandom: () {
        AppSettings.playClick();
        _startRandomMatch(appState);
      },
      onFriend: () {
        AppSettings.playClick();
        _chooseArenaOpponent(appState);
      },
      onClose: () {
        AppSettings.playClick();
        Navigator.of(context).pop();
      },
    );
  }
}
