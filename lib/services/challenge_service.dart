import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_config.dart';
import '../core/constants/firestore_collections.dart';
import '../models/challenge_card.dart';

class ChallengeService {
  ChallengeService({FirebaseFirestore? firestore, Random? random})
    : _firestore = firestore,
      _random = random ?? Random();

  final FirebaseFirestore? _firestore;
  final Random _random;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  List<ChallengeCard>? _cachedCards;

  // ===== تحميل البطاقات =====

  Future<List<ChallengeCard>> loadAllCards() async {
    if (_cachedCards != null) return _cachedCards!;
    _cachedCards = AppConfig.useMockData
        ? await _loadFromJson()
        : await _loadFromFirestore();
    return _cachedCards!;
  }

  Future<List<ChallengeCard>> _loadFromJson() async {
    final text = await rootBundle.loadString(
      'assets/sample_data/challenge_cards.json',
    );
    final data = jsonDecode(text) as Map<String, dynamic>;
    final list = data['cards'] as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(ChallengeCard.fromJson)
        .where((card) => card.isActive)
        .toList(growable: false);
  }

  Future<List<ChallengeCard>> _loadFromFirestore() async {
    final snapshot = await _db
        .collection(FirestoreCollections.challengeCards)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs
        .map((doc) => ChallengeCard.fromJson({...doc.data(), 'id': doc.id}))
        .toList(growable: false);
  }

  // ===== بناء حزمة لجلسة لعب =====

  /// يجلب [count] بطاقة مخلوطة عشوائياً مع تطبيق الفلاتر الاختيارية.
  Future<List<ChallengeCard>> getDeckForSession({
    int count = 10,
    List<String>? categoryIds,
    List<ChallengeCardType>? types,
    ChallengeDifficulty? difficulty,
  }) async {
    var cards = await loadAllCards();

    if (categoryIds != null && categoryIds.isNotEmpty) {
      cards = cards.where((c) => categoryIds.contains(c.categoryId)).toList();
    }
    if (types != null && types.isNotEmpty) {
      cards = cards.where((c) => types.contains(c.type)).toList();
    }
    if (difficulty != null) {
      cards = cards.where((c) => c.difficulty == difficulty).toList();
    }

    final shuffled = List<ChallengeCard>.from(cards)..shuffle(_random);
    return shuffled
        .take(count.clamp(1, shuffled.length))
        .toList(growable: false);
  }

  // ===== فلاتر مساعدة =====

  Future<List<ChallengeCard>> getCardsByType(
    ChallengeCardType type, {
    int? limit,
  }) async {
    final all = await loadAllCards();
    final filtered = all.where((c) => c.type == type).toList()
      ..shuffle(_random);
    return limit == null
        ? filtered
        : filtered.take(limit).toList(growable: false);
  }

  Future<List<ChallengeCard>> getCardsByCategory(
    String categoryId, {
    int? limit,
  }) async {
    final all = await loadAllCards();
    final filtered = all.where((c) => c.categoryId == categoryId).toList()
      ..shuffle(_random);
    return limit == null
        ? filtered
        : filtered.take(limit).toList(growable: false);
  }

  Future<ChallengeCard?> getRandomCard({
    String? categoryId,
    ChallengeCardType? type,
    ChallengeDifficulty? difficulty,
  }) async {
    final deck = await getDeckForSession(
      count: 1,
      categoryIds: categoryId != null ? [categoryId] : null,
      types: type != null ? [type] : null,
      difficulty: difficulty,
    );
    return deck.isEmpty ? null : deck.first;
  }

  // ===== التحقق من الإجابات =====

  /// للسؤال والحرف: هل الإجابة صحيحة؟
  bool checkAnswer(ChallengeCard card, String playerAnswer) =>
      card.isCorrectAnswer(playerAnswer);

  /// للرابط: هل رابط اللاعب صحيح؟
  bool checkLinkAnswer(ChallengeCard card, String playerAnswer) =>
      card.isCorrectLinkAnswer(playerAnswer);

  /// للوصف والتمثيل: يحكم المضيف، دائماً نُعيد true ليقرر المضيف
  bool isJudgedByHost(ChallengeCard card) =>
      card.type == ChallengeCardType.describe ||
      card.type == ChallengeCardType.act;

  // ===== إحصاءات =====

  Future<List<String>> getAvailableCategories() async {
    final cards = await loadAllCards();
    return cards.map((c) => c.categoryId).toSet().toList()..sort();
  }

  Future<Map<String, int>> getCardStats() async {
    final cards = await loadAllCards();
    final stats = <String, int>{'total': cards.length};
    for (final card in cards) {
      stats['type_${card.type.name}'] =
          (stats['type_${card.type.name}'] ?? 0) + 1;
      stats['cat_${card.categoryId}'] =
          (stats['cat_${card.categoryId}'] ?? 0) + 1;
      stats['diff_${card.difficulty.name}'] =
          (stats['diff_${card.difficulty.name}'] ?? 0) + 1;
    }
    return stats;
  }

  // ===== Cache =====

  void clearCache() => _cachedCards = null;
}
