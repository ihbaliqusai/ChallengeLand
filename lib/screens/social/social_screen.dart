import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_state.dart';
import '../../services/social_service.dart';
import '../../widgets/friend_challenge_modal.dart';
import '../../widgets/social_stream_builder.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key, this.initialTab = 0});
  final int initialTab;
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

  Future<void> _action(String key, Future<void> Function() action,
      {String successMessage = 'تم تحديث الطلب.'}) async {
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(successMessage)));
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
      child: SingleChildScrollView(
          child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                        color: const Color(0xFF172554),
                        borderRadius: BorderRadius.circular(28)),
                    child: const Icon(Icons.people_outline_rounded,
                        size: 44, color: Color(0xFF7DD3FC))),
                const SizedBox(height: 18),
                Text(label,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Color(0xFFCBD5E1), height: 1.6)),
              ]))));

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
              color: const Color(0xFF111D38),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFF243454))),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          CircleAvatar(
                              radius: 27,
                              backgroundColor: const Color(0xFF233B63),
                              backgroundImage:
                                  photo != null && photo.startsWith('https://')
                                      ? NetworkImage(photo)
                                      : null,
                              child:
                                  photo == null || !photo.startsWith('https://')
                                      ? const Icon(Icons.person_rounded)
                                      : null),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text((data['username'] ?? 'لاعب').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    'المستوى ${data['level'] ?? 1} • ${data['trophies'] ?? 0} كأس',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF94A3B8))),
                                const SizedBox(height: 5),
                                Text(subtitle,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6EE7B7))),
                              ])),
                        ]),
                        if (actions.isNotEmpty) ...[
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child:
                                  Divider(height: 1, color: Color(0xFF243454))),
                          Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 6,
                              children: actions),
                        ],
                      ])),
            );
          });

  Widget _button(String key, String label, Future<void> Function() action) =>
      OutlinedButton(
          style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFBAE6FD),
              side: const BorderSide(color: Color(0xFF38527B)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          onPressed: _busy.contains(key)
              ? null
              : () => _action(key, action,
                  successMessage: label == 'دعوة للعب'
                      ? 'أُرسلت الدعوة؛ تبدأ المواجهة بعد قبول اللاعب.'
                      : label == 'إضافة صديق' || label == 'إضافة'
                          ? 'أُرسل طلب الصداقة؛ سيصل إشعار إلى اللاعب.'
                          : 'تم تحديث الطلب.'),
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
        initialIndex: widget.initialTab.clamp(0, 3),
        child: Scaffold(
          backgroundColor: const Color(0xFF091226),
          appBar: AppBar(
              backgroundColor: const Color(0xFF101E3A),
              foregroundColor: Colors.white,
              toolbarHeight: 72,
              title: const Text('الأصدقاء والتحديات'),
              actions: [
                IconButton(
                    tooltip: 'مشاركة رمز التحدي',
                    onPressed: () => FriendChallengeModal.show(context),
                    icon: const Icon(Icons.qr_code_rounded)),
              ],
              bottom: const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: Color(0xFF38BDF8),
                  labelColor: Color(0xFF7DD3FC),
                  unselectedLabelColor: Color(0xFF94A3B8),
                  tabs: [
                    Tab(
                        icon: Icon(Icons.wifi_tethering_rounded),
                        text: 'المتصلون'),
                    Tab(icon: Icon(Icons.people_alt_rounded), text: 'أصدقائي'),
                    Tab(
                        icon: Icon(Icons.notifications_active_outlined),
                        text: 'الطلبات'),
                    Tab(icon: Icon(Icons.shield_outlined), text: 'الخصوصية')
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
                              padding:
                                  const EdgeInsets.only(top: 12, bottom: 24),
                              children: [
                                Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        20, 4, 20, 12),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('${visible.length} لاعب متصل',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 6),
                                          const Text(
                                              'ادعُ أي لاعب متاح لمواجهة، حتى إن لم يكن ضمن أصدقائك.',
                                              style: TextStyle(
                                                  color: Color(0xFF94A3B8),
                                                  height: 1.5)),
                                        ])),
                                ...visible.map((d) => _player(d.id,
                                        subtitle:
                                            d.data()['state'] == 'available'
                                                ? 'متصل • متاح للتحدي'
                                                : 'متصل • في مباراة',
                                        actions: [
                                          if (d.data()['state'] == 'available')
                                            _button(
                                                d.id,
                                                'دعوة للعب',
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
                                            const Chip(label: Text('طلب قائم')),
                                        ]))
                              ]);
                        }),
                        Column(children: [
                          Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF111D38),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: const Color(0xFF243454))),
                              child: Row(children: [
                                Expanded(
                                    child: TextField(
                                        controller: _code,
                                        textDirection: TextDirection.ltr,
                                        maxLength: 10,
                                        decoration: const InputDecoration(
                                            labelText: 'رمز الصديق',
                                            prefixIcon: Icon(
                                                Icons.person_add_alt_1_rounded,
                                                color: Color(0xFF7DD3FC)),
                                            counterText: ''),
                                        textCapitalization:
                                            TextCapitalization.characters)),
                                const SizedBox(width: 8),
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
                                                            'دعوة للعب',
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
                          if (!links.any((d) =>
                              SocialService.pending(d.data(), service.now)))
                            const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                child: Text(
                                    'لا توجد طلبات صداقة معلّقة. يمكنك دعوة اللاعبين من قائمة المتصلين.',
                                    style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        height: 1.5))),
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
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          const Text('من يمكنه تحديك؟'),
                                          const SizedBox(height: 8),
                                          DropdownButton<String>(
                                              isExpanded: true,
                                              value: policy,
                                              items: const [
                                                DropdownMenuItem(
                                                    value: 'everyone',
                                                    child: Text('الجميع')),
                                                DropdownMenuItem(
                                                    value: 'friends',
                                                    child:
                                                        Text('الأصدقاء فقط')),
                                                DropdownMenuItem(
                                                    value: 'none',
                                                    child: Text('لا أحد')),
                                              ],
                                              onChanged:
                                                  _busy.contains('settings')
                                                      ? null
                                                      : (value) {
                                                          if (value != null) {
                                                            _action(
                                                                'settings',
                                                                () => service
                                                                    .setSettings(
                                                                        uid,
                                                                        discoverable,
                                                                        value));
                                                          }
                                                        }),
                                        ])),
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
