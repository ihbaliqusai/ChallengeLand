import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  static String userRatedKey(String uid) => '${_keyHasRated}_$uid';
  static String userRewardKey(String uid) => '${_keyRewardClaimed}_$uid';

  static const int rewardCoins = 500;
  static const int rewardGems = 10;
  static const int minVictoriesForPrompt = 2; // ظهور فقط بعد فوزين على الأقل
  static const int cooldownHours =
      72; // فاصل 3 أيام بين طلبات التقييم التلقائية
  static const int maxAutoPrompts =
      3; // حد أقصى 3 مرات تلقائياً حتى لا يزعج اللاعب

  bool _isDialogShowing = false;

  String? _resolveUid(String? uid) {
    if (uid != null && uid.isNotEmpty) return uid;
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// Hide the home entry once rating or its reward has been completed.
  Future<bool> shouldShowRatingEntry({String? uid}) async {
    final effectiveUid = _resolveUid(uid);
    try {
      final prefs = await SharedPreferences.getInstance();
      final ratedLocally = (prefs.getBool(_keyHasRated) ?? false) ||
          (effectiveUid != null && (prefs.getBool(userRatedKey(effectiveUid)) ?? false));
      final claimedLocally = (prefs.getBool(_keyRewardClaimed) ?? false) ||
          (effectiveUid != null && (prefs.getBool(userRewardKey(effectiveUid)) ?? false));
      if (ratedLocally || claimedLocally) return false;

      if (effectiveUid != null && effectiveUid.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(effectiveUid)
              .get()
              .timeout(const Duration(seconds: 4));
          if (doc.exists) {
            final data = doc.data();
            final ratedRemote = data?['hasRated'] == true;
            final claimedRemote = data?['claimedRatingReward'] == true;
            if (ratedRemote || claimedRemote) {
              if (ratedRemote) {
                await prefs.setBool(_keyHasRated, true);
                await prefs.setBool(userRatedKey(effectiveUid), true);
              }
              if (claimedRemote) {
                await prefs.setBool(_keyRewardClaimed, true);
                await prefs.setBool(userRewardKey(effectiveUid), true);
              }
              return false;
            }
          }
        } catch (_) {}
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// هل قام اللاعب بتقييم اللعبة سابقاً؟
  Future<bool> hasRated({String? uid}) async {
    final effectiveUid = _resolveUid(uid);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_keyHasRated) ?? false) return true;
      if (effectiveUid != null && effectiveUid.isNotEmpty) {
        if (prefs.getBool(userRatedKey(effectiveUid)) ?? false) return true;
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(effectiveUid)
              .get()
              .timeout(const Duration(seconds: 4));
          if (doc.exists &&
              (doc.data()?['hasRated'] == true ||
                  doc.data()?['claimedRatingReward'] == true)) {
            await prefs.setBool(_keyHasRated, true);
            await prefs.setBool(userRatedKey(effectiveUid), true);
            return true;
          }
        } catch (_) {}
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// هل تم استلام مكافأة التقييم سابقاً؟
  Future<bool> hasClaimedReward({String? uid}) async {
    final effectiveUid = _resolveUid(uid);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_keyRewardClaimed) ?? false) return true;
      if (effectiveUid != null && effectiveUid.isNotEmpty) {
        if (prefs.getBool(userRewardKey(effectiveUid)) ?? false) return true;
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(effectiveUid)
              .get()
              .timeout(const Duration(seconds: 4));
          if (doc.exists && doc.data()?['claimedRatingReward'] == true) {
            await prefs.setBool(_keyRewardClaimed, true);
            await prefs.setBool(userRewardKey(effectiveUid), true);
            return true;
          }
        } catch (_) {}
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// التحقق من أهلية الظهور التلقائي (توقيت سعيد + عدم إزعاج)
  Future<bool> shouldPromptAuto({String? uid}) async {
    if (_isDialogShowing) return false;
    try {
      final effectiveUid = _resolveUid(uid);
      final prefs = await SharedPreferences.getInstance();
      final rated = (prefs.getBool(_keyHasRated) ?? false) ||
          (effectiveUid != null &&
              (prefs.getBool(userRatedKey(effectiveUid)) ?? false));
      final claimed = (prefs.getBool(_keyRewardClaimed) ?? false) ||
          (effectiveUid != null &&
              (prefs.getBool(userRewardKey(effectiveUid)) ?? false));
      if (rated || claimed) return false;

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
      await prefs.setInt(
          _keyLastPromptTime, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// تسجيل إتمام التقييم بنجاح
  Future<void> markRated({String? uid}) async {
    final effectiveUid = _resolveUid(uid);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasRated, true);
      if (effectiveUid != null && effectiveUid.isNotEmpty) {
        await prefs.setBool(userRatedKey(effectiveUid), true);
        try {
          await FirebaseFirestore.instance.collection('users').doc(effectiveUid).set({
            'hasRated': true,
            'ratedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// منح مكافأة التقييم للاعب
  Future<bool> grantRatingReward(BuildContext context) async {
    final appState = context.read<AppState>();
    final uid = _resolveUid(appState.currentUser?.uid);
    try {
      final alreadyClaimed = await hasClaimedReward(uid: uid);
      if (alreadyClaimed) return false;

      final claimId = uid != null && uid.isNotEmpty ? '$uid:rate_reward' : null;
      final success = await appState.grantRewardCurrency(
        coinsReward: rewardCoins,
        gemsReward: rewardGems,
        claimId: claimId,
      );
      if (!success) return false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyRewardClaimed, true);
      await prefs.setBool(_keyHasRated, true);
      if (uid != null && uid.isNotEmpty) {
        await prefs.setBool(userRewardKey(uid), true);
        await prefs.setBool(userRatedKey(uid), true);
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'claimedRatingReward': true,
            'hasRated': true,
            'ratingRewardCoins': rewardCoins,
            'ratingRewardGems': rewardGems,
            'claimedRatingRewardAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint(
              '[RateGameService] Failed to record rating claim in firestore: $e');
        }
      }

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
      final user = appState.currentUser ?? appState.user;
      final uid = _resolveUid(user?.uid);

      await FirebaseFirestore.instance.collection('ratings_feedback').add({
        'rating': rating,
        'tags': tags,
        'message': message.trim(),
        'userId': uid ?? 'guest',
        'userName': user?.displayName ?? 'لاعب',
        'userEmail': user?.email ?? '',
        'userLevel': appState.level,
        'platform': 'android',
        'appVersion': '3.6.2',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await markRated(uid: uid);
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
    String? uid,
  }) async {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    final effectiveUid = _resolveUid(uid);

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
        pageBuilder: (ctx, anim1, anim2) =>
            RateGameDialog(isManual: isManual, uid: effectiveUid),
        transitionBuilder: (ctx, anim1, anim2, child) {
          final curve =
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
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
