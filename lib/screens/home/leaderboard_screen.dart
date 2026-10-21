import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_state.dart';
import '../../core/player_rank.dart';
import '../../core/trophy_league.dart';
import '../../services/progression_service.dart';
import '../../widgets/friend_challenge_modal.dart';
import '../../widgets/adaptive_asset_image.dart';

/// Representation of a player in the leaderboard.
class _LeaderboardPlayer {
  const _LeaderboardPlayer({
    required this.uid,
    required this.username,
    required this.trophies,
    required this.level,
    required this.xp,
    this.xpEstimated = false,
    required this.photoUrl,
    this.friendCode,
    this.wins = 0,
    this.lastSeenAt,
  });

  final String uid;
  final String username;
  final int trophies;
  final int level;
  final int xp;
  final bool xpEstimated;
  String get xpLabel => '${xpEstimated ? '≥ ' : ''}${_compactNumber(xp)} XP';
  final String photoUrl;
  final String? friendCode;
  final int wins;
  final DateTime? lastSeenAt;

  factory _LeaderboardPlayer.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final stats = ProgressionService.readStats(data);
    final nested = data['playerStats'];
    final hasStoredXp =
        data['xp'] is num || (nested is Map && nested['xp'] is num);
    final totalScore = data['totalScore'];
    return _LeaderboardPlayer(
      uid: doc.id,
      username: _resolveUsername(data),
      trophies: stats['trophies']!,
      level: stats['level']!,
      xp: stats['xp']!,
      xpEstimated: !hasStoredXp &&
          (totalScore is! num ||
              stats['xp'] != ProgressionService.integer(totalScore)),
      photoUrl: (data['photoUrl'] ?? '').toString(),
      friendCode: data['friendCode']?.toString(),
      wins: stats['wins']!,
      lastSeenAt: (data['lastSeenAt'] is Timestamp)
          ? (data['lastSeenAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory _LeaderboardPlayer.local(AppState appState) {
    final user = appState.currentUser;
    final name = user?.displayName?.trim();
    final emailName = user?.email?.split('@').first.trim();
    return _LeaderboardPlayer(
      uid: user?.uid ?? '',
      username: (name != null && name.isNotEmpty)
          ? name
          : (emailName != null && emailName.isNotEmpty)
              ? emailName
              : 'لاعب',
      trophies: appState.trophies,
      level: appState.level,
      xp: appState.xp,
      photoUrl: user?.photoURL ?? '',
      friendCode: appState.friendCode,
      wins: appState.playerStats['wins'] ?? 0,
      lastSeenAt: DateTime.now(),
    );
  }

  static String _resolveUsername(Map<String, dynamic> data) {
    final candidates = <String?>[
      data['username']?.toString(),
      data['playerName']?.toString(),
      data['displayName']?.toString(),
      data['name']?.toString(),
      data['email']?.toString().split('@').first,
    ];

    for (final candidate in candidates) {
      final normalized = candidate?.trim() ?? '';
      if (normalized.isEmpty) continue;
      final lowered = normalized.toLowerCase();
      if (lowered == 'guest' || lowered == 'player') continue;
      return normalized;
    }
    return 'لاعب';
  }
}

/// The main comprehensive Leaderboard screen.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    this.firestore,
  });

  final FirebaseFirestore? firestore;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with TickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  List<_LeaderboardPlayer> _trophyPlayers = <_LeaderboardPlayer>[];
  List<_LeaderboardPlayer> _xpPlayers = <_LeaderboardPlayer>[];
  int _loadGeneration = 0;
  String? _currentUid;

  // Active Tab: 0 = Trophies, 1 = Levels, 2 = Leagues Roadmap
  int _activeTab = 0;

  // Filter mode: 0 = All (Top 200), 1 = Top 10, 2 = Top 50, 3 = Near Me
  int _filterMode = 0;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchExpanded = false;
  String _searchQuery = '';

  // Controllers
  late final ScrollController _scrollController;
  late final AnimationController _crownAnimController;
  late final AnimationController _entranceAnimController;
  late final AnimationController _pulseAnimController;

  bool _showJumpToMyRank = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _scrollController = ScrollController()..addListener(_onScroll);

    // Crown floating & sparkling animation
    _crownAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Entrance rise animation for podium & components
    _entranceAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Subtle breathing pulse for current user aura
    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _searchController.addListener(() {
      final query = _searchController.text.trim();
      if (query != _searchQuery) {
        setState(() => _searchQuery = query);
      }
    });

    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _crownAnimController.dispose();
    _entranceAnimController.dispose();
    _pulseAnimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final show = _scrollController.offset > 240;
    if (show != _showJumpToMyRank) {
      setState(() => _showJumpToMyRank = show);
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });

    final appState = context.read<AppState>();
    _currentUid = appState.currentUser?.uid;
    try {
      await appState.checkAndAwardXpForGames();
      await appState.syncPublicProfile();
      final firestore = widget.firestore ?? FirebaseFirestore.instance;
      // Each ladder has its own server query. Legacy level-only profiles remain
      // visible while their cumulative XP is being migrated.
      final snapshots = await Future.wait([
        firestore
            .collection('public_profiles')
            .orderBy('trophies', descending: true)
            .limit(200)
            .get(),
        firestore
            .collection('public_profiles')
            .orderBy('xp', descending: true)
            .limit(200)
            .get(),
        firestore
            .collection('public_profiles')
            .orderBy('level', descending: true)
            .limit(200)
            .get(),
        firestore
            .collection('public_profiles')
            .orderBy('totalScore', descending: true)
            .limit(200)
            .get(),
      ]);
      final trophies = snapshots[0]
          .docs
          .map(_LeaderboardPlayer.fromDoc)
          .where((player) => player.trophies > 0)
          .toList();
      final experience = <String, _LeaderboardPlayer>{};
      for (final snapshot in snapshots.skip(1)) {
        for (final doc in snapshot.docs) {
          final player = _LeaderboardPlayer.fromDoc(doc);
          if (player.xp > 0) experience[player.uid] = player;
        }
      }
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _trophyPlayers = trophies;
        _xpPlayers = experience.values.toList();
        _loading = false;
      });
      _entranceAnimController.forward(from: 0.0);
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل بيانات لوحة الصدارة. تحقق من اتصالك بالإنترنت.';
      });
    }
  }

  List<_LeaderboardPlayer> _getSortedPlayers([AppState? state]) {
    final appState = state ?? (mounted ? context.read<AppState>() : null);
    final myUid = _currentUid ?? appState?.currentUser?.uid;
    final myFriendCode = appState?.friendCode;
    final source = _activeTab == 1 ? _xpPlayers : _trophyPlayers;
    final list = source.map((player) {
      final isMe = (myUid != null && myUid.isNotEmpty && player.uid == myUid) ||
          (myFriendCode != null &&
              myFriendCode.isNotEmpty &&
              player.friendCode == myFriendCode);
      if (!isMe || appState == null) return player;
      return _LeaderboardPlayer(
        uid: player.uid,
        username: player.username == 'لاعب'
            ? _LeaderboardPlayer.local(appState).username
            : player.username,
        // Trophy losses must appear immediately as well as gains.
        trophies: appState.trophies,
        level: appState.level,
        xp: appState.xp,
        photoUrl: player.photoUrl,
        friendCode: player.friendCode ?? myFriendCode,
        wins: appState.playerStats['wins'] ?? player.wins,
        lastSeenAt: player.lastSeenAt,
      );
    }).where((player) {
      if (_activeTab == 1) return player.xp > 0;
      if (player.trophies <= 0) return false;
      final isMe = (myUid != null && myUid.isNotEmpty && player.uid == myUid) ||
          (myFriendCode != null &&
              myFriendCode.isNotEmpty &&
              player.friendCode == myFriendCode);
      if (isMe && source.length >= 200) {
        // A pending local loss can move this account below the loaded
        // window. Its new global rank requires another server query.
        final boundary = source.last;
        if (player.trophies < boundary.trophies ||
            (player.trophies == boundary.trophies &&
                player.uid.compareTo(boundary.uid) < 0)) {
          return false;
        }
      }
      return true;
    }).toList();
    list.sort((a, b) {
      final scoreComparison = _activeTab == 1
          ? b.xp.compareTo(a.xp)
          : b.trophies.compareTo(a.trophies);
      // Firestore uses descending document ID to break descending score ties.
      return scoreComparison != 0 ? scoreComparison : b.uid.compareTo(a.uid);
    });
    // A player outside this window is shown only in their summary. Appending
    // them here would invent a global rank of 201.
    return list.take(200).toList(growable: false);
  }

  List<_LeaderboardPlayer> _filterPlayers(List<_LeaderboardPlayer> sorted) {
    var result = sorted;

    // Search query filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((p) =>
              p.username.toLowerCase().contains(q) ||
              (p.friendCode != null && p.friendCode!.toLowerCase().contains(q)))
          .toList();
      return result;
    }

    // Filter mode
    if (_filterMode == 1) {
      // Top 10
      result = result.take(10).toList();
    } else if (_filterMode == 2) {
      // Top 50
      result = result.take(50).toList();
    } else if (_filterMode == 3) {
      // Near Me (±5 around current user)
      final appState = mounted ? context.read<AppState>() : null;
      final myUid = _currentUid ?? appState?.currentUser?.uid;
      final myFriendCode = appState?.friendCode;
      final myIdx = sorted.indexWhere((p) =>
          (myUid != null && myUid.isNotEmpty && p.uid == myUid) ||
          (myFriendCode != null &&
              myFriendCode.isNotEmpty &&
              p.friendCode == myFriendCode));
      if (myIdx != -1) {
        final start = math.max(0, myIdx - 5);
        final end = math.min(sorted.length, myIdx + 6);
        result = sorted.sublist(start, end);
      } else {
        result = const [];
      }
    }

    return result;
  }

  void _scrollToMyRank(int myGlobalRank) {
    if (!_scrollController.hasClients || myGlobalRank <= 0) return;
    HapticFeedback.selectionClick();

    // Approximate offset: header & podium are around 540px
    final targetOffset = 520.0 + ((myGlobalRank - 1) * 88.0);
    final clamped = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeInOutCubic,
    );
  }

  void _openPlayerModal(_LeaderboardPlayer player, int rank) {
    HapticFeedback.lightImpact();
    final appState = mounted ? context.read<AppState>() : null;
    final myUid = _currentUid ?? appState?.currentUser?.uid;
    final myFriendCode = appState?.friendCode;
    final isMe = (myUid != null && myUid.isNotEmpty && player.uid == myUid) ||
        (myFriendCode != null &&
            myFriendCode.isNotEmpty &&
            player.friendCode == myFriendCode);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      builder: (ctx) => _PlayerProfileModal(
        player: player,
        rank: rank,
        isMe: isMe,
      ),
    );
  }

  void _openLeagueRulesModal() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      builder: (ctx) => const _LeagueRulesModal(),
    );
  }

  void _shareMyRank(int rank, int trophies) {
    HapticFeedback.lightImpact();
    final metric = _activeTab == 1
        ? '${context.read<AppState>().xp} نقطة خبرة'
        : '$trophies كأس';
    final ladder = _activeTab == 1 ? 'الخبرة' : 'الكؤوس';
    final message =
        '🏆 أنا بالمركز #$rank في صدارة $ladder في أرض التحدي برصيد $metric!';
    Share.share(message, subject: 'ترتيبي في أرض التحدي');
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final myUid = _currentUid ?? appState.currentUser?.uid;
    final myFriendCode = appState.friendCode;
    final sortedPlayers = _getSortedPlayers(appState);
    final myIndex = sortedPlayers.indexWhere((player) =>
        (myUid != null && myUid.isNotEmpty && player.uid == myUid) ||
        (myFriendCode.isNotEmpty && player.friendCode == myFriendCode));
    final myRank = myIndex == -1 ? null : myIndex + 1;
    final myPlayer = myIndex == -1
        ? _LeaderboardPlayer.local(appState)
        : sortedPlayers[myIndex];

    final filteredPlayers = _filterPlayers(sortedPlayers);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF050B17),
        body: Stack(
          children: <Widget>[
            // ── Background art & ambient lighting ─────────────────────────
            Positioned.fill(
              child: adaptiveAssetImage('assets/ui/bg_main.webp',
                  fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      const Color(0xFF030712).withValues(alpha: 0.65),
                      const Color(0xFF060D1E).withValues(alpha: 0.92),
                      const Color(0xFF030712).withValues(alpha: 0.98),
                    ],
                  ),
                ),
              ),
            ),

            // Subtle neon glow orbs in the background
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.20),
                      blurRadius: 100,
                      spreadRadius: 40,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 260,
              left: -50,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.10),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.16),
                      blurRadius: 100,
                      spreadRadius: 30,
                    ),
                  ],
                ),
              ),
            ),

            // ── Main UI Layout ───────────────────────────────────────────
            SafeArea(
              child: Column(
                children: <Widget>[
                  // Top App Bar Header
                  _LeaderboardHeader(
                    total: sortedPlayers.length,
                    onBack: () => Navigator.of(context).pop(),
                    onOpenRules: _openLeagueRulesModal,
                    onRefresh: _load,
                    isLoading: _loading,
                  ),

                  // Navigation Tabs (Trophies, Levels, Leagues Roadmap)
                  _LeaderboardTabs(
                    activeTab: _activeTab,
                    onTabSelected: (index) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _activeTab = index;
                        _filterMode = 0;
                        _searchQuery = '';
                        _searchController.clear();
                        _isSearchExpanded = false;
                      });
                    },
                  ),

                  // Content Body
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      color: const Color(0xFFFACC15),
                      backgroundColor: const Color(0xFF0F172A),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _loading
                            ? const _LeaderboardLoadingSkeleton()
                            : _error != null
                                ? _LeaderboardErrorState(
                                    error: _error!,
                                    onRetry: _load,
                                  )
                                : _activeTab == 2
                                    ? _LeaguesRoadmapView(
                                        myPlayer: myPlayer,
                                        totalPlayers: sortedPlayers.length,
                                        players: sortedPlayers,
                                      )
                                    : _LeaderboardListView(
                                        scrollController: _scrollController,
                                        sortedPlayers: sortedPlayers,
                                        displayPlayers: filteredPlayers,
                                        currentUid: _currentUid,
                                        myRank: myRank,
                                        myPlayer: myPlayer,
                                        activeTab: _activeTab,
                                        filterMode: _filterMode,
                                        onFilterChanged: (mode) {
                                          HapticFeedback.selectionClick();
                                          setState(() => _filterMode = mode);
                                        },
                                        isSearchExpanded: _isSearchExpanded,
                                        searchController: _searchController,
                                        onToggleSearch: () {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            _isSearchExpanded =
                                                !_isSearchExpanded;
                                            if (!_isSearchExpanded) {
                                              _searchController.clear();
                                              _searchQuery = '';
                                            }
                                          });
                                        },
                                        entranceAnim: _entranceAnimController,
                                        crownAnim: _crownAnimController,
                                        pulseAnim: _pulseAnimController,
                                        onPlayerTap: _openPlayerModal,
                                        onShareRank: () {
                                          if (myRank != null) {
                                            _shareMyRank(
                                                myRank, myPlayer.trophies);
                                          }
                                        },
                                        onScrollToRank: _scrollToMyRank,
                                      ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Floating Sticky "My Rank" Bar ──────────────────────────────
            if (!_loading && _activeTab != 2 && myRank != null)
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  offset:
                      _showJumpToMyRank ? Offset.zero : const Offset(0, 1.4),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 240),
                    opacity: _showJumpToMyRank ? 1.0 : 0.0,
                    child: _FloatingMyRankBar(
                      myPlayer: myPlayer,
                      myRank: myRank,
                      activeTab: _activeTab,
                      onTapJump: () => _scrollToMyRank(myRank),
                      onTapShare: () => _shareMyRank(myRank, myPlayer.trophies),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER COMPONENT
// ─────────────────────────────────────────────────────────────────────────────
class _LeaderboardHeader extends StatelessWidget {
  const _LeaderboardHeader({
    required this.total,
    required this.onBack,
    required this.onOpenRules,
    required this.onRefresh,
    required this.isLoading,
  });

  final int total;
  final VoidCallback onBack;
  final VoidCallback onOpenRules;
  final VoidCallback onRefresh;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF040814).withValues(alpha: 0.70),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          // Back button
          _GlassButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'رجوع',
            onTap: onBack,
          ),
          const SizedBox(width: 14),

          // Title & Subtitle with glowing trophy
          Expanded(
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        'لوحة الصدارة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        total == 0
                            ? 'أفضل 200 لاعب • ترتيب الكؤوس والخبرة'
                            : '${_compactNumber(total)} لاعب من أفضل 200',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Trophy rules info button
          _GlassButton(
            icon: Icons.info_outline_rounded,
            tooltip: 'دليل الكؤوس والنقاط',
            color: const Color(0xFF38BDF8),
            onTap: onOpenRules,
          ),
          const SizedBox(width: 8),

          // Refresh button
          _GlassButton(
            icon:
                isLoading ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
            tooltip: 'تحديث النتائج',
            color: const Color(0xFFFACC15),
            onTap: isLoading ? null : onRefresh,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABS COMPONENT
// ─────────────────────────────────────────────────────────────────────────────
class _LeaderboardTabs extends StatelessWidget {
  const _LeaderboardTabs({
    required this.activeTab,
    required this.onTabSelected,
  });

  final int activeTab;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1226).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          _TabItem(
            title: 'سباق الكؤوس',
            icon: Icons.emoji_events_rounded,
            accentColor: const Color(0xFFFACC15),
            isSelected: activeTab == 0,
            onTap: () => onTabSelected(0),
          ),
          _TabItem(
            title: 'أقوياء المستوى',
            icon: Icons.military_tech_rounded,
            accentColor: const Color(0xFF38BDF8),
            isSelected: activeTab == 1,
            onTap: () => onTabSelected(1),
          ),
          _TabItem(
            title: 'خريطة الدوريات',
            icon: Icons.shield_rounded,
            accentColor: const Color(0xFFA78BFA),
            isSelected: activeTab == 2,
            onTap: () => onTabSelected(2),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.55)
                  : Colors.transparent,
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                color: isSelected ? accentColor : Colors.white54,
                size: 16,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEADERBOARD LIST VIEW (PODIUM + GAP TRACKER + FILTER CHIPS + ROWS)
// ─────────────────────────────────────────────────────────────────────────────
class _LeaderboardListView extends StatelessWidget {
  const _LeaderboardListView({
    required this.scrollController,
    required this.sortedPlayers,
    required this.displayPlayers,
    required this.currentUid,
    required this.myRank,
    required this.myPlayer,
    required this.activeTab,
    required this.filterMode,
    required this.onFilterChanged,
    required this.isSearchExpanded,
    required this.searchController,
    required this.onToggleSearch,
    required this.entranceAnim,
    required this.crownAnim,
    required this.pulseAnim,
    required this.onPlayerTap,
    required this.onShareRank,
    required this.onScrollToRank,
  });

  final ScrollController scrollController;
  final List<_LeaderboardPlayer> sortedPlayers;
  final List<_LeaderboardPlayer> displayPlayers;
  final String? currentUid;
  final int? myRank;
  final _LeaderboardPlayer myPlayer;
  final int activeTab;
  final int filterMode;
  final ValueChanged<int> onFilterChanged;
  final bool isSearchExpanded;
  final TextEditingController searchController;
  final VoidCallback onToggleSearch;
  final AnimationController entranceAnim;
  final AnimationController crownAnim;
  final AnimationController pulseAnim;
  final void Function(_LeaderboardPlayer, int) onPlayerTap;
  final VoidCallback onShareRank;
  final ValueChanged<int> onScrollToRank;

  @override
  Widget build(BuildContext context) {
    if (sortedPlayers.isEmpty) {
      return const _LeaderboardEmptyState();
    }

    final topThree = sortedPlayers.take(3).toList(growable: false);
    final leader = sortedPlayers.first;

    // Next rival to overtake
    _LeaderboardPlayer? nextRival;
    int? rivalRank;
    if (myRank != null &&
        myRank! > 1 &&
        myRank! <= sortedPlayers.length &&
        !(activeTab == 1 && sortedPlayers[myRank! - 2].xpEstimated)) {
      rivalRank = myRank! - 1;
      nextRival = sortedPlayers[rivalRank - 1];
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        final horizontalPadding = constraints.maxWidth < 600 ? 12.0 : 16.0;

        return CustomScrollView(
          controller: scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: <Widget>[
            // ── Top Section: Podium & Stats Overview ──────────────────────
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                4,
                horizontalPadding,
                12,
              ),
              sliver: SliverToBoxAdapter(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            flex: 5,
                            child: _TopSummaryCard(
                              leader: leader,
                              myPlayer: myPlayer,
                              myRank: myRank,
                              total: sortedPlayers.length,
                              activeTab: activeTab,
                              onShareRank: onShareRank,
                              onScrollToMe: myRank == null
                                  ? null
                                  : () => onScrollToRank(myRank!),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 6,
                            child: _AnimatedPodium(
                              topThree: topThree,
                              currentUid: currentUid,
                              myFriendCode: myPlayer.friendCode,
                              crownAnim: crownAnim,
                              entranceAnim: entranceAnim,
                              activeTab: activeTab,
                              onPlayerTap: onPlayerTap,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: <Widget>[
                          _AnimatedPodium(
                            topThree: topThree,
                            currentUid: currentUid,
                            myFriendCode: myPlayer.friendCode,
                            crownAnim: crownAnim,
                            entranceAnim: entranceAnim,
                            activeTab: activeTab,
                            onPlayerTap: onPlayerTap,
                          ),
                          const SizedBox(height: 12),
                          _TopSummaryCard(
                            leader: leader,
                            myPlayer: myPlayer,
                            myRank: myRank,
                            total: sortedPlayers.length,
                            activeTab: activeTab,
                            onShareRank: onShareRank,
                            onScrollToMe: myRank == null
                                ? null
                                : () => onScrollToRank(myRank!),
                          ),
                        ],
                      ),
              ),
            ),

            // ── Next Rival / Overtake Tracker (Gamification) ──────────────
            if (nextRival != null && rivalRank != null)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  12,
                ),
                sliver: SliverToBoxAdapter(
                  child: _NextRivalOvertakeBanner(
                    myPlayer: myPlayer,
                    myRank: myRank!,
                    rival: nextRival,
                    rivalRank: rivalRank,
                    activeTab: activeTab,
                    onTapRival: () => onPlayerTap(nextRival!, rivalRank!),
                  ),
                ),
              ),

            // ── Search & Filter Controls ──────────────────────────────────
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                10,
              ),
              sliver: SliverToBoxAdapter(
                child: _FilterAndSearchBar(
                  filterMode: filterMode,
                  onFilterChanged: onFilterChanged,
                  isSearchExpanded: isSearchExpanded,
                  searchController: searchController,
                  onToggleSearch: onToggleSearch,
                  totalShown: displayPlayers.length,
                ),
              ),
            ),

            // ── Leaderboard List Items ────────────────────────────────────
            if (displayPlayers.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.symmetric(vertical: 36),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: Text(
                      'لا توجد نتائج مطابقة لبحثك',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  86, // extra bottom padding for floating bar
                ),
                sliver: SliverList.separated(
                  itemCount: displayPlayers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final player = displayPlayers[index];
                    // Global rank in sorted list
                    final globalRank =
                        sortedPlayers.indexWhere((p) => p.uid == player.uid) +
                            1;
                    final isMe = (currentUid != null &&
                            currentUid!.isNotEmpty &&
                            player.uid == currentUid) ||
                        (myPlayer.friendCode != null &&
                            myPlayer.friendCode!.isNotEmpty &&
                            player.friendCode == myPlayer.friendCode);

                    return _AnimatedRankRow(
                      index: index,
                      player: player,
                      rank: globalRank > 0 ? globalRank : index + 1,
                      total: sortedPlayers.length,
                      isMe: isMe,
                      activeTab: activeTab,
                      pulseAnim: pulseAnim,
                      onTap: () => onPlayerTap(
                        player,
                        globalRank > 0 ? globalRank : index + 1,
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED GRAND PODIUM (#1, #2, #3)
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedPodium extends StatelessWidget {
  const _AnimatedPodium({
    required this.topThree,
    required this.currentUid,
    this.myFriendCode,
    required this.crownAnim,
    required this.entranceAnim,
    required this.activeTab,
    required this.onPlayerTap,
  });

  final List<_LeaderboardPlayer> topThree;
  final String? currentUid;
  final String? myFriendCode;
  final AnimationController crownAnim;
  final AnimationController entranceAnim;
  final int activeTab;
  final void Function(_LeaderboardPlayer, int) onPlayerTap;

  bool _isMe(_LeaderboardPlayer? p) {
    if (p == null) return false;
    if (currentUid != null && currentUid!.isNotEmpty && p.uid == currentUid) {
      return true;
    }
    if (myFriendCode != null &&
        myFriendCode!.isNotEmpty &&
        p.friendCode == myFriendCode) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final first = topThree.isNotEmpty ? topThree[0] : null;
    final second = topThree.length > 1 ? topThree[1] : null;
    final third = topThree.length > 2 ? topThree[2] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF091224).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.32),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          // Section header label
          const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFFACC15),
                size: 20,
              ),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'منصة الثلاثة الأوائل',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Podium slots (#2 on Left, #1 in Center, #3 on Right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              // #2 Second Place (Silver)
              Expanded(
                child: _PodiumPillar(
                  player: second,
                  rank: 2,
                  targetHeight: 110,
                  entranceAnim: entranceAnim,
                  isMe: _isMe(second),
                  activeTab: activeTab,
                  onTap: second == null ? null : () => onPlayerTap(second, 2),
                ),
              ),
              const SizedBox(width: 8),

              // #1 First Place (Gold Champion)
              Expanded(
                flex: 1,
                child: _PodiumPillar(
                  player: first,
                  rank: 1,
                  targetHeight: 145,
                  entranceAnim: entranceAnim,
                  crownAnim: crownAnim,
                  isMe: _isMe(first),
                  activeTab: activeTab,
                  onTap: first == null ? null : () => onPlayerTap(first, 1),
                ),
              ),
              const SizedBox(width: 8),

              // #3 Third Place (Bronze)
              Expanded(
                child: _PodiumPillar(
                  player: third,
                  rank: 3,
                  targetHeight: 92,
                  entranceAnim: entranceAnim,
                  isMe: _isMe(third),
                  activeTab: activeTab,
                  onTap: third == null ? null : () => onPlayerTap(third, 3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PodiumPillar extends StatelessWidget {
  const _PodiumPillar({
    required this.player,
    required this.rank,
    required this.targetHeight,
    required this.entranceAnim,
    this.crownAnim,
    required this.isMe,
    required this.activeTab,
    required this.onTap,
  });

  final _LeaderboardPlayer? player;
  final int rank;
  final double targetHeight;
  final AnimationController entranceAnim;
  final AnimationController? crownAnim;
  final bool isMe;
  final int activeTab;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rankColors = _getRankColors(rank);
    final avatarSize = rank == 1 ? 58.0 : 48.0;

    return GestureDetector(
      key: ValueKey('leaderboard-podium-$rank'),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          // Floating Crown / Laurel for #1 Champion
          if (rank == 1 && crownAnim != null)
            AnimatedBuilder(
              animation: crownAnim!,
              builder: (context, child) {
                final hover = math.sin(crownAnim!.value * math.pi) * 4.0;
                return Transform.translate(
                  offset: Offset(0, -hover),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.50),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.military_tech_rounded,
                      color: Color(0xFFFFD700),
                      size: 26,
                    ),
                  ),
                );
              },
            )
          else
            const SizedBox(height: 18),

          // Player Avatar with Aura & Badges
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: <Widget>[
              // Glowing aura
              Container(
                width: avatarSize + 8,
                height: avatarSize + 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      rankColors.primary.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // Avatar Circle
              _PlayerAvatar(
                photoUrl: player?.photoUrl ?? '',
                name: player?.username ?? '',
                size: avatarSize,
                borderColor:
                    isMe ? const Color(0xFFFACC15) : rankColors.primary,
                borderWidth: 2.4,
              ),

              // Rank Badge floating on bottom
              Positioned(
                bottom: -6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: rankColors.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Player Name
          Text(
            player?.username ?? 'لاعب',
            style: TextStyle(
              color: isMe ? const Color(0xFFFACC15) : Colors.white,
              fontSize: rank == 1 ? 13 : 11.5,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),

          // Primary Stat (Trophies or Level)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                activeTab == 1
                    ? Icons.military_tech_rounded
                    : Icons.emoji_events_rounded,
                color: activeTab == 1
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFFFACC15),
                size: 13,
              ),
              const SizedBox(width: 3),
              Text(
                player == null
                    ? '--'
                    : activeTab == 1
                        ? 'مستوى ${player!.level}'
                        : _compactNumber(player!.trophies),
                style: TextStyle(
                  color: activeTab == 1
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFFFACC15),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 3D Animated Pedestal Pillar
          AnimatedBuilder(
            animation: entranceAnim,
            builder: (context, child) {
              final curved = CurvedAnimation(
                parent: entranceAnim,
                curve: Curves.easeOutBack,
              ).value;
              final currentH = math.max(20.0, targetHeight * curved);

              return Container(
                height: currentH,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      rankColors.primary.withValues(alpha: 0.35),
                      rankColors.primary.withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                    bottom: Radius.circular(8),
                  ),
                  border: Border.all(
                    color: rankColors.primary.withValues(alpha: 0.60),
                    width: 1.5,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: rankColors.primary.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          rank == 1
                              ? Icons.workspace_premium_rounded
                              : rank == 2
                                  ? Icons.shield_moon_rounded
                                  : Icons.shield_rounded,
                          color: rankColors.primary.withValues(alpha: 0.70),
                          size: rank == 1 ? 26 : 20,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '#$rank',
                          style: TextStyle(
                            color: rankColors.primary,
                            fontSize: rank == 1 ? 24 : 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP SUMMARY / METRIC CARD
// ─────────────────────────────────────────────────────────────────────────────
class _TopSummaryCard extends StatelessWidget {
  const _TopSummaryCard({
    required this.leader,
    required this.myPlayer,
    required this.myRank,
    required this.total,
    required this.activeTab,
    required this.onShareRank,
    this.onScrollToMe,
  });

  final _LeaderboardPlayer leader;
  final _LeaderboardPlayer myPlayer;
  final int? myRank;
  final int total;
  final int activeTab;
  final VoidCallback onShareRank;
  final VoidCallback? onScrollToMe;

  @override
  Widget build(BuildContext context) {
    final league = TrophyProgression.leagueFor(myPlayer.trophies);
    final rankTier = PlayerRank.tierForLevel(myPlayer.level);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF091224).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row with My Profile Snapshot
          Row(
            children: <Widget>[
              _PlayerAvatar(
                photoUrl: myPlayer.photoUrl,
                name: myPlayer.username,
                size: 42,
                borderColor: const Color(0xFFFACC15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            myPlayer.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFACC15).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFFACC15)
                                  .withValues(alpha: 0.40),
                            ),
                          ),
                          child: const Text(
                            'أنت',
                            style: TextStyle(
                              color: Color(0xFFFACC15),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'الدوري: ${TrophyProgression.divisionLabelFor(myPlayer.trophies)} • رتبة الخبرة: ${rankTier.nameAr}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Action buttons (Share & Scroll to rank)
              if (onScrollToMe != null)
                IconButton(
                  onPressed: onScrollToMe,
                  tooltip: 'موقعي في القائمة',
                  icon: const Icon(Icons.my_location_rounded),
                  color: const Color(0xFF38BDF8),
                  style: IconButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF38BDF8).withValues(alpha: 0.14),
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                  ),
                ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: myRank == null ? null : onShareRank,
                tooltip: 'مشاركة الترتيب',
                icon: const Icon(Icons.share_rounded),
                color: const Color(0xFFFACC15),
                style: IconButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFFACC15).withValues(alpha: 0.14),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(36, 36),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3 Metric Cards Grid
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricBadge(
                  icon: Icons.place_rounded,
                  color: const Color(0xFF38BDF8),
                  label: 'المركز في الصدارة',
                  value: myRank == null ? 'خارج القائمة' : '#$myRank',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBadge(
                  icon: activeTab == 1
                      ? Icons.military_tech_rounded
                      : Icons.emoji_events_rounded,
                  color: const Color(0xFFFACC15),
                  label: activeTab == 1 ? 'مستواك' : 'كؤوسك',
                  value: activeTab == 1
                      ? '${myPlayer.level}'
                      : _compactNumber(myPlayer.trophies),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBadge(
                  icon: Icons.auto_awesome_rounded,
                  color: const Color(0xFFA78BFA),
                  label: 'إجمالي الخبرة',
                  value: myPlayer.xpLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // League Progress Bar towards next league
          _LeagueMiniProgressBar(
            trophies: myPlayer.trophies,
            league: league,
          ),
        ],
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.60),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _LeagueMiniProgressBar extends StatelessWidget {
  const _LeagueMiniProgressBar({
    required this.trophies,
    required this.league,
  });

  final int trophies;
  final TrophyLeague league;

  @override
  Widget build(BuildContext context) {
    final progress = league.progress(trophies);
    final left = league.trophiesLeft(trophies);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(
                child: Text(
                  'التقدم في دوري ${league.nameAr}',
                  style: TextStyle(
                    color: league.color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                league.max == null
                    ? 'الحد الأقصى للدوريات!'
                    : 'باقي $left كأس للدوري التالي',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(league.color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEXT RIVAL OVERTAKE BANNER (GAMIFICATION MOTIVATION)
// ─────────────────────────────────────────────────────────────────────────────
class _NextRivalOvertakeBanner extends StatelessWidget {
  const _NextRivalOvertakeBanner({
    required this.myPlayer,
    required this.myRank,
    required this.rival,
    required this.rivalRank,
    required this.activeTab,
    required this.onTapRival,
  });

  final _LeaderboardPlayer myPlayer;
  final int myRank;
  final _LeaderboardPlayer rival;
  final int rivalRank;
  final int activeTab;
  final VoidCallback onTapRival;

  @override
  Widget build(BuildContext context) {
    final diff = activeTab == 1
        ? (rival.xp - myPlayer.xp + 1)
        : (rival.trophies - myPlayer.trophies + 1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF59E0B).withValues(alpha: 0.16),
            const Color(0xFF0F172A).withValues(alpha: 0.85),
          ],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.40),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Color(0xFFFACC15),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'هدفك القادم للصدارة!',
                  style: TextStyle(
                    color: Color(0xFFFACC15),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  activeTab == 1
                      ? 'يفصلك $diff XP لتخطي ${rival.username} واحتلال المركز #$rivalRank!'
                      : 'يفصلك $diff كأس فقط لتخطي ${rival.username} واحتلال المركز #$rivalRank!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onTapRival,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(60, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'تحدي',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER AND SEARCH BAR
// ─────────────────────────────────────────────────────────────────────────────
class _FilterAndSearchBar extends StatelessWidget {
  const _FilterAndSearchBar({
    required this.filterMode,
    required this.onFilterChanged,
    required this.isSearchExpanded,
    required this.searchController,
    required this.onToggleSearch,
    required this.totalShown,
  });

  final int filterMode;
  final ValueChanged<int> onFilterChanged;
  final bool isSearchExpanded;
  final TextEditingController searchController;
  final VoidCallback onToggleSearch;
  final int totalShown;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        // Search textfield if expanded
        if (isSearchExpanded)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
              ),
            ),
            child: TextField(
              controller: searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'ابحث عن لاعب باسمه أو كود الصداقة...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.40),
                  fontSize: 12,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF38BDF8),
                  size: 20,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white60, size: 18),
                  onPressed: onToggleSearch,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),

        // Filter chips bar
        Row(
          children: <Widget>[
            // Search toggle button
            InkWell(
              onTap: onToggleSearch,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSearchExpanded
                      ? const Color(0xFF38BDF8).withValues(alpha: 0.20)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSearchExpanded
                        ? const Color(0xFF38BDF8)
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(
                  Icons.search_rounded,
                  color: isSearchExpanded
                      ? const Color(0xFF38BDF8)
                      : Colors.white70,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Filter Chips
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: <Widget>[
                    _FilterChip(
                      label: 'الكل ($totalShown)',
                      isSelected: filterMode == 0,
                      onTap: () => onFilterChanged(0),
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'أفضل 10',
                      isSelected: filterMode == 1,
                      onTap: () => onFilterChanged(1),
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'أفضل 50',
                      isSelected: filterMode == 2,
                      onTap: () => onFilterChanged(2),
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'منافسين حولي',
                      isSelected: filterMode == 3,
                      onTap: () => onFilterChanged(3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFACC15).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFACC15).withValues(alpha: 0.65)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFFFACC15) : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED RANK ROW
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedRankRow extends StatelessWidget {
  const _AnimatedRankRow({
    required this.index,
    required this.player,
    required this.rank,
    required this.total,
    required this.isMe,
    required this.activeTab,
    required this.pulseAnim,
    required this.onTap,
  });

  final int index;
  final _LeaderboardPlayer player;
  final int rank;
  final int total;
  final bool isMe;
  final int activeTab;
  final AnimationController pulseAnim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final league = TrophyProgression.leagueFor(player.trophies);
    final tier = PlayerRank.tierForLevel(player.level);
    final rankColors = _getRankColors(rank);

    // Staggered slide and fade
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 260 + math.min(index * 20, 400)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedBuilder(
          animation: pulseAnim,
          builder: (context, child) {
            final pulseBorder = isMe
                ? const Color(0xFFFACC15)
                    .withValues(alpha: 0.55 + 0.35 * pulseAnim.value)
                : rank <= 3
                    ? rankColors.primary.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.09);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                    : const Color(0xFF091224).withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: pulseBorder, width: isMe ? 1.5 : 1.0),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: isMe
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.20),
                    blurRadius: isMe ? 14 : 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  // Rank Badge
                  _RankBadge(rank: rank, colors: rankColors),
                  const SizedBox(width: 12),

                  // Player Avatar with League Border
                  _PlayerAvatar(
                    photoUrl: player.photoUrl,
                    name: player.username,
                    size: 44,
                    borderColor: isMe ? const Color(0xFFFACC15) : league.color,
                  ),
                  const SizedBox(width: 12),

                  // Player Info & Badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                player.username,
                                style: TextStyle(
                                  color: isMe
                                      ? const Color(0xFFFACC15)
                                      : Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isMe) ...<Widget>[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFACC15)
                                      .withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFFACC15)
                                        .withValues(alpha: 0.50),
                                  ),
                                ),
                                child: const Text(
                                  'أنت',
                                  style: TextStyle(
                                    color: Color(0xFFFACC15),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: <Widget>[
                            _MiniChip(
                              icon: league.icon,
                              color: league.color,
                              text: TrophyProgression.divisionLabelFor(
                                  player.trophies),
                            ),
                            _MiniChip(
                              icon: tier.icon,
                              color: tier.color,
                              text: 'مستوى ${player.level}',
                            ),
                            _MiniChip(
                              icon: Icons.auto_awesome_rounded,
                              color: const Color(0xFFA78BFA),
                              text: tier.nameAr,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Primary Metric on Right (Trophies or Level)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            activeTab == 1
                                ? Icons.military_tech_rounded
                                : Icons.emoji_events_rounded,
                            color: activeTab == 1
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFFFACC15),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            activeTab == 1
                                ? 'مستوى ${player.level}'
                                : _compactNumber(player.trophies),
                            style: TextStyle(
                              color: activeTab == 1
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFFFACC15),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activeTab == 1
                            ? player.xpLabel
                            : 'مستوى ${player.level}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({
    required this.rank,
    required this.colors,
  });

  final int rank;
  final _RankPalette colors;

  @override
  Widget build(BuildContext context) {
    if (rank <= 3) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.40),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '#$rank',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Center(
        child: Text(
          '#$rank',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: rank < 100 ? 13 : 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FLOATING STICKY "MY RANK" BAR
// ─────────────────────────────────────────────────────────────────────────────
class _FloatingMyRankBar extends StatelessWidget {
  const _FloatingMyRankBar({
    required this.myPlayer,
    required this.myRank,
    required this.activeTab,
    required this.onTapJump,
    required this.onTapShare,
  });

  final _LeaderboardPlayer myPlayer;
  final int myRank;
  final int activeTab;
  final VoidCallback onTapJump;
  final VoidCallback onTapShare;

  @override
  Widget build(BuildContext context) {
    final league = TrophyProgression.leagueFor(myPlayer.trophies);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F1E36).withValues(alpha: 0.95),
            const Color(0xFF0B1426).withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFACC15).withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          // My Avatar
          _PlayerAvatar(
            photoUrl: myPlayer.photoUrl,
            name: myPlayer.username,
            size: 38,
            borderColor: const Color(0xFFFACC15),
          ),
          const SizedBox(width: 10),

          // Rank & Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'المركز #$myRank',
                      style: const TextStyle(
                        color: Color(0xFFFACC15),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${myPlayer.username})',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                Text(
                  activeTab == 1
                      ? 'مستوى ${myPlayer.level} • دوري ${league.nameAr}'
                      : '${_compactNumber(myPlayer.trophies)} كأس • دوري ${league.nameAr}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // Scroll to my rank button
          ElevatedButton.icon(
            onPressed: onTapJump,
            icon: const Icon(Icons.my_location_rounded, size: 14),
            label: const Text('موقعي'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              minimumSize: const Size(60, 34),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
              textStyle:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 6),

          // Share button
          IconButton(
            onPressed: onTapShare,
            tooltip: 'مشاركة الترتيب',
            icon: const Icon(Icons.share_rounded, size: 18),
            color: const Color(0xFFFACC15),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFFACC15).withValues(alpha: 0.15),
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(34, 34),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEAGUES ROADMAP TAB (JOURNEY & PERKS)
// ─────────────────────────────────────────────────────────────────────────────
class _LeaguesRoadmapView extends StatelessWidget {
  const _LeaguesRoadmapView({
    required this.myPlayer,
    required this.totalPlayers,
    required this.players,
  });

  final _LeaderboardPlayer myPlayer;
  final int totalPlayers;
  final List<_LeaderboardPlayer> players;

  @override
  Widget build(BuildContext context) {
    final currentLeague = TrophyProgression.leagueFor(myPlayer.trophies);
    const leagues = TrophyProgression.leagues;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Intro Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF8B5CF6).withValues(alpha: 0.20),
                  const Color(0xFF0F172A).withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.40),
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.military_tech_rounded,
                    color: Color(0xFFA78BFA),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'دليل ورتب الدوريات',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'دوريك الحالي ${TrophyProgression.divisionLabelFor(myPlayer.trophies)}. لكل دوري ثلاث درجات: III ثم II ثم I، حتى دوري الأساطير المفتوح.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Section Title
          const Text(
            'مسار الدوريات السبع',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),

          // List of leagues
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leagues.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final league = leagues[index];
              final isCurrent = league.name == currentLeague.name;
              final isUnlocked = myPlayer.trophies >= league.min;

              // Count how many players in leaderboard belong to this league
              final countInLeague = players
                  .where((p) =>
                      p.trophies >= league.min &&
                      (league.max == null || p.trophies <= league.max!))
                  .length;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? league.color.withValues(alpha: 0.16)
                      : const Color(0xFF091224).withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCurrent
                        ? league.color
                        : Colors.white.withValues(alpha: 0.10),
                    width: isCurrent ? 1.8 : 1.0,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: league.color.withValues(alpha: 0.20),
                            blurRadius: 16,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: <Widget>[
                    // League Icon
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: league.color.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: league.color.withValues(alpha: 0.40),
                        ),
                      ),
                      child: Icon(league.icon, color: league.color, size: 24),
                    ),
                    const SizedBox(width: 14),

                    // League Name & Range
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Text(
                                league.nameAr,
                                style: TextStyle(
                                  color: league.color,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(${league.name})',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.40),
                                  fontSize: 11,
                                ),
                              ),
                              if (isCurrent) ...<Widget>[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: league.color.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'دوريك الحالي',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'المتطلب: ${league.rangeLabel()} كأس • $countInLeague ضمن الصدارة',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.60),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status Badge (Unlocked / Current / Locked)
                    Icon(
                      isUnlocked
                          ? Icons.check_circle_rounded
                          : Icons.lock_outline_rounded,
                      color: isUnlocked
                          ? const Color(0xFF34D399)
                          : Colors.white.withValues(alpha: 0.30),
                      size: 20,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INTERACTIVE PLAYER PROFILE MODAL (CHALLENGE / COPY CODE / STATS)
// ─────────────────────────────────────────────────────────────────────────────
class _PlayerProfileModal extends StatelessWidget {
  const _PlayerProfileModal({
    required this.player,
    required this.rank,
    required this.isMe,
  });

  final _LeaderboardPlayer player;
  final int rank;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final league = TrophyProgression.leagueFor(player.trophies);
    final tier = PlayerRank.tierForLevel(player.level);
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Color(0xFF091224),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF38BDF8), width: 1.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Draggable drag handle
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // Avatar & Rank Overlay
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: <Widget>[
                  _PlayerAvatar(
                    photoUrl: player.photoUrl,
                    name: player.username,
                    size: 74,
                    borderColor: league.color,
                    borderWidth: 3,
                  ),
                  Positioned(
                    bottom: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _getRankColors(rank).gradient,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 1.2),
                      ),
                      child: Text(
                        'المركز #$rank',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Username
              Text(
                player.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Friend code snippet
              if (player.friendCode != null && player.friendCode!.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      'كود اللاعب: ${player.friendCode}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.60),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      color: const Color(0xFF38BDF8),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: player.friendCode!));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم نسخ كود الصداقة بنجاح!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 18),

              // 4 Stats Grid Cards
              Row(
                children: <Widget>[
                  Expanded(
                    child: _ModalStatBox(
                      icon: Icons.emoji_events_rounded,
                      color: const Color(0xFFFACC15),
                      title: 'الكؤوس',
                      value: _compactNumber(player.trophies),
                      subtitle: league.nameAr,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ModalStatBox(
                      icon: Icons.military_tech_rounded,
                      color: const Color(0xFF38BDF8),
                      title: 'المستوى',
                      value: '${player.level}',
                      subtitle: tier.nameAr,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _ModalStatBox(
                      icon: Icons.speed_rounded,
                      color: const Color(0xFF34D399),
                      title: 'إجمالي الخبرة',
                      value: player.xpEstimated
                          ? '≥ ${player.xp}'
                          : '${player.xp}',
                      subtitle: player.xpEstimated
                          ? 'حد أدنى حسب المستوى المسجل'
                          : 'XP • جميع أطوار اللعب',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ModalStatBox(
                      icon: Icons.shield_rounded,
                      color: const Color(0xFFA78BFA),
                      title: 'الدوري',
                      value:
                          TrophyProgression.divisionLabelFor(player.trophies),
                      subtitle: league.rangeLabel(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action Buttons
              if (!isMe) ...<Widget>[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    FriendChallengeModal.show(
                      context,
                      initialFriendCode: player.friendCode,
                    );
                  },
                  icon: const Icon(Icons.sports_esports_rounded, size: 20),
                  label: const Text('تحدي اللاعب (1 ضد 1)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                  minimumSize: const Size(double.infinity, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalStatBox extends StatelessWidget {
  const _ModalStatBox({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TROPHY RULES & SCORING MODAL
// ─────────────────────────────────────────────────────────────────────────────
class _LeagueRulesModal extends StatelessWidget {
  const _LeagueRulesModal();

  @override
  Widget build(BuildContext context) {
    const rules = TrophyProgression.rules;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Color(0xFF091224),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFFFACC15), width: 1.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFACC15).withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFFFACC15),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'نظام احتساب الكؤوس',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'كل مباراة مكتملة تحتسب مرة واحدة في جميع الأطوار',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Rules grid
            Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: rules.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final rule = rules[index];
                  final isPositive = !rule.value.startsWith('-');

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: rule.color.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(rule.icon, color: rule.color, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            rule.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPositive
                                ? const Color(0xFF34D399)
                                    .withValues(alpha: 0.18)
                                : const Color(0xFFEF4444)
                                    .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            rule.value,
                            style: TextStyle(
                              color: isPositive
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFFEF4444),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // Close button
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('حسناً، فهمت'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMMON REUSABLE ATOMS & SKELETONS
// ─────────────────────────────────────────────────────────────────────────────
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.tooltip,
    this.color = Colors.white,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
            ),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({
    required this.photoUrl,
    required this.name,
    required this.size,
    required this.borderColor,
    this.borderWidth = 2.0,
  });

  final String photoUrl;
  final String name;
  final double size;
  final Color borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty ? '؟' : name.trim().characters.first;
    final hasPhoto = photoUrl.trim().isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
        gradient: LinearGradient(
          colors: [
            borderColor.withValues(alpha: 0.35),
            borderColor.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _AvatarInitials(initials: initials),
            )
          : _AvatarInitials(initials: initials),
    );
  }
}

class _AvatarInitials extends StatelessWidget {
  const _AvatarInitials({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LeaderboardLoadingSkeleton extends StatelessWidget {
  const _LeaderboardLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFACC15).withValues(alpha: 0.16),
              border: Border.all(
                color: const Color(0xFFFACC15).withValues(alpha: 0.40),
                width: 2,
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Color(0xFFFACC15),
                  strokeWidth: 2.8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'جاري تحديث لوحة الصدارة...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'نجمع أقوى نتائج المتصدرين حالياً',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardErrorState extends StatelessWidget {
  const _LeaderboardErrorState({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF091224),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFFEF4444),
              size: 46,
            ),
            const SizedBox(height: 12),
            const Text(
              'تعذر تحميل الصدارة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFACC15),
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardEmptyState extends StatelessWidget {
  const _LeaderboardEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF091224),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFACC15).withValues(alpha: 0.30),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.emoji_events_outlined,
              color: Color(0xFFFACC15),
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'لا يوجد متصدرون بعد',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'كن أول من يخوض المباريات ويسجل نقاطه ليتصدر قائمة الشرف!',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.60),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS & PALETTES
// ─────────────────────────────────────────────────────────────────────────────
class _RankPalette {
  const _RankPalette({
    required this.primary,
    required this.gradient,
  });

  final Color primary;
  final List<Color> gradient;
}

_RankPalette _getRankColors(int rank) {
  if (rank == 1) {
    return const _RankPalette(
      primary: Color(0xFFFFD700),
      gradient: [Color(0xFFFFDF00), Color(0xFFF59E0B), Color(0xFFD97706)],
    );
  }
  if (rank == 2) {
    return const _RankPalette(
      primary: Color(0xFFE2E8F0),
      gradient: [Color(0xFFFFFFFF), Color(0xFFCBD5E1), Color(0xFF94A3B8)],
    );
  }
  if (rank == 3) {
    return const _RankPalette(
      primary: Color(0xFFCD7F32),
      gradient: [Color(0xFFFDBA74), Color(0xFFEA580C), Color(0xFF9A3412)],
    );
  }
  if (rank <= 10) {
    return const _RankPalette(
      primary: Color(0xFF38BDF8),
      gradient: [Color(0xFF7DD3FC), Color(0xFF0284C7)],
    );
  }
  return const _RankPalette(
    primary: Color(0xFF94A3B8),
    gradient: [Color(0xFF64748B), Color(0xFF334155)],
  );
}

String _compactNumber(int value) {
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();
  if (abs >= 1000000) {
    final number = abs / 1000000;
    return '$sign${number.toStringAsFixed(number >= 10 ? 0 : 1)}M';
  }
  if (abs >= 1000) {
    final number = abs / 1000;
    return '$sign${number.toStringAsFixed(number >= 10 ? 0 : 1)}K';
  }
  return value.toString();
}
