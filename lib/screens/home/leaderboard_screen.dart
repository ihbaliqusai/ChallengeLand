import '../../widgets/game_back_button.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/app_state.dart';
import '../../core/leaderboard_countries.dart';
import '../../core/trophy_league.dart';
import '../../services/leaderboard_service.dart';
import '../../widgets/friend_challenge_modal.dart';
import 'widgets/leaderboard_art.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, this.firestore, this.service});
  final FirebaseFirestore? firestore;
  final LeaderboardService? service;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final LeaderboardService _service;
  final _scrollController = ScrollController();
  LeaderboardScope _scope = LeaderboardScope.world;
  List<LeaderboardPlayer> _players = const [];
  String? _uid, _countryCode, _error;
  bool _initialized = false, _countryLoaded = false;
  bool _loading = true, _savingCountry = false;
  int _loadGeneration = 0;
  int _countryRevision = 0;
  bool _hasResult = false;
  String? _displayedBoard;
  StreamSubscription<List<LeaderboardPlayer>>? _playersSubscription;
  Completer<void>? _firstResult;
  Future<String?>? _countryRequest;

  @override
  void initState() {
    super.initState();
    _service =
        widget.service ?? LeaderboardService(firestore: widget.firestore);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.watch<AppState>();
    final uid = state.currentUser?.uid;
    if (!_initialized || _uid != uid) {
      _initialized = true;
      _uid = uid;
      _countryRevision++;
      _countryRequest = null;
      _countryCode = uid == null ? null : _service.cachedCountry(uid);
      _countryLoaded = uid == null || _countryCode != null;
      _savingCountry = false;
      _players = const [];
      _hasResult = false;
      _displayedBoard = null;
      unawaited(_load());
      if (uid != null) {
        // Country and progression updates must never delay world/friend rows.
        unawaited(_resolveCountry().then<void>((_) {}, onError: (_) {}));
      }
      unawaited(Future<void>.microtask(() async {
        try {
          await state.syncPublicProfile();
        } catch (_) {
          // Rankings remain readable when a separate progression sync fails.
        }
      }));
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _countryRevision++;
    unawaited(_playersSubscription?.cancel());
    _finishFirstResult();
    _scrollController.dispose();
    super.dispose();
  }

  void _finishFirstResult() {
    final result = _firstResult;
    if (result != null && !result.isCompleted) result.complete();
    _firstResult = null;
  }

  Future<String?> _resolveCountry() {
    final uid = _uid;
    if (uid == null) return Future.value(null);
    final pending = _countryRequest;
    if (pending != null) return pending;
    final revision = _countryRevision;
    final request = _service.loadCountry(uid).then((code) {
      if (!mounted || uid != _uid || revision != _countryRevision) return code;
      final changed = code != _countryCode;
      setState(() {
        _countryCode = code;
        _countryLoaded = true;
      });
      if (changed &&
          _scope == LeaderboardScope.country &&
          _playersSubscription != null) {
        unawaited(_load());
      }
      return code;
    });
    _countryRequest = request;
    return request;
  }

  String get _boardKey =>
      '${_uid ?? ''}/${_scope.name}/${_scope == LeaderboardScope.country ? _countryCode ?? '' : ''}';

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final uid = _uid;
    final scope = _scope;
    unawaited(_playersSubscription?.cancel());
    _playersSubscription = null;
    _finishFirstResult();
    final firstResult = Completer<void>();
    _firstResult = firstResult;
    final cached =
        _service.cached(scope: scope, uid: uid, countryCode: _countryCode);
    final sameBoard = _displayedBoard == _boardKey;
    setState(() {
      _players = cached ?? (sameBoard ? _players : const []);
      _hasResult = cached != null || (sameBoard && _hasResult);
      _displayedBoard = _boardKey;
      _loading = true;
      _error = null;
    });
    try {
      if (scope == LeaderboardScope.country && !_countryLoaded && uid != null) {
        // Only the country query depends on this profile field.
        if (_countryRequest != null) {
          try {
            await _countryRequest;
          } catch (_) {
            if (!mounted || generation != _loadGeneration) return;
            _countryRequest = null;
          }
        }
        if (!_countryLoaded) await _resolveCountry();
        if (!mounted || generation != _loadGeneration) return;
        final countryCache =
            _service.cached(scope: scope, uid: uid, countryCode: _countryCode);
        setState(() {
          _players = countryCache ?? const [];
          _hasResult = countryCache != null;
          _displayedBoard = _boardKey;
        });
      }
      _playersSubscription = _service
          .watch(
        scope: scope,
        uid: uid,
        countryCode: _countryCode,
      )
          .listen((players) {
        if (!mounted || generation != _loadGeneration) return;
        setState(() {
          _players = players;
          _hasResult = true;
          _loading = false;
          _error = null;
        });
        _finishFirstResult();
      }, onError: (Object error) {
        if (!mounted || generation != _loadGeneration) return;
        _reportLoadError(scope, error);
        setState(() {
          _loading = false;
          _error = 'تعذر تحميل لوحة الصدارة. تحقق من اتصالك وحاول مجددًا.';
        });
        _finishFirstResult();
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      _reportLoadError(scope, error);
      _countryRequest = null;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل لوحة الصدارة. تحقق من اتصالك وحاول مجددًا.';
      });
      _finishFirstResult();
    }
    return firstResult.future;
  }

  void _reportLoadError(LeaderboardScope scope, Object error) {
    final code = error is FirebaseException ? error.code : error.runtimeType;
    final country = scope == LeaderboardScope.country
        ? _countryCode ?? 'unresolved'
        : 'n/a';
    debugPrint(
        '[Leaderboard] scope=${scope.name} country=$country load failed: $code');
  }

  void _selectScope(LeaderboardScope scope) {
    if (_scope == scope) return;
    HapticFeedback.selectionClick();
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() => _scope = scope);
    _load();
  }

  Future<void> _chooseCountry() async {
    if (_uid == null || _savingCountry) return;
    final uid = _uid!;
    final selected = await showDialog<String>(
        context: context,
        builder: (_) => _CountryPicker(selected: _countryCode));
    if (selected == null || !mounted || uid != _uid) return;
    // A pending read must not restore the previous country after this choice.
    final saveGeneration = ++_loadGeneration;
    _countryRevision++;
    _countryRequest = null;
    setState(() {
      _savingCountry = true;
      _loading = true;
      _error = null;
    });
    try {
      await _service.saveCountry(uid, selected);
      if (!mounted || uid != _uid) return;
      setState(() {
        _countryCode = selected;
        _countryLoaded = true;
      });
      await _load();
    } catch (_) {
      if (!mounted || uid != _uid || saveGeneration != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = 'تعذر حفظ بلدك. حاول مجددًا.';
      });
    } finally {
      if (mounted && uid == _uid) setState(() => _savingCountry = false);
    }
  }

  bool _isMe(LeaderboardPlayer player, AppState state) =>
      (_uid != null && player.uid == _uid) ||
      (state.friendCode.isNotEmpty && player.friendCode == state.friendCode);

  List<LeaderboardPlayer> _currentPlayers(AppState state) {
    final players = _players.map((player) {
      if (!_isMe(player, state)) return player;
      return LeaderboardPlayer(
          uid: player.uid,
          username: player.username,
          trophies: state.trophies,
          level: state.level,
          xp: state.xp,
          photoUrl: player.photoUrl,
          friendCode: player.friendCode,
          countryCode: player.countryCode,
          teamName: player.teamName,
          wins: state.playerStats['wins'] ?? player.wins,
          lastSeenAt: player.lastSeenAt);
    }).where((player) {
      if (_scope != LeaderboardScope.friends && player.trophies <= 0) {
        return false;
      }
      if (_players.length == LeaderboardService.maxPlayers &&
          _isMe(player, state)) {
        final boundary = _players.last;
        // A local loss below a full query window cannot establish a new rank.
        if (player.trophies < boundary.trophies ||
            (player.trophies == boundary.trophies &&
                player.uid.compareTo(boundary.uid) < 0)) {
          return false;
        }
      }
      return true;
    }).toList();
    players.sort((a, b) {
      final score = b.trophies.compareTo(a.trophies);
      return score != 0 ? score : b.uid.compareTo(a.uid);
    });
    return players;
  }

  void _openPlayer(LeaderboardPlayer player, int rank) {
    HapticFeedback.lightImpact();
    final isMe = _isMe(player, context.read<AppState>());
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF190D42),
        showDragHandle: true,
        builder: (sheetContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: SafeArea(
                child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _FramedAvatar(player: player, size: 72),
                const SizedBox(height: 12),
                Text(player.username, style: _gameText(22)),
                const SizedBox(height: 6),
                Text('المركز $rank • ${_score(player.trophies)} كأس',
                    style: _gameText(15)),
                const SizedBox(height: 6),
                Text('المستوى ${player.level} • ${player.wins} انتصار',
                    style: _gameText(13)),
                if (player.countryCode.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LeaderboardCountryFlag(
                          code: player.countryCode, width: 18),
                      const SizedBox(width: 6),
                      Flexible(
                          child: Text(
                              leaderboardCountries[player.countryCode] ??
                                  player.countryCode,
                              style: _gameText(13))),
                    ],
                  ),
                ],
                if (player.friendCode.isNotEmpty)
                  TextButton.icon(
                      onPressed: () => Clipboard.setData(
                          ClipboardData(text: player.friendCode)),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: Text('كود الصداقة: ${player.friendCode}')),
                if (!isMe && player.friendCode.isNotEmpty)
                  FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        FriendChallengeModal.show(context,
                            initialFriendCode: player.friendCode);
                      },
                      icon: const Icon(Icons.sports_esports_rounded),
                      label: const Text('تحدي اللاعب')),
              ]),
            ))));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final players = _currentPlayers(state);
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: const Color(0xFF14072F),
            body: Stack(children: [
              const Positioned.fill(child: LeaderboardBackdrop()),
              SafeArea(
                  left: false,
                  right: false,
                  child: LayoutBuilder(builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth -
                        MediaQuery.paddingOf(context).horizontal;
                    final landscape = availableWidth > constraints.maxHeight;
                    final contentWidth = math.min(availableWidth, 880.0);
                    final rowHeight = (contentWidth * .15).clamp(48.0, 78.0);
                    return Column(children: [
                      SafeArea(
                          top: false,
                          bottom: false,
                          child: Column(children: [
                            SizedBox(
                                height: landscape ? 48 : 64,
                                child: Directionality(
                                    textDirection: Directionality.of(context),
                                    child: Row(children: [
                                      const SizedBox(width: 8),
                                      GameBackButton(
                                          onPressed: () =>
                                              Navigator.of(context).maybePop()),
                                      const Spacer(),
                                      if (_scope == LeaderboardScope.country &&
                                          _countryCode != null)
                                        TextButton.icon(
                                            key: const ValueKey(
                                                'leaderboard-change-country'),
                                            onPressed: _savingCountry
                                                ? null
                                                : _chooseCountry,
                                            icon: const Icon(
                                                Icons
                                                    .edit_location_alt_outlined,
                                                color: Colors.white70,
                                                size: 17),
                                            label: Text('تغيير البلد',
                                                style: _gameText(12))),
                                      const SizedBox(width: 12),
                                    ]))),
                            _ScopeTabs(
                                scope: _scope,
                                countryName: leaderboardCountries[_countryCode],
                                onSelect: _selectScope),
                          ])),
                      Container(
                          key: const ValueKey('leaderboard-title-banner'),
                          width: double.infinity,
                          height: landscape ? 48 : 52,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF478CE1),
                                    Color(0xFF1C49B2)
                                  ]),
                              border: Border.symmetric(
                                  horizontal: BorderSide(
                                      color: Color(0xFF36B9F5), width: 2))),
                          child: Semantics(
                              namesRoute: true,
                              label: 'لوحة الصدارة',
                              child:
                                  Text('أفضل اللاعبين', style: _gameText(24)))),
                      Expanded(
                        child: SafeArea(
                            top: false,
                            bottom: false,
                            child: Stack(children: [
                              Positioned.fill(
                                  child: RefreshIndicator(
                                      onRefresh: _load,
                                      color: const Color(0xFFFFD341),
                                      backgroundColor: const Color(0xFF214FAB),
                                      child: _buildList(
                                          players,
                                          state,
                                          contentWidth,
                                          rowHeight,
                                          availableWidth))),
                              if (_loading && _hasResult)
                                const Align(
                                  alignment: Alignment.topCenter,
                                  child: LinearProgressIndicator(
                                    minHeight: 2,
                                    color: Color(0xFF72D6FF),
                                    backgroundColor: Colors.transparent,
                                  ),
                                ),
                              if (_error != null && _hasResult)
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Material(
                                    color: const Color(0xEE190D42),
                                    borderRadius: BorderRadius.circular(12),
                                    child: TextButton.icon(
                                      onPressed: _load,
                                      icon: const Icon(Icons.refresh_rounded,
                                          color: Colors.white),
                                      label: Text(
                                          'تعذر التحديث • إعادة المحاولة',
                                          style: _gameText(13)),
                                    ),
                                  ),
                                ),
                            ])),
                      ),
                    ]);
                  })),
            ])));
  }

  Widget _buildList(List<LeaderboardPlayer> players, AppState state,
      double contentWidth, double rowHeight, double availableWidth) {
    String? message, action;
    VoidCallback? onAction;
    if (_error != null && !_hasResult) {
      message = _error;
      action = 'إعادة المحاولة';
      onAction = _load;
    } else if (_scope != LeaderboardScope.world && _uid == null) {
      message = _scope == LeaderboardScope.friends
          ? 'سجّل الدخول لعرض ترتيبك بين أصدقائك'
          : 'سجّل الدخول لعرض ترتيب بلدك';
    } else if (_scope == LeaderboardScope.country && _countryCode == null) {
      message = 'تعذر تحديد بلدك تلقائيًا. اختره للمنافسة مع لاعبيه';
      action = 'اختيار البلد';
      onAction = _chooseCountry;
    } else if (_hasResult && players.isEmpty) {
      message = _scope == LeaderboardScope.friends
          ? 'أضف أصدقاء لتبدأ المنافسة معهم'
          : 'لا يوجد لاعبون في هذا التصنيف حتى الآن';
    }
    if ((!_loading || _hasResult) && message != null) {
      return LayoutBuilder(
          builder: (context, constraints) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(28),
                  children: [
                    SizedBox(height: math.max(12, constraints.maxHeight * .15)),
                    const Center(child: LeaderboardTrophy(size: 60)),
                    const SizedBox(height: 18),
                    Text(message!,
                        textAlign: TextAlign.center, style: _gameText(16)),
                    if (action != null) ...[
                      const SizedBox(height: 18),
                      Center(
                          child: FilledButton(
                              onPressed: onAction,
                              style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF3088E5)),
                              child: Text(action))),
                    ],
                  ]));
    }
    final inset = math.max(16.0, (availableWidth - contentWidth * .84) / 2);
    return Scrollbar(
        controller: _scrollController,
        radius: const Radius.circular(4),
        child: ListView.separated(
            key: ValueKey('leaderboard-list-${_scope.name}'),
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(inset, 12, inset, 22),
            itemCount: _loading && !_hasResult ? 8 : players.length,
            separatorBuilder: (_, __) => SizedBox(height: rowHeight * .2),
            itemBuilder: (context, index) {
              if (_loading && !_hasResult) {
                return _LoadingRow(height: rowHeight);
              }
              final player = players[index];
              return _PlayerRow(
                  key: ValueKey('leaderboard-player-${player.uid}'),
                  player: player,
                  rank: index + 1,
                  height: rowHeight,
                  isMe: _isMe(player, state),
                  onTap: () => _openPlayer(player, index + 1));
            }));
  }
}

class _ScopeTabs extends StatelessWidget {
  const _ScopeTabs(
      {required this.scope, required this.countryName, required this.onSelect});
  final LeaderboardScope scope;
  final String? countryName;
  final ValueChanged<LeaderboardScope> onSelect;

  @override
  Widget build(BuildContext context) => Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: FractionallySizedBox(
              widthFactor: .65,
              child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: LeaderboardScope.values.map((tab) {
                        final selected = tab == scope;
                        final label = switch (tab) {
                          LeaderboardScope.world => 'العالم',
                          LeaderboardScope.country => countryName ?? 'بلدي',
                          LeaderboardScope.friends => 'أصدقائي',
                        };
                        return Expanded(
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Semantics(
                                    selected: selected,
                                    button: true,
                                    label: switch (tab) {
                                      LeaderboardScope.world =>
                                        'على مستوى العالم',
                                      LeaderboardScope.country =>
                                        'على مستوى بلدي',
                                      LeaderboardScope.friends =>
                                        'على مستوى أصدقائي',
                                    },
                                    child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                            key: ValueKey(
                                                'leaderboard-tab-${tab.name}'),
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    top: Radius.circular(11)),
                                            onTap: () {
                                              AppSettings.playClick();
                                              onSelect(tab);
                                            },
                                            child: Ink(
                                                height: 36,
                                                decoration: BoxDecoration(
                                                    color: selected
                                                        ? const Color(
                                                            0xFF4089D9)
                                                        : const Color(
                                                            0xFF28558E),
                                                    borderRadius:
                                                        const BorderRadius.vertical(
                                                            top: Radius.circular(
                                                                11)),
                                                    border: Border.all(
                                                        color: selected ? const Color(0xFF2CA7F5) : const Color(0xFF24699F),
                                                        width: 1.6)),
                                                child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: _gameText(15)))))))))));
                      }).toList())))));
}

const _rowGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF438BDB), Color(0xFF1A48B2)]);

class _PlayerRow extends StatelessWidget {
  const _PlayerRow(
      {super.key,
      required this.player,
      required this.rank,
      required this.height,
      required this.isMe,
      required this.onTap});
  final LeaderboardPlayer player;
  final int rank;
  final double height;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = player.teamName.isNotEmpty
        ? player.teamName
        : 'دوري ${TrophyProgression.leagueFor(player.trophies).nameAr}';
    return Semantics(
        button: true,
        label:
            'المركز $rank، ${player.username}، ${_score(player.trophies)} كأس${isMe ? '، أنت' : ''}',
        child: Container(
            height: height,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF07091F), offset: Offset(0, 5)),
                  BoxShadow(color: Color(0xFF193E82), offset: Offset(0, 3))
                ]),
            child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(13),
                clipBehavior: Clip.antiAlias,
                child: Ink(
                    decoration: BoxDecoration(
                        gradient: _rowGradient,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                            color: isMe
                                ? const Color(0xFF96E9FF)
                                : const Color(0xFF2DA9F4),
                            width: 1.8)),
                    child: InkWell(
                        onTap: onTap,
                        child: Directionality(
                            textDirection: TextDirection.ltr,
                            child:
                                LayoutBuilder(builder: (context, constraints) {
                              final compact = constraints.maxWidth < 400;
                              final scale =
                                  compact ? math.min(1.0, height / 60) : 1.0;
                              final avatarSize = height - 12 * scale;
                              return Row(children: [
                                Container(
                                    width: compact ? 44 * scale : 60,
                                    height: height - 3,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                        color: const Color(0xFF35A3E3)
                                            .withValues(alpha: .5),
                                        border: Border(
                                            right: BorderSide(
                                                color: Colors.white
                                                    .withValues(alpha: .07)))),
                                    child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5),
                                            child: Text('$rank',
                                                style: _gameText(compact
                                                    ? 27 * scale
                                                    : 31))))),
                                SizedBox(width: 4 * scale),
                                _FramedAvatar(player: player, size: avatarSize),
                                SizedBox(width: compact ? 9 * scale : 14),
                                Expanded(
                                    child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(player.username,
                                          textDirection:
                                              _nameDirection(player.username),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: _gameText(
                                              compact ? 20 * scale : 24)),
                                      const SizedBox(height: 1),
                                      Text(subtitle,
                                          textDirection:
                                              _nameDirection(subtitle),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: _gameText(
                                              compact ? 16 * scale : 18)),
                                    ])),
                                SizedBox(width: compact ? 5 * scale : 12),
                                _TrophyScore(
                                    trophies: player.trophies,
                                    compact: compact,
                                    scale: scale),
                                SizedBox(width: compact ? 8 * scale : 14),
                              ]);
                            })))))));
  }
}

class _FramedAvatar extends StatelessWidget {
  const _FramedAvatar({required this.player, required this.size});
  final LeaderboardPlayer player;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
      dimension: size,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
            child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * .22),
                    gradient: const SweepGradient(colors: [
                      Color(0xFFB4FF62),
                      Color(0xFF8AFAEC),
                      Color(0xFF96A2FF),
                      Color(0xFFFF6CDB),
                      Color(0xFFFFB19A),
                      Color(0xFFFFE967),
                      Color(0xFFB4FF62)
                    ]),
                    border:
                        Border.all(color: const Color(0xFF10122A), width: 1.4),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0xFF101332),
                          offset: Offset(0, 2),
                          blurRadius: 1)
                    ]),
                child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                        color: const Color(0xFF243B73),
                        borderRadius: BorderRadius.circular(size * .15),
                        border: Border.all(color: Colors.white, width: 1.3)),
                    child: player.photoUrl.trim().isEmpty
                        ? _AvatarFallback(name: player.username)
                        : Image.network(player.photoUrl,
                            fit: BoxFit.cover,
                            cacheWidth:
                                (size * MediaQuery.devicePixelRatioOf(context))
                                    .round(),
                            errorBuilder: (_, __, ___) =>
                                _AvatarFallback(name: player.username))))),
        if (player.countryCode.isNotEmpty)
          Positioned(
              left: -5,
              bottom: size * .12,
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                      color: const Color(0xFF303865),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                          color: const Color(0xFFB9A6D6), width: .7)),
                  child: LeaderboardCountryFlag(
                      code: player.countryCode, width: size * .3))),
      ]));
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final hue = name.runes.fold<int>(0, (total, unit) => total + unit) % 360;
    return DecoratedBox(
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
              HSLColor.fromAHSL(1, hue.toDouble(), .55, .52).toColor(),
              const Color(0xFF172049)
            ])),
        child: const FittedBox(
            fit: BoxFit.contain,
            child: Icon(Icons.person_rounded,
                color: Color(0xFFF1EDFF), size: 42)));
  }
}

class _TrophyScore extends StatelessWidget {
  const _TrophyScore(
      {required this.trophies, required this.compact, this.scale = 1});
  final int trophies;
  final bool compact;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 30.0 * scale : 40.0;
    return SizedBox(
        width: compact ? 84 * scale : 122,
        height: size + 2,
        child: Stack(alignment: Alignment.centerLeft, children: [
          Positioned(
              left: size * .5,
              right: 0,
              top: 5,
              bottom: 3,
              child: Container(
                  padding: EdgeInsets.only(left: size * .48, right: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: const Color(0xFF123D77),
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(
                          top: BorderSide(
                              color: Color(0xFF102B63), width: 1.5))),
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_score(trophies),
                          style: _gameText(compact ? 14 * scale : 17))))),
          LeaderboardTrophy(size: size),
        ]));
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
      label: 'جارٍ تحميل اللاعبين',
      child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
              gradient: _rowGradient,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFF2DA9F4), width: 1.8)),
          child: Row(textDirection: TextDirection.ltr, children: [
            Container(
                width: height - 18,
                height: height - 18,
                decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(9))),
            const SizedBox(width: 14),
            Expanded(child: Container(height: 10, color: Colors.white12)),
            const SizedBox(width: 22),
            const LeaderboardTrophy(size: 30),
          ])));
}

class _CountryPicker extends StatefulWidget {
  const _CountryPicker({this.selected});
  final String? selected;
  @override
  State<_CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<_CountryPicker> {
  String _query = '';

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll('ى', 'ي');

  @override
  Widget build(BuildContext context) {
    final query = _normalize(_query);
    final countries = leaderboardCountries.entries
        .where((entry) =>
            _normalize(entry.value).contains(query) ||
            entry.key.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: const Color(0xFF1C1244),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
          // The whole picker can scroll when a landscape keyboard is open.
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text('اختر بلدك', style: _gameText(19))),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'إغلاق',
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white),
                          ),
                        ],
                      ),
                      TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'ابحث عن بلدك',
                          hintStyle: TextStyle(color: Colors.white54),
                          prefixIcon: Icon(Icons.search, color: Colors.white70),
                        ),
                        onChanged: (value) =>
                            setState(() => _query = value.trim()),
                      ),
                    ],
                  ),
                ),
              ),
              if (countries.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                        child: Text('لا توجد نتائج', style: _gameText(14))),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final country = countries[index];
                        return ListTile(
                          key: ValueKey('leaderboard-country-${country.key}'),
                          leading: LeaderboardCountryFlag(
                              code: country.key, width: 26),
                          title: Text(country.value, style: _gameText(16)),
                          trailing: country.key == widget.selected
                              ? const Icon(Icons.check_rounded,
                                  color: Color(0xFF7DDEFF))
                              : null,
                          onTap: () => Navigator.of(context).pop(country.key),
                        );
                      },
                      childCount: countries.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _gameText(double size) => TextStyle(
    fontFamily: 'Leaderboard',
    fontFamilyFallback: const ['NotoSansArabic'],
    color: Colors.white,
    fontSize: size,
    height: 1.3,
    fontWeight: FontWeight.w600,
    shadows: const [
      Shadow(color: Color(0xFF102242), offset: Offset(0, 1.5), blurRadius: 1)
    ]);

TextDirection _nameDirection(String value) =>
    RegExp(r'[\u0600-\u06FF]').hasMatch(value)
        ? TextDirection.rtl
        : TextDirection.ltr;

String _score(int value) => value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},');
