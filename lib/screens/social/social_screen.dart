import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../models/social_player_activity.dart';
import '../../services/social_service.dart';
import '../../widgets/friend_challenge_modal.dart';
import '../../widgets/friend_stake_selector.dart';
import '../../widgets/social_player_card.dart';
import '../../widgets/social_artwork.dart';
import '../../widgets/social_stream_builder.dart';
import 'player_profile_screen.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key, this.initialTab = 0, this.initialStake = 0});
  final int initialTab;
  final int initialStake;
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
      if (mounted && account == _account && successMessage.isNotEmpty) {
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
    final isDestructive = label.contains('حظر') || label == 'رفض';
    final isStaked = label.contains('قطع') || key.startsWith('stake:');
    final isFriend = label.contains('إضافة صديق') || key.startsWith('friend:');
    final role = primary
        ? _PlayerActionRole.primary
        : isStaked
            ? _PlayerActionRole.staked
            : isFriend
                ? _PlayerActionRole.friend
                : isDestructive
                    ? _PlayerActionRole.destructive
                    : _PlayerActionRole.standard;

    return _PlayerOptionAction(
      requiresAvailable: label == 'تحدٍّ مباشر' || label == 'تحدٍّ على قطع',
      isDestructive: isDestructive,
      role: role,
      label: label,
      builder: (buttonContext, available) {
        final callback = working ||
                ((label == 'تحدٍّ مباشر' || label == 'تحدٍّ على قطع') &&
                    !available)
            ? null
            : () {
                if (closeOptions) Navigator.of(buttonContext).pop();
                if (actionOwner != _account) return;
                unawaited(_action(key, action,
                    successMessage: label == 'تحدٍّ على قطع'
                        ? ''
                        : label == 'تحدٍّ مباشر'
                            ? 'أُرسلت الدعوة؛ تبدأ المواجهة بعد قبول اللاعب.'
                            : label == 'إضافة صديق' || label == 'إرسال الطلب'
                                ? 'أُرسل طلب الصداقة؛ سيصل إشعار إلى اللاعب.'
                                : 'تم تحديث الطلب.'));
              };
        final enabled = callback != null;
        return ElevatedButton(
          onPressed: callback,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: const Color(0xFF8E83A3),
            padding: EdgeInsets.zero,
            elevation: 0,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _actionButtonFace(
            role: role,
            label: working ? 'جارٍ الإرسال…' : label,
            icon: icon,
            enabled: enabled,
            working: working,
          ),
        );
      },
    );
  }

  Widget _actionButtonFace({
    required _PlayerActionRole role,
    required String label,
    required IconData? icon,
    required bool enabled,
    required bool working,
  }) {
    final Gradient bgGradient;
    final Border border;
    final List<BoxShadow> shadows;
    final TextStyle textStyle;
    final Widget iconWidget;

    switch (role) {
      case _PlayerActionRole.primary:
        bgGradient = enabled
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF4EE3FF),
                  Color(0xFF139EF4),
                  Color(0xFF0075D1),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF384A5C), Color(0xFF263340)],
              );
        border = Border.all(
          color: enabled ? const Color(0xFF9EEBFF) : const Color(0xFF4C5D70),
          width: 1.5,
        );
        shadows = enabled
            ? const [
                BoxShadow(
                  color: Color(0xFF004B8C),
                  offset: Offset(0, 4),
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: Color(0x6600B4FF),
                  offset: Offset(0, 2),
                  blurRadius: 6,
                ),
              ]
            : const [];
        textStyle = TextStyle(
          color: enabled ? Colors.white : const Color(0xFF8697A8),
          fontWeight: FontWeight.w900,
          fontSize: 16,
          shadows: enabled
              ? const [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 2,
                    color: Color(0x88002040),
                  ),
                ]
              : null,
        );
        iconWidget = Icon(
          icon ?? Icons.bolt_rounded,
          color: enabled ? const Color(0xFFFFD600) : const Color(0xFF6E7E91),
          size: 24,
        );
        break;

      case _PlayerActionRole.staked:
        bgGradient = enabled
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF451E75),
                  Color(0xFF2C1150),
                  Color(0xFF1E0938),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2D1F3E), Color(0xFF1D1429)],
              );
        border = Border.all(
          color: enabled ? const Color(0xFFE5AA38) : const Color(0xFF54436A),
          width: 2.0,
        );
        shadows = enabled
            ? const [
                BoxShadow(
                  color: Color(0xFF120325),
                  offset: Offset(0, 4),
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: Color(0x44E5AA38),
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ]
            : const [];
        textStyle = TextStyle(
          color: enabled ? const Color(0xFFFFF9E6) : const Color(0xFF7E6F94),
          fontWeight: FontWeight.w900,
          fontSize: 15,
          shadows: enabled
              ? const [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 2,
                    color: Colors.black87,
                  ),
                ]
              : null,
        );
        iconWidget = Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: enabled
                ? const LinearGradient(
                    colors: [Color(0xFFFFDF7A), Color(0xFFDCA028)],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF867657), Color(0xFF5A4F3A)],
                  ),
            boxShadow: enabled
                ? const [
                    BoxShadow(color: Color(0x66FFCC00), blurRadius: 4),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              '\$',
              style: TextStyle(
                color:
                    enabled ? const Color(0xFF5A3800) : const Color(0xFF332B1E),
                fontWeight: FontWeight.w900,
                fontSize: 13,
                height: 1.1,
              ),
            ),
          ),
        );
        break;

      case _PlayerActionRole.friend:
        bgGradient = enabled
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF451E75),
                  Color(0xFF2C1150),
                  Color(0xFF1E0938),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2D1F3E), Color(0xFF1D1429)],
              );
        border = Border.all(
          color: enabled ? const Color(0xFFE5AA38) : const Color(0xFF54436A),
          width: 2.0,
        );
        shadows = enabled
            ? const [
                BoxShadow(
                  color: Color(0xFF120325),
                  offset: Offset(0, 4),
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: Color(0x44E5AA38),
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ]
            : const [];
        textStyle = TextStyle(
          color: enabled ? const Color(0xFFFFF9E6) : const Color(0xFF7E6F94),
          fontWeight: FontWeight.w900,
          fontSize: 15,
          shadows: enabled
              ? const [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 2,
                    color: Colors.black87,
                  ),
                ]
              : null,
        );
        iconWidget = Icon(
          icon ?? Icons.person_add_alt_1_rounded,
          color: enabled ? const Color(0xFF5ED3FF) : const Color(0xFF6A798A),
          size: 22,
        );
        break;

      case _PlayerActionRole.destructive:
        bgGradient = enabled
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF5A1625),
                  Color(0xFF380A15),
                  Color(0xFF26040C),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF33161C), Color(0xFF210C10)],
              );
        border = Border.all(
          color: enabled ? const Color(0xFF8E372B) : const Color(0xFF4D231E),
          width: 2.0,
        );
        shadows = enabled
            ? const [
                BoxShadow(
                  color: Color(0xFF190206),
                  offset: Offset(0, 4),
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: Color(0x44FF3B56),
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ]
            : const [];
        textStyle = TextStyle(
          color: enabled ? Colors.white : const Color(0xFF8C6D73),
          fontWeight: FontWeight.w900,
          fontSize: 16,
          shadows: enabled
              ? const [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 2,
                    color: Colors.black87,
                  ),
                ]
              : null,
        );
        iconWidget = Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: enabled
                ? const LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFF8E1B1B)],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF6E2827), Color(0xFF471717)],
                  ),
            border: Border.all(
              color:
                  enabled ? const Color(0xFFFF8585) : const Color(0xFF854747),
              width: 1.5,
            ),
            boxShadow: enabled
                ? const [
                    BoxShadow(color: Color(0x66FF1744), blurRadius: 4),
                  ]
                : null,
          ),
          child: const Center(
            child: Icon(
              Icons.block_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
        );
        break;

      case _PlayerActionRole.standard:
        bgGradient = enabled
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF451E75),
                  Color(0xFF2C1150),
                  Color(0xFF1E0938),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2D1F3E), Color(0xFF1D1429)],
              );
        border = Border.all(
          color: enabled ? const Color(0xFFB593E8) : const Color(0xFF54436A),
          width: 1.5,
        );
        shadows = enabled
            ? const [
                BoxShadow(
                  color: Color(0xFF120325),
                  offset: Offset(0, 4),
                  blurRadius: 0,
                ),
              ]
            : const [];
        textStyle = TextStyle(
          color: enabled ? const Color(0xFFFFF9E6) : const Color(0xFF7E6F94),
          fontWeight: FontWeight.w800,
          fontSize: 15,
        );
        iconWidget = Icon(
          icon ?? Icons.touch_app_rounded,
          color: enabled ? const Color(0xFFD3BEFF) : const Color(0xFF6A798A),
          size: 20,
        );
        break;
    }

    return Ink(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: bgGradient,
        border: border,
        boxShadow: shadows,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (working) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _mint),
            ),
            const SizedBox(width: 6),
          ] else ...[
            iconWidget,
            const SizedBox(width: 6),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: textStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendStakedChallenge(String uid, String peer) async {
    final amount = await FriendStakeSelector.choose(context,
        initialAmount: widget.initialStake);
    if (amount == null || !mounted || _account != uid) return;
    await service.sendStakedChallenge(uid, peer, amount);
    if (mounted && _account == uid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'أُرسلت دعوة بـ$amount قطعة؛ الجائزة ${amount * 2} قطعة بعد قبول صديقك.')));
    }
  }

  Future<void> _respondToChallenge(String uid,
      QueryDocumentSnapshot<Map<String, dynamic>> request, String status) {
    final amount = SocialService.stakeCoins(request.data());
    return amount > 0
        ? service.respondStakedChallenge(request.id, status,
            expectedAmount: amount)
        : service.respond(uid, request.id, status, challenge: true);
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
                          fontSize: 15,
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
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: color.withValues(alpha: .7), width: 1.5)),
                child: Text('$count',
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.w800))),
          ]));

  Widget _note(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
      child: Text(text,
          style: const TextStyle(color: _muted, fontSize: 12, height: 1.7)));

  Widget _discoveryHero(int online, int available) => Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SocialDiscoveryArtwork(
                  online: online, available: available))));
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
                backgroundColor: const Color(0xFF281548),
                side: BorderSide(
                    color: _activity == value
                        ? const Color(0xFFF0BB4A)
                        : const Color(0xFF8253B4),
                    width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
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
                      if (isOnline && doc.data()['state'] == 'available')
                        _button('stake:${doc.id}', 'تحدٍّ على قطع',
                            () => _sendStakedChallenge(uid, doc.id),
                            icon: Icons.monetization_on_rounded),
                      if (!friends.contains(doc.id) &&
                          !pending.contains(doc.id))
                        _button('friend:${doc.id}', 'إضافة صديق',
                            () => service.send(uid, doc.id, challenge: false),
                            icon: Icons.person_add_alt_1_rounded),
                      if (pending.contains(doc.id))
                        _statusBadge('طلب قائم', Icons.hourglass_top_rounded),
                      if (friends.contains(doc.id))
                        _statusBadge('صديقك', Icons.check_rounded),
                      ..._managePlayer(uid, doc.id,
                          isFriend: friends.contains(doc.id)),
                    ]));
          }
        }
        return LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth >= 600 && constraints.maxHeight <= 520) {
            return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF704692), width: 1.5),
                          color: const Color(0x2223104A)),
                      width: constraints.maxWidth >= 800 ? 260 : 220,
                      child: _list([
                        (_) => _discoveryHero(online.length, available),
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

  List<Widget> _managePlayer(String uid, String peer,
          {required bool isFriend}) =>
      [
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
      ];

  Widget _panel({required Widget child}) => Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF43236F), Color(0xFF271746)]),
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
                        if (available)
                          _button('stake:$peer', 'تحدٍّ على قطع',
                              () => _sendStakedChallenge(uid, peer),
                              icon: Icons.monetization_on_rounded),
                        ..._managePlayer(uid, peer, isFriend: true)
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
              final stake = SocialService.stakeCoins(d.data());
              final peer = (incoming ? d.data()['fromUid'] : d.data()['toUid'])
                  as String;
              final seconds = (d.data()['expiresAt'] as Timestamp)
                  .toDate()
                  .difference(service.now)
                  .inSeconds
                  .clamp(0, 30);
              return _player(peer,
                  subtitle:
                      '${incoming ? 'يدعوك لمواجهة' : 'بانتظار القبول'} • $seconds ث'
                      '${stake > 0 ? '\n${SocialService.stakeDescription(d.data())}' : ''}',
                  actions: [
                    if (stake > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                            '${SocialService.stakeDescription(d.data())}\n'
                            'التعادل أو خلل المباراة يعيد القطع. الانسحاب بعد البدء خسارة.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xFFFFD166),
                                fontSize: 12,
                                height: 1.6)),
                      ),
                    if (incoming)
                      _button(d.id, stake > 0 ? 'قبول بـ$stake قطعة' : 'قبول',
                          () => _respondToChallenge(uid, d, 'accepted'),
                          primary: true, icon: Icons.check_rounded),
                    _button(
                        d.id,
                        incoming ? 'رفض' : 'إلغاء',
                        () => _respondToChallenge(
                            uid, d, incoming ? 'declined' : 'cancelled'))
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
    final compact = MediaQuery.sizeOf(context).height < 500;
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Theme(
          data: theme.copyWith(
              brightness: Brightness.dark,
              colorScheme: theme.colorScheme.copyWith(
                  brightness: Brightness.dark,
                  primary: const Color(0xFFD0B4FF),
                  onPrimary: const Color(0xFF251844),
                  surface: const Color(0xFF28164C),
                  onSurface: Colors.white),
              textTheme: theme.textTheme
                  .apply(bodyColor: Colors.white, displayColor: Colors.white)),
          child: Scaffold(
              backgroundColor: const Color(0xFF160D36),
              body: RepaintBoundary(
                key: const ValueKey('social-screen-artwork'),
                child: SocialArtworkFrame(
                  child: SafeArea(
                    child: Column(children: [
                      SocialArtworkHeader(
                          onBack: () => Navigator.of(context).maybePop(),
                          onRefresh: enabled ? _retry : null),
                      SizedBox(
                          height: 40,
                          child: TabBar(
                            controller: _tabs,
                            isScrollable: true,
                            tabAlignment: TabAlignment.center,
                            labelColor: Colors.white,
                            unselectedLabelColor: const Color(0xFFD1CBE8),
                            labelStyle: theme.textTheme.titleSmall?.copyWith(
                                fontSize: 13, fontWeight: FontWeight.w800),
                            labelPadding:
                                const EdgeInsets.symmetric(horizontal: 13),
                            dividerColor: Colors.transparent,
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicator: BoxDecoration(
                                borderRadius: BorderRadius.circular(13),
                                gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF7544B5),
                                      Color(0xFF9E41C6)
                                    ]),
                                border: Border.all(color: socialGold, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0xFF61356D),
                                      offset: Offset(0, 3))
                                ]),
                            tabs: const [
                              Tab(text: 'ساحة اللاعبين'),
                              Tab(text: 'أصدقائي'),
                              Tab(text: 'الطلبات'),
                              Tab(text: 'الخصوصية')
                            ],
                          )),
                      const SizedBox(height: 6),
                      Expanded(
                          child: Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFF7850AD),
                                      width: 1.5),
                                  gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0x7733205D),
                                        Color(0x77351B69)
                                      ])),
                              child: !signedIn
                                  ? _empty(
                                      'سجّل الدخول لحفظ أصدقائك وإرسال التحديات.')
                                  : !app.isOnline
                                      ? _empty(
                                          'تحتاج إلى الاتصال بالإنترنت لاستخدام الأصدقاء والتحديات.',
                                          icon: Icons.wifi_off_rounded)
                                      : _connectedBody(user.uid))),
                      const SizedBox(height: 8),
                      SizedBox(
                          height: compact ? 48 : 54,
                          child: Row(children: [
                            Expanded(
                                child: SocialActionButton(
                                    label: 'المتصلون',
                                    icon: Icons.bolt_rounded,
                                    green: false,
                                    onPressed: enabled
                                        ? () {
                                            setState(() => _activity =
                                                SocialPlayerActivity.online);
                                            _tabs.animateTo(0);
                                          }
                                        : null)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: SocialActionButton(
                                    label: 'إضافة أصدقاء',
                                    icon: Icons.person_add_alt_1_rounded,
                                    green: true,
                                    onPressed: enabled
                                        ? () => _tabs.animateTo(1)
                                        : null)),
                            const SizedBox(width: 4),
                            IconButton(
                                tooltip: 'مشاركة رمز التحدي',
                                onPressed: enabled
                                    ? () => FriendChallengeModal.show(context,
                                        initialStake: widget.initialStake)
                                    : null,
                                icon: Icon(Icons.qr_code_rounded,
                                    color: enabled
                                        ? socialGold
                                        : socialGold.withValues(alpha: .4))),
                          ])),
                    ]),
                  ),
                ),
              )),
        ));
  }
}

enum _PlayerActionRole {
  primary,
  staked,
  friend,
  destructive,
  standard,
}

/// Lets the options dialog disable a challenge as live presence changes.
class _PlayerOptionAction extends StatelessWidget {
  const _PlayerOptionAction({
    required this.builder,
    this.requiresAvailable = false,
    this.available = true,
    this.isDestructive = false,
    this.role = _PlayerActionRole.standard,
    this.label = '',
  });

  final Widget Function(BuildContext, bool) builder;
  final bool requiresAvailable, available, isDestructive;
  final _PlayerActionRole role;
  final String label;

  @override
  Widget build(BuildContext context) => builder(context, available);

  _PlayerOptionAction withAvailability(bool value) => _PlayerOptionAction(
        builder: builder,
        requiresAvailable: requiresAvailable,
        available: value,
        isDestructive: isDestructive,
        role: role,
        label: label,
      );
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

  Widget _goldenCloseButton(BuildContext context) {
    return Tooltip(
      message: 'إغلاق خيارات اللاعب',
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF0B3),
              Color(0xFFFFD466),
              Color(0xFFE5AA38),
              Color(0xFF8A590C),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(3.5),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0xFFF7C752), Color(0xFFB8780E)],
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.pop(context),
              child: const Center(
                child: Icon(
                  Icons.close_rounded,
                  color: Color(0xFF4A2602),
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarWithGlowDots(String photo, bool available) {
    return Container(
      width: 62,
      height: 62,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFEA9F),
            Color(0xFFFFD466),
            Color(0xFFE5AA38),
            Color(0xFF8A590C),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3.5),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipOval(
              child: photo.startsWith('https://')
                  ? Image.network(
                      photo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarIcon(),
                    )
                  : _avatarIcon(),
            ),
          ),
          if (available) ...[
            Positioned(
              top: 1,
              right: -1,
              child: _neonGreenDot(),
            ),
            Positioned(
              bottom: 3,
              right: -2,
              child: _neonGreenDot(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _neonGreenDot() => Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF4CFF50),
          border: Border.all(color: const Color(0xFFD4FFA6), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF39FF14),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      );

  Widget _avatarIcon() => Container(
        color: const Color(0xFF281845),
        child: const Icon(
          Icons.person_rounded,
          size: 38,
          color: Color(0xFFE0D7F8),
        ),
      );

  Widget _viewProfileButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pop(context);
        widget.onViewProfile();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        padding: EdgeInsets.zero,
        elevation: 0,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Ink(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF3F7FA),
              Color(0xFFD6E2EC),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFE5AA38),
            width: 2.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66E5AA38),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
            BoxShadow(
              color: Color(0x77000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF261947),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4C3877), width: 1.5),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'عرض الملف الشخصي',
                  style: TextStyle(
                    color: Color(0xFF1E1538),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ornateGoldenDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 2.5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    Color(0xFF9E6D15),
                    Color(0xFFFFD466)
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Transform.rotate(
            angle: 0.785398,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFF5CC),
                    Color(0xFFFFD466),
                    Color(0xFF9E6D15)
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD466).withValues(alpha: 0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 2.5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFFFD466),
                    Color(0xFF9E6D15),
                    Colors.transparent
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: (MediaQuery.sizeOf(context).height -
                        MediaQuery.viewInsetsOf(context).bottom -
                        24)
                    .clamp(100, 900)),
            child: RepaintBoundary(
              key: const ValueKey('player-options-dialog-boundary'),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFEA9F),
                          Color(0xFFE5AA38),
                          Color(0xFF9E6D15),
                          Color(0xFFE5AA38),
                          Color(0xFFFFEA9F),
                        ],
                        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xAA070214),
                          blurRadius: 36,
                          spreadRadius: 4,
                          offset: Offset(0, 14),
                        ),
                        BoxShadow(
                          color: Color(0x55E5AA38),
                          blurRadius: 18,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        gradient: const RadialGradient(
                          center: Alignment(0, -0.4),
                          radius: 1.2,
                          colors: [
                            Color(0xFF381768),
                            Color(0xFF220C42),
                            Color(0xFF130528),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0x55BE9AFF),
                          width: 1.5,
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                        child: FutureBuilder<Map<String, dynamic>>(
                          future: _profile,
                          initialData: widget.initialProfile,
                          builder: (context, snapshot) {
                            final data =
                                snapshot.data ?? const <String, dynamic>{};
                            final photo = data['photoUrl']?.toString() ?? '';
                            final name =
                                (data['username'] ?? 'لاعب').toString();
                            return StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>>(
                              stream: _presence,
                              builder: (context, presence) {
                                final available = SocialService.fresh(
                                        presence.data?.data(),
                                        widget.service.now) &&
                                    presence.data?.data()?['state'] ==
                                        'available';
                                final statusLabel = presence.hasData
                                    ? SocialActivity.lastSeenLabel(
                                        presence.data?.data(),
                                        widget.service.now)
                                    : widget.initialStatus;

                                final standardActions = <Widget>[];
                                final destructiveActions = <Widget>[];

                                for (final action in widget.actions) {
                                  final resolved =
                                      action is _PlayerOptionAction &&
                                              action.requiresAvailable
                                          ? action.withAvailability(available)
                                          : action;
                                  if (action is _PlayerOptionAction &&
                                      action.isDestructive) {
                                    destructiveActions.add(resolved);
                                  } else {
                                    standardActions.add(resolved);
                                  }
                                }

                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        _avatarWithGlowDots(photo, available),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Color(0xFFFFFBE8),
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 25,
                                                  letterSpacing: 0.5,
                                                  shadows: [
                                                    Shadow(
                                                      offset: Offset(0, 3),
                                                      blurRadius: 6,
                                                      color: Color(0xAA2B0B00),
                                                    ),
                                                    Shadow(
                                                      offset: Offset(0, 1),
                                                      blurRadius: 2,
                                                      color: Color(0xFF4A1E00),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                statusLabel,
                                                style: TextStyle(
                                                  color: available
                                                      ? const Color(0xFF52FF68)
                                                      : const Color(0xFFE0D7F8),
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 15,
                                                  shadows: available
                                                      ? const [
                                                          Shadow(
                                                            color: Color(
                                                                0xCC39FF14),
                                                            blurRadius: 10,
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        _goldenCloseButton(context),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    _viewProfileButton(context),
                                    _ornateGoldenDivider(),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final showRow =
                                            constraints.maxWidth >= 340 &&
                                                standardActions.length <= 3 &&
                                                standardActions.isNotEmpty;
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (showRow)
                                              Row(
                                                children: [
                                                  for (int i = 0;
                                                      i <
                                                          standardActions
                                                              .length;
                                                      i++) ...[
                                                    if (i > 0)
                                                      const SizedBox(width: 8),
                                                    Expanded(
                                                        child:
                                                            standardActions[i]),
                                                  ],
                                                ],
                                              )
                                            else
                                              Wrap(
                                                alignment: WrapAlignment.center,
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: standardActions,
                                              ),
                                            if (destructiveActions
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 10),
                                              Center(
                                                child: SizedBox(
                                                  width: showRow ? 180 : null,
                                                  child:
                                                      destructiveActions.first,
                                                ),
                                              ),
                                            ],
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _DialogCornerBracketPainter(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )));
}

class _DialogCornerBracketPainter extends CustomPainter {
  const _DialogCornerBracketPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final goldPaint = Paint()
      ..color = const Color(0xFFFFD466)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final goldFill = Paint()
      ..color = const Color(0xFFDCA028)
      ..style = PaintingStyle.fill;

    const diamondSize = 13.0;
    const cornerOffset = 18.0;

    void drawCorner(double cx, double cy, double dirX, double dirY) {
      final diamondCenter =
          Offset(cx + dirX * cornerOffset, cy + dirY * cornerOffset);
      final path = Path()
        ..moveTo(diamondCenter.dx, diamondCenter.dy - diamondSize / 2)
        ..lineTo(diamondCenter.dx + diamondSize / 2, diamondCenter.dy)
        ..lineTo(diamondCenter.dx, diamondCenter.dy + diamondSize / 2)
        ..lineTo(diamondCenter.dx - diamondSize / 2, diamondCenter.dy)
        ..close();

      final glowPaint = Paint()
        ..color = const Color(0x66FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(path, glowPaint);

      final diamondFill = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFE8F7FF), Color(0xFFBCE3F5)],
        ).createShader(
            Rect.fromCircle(center: diamondCenter, radius: diamondSize));
      canvas.drawPath(path, diamondFill);

      final diamondBorder = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawPath(path, diamondBorder);

      final bracketPath = Path();
      bracketPath.moveTo(cx + dirX * 36, cy + dirY * 6);
      bracketPath.quadraticBezierTo(
        cx + dirX * 12,
        cy + dirY * 6,
        cx + dirX * 6,
        cy + dirY * 12,
      );
      bracketPath.lineTo(cx + dirX * 6, cy + dirY * 36);
      canvas.drawPath(bracketPath, goldPaint);

      canvas.drawCircle(Offset(cx + dirX * 38, cy + dirY * 6), 2.0, goldFill);
      canvas.drawCircle(Offset(cx + dirX * 6, cy + dirY * 38), 2.0, goldFill);
    }

    drawCorner(0, 0, 1, 1);
    drawCorner(size.width, 0, -1, 1);
    drawCorner(0, size.height, 1, -1);
    drawCorner(size.width, size.height, -1, -1);

    final flareCenter = Offset(size.width / 2, 0);
    final flareGlow = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFFBE0), Color(0x88FFD566), Colors.transparent],
        stops: [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: flareCenter, radius: 24));
    canvas.drawCircle(flareCenter, 24, flareGlow);

    final topDiamond = Path()
      ..moveTo(flareCenter.dx, flareCenter.dy - 3)
      ..lineTo(flareCenter.dx + 8, flareCenter.dy)
      ..lineTo(flareCenter.dx, flareCenter.dy + 3)
      ..lineTo(flareCenter.dx - 8, flareCenter.dy)
      ..close();
    canvas.drawPath(topDiamond, Paint()..color = const Color(0xFFFFF9DB));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
