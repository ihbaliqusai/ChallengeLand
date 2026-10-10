import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_state.dart';
import '../services/social_service.dart';

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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _blockSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _presenceSubscription;
  Timer? _timer;
  String? _uid;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _requests = [];
  bool _foreground = true;
  bool _working = false;
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
    _blockSubscription?.cancel();
    _presenceSubscription?.cancel();
    _uid = uid;
    _requests = [];
    _handled.clear();
    _error = null;
    _blocked = {};
    _presence = null;
    if (uid != null) {
      final service = context.read<SocialService>();
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
    _blockSubscription?.cancel();
    _presenceSubscription?.cancel();
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
        await app.openFriendChallenge(code);
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

  Future<void> _respond(String id, String status) async {
    if (_working || _uid == null) return;
    setState(() => _working = true);
    try {
      await context
          .read<SocialService>()
          .respond(_uid!, id, status, challenge: true);
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
    final request = incoming.isNotEmpty
        ? incoming.first
        : outgoing.isNotEmpty
            ? outgoing.first
            : null;
    final isIncoming = request?.data()['toUid'] == _uid;
    return Stack(children: [
      widget.child,
      if (_foreground &&
          ((_presence?['state'] == 'available' && request != null) ||
              _error != null))
        Positioned(
            top: 12,
            left: 20,
            right: 20,
            child: SafeArea(
                child: Material(
                    elevation: 12,
                    color: const Color(0xFF172554),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Row(children: [
                            const Icon(Icons.sports_esports_rounded,
                                color: Color(0xFF38BDF8)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: request == null
                                    ? Text(_error!)
                                    : FutureBuilder<Map<String, dynamic>>(
                                        future: context
                                            .read<SocialService>()
                                            .profile(request.data()[isIncoming
                                                ? 'fromUid'
                                                : 'toUid'] as String),
                                        builder: (context, snapshot) => Text(
                                            '${isIncoming ? '${snapshot.data?['username'] ?? 'لاعب'} يدعوك لمواجهة' : 'بانتظار قبول ${snapshot.data?['username'] ?? 'اللاعب'}'} • ${(request.data()['expiresAt'] as Timestamp).toDate().difference(context.read<SocialService>().now).inSeconds.clamp(0, 30)} ث',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis))),
                            if (request != null && isIncoming) ...[
                              FilledButton(
                                  onPressed: _working
                                      ? null
                                      : () => _respond(request.id, 'accepted'),
                                  child: const Text('قبول')),
                              TextButton(
                                  onPressed: _working
                                      ? null
                                      : () => _respond(request.id, 'declined'),
                                  child: const Text('رفض')),
                            ],
                            if (request != null && !isIncoming)
                              TextButton(
                                  onPressed: _working
                                      ? null
                                      : () => _respond(request.id, 'cancelled'),
                                  child: const Text('إلغاء الدعوة')),
                            if (_error != null)
                              IconButton(
                                  onPressed: () =>
                                      setState(() => _error = null),
                                  icon: const Icon(Icons.close)),
                          ])),
                    )))),
    ]);
  }
}
