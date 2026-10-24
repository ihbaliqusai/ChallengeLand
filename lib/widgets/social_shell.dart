import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_state.dart';
import '../services/online_match_flow.dart';
import '../services/social_service.dart';
import 'game_notice.dart';

/// Receives invitations on every Flutter route, and starts the existing native
/// duel on BOTH devices after the recipient's atomic acceptance.
class SocialShell extends StatefulWidget {
  const SocialShell({super.key, required this.child});
  final Widget child;
  @override
  State<SocialShell> createState() => _SocialShellState();
}

class _SocialShellState extends State<SocialShell> with WidgetsBindingObserver {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _friendSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _blockSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _presenceSubscription;
  Timer? _timer;
  String? _uid;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _requests = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _friendRequests = [];
  final _dismissedFriends = <String>{};
  bool _foreground = true;
  bool _working = false;
  bool _choosingMatch = false;
  final _handled = <String>{};
  String? _error;
  Set<String> _blocked = {};
  Map<String, dynamic>? _presence;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        context.read<SocialService>().syncClock();
        setState(() {});
        _launchAccepted();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AppState>().currentUser;
    final uid = user == null || user.isAnonymous ? null : user.uid;
    if (_uid == uid) return;
    _subscription?.cancel();
    _friendSubscription?.cancel();
    _blockSubscription?.cancel();
    _presenceSubscription?.cancel();
    _uid = uid;
    _requests = [];
    _friendRequests = [];
    _dismissedFriends.clear();
    _handled.clear();
    _error = null;
    _blocked = {};
    _presence = null;
    if (uid != null) {
      final service = context.read<SocialService>();
      _friendSubscription = service.links(uid).listen((snapshot) {
        if (!mounted || _uid != uid) return;
        setState(() => _friendRequests =
            snapshot.docs.where((d) => !d.metadata.hasPendingWrites).toList());
      }, onError: (Object _) {
        if (mounted && _uid == uid) setState(() => _friendRequests = []);
      });
      service.syncClock();
      _blockSubscription = service.blocks(uid).listen((snapshot) {
        if (mounted && _uid == uid) {
          setState(() => _blocked = snapshot.docs
              .map((d) => d.data()['targetUid'] as String)
              .toSet());
        }
      }, onError: (Object _) {});
      _presenceSubscription = service.presence(uid).listen((snapshot) {
        if (mounted && _uid == uid) setState(() => _presence = snapshot.data());
      }, onError: (Object _) {});
      _subscription =
          context.read<SocialService>().challenges(uid).listen((snapshot) {
        if (!mounted || _uid != uid) return;
        setState(() => _requests =
            snapshot.docs.where((d) => !d.metadata.hasPendingWrites).toList());
        _launchAccepted();
      }, onError: (Object error) {
        // The social feature must not interrupt startup or offline gameplay.
        if (mounted && _uid == uid) setState(() => _requests = []);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _launchAccepted();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _friendSubscription?.cancel();
    _blockSubscription?.cancel();
    _presenceSubscription?.cancel();
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<bool> _prepareMatch(String uid, {String? matchId}) async {
    setState(() => _choosingMatch = true);
    try {
      return await OnlineMatchFlow.prepare(context, uid, matchId: matchId);
    } finally {
      if (mounted) setState(() => _choosingMatch = false);
    }
  }

  Future<void> _launchAccepted() async {
    if (_working || !_foreground || _uid == null || !mounted) return;
    final uid = _uid!;
    final now = context.read<SocialService>().now;
    final accepted = _requests.where((d) {
      final data = d.data();
      final at = data['acceptedAt'];
      return data['status'] == 'accepted' &&
          at is Timestamp &&
          now.difference(at.toDate()).inSeconds >= -10 &&
          now.difference(at.toDate()).inSeconds < 30 &&
          !_handled.contains('${d.id}:${at.millisecondsSinceEpoch}');
    });
    if (accepted.isEmpty) return;
    _working = true;
    final request = accepted.first;
    final data = request.data();
    final token =
        '${request.id}:${(data['acceptedAt'] as Timestamp).millisecondsSinceEpoch}';
    final service = context.read<SocialService>();
    final app = context.read<AppState>();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || _uid != uid) return;
      final history = prefs.getStringList('social_launched_$uid') ?? [];
      if (history.contains(token)) {
        _handled.add(token);
        return;
      }
      final lock =
          await service.db.collection('social_reservations').doc(uid).get();
      if (lock.data()?['challengeId'] != request.id ||
          lock.data()?['acceptedAt'] != data['acceptedAt']) {
        return;
      }
      final peer =
          (data['fromUid'] == uid ? data['toUid'] : data['fromUid']) as String;
      final profile = await service.profile(peer);
      final code = profile['friendCode']?.toString() ?? '';
      if (code.isEmpty) throw const SocialException('لم يتوفر رمز اللاعب.');
      if (!mounted) return;
      if (!await _prepareMatch(uid,
          matchId: data['stakeMatchId']?.toString())) {
        _handled.add(token);
        return;
      }
      final age =
          service.now.difference((data['acceptedAt'] as Timestamp).toDate());
      if (!mounted ||
          age >= const Duration(seconds: 30) ||
          _uid != uid ||
          !_foreground ||
          app.currentUser?.uid != uid) {
        return;
      }
      // Persist before crossing the native boundary: lifecycle changes must not
      // replay the same invitation. A failed bridge call restores retryability.
      history.add(token);
      await prefs.setStringList('social_launched_$uid',
          history.length > 40 ? history.sublist(history.length - 40) : history);
      _handled.add(token);
      try {
        final stake = SocialService.stakeCoins(data);
        if (data['serverStake'] == true) {
          final matchId = data['stakeMatchId']?.toString() ?? '';
          if (matchId.isEmpty || !SocialService.stakeAmounts.contains(stake)) {
            throw const SocialException('بيانات تحدي القطع غير مكتملة.');
          }
          await app.openStakedFriendChallenge(code,
              matchId: matchId, stakeCoins: stake);
        } else {
          await app.openFriendChallenge(code);
        }
      } catch (_) {
        _handled.remove(token);
        history.remove(token);
        await prefs.setStringList('social_launched_$uid', history);
        rethrow;
      }
      if (mounted && _uid == uid) setState(() => _error = null);
    } catch (_) {
      // Keep retry explicit; do not open a new Activity every timer tick.
      if (_uid == uid) _handled.add(token);
      if (mounted && _uid == uid) {
        setState(() => _error = 'تعذر فتح المواجهة. حاول إرسال دعوة جديدة.');
      }
    } finally {
      _working = false;
    }
  }

  Future<void> _respond(String id, String status,
      {bool challenge = true, int stakeCoins = 0}) async {
    if (_working || _uid == null) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final service = context.read<SocialService>();
      if (challenge && status == 'accepted' && !await _prepareMatch(_uid!)) {
        return;
      }
      if (challenge && stakeCoins > 0) {
        await service.respondStakedChallenge(id, status,
            expectedAmount: stakeCoins);
      } else {
        await service.respond(_uid!, id, status, challenge: challenge);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is SocialException
            ? error.message
            : 'تعذر تحديث الدعوة. حاول مجددًا.');
      }
    } finally {
      if (mounted) setState(() => _working = false);
      _launchAccepted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final incoming = _requests.where((d) =>
        d.data()['toUid'] == _uid &&
        !_blocked.contains(d.data()['fromUid']) &&
        SocialService.pending(d.data(), context.read<SocialService>().now));
    final outgoing = _requests.where((d) =>
        d.data()['fromUid'] == _uid &&
        !_blocked.contains(d.data()['toUid']) &&
        SocialService.pending(d.data(), context.read<SocialService>().now));
    final friends = _friendRequests.where((d) =>
        d.data()['toUid'] == _uid &&
        !_blocked.contains(d.data()['fromUid']) &&
        !_dismissedFriends.contains('${d.id}:${d.data()['createdAt']}') &&
        SocialService.pending(d.data(), context.read<SocialService>().now));
    final challengeRequest = incoming.isNotEmpty
        ? incoming.first
        : outgoing.isNotEmpty
            ? outgoing.first
            : null;
    final canShowChallenge = _presence?['state'] == 'available';
    final request = canShowChallenge && challengeRequest != null
        ? challengeRequest
        : friends.isNotEmpty
            ? friends.first
            : null;
    final isFriend = request != null &&
        request == (friends.isNotEmpty ? friends.first : null);
    final isIncoming = request?.data()['toUid'] == _uid;
    final stakeCoins = request == null || isFriend
        ? 0
        : SocialService.stakeCoins(request.data());
    final remaining = request == null
        ? 0
        : (request.data()['expiresAt'] as Timestamp)
            .toDate()
            .difference(context.read<SocialService>().now)
            .inSeconds
            .clamp(0, 30);
    final tone = request == null
        ? GameNoticeTone.error
        : isFriend
            ? GameNoticeTone.friend
            : GameNoticeTone.challenge;
    return Stack(children: [
      widget.child,
      if (_foreground && !_choosingMatch && (request != null || _error != null))
        Positioned.fill(
          child: Stack(children: [
            const ModalBarrier(color: Color(0xB3070B19), dismissible: false),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 16, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
                child: Center(
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Semantics(
                      scopesRoute: true,
                      explicitChildNodes: true,
                      child: GameNoticeCard(
                        key: ValueKey('socialNotice:${request?.id ?? 'error'}'),
                        tone: tone,
                        title: Text(request == null
                            ? 'تعذّر فتح المواجهة'
                            : isFriend
                                ? 'طلب صداقة جديد'
                                : isIncoming
                                    ? 'دعوة إلى التحدي'
                                    : 'تم إرسال الدعوة'),
                        onClose: _working
                            ? null
                            : isFriend
                                ? () => setState(() => _dismissedFriends.add(
                                    '${request.id}:${request.data()['createdAt']}'))
                                : request == null
                                    ? () => setState(() => _error = null)
                                    : null,
                        busy: _working,
                        progress: request != null && !isFriend
                            ? remaining / 30
                            : null,
                        content:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          if (request != null)
                            FutureBuilder<Map<String, dynamic>>(
                              future: context.read<SocialService>().profile(
                                  request.data()[isIncoming
                                      ? 'fromUid'
                                      : 'toUid'] as String),
                              builder: (context, snapshot) => Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isFriend
                                        ? '${snapshot.data?['username'] ?? 'لاعب'} أرسل لك طلب صداقة'
                                        : isIncoming
                                            ? '${snapshot.data?['username'] ?? 'لاعب'} يدعوك لمواجهة'
                                            : 'بانتظار قبول ${snapshot.data?['username'] ?? 'اللاعب'}',
                                    textAlign: TextAlign.center,
                                  ),
                                  if (!isFriend) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color:
                                            tone.color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text('متبقي $remaining ثانية',
                                          style: TextStyle(
                                              color: tone.color,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          if (stakeCoins > 0) ...[
                            const SizedBox(height: 12),
                            Text(
                                SocialService.stakeDescription(request!.data()),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Color(0xFFFFD166),
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            const Text(
                                'التعادل أو خلل المباراة يعيد القطع. الانسحاب بعد البدء خسارة.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11)),
                          ],
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Color(0xFFFDA4AF))),
                            ),
                        ]),
                        actions: [
                          if (request != null && isIncoming) ...[
                            FilledButton(
                              onPressed: _working
                                  ? null
                                  : () => _respond(request.id, 'accepted',
                                      challenge: !isFriend,
                                      stakeCoins: stakeCoins),
                              child: Text(stakeCoins > 0
                                  ? 'قبول بـ$stakeCoins قطعة'
                                  : 'قبول'),
                            ),
                            OutlinedButton(
                              onPressed: _working
                                  ? null
                                  : () => _respond(request.id, 'declined',
                                      challenge: !isFriend,
                                      stakeCoins: stakeCoins),
                              child: const Text('رفض'),
                            ),
                          ],
                          if (request != null && !isIncoming)
                            OutlinedButton(
                              onPressed: _working
                                  ? null
                                  : () => _respond(request.id, 'cancelled',
                                      stakeCoins: stakeCoins),
                              child: const Text('إلغاء الدعوة'),
                            ),
                          if (isFriend)
                            TextButton(
                              key: const ValueKey('dismissFriendRequest'),
                              onPressed: _working
                                  ? null
                                  : () => setState(() => _dismissedFriends.add(
                                      '${request.id}:${request.data()['createdAt']}')),
                              child: const Text('لاحقًا'),
                            ),
                          if (request == null)
                            FilledButton(
                              onPressed: () => setState(() => _error = null),
                              child: const Text('حسنًا'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
    ]);
  }
}
