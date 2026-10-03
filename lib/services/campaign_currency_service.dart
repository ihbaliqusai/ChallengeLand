import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Saves campaign currency and its receipt together so interrupted deliveries
/// can be retried safely, including from another device or service instance.
class CampaignCurrencyService {
  CampaignCurrencyService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const int maxBalance = 2147483647;

  Future<bool> hasClaimed(
      {required String uid, required String claimId}) async {
    final playerId = _playerId(uid);
    final receiptId = _receiptId(claimId);
    final snapshot = await _firestore.collection('users').doc(playerId).get();
    return _receiptIds(snapshot.data()?['appliedCampaignCurrencyClaimIds'])
        .contains(receiptId);
  }

  Future<Map<String, int>> grant({
    required String uid,
    required String claimId,
    required int coins,
    required int gems,
    int fallbackCoins = 0,
    int fallbackGems = 0,
  }) async {
    final playerId = _playerId(uid);
    final receiptId = _receiptId(claimId);
    if (coins < 0 || gems < 0) {
      throw ArgumentError('Campaign currency rewards must be nonnegative');
    }

    final userRef = _firestore.collection('users').doc(playerId);
    return _firestore.runTransaction<Map<String, int>>((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data() ?? const <String, dynamic>{};
      final currentCoins = _balance(data['coins'], fallbackCoins);
      final currentGems = _balance(data['gems'], fallbackGems);
      final receiptIds = _receiptIds(data['appliedCampaignCurrencyClaimIds']);
      if (receiptIds.contains(receiptId)) {
        return <String, int>{'coins': currentCoins, 'gems': currentGems};
      }

      final balances = <String, int>{
        'coins':
            math.min(maxBalance, currentCoins + math.min(maxBalance, coins)),
        'gems': math.min(maxBalance, currentGems + math.min(maxBalance, gems)),
      };
      transaction.set(
        userRef,
        <String, dynamic>{
          ...balances,
          'appliedCampaignCurrencyClaimIds': [...receiptIds, receiptId],
        },
        SetOptions(merge: true),
      );
      return balances;
    });
  }

  int _balance(dynamic value, int fallback) {
    final parsed = value is int
        ? value
        : value is num && value.isFinite
            ? value.toInt()
            : value is String
                ? int.tryParse(value.trim())
                : null;
    return (parsed != null && parsed >= 0 ? parsed : fallback)
        .clamp(0, maxBalance);
  }

  String _playerId(String uid) {
    final playerId = uid.trim();
    if (playerId.isEmpty ||
        playerId.contains('/') ||
        playerId == '.' ||
        playerId == '..') {
      throw ArgumentError.value(uid, 'uid', 'A valid player ID is required');
    }
    return playerId;
  }

  String _receiptId(String claimId) {
    final receiptId = claimId.trim();
    if (receiptId.isEmpty) {
      throw ArgumentError.value(
          claimId, 'claimId', 'A reward receipt is required');
    }
    return receiptId;
  }

  Set<String> _receiptIds(dynamic value) {
    return value is List
        ? value
            .whereType<String>()
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
        : <String>{};
  }
}
