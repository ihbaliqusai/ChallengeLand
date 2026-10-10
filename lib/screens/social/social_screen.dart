import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_state.dart';
import '../../services/social_service.dart';
import '../../widgets/friend_challenge_modal.dart';
import '../../widgets/social_stream_builder.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});
  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final _code = TextEditingController();
  final _busy = <String>{};
  Timer? _timer;
  String? _account;
  int _reload = 0;
  void _retry() {
    service.refreshReads();
    setState(() => _reload++);
  }

  SocialService get service => context.read<SocialService>();
  @override
  void initState() {
    super.initState();
    // Native Firestore snapshots are broadcast without replay. The global
    // shell may already have consumed their initial event before navigation.
    // Give this page fresh streams so it always receives an initial snapshot.
    service.refreshReads();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        service.syncClock();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _action(String key, Future<void> Function() action) async {
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم تحديث الطلب.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is SocialException
                ? error.message
                : 'تعذر تنفيذ الطلب. تحقق من الاتصال وحاول مجددًا.')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Widget _stream(
          Stream<QuerySnapshot<Map<String, dynamic>>> stream,
          Widget Function(List<QueryDocumentSnapshot<Map<String, dynamic>>>)
              builder) =>
      SocialStreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          onRetry: _retry,
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                  child: Text('تعذر تحميل اللاعبين. تحقق من الاتصال.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return builder(snapshot.data!.docs);
          });

  Widget _empty(String label) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(label, textAlign: TextAlign.center)));

  Widget _discoveryStream(
          Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> stream,
          Widget Function(List<QueryDocumentSnapshot<Map<String, dynamic>>>)
              builder) =>
      SocialStreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        onRetry: _retry,
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _empty('تعذر تحميل اللاعبين. تحقق من الاتصال.');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return builder(snapshot.data!);
        },
      );

  Widget _player(String peer,
          {required String subtitle, required List<Widget> actions}) =>
      FutureBuilder<Map<String, dynamic>>(
          future: service.profile(peer),
          builder: (context, snapshot) {
            final data = snapshot.data ?? {};
            final photo = data['photoUrl']?.toString();
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    CircleAvatar(
                        backgroundImage:
                            photo != null && photo.startsWith('https://')
                                ? NetworkImage(photo)
                                : null,
                        child: photo == null || !photo.startsWith('https://')
                            ? const Icon(Icons.person_rounded)
                            : null),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text((data['username'] ?? 'لاعب').toString(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                              'المستوى ${data['level'] ?? 1} • ${data['trophies'] ?? 0} كأس',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white70)),
                          Text(subtitle,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF38BDF8))),
                        ])),
                    Wrap(spacing: 6, children: actions),
                  ])),
            );
          });

  Widget _button(String key, String label, Future<void> Function() action) =>
      TextButton(
          onPressed: _busy.contains(key) ? null : () => _action(key, action),
          child: Text(_busy.contains(key) ? '…' : label));

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.currentUser;
    if (_account != user?.uid) {
      _busy.clear();
      _account = user?.uid;
    }
    if (user == null || user.isAnonymous) {
      return Scaffold(
          appBar: AppBar(title: const Text('الأصدقاء والتحديات')),
          body: _empty('سجّل الدخول لحفظ أصدقائك وإرسال التحديات.'));
    }
    final uid = user.uid;
    return DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
              title: const Text('الأصدقاء والتحديات'),
              actions: [
                TextButton(
                    onPressed: () => FriendChallengeModal.show(context),
                    child: const Text('مشاركة رمز التحدي')),
              ],
              bottom: const TabBar(tabs: [
                Tab(text: 'المتصلون'),
                Tab(text: 'أصدقائي'),
                Tab(text: 'الطلبات'),
                Tab(text: 'الخصوصية')
              ])),
          body: !app.isOnline
              ? _empty(
                  'تحتاج إلى الاتصال بالإنترنت لاستخدام الأصدقاء والتحديات.')
              : SocialStreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  onRetry: _retry,
                  key: ValueKey('$uid:$_reload'),
                  stream: service.blocks(uid),
                  builder: (context, blockSnapshot) {
                    if (blockSnapshot.hasError) {
                      return _empty('تعذر تحميل إعدادات الحظر.');
                    }
                    if (!blockSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final blocked = blockSnapshot.data!.docs
                        .map((d) => d.data()['targetUid'] as String)
                        .toSet();
                    return _stream(service.links(uid), (links) {
                      final friendIds = links
                          .where((d) => d.data()['status'] == 'accepted')
                          .map((d) => (d.data()['members'] as List)
                              .firstWhere((x) => x != uid) as String)
                          .toSet();
                      final pendingIds = links
                          .where((d) =>
                              SocialService.pending(d.data(), service.now))
                          .map((d) => (d.data()['members'] as List)
                              .firstWhere((x) => x != uid) as String)
                          .toSet();
                      return TabBarView(children: [
                        _discoveryStream(service.suggestedPlayers(app.trophies),
                            (players) {
                          final visible = players
                              .where((d) =>
                                  d.id != uid &&
                                  !blocked.contains(d.id) &&
                                  SocialService.fresh(d.data(), service.now))
                              .toList();
                          if (visible.isEmpty) {
                            return _empty(
                                'لا يوجد لاعبون متصلون الآن. يمكنك إضافة صديق باستخدام رمزه.');
                          }
                          return ListView(
                              children: visible
                                  .map((d) => _player(d.id,
                                          subtitle:
                                              d.data()['state'] == 'available'
                                                  ? 'متصل • متاح للتحدي'
                                                  : 'متصل • في مباراة',
                                          actions: [
                                            if (d.data()['state'] ==
                                                'available')
                                              _button(
                                                  d.id,
                                                  'تحدَّ',
                                                  () => service.send(uid, d.id,
                                                      challenge: true)),
                                            if (!friendIds.contains(d.id) &&
                                                !pendingIds.contains(d.id))
                                              _button(
                                                  'friend:${d.id}',
                                                  'إضافة صديق',
                                                  () => service.send(uid, d.id,
                                                      challenge: false)),
                                            if (pendingIds.contains(d.id))
                                              const Chip(
                                                  label: Text('طلب قائم')),
                                          ]))
                                  .toList());
                        }),
                        Column(children: [
                          Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(children: [
                                Expanded(
                                    child: TextField(
                                        controller: _code,
                                        textDirection: TextDirection.ltr,
                                        maxLength: 10,
                                        decoration: const InputDecoration(
                                            labelText: 'رمز الصديق',
                                            counterText: ''),
                                        textCapitalization:
                                            TextCapitalization.characters)),
                                _button('lookup', 'إضافة', () async {
                                  final peer =
                                      await service.findCode(_code.text);
                                  await service.send(uid, peer,
                                      challenge: false);
                                }),
                              ])),
                          Expanded(
                              child: friendIds.difference(blocked).isEmpty
                                  ? _empty(
                                      'أضف أصدقاء لتجدهم هنا على كل أجهزتك.')
                                  : ListView(
                                      children: friendIds
                                          .difference(blocked)
                                          .map((peer) => StreamBuilder<
                                                  DocumentSnapshot<
                                                      Map<String, dynamic>>>(
                                              stream: service.presence(peer),
                                              builder: (context, snapshot) {
                                                final online =
                                                    SocialService.fresh(
                                                        snapshot.data?.data(),
                                                        service.now);
                                                final available = online &&
                                                    snapshot.data?.data()?[
                                                            'state'] ==
                                                        'available';
                                                return _player(peer,
                                                    subtitle: available
                                                        ? 'متاح للتحدي'
                                                        : online
                                                            ? 'في مباراة'
                                                            : 'غير متصل',
                                                    actions: [
                                                      if (available)
                                                        _button(
                                                            peer,
                                                            'تحدَّ',
                                                            () => service.send(
                                                                uid, peer,
                                                                challenge:
                                                                    true)),
                                                      PopupMenuButton<String>(
                                                          onSelected: (value) => _action(
                                                              'manage:$peer',
                                                              () => value ==
                                                                      'block'
                                                                  ? service
                                                                      .block(
                                                                          uid,
                                                                          peer)
                                                                  : service.respond(
                                                                      uid,
                                                                      SocialService.pairId(
                                                                          uid,
                                                                          peer),
                                                                      'removed',
                                                                      challenge:
                                                                          false)),
                                                          itemBuilder: (_) =>
                                                              const [
                                                                PopupMenuItem(
                                                                    value:
                                                                        'remove',
                                                                    child: Text(
                                                                        'إزالة الصديق')),
                                                                PopupMenuItem(
                                                                    value:
                                                                        'block',
                                                                    child: Text(
                                                                        'حظر')),
                                                              ]),
                                                    ]);
                                              }))
                                          .toList())),
                        ]),
                        ListView(children: [
                          const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('طلبات الصداقة')),
                          ...links
                              .where((d) =>
                                  SocialService.pending(d.data(), service.now))
                              .map((d) {
                            final incoming = d.data()['toUid'] == uid;
                            final peer = (incoming
                                ? d.data()['fromUid']
                                : d.data()['toUid']) as String;
                            if (blocked.contains(peer)) {
                              return const SizedBox.shrink();
                            }
                            return _player(peer,
                                subtitle: incoming
                                    ? 'يريد إضافتك صديقًا'
                                    : 'بانتظار موافقة اللاعب',
                                actions: [
                                  if (incoming)
                                    _button(
                                        d.id,
                                        'قبول',
                                        () => service.respond(
                                            uid, d.id, 'accepted',
                                            challenge: false)),
                                  _button(
                                      d.id,
                                      incoming ? 'رفض' : 'إلغاء',
                                      () => service.respond(uid, d.id,
                                          incoming ? 'declined' : 'cancelled',
                                          challenge: false)),
                                ]);
                          }),
                          const Padding(
                              padding: EdgeInsets.all(12),
                              child:
                                  Text('دعوات المواجهة • تنتهي خلال 30 ثانية')),
                          _stream(service.challenges(uid), (docs) {
                            final active = docs
                                .where((d) => SocialService.pending(
                                    d.data(), service.now))
                                .toList();
                            if (active.isEmpty) {
                              return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('لا توجد دعوات قائمة.'));
                            }
                            return Column(
                                children: active.map((d) {
                              final incoming = d.data()['toUid'] == uid;
                              final peer = (incoming
                                  ? d.data()['fromUid']
                                  : d.data()['toUid']) as String;
                              final seconds =
                                  (d.data()['expiresAt'] as Timestamp)
                                      .toDate()
                                      .difference(service.now)
                                      .inSeconds
                                      .clamp(0, 30);
                              return _player(peer,
                                  subtitle:
                                      '${incoming ? 'يدعوك لمواجهة' : 'بانتظار القبول'} • $seconds ث',
                                  actions: [
                                    if (incoming && !blocked.contains(peer))
                                      _button(
                                          d.id,
                                          'قبول',
                                          () => service.respond(
                                              uid, d.id, 'accepted',
                                              challenge: true)),
                                    _button(
                                        d.id,
                                        incoming ? 'رفض' : 'إلغاء',
                                        () => service.respond(uid, d.id,
                                            incoming ? 'declined' : 'cancelled',
                                            challenge: true)),
                                  ]);
                            }).toList());
                          }),
                        ]),
                        SocialStreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>>(
                            onRetry: _retry,
                            stream: service.settings(uid),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return _empty('تعذر تحميل الخصوصية.');
                              }
                              if (!snapshot.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              final data = snapshot.data?.data() ?? {};
                              final discoverable =
                                  data['discoverable'] != false;
                              final policy = (data['allowChallenges'] ??
                                  'everyone') as String;
                              return ListView(children: [
                                SwitchListTile(
                                    title:
                                        const Text('الظهور في قائمة المتصلين'),
                                    subtitle: const Text(
                                        'يمكن لأصدقائك معرفة حالتك حتى عند إخفائك من القائمة العامة.'),
                                    value: discoverable,
                                    onChanged: _busy.contains('settings')
                                        ? null
                                        : (value) => _action(
                                            'settings',
                                            () => service.setSettings(
                                                uid, value, policy))),
                                ListTile(
                                    title: const Text('من يمكنه تحديك؟'),
                                    trailing: DropdownButton<String>(
                                        value: policy,
                                        items: const [
                                          DropdownMenuItem(
                                              value: 'everyone',
                                              child: Text('الجميع')),
                                          DropdownMenuItem(
                                              value: 'friends',
                                              child: Text('الأصدقاء فقط')),
                                          DropdownMenuItem(
                                              value: 'none',
                                              child: Text('لا أحد')),
                                        ],
                                        onChanged: _busy.contains('settings')
                                            ? null
                                            : (value) {
                                                if (value != null) {
                                                  _action(
                                                      'settings',
                                                      () => service.setSettings(
                                                          uid,
                                                          discoverable,
                                                          value));
                                                }
                                              })),
                                const ListTile(
                                    leading: Icon(Icons.shield_outlined),
                                    title: Text('أصدقاء للمنافسة'),
                                    subtitle: Text(
                                        'لا توجد محادثات. كل صداقة تحتاج موافقة الطرفين، والحظر يمنع الطلبات والتحديات.')),
                                ...blocked.map((peer) => _player(peer,
                                        subtitle: 'محظور',
                                        actions: [
                                          _button(peer, 'إلغاء الحظر',
                                              () => service.unblock(uid, peer))
                                        ])),
                              ]);
                            }),
                      ]);
                    });
                  }),
        ));
  }
}
