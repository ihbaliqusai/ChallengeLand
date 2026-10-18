import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:challenge_land/screens/online/rooms_screen.dart';
import '../online/room_lobby_screen.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../models/room.dart';
import '../../core/player_rank.dart';
import '../campaign/campaign_map_screen.dart';
import 'store_screen.dart';
import 'resource_shop_screen.dart';
import 'leaderboard_screen.dart';
import 'daily_streak_screen.dart';
import 'profile_screen.dart';
import '../online/settings_screen.dart';
import '../online/stats_screen.dart';
import '../online/achievements_screen.dart';
import '../../services/room_service.dart';
import '../../services/campaign_result_handler.dart';
import '../../services/invite_service.dart';
import '../../services/native_bridge_service.dart';
import '../../widgets/friend_challenge_modal.dart';
import '../social/social_screen.dart';
import '../../widgets/special_offer_dialog.dart';
import '../../widgets/special_offer_badge.dart';
import '../../widgets/cross_promo_millionaire_badge.dart';
import '../../widgets/daily_reward_dialog.dart';
import '../../widgets/home_quick_action.dart';
import '../../widgets/home_menu_artwork.dart';
import '../../widgets/game_modes_artwork.dart';
import '../../widgets/home_artwork.dart';
import '../../widgets/home_character_artwork.dart';
import '../../services/rate_game_service.dart';
import '../../services/cross_promo_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _idleCtrl;
  late final AnimationController _bgCtrl;
  bool _syncingPendingRoomMatchResult = false;
  bool _handlingNativeLaunchAction = false;
  bool _hasCheckedDailyRewardThisLaunch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadCurrency();
      // loadLevelData sets _lastKnownGamesPlayed then calls checkAndAwardXpForGames.
      // Called here because didChangeAppLifecycleState(resumed) is NOT fired
      // when the native game Activity restarts MainActivity with FLAG_ACTIVITY_CLEAR_TASK.
      context.read<AppState>().loadLevelData();
      _consumePendingRoomMatchResult();
      CampaignResultHandler.consumeAndHandlePendingCampaignResult(
        context: context,
      );
      _consumeNativeLaunchAction();
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _checkClipboardForIncomingInvite();
      });
      _checkAndShowDailyReward();
    });
    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppState>().loadCurrency();
      context.read<AppState>().refreshCommerce();
      context.read<AppState>().loadLevelData();
      context.read<AppState>().checkAndAwardXpForGames();
      _consumePendingRoomMatchResult();
      CampaignResultHandler.consumeAndHandlePendingCampaignResult(
        context: context,
      );
      _consumeNativeLaunchAction();
      _checkClipboardForIncomingInvite();
      final promo = context.read<CrossPromoService>();
      final uid = context.read<AppState>().currentUser?.uid;
      promo.checkInstallation();
      promo.checkRewardClaimed(uid: uid);
    }
  }

  Future<void> _checkAndShowDailyReward() async {
    if (!mounted || _hasCheckedDailyRewardThisLaunch) return;
    _hasCheckedDailyRewardThisLaunch = true;

    // مهلة قصيرة لإتاحة استقرار الشاشة وسلاسة الانتقال
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final appState = context.read<AppState>();
    // انتظار تحميل بيانات السلسلة من Firestore إذا كانت لا تزال قيد التحميل
    int waitCount = 0;
    while (!appState.dailyStreakLoaded && waitCount < 12 && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      waitCount++;
    }
    if (!mounted) return;

    final shouldShow =
        appState.isOnline && !appState.claimedToday && appState.user != null;

    if (shouldShow && mounted) {
      await DailyRewardDialog.show(context);
    }

    // بعد الانتهاء من فحص/عرض المكافأة اليومية يتم التحقق من العرض الخاص
    // لضمان عدم ظهور نافذتين فوق بعضهما مطلقاً
    if (mounted) {
      _checkAndShowSpecialOffer();
    }
  }

  Future<void> _checkAndShowSpecialOffer() async {
    if (!mounted) return;
    final appState = context.read<AppState>();
    if (appState.isVip) return;
    final shouldShow =
        await SpecialOfferDialog.shouldShowAuto(isVip: appState.isVip);
    if (shouldShow && mounted && !appState.isVip) {
      await SpecialOfferDialog.show(context);
    }
  }

  Future<void> _checkClipboardForIncomingInvite() async {
    if (!mounted) return;
    try {
      final appState = context.read<AppState>();
      final myCode = appState.friendCode;
      final myUid = appState.user?.uid ?? '';
      final inviteService = context.read<InviteService>();

      final candidate = await inviteService.inspectClipboardInvite(
        myFriendCode: myCode,
        myUid: myUid,
      );

      if (candidate != null && mounted) {
        _showIncomingInviteDialog(candidate);
      }
    } catch (_) {}
  }

  void _showIncomingInviteDialog(InviteCandidate candidate) {
    final isFriend = candidate.type == InviteType.friendChallenge;
    final primaryColor =
        isFriend ? const Color(0xFFFFD700) : const Color(0xFF38BDF8);

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F1E4A), Color(0xFF080D24)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.2),
                blurRadius: 28,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isFriend
                        ? [const Color(0xFFFFD700), const Color(0xFFF59E0B)]
                        : [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
                  ),
                ),
                child: Icon(
                  isFriend
                      ? Icons.sports_esports_rounded
                      : Icons.groups_rounded,
                  color: isFriend ? const Color(0xFF0B1437) : Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                candidate.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                candidate.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF070F28),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  candidate.code,
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        final inviteService = context.read<InviteService>();
                        inviteService.dismissInviteCode(candidate.code);
                        inviteService.dismissInviteCode(candidate.rawText);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('تجاهل'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isFriend
                              ? [
                                  const Color(0xFFFFD700),
                                  const Color(0xFFF59E0B)
                                ]
                              : [
                                  const Color(0xFF38BDF8),
                                  const Color(0xFF0284C7)
                                ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          final inviteService = context.read<InviteService>();
                          await inviteService.dismissInviteCode(candidate.code);
                          await inviteService
                              .dismissInviteCode(candidate.rawText);

                          if (!mounted) return;

                          if (isFriend) {
                            FriendChallengeModal.show(
                              context,
                              initialFriendCode: candidate.code,
                            );
                          } else {
                            final userId = context.read<AppState>().user?.uid;
                            if (userId != null) {
                              try {
                                final joinResult =
                                    await context.read<RoomService>().joinRoom(
                                          roomId: candidate.code,
                                          userId: userId,
                                        );
                                if (!mounted) return;
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => RoomLobbyScreen(
                                      roomId: candidate.code,
                                      isJoiningMidGame:
                                          joinResult.joinedMidGame,
                                    ),
                                  ),
                                );
                                return;
                              } catch (_) {}
                            }
                            if (!mounted) return;
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => RoomsScreen(
                                    initialRoomCode: candidate.code),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor:
                              isFriend ? const Color(0xFF0B1437) : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          isFriend ? 'بدء التحدي الآن ⚔️' : 'انضمام للغرفة 🏆',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _consumeNativeLaunchAction() async {
    if (_handlingNativeLaunchAction || !mounted) return;
    _handlingNativeLaunchAction = true;
    try {
      final action =
          await context.read<NativeBridgeService>().consumeLaunchAction();
      if (!mounted || action == null || action.isEmpty) return;
      if (action == 'open_online_rooms') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const RoomsScreen()),
          (route) => route.isFirst,
        );
      } else if (action == 'open_store') {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const StoreScreen()),
        );
      } else if (action == 'social:requests') {
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const SocialScreen(initialTab: 2),
        ));
      } else if (action.startsWith('challenge:')) {
        final code = action.substring('challenge:'.length).trim();
        if (code.isNotEmpty) {
          await FriendChallengeModal.show(context, initialFriendCode: code);
        }
      } else if (action.startsWith('room:')) {
        final roomId = action.substring('room:'.length).trim();
        if (roomId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const RoomsScreen(),
            ),
          );
        }
      }
    } finally {
      _handlingNativeLaunchAction = false;
    }
  }

  Future<void> _openCampaignMap() async {
    final nativeBridgeService = context.read<NativeBridgeService>();
    try {
      await nativeBridgeService.playCampaignMapMusic();
    } catch (_) {}
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: CampaignMapScreen.routeName),
        builder: (_) => const CampaignMapScreen(),
      ),
    );
  }

  Future<void> _consumePendingRoomMatchResult() async {
    if (_syncingPendingRoomMatchResult) return;
    final userId = context.read<AppState>().user?.uid;
    if (userId == null) return;
    final nativeBridgeService = context.read<NativeBridgeService>();
    final roomService = context.read<RoomService>();

    _syncingPendingRoomMatchResult = true;
    try {
      final payload = await nativeBridgeService.getPendingRoomMatchResult();
      if (payload == null) return;

      final roomId = (payload['roomId'] ?? '').toString().trim();
      final matchMode = (payload['matchMode'] ?? '').toString().trim();
      final score = (payload['score'] as num?)?.toInt() ?? 0;
      final answeredCount = (payload['answeredCount'] as num?)?.toInt() ?? 0;
      final winnerId = (payload['winnerId'] ?? '').toString().trim();
      final mySets = (payload['mySets'] as num?)?.toInt() ?? 0;
      final myLivesRemaining =
          (payload['myLivesRemaining'] as num?)?.toInt() ?? 0;
      final myEliminated = payload['myEliminated'] == true;
      final boardRoom = payload['boardRoom'] == true;
      final isTeamBoard = payload['isTeam'] == true;
      final meOwner = payload['meOwner'] == true;
      final winnerTeam = (payload['winnerTeam'] ?? '').toString().trim();
      final boardWinnerId = (payload['winnerId'] ?? '').toString().trim();
      final opponents = _decodeOpponentsPayload(
        (payload['opponentsJson'] ?? '').toString(),
      );
      if (roomId.isEmpty || matchMode.isEmpty) {
        await nativeBridgeService.clearPendingRoomMatchResult();
        return;
      }

      // Board (التحدي) room result — competition (solo) or team. The host writes
      // every seat's authoritative board score in one transaction (board totals
      // exceed the classic per-question clamp).
      if (boardRoom) {
        if (meOwner) {
          final seatScores = <String, int>{userId: score};
          for (final opponent in opponents) {
            final oid =
                (opponent['userId'] ?? opponent['id'] ?? '').toString().trim();
            if (oid.isNotEmpty) {
              seatScores[oid] = (opponent['score'] as num?)?.toInt() ?? 0;
            }
          }
          await roomService.finalizeRoomBoardMatch(
            roomId: roomId,
            seatScores: seatScores,
            isTeam: isTeamBoard,
            winnerTeam: winnerTeam,
            winnerId: boardWinnerId,
            answeredCount: answeredCount,
          );
        }
        await nativeBridgeService.clearPendingRoomMatchResult();
        return;
      }

      switch (matchMode) {
        case Room.modeBlitz:
          await roomService.finalizeBlitzMatchFromNative(
            roomId: roomId,
            userId: userId,
            score: score,
            answeredCount: answeredCount,
          );
          break;
        case Room.modeBattle:
        case Room.modeTeamBattle:
          await roomService.submitFinalScore(
            roomId: roomId,
            userId: userId,
            score: score,
            answeredCount: answeredCount,
          );
          if (matchMode == Room.modeTeamBattle) {
            await roomService.processTeamBattleResult(roomId: roomId);
          }
          break;
        case Room.modeSeries:
          await roomService.finalizeSeriesMatchFromNative(
            roomId: roomId,
            userId: userId,
            score: score,
            answeredCount: answeredCount,
            roundWins: mySets,
            winnerId: winnerId,
            opponents: opponents,
          );
          break;
        case Room.modeElimination:
        case Room.modeSurvival:
          await roomService.finalizeRoundBasedMatchFromNative(
            roomId: roomId,
            userId: userId,
            matchMode: matchMode,
            score: score,
            answeredCount: answeredCount,
            winnerId: winnerId,
            myEliminated: myEliminated,
            myLivesRemaining: myLivesRemaining,
            opponents: opponents,
          );
          break;
        default:
          break;
      }

      final isWinner = (winnerId.isNotEmpty && winnerId == userId) ||
          (boardWinnerId.isNotEmpty && boardWinnerId == userId);
      if (isWinner && mounted) {
        RateGameService.instance.recordRoomMatchVictory(context);
      }

      await nativeBridgeService.clearPendingRoomMatchResult();
    } catch (_) {
      // Leave room sync silent so returning from native feels seamless.
    } finally {
      _syncingPendingRoomMatchResult = false;
    }
  }

  List<Map<String, dynamic>> _decodeOpponentsPayload(String opponentsJson) {
    final opponents = <Map<String, dynamic>>[];
    if (opponentsJson.trim().isEmpty) {
      return opponents;
    }

    final decoded = jsonDecode(opponentsJson);
    if (decoded is! List) {
      return opponents;
    }

    for (final item in decoded) {
      if (item is Map) {
        opponents.add(
          item.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );
      }
    }
    return opponents;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.user;
    final username =
        (user?.displayName ?? user?.email?.split('@').first ?? 'لاعب').trim();
    final displayUsername =
        username.isEmpty || username.contains('Ã') ? 'لاعب' : username;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(HomeArtwork.background),
            fit: BoxFit.cover,
          ),
        ),
        child: LayoutBuilder(builder: (context, homeArea) {
          return Stack(
            children: [
              // â”€â”€ Dark overlay â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF08262C).withValues(alpha: 0.04),
                        const Color(0xFF061418).withValues(alpha: 0.18),
                      ],
                    ),
                  ),
                ),
              ),

              // â”€â”€ Animated sparkles â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _bgCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _SparklesPainter(_bgCtrl.value),
                  ),
                ),
              ),

              // â”€â”€ CENTER arena â€” full screen width so content is truly centred â”€â”€
              Positioned.fill(
                child: SafeArea(
                  left: false,
                  child: _HomeLobbyLayout(
                    appState: appState,
                    username: displayUsername,
                    user: user,
                    idleCtrl: _idleCtrl,
                    onCampaignTap: () => unawaited(_openCampaignMap()),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

void _showOnlineRequiredToast(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'تتطلب هذه الميزة اتصالا بالإنترنت',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  TOP BAR
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Future<void> _showGameModesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.50),
    isScrollControlled: true,
    builder: (sheetContext) => _GameModesSheet(rootContext: context),
  );
}

class _GameModesSheet extends StatelessWidget {
  const _GameModesSheet({required this.rootContext});

  final BuildContext rootContext;

  void _openOnlineRoute(
    BuildContext sheetContext,
    Widget screen,
    bool isOnline,
  ) {
    Navigator.of(sheetContext).pop();
    if (!isOnline) {
      _showOnlineRequiredToast(rootContext);
      return;
    }
    Navigator.of(rootContext).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  void _runMode(BuildContext sheetContext, VoidCallback action) {
    Navigator.of(sheetContext).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final media = MediaQuery.of(context);
    final width = math.min(
        900.0,
        math.min(
            media.size.width - media.padding.horizontal - 24,
            (media.size.height - media.padding.vertical - 24) *
                GameModesArtwork.aspectRatio));
    return SafeArea(
        child: Center(
            child: Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
          width: width,
          child: GameModesArtwork(
            isOnline: appState.isOnline,
            onClose: () => Navigator.of(context).pop(),
            onMainChallenge: () => _runMode(context,
                () => rootContext.read<AppState>().openMainChallenge()),
            onGroupChallenge: () => _openOnlineRoute(
                context, const RoomsScreen(), appState.isOnline),
            onFriendChallenge: () => _openOnlineRoute(
                context, const SocialScreen(), appState.isOnline),
            onOffline: () => _runMode(
                context, () => rootContext.read<AppState>().openOfflineGame()),
            onUnavailable: () =>
                _runMode(context, () => _showOnlineRequiredToast(rootContext)),
          )),
    )));
  }
}

class _HomeMenuButton extends StatefulWidget {
  const _HomeMenuButton({
    required this.appState,
    required this.username,
    required this.user,
  });

  final AppState appState;
  final String username;
  final dynamic user;

  @override
  State<_HomeMenuButton> createState() => _HomeMenuButtonState();
}

class _HomeMenuButtonState extends State<_HomeMenuButton> {
  int _pendingRewards = 0;

  @override
  void initState() {
    super.initState();
    _refreshPendingRewards();
  }

  Future<void> _refreshPendingRewards() async {
    try {
      final data = await context.read<NativeBridgeService>().getAchievements();
      if (!mounted) return;
      setState(() {
        _pendingRewards = (data['unclaimedAchievements'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingRewards = 0);
    }
  }

  Future<void> _openMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.50),
      isScrollControlled: true,
      builder: (sheetContext) => _HomeMenuSheet(
        rootContext: context,
        username: widget.username,
        user: widget.user,
        pendingRewards: _pendingRewards,
      ),
    );
    if (mounted) {
      await _refreshPendingRewards();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDailyReward = widget.appState.isOnline &&
        widget.appState.streakDay > 0 &&
        !widget.appState.claimedToday;
    final hasAttention = hasDailyReward || _pendingRewards > 0;

    return Padding(
      padding: EdgeInsets.zero,
      child: Tooltip(
        message: 'القائمة',
        child: GestureDetector(
          onTap: _openMenu,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Image.asset(HomeArtwork.menu,
                    fit: BoxFit.contain, excludeFromSemantics: true),
              ),
              if (hasAttention)
                const Positioned(top: -3, right: -3, child: _UnclaimedDot()),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeMenuSheet extends StatelessWidget {
  const _HomeMenuSheet({
    required this.rootContext,
    required this.username,
    required this.user,
    required this.pendingRewards,
  });

  final BuildContext rootContext;
  final String username;
  final dynamic user;
  final int pendingRewards;

  void _openScreen(
    BuildContext sheetContext,
    Widget screen,
  ) {
    Navigator.of(sheetContext).pop();
    Navigator.of(rootContext).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveState = context.watch<AppState>();
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.padding.vertical - 24;
    final width = math.min(
        1000.0,
        math.min(media.size.width - media.padding.horizontal - 24,
            availableHeight * HomeMenuArtwork.aspectRatio));
    final dailyReady = liveState.isOnline &&
        liveState.streakDay > 0 &&
        !liveState.claimedToday;
    return SafeArea(
        child: Center(
            child: Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
          width: width,
          child: HomeMenuArtwork(
            username: username,
            rankTitle: PlayerRank.titleForLevel(liveState.level),
            rankColor: PlayerRank.colorForLevel(liveState.level),
            photoUrl: user?.photoURL,
            isOnline: liveState.isOnline,
            dailyReady: dailyReady,
            pendingRewards: pendingRewards,
            onProfile: () => _openScreen(context, const ProfileScreen()),
            onClose: () => Navigator.of(context).pop(),
            onLeaderboard: () =>
                _openScreen(context, const LeaderboardScreen()),
            onRewards: () => _openScreen(context, const DailyStreakScreen()),
            onStats: () => _openScreen(context, const StatsScreen()),
            onAchievements: () =>
                _openScreen(context, const AchievementsScreen()),
            onSettings: () => _openScreen(context, const SettingsScreen()),
            onUnavailable: () {
              Navigator.of(context).pop();
              _showOnlineRequiredToast(rootContext);
            },
            ratingEntry: FutureBuilder<bool>(
              future: RateGameService.instance.shouldShowRatingEntry(),
              builder: (context, snapshot) {
                if (snapshot.data != true) return const SizedBox.shrink();
                return Tooltip(
                  message:
                      'شاركنا رأيك وادعمنا للحصول على 500 كوين + 10 جواهر 🎁',
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      RateGameService.instance
                          .showRateDialog(rootContext, isManual: true);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFFDDAF55), width: 2),
                          gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF826031), Color(0xFF35243E)]),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0xAA000000),
                                blurRadius: 8,
                                offset: Offset(0, 4))
                          ]),
                      child: const FittedBox(
                          fit: BoxFit.contain,
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text('تقييم أرض التحدي ⭐',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    height: 1.25,
                                    fontWeight: FontWeight.w900)),
                            Text('500 نقود + 10 جواهر',
                                style: TextStyle(
                                    color: Color(0xFFFDE68A),
                                    fontSize: 12,
                                    height: 1.4,
                                    fontWeight: FontWeight.w700)),
                            Text('قيّم الآن',
                                style: TextStyle(
                                    color: Color(0xFFFFD761),
                                    fontSize: 15,
                                    height: 1.25,
                                    fontWeight: FontWeight.w900)),
                          ])),
                    ),
                  ),
                );
              },
            ),
          )),
    )));
  }
}

/// Existing artwork arranged around the selected contestant, as a game lobby.
class _HomeLobbyLayout extends StatelessWidget {
  const _HomeLobbyLayout({
    required this.appState,
    required this.username,
    required this.user,
    required this.idleCtrl,
    required this.onCampaignTap,
  });
  final AppState appState;
  final String username;
  final dynamic user;
  final AnimationController idleCtrl;
  final VoidCallback onCampaignTap;

  void _openOnlineScreen(BuildContext context, Widget screen) {
    if (!appState.isOnline) {
      _showOnlineRequiredToast(context);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, area) {
        // The shortcut rail uses a small physical edge inset. Keep the remaining
        // controls in their original safe area on displays with a left cutout.
        final safeLeft = MediaQuery.paddingOf(context).left;
        final width = area.maxWidth - safeLeft;
        final height = area.maxHeight;
        final portrait = height > width;
        final headerHeight = portrait ? 108.0 : 64.0;
        final panelWidth =
            portrait ? width - 32 : (width * .29).clamp(190.0, 340.0);
        final panelTop = portrait ? height * .66 : headerHeight + 16;
        final panelHeight = height - panelTop - 16;
        final heroLeftInset = portrait ? 64.0 : 76.0;
        final heroLeft = heroLeftInset + safeLeft;
        final heroWidth =
            portrait ? width - 80 : width - panelWidth - heroLeftInset - 40;
        final heroBottom = portrait ? panelTop - 10 : height - 16;
        final characterTop = headerHeight + 62;
        final characterHeight = math.max(1.0, heroBottom - characterTop);
        final compact = height < 600;
        final maxWalletWidth =
            portrait ? width - 28 : (width - 100).clamp(280.0, 520.0);
        final balanceWidth = (maxWalletWidth - 12) / 4;
        const walletGap = 2.0;
        const resourceScale = .9;
        final keysWidth =
            math.min(balanceWidth, 44 * 1608 / 872) * resourceScale;
        final ticketsWidth =
            math.min(balanceWidth, 44 * 1616 / 884) * resourceScale;
        final walletWidth =
            balanceWidth * 2 + keysWidth + ticketsWidth + walletGap * 3;
        final badgeHeight =
            portrait ? 56.0 : (panelHeight * .20).clamp(42.0, 64.0);
        final bannerHeight = portrait
            ? 66.0
            : math.min(
                panelWidth * .32, (panelHeight - badgeHeight * 2 - 28) / 2);
        Widget fitBadge(Widget badge) => SizedBox(
            height: badgeHeight,
            width: portrait ? (panelWidth - 12) / 2 : panelWidth,
            child: FittedBox(fit: BoxFit.contain, child: badge));
        Widget banner(String asset, String label, VoidCallback onPressed,
                {bool enabled = true}) =>
            SizedBox(
                width: portrait ? (panelWidth - 12) / 2 : panelWidth,
                height: bannerHeight,
                child: FittedBox(
                    child: _BattleButton(
                        asset: asset,
                        label: label,
                        compact: compact,
                        enabled: enabled,
                        onPressed: onPressed)));
        final campaign = banner(
            HomeArtwork.campaign, 'تحدي المراحل', onCampaignTap,
            enabled: appState.isOnline);
        final modes = banner(HomeArtwork.modes, 'أوضاع اللعب',
            () => _showGameModesSheet(context));
        final promotions = [
          if (!appState.isVip) fitBadge(const SpecialOfferBadge()),
          fitBadge(const CrossPromoMillionaireBadge()),
        ];
        return Stack(children: [
          Positioned(
              top: 6,
              left: 12,
              child: _HomeMenuButton(
                  appState: appState, username: username, user: user)),
          Positioned(
              top: portrait ? 60 : 8,
              right: portrait ? (width - walletWidth) / 2 : 16,
              width: walletWidth,
              height: 44,
              child: Row(textDirection: TextDirection.ltr, children: [
                for (final gems in [false, true]) ...[
                  if (gems) const SizedBox(width: walletGap),
                  SizedBox(
                      width: balanceWidth,
                      child: HomeCurrencyArtwork(
                          key: ValueKey(gems
                              ? 'home-gems-balance'
                              : 'home-coins-balance'),
                          gems: gems,
                          value: (gems ? appState.gems : appState.coins)
                              .toString(),
                          enabled: appState.isOnline,
                          onPressed: () =>
                              _openOnlineScreen(context, const StoreScreen()))),
                ],
                const SizedBox(width: walletGap),
                SizedBox(
                    width: keysWidth,
                    child: HomeResourceArtwork(
                        key: const ValueKey('home-keys-balance'),
                        tickets: false,
                        value: appState.economyLoaded
                            ? '${appState.economyWallet.totalKeys}'
                            : '…',
                        enabled: appState.isOnline,
                        onPressed: () => _openOnlineScreen(
                            context, const ResourceShopScreen()))),
                const SizedBox(width: walletGap),
                SizedBox(
                    width: ticketsWidth,
                    child: HomeResourceArtwork(
                        key: const ValueKey('home-tickets-balance'),
                        tickets: true,
                        value: appState.economyLoaded
                            ? '${appState.economyWallet.tickets}'
                            : '…',
                        enabled: appState.isOnline,
                        onPressed: () => _openOnlineScreen(
                            context, const ResourceShopScreen()))),
              ])),
          Positioned(
              top: headerHeight + 2,
              left: heroLeft,
              width: heroWidth,
              height: 56,
              child: Center(child: _LevelBadge(appState: appState))),
          Positioned(
              top: characterTop,
              left: heroLeft,
              width: heroWidth,
              height: characterHeight,
              child: HomeCharacterArtwork(
                  key: const ValueKey('home-selected-character'),
                  character: appState.selectedCharacter)),
          Positioned(
              top: portrait ? headerHeight + 12 : 74,
              left: 12,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                HomeQuickAction(
                    key: const ValueKey('home-friends-shortcut'),
                    asset: HomeArtwork.friends,
                    label: 'الأصدقاء واللاعبون',
                    icon: Icons.people_alt_rounded,
                    color: const Color(0xFF7DD3FC),
                    animation: idleCtrl,
                    showGreenDot: true,
                    isAvailable: appState.isOnline,
                    onPressed: () =>
                        _openOnlineScreen(context, const SocialScreen())),
                const SizedBox(height: 12),
                HomeQuickAction(
                    key: const ValueKey('home-store-shortcut'),
                    asset: HomeArtwork.store,
                    label: 'المتجر',
                    icon: Icons.shopping_basket_rounded,
                    color: const Color(0xFFFFD761),
                    animation: idleCtrl,
                    animationPhase: math.pi / 3,
                    isAvailable: appState.isOnline,
                    onPressed: () =>
                        _openOnlineScreen(context, const StoreScreen())),
              ])),
          Positioned(
              key: const ValueKey('home-actions-panel'),
              top: panelTop,
              right: 16,
              width: panelWidth,
              height: panelHeight,
              child: portrait
                  ? Column(children: [
                      Row(
                          textDirection: TextDirection.ltr,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            campaign,
                            const SizedBox(width: 12),
                            modes
                          ]),
                      const Spacer(),
                      Row(
                          textDirection: TextDirection.rtl,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: promotions),
                    ])
                  : Column(children: [
                      ...promotions.expand(
                          (badge) => [badge, const SizedBox(height: 10)]),
                      const Spacer(),
                      campaign,
                      const SizedBox(height: 8),
                      modes,
                    ])),
        ]);
      });
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) => HomeLevelBadge(
        key: const ValueKey('home-level-badge'),
        level: appState.level,
        xp: appState.xpInCurrentLevel,
        requiredXp: appState.xpNeededForLevel,
      );
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  LEFT SIDEBAR
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _UnclaimedDot extends StatelessWidget {
  const _UnclaimedDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.55),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  WATCH AD CARD
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _BattleButton extends StatelessWidget {
  const _BattleButton(
      {required this.asset,
      required this.label,
      required this.onPressed,
      this.compact = false,
      this.enabled = true});
  final String asset, label;
  final VoidCallback onPressed;
  final bool compact, enabled;
  @override
  Widget build(BuildContext context) => HomeBannerButton(
      asset: asset,
      label: label,
      compact: compact,
      enabled: enabled,
      onPressed: enabled ? onPressed : () => _showOnlineRequiredToast(context));
}

class _SparklesPainter extends CustomPainter {
  _SparklesPainter(this.t);
  final double t; // 0..1 repeating

  static const int _count = 55;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < _count; i++) {
      final seed = i * 2654435761 & 0xFFFFFFFF;
      final fx = ((seed ^ (seed >> 16)) & 0xFFFF) / 0xFFFF;
      final fy = ((seed ^ (seed >> 8)) & 0xFFFF) / 0xFFFF;
      final phase = (i * 0.37) % 1.0;
      // Integer speed (1, 2, 3): particle travels exactly N full screen heights
      // per cycle â†’ position at t=0 equals position at t=1 â†’ zero visible jump.
      final speed = (1 + i % 3).toDouble();
      final radius = 1.0 + (i % 4) * 0.9;

      // Upward drift with seamless full loop
      final raw = (fy - t * speed) % 1.0;
      final dy = raw < 0 ? raw + 1.0 : raw;

      final alpha = math.sin((t * speed + phase) * 2 * math.pi) * 0.5 + 0.5;
      final opacity = (0.15 + alpha * 0.75).clamp(0.0, 1.0);

      final Color base;
      final mod = i % 3;
      if (mod == 0) {
        base = const Color(0xFFFACC15);
      } else if (mod == 1) {
        base = const Color(0xFF38BDF8);
      } else {
        base = Colors.white;
      }

      // Glow halo for larger particles
      if (radius > 2.2) {
        paint
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
          ..color = base.withValues(alpha: opacity * 0.35);
        canvas.drawCircle(
          Offset(fx * size.width, dy * size.height),
          radius * 1.8,
          paint,
        );
        paint.maskFilter = null;
      }

      paint.color = base.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(fx * size.width, dy * size.height),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SparklesPainter old) => old.t != t;
}
