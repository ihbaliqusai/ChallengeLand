import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../models/social_player_activity.dart';
import '../../services/social_service.dart';
import '../../widgets/friend_challenge_modal.dart';
import '../../widgets/social_player_card.dart';
import '../../widgets/social_stream_builder.dart';
import 'player_profile_screen.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen>
    with SingleTickerProviderStateMixin {
  static const _mint = Color(0xFF8BEFC1);
  static const _muted = Color(0xFFD0C6F1);
  late final TabController _tabs;
  String? _selectedPeer;
  final _code = TextEditingController();
  final _busy = <String>{};
  Timer? _timer;
  String? _account;
  int _reload = 0;
  SocialPlayerActivity? _activity;
  SocialService get service => context.read<SocialService>();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
        length: 4, vsync: this, initialIndex: widget.initialTab.clamp(0, 3));
    // Native broadcast snapshots do not replay events consumed by the shell.
    service.refreshReads();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        unawaited(service.syncClock());
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabs.dispose();
    _code.dispose();
    super.dispose();
  }

  void _retry() {
    service.refreshReads();
    setState(() => _reload++);
  }

  Future<void> _action(String key, Future<void> Function() action,
      {String successMessage = 'تم تحديث الطلب.'}) async {
    if (_busy.contains(key)) return;
    final account = _account;
    setState(() => _busy.add(key));
    try {
      await action();
      if (mounted && account == _account) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (error) {
      if (mounted && account == _account) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is SocialException
                ? error.message
                : 'تعذر تنفيذ الطلب. تحقق من الاتصال وحاول مجددًا.')));
      }
    } finally {
      if (mounted && account == _account) setState(() => _busy.remove(key));
    }
  }

  Widget _stream(
          Stream<QuerySnapshot<Map<String, dynamic>>> stream,
          Widget Function(List<QueryDocumentSnapshot<Map<String, dynamic>>>)
              builder) =>
      SocialStreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          onRetry: _retry,
          stream: stream,
          builder: (context, snapshot) => builder(snapshot.data!.docs));

  Widget _empty(String label, {IconData icon = Icons.people_outline_rounded}) =>
      Center(
          child: SingleChildScrollView(
              child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                            color: const Color(0xFF17243C),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: const Color(0xFF2A3C56))),
                        child: Icon(icon, size: 40, color: _mint)),
                    const SizedBox(height: 18),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFFCBD5E1), height: 1.6)),
                  ]))));

  Widget _player(String peer,
          {required String subtitle,
          required List<Widget> actions,
          bool online = false,
          bool inMatch = false}) =>
      FutureBuilder<Map<String, dynamic>>(
          key: ValueKey('profile:$peer'),
          future: service.profile(peer),
          builder: (context, snapshot) => SocialPlayerCard(
              key: ValueKey('player:$peer'),
              profile: snapshot.data ?? const {},
              status: subtitle,
              selected: _selectedPeer == peer,
              onTap: () =>
                  _showPlayerOptions(peer, subtitle, snapshot.data, actions),
              online: online,
              inMatch: inMatch,
              loading: !snapshot.hasData && !snapshot.hasError,
              profileUnavailable: snapshot.hasError ||
                  snapshot.data?['_profileMissing'] == true));

  Future<void> _showPlayerOptions(String peer, String status,
      Map<String, dynamic>? profile, List<Widget> actions) async {
    final account = _account;
    setState(() => _selectedPeer = peer);
    await showDialog<void>(
      context: context,
      builder: (_) => _PlayerOptionsDialog(
        key: ValueKey('playerOptions:$peer'),
        peer: peer,
        service: service,
        initialProfile: profile,
        initialStatus: status,
        actions: actions,
        onViewProfile: () {
          if (!mounted || _account != account) return;
          Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => PlayerProfileScreen(
                  playerUid: peer, initialProfile: profile)));
        },
      ),
    );
  }

  Widget _button(String key, String label, Future<void> Function() action,
      {bool primary = false, IconData? icon, bool closeOptions = true}) {
    final working = _busy.contains(key);
    final actionOwner = _account;
    return _PlayerOptionAction(
      requiresAvailable: label == 'تحدٍّ مباشر',
      builder: (buttonContext, available) {
        final callback = working || (label == 'تحدٍّ مباشر' && !available)
            ? null
            : () {
                if (closeOptions) Navigator.of(buttonContext).pop();
                if (actionOwner != _account) return;
                unawaited(_action(key, action,
                    successMessage: label == 'تحدٍّ مباشر'
                        ? 'أُرسلت الدعوة؛ تبدأ المواجهة بعد قبول اللاعب.'
                        : label == 'إضافة صديق' || label == 'إرسال الطلب'
                            ? 'أُرسل طلب الصداقة؛ سيصل إشعار إلى اللاعب.'
                            : 'تم تحديث الطلب.'));
              };
        final child = Row(mainAxisSize: MainAxisSize.min, children: [
          if (working) ...[
            const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: _mint)),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 17),
            const SizedBox(width: 6)
          ],
          Flexible(child: Text(working ? 'جارٍ الإرسال…' : label)),
        ]);
        final shape =
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
        return primary
            ? FilledButton(
                style: FilledButton.styleFrom(
                    foregroundColor: const Color(0xFF142755),
                    backgroundColor: const Color(0xFF76D2FF),
                    disabledBackgroundColor: const Color(0xFF646086),
                    shape: shape,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    textStyle: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontSize: 12, fontWeight: FontWeight.w800)),
                onPressed: callback,
                child: child)
            : OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF6F1FF),
                    side:
                        const BorderSide(color: Color(0xFFB6A0ED), width: 1.5),
                    shape: shape,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    textStyle: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
                onPressed: callback,
                child: child);
      },
    );
  }

  Widget _list(List<WidgetBuilder> items, {String? storageKey}) =>
      ListView.builder(
          key: storageKey == null ? null : PageStorageKey(storageKey),
          padding: const EdgeInsets.only(top: 10, bottom: 14),
          itemCount: items.length,
          itemBuilder: (context, index) => items[index](context));

  Widget _section(String title, int count, IconData icon, Color color,
          {String? subtitle}) =>
      Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: color, size: 16)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: const TextStyle(
                            color: _muted, fontSize: 11, height: 1.5)),
                ])),
            const SizedBox(width: 8),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(9)),
                child: Text('$count',
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.w800))),
          ]));

  Widget _note(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
      child: Text(text,
          style: const TextStyle(color: _muted, fontSize: 12, height: 1.7)));

  Widget _discoveryHero(int online, int available, {bool compact = false}) =>
      Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFE2EBF7),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFAD8CE8), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x66211640), offset: Offset(0, 3))
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFF8A5CDA), Color(0xFF6944BB)])),
                child: Row(children: [
                  const Icon(Icons.shield_rounded,
                      color: Color(0xFFE6DCFF), size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          compact ? 'اختر منافسك' : 'أصدقاء أكثر، تحديات أقوى',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                    color: Color(0xFF30204D),
                                    offset: Offset(0, 1))
                              ]))),
                ])),
            Padding(
                padding: const EdgeInsets.all(11),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!compact) ...[
                        const Text('اضغط على اللاعب للتحدي مباشرة أو عرض ملفه.',
                            style: TextStyle(
                                color: Color(0xFF625F7D),
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                      ],
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        if (!compact)
                          _heroCount('$online متصل الآن', Icons.circle,
                              const Color(0xFF168D56)),
                        _heroCount('$available متاح للتحدي', Icons.bolt_rounded,
                            const Color(0xFF345E9C)),
                      ]),
                    ])),
          ]));

  Widget _heroCount(String label, IconData icon, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
          color: const Color(0xFFC5D3E5).withValues(alpha: .65),
          borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: icon == Icons.circle ? 8 : 16, color: color),
        const SizedBox(width: 7),
        Flexible(
          child: Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        )
      ]));

  String _filterLabel(SocialPlayerActivity? activity) => switch (activity) {
        null => 'الكل',
        SocialPlayerActivity.online => 'متصل الآن',
        SocialPlayerActivity.lastHour => 'خلال ساعة',
        SocialPlayerActivity.lastSixHours => 'خلال 6 ساعات',
        SocialPlayerActivity.today => 'اليوم',
      };

  String _sectionLabel(SocialPlayerActivity activity) => switch (activity) {
        SocialPlayerActivity.online => 'متصلون الآن',
        SocialPlayerActivity.lastHour => 'نشطوا خلال ساعة',
        SocialPlayerActivity.lastSixHours => 'نشطوا خلال 6 ساعات',
        SocialPlayerActivity.today => 'نشطوا اليوم',
      };

  Widget _activityFilters(Map<SocialPlayerActivity, int> counts,
      {bool wrapped = false}) {
    final chips = <SocialPlayerActivity?>[null, ...SocialPlayerActivity.values]
        .map((value) => Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
                selected: _activity == value,
                onSelected: (_) => setState(() => _activity = value),
                showCheckmark: false,
                selectedColor: const Color(0xFFFFDB74),
                backgroundColor: const Color(0xFF6043AC),
                side: BorderSide(
                    color: _activity == value
                        ? const Color(0xFFF0BB4A)
                        : const Color(0xFF9272D7)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: _activity == value
                        ? const Color(0xFF4D351D)
                        : const Color(0xFFE8DFFB),
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
                label: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(child: Text(_filterLabel(value))),
                  if (value != null) ...[
                    const SizedBox(width: 7),
                    Text('${counts[value] ?? 0}',
                        style: const TextStyle(fontSize: 11))
                  ]
                ]))))
        .toList();
    return wrapped
        ? Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 10, 0),
            child: Wrap(runSpacing: 4, children: chips))
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 2),
            child: Row(children: chips));
  }

  Widget _discovery(String uid, Set<String> blocked, Set<String> friends,
          Set<String> pending) =>
      _stream(service.recentPlayers(), (docs) {
        final groups = {
          for (final activity in SocialPlayerActivity.values)
            activity: <QueryDocumentSnapshot<Map<String, dynamic>>>[]
        };
        for (final doc in docs) {
          if (doc.id == uid || blocked.contains(doc.id)) continue;
          final activity = SocialActivity.classify(doc.data(), service.now);
          if (activity != null) groups[activity]!.add(doc);
        }
        groups[SocialPlayerActivity.online]!.sort((a, b) {
          final aAvailable = a.data()['state'] == 'available';
          final bAvailable = b.data()['state'] == 'available';
          if (aAvailable != bAvailable) return aAvailable ? -1 : 1;
          return (b.data()['heartbeatAt'] as Timestamp)
              .compareTo(a.data()['heartbeatAt'] as Timestamp);
        });
        final counts = groups.map((key, value) => MapEntry(key, value.length));
        final online = groups[SocialPlayerActivity.online]!;
        final available =
            online.where((d) => d.data()['state'] == 'available').length;
        final items = <WidgetBuilder>[];
        final selected = _activity == null
            ? SocialPlayerActivity.values
            : <SocialPlayerActivity>[_activity!];
        for (final activity in selected) {
          final players = groups[activity]!;
          final isOnline = activity == SocialPlayerActivity.online;
          items.add((_) => _section(
              _sectionLabel(activity),
              players.length,
              isOnline ? Icons.wifi_tethering_rounded : Icons.history_rounded,
              isOnline ? const Color(0xFF4ADE80) : const Color(0xFFA5B4FC)));
          if (players.isEmpty) {
            items.add((_) => _note(isOnline
                ? 'لا يوجد لاعبون متصلون الآن. عُد قريبًا لمنافسة جديدة.'
                : 'لا يوجد لاعبون في هذه الفترة حاليًا.'));
          }
          for (final doc in players) {
            items.add((_) => _player(doc.id,
                    subtitle:
                        SocialActivity.lastSeenLabel(doc.data(), service.now),
                    online: isOnline,
                    inMatch: isOnline && doc.data()['state'] == 'in_match',
                    actions: [
                      if (isOnline && doc.data()['state'] == 'available')
                        _button(doc.id, 'تحدٍّ مباشر',
                            () => service.send(uid, doc.id, challenge: true),
                            primary: true, icon: Icons.bolt_rounded),
                      if (!friends.contains(doc.id) &&
                          !pending.contains(doc.id))
                        _button('friend:${doc.id}', 'إضافة صديق',
                            () => service.send(uid, doc.id, challenge: false),
                            icon: Icons.person_add_alt_1_rounded),
                      if (pending.contains(doc.id))
                        _statusBadge('طلب قائم', Icons.hourglass_top_rounded),
                      if (friends.contains(doc.id))
                        _statusBadge('صديقك', Icons.check_rounded),
                      _managePlayer(uid, doc.id,
                          isFriend: friends.contains(doc.id)),
                    ]));
          }
        }
        return LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth >= 600 && constraints.maxHeight <= 520) {
            return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                      width: constraints.maxWidth >= 800 ? 260 : 220,
                      child: _list([
                        (_) => _discoveryHero(online.length, available,
                            compact: true),
                        (_) => _activityFilters(counts, wrapped: true),
                      ], storageKey: 'social-discovery-controls')),
                  Expanded(
                      child:
                          _list(items, storageKey: 'social-discovery-players')),
                ]);
          }
          return _list([
            (_) => _discoveryHero(online.length, available),
            (_) => _activityFilters(counts),
            ...items,
          ], storageKey: 'social-discovery');
        });
      });

  Widget _statusBadge(String label, IconData icon) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: const Color(0xFF4A337B),
          borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: _muted, size: 15),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: _muted, fontSize: 11))
      ]));

  Widget _managePlayer(String uid, String peer, {required bool isFriend}) =>
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (isFriend)
          _button(
              'manage:$peer',
              'إزالة الصديق',
              () => service.respond(
                  uid, SocialService.pairId(uid, peer), 'removed',
                  challenge: false),
              icon: Icons.person_remove_alt_1_rounded),
        _button('manage:$peer', 'حظر اللاعب', () => service.block(uid, peer),
            icon: Icons.block_rounded),
      ]);

  Widget _panel({required Widget child}) => Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: const Color(0xFF503786),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF9675D6), width: 1.5)),
      child: child);

  Widget _addFriend(String uid) => _panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('أضف صديقك برمزه',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
        const SizedBox(height: 5),
        const Text('أرسل طلبًا وابدآ رحلتكما في المنافسة.',
            style: TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 14),
        TextField(
            controller: _code,
            textDirection: TextDirection.ltr,
            maxLength: 10,
            style: const TextStyle(color: Colors.white),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
                labelText: 'رمز الصديق',
                labelStyle: const TextStyle(color: _muted),
                prefixIcon:
                    const Icon(Icons.person_add_alt_1_rounded, color: _mint),
                counterText: '',
                filled: true,
                fillColor: const Color(0xFF0C1628),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 12),
        Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _button('lookup', 'إرسال الطلب', () async {
              final peer = await service.findCode(_code.text);
              await service.send(uid, peer, challenge: false);
            }, primary: true, icon: Icons.send_rounded, closeOptions: false)),
      ]));

  Widget _friends(String uid, Set<String> friends) => _list([
        (_) => _addFriend(uid),
        (_) => _section('فريقك من الأصدقاء', friends.length,
            Icons.people_alt_rounded, const Color(0xFFA5B4FC)),
        if (friends.isEmpty)
          (_) => _note('أضف أصدقاء لتجدهم هنا على كل أجهزتك.'),
        ...friends.map((peer) => (BuildContext _) =>
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                key: ValueKey('friend-presence:$peer'),
                stream: service.presence(peer),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data();
                  final online = SocialService.fresh(data, service.now);
                  final available = online && data?['state'] == 'available';
                  return _player(peer,
                      subtitle: snapshot.hasError
                          ? 'تعذر تحديث حالة الاتصال'
                          : SocialActivity.lastSeenLabel(data, service.now),
                      online: online,
                      inMatch: online && !available,
                      actions: [
                        if (available)
                          _button(peer, 'تحدٍّ مباشر',
                              () => service.send(uid, peer, challenge: true),
                              primary: true, icon: Icons.bolt_rounded),
                        _managePlayer(uid, peer, isFriend: true)
                      ]);
                })),
      ], storageKey: 'social-friends');

  Widget _requests(String uid, Set<String> blocked,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> links) {
    final pending = links.where((d) {
      final peer =
          d.data()['fromUid'] == uid ? d.data()['toUid'] : d.data()['fromUid'];
      return !blocked.contains(peer) &&
          SocialService.pending(d.data(), service.now);
    }).toList();
    return _stream(service.challenges(uid), (docs) {
      final challenges = docs.where((d) {
        final peer = d.data()['fromUid'] == uid
            ? d.data()['toUid']
            : d.data()['fromUid'];
        return !blocked.contains(peer) &&
            SocialService.pending(d.data(), service.now);
      }).toList();
      return _list([
        (_) => _section(
            'دعوات المواجهة', challenges.length, Icons.bolt_rounded, _mint,
            subtitle: 'اقبل الدعوة قبل انتهاء الوقت'),
        if (challenges.isEmpty)
          (_) => _note('لا توجد دعوات قائمة. تحدَّ لاعبًا من ساحة اللاعبين.'),
        ...challenges.map((d) => (BuildContext _) {
              final incoming = d.data()['toUid'] == uid;
              final peer = (incoming ? d.data()['fromUid'] : d.data()['toUid'])
                  as String;
              final seconds = (d.data()['expiresAt'] as Timestamp)
                  .toDate()
                  .difference(service.now)
                  .inSeconds
                  .clamp(0, 30);
              return _player(peer,
                  subtitle:
                      '${incoming ? 'يدعوك لمواجهة' : 'بانتظار القبول'} • $seconds ث',
                  actions: [
                    if (incoming)
                      _button(
                          d.id,
                          'قبول',
                          () => service.respond(uid, d.id, 'accepted',
                              challenge: true),
                          primary: true,
                          icon: Icons.check_rounded),
                    _button(
                        d.id,
                        incoming ? 'رفض' : 'إلغاء',
                        () => service.respond(
                            uid, d.id, incoming ? 'declined' : 'cancelled',
                            challenge: true))
                  ]);
            }),
        (_) => _section('طلبات الصداقة', pending.length,
            Icons.person_add_alt_1_rounded, const Color(0xFFA5B4FC)),
        if (pending.isEmpty)
          (_) => _note(
              'لا توجد طلبات صداقة معلّقة. يمكنك إضافة اللاعبين من الساحة.'),
        ...pending.map((d) => (BuildContext _) {
              final incoming = d.data()['toUid'] == uid;
              final peer = (incoming ? d.data()['fromUid'] : d.data()['toUid'])
                  as String;
              return _player(peer,
                  subtitle:
                      incoming ? 'يريد إضافتك صديقًا' : 'بانتظار موافقة اللاعب',
                  actions: [
                    if (incoming)
                      _button(
                          d.id,
                          'قبول',
                          () => service.respond(uid, d.id, 'accepted',
                              challenge: false),
                          primary: true,
                          icon: Icons.check_rounded),
                    _button(
                        d.id,
                        incoming ? 'رفض' : 'إلغاء',
                        () => service.respond(
                            uid, d.id, incoming ? 'declined' : 'cancelled',
                            challenge: false))
                  ]);
            }),
      ], storageKey: 'social-requests');
    });
  }

  Widget _privacy(String uid, Set<String> blocked) => SocialStreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
      onRetry: _retry,
      stream: service.settings(uid),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};
        final discoverable = data['discoverable'] != false;
        final policy = (data['allowChallenges'] ?? 'everyone') as String;
        return _list([
          (_) => _panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const Icon(Icons.verified_user_outlined,
                        color: _mint, size: 32),
                    const SizedBox(height: 12),
                    const Text('العب بطريقتك',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Text('تحكّم في ظهورك واللاعبين الذين يمكنهم دعوتك.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: _muted, fontSize: 12, height: 1.7)),
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('الظهور في ساحة اللاعبين',
                            style: TextStyle(fontSize: 14)),
                        subtitle: const Text(
                            'يمكن لأصدقائك معرفة حالتك حتى عند إخفائك من القائمة العامة.',
                            style: TextStyle(
                                color: _muted, fontSize: 11, height: 1.7)),
                        value: discoverable,
                        activeColor: _mint,
                        onChanged: _busy.contains('settings')
                            ? null
                            : (value) => _action('settings',
                                () => service.setSettings(uid, value, policy))),
                    const Divider(color: Color(0xFF293750), height: 28),
                    const Text('من يمكنه تحديك؟',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                        value: policy,
                        isExpanded: true,
                        decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0C1628),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12))),
                        dropdownColor: const Color(0xFF17243C),
                        items: const [
                          DropdownMenuItem(
                              value: 'everyone', child: Text('الجميع')),
                          DropdownMenuItem(
                              value: 'friends', child: Text('الأصدقاء فقط')),
                          DropdownMenuItem(value: 'none', child: Text('لا أحد'))
                        ],
                        onChanged: _busy.contains('settings')
                            ? null
                            : (value) {
                                if (value != null) {
                                  _action(
                                      'settings',
                                      () => service.setSettings(
                                          uid, discoverable, value));
                                }
                              }),
                  ])),
          (_) => _note(
              'كل صداقة تحتاج موافقة الطرفين. الحظر يمنع طلبات الصداقة والتحديات.'),
          (_) => _section('اللاعبون المحظورون', blocked.length,
              Icons.block_rounded, const Color(0xFFFDA4AF)),
          if (blocked.isEmpty) (_) => _note('قائمة الحظر فارغة.'),
          ...blocked.map((peer) => (BuildContext _) => _player(peer,
                  subtitle: 'محظور',
                  actions: [
                    _button('unblock:$peer', 'إلغاء الحظر',
                        () => service.unblock(uid, peer))
                  ])),
        ], storageKey: 'social-privacy');
      });

  Widget _connectedBody(String uid) =>
      SocialStreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        key: ValueKey('$uid:$_reload'),
        onRetry: _retry,
        stream: service.blocks(uid),
        builder: (context, snapshot) {
          final blocked = snapshot.data!.docs
              .map((d) => d.data()['targetUid'] as String)
              .toSet();
          return _stream(service.links(uid), (links) {
            String peer(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                (d.data()['members'] as List).firstWhere((x) => x != uid)
                    as String;
            final friends = links
                .where((d) => d.data()['status'] == 'accepted')
                .map(peer)
                .toSet();
            final pending = links
                .where((d) => SocialService.pending(d.data(), service.now))
                .map(peer)
                .toSet();
            return TabBarView(controller: _tabs, children: [
              _discovery(uid, blocked, friends, pending),
              _friends(uid, friends.difference(blocked)),
              _requests(uid, blocked, links),
              _privacy(uid, blocked),
            ]);
          });
        },
      );

  Widget _gameButton(
          String label, IconData icon, Color color, VoidCallback? action) =>
      Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            boxShadow: const [
              BoxShadow(color: Color(0xAA20124A), offset: Offset(0, 3))
            ],
          ),
          child: FilledButton.icon(
            onPressed: action,
            icon: Icon(icon, size: 21),
            label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: const Color(0xFF1B2942),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              side: BorderSide(
                  color: Colors.white.withValues(alpha: .65), width: 2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
              textStyle: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ));

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.currentUser;
    if (_account != user?.uid) {
      service.refreshReads();
      _busy.clear();
      _code.clear();
      _activity = null;
      _selectedPeer = null;
      _account = user?.uid;
    }
    final signedIn = user != null && !user.isAnonymous;
    final enabled = signedIn && app.isOnline;
    final theme = Theme.of(context);
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Theme(
          data: theme.copyWith(
              brightness: Brightness.dark,
              colorScheme: theme.colorScheme.copyWith(
                  brightness: Brightness.dark,
                  primary: const Color(0xFFD0B4FF),
                  onPrimary: const Color(0xFF251844),
                  surface: const Color(0xFF44317B),
                  onSurface: Colors.white),
              textTheme: theme.textTheme
                  .apply(bodyColor: Colors.white, displayColor: Colors.white)),
          child: Scaffold(
              backgroundColor: const Color(0xFF23164A),
              body: Stack(children: [
                Positioned.fill(
                    child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Image.asset('assets/ui/bg_main.png',
                            fit: BoxFit.cover))),
                Positioned.fill(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF2E224B).withValues(alpha: .5),
                    const Color(0xFF120A2D).withValues(alpha: .82)
                  ],
                )))),
                SafeArea(
                    child: Center(
                        child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Container(
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF7952D4), Color(0xFF5636A9)]),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: const Color(0xFF211239), width: 2.5),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x990B061C),
                            blurRadius: 24,
                            offset: Offset(0, 8))
                      ],
                    ),
                    child: Column(children: [
                      Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          child: Row(children: [
                            IconButton(
                                tooltip: 'رجوع',
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                icon: const Icon(Icons.arrow_back_rounded,
                                    color: Colors.white)),
                            Expanded(
                                child: Text('الأصدقاء والتحديات',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize:
                                            MediaQuery.sizeOf(context).width <
                                                    360
                                                ? 15
                                                : 19,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        shadows: const [
                                          Shadow(
                                              color: Color(0xFF2A173F),
                                              offset: Offset(0, 2),
                                              blurRadius: 1)
                                        ]))),
                            IconButton(
                                tooltip: 'تحديث اللاعبين',
                                onPressed: enabled ? _retry : null,
                                icon: const Icon(Icons.refresh_rounded)),
                          ])),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: TabBar(
                            controller: _tabs,
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            labelColor: Colors.white,
                            unselectedLabelColor: const Color(0xFFD9CDF9),
                            labelStyle: theme.textTheme.titleSmall?.copyWith(
                                fontSize: 12, fontWeight: FontWeight.w800),
                            labelPadding:
                                const EdgeInsets.symmetric(horizontal: 13),
                            dividerColor: Colors.transparent,
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicator: BoxDecoration(
                                color: const Color(0xFF9B77E4),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                    color: const Color(0xFFCEB4FF),
                                    width: 1.5)),
                            tabs: const [
                              Tab(height: 38, text: 'ساحة اللاعبين'),
                              Tab(height: 38, text: 'أصدقائي'),
                              Tab(height: 38, text: 'الطلبات'),
                              Tab(height: 38, text: 'الخصوصية')
                            ],
                          )),
                      Expanded(
                          child: Container(
                        margin: const EdgeInsets.fromLTRB(7, 8, 7, 0),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF2B205D), Color(0xFF483195)]),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color:
                                  const Color(0xFFAB82EE).withValues(alpha: .5),
                              width: 1.5),
                        ),
                        child: !signedIn
                            ? _empty(
                                'سجّل الدخول لحفظ أصدقائك وإرسال التحديات.')
                            : !app.isOnline
                                ? _empty(
                                    'تحتاج إلى الاتصال بالإنترنت لاستخدام الأصدقاء والتحديات.',
                                    icon: Icons.wifi_off_rounded)
                                : _connectedBody(user.uid),
                      )),
                      Padding(
                          padding: const EdgeInsets.all(9),
                          child: Row(children: [
                            Expanded(
                                child: _gameButton(
                                    'المتصلون',
                                    Icons.bolt_rounded,
                                    const Color(0xFF72CEFF),
                                    enabled
                                        ? () {
                                            setState(() => _activity =
                                                SocialPlayerActivity.online);
                                            _tabs.animateTo(0);
                                          }
                                        : null)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _gameButton(
                                    'إضافة أصدقاء',
                                    Icons.person_add_alt_1_rounded,
                                    const Color(0xFF67E09A),
                                    enabled ? () => _tabs.animateTo(1) : null)),
                            const SizedBox(width: 6),
                            IconButton(
                                tooltip: 'مشاركة رمز التحدي',
                                onPressed: enabled
                                    ? () => FriendChallengeModal.show(context)
                                    : null,
                                icon: const Icon(Icons.qr_code_rounded,
                                    color: Colors.white)),
                          ])),
                    ]),
                  ),
                ))),
              ])),
        ));
  }
}

/// Lets the options dialog disable a challenge as live presence changes.
class _PlayerOptionAction extends StatelessWidget {
  const _PlayerOptionAction(
      {required this.builder,
      this.requiresAvailable = false,
      this.available = true});
  final Widget Function(BuildContext, bool) builder;
  final bool requiresAvailable, available;
  @override
  Widget build(BuildContext context) => builder(context, available);
  _PlayerOptionAction withAvailability(bool value) => _PlayerOptionAction(
      builder: builder, requiresAvailable: requiresAvailable, available: value);
}

class _PlayerOptionsDialog extends StatefulWidget {
  const _PlayerOptionsDialog(
      {super.key,
      required this.peer,
      required this.service,
      required this.initialProfile,
      required this.initialStatus,
      required this.actions,
      required this.onViewProfile});
  final String peer, initialStatus;
  final SocialService service;
  final Map<String, dynamic>? initialProfile;
  final List<Widget> actions;
  final VoidCallback onViewProfile;
  @override
  State<_PlayerOptionsDialog> createState() => _PlayerOptionsDialogState();
}

class _PlayerOptionsDialogState extends State<_PlayerOptionsDialog> {
  Timer? _clock;
  late final Future<Map<String, dynamic>> _profile;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _presence;
  @override
  void initState() {
    super.initState();
    _profile = widget.service.profile(widget.peer);
    // A separate listener receives an initial snapshot even when the page has
    // already consumed its cached native broadcast for this friend.
    _presence = widget.service.db
        .collection('player_presence')
        .doc(widget.peer)
        .snapshots();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: (MediaQuery.sizeOf(context).height -
                      MediaQuery.viewInsetsOf(context).bottom -
                      40)
                  .clamp(100, 900)),
          child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF7050BC), Color(0xFF38245F)]),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFBE9AFF), width: 2),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x880D0723),
                      blurRadius: 30,
                      offset: Offset(0, 12))
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _profile,
                  initialData: widget.initialProfile,
                  builder: (context, snapshot) {
                    final data = snapshot.data ?? const <String, dynamic>{};
                    final photo = data['photoUrl']?.toString() ?? '';
                    final name = (data['username'] ?? 'لاعب').toString();
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(children: [
                            CircleAvatar(
                                radius: 26,
                                backgroundColor: const Color(0xFFD6E2F0),
                                child: ClipOval(
                                    child: photo.startsWith('https://')
                                        ? Image.network(photo,
                                            width: 52,
                                            height: 52,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.person_rounded,
                                                    size: 35,
                                                    color: Color(0xFF614E83)))
                                        : const Icon(Icons.person_rounded,
                                            size: 35,
                                            color: Color(0xFF614E83)))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20))),
                            IconButton(
                                tooltip: 'إغلاق خيارات اللاعب',
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded,
                                    color: Colors.white)),
                          ]),
                          const SizedBox(height: 12),
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              stream: _presence,
                              builder: (context, presence) {
                                final available = SocialService.fresh(
                                        presence.data?.data(),
                                        widget.service.now) &&
                                    presence.data?.data()?['state'] ==
                                        'available';
                                return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                          presence.hasData
                                              ? SocialActivity.lastSeenLabel(
                                                  presence.data?.data(),
                                                  widget.service.now)
                                              : widget.initialStatus,
                                          style: const TextStyle(
                                              color: Color(0xFFE0D7F8),
                                              fontSize: 12)),
                                      const SizedBox(height: 14),
                                      OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            widget.onViewProfile();
                                          },
                                          icon: const Icon(
                                              Icons.account_box_rounded),
                                          label: const Text('عرض الملف الشخصي'),
                                          style: OutlinedButton.styleFrom(
                                              textStyle: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge
                                                  ?.copyWith(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w800),
                                              foregroundColor:
                                                  const Color(0xFF302343),
                                              backgroundColor:
                                                  const Color(0xFFE2EBF7),
                                              padding: const EdgeInsets.all(13),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)))),
                                      const Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 14),
                                          child: Divider(
                                              color: Color(0xFF9A79CD),
                                              height: 1)),
                                      Wrap(
                                          alignment: WrapAlignment.center,
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: widget.actions
                                              .map((action) =>
                                                  action is _PlayerOptionAction &&
                                                          action
                                                              .requiresAvailable
                                                      ? action.withAvailability(
                                                          available)
                                                      : action)
                                              .toList()),
                                    ]);
                              }),
                        ]);
                  },
                ),
              )),
        ),
      ));
}
