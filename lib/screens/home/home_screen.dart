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
import '../../core/trophy_league.dart';
import '../campaign/campaign_map_screen.dart';
import 'store_screen.dart';
import 'leaderboard_screen.dart';
import 'daily_streak_screen.dart';
import 'profile_screen.dart';
import '../online/settings_screen.dart';
import '../online/stats_screen.dart';
import '../online/achievements_screen.dart';
import '../../services/room_service.dart';
import '../../widgets/currency_reward_overlay.dart';
import '../../services/ad_service.dart';
import '../../services/campaign_result_handler.dart';
import '../../services/invite_service.dart';
import '../../services/native_bridge_service.dart';
import '../../widgets/friend_challenge_modal.dart';
import '../../widgets/cross_promo_millionaire_badge.dart';
import '../../widgets/cross_promo_millionaire_dialog.dart';
import '../../widgets/special_offer_dialog.dart';
import '../../widgets/special_offer_badge.dart';
import '../../widgets/daily_reward_dialog.dart';
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
  late final AnimationController _glowCtrl;
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

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
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
      } else if (action.startsWith('challenge:')) {
        final code = action.substring('challenge:'.length).trim();
        if (code.isNotEmpty) {
          await context.read<AppState>().openFriendChallenge(code);
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
    _glowCtrl.dispose();
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
            image: AssetImage('assets/ui/bg_main.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // â”€â”€ Dark overlay â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0A1B4A).withValues(alpha: 0.80),
                      const Color(0xFF060C24).withValues(alpha: 0.90),
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
              child: _CenterArena(
                appState: appState,
                idleCtrl: _idleCtrl,
                glowCtrl: _glowCtrl,
                onCampaignTap: () => unawaited(_openCampaignMap()),
              ),
            ),

            // â”€â”€ LEFT SIDEBAR â€” overlays the center â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            // â”€â”€ RIGHT SIDEBAR â€” overlays the center â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            // â”€â”€ TOP BAR: currency + arena progress â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopBar(appState: appState),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: _HomeMenuButton(
                appState: appState,
                username: displayUsername,
                user: user,
              ),
            ),
            const Positioned(
              bottom: 12,
              left: 14,
              child: CrossPromoMillionaireBadge(),
            ),
            if (!appState.isVip)
              const Positioned(
                bottom: 12,
                right: 14,
                child: SpecialOfferBadge(),
              ),
          ],
        ),
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
    final isOnline = appState.isOnline;
    final media = MediaQuery.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 700,
              maxHeight: math.min(media.size.height * 0.86, 440.0),
            ),
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF071126).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.34),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.34),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.sports_esports_rounded,
                          color: Color(0xFF38BDF8),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'أوضاع اللعب',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'إغلاق',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.white70,
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.06),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _GameModeTile(
                            icon: Icons.emoji_events_rounded,
                            color: const Color(0xFFFFD761),
                            title: 'التحدي الرئيسي',
                            subtitle: 'فريقان على جهاز واحد',
                            onTap: () => _runMode(
                              context,
                              () => rootContext
                                  .read<AppState>()
                                  .openMainChallenge(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _GameModeTile(
                            icon: Icons.groups_rounded,
                            color: const Color(0xFFFACC15),
                            title: 'تحدي جماعي',
                            subtitle: 'غرف ومنافسة أونلاين',
                            enabled: isOnline,
                            onTap: () => _openOnlineRoute(
                              context,
                              const RoomsScreen(),
                              isOnline,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _GameModeTile(
                            icon: Icons.people_alt_rounded,
                            color: const Color(0xFF38BDF8),
                            title: 'تحدي صديق',
                            subtitle: '1 ضد 1 أو منافس عشوائي',
                            enabled: isOnline,
                            onTap: () => FriendChallengeModal.show(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _GameModeTile(
                            icon: Icons.sports_esports_rounded,
                            color: const Color(0xFF34D399),
                            title: 'أوفلاين',
                            subtitle: 'العب بدون اتصال',
                            onTap: () => _runMode(
                              context,
                              () => rootContext
                                  .read<AppState>()
                                  .openOfflineGame(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GameModeTile extends StatelessWidget {
  const _GameModeTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.50,
      child: GestureDetector(
        onTap: enabled ? onTap : () => _showOnlineRequiredToast(context),
        child: Container(
          height: 112,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.34)),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 28),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (!enabled)
                const Positioned(top: 0, left: 0, child: _LockBadge()),
            ],
          ),
        ),
      ),
    );
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
        appState: widget.appState,
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
    final top = MediaQuery.of(context).padding.top + 6;
    final hasDailyReward = widget.appState.isOnline &&
        widget.appState.streakDay > 0 &&
        !widget.appState.claimedToday;
    final hasAttention = hasDailyReward || _pendingRewards > 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(0, top, 12, 0),
      child: Tooltip(
        message: 'القائمة',
        child: GestureDetector(
          onTap: _openMenu,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.menu_rounded,
                  color: Color(0xFF7DD3FC),
                  size: 28,
                ),
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
    required this.appState,
    required this.username,
    required this.user,
    required this.pendingRewards,
  });

  final BuildContext rootContext;
  final AppState appState;
  final String username;
  final dynamic user;
  final int pendingRewards;

  void _openScreen(
    BuildContext sheetContext,
    Widget screen, {
    bool enabled = true,
  }) {
    Navigator.of(sheetContext).pop();
    if (!enabled) {
      _showOnlineRequiredToast(rootContext);
      return;
    }
    Navigator.of(rootContext).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = appState.isOnline;
    final media = MediaQuery.of(context);
    final rankTitle = PlayerRank.titleForLevel(appState.level);
    final rankColor = PlayerRank.colorForLevel(appState.level);
    final dailyReady =
        isOnline && appState.streakDay > 0 && !appState.claimedToday;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 760,
              maxHeight: math.min(media.size.height * 0.82, 430.0),
            ),
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF071126).withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFFACC15).withValues(alpha: 0.30),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.34),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MenuHeader(
                    username: username,
                    user: user,
                    rankTitle: rankTitle,
                    rankColor: rankColor,
                    onProfile: () =>
                        _openScreen(context, const ProfileScreen()),
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.55,
                      children: [
                        _MenuActionTile(
                          icon: Icons.leaderboard_rounded,
                          color: const Color(0xFFFACC15),
                          title: 'الصدارة',
                          enabled: isOnline,
                          onTap: () => _openScreen(
                            context,
                            const LeaderboardScreen(),
                            enabled: isOnline,
                          ),
                        ),
                        _MenuActionTile(
                          icon: Icons.inventory_2_rounded,
                          color: const Color(0xFF34D399),
                          title: 'المكافآت',
                          badgeLabel: dailyReady ? '!' : null,
                          enabled: isOnline,
                          onTap: () => _openScreen(
                            context,
                            const DailyStreakScreen(),
                            enabled: isOnline,
                          ),
                        ),
                        _MenuActionTile(
                          icon: Icons.storefront_rounded,
                          color: const Color(0xFF38BDF8),
                          title: 'المتجر',
                          enabled: isOnline,
                          onTap: () => _openScreen(
                            context,
                            const StoreScreen(),
                            enabled: isOnline,
                          ),
                        ),
                        _MenuActionTile(
                          icon: Icons.bar_chart_rounded,
                          color: const Color(0xFF60A5FA),
                          title: 'الإحصائيات',
                          onTap: () =>
                              _openScreen(context, const StatsScreen()),
                        ),
                        _MenuActionTile(
                          icon: Icons.emoji_events_rounded,
                          color: const Color(0xFFA78BFA),
                          title: 'الإنجازات',
                          badgeLabel: pendingRewards > 0
                              ? (pendingRewards > 9 ? '9+' : '$pendingRewards')
                              : null,
                          onTap: () => _openScreen(
                            context,
                            const AchievementsScreen(),
                          ),
                        ),
                        _MenuActionTile(
                          icon: Icons.settings_rounded,
                          color: const Color(0xFF94A3B8),
                          title: 'الإعدادات',
                          onTap: () =>
                              _openScreen(context, const SettingsScreen()),
                        ),
                      ],
                    ),
                  ),
                  FutureBuilder<bool>(
                    future: RateGameService.instance.hasRated(),
                    builder: (context, snapshot) {
                      if (snapshot.data == true) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 6),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            RateGameService.instance
                                .showRateDialog(rootContext, isManual: true);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.22),
                                  const Color(0xFF1E293B)
                                      .withValues(alpha: 0.70),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFFFFD54F),
                                        Color(0xFFFFA000),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Image.asset(
                                    'assets/ui/rate.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.star_rounded,
                                      color: Color(0xFF451A03),
                                      size: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'تقييم أرض التحدي ⭐',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        'شاركنا رأيك وادعمنا للحصول على 500 كوين + 10 جواهر 🎁',
                                        style: TextStyle(
                                          color: Color(0xFFFDE68A),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFACC15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'قيّم الآن',
                                    style: TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      CrossPromoMillionaireDialog.show(rootContext);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFF59E0B).withValues(alpha: 0.18),
                            const Color(0xFF1E293B).withValues(alpha: 0.70),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.40),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFFDE68A),
                                  Color(0xFFD97706),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.emoji_events_rounded,
                              color: Color(0xFF451A03),
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'لعبة تحدي المليون 🏆',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Consumer<CrossPromoService>(
                                  builder: (context, promo, _) {
                                    return Text(
                                      promo.isRewardClaimed
                                          ? 'المسابقة الثقافية الشهيرة بأكثر من 50,000 سؤال'
                                          : 'حمّل اللعبة واحصل على 80 جوهرة مجاناً!',
                                      style: const TextStyle(
                                        color: Color(0xFFFDE68A),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          Consumer<CrossPromoService>(
                            builder: (context, promo, _) {
                              final claimed = promo.isRewardClaimed;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: claimed
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  claimed ? 'عرض اللعبة' : '+80 💎 هدية',
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({
    required this.username,
    required this.user,
    required this.rankTitle,
    required this.rankColor,
    required this.onProfile,
    required this.onClose,
  });

  final String username;
  final dynamic user;
  final String rankTitle;
  final Color rankColor;
  final VoidCallback onProfile;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onProfile,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF111827),
              border: Border.all(color: rankColor, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: user?.photoURL?.isNotEmpty == true
                ? Image.network(
                    user!.photoURL!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.person_rounded, color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: onProfile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.circle, color: rankColor, size: 9),
                    const SizedBox(width: 5),
                    Text(
                      rankTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: rankColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Tooltip(
          message: 'إغلاق',
          child: IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            color: Colors.white70,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuActionTile extends StatelessWidget {
  const _MenuActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.badgeLabel,
    this.enabled = true,
  });

  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;
  final String? badgeLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.50,
      child: GestureDetector(
        onTap: enabled ? onTap : () => _showOnlineRequiredToast(context),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.30)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!enabled)
              const Positioned(top: -4, left: -4, child: _LockBadge()),
            if (badgeLabel != null)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.3),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeLabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      height: 1,
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 6;
    final isOnline = appState.isOnline;
    return SizedBox(
      height: top + 52,
      child: Stack(
        children: [
          // Currency chips â€” top left
          Positioned(
            top: top,
            left: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CurrencyChip(
                  icon: Icons.monetization_on_rounded,
                  color: const Color(0xFFFACC15),
                  label: appState.coins.toString(),
                  enabled: isOnline,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const StoreScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                _CurrencyChip(
                  icon: Icons.diamond_rounded,
                  color: const Color(0xFF38BDF8),
                  label: appState.gems.toString(),
                  enabled: isOnline,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const StoreScreen()),
                  ),
                ),
              ],
            ),
          ),
          // Level badge â€” exactly centered
          Positioned(
            top: top,
            left: 0,
            right: 0,
            child: Center(
              child: _LevelBadge(appState: appState),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : () => _showOnlineRequiredToast(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, size: 12, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final level = appState.level;
    final xpIn = appState.xpInCurrentLevel;
    final xpFor = appState.xpNeededForLevel;
    final progress = xpFor > 0 ? (xpIn / xpFor).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFFACC15).withValues(alpha: 0.6), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded,
              color: Color(0xFFFACC15), size: 18),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'المستوى $level',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(
                width: 80,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFFFACC15)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          Text(
            '$xpIn/$xpFor',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  LEFT SIDEBAR
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Kept temporarily while the simplified home menu is validated.
// ignore: unused_element
class _LeftSidebar extends StatelessWidget {
  const _LeftSidebar({required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final isOnline = appState.isOnline;
    return Padding(
      padding: EdgeInsets.fromLTRB(10, MediaQuery.of(context).padding.top + 8,
          6, MediaQuery.of(context).padding.bottom + 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final items = <Widget>[
            _SideCard(
              label: 'Ø§Ù„ØµØ¯Ø§Ø±Ø©',
              icon: Icons.leaderboard_rounded,
              iconColor: const Color(0xFFFACC15),
              enabled: isOnline,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const LeaderboardScreen()),
              ),
            ),
            GestureDetector(
              onTap: isOnline
                  ? () {
                      if (!appState.claimedToday) {
                        DailyRewardDialog.show(context);
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const DailyStreakScreen()),
                        );
                      }
                    }
                  : () => _showOnlineRequiredToast(context),
              child: Opacity(
                opacity: isOnline ? 1.0 : 0.5,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    _ChestCounter(
                      current: appState.rewardWeekCompleted,
                      total: appState.rewardWeekLength,
                    ),
                    if (isOnline &&
                        appState.streakDay > 0 &&
                        !appState.claimedToday)
                      const Positioned(
                        top: -4,
                        right: -4,
                        child: _UnclaimedDot(),
                      ),
                    if (!isOnline)
                      const Positioned(top: 4, right: 4, child: _LockBadge()),
                  ],
                ),
              ),
            ),
            _SideCard(
              label: 'Ø£ÙˆÙÙ„Ø§ÙŠÙ†',
              icon: Icons.sports_esports_rounded,
              iconColor: const Color(0xFF60A5FA),
              onTap: () => context.read<AppState>().openOfflineGame(),
            ),
            _WatchAdCard(),
          ];

          final contentHeight = constraints.maxHeight;
          if (contentHeight < 340) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    items[i],
                    if (i != items.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
            );
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                items[i],
                if (i != items.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.enabled = true,
  });
  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : () => _showOnlineRequiredToast(context),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: iconColor, size: 26),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            if (!enabled)
              const Positioned(top: 4, right: 4, child: _LockBadge()),
          ],
        ),
      ),
    );
  }
}

class _LockBadge extends StatelessWidget {
  const _LockBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.lock_rounded, color: Colors.white70, size: 11),
    );
  }
}

class _ChestCounter extends StatelessWidget {
  const _ChestCounter({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/ui/box1.png',
              width: 36, height: 36, fit: BoxFit.contain),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? (current / total).clamp(0.0, 1.0) : 0,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$current/$total',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

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
class _WatchAdCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final adService = context.watch<AdService>();
    final isOnline = context.select<AppState, bool>((s) => s.isOnline);
    final canWatch = adService.canWatchAd && isOnline;
    final watchesLeft = adService.watchesLeft;

    return GestureDetector(
      onTap: canWatch
          ? () async {
              final reward = await adService.showRewardedAd();
              if (reward != null && context.mounted) {
                final native = context.read<NativeBridgeService>();
                await native.grantCurrency(
                  coins: reward['coins']!,
                  gems: reward['gems']!,
                );
                if (context.mounted) {
                  context.read<AppState>().loadCurrency();
                  showCurrencyRewardOverlay(
                    context,
                    coins: reward['coins']!,
                    gems: reward['gems']!,
                  );
                }
              }
            }
          : (!isOnline ? () => _showOnlineRequiredToast(context) : null),
      child: Opacity(
        opacity: canWatch ? 1.0 : 0.5,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: canWatch
                      ? const Color(0xFF22C55E).withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.18),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.smart_display_rounded,
                      color: Color(0xFF22C55E), size: 22),
                  const SizedBox(height: 3),
                  const Text(
                    'Ù…ÙƒØ§ÙØ£Ø©',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '$watchesLeft/${AdService.maxDailyWatches}',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (!isOnline)
              const Positioned(top: 4, right: 4, child: _LockBadge()),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  CENTER ARENA (Castle + Battle button)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _CenterArena extends StatelessWidget {
  const _CenterArena({
    required this.appState,
    required this.idleCtrl,
    required this.glowCtrl,
    required this.onCampaignTap,
  });
  final AppState appState;
  final AnimationController idleCtrl;
  final AnimationController glowCtrl;
  final VoidCallback onCampaignTap;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final width = constraints.maxWidth;
        final isCompactHeight = height < 600;
        final logoMaxHeight =
            (height * (isCompactHeight ? 0.34 : 0.27)).clamp(170.0, 220.0);
        final logoMaxWidth =
            (width * (isCompactHeight ? 0.24 : 0.22)).clamp(280.0, 330.0);
        final buttonHeight = isCompactHeight ? 46.0 : 52.0;
        final buttonGap = isCompactHeight ? 8.0 : 10.0;
        final buttonGroupHeight = buttonHeight * 2 + buttonGap;
        final buttonBottom = media.padding.bottom + 8;
        final buttonTop = height - buttonBottom - buttonGroupHeight;
        final minLogoCenterY = media.padding.top + 68 + logoMaxHeight / 2;
        final maxLogoCenterY = buttonTop - 14 - logoMaxHeight / 2;
        final preferredLogoCenterY = height * 0.5 - 20;
        final logoCenterY = maxLogoCenterY < minLogoCenterY
            ? preferredLogoCenterY
            : preferredLogoCenterY.clamp(minLogoCenterY, maxLogoCenterY);

        return Stack(
          alignment: Alignment.center,
          children: [
            // â”€â”€ Logo â€” centered responsively â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Positioned(
              top: logoCenterY - logoMaxHeight / 2,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: logoMaxWidth,
                  height: logoMaxHeight,
                  child: AnimatedBuilder(
                    animation: idleCtrl,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, math.sin(idleCtrl.value * math.pi) * 6),
                      child: child,
                    ),
                    child: _CastleWidget(),
                  ),
                ),
              ),
            ),

            // â”€â”€ Ranking + Battle buttons â€” pinned to bottom â”€â”€â”€â”€â”€
            Positioned(
              bottom: buttonBottom,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BattleButton(
                    glowCtrl: glowCtrl,
                    label: 'تحدي المراحل',
                    green: true,
                    compact: isCompactHeight,
                    enabled: appState.isOnline,
                    onPressed: onCampaignTap,
                  ),
                  SizedBox(height: buttonGap),
                  _BattleButton(
                    glowCtrl: glowCtrl,
                    label: 'أوضاع اللعب',
                    gold: false,
                    compact: isCompactHeight,
                    enabled: true,
                    onPressed: () => _showGameModesSheet(context),
                  ),
                ],
              ),
            ),
            if (buttonHeight < 0)
              Positioned(
                bottom: buttonBottom,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _BattleButton(
                      glowCtrl: glowCtrl,
                      label: 'تحدي المراحل',
                      green: true,
                      compact: isCompactHeight,
                      enabled: appState.isOnline,
                      onPressed: onCampaignTap,
                    ),
                    SizedBox(height: buttonGap),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _BattleButton(
                          glowCtrl: glowCtrl,
                          label: 'ØªØ­Ø¯ÙŠ Ø¬Ù…Ø§Ø¹ÙŠ',
                          gold: true,
                          compact: isCompactHeight,
                          textColor: Colors.white,
                          enabled: appState.isOnline,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const RoomsScreen()),
                          ),
                        ),
                        SizedBox(width: isCompactHeight ? 10 : 12),
                        _BattleButton(
                          glowCtrl: glowCtrl,
                          label: 'تحدي صديق',
                          gold: false,
                          compact: isCompactHeight,
                          enabled: appState.isOnline,
                          onPressed: () => FriendChallengeModal.show(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CastleWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/ui/logo.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

class _BattleButton extends StatefulWidget {
  const _BattleButton({
    required this.glowCtrl,
    required this.label,
    required this.onPressed,
    this.green = false,
    this.gold = true,
    this.compact = false,
    this.enabled = true,
    this.textColor,
  });
  final AnimationController glowCtrl;
  final String label;
  final VoidCallback onPressed;
  final bool green;
  final bool gold;
  final bool compact;
  final bool enabled;
  final Color? textColor;

  @override
  State<_BattleButton> createState() => _BattleButtonState();
}

class _BattleButtonState extends State<_BattleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final width = widget.compact ? 148.0 : 160.0;
    final height = widget.compact ? 46.0 : 52.0;
    final fontSize = widget.compact ? 18.0 : 20.0;
    final isGreen = widget.green;
    final isGold = widget.gold;
    final enabled = widget.enabled;
    final gradColors = isGreen
        ? const [Color(0xFF34D399), Color(0xFF16A34A)]
        : isGold
            ? const [Color(0xFFF8D34C), Color(0xFFF59E0B)]
            : const [Color(0xFF6D28D9), Color(0xFF2563EB)];
    final borderColor = isGreen
        ? const Color(0xFFBBF7D0)
        : isGold
            ? const Color(0xFFFFF3A3)
            : const Color(0xFFA5F3FC);
    final glowColor = isGreen
        ? const Color(0xFF22C55E)
        : isGold
            ? const Color(0xFFF59E0B)
            : const Color(0xFF2563EB);
    final textColor = widget.textColor ??
        (isGold && !isGreen ? const Color(0xFF1F2937) : Colors.white);

    return AnimatedBuilder(
      animation: widget.glowCtrl,
      builder: (_, __) {
        final glow = enabled ? (0.3 + widget.glowCtrl.value * 0.4) : 0.0;
        return AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: GestureDetector(
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: enabled
                ? (_) {
                    setState(() => _pressed = false);
                    widget.onPressed();
                  }
                : (_) => _showOnlineRequiredToast(context),
            onTapCancel:
                enabled ? () => setState(() => _pressed = false) : null,
            child: Opacity(
              opacity: enabled ? 1.0 : 0.55,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(colors: gradColors),
                      border: Border.all(color: borderColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withValues(alpha: glow),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  if (!enabled)
                    const Positioned(top: 6, right: 8, child: _LockBadge()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ignore: unused_element
Future<void> _showChestRewardDialog(BuildContext context, int coins, int gems) {
  return showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF152055),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'ðŸŽ ØªÙ… ÙØªØ­ Ø§Ù„ØµÙ†Ø¯ÙˆÙ‚!',
        textAlign: TextAlign.center,
        style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (coins > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monetization_on_rounded,
                    color: Color(0xFFFACC15), size: 28),
                const SizedBox(width: 8),
                Text('+$coins',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          if (gems > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.diamond_rounded,
                    color: Color(0xFF38BDF8), size: 28),
                const SizedBox(width: 8),
                Text('+$gems',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Ø±Ø§Ø¦Ø¹!',
              style: TextStyle(
                  color: Color(0xFFFACC15), fontWeight: FontWeight.w900)),
        ),
      ],
    ),
  );
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  RIGHT SIDEBAR
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Kept temporarily while the simplified home menu is validated.
// ignore: unused_element
class _RightSidebar extends StatelessWidget {
  const _RightSidebar({
    required this.appState,
    required this.username,
    required this.user,
  });
  final AppState appState;
  final String username;
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    // Use MediaQuery to get the top inset safely (works with immersive mode)
    final topPad = MediaQuery.of(context).padding.top + 8;
    final botPad = MediaQuery.of(context).padding.bottom + 8;
    final isOnline = appState.isOnline;

    return Padding(
      padding: EdgeInsets.fromLTRB(6, topPad, 10, botPad),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final navButtons = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NavButton(
                label: 'Ø¥Ø­ØµØ§Ø¦ÙŠØ§Øª',
                icon: Icons.bar_chart_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const StatsScreen()),
                ),
              ),
              const SizedBox(height: 4),
              const _AchievementNavButton(),
              const SizedBox(height: 4),
              _NavButton(
                label: 'Ù…ØªØ¬Ø±',
                icon: Icons.storefront_rounded,
                enabled: isOnline,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const StoreScreen()),
                ),
              ),
              const SizedBox(height: 4),
              _NavButton(
                label: 'Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª',
                icon: Icons.settings_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          );
          final dailyChests = GestureDetector(
            onTap: isOnline
                ? () => DailyRewardDialog.show(context)
                : () => _showOnlineRequiredToast(context),
            child: Opacity(
              opacity: isOnline ? 1.0 : 0.5,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  _DailyChests(appState: appState),
                  if (isOnline &&
                      appState.streakDay > 0 &&
                      !appState.claimedToday)
                    const Positioned(
                      top: -4,
                      right: -4,
                      child: _UnclaimedDot(),
                    ),
                  if (!isOnline)
                    const Positioned(top: 4, right: 4, child: _LockBadge()),
                ],
              ),
            ),
          );
          final profileCard = _PlayerCard(
            appState: appState,
            username: username,
            user: user,
          );

          if (constraints.maxHeight < 350) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  navButtons,
                  const SizedBox(height: 10),
                  dailyChests,
                  const SizedBox(height: 10),
                  profileCard,
                ],
              ),
            );
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: [
              navButtons,
              dailyChests,
              profileCard,
            ],
          );
        },
      ),
    );
  }
}

class _AchievementNavButton extends StatefulWidget {
  const _AchievementNavButton();

  @override
  State<_AchievementNavButton> createState() => _AchievementNavButtonState();
}

class _AchievementNavButtonState extends State<_AchievementNavButton> {
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

  Future<void> _openAchievements() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AchievementsScreen()),
    );
    if (mounted) {
      await _refreshPendingRewards();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        _NavButton(
          label: 'Ø¥Ù†Ø¬Ø§Ø²Ø§Øª',
          icon: Icons.emoji_events_rounded,
          onTap: _openAchievements,
        ),
        if (_pendingRewards > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                    blurRadius: 10,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                _pendingRewards > 9 ? '9+' : '$_pendingRewards',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : () => _showOnlineRequiredToast(context),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF091332).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: const Color(0xFF7DD3FC), size: 22),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            if (!enabled)
              const Positioned(top: 2, right: 2, child: _LockBadge()),
          ],
        ),
      ),
    );
  }
}

class _DailyChests extends StatelessWidget {
  const _DailyChests({required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final opened = appState.rewardWeekCompleted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFFACC15).withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'ØµÙ†Ø§Ø¯ÙŠÙ‚ ÙŠÙˆÙ…ÙŠØ©',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFACC15),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(appState.rewardWeekLength, (i) {
              final isOpened = i < opened;
              const closedBoxImages = [
                'assets/ui/box1.png',
                'assets/ui/box2.png',
                'assets/ui/box3.png',
              ];
              final imagePath = isOpened
                  ? 'assets/ui/box4.png'
                  : closedBoxImages[i % closedBoxImages.length];
              return Opacity(
                opacity: isOpened ? 1.0 : 0.5,
                child: SizedBox(
                  width: 30,
                  height: 34,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Image.asset(imagePath, fit: BoxFit.contain),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  SPARKLES BACKGROUND PAINTER
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.appState,
    required this.username,
    required this.user,
  });
  final AppState appState;
  final String username;
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final rankTitle = PlayerRank.titleForLevel(appState.level);
    final rankColor = PlayerRank.colorForLevel(appState.level);
    final league = TrophyProgression.leagueFor(appState.trophies);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
      ),
      child: Container(
        width: 188,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C3AED),
                border: Border.all(color: const Color(0xFFFACC15), width: 2),
              ),
              child: ClipOval(
                child: user?.photoURL?.isNotEmpty == true
                    ? Image.network(user!.photoURL!, fit: BoxFit.cover)
                    : const Icon(Icons.person_rounded,
                        size: 20, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    username.isEmpty ? 'Ù„Ø§Ø¹Ø¨' : username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: rankColor),
                      const SizedBox(width: 3),
                      Text(
                        rankTitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: rankColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(league.icon, size: 12, color: league.color),
                      const SizedBox(width: 3),
                      Text(
                        '${appState.trophies} ${league.nameAr}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: league.color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Edit icon
            Icon(Icons.edit_rounded,
                size: 14, color: Colors.white.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
