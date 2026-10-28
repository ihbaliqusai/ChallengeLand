import '../../widgets/game_back_button.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/adaptive_asset_image.dart';

class InviteFriendsMilestone {
  const InviteFriendsMilestone({
    required this.count,
    required this.coins,
    required this.gems,
    required this.claimed,
  });

  final int count;
  final int coins;
  final int gems;
  final bool claimed;

  Map<String, dynamic> toJson() => {
        'count': count,
        'coins': coins,
        'gems': gems,
        'claimed': claimed,
      };

  factory InviteFriendsMilestone.fromJson(Map<String, dynamic> json) =>
      InviteFriendsMilestone(
        count: (json['count'] as num?)?.toInt() ?? 0,
        coins: (json['coins'] as num?)?.toInt() ?? 0,
        gems: (json['gems'] as num?)?.toInt() ?? 0,
        claimed: json['claimed'] == true,
      );
}

class InviteFriendsData {
  const InviteFriendsData({
    required this.code,
    required this.qualifiedCount,
    required this.earnedCoins,
    required this.earnedGems,
    required this.canAccept,
    this.acceptedCode,
    this.milestones = const [],
  });

  final String code;
  final int qualifiedCount;
  final int earnedCoins;
  final int earnedGems;
  final String? acceptedCode;
  final bool canAccept;
  final List<InviteFriendsMilestone> milestones;

  Map<String, dynamic> toJson() => {
        'code': code,
        'qualifiedCount': qualifiedCount,
        'earnedCoins': earnedCoins,
        'earnedGems': earnedGems,
        'canAccept': canAccept,
        if (acceptedCode != null) 'acceptedCode': acceptedCode,
        'milestones': milestones.map((m) => m.toJson()).toList(),
      };

  factory InviteFriendsData.fromJson(Map<String, dynamic> json) {
    int amount(dynamic value) => (value as num?)?.toInt() ?? 0;
    return InviteFriendsData(
      code: json['code'] as String? ?? '',
      qualifiedCount: amount(json['qualifiedCount']),
      earnedCoins: amount(json['earnedCoins']),
      earnedGems: amount(json['earnedGems']),
      canAccept: json['canAccept'] == true,
      acceptedCode: json['acceptedCode'] as String?,
      milestones: [
        for (final m in json['milestones'] as List? ?? const [])
          if (m is Map)
            InviteFriendsMilestone.fromJson(Map<String, dynamic>.from(m)),
      ],
    );
  }
}

/// A presentation-only screen; attribution and currency grants stay in the
/// authenticated referral service supplied by the caller.
class InviteFriendsScreen extends StatefulWidget {
  const InviteFriendsScreen({
    super.key,
    required this.load,
    required this.accept,
    required this.share,
    required this.onPlayWithFriends,
    this.initialCode,
    this.initialData,
    this.loadCached,
  });

  final Future<InviteFriendsData> Function() load;
  final Future<InviteFriendsData?> Function()? loadCached;
  final Future<InviteFriendsData> Function(String code) accept;
  final Future<void> Function(String code) share;
  final VoidCallback onPlayWithFriends;
  final String? initialCode;
  final InviteFriendsData? initialData;

  @override
  State<InviteFriendsScreen> createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends State<InviteFriendsScreen>
    with WidgetsBindingObserver {
  static const _gold = Color(0xFFFFDC35);
  static const _muted = Color(0xFFD0C4F3);
  late final TextEditingController _inviteCode;
  final _acceptPanelKey = GlobalKey();
  bool _initialCodeRevealed = false;
  DateTime? _lastResumeRefresh;
  InviteFriendsData? _data;
  String? _working;
  String? _error;
  String? _acceptError;
  String? _notice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inviteCode = TextEditingController(text: widget.initialCode ?? '');
    _data = widget.initialData;
    _initAndRefresh();
  }

  Future<void> _initAndRefresh() async {
    if (_data == null && widget.loadCached != null) {
      try {
        final cached = await widget.loadCached!();
        if (mounted && cached != null && _data == null) {
          setState(() => _data = cached);
        }
      } catch (_) {}
    }
    await _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inviteCode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastResumeRefresh == null ||
          now.difference(_lastResumeRefresh!) > const Duration(seconds: 15)) {
        _lastResumeRefresh = now;
        unawaited(_refresh());
      }
    }
  }

  Future<void> _refresh() async {
    if (_working != null) return;
    setState(() {
      _working = 'load';
      _error = null;
    });
    try {
      final data = await widget.load();
      if (mounted) {
        setState(() => _data = data);
        if (!_initialCodeRevealed &&
            (widget.initialCode?.trim().isNotEmpty ?? false)) {
          _initialCodeRevealed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final target = _acceptPanelKey.currentContext;
            if (!mounted || target == null) return;
            unawaited(Scrollable.ensureVisible(target,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                alignment: .8));
          });
        }
      }
    } catch (error) {
      if (mounted) {
        if (_data == null) {
          setState(() => _error = _message(error));
        } else {
          final msg = _message(error);
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(msg),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  String _message(Object error) {
    final text = error
        .toString()
        .replaceFirst(RegExp(r'^(Exception|StateError|Bad state):\s*'), '');
    return text.isEmpty
        ? 'تعذّر إتمام الطلب. تحقق من الاتصال وحاول مجددًا.'
        : text;
  }

  Future<void> _share() async {
    final data = _data;
    if ((_working != null && _working != 'load') ||
        data == null ||
        data.code.isEmpty) {
      return;
    }
    setState(() {
      _working = 'share';
      _error = null;
      _notice = null;
    });
    try {
      await widget.share(data.code);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  Future<void> _accept() async {
    final code = _inviteCode.text.trim();
    if (_working != null || _data?.canAccept != true) return;
    if (code.isEmpty) {
      setState(() => _acceptError = 'أدخل كود صديقك أولًا.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _working = 'accept';
      _error = null;
      _acceptError = null;
      _notice = null;
    });
    try {
      final data = await widget.accept(code);
      if (mounted) {
        setState(() {
          _data = data;
          _notice = 'تم قبول الدعوة! أُضيفت مكافأتك ومكافأة صديقك.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _acceptError = _message(error));
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  Future<void> _copyCode() async {
    final code = _data?.code;
    if (code == null || code.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (mounted) {
        setState(() => _notice = 'تم نسخ كود دعوتك. أرسله لأصدقائك!');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر نسخ الكود. حاول مجددًا.');
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFF171047),
          body: Stack(children: [
            const Positioned.fill(child: CustomPaint(painter: _InviteSky())),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1230),
                  child: Column(children: [
                    _header(),
                    Expanded(
                        child: LayoutBuilder(builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 760;
                      if (wide) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 10,
                                  child: SingleChildScrollView(
                                    child: _invitationHero(compact: true),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 11,
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _details(),
                                  ),
                                ),
                              ]),
                        );
                      }
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                        child: Column(children: [
                          _invitationHero(compact: false),
                          const SizedBox(height: 24),
                          _details(),
                        ]),
                      );
                    })),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      );

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 5, 18, 5),
        child: Row(children: [
          GameBackButton(onPressed: () => Navigator.of(context).maybePop()),
          const Expanded(
            child: Text('دعوة الأصدقاء',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                          color: Color(0xFF08051E),
                          offset: Offset(0, 3),
                          blurRadius: 2)
                    ])),
          ),
          IconButton(
            tooltip: 'تحديث الدعوات',
            onPressed: _working == null ? _refresh : null,
            icon: _working == 'load'
                ? const SizedBox.square(
                    dimension: 20,
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: _gold))
                : const Icon(Icons.refresh_rounded, color: _muted),
          ),
        ]),
      );

  Widget _invitationHero({required bool compact}) => Column(children: [
        LayoutBuilder(
          builder: (context, area) => SizedBox(
            height:
                math.min(compact ? 250.0 : 280.0, area.maxWidth * 1686 / 2528),
            width: double.infinity,
            child: adaptiveAssetImage(
              'assets/social/invite_friends_hero.png',
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              filterQuality: FilterQuality.medium,
              semanticLabel:
                  'ثلاثة أصدقاء يشاركون اللعب على هواتفهم في أرض التحدي',
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.groups_rounded,
                    size: 150, color: Color(0xFFC7B7FF)),
              ),
            ),
          ),
        ),
        _ArcadeButton(
          key: const Key('share-referral'),
          label: 'دعوة الأصدقاء',
          icon: Icons.person_add_alt_1_rounded,
          colors: const [
            Color(0xFFFFF900),
            Color(0xFFFFCE00),
            Color(0xFFFFAC00)
          ],
          edge: const Color(0xFFBD6800),
          foreground: const Color(0xFF502171),
          busy: _working == 'share',
          onTap: _data != null && (_working == null || _working == 'load')
              ? _share
              : null,
          large: true,
        ),
        const SizedBox(height: 10),
        const Text('أصدقاء أكثر، تحديات أجمل، ومكافآت للجميع!',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: _muted, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        _ArcadeButton(
          key: const Key('play-with-friends'),
          label: 'العب مع أصدقائك',
          icon: Icons.sports_esports_rounded,
          colors: const [
            Color(0xFFD72BFF),
            Color(0xFFB80AEA),
            Color(0xFF850EAA)
          ],
          edge: const Color(0xFF560A79),
          onTap: _working == 'accept' ? null : widget.onPlayWithFriends,
        ),
      ]);

  Widget _details() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _rewardPanel(),
        if (_data == null && _working == 'load') ...[
          const SizedBox(height: 16),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _gold)),
            SizedBox(width: 10),
            Flexible(
                child: Text('جارٍ تجهيز كود دعوتك ومكافآتك…',
                    style: TextStyle(color: _muted, fontSize: 12))),
          ]),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          _feedback(_error!, error: true),
        ],
        if (_notice != null) ...[
          const SizedBox(height: 10),
          _feedback(_notice!),
        ],
        if (_data != null) ...[
          const SizedBox(height: 12),
          _codePanel(),
          const SizedBox(height: 12),
          _statistics(),
          if (_data!.milestones.isNotEmpty) ...[
            const SizedBox(height: 16),
            _milestonePanel(),
          ],
          const SizedBox(height: 14),
          KeyedSubtree(key: _acceptPanelKey, child: _acceptPanel()),
        ] else if (_working == null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة')),
        ],
        const SizedBox(height: 12),
        const Text(
            'للأصدقاء الجدد خلال أول ٧ أيام من إنشاء الحساب. تُحتسب الدعوة مرة واحدة بعد تثبيت اللعبة وتسجيل الدخول وقبول الكود. المكافآت عملات وجواهر داخل اللعبة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, height: 1.6, fontSize: 10)),
      ]);

  Widget _rewardPanel() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: _panelDecoration(const Color(0xFF4C2688)),
        child: Column(children: [
          const Text('ادعُهم.. واربحوا معًا!',
              style: TextStyle(
                  color: _gold, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          const Text('عن كل صديق جديد يقبل دعوتك',
              style: TextStyle(color: Colors.white, fontSize: 12)),
          const SizedBox(height: 11),
          Row(children: [
            Expanded(child: _rewardGroup('مكافأتك', 1000, 10, true)),
            Container(
                width: 1,
                height: 45,
                color: Colors.white.withValues(alpha: .17)),
            Expanded(child: _rewardGroup('هدية لصديقك', 500, 5, false)),
          ]),
        ]),
      );

  Widget _rewardGroup(String title, int coins, int gems, bool highlighted) =>
      Column(children: [
        Text(title,
            style: TextStyle(
                color: highlighted ? _gold : _muted,
                fontSize: 11,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              _currency(coins, gem: false),
              _currency(gems, gem: true),
            ]),
      ]);

  Widget _currency(int amount, {required bool gem, double size = 17}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(gem ? Icons.diamond_rounded : Icons.monetization_on_rounded,
              size: size + 3,
              color: gem ? const Color(0xFF6DE5FF) : _gold,
              shadows: const [
                Shadow(
                    color: Color(0x99000000),
                    offset: Offset(0, 2),
                    blurRadius: 2)
              ]),
          const SizedBox(width: 4),
          Text(_number(amount),
              textDirection: TextDirection.ltr,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: size)),
        ],
      );

  Widget _codePanel() => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
        decoration: _panelDecoration(const Color(0xFF2A1C62)),
        child: Row(children: [
          const Icon(Icons.confirmation_number_rounded, color: _gold, size: 25),
          const SizedBox(width: 10),
          const Text('كود دعوتك',
              style: TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(width: 10),
          Expanded(
              child: SelectableText(_data!.code,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .6))),
          IconButton(
              key: const Key('copy-referral-code'),
              tooltip: 'نسخ كود الدعوة',
              onPressed: _copyCode,
              icon: const Icon(Icons.copy_rounded, size: 21, color: _gold)),
        ]),
      );

  Widget _statistics() => Row(children: [
        Expanded(
            child: _stat('أصدقاء انضموا', _data!.qualifiedCount,
                Icons.groups_rounded, const Color(0xFFBB9BFF))),
        const SizedBox(width: 8),
        Expanded(
            child: _stat('عملات ربحتها', _data!.earnedCoins,
                Icons.monetization_on_rounded, _gold)),
        const SizedBox(width: 8),
        Expanded(
            child: _stat('جواهر ربحتها', _data!.earnedGems,
                Icons.diamond_rounded, const Color(0xFF6DE5FF))),
      ]);

  Widget _stat(String label, int value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 5),
        decoration: _panelDecoration(const Color(0xFF221654)),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 5),
            Flexible(
                child: Text(_number(value),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 19))),
          ]),
          const SizedBox(height: 3),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 10)),
        ]),
      );

  Widget _milestonePanel() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Row(children: [
          Icon(Icons.card_giftcard_rounded, color: _gold, size: 19),
          SizedBox(width: 7),
          Expanded(
            child: Text('لمّ الشلّة وخذ مكافآت إضافية',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 9),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < _data!.milestones.length; i++) ...[
            if (i != 0) const SizedBox(width: 8),
            Expanded(child: _milestone(_data!.milestones[i])),
          ],
        ]),
        const SizedBox(height: 6),
        const Text('تُضاف المكافآت تلقائيًا عند اكتمال العدد',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 10)),
      ]);

  Widget _milestone(InviteFriendsMilestone milestone) {
    final progress = (_data!.qualifiedCount / milestone.count).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: milestone.claimed
            ? const Color(0xFF294C54)
            : const Color(0xFF2E1C62),
        border: Border.all(
            color: milestone.claimed
                ? const Color(0xFF6BE6AF)
                : const Color(0xFF69428D)),
      ),
      child: Column(children: [
        Icon(
            milestone.claimed
                ? Icons.verified_rounded
                : Icons.card_giftcard_rounded,
            color: milestone.claimed ? const Color(0xFF6BE6AF) : _gold,
            size: 24),
        const SizedBox(height: 3),
        Text('${milestone.count} أصدقاء',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12)),
        const SizedBox(height: 5),
        Wrap(
            alignment: WrapAlignment.center,
            spacing: 5,
            runSpacing: 3,
            children: [
              _currency(milestone.coins, gem: false, size: 11),
              _currency(milestone.gems, gem: true, size: 11),
            ]),
        const SizedBox(height: 8),
        ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: progress,
              backgroundColor: const Color(0xFF140C38),
              color: milestone.claimed ? const Color(0xFF6BE6AF) : _gold,
            )),
        const SizedBox(height: 4),
        Text(
            milestone.claimed
                ? 'تمت إضافتها'
                : '${math.min(_data!.qualifiedCount, milestone.count)} / ${milestone.count}',
            textDirection:
                milestone.claimed ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(
                color: milestone.claimed ? const Color(0xFF9BFFD0) : _muted,
                fontSize: 10)),
      ]),
    );
  }

  Widget _acceptPanel() {
    if (_data!.acceptedCode != null) {
      return _feedback('سبق أن قبلت دعوة صديقك. الآن دورك تدعو شلّتك!');
    }
    if (!_data!.canAccept) {
      if (widget.initialCode?.trim().isNotEmpty ?? false) {
        return _feedback(
            'لا يمكن لهذا الحساب قبول دعوة جديدة. يمكنك دعوة أصدقائك والحصول على المكافآت.');
      }
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: _panelDecoration(const Color(0xFF221654)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('وصلك كود من صديق؟',
            style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        const Text('اقبل دعوته وخذ 500 عملة و5 جواهر',
            style: TextStyle(color: _muted, fontSize: 11)),
        const SizedBox(height: 9),
        Row(children: [
          Expanded(
              child: TextField(
            key: const Key('accept-referral-code'),
            controller: _inviteCode,
            enabled: _working == null,
            textDirection: TextDirection.ltr,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _accept(),
            onChanged: (_) {
              if (_acceptError != null) setState(() => _acceptError = null);
            },
            style: const TextStyle(
                color: Colors.white, fontSize: 13, letterSpacing: 1),
            decoration: InputDecoration(
              hintText: 'CL-XXXXXXXXXXXX',
              hintStyle:
                  const TextStyle(color: Color(0xFF8B7DB7), fontSize: 12),
              labelText: 'كود الدعوة',
              errorText: _acceptError,
              errorMaxLines: 3,
              labelStyle: const TextStyle(color: _muted, fontSize: 12),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
            ),
          )),
          const SizedBox(width: 8),
          FilledButton(
            key: const Key('accept-referral'),
            onPressed: _working == null ? _accept : null,
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8852EE),
                foregroundColor: Colors.white,
                minimumSize: const Size(84, 46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11))),
            child: _working == 'accept'
                ? const SizedBox.square(
                    dimension: 19,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('قبول الدعوة',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ]),
      ]),
    );
  }

  Widget _feedback(String text, {bool error = false}) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
            color: error ? const Color(0xFF4C203E) : const Color(0xFF203F4C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color:
                    error ? const Color(0xFFBD6383) : const Color(0xFF52B49B))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
              error
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              size: 19,
              color: error ? const Color(0xFFFFB6CE) : const Color(0xFF8AF0C5)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: error
                          ? const Color(0xFFFFD1DF)
                          : const Color(0xFFB9FFE5),
                      fontSize: 12,
                      height: 1.5))),
        ]),
      );

  BoxDecoration _panelDecoration(Color color) => BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color, Color.lerp(color, const Color(0xFF100B34), .35)!]),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x25000000), offset: Offset(0, 3), blurRadius: 5)
        ],
      );

  String _number(int value) => value.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},');
}

class _ArcadeButton extends StatelessWidget {
  const _ArcadeButton(
      {super.key,
      required this.label,
      required this.icon,
      required this.colors,
      required this.edge,
      this.onTap,
      this.busy = false,
      this.large = false,
      this.foreground = Colors.white});

  final String label;
  final IconData icon;
  final List<Color> colors;
  final Color edge;
  final Color foreground;
  final VoidCallback? onTap;
  final bool busy;
  final bool large;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onTap != null,
        child: Container(
          padding: const EdgeInsets.only(bottom: 5),
          decoration: BoxDecoration(
              color: edge,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x70060023),
                    offset: Offset(0, 6),
                    blurRadius: 4)
              ]),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(19),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: colors),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                    color: Colors.white.withValues(alpha: .3), width: 2),
              ),
              child: InkWell(
                onTap: onTap,
                child: SizedBox(
                  height: large ? 65 : 51,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Opacity(
                      opacity: onTap == null && !busy ? .65 : 1,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (busy)
                              SizedBox.square(
                                  dimension: 27,
                                  child: CircularProgressIndicator(
                                      color: foreground, strokeWidth: 3))
                            else
                              Icon(icon,
                                  color: foreground,
                                  size: large ? 35 : 29,
                                  shadows: [
                                    Shadow(
                                        color: edge, offset: const Offset(0, 2))
                                  ]),
                            const SizedBox(width: 13),
                            Flexible(
                                child: Text(label,
                                    maxLines: 1,
                                    style: TextStyle(
                                        color: foreground,
                                        fontSize: large ? 26 : 21,
                                        fontWeight: FontWeight.w900,
                                        shadows: [
                                          Shadow(
                                              color:
                                                  edge.withValues(alpha: .35),
                                              offset: const Offset(0, 2))
                                        ]))),
                          ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _InviteSky extends CustomPainter {
  const _InviteSky();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
        bounds,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3C1387), Color(0xFF21105C), Color(0xFF130D3C)],
          ).createShader(bounds));
    final glow = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x773F52E7), Color(0x003F52E7)],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width * .72, size.height * .2),
          radius: size.width * .6));
    canvas.drawRect(bounds, glow);
    final random = math.Random(46);
    for (var i = 0; i < 52; i++) {
      final center = Offset(
          random.nextDouble() * size.width, random.nextDouble() * size.height);
      canvas.drawCircle(
          center,
          random.nextDouble() * 1.8 + .5,
          Paint()
            ..color = Colors.white
                .withValues(alpha: random.nextDouble() * .19 + .03));
    }
  }

  @override
  bool shouldRepaint(covariant _InviteSky oldDelegate) => false;
}
