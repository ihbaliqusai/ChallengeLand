import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player_profile.dart';
import '../models/legacy_room.dart';

enum InviteType {
  friendChallenge,
  room,
}

class InviteCandidate {
  const InviteCandidate({
    required this.type,
    required this.code,
    required this.title,
    required this.subtitle,
    required this.rawText,
    this.senderName,
    this.senderPhoto,
    this.senderLevel,
    this.roomMode,
    this.roomPlayerCount,
    this.roomMaxPlayers,
  });

  final InviteType type;
  final String code;
  final String title;
  final String subtitle;
  final String rawText;
  final String? senderName;
  final String? senderPhoto;
  final int? senderLevel;
  final String? roomMode;
  final int? roomPlayerCount;
  final int? roomMaxPlayers;
}

class RoomPreview {
  const RoomPreview({
    required this.id,
    required this.mode,
    required this.hostName,
    required this.playerCount,
    required this.maxPlayers,
    required this.isWaiting,
    required this.isFull,
  });

  final String id;
  final String mode;
  final String hostName;
  final int playerCount;
  final int maxPlayers;
  final bool isWaiting;
  final bool isFull;
}

class InviteService {
  InviteService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _kDismissedInvitesKey = 'dismissed_invite_codes_v2';
  static const String _kRecentOpponentsKey = 'recent_opponents_v1';
  static const int _kMaxRecentOpponents = 12;

  // ── SharedPreferences Handling ──────────────────────────────────────────────

  Future<Set<String>> _getDismissedCodes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kDismissedInvitesKey) ?? <String>[];
      return list.toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> dismissInviteCode(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final set =
          (prefs.getStringList(_kDismissedInvitesKey) ?? <String>[]).toSet();
      set.add(clean);
      // Keep set bounded to last 100 codes
      final trimmedList = set.toList();
      if (trimmedList.length > 100) {
        trimmedList.removeRange(0, trimmedList.length - 100);
      }
      await prefs.setStringList(_kDismissedInvitesKey, trimmedList);
    } catch (_) {}
  }

  Future<bool> isInviteDismissed(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return true;
    final set = await _getDismissedCodes();
    return set.contains(clean);
  }

  // ── Code Extraction ─────────────────────────────────────────────────────────

  String extractFriendCode(String text) {
    if (text.isEmpty) return '';
    final trimmed = text.trim();

    // Direct exact code
    if (RegExp(r'^(?:CL-)?[A-Za-z0-9]{4,15}$', caseSensitive: false)
        .hasMatch(trimmed)) {
      return trimmed
          .replaceAll(RegExp(r'^CL-', caseSensitive: false), '')
          .toUpperCase();
    }

    // Match labeled code
    final match = RegExp(
      r'(?:كود التحدي(?: الخاص بي)?|كود الصديق|كود|code)[:\s\n`]*([A-Za-z0-9]{4,15})',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim().toUpperCase();
    }

    // Check inside word boundaries
    final words =
        text.replaceAll(RegExp(r'https?://[^\s]+'), '').split(RegExp(r'\s+'));
    for (final word in words) {
      final clean = word.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      if (clean.length >= 6 && clean.length <= 12) {
        return clean.toUpperCase();
      }
    }
    return '';
  }

  String extractRoomId(String text) {
    if (text.isEmpty) return '';
    final match = RegExp(
      r'(?:رمز الغرفة|كود الغرفة|room(?:Id)?|غرفة)[:\s\n`]*([A-Za-z0-9_-]{6,30})',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
    return '';
  }

  // ── Pre-Validation ──────────────────────────────────────────────────────────

  /// Verifies if a friend code actually belongs to a registered player in Firestore.
  Future<PlayerProfile?> verifyFriendCode(
    String friendCode, {
    required String myFriendCode,
    required String myUid,
  }) async {
    final clean = friendCode.trim().toUpperCase();
    if (clean.isEmpty) return null;
    if (clean == myFriendCode.toUpperCase() || clean == myUid.toUpperCase()) {
      return null;
    }

    try {
      // 1. Check public_profiles by friendCode field
      final queryByCode = await _firestore
          .collection('public_profiles')
          .where('friendCode', isEqualTo: clean)
          .limit(1)
          .get();

      if (queryByCode.docs.isNotEmpty) {
        final doc = queryByCode.docs.first;
        final profile = PlayerProfile.fromMap(doc.data());
        if (profile.uid.isNotEmpty && profile.uid != myUid) {
          return profile;
        }
      }

      // 2. Check public_profiles by direct UID
      final directDoc =
          await _firestore.collection('public_profiles').doc(clean).get();
      if (directDoc.exists && directDoc.data() != null) {
        final profile = PlayerProfile.fromMap(directDoc.data()!);
        if (profile.uid.isNotEmpty && profile.uid != myUid) {
          return profile;
        }
      }

      // 3. Check public_profiles where UID starts with this friend code
      // (Since friendCode is derived from the first 10 uppercase chars of UID)
      final rangeQuery = await _firestore
          .collection('public_profiles')
          .orderBy('uid')
          .startAt([clean.toLowerCase()])
          .endAt(['${clean.toLowerCase()}\uf8ff'])
          .limit(1)
          .get();

      if (rangeQuery.docs.isNotEmpty) {
        final doc = rangeQuery.docs.first;
        final profile = PlayerProfile.fromMap(doc.data());
        if (profile.uid.isNotEmpty && profile.uid != myUid) {
          return profile;
        }
      }

      // 4. Also check users collection as fallback
      final userDoc = await _firestore.collection('users').doc(clean).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        return PlayerProfile.fromMap({...data, 'uid': userDoc.id});
      }
    } catch (e) {
      if (kDebugMode) {
        print('InviteService.verifyFriendCode error: $e');
      }
    }

    return null;
  }

  /// Verifies if a room exists and is currently in waiting status.
  Future<RoomPreview?> verifyRoom(String roomId) async {
    final clean = roomId.trim();
    if (clean.isEmpty) return null;

    try {
      final doc = await _firestore.collection('rooms').doc(clean).get();
      if (!doc.exists || doc.data() == null) return null;

      final room = Room.fromSnapshot(doc);

      if (room.phase == Room.phaseFinished) {
        return null;
      }

      final hostName = (room.roomName != null && room.roomName!.isNotEmpty)
          ? room.roomName!
          : 'المضيف';
      final isWaiting = room.phase == Room.phaseLobby && !room.started;
      return RoomPreview(
        id: room.id,
        mode: room.mode,
        hostName: hostName,
        playerCount: room.players.length,
        maxPlayers: room.maxPlayers,
        isWaiting: isWaiting,
        isFull: room.isFull,
      );
    } catch (e) {
      if (kDebugMode) {
        print('InviteService.verifyRoom error: $e');
      }
      return null;
    }
  }

  // ── Smart Clipboard Inspection ──────────────────────────────────────────────

  /// Inspects system clipboard and returns an InviteCandidate ONLY if valid and not previously dismissed.
  Future<InviteCandidate?> inspectClipboardInvite({
    required String myFriendCode,
    required String myUid,
  }) async {
    try {
      final clipData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipData?.text == null || clipData!.text!.trim().isEmpty) {
        return null;
      }

      final text = clipData.text!.trim();

      // Check if this full text or its code is already dismissed
      if (await isInviteDismissed(text)) {
        return null;
      }

      // 1. Check for Room invite first if text mentions room
      if (text.contains('غرف') || text.contains('room')) {
        final roomId = extractRoomId(text);
        if (roomId.isNotEmpty) {
          if (await isInviteDismissed(roomId)) return null;

          final roomPreview = await verifyRoom(roomId);
          if (roomPreview != null && !roomPreview.isFull) {
            return InviteCandidate(
              type: InviteType.room,
              code: roomPreview.id,
              title: '🏆 دعوة انضمام لغرفة جماعية!',
              subtitle:
                  'المضيف: ${roomPreview.hostName} • ${roomPreview.playerCount}/${roomPreview.maxPlayers} لاعبين',
              rawText: text,
              senderName: roomPreview.hostName,
              roomMode: roomPreview.mode,
              roomPlayerCount: roomPreview.playerCount,
              roomMaxPlayers: roomPreview.maxPlayers,
            );
          } else {
            // Room does not exist or expired -> permanently dismiss so we never check it again
            await dismissInviteCode(roomId);
            await dismissInviteCode(text);
            return null;
          }
        }
      }

      // 2. Check for Friend Challenge code
      final isFriendMsg = text.contains('تحدي') ||
          text.contains('كود') ||
          text.contains('ChallengeLand') ||
          RegExp(r'^(?:CL-)?[A-Za-z0-9]{6,12}$', caseSensitive: false)
              .hasMatch(text);

      if (isFriendMsg) {
        final code = extractFriendCode(text);
        if (code.isNotEmpty && code != myFriendCode && code != myUid) {
          if (await isInviteDismissed(code)) return null;

          final profile = await verifyFriendCode(
            code,
            myFriendCode: myFriendCode,
            myUid: myUid,
          );

          if (profile != null) {
            return InviteCandidate(
              type: InviteType.friendChallenge,
              code: code,
              title: '⚔️ دعوة تحدي 1 ضد 1 من صديق!',
              subtitle: '${profile.username} يتحداك الآن في أرض التحدي',
              rawText: text,
              senderName: profile.username,
              senderPhoto: profile.photoUrl,
              senderLevel: profile.level,
            );
          } else {
            // Not a real registered user -> permanently dismiss so we never alert the user!
            await dismissInviteCode(code);
            await dismissInviteCode(text);
            return null;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('InviteService.inspectClipboardInvite error: $e');
      }
    }

    return null;
  }

  // ── Recent Opponents Tracking ───────────────────────────────────────────────

  Future<List<PlayerProfile>> getRecentOpponents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kRecentOpponentsKey);
      if (raw == null || raw.isEmpty) return <PlayerProfile>[];

      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => PlayerProfile.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <PlayerProfile>[];
    }
  }

  Future<void> saveRecentOpponent(PlayerProfile profile) async {
    if (profile.uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getRecentOpponents();

      // Remove existing occurrence if any
      current.removeWhere((p) => p.uid == profile.uid);

      // Add to front
      current.insert(0, profile);

      // Keep up to max limit
      if (current.length > _kMaxRecentOpponents) {
        current.removeRange(_kMaxRecentOpponents, current.length);
      }

      final encoded = jsonEncode(current.map((p) => p.toMap()).toList());
      await prefs.setString(_kRecentOpponentsKey, encoded);
    } catch (_) {}
  }

  // ── Formatted Share Messages ────────────────────────────────────────────────

  static String buildFriendInviteShareMessage({
    required String code,
    required String playerName,
  }) {
    return '⚔️ *أرض التحدي | دعوة مواجهة خاصة 1 ضد 1* ⚔️\n\n'
        '👑 اللاعب *$playerName* أرسل لك دعوة تحدي معرفي حاسم ومثير!\n'
        'هل تقبل التحدي وتثبت جدارتك على ساحة الأبطال؟\n\n'
        '🔑 *كود التحدي المباشر:*\n`$code`\n\n'
        '📲 *رابط تحميل وفتح اللعبة مباشرة:*\n'
        'https://play.google.com/store/apps/details?id=com.qi7bali.landchallengeonline\n\n'
        '⚡ *طريقة الانضمام السريع:*\n'
        'انسخ الكود أعلاه وافتح اللعبة، وسيظهر لك التحدي تلقائياً للبدء فوراً!';
  }

  static String buildRoomInviteShareMessage({
    required String roomId,
    required String hostName,
    required String modeName,
    required int maxPlayers,
  }) {
    return '🏆 *أرض التحدي | دعوة انضمام لغرفة جماعية* 🏆\n\n'
        '👑 المضيف: *$hostName*\n'
        '🎯 طور اللعب: *$modeName* (سعة $maxPlayers لاعبين)\n\n'
        '🔑 *رمز الغرفة:*\n`$roomId`\n\n'
        '📲 *رابط تحميل وفتح اللعبة مباشرة:*\n'
        'https://play.google.com/store/apps/details?id=com.qi7bali.landchallengeonline\n\n'
        '⚡ *طريقة الانضمام:*\n'
        'انسخ الرمز أعلاه وافتح اللعبة، وسيتم التعرف على الغرفة تلقائياً!';
  }

  static String translateRoomMode(String mode) {
    switch (mode) {
      case 'team_battle':
        return 'حرب الفرق';
      case 'elimination':
        return 'إقصاء المليون';
      case 'blitz':
        return 'صراع السرعة';
      case 'survival':
        return 'البقاء للأذكى';
      case 'series':
        return 'سلسلة جولات';
      case 'battle':
      default:
        return 'تحدي جماعي';
    }
  }
}
