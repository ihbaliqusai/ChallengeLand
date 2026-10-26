import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';

class EconomyOperationException implements Exception {
  const EconomyOperationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class NativeBridgeService {
  Future<bool> isOnlineMatchAccount(String uid) async =>
      await _channel.invokeMethod<bool>('isOnlineMatchAccount', {'uid': uid}) ==
      true;

  Future<void> completeOnlineRoomRecovery(String id, String message,
      {required String uid}) async {
    await _channel.invokeMethod<void>('completeOnlineRoomRecovery',
        {'id': id, 'message': message, 'uid': uid});
  }

  Future<List<Map<String, dynamic>>> getRecoverableOnlineMatches() async {
    final raw =
        await _channel.invokeMethod<String>('getRecoverableOnlineMatches');
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  Future<void> resumeOnlineMatch(String id) async {
    await _channel.invokeMethod<bool>('resumeOnlineMatch', {'id': id});
  }

  Future<Map<String, dynamic>> inspectOnlineMatch(String id,
      {bool forfeit = false, String? uid}) async {
    final raw = await _channel.invokeMethod<String>(
        forfeit ? 'forfeitOnlineMatch' : 'inspectOnlineMatch',
        {'id': id, if (uid != null) 'uid': uid});
    if (raw == null) throw StateError('تعذر التحقق من المباراة السابقة.');
    // Native launch credentials and board answers must stay on the native side.
    final record = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return {
      'id': record['id'],
      'uid': record['uid'],
      'roomId': record['roomId'],
      'finished': record['finished'] == true,
      'message': record['message'],
    };
  }

  Future<void> dismissOnlineMatchRecovery(String id) async {
    await _channel.invokeMethod<void>('dismissOnlineMatchRecovery', {'id': id});
  }

  Future<Map<String, dynamic>> friendStakes(Map<String, dynamic> data) async {
    try {
      return await _channel.invokeMapMethod<String, dynamic>(
              'friendStakes', data) ??
          <String, dynamic>{};
    } on PlatformException catch (error) {
      final code = error.code.toUpperCase().replaceAll('-', '_');
      final message = error.message?.trim();
      final rawMessage = message?.toUpperCase().replaceAll('-', '_');
      final serviceMissing = code == 'NOT_FOUND' || code == 'UNIMPLEMENTED';
      // Older Android versions only passed a generic code and the raw Firebase
      // status as the message. Keep specific server messages (e.g. low balance).
      final rawStatus =
          rawMessage == 'NOT_FOUND' || rawMessage == 'UNIMPLEMENTED';
      if ((serviceMissing &&
              (message == null || message.isEmpty || rawStatus)) ||
          (code == 'FRIEND_STAKES_FAILED' && rawStatus)) {
        throw const EconomyOperationException(
            'خدمة تحدي القطع غير متاحة حاليًا. حاول مجددًا لاحقًا.');
      }
      throw EconomyOperationException(message?.isNotEmpty == true
          ? message!
          : 'تعذر تحديث تحدي القطع. حاول مجددًا.');
    } on MissingPluginException {
      throw const EconomyOperationException(
          'تحدي القطع غير متاح على هذا الجهاز.');
    }
  }

  Future<Map<String, dynamic>> economy(Map<String, dynamic> data) async {
    try {
      final response =
          await _channel.invokeMapMethod<String, dynamic>('gameEconomy', data);
      return response ?? <String, dynamic>{};
    } on PlatformException catch (error) {
      throw EconomyOperationException(
          error.message ?? 'تعذر تحديث الرصيد. حاول مجدداً.');
    }
  }

  bool get supportsAnimatedCharacters =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static const MethodChannel _channel = MethodChannel('millionaire/native');

  NativeBridgeService() {
    _initChannelHandler();
  }

  static final List<void Function(String productId)>
      _purchaseDeliveredListeners = [];
  static final List<void Function(Map<String, dynamic>)>
      _purchaseStatusListeners = [];

  static void addPurchaseStatusListener(
      void Function(Map<String, dynamic>) listener) {
    if (!_purchaseStatusListeners.contains(listener)) {
      _purchaseStatusListeners.add(listener);
    }
  }

  static void removePurchaseStatusListener(
      void Function(Map<String, dynamic>) listener) {
    _purchaseStatusListeners.remove(listener);
  }

  static void addPurchaseDeliveredListener(
      void Function(String productId) listener) {
    if (!_purchaseDeliveredListeners.contains(listener)) {
      _purchaseDeliveredListeners.add(listener);
    }
  }

  static void removePurchaseDeliveredListener(
      void Function(String productId) listener) {
    _purchaseDeliveredListeners.remove(listener);
  }

  static bool _handlerInitialized = false;
  static void _initChannelHandler() {
    if (_handlerInitialized) return;
    _handlerInitialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPurchaseStatus' && call.arguments is Map) {
        final status = Map<String, dynamic>.from(call.arguments as Map);
        for (final listener in List.of(_purchaseStatusListeners)) {
          try {
            listener(status);
          } catch (_) {}
        }
      }
      if (call.method == 'onPurchaseDelivered') {
        final productId =
            (call.arguments as Map?)?['productId']?.toString() ?? '';
        if (productId.isNotEmpty) {
          for (final listener in List.of(_purchaseDeliveredListeners)) {
            try {
              listener(productId);
            } catch (_) {}
          }
        }
      }
      return null;
    });
  }

  Future<void> launchLegacyGame() async {
    await _channel.invokeMethod('launchOriginal');
  }

  Future<void> syncQuestionHistory({String roomId = ''}) async {
    if (!supportsAnimatedCharacters) return;
    try {
      await _channel
          .invokeMethod<bool>('syncQuestionHistory', {'roomId': roomId});
    } on PlatformException catch (error) {
      throw EconomyOperationException(
          error.message ?? 'تعذر مزامنة سجل الأسئلة. حاول مجددًا.');
    }
  }

  Future<List<int>> reserveRoomQuestionIds({
    required String roomId,
    required String matchMode,
    required int roundNumber,
  }) async {
    List<int>? ids;
    try {
      ids = await _channel.invokeListMethod<int>('reserveRoomQuestions', {
        'roomId': roomId,
        'matchMode': matchMode,
        'roundNumber': roundNumber,
      });
    } on PlatformException catch (error) {
      throw EconomyOperationException(
          error.message ?? 'تعذر تجهيز أسئلة جديدة للغرفة. حاول مجددًا.');
    }
    if (ids == null || ids.isEmpty) {
      throw const EconomyOperationException('تعذر تجهيز أسئلة جديدة للغرفة.');
    }
    return ids;
  }

  Future<String?> consumeLaunchAction() async {
    final action = await _channel.invokeMethod<String>('consumeLaunchAction');
    return action?.trim().isEmpty ?? true ? null : action;
  }

  Future<bool> isAppInstalled(String packageName) async {
    try {
      final installed = await _channel.invokeMethod<bool>('isAppInstalled', {
        'packageName': packageName,
      });
      return installed ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> launchAppOrPlayStore({
    required String packageName,
    String? playStoreUrl,
  }) async {
    try {
      final result =
          await _channel.invokeMethod<String>('launchAppOrPlayStore', {
        'packageName': packageName,
        'playStoreUrl': playStoreUrl ??
            'https://play.google.com/store/apps/details?id=$packageName',
      });
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<String?> openStoreRating({String? packageName}) async {
    try {
      final result = await _channel.invokeMethod<String>('openStoreRating', {
        'packageName': packageName ?? 'com.qi7bali.landchallengeonline',
      });
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<bool> composeSupportEmail({
    required String recipient,
    required String subject,
    required String body,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('composeSupportEmail', {
            'recipient': recipient,
            'subject': subject,
            'body': body,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> openExternalUrl(String url) async {
    if (Uri.tryParse(url)?.scheme != 'https') return false;
    try {
      return await _channel
              .invokeMethod<bool>('openExternalUrl', {'url': url}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> launchLegacyRoomMatch({
    required List<Map<String, dynamic>> opponents,
    required bool meOwner,
    required String roomId,
    String matchMode = 'battle',
    int seriesTarget = 2,
    int roundDurationSeconds = 30,
    String myTeam = '',
    int roomRoundNumber = 1,
    String economyMatchId = '',
    bool resumeExistingGame = false,
    String seatSourceId = '',
    int initialScore = 0,
    int initialAnsweredCount = 0,
    int initialRoundWins = 0,
    int initialLivesRemaining = 0,
    bool initiallyEliminated = false,
    // Question state — used for round-based modes so joining/resuming players
    // start at the correct question, not question 0.
    List<int> questionIds = const [],
    int currentQuestionIndex = 0,
  }) async {
    final safeOpponents = opponents
        .map(
          (opponent) => <String, dynamic>{
            'id': (opponent['id'] ?? '').toString(),
            'seatId': (opponent['seatId'] ?? opponent['id'] ?? '').toString(),
            'userId': (opponent['userId'] ?? opponent['id'] ?? '').toString(),
            'name': (opponent['name'] ?? '').toString(),
            'photo': (opponent['photo'] ?? '').toString(),
            'level': (opponent['level'] as num?)?.toInt() ?? 1,
            'intelligence': (opponent['intelligence'] as num?)?.toInt() ?? 0,
            'score': (opponent['score'] as num?)?.toInt() ?? 0,
            'bot': opponent['bot'] == true,
            'teamId': (opponent['teamId'] ?? '').toString(),
            'sets': (opponent['sets'] as num?)?.toInt() ?? 0,
            'livesRemaining':
                (opponent['livesRemaining'] as num?)?.toInt() ?? 0,
            'eliminated': opponent['eliminated'] == true,
          },
        )
        .toList(growable: false);

    await _channel.invokeMethod('launchRoomMatch', <String, dynamic>{
      'roomId': roomId,
      'opponentsJson': jsonEncode(safeOpponents),
      'meOwner': meOwner,
      'matchMode': matchMode,
      'seriesTarget': seriesTarget,
      'roundDurationSeconds': roundDurationSeconds,
      'myTeam': myTeam,
      'roomRoundNumber': roomRoundNumber,
      'economyMatchId': economyMatchId,
      'resumeExistingGame': resumeExistingGame,
      'seatSourceId': seatSourceId,
      'initialScore': initialScore,
      'initialAnsweredCount': initialAnsweredCount,
      'initialRoundWins': initialRoundWins,
      'initialLivesRemaining': initialLivesRemaining,
      'initiallyEliminated': initiallyEliminated,
      'questionIds': questionIds,
      'currentQuestionIndex': currentQuestionIndex,
    });
  }

  Future<void> launchCampaignStage({
    required String campaignId,
    required String stageId,
    required String stageType,
    required List<int> questionIds,
    required List<String> allowedLevels,
    required int questionCount,
    required int timeLimitSeconds,
    required bool allow5050,
    required bool allowAudience,
    required bool allowCall,
    String bossBotName = '',
    int bossBotIntelligence = 0,
    String campaignMode = 'classic',
    String campaignEntry = 'stage',
    String winCondition = 'completeQuestions',
    int lives = 0,
    int maxWrongAnswers = 0,
    int targetScore = 0,
    String opponentName = '',
    int opponentAccuracy = 0,
    int opponentStartScore = 0,
    int seriesRounds = 0,
    int seriesWinsRequired = 0,
    String teamAllyName = '',
    String teamEnemyName = '',
    bool campaignBoard = false,
    String boardKind = 'solo',
    int boardTargetScore = 0,
    int boardTwoStarScore = 0,
    int boardThreeStarScore = 0,
    int boardSoloPicks = 6,
    int boardSoloCols = 4,
    int boardBotCount = 0,
    int boardBotIntelligence = 0,
    int boardRequiredCategoryCount = 0,
    bool boardAllowRevealOptions = true,
    int boardDesignVersion = 0,
    String bossStyle = 'balanced',
    String categoryPolicy = 'playerPick',
    List<String> worldCategories = const <String>[],
  }) async {
    await _channel.invokeMethod('launchCampaignStage', <String, dynamic>{
      'campaignId': campaignId,
      'stageId': stageId,
      'stageType': stageType,
      'campaignEntry': campaignEntry,
      'campaignMode': campaignMode,
      'winCondition': winCondition,
      'questionIds': questionIds,
      'allowedLevels': allowedLevels,
      'questionCount': questionCount,
      'timeLimitSeconds': timeLimitSeconds,
      'allow5050': allow5050,
      'allowAudience': allowAudience,
      'allowCall': allowCall,
      'bossBotName': bossBotName,
      'bossBotIntelligence': bossBotIntelligence,
      'lives': lives,
      'maxWrongAnswers': maxWrongAnswers,
      'targetScore': targetScore,
      'opponentName': opponentName,
      'opponentAccuracy': opponentAccuracy,
      'opponentStartScore': opponentStartScore,
      'seriesRounds': seriesRounds,
      'seriesWinsRequired': seriesWinsRequired,
      'teamAllyName': teamAllyName,
      'teamEnemyName': teamEnemyName,
      'campaignBoard': campaignBoard,
      'boardKind': boardKind,
      'boardTargetScore': boardTargetScore,
      'boardTwoStarScore': boardTwoStarScore,
      'boardThreeStarScore': boardThreeStarScore,
      'boardSoloPicks': boardSoloPicks,
      'boardSoloCols': boardSoloCols,
      'boardBotCount': boardBotCount,
      'boardBotIntelligence': boardBotIntelligence,
      'boardRequiredCategoryCount': boardRequiredCategoryCount,
      'boardAllowRevealOptions': boardAllowRevealOptions,
      'boardDesignVersion': boardDesignVersion,
      'bossStyle': bossStyle,
      'categoryPolicy': categoryPolicy,
      'worldCategories': worldCategories,
    });
  }

  Future<void> announceRoomSeatClaim({
    required String roomId,
    required String matchMode,
    required int roomRoundNumber,
    required String seatId,
    required String userId,
    required String username,
    required String photoUrl,
    required String teamId,
    int initialScore = 0,
    int initialRoundWins = 0,
    int initialLivesRemaining = 0,
    bool initiallyEliminated = false,
  }) async {
    await _channel.invokeMethod('announceRoomSeatClaim', <String, dynamic>{
      'roomId': roomId,
      'matchMode': matchMode,
      'roomRoundNumber': roomRoundNumber,
      'seatId': seatId,
      'userId': userId,
      'username': username,
      'photoUrl': photoUrl,
      'teamId': teamId,
      'initialScore': initialScore,
      'initialRoundWins': initialRoundWins,
      'initialLivesRemaining': initialLivesRemaining,
      'initiallyEliminated': initiallyEliminated,
    });
  }

  Future<Map<String, dynamic>?> consumePendingRoomMatchResult() async {
    final payload =
        await _channel.invokeMethod<String>('consumePendingRoomMatchResult');
    if (payload == null || payload.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return null;
  }

  Future<Map<String, dynamic>?> getPendingRoomMatchResult() async {
    final payload =
        await _channel.invokeMethod<String>('getPendingRoomMatchResult');
    if (payload == null || payload.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return null;
  }

  Future<void> clearPendingRoomMatchResult() async {
    await _channel.invokeMethod<void>('clearPendingRoomMatchResult');
  }

  Future<Map<String, dynamic>?> getPendingCampaignStageResult() async {
    try {
      final payload =
          await _channel.invokeMethod<dynamic>('getPendingCampaignStageResult');
      return _decodeCampaignResult(payload);
    } on MissingPluginException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> consumePendingCampaignStageResult() async {
    try {
      final payload = await _channel
          .invokeMethod<dynamic>('consumePendingCampaignStageResult');
      return _decodeCampaignResult(payload);
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> clearPendingCampaignStageResult() async {
    try {
      await _channel.invokeMethod<void>('clearPendingCampaignStageResult');
    } on MissingPluginException {
      return;
    }
  }

  Future<void> syncLegacyUser({
    required String uid,
    required String username,
    String? photoUrl,
  }) async {
    await _channel.invokeMethod('syncLegacyUser', <String, dynamic>{
      'uid': uid,
      'username': username,
      'photoUrl': photoUrl ?? '',
    });
  }

  Future<void> resetLegacyUser() async {
    await _channel.invokeMethod('resetLegacyUser');
  }

  Future<Map<String, dynamic>> getProgressionSnapshot() async {
    final raw = await _channel
        .invokeMapMethod<String, dynamic>('getProgressionSnapshot');
    if (raw == null) throw StateError('Native progression is unavailable');
    return raw;
  }

  Future<Map<String, dynamic>> hydrateProgression({
    required String accountUid,
    required Map<String, int> stats,
    required Map<String, int> acknowledged,
  }) async {
    final raw =
        await _channel.invokeMapMethod<String, dynamic>('hydrateProgression', {
      'accountUid': accountUid,
      'stats': stats,
      'acknowledged': acknowledged,
    });
    if (raw == null) throw StateError('Progression account changed');
    return raw;
  }

  Future<void> launchOfflineGame() async {
    await _channel.invokeMethod('launchOfflineGame');
  }

  Future<void> launchMainChallenge() async {
    await _channel.invokeMethod('launchMainChallenge');
  }

  Future<void> launchStats() async {
    await _channel.invokeMethod('launchStats');
  }

  Future<void> launchAchievements() async {
    await _channel.invokeMethod('launchAchievements');
  }

  Future<void> launchStore() async {
    await _channel.invokeMethod('launchStore');
  }

  Future<void> launchNativeSettings() async {
    await _channel.invokeMethod('launchSettings');
  }

  Future<void> launchSpeedBattle(
      {String? matchMode, String? friendCode}) async {
    await _channel.invokeMethod('launchSpeedBattle', <String, dynamic>{
      'matchMode': matchMode ?? '',
      'friendCode': friendCode ?? '',
    });
  }

  Future<void> launchRandomMatch({int? stakeCoins}) async {
    await _channel.invokeMethod('launchRandomMatch', <String, dynamic>{
      if (stakeCoins != null && stakeCoins > 0) 'stakeCoins': stakeCoins,
    });
  }

  Future<void> launchFriendChallenge({required String friendCode}) async {
    await _channel.invokeMethod('launchFriendChallenge', <String, dynamic>{
      'friendCode': friendCode,
    });
  }

  Future<void> launchStakedFriendChallenge({
    required String friendCode,
    required String matchId,
    required int stakeCoins,
  }) async {
    await _channel.invokeMethod('launchFriendChallenge', <String, dynamic>{
      'friendCode': friendCode,
      'stakeMatchId': matchId,
      'stakeCoins': stakeCoins,
    });
  }

  Future<void> playCampaignMapMusic() async {
    await _channel.invokeMethod<void>('playCampaignMapMusic');
  }

  Future<void> stopCampaignMapMusic() async {
    await _channel.invokeMethod<void>('stopCampaignMapMusic');
  }

  /// يُعيد إحصائيات اللاعب الحقيقية من PlayerStats
  Future<Map<String, int>> getPlayerStats() async {
    final result =
        await _channel.invokeMapMethod<String, dynamic>('getPlayerStats');
    if (result == null) return {};
    return result.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  /// يُعيد حالة جميع الإنجازات + عدادات التقدم الحالية.
  /// المفاتيح البوليانية هي مفاتيح الإنجازات (ACH_*)، والمفاتيح الرقمية هي إحصاءات اللاعب.
  Future<Map<String, dynamic>> getAchievements() async {
    final result =
        await _channel.invokeMapMethod<String, dynamic>('getAchievements');
    return result ?? {};
  }

  Future<void> recordCampaignAchievementProgress({
    required String accountUid,
    required String campaignId,
    required String stageId,
    required String campaignMode,
    required bool completed,
    required int stars,
    required bool bossDefeated,
    required int usedLifelines,
  }) async {
    await _channel.invokeMethod('recordCampaignAchievementProgress', {
      'accountUid': accountUid,
      'campaignId': campaignId,
      'stageId': stageId,
      'campaignMode': campaignMode,
      'completed': completed,
      'stars': stars,
      'bossDefeated': bossDefeated,
      'usedLifelines': usedLifelines,
    });
  }

  Future<Map<String, int>> claimAchievementReward(String key) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'claimAchievementReward',
      <String, dynamic>{'key': key},
    );
    if (result == null) {
      return <String, int>{
        'success': 0,
        'coins': 0,
        'xp': 0,
        'totalCoins': 0,
        'totalGems': 0,
        'totalXp': 0,
        'unclaimedAchievements': 0,
      };
    }
    return result.map((k, v) {
      if (v is bool) return MapEntry(k, v ? 1 : 0);
      return MapEntry(k, (v as num?)?.toInt() ?? 0);
    });
  }

  Future<void> hydrateAchievementClaims(
      {required String accountUid,
      required Iterable<String> unlockedIds,
      required Iterable<String> claimedIds}) async {
    final ok = await _channel.invokeMethod<bool>('hydrateAchievementClaims', {
      'accountUid': accountUid,
      'unlockedIds': unlockedIds.toList(),
      'claimedIds': claimedIds.toList(),
    });
    if (ok != true) throw StateError('Achievement receipts were not restored');
  }

  Future<Map<String, int>> claimAllAchievementRewards() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'claimAllAchievementRewards',
    );
    if (result == null) {
      return <String, int>{
        'success': 0,
        'claimedCount': 0,
        'coins': 0,
        'xp': 0,
        'totalCoins': 0,
        'totalGems': 0,
        'totalXp': 0,
        'unclaimedAchievements': 0,
      };
    }
    return result.map((k, v) {
      if (v is bool) return MapEntry(k, v ? 1 : 0);
      return MapEntry(k, (v as num?)?.toInt() ?? 0);
    });
  }

  /// يُعيد {'coins': int, 'gems': int} من SharedPreferences الـ native
  Future<Map<String, int>> getUserCurrency() async {
    final result =
        await _channel.invokeMapMethod<String, int>('getUserCurrency');
    return result ?? {'coins': 0, 'gems': 0};
  }

  Future<Map<String, dynamic>> grantCurrency({
    int coins = 0,
    int gems = 0,
    String? claimId,
  }) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'grantCurrency',
      <String, dynamic>{
        'coins': coins,
        'gems': gems,
        if (claimId != null) 'claimId': claimId,
      },
    );
    if (result == null) return {'coins': 0, 'gems': 0, 'granted': false};
    return {
      'coins': (result['coins'] as num?)?.toInt() ?? 0,
      'gems': (result['gems'] as num?)?.toInt() ?? 0,
      'granted': result['granted'] as bool? ?? true,
    };
  }

  Future<Map<String, int>> setUserCurrency({
    required int coins,
    required int gems,
    String? expectedUid,
  }) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'setUserCurrency',
      <String, dynamic>{
        'coins': coins,
        'gems': gems,
        if (expectedUid != null) 'expectedUid': expectedUid,
      },
    );
    if (result == null) {
      if (expectedUid != null) {
        throw StateError('Could not sync campaign currency');
      }
      return {'coins': 0, 'gems': 0};
    }
    return result.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  /// يُعيد قيم الإعدادات المحفوظة من Android SharedPreferences
  Future<Map<String, dynamic>> getSettings() async {
    final result =
        await _channel.invokeMapMethod<String, dynamic>('getSettings');
    return {
      'sfx': result?['sfx'] as bool? ?? true,
      'music': result?['music'] as bool? ?? false,
      'haptic': result?['haptic'] as bool? ?? true,
      'hapticAvailable': result?['hapticAvailable'] as bool? ?? true,
      'notifications': result?['notifications'] as bool? ?? true,
      'systemNotifications': result?['systemNotifications'] as bool? ?? true,
      'dialogs': result?['dialogs'] as bool? ?? true,
      'language': result?['language'] as String? ?? 'ar',
    };
  }

  Future<void> setSoundEnabled(bool enabled) async {
    await _channel.invokeMethod<void>('setSoundEnabled', {'enabled': enabled});
  }

  Future<void> setMusicEnabled(bool enabled) async {
    await _channel.invokeMethod<void>('setMusicEnabled', {'enabled': enabled});
  }

  Future<bool> setHapticEnabled(bool enabled) async {
    final result = await _channel.invokeMethod<bool>(
      'setHapticEnabled',
      {'enabled': enabled},
    );
    return result ?? false;
  }

  Future<bool> playHaptic({String style = 'light'}) async {
    final result = await _channel.invokeMethod<bool>(
      'playHaptic',
      {'style': style},
    );
    return result ?? false;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _channel
        .invokeMethod<void>('setNotificationsEnabled', {'enabled': enabled});
  }

  Future<void> setDialogsEnabled(bool enabled) async {
    await _channel
        .invokeMethod<void>('setDialogsEnabled', {'enabled': enabled});
  }

  Future<void> setLanguage(String language) async {
    await _channel.invokeMethod<void>('setLanguage', {'language': language});
  }

  Future<void> openNotificationSettings() async {
    await _channel.invokeMethod<void>('openNotificationSettings');
  }

  Future<void> resetLocalProgress({String? accountUid}) async {
    await _channel.invokeMethod<void>('resetLocalProgress', {
      if (accountUid != null) 'accountUid': accountUid,
    });
  }

  Future<bool> restorePurchases() async {
    return (await restorePurchaseState())['success'] == true;
  }

  Future<Map<String, dynamic>> restorePurchaseState() async {
    final result = await _channel.invokeMethod<dynamic>('restorePurchases');
    if (result is Map) return Map<String, dynamic>.from(result);
    return {'success': result == true};
  }

  /// يشتري عملات (كوينز) بخصم جواهر من الرصيد المحلي.
  Future<bool> buyCurrency(
      {required int coinAmount, required int gemCost}) async {
    final result = await _channel.invokeMethod<bool>(
      'buyCurrency',
      {'coinAmount': coinAmount, 'gemCost': gemCost},
    );
    return result ?? false;
  }

  /// يُعيد حالة الشخصيات المحفوظة:
  /// {'selected': int (-1 إذا لم يختر بعد), 'unlocked': List<int> الشخصيات المشتراة}.
  Future<Map<String, dynamic>> getCharacterState() async {
    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>('getCharacterState');
      final selected = (result?['selected'] as num?)?.toInt() ?? -1;
      final rawUnlocked = result?['unlocked'];
      final unlocked = <int>[];
      if (rawUnlocked is List) {
        for (final value in rawUnlocked) {
          final asInt = (value as num?)?.toInt();
          if (asInt != null) unlocked.add(asInt);
        }
      }
      return {'selected': selected, 'unlocked': unlocked};
    } on MissingPluginException {
      return {'selected': -1, 'unlocked': <int>[]};
    }
  }

  /// Reuses the native game's full-body artwork without bundling another copy.
  Future<Uint8List?> getCharacterArtwork(int index) async {
    try {
      return await _channel
          .invokeMethod<Uint8List>('getCharacterArtwork', {'index': index});
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// يحفظ فهرس الشخصية المختارة كمصدر وحيد يقرأه المحرّك في كل الأطوار.
  Future<bool> setSelectedCharacter(int index) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setSelectedCharacter',
        <String, dynamic>{'index': index},
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// يفتح شخصية مقفلة بخصم الثمن من الكوين أو الجواهر. يُعيد true عند النجاح.
  Future<bool> unlockCharacter({
    required int index,
    required String payWith, // 'coins' | 'gems'
    required int cost,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('unlockCharacter', {
        'index': index,
        'payWith': payWith,
        'cost': cost,
      });
      return result ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// يُعيد حالة الفئات المحفوظة من Android:
  /// {'unlocked': List<String>, 'rentals': Map<String, int>, 'isVip': bool}
  Future<Map<String, dynamic>> getCategoryState() async {
    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>('getCategoryState');
      final unlocked = <String>[];
      final rawUnlocked = result?['unlocked'];
      if (rawUnlocked is List) {
        for (final item in rawUnlocked) {
          if (item != null) unlocked.add(item.toString());
        }
      }
      final rentals = <String, int>{};
      final rawRentals = result?['rentals'];
      if (rawRentals is Map) {
        rawRentals.forEach((k, v) {
          final expiry = (v as num?)?.toInt() ?? 0;
          if (expiry > 0) rentals[k.toString()] = expiry;
        });
      }
      final isVip = result?['isVip'] == true;
      return {
        'unlocked': unlocked,
        'rentals': rentals,
        'isVip': isVip,
      };
    } on MissingPluginException {
      return {
        'unlocked': <String>[],
        'rentals': <String, int>{},
        'isVip': false
      };
    } catch (_) {
      return {
        'unlocked': <String>[],
        'rentals': <String, int>{},
        'isVip': false
      };
    }
  }

  /// يفتح فئة مقفلة بشكل دائم بخصم الجواهر من رصيد اللاعب
  Future<bool> unlockCategoryPermanently(String category,
      {int gemCost = 150}) async {
    try {
      final result = await _channel.invokeMethod<bool>('unlockCategory', {
        'category': category,
        'gemCost': gemCost,
      });
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Legacy signature: a completed ad now issues one category-bound match permit.
  Future<bool> rentCategory(String category, {int hours = 24}) async {
    try {
      await economy({'action': 'ad', 'category': category});
      return true;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// يُعيّن حالة الفئات المفتوحة والـ VIP للنسخة الأصلية عند تسجيل دخول مستخدم
  Future<bool> setCategoryState({
    required List<String> unlocked,
    required bool isVip,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('setCategoryState', {
        'unlocked': unlocked,
        'isVip': isVip,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// يُعيّن الشخصيات المفتوحة والمختارة للنسخة الأصلية عند تسجيل دخول مستخدم
  Future<bool> setCharacterState({
    required int selected,
    required List<int> unlocked,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('setCharacterState', {
        'selected': selected,
        'unlocked': unlocked,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic>? _decodeCampaignResult(dynamic raw) {
    final decoded = _decodeNativeMap(raw);
    if (decoded == null) return null;
    final mode = decoded['mode'];
    if (mode != null && mode.toString() != 'campaign') return null;
    return decoded;
  }

  Map<String, dynamic>? _decodeNativeMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      if (raw.trim().isEmpty) return null;
      try {
        return _decodeNativeMap(jsonDecode(raw));
      } on Object {
        return null;
      }
    }
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return null;
  }

  Future<Map<String, dynamic>> launchBilling(String productId) async {
    try {
      final res =
          await _channel.invokeMapMethod<String, dynamic>('launchBilling', {
        'productId': productId,
      });
      return res ?? {'success': false, 'message': 'Unknown response'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getBillingProducts() async {
    final result =
        await _channel.invokeMapMethod<String, dynamic>('getBillingProducts');
    return result ?? {'available': false, 'products': <dynamic>[]};
  }

  Future<Map<String, dynamic>> getCommerceState() async {
    try {
      return await _channel
              .invokeMapMethod<String, dynamic>('getCommerceState') ??
          <String, dynamic>{};
    } on MissingPluginException {
      return <String, dynamic>{};
    }
  }

  Future<bool> manageSubscriptions() async {
    try {
      return await _channel.invokeMethod<bool>('manageSubscriptions') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> syncCommerceDeliveryIds(List<String> deliveryIds) async {
    await _channel.invokeMethod<void>(
        'syncCommerceDeliveryIds', {'appliedDeliveryIds': deliveryIds});
  }

  Future<void> confirmCommerceSnapshot(List<String> deliveryIds,
      {required String accountUid}) async {
    await _channel.invokeMethod<dynamic>('confirmCommerceSnapshot',
        {'appliedDeliveryIds': deliveryIds, 'accountUid': accountUid});
  }

  Future<bool> hydrateCommerceWallet(
      {required String accountUid,
      required int coins,
      required int gems,
      int? referralRevision,
      required List<String> deliveryIds}) async {
    return await _channel.invokeMethod<bool>('hydrateCommerceWallet', {
          'accountUid': accountUid,
          'coins': coins,
          'gems': gems,
          if (referralRevision != null) 'referralRevision': referralRevision,
          'appliedDeliveryIds': deliveryIds,
        }) ??
        false;
  }

  Future<bool> isBillingAvailable() async {
    try {
      final res = await _channel.invokeMethod<bool>('isBillingAvailable');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> initBilling() async {
    try {
      await _channel.invokeMethod('initBilling');
    } catch (_) {}
  }
}
