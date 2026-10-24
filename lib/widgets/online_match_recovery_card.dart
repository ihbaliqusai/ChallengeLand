import 'game_notice.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/native_bridge_service.dart';
import '../services/online_match_flow.dart';

class OnlineMatchRecoveryCard extends StatefulWidget {
  const OnlineMatchRecoveryCard({super.key, required this.userId});

  final String userId;

  @override
  State<OnlineMatchRecoveryCard> createState() =>
      _OnlineMatchRecoveryCardState();
}

class _OnlineMatchRecoveryCardState extends State<OnlineMatchRecoveryCard>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _matches = const [];
  bool _busy = false;
  int _refreshId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(OnlineMatchRecoveryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _matches = const [];
      unawaited(_refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final refreshId = ++_refreshId;
    if (widget.userId.isEmpty) return;
    try {
      final matches = await context
          .read<NativeBridgeService>()
          .getRecoverableOnlineMatches();
      if (!mounted || refreshId != _refreshId) return;
      final uid = widget.userId;
      final owned = matches.where((match) => match['uid'] == uid).toList();
      // Keep return buttons available while the live server checks are pending.
      setState(() => _matches = owned);
      final resolved = <Map<String, dynamic>>[];
      for (final match in owned) {
        try {
          resolved.add(await OnlineMatchFlow.inspect(context, uid, match));
        } catch (_) {
          resolved.add(match);
        }
        if (!mounted || refreshId != _refreshId) return;
      }
      setState(() => _matches = resolved);
    } catch (_) {
      // A failed refresh keeps the saved return button available for another try.
    }
  }

  Future<void> _resume(Map<String, dynamic> match) async {
    if (_busy) return;
    final uid = widget.userId;
    setState(() => _busy = true);
    try {
      await OnlineMatchFlow.resume(context, uid, match);
      if (mounted && widget.userId == uid) await _refresh();
    } catch (_) {
      if (mounted && widget.userId == uid) {
        GameNoticeMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('تعذر استعادة المباراة. تحقق من الاتصال ثم حاول مجددًا.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseMatch() async {
    if (_matches.length == 1) return _resume(_matches.first);
    final uid = widget.userId;
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('مبارياتك السابقة'),
        children: [
          for (final match in _matches)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, match),
              child: Text(match['finished'] == true
                  ? 'عرض نتيجة المباراة'
                  : (match['roomId'] as String? ?? '').isNotEmpty
                      ? 'العودة إلى غرفة اللعب'
                      : 'العودة إلى المباراة'),
            ),
        ],
      ),
    );
    if (mounted && selected != null && widget.userId == uid) {
      await _resume(selected);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_matches.isEmpty) return const SizedBox.shrink();
    final finished = _matches.every((match) => match['finished'] == true);
    final activeCount =
        _matches.where((match) => match['finished'] != true).length;
    return Material(
      color: const Color(0xF2113440),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const ValueKey('resume-online-match'),
        onTap: _busy ? null : _chooseMatch,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(textDirection: TextDirection.rtl, children: [
            if (_busy)
              const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(finished ? Icons.info_outline : Icons.play_circle_fill,
                  color: const Color(0xFF6EE7B7)),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                  Text(
                      finished
                          ? 'نتيجة مباراتك السابقة'
                          : 'العودة إلى المباراة',
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                  Text(
                      _matches.length > 1
                          ? finished
                              ? 'لديك ${_matches.length} نتائج سابقة'
                              : activeCount > 1
                                  ? 'لديك $activeCount مباريات سابقة لم تنتهِ'
                                  : 'مباراة جارية ونتائج سابقة'
                          : finished
                              ? 'اضغط لعرض النتيجة'
                              : 'تابع المباراة أو اعرض نتيجتها إذا انتهت',
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFFB9D8DE), fontSize: 10)),
                ])),
          ]),
        ),
      ),
    );
  }
}
