import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_state.dart';
import '../widgets/currency_reward_overlay.dart';
import '../widgets/rate_game_dialog.dart';
import 'native_bridge_service.dart';

/// إدارة تقييم اللعبة بذكاء واحترافية وفق معايير أفضل الألعاب العالمية
class RateGameService {
  RateGameService._();
  static final RateGameService instance = RateGameService._();

  static const String _keyHasRated = 'has_rated_challenge_land';
  static const String _keyLastPromptTime = 'rate_last_prompt_timestamp';
  static const String _keyPromptCount = 'rate_prompt_count';
  static const String _keyVictoriesCount = 'rate_victories_count';
  static const String _keyRewardClaimed = 'rate_reward_claimed';

  static const int rewardCoins = 500;
  static const int rewardGems = 10;
  static const int minVictoriesForPrompt = 2; // ظهور فقط بعد فوزين على الأقل
  static const int cooldownHours = 72; // فاصل 3 أيام بين طلبات التقييم التلقائية
  static const int maxAutoPrompts = 3; // حد أقصى 3 مرات تلقائياً حتى لا يزعج اللاعب

  bool _isDialogShowing = false;

  /// هل قام اللاعب بتقييم اللعبة سابقاً؟
  Future<bool> hasRated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyHasRated) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// هل تم استلام مكافأة التقييم سابقاً؟
  Future<bool> hasClaimedReward() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyRewardClaimed) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// التحقق من أهلية الظهور التلقائي (توقيت سعيد + عدم إزعاج)
  Future<bool> shouldPromptAuto() async {
    if (_isDialogShowing) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rated = prefs.getBool(_keyHasRated) ?? false;
      if (rated) return false;

      final count = prefs.getInt(_keyPromptCount) ?? 0;
      if (count >= maxAutoPrompts) return false;

      final victories = prefs.getInt(_keyVictoriesCount) ?? 0;
      if (victories < minVictoriesForPrompt) return false;

      final lastTime = prefs.getInt(_keyLastPromptTime) ?? 0;
      if (lastTime > 0) {
        final lastDate = DateTime.fromMillisecondsSinceEpoch(lastTime);
        final diff = DateTime.now().difference(lastDate);
        if (diff.inHours < cooldownHours) return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// تسجيل فوز مرحلة في طور الحملة (تحدي المراحل)
  Future<void> recordCampaignVictory(
    BuildContext context, {
    required int stars,
    bool isBoss = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentWins = (prefs.getInt(_keyVictoriesCount) ?? 0) + 1;
      await prefs.setInt(_keyVictoriesCount, currentWins);

      // يظهر التقييم فقط في لحظات السعادة القصوى (3 نجوم أو هزيمة زعيم)
      if (stars >= 3 || isBoss) {
        final canShow = await shouldPromptAuto();
        if (canShow && context.mounted) {
          unawaited(
            Future.delayed(const Duration(milliseconds: 1400), () {
              if (context.mounted && !_isDialogShowing) {
                showRateDialog(context, isAutoPrompt: true);
              }
            }),
          );
        }
      }
    } catch (_) {}
  }

  /// تسجيل فوز مباراة أونلاين (غرف / تحدي الأصدقاء)
  Future<void> recordRoomMatchVictory(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentWins = (prefs.getInt(_keyVictoriesCount) ?? 0) + 1;
      await prefs.setInt(_keyVictoriesCount, currentWins);

      final canShow = await shouldPromptAuto();
      if (canShow && context.mounted) {
        unawaited(
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (context.mounted && !_isDialogShowing) {
              showRateDialog(context, isAutoPrompt: true);
            }
          }),
        );
      }
    } catch (_) {}
  }

  /// تسجيل أنه تم عرض النافذة وتحديث العداد والوقت
  Future<void> markPromptShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = (prefs.getInt(_keyPromptCount) ?? 0) + 1;
      await prefs.setInt(_keyPromptCount, count);
      await prefs.setInt(_keyLastPromptTime, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// تسجيل إتمام التقييم بنجاح
  Future<void> markRated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasRated, true);
    } catch (_) {}
  }

  /// منح مكافأة التقييم للاعب
  Future<bool> grantRatingReward(BuildContext context) async {
    final appState = context.read<AppState>();
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyClaimed = prefs.getBool(_keyRewardClaimed) ?? false;
      if (alreadyClaimed) return false;

      final success = await appState.grantRewardCurrency(
        coinsReward: rewardCoins,
        gemsReward: rewardGems,
      );
      if (!success) return false;

      await prefs.setBool(_keyRewardClaimed, true);
      await prefs.setBool(_keyHasRated, true);

      if (context.mounted) {
        showCurrencyRewardOverlay(
          context,
          coins: rewardCoins,
          gems: rewardGems,
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// فتح صفحة المتجر مباشرة للتقييم
  Future<void> openStore(BuildContext context) async {
    try {
      final native = context.read<NativeBridgeService>();
      await native.openStoreRating();
    } catch (_) {}
  }

  /// إرسال ملاحظات واقتراحات اللاعبين (في حال التقييم بأقل من 4 نجوم)
  Future<bool> submitFeedback({
    required BuildContext context,
    required int rating,
    required List<String> tags,
    required String message,
  }) async {
    try {
      final appState = context.read<AppState>();
      final user = appState.user;

      await FirebaseFirestore.instance.collection('ratings_feedback').add({
        'rating': rating,
        'tags': tags,
        'message': message.trim(),
        'userId': user?.uid ?? 'guest',
        'userName': user?.displayName ?? 'لاعب',
        'userEmail': user?.email ?? '',
        'userLevel': appState.level,
        'platform': 'android',
        'appVersion': '3.6.2',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await markRated();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// إظهار نافذة التقييم الفاخرة
  Future<void> showRateDialog(
    BuildContext context, {
    bool isManual = false,
    bool isAutoPrompt = false,
  }) async {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    if (isAutoPrompt) {
      await markPromptShown();
    }

    try {
      if (!context.mounted) return;
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'RateGameDialog',
        barrierColor: Colors.black.withValues(alpha: 0.85),
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (ctx, anim1, anim2) => RateGameDialog(isManual: isManual),
        transitionBuilder: (ctx, anim1, anim2, child) {
          final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
          return ScaleTransition(
            scale: Tween<double>(begin: 0.82, end: 1.0).animate(curve),
            child: FadeTransition(opacity: anim1, child: child),
          );
        },
      );
    } finally {
      _isDialogShowing = false;
    }
  }
}
