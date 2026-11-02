import '../../widgets/game_notice.dart';
import '../../widgets/home_background.dart';
import '../../core/performance_probe.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:challenge_land/screens/online/rooms_screen.dart';
import '../online/room_lobby_screen.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/app_settings.dart';
import '../../models/room.dart';
import '../../models/campaign_home_progress.dart';
import '../../core/player_rank.dart';
import '../campaign/campaign_map_screen.dart';
import '../character/character_select_screen.dart';
import '../../core/campaign_navigation.dart';
import '../../models/store_catalog.dart';
import 'store_screen.dart';
import 'leaderboard_screen.dart';
import 'daily_streak_screen.dart';
import 'profile_screen.dart';
import '../online/settings_screen.dart';
import '../online/stats_screen.dart';
import '../online/achievements_screen.dart';
import '../../services/room_service.dart';
import '../../services/online_match_flow.dart';
import '../../services/campaign_result_handler.dart';
import '../../services/campaign_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/invite_service.dart';
import '../../services/native_bridge_service.dart';
import '../../widgets/friend_challenge_modal.dart';
import '../../widgets/incoming_invite_dialog.dart';
import '../social/social_screen.dart';
import '../social/invite_friends_page.dart';
import '../../services/referral_service.dart';
import '../../widgets/special_offer_dialog.dart';
import '../../widgets/daily_reward_dialog.dart';
import '../../widgets/home_quick_action.dart';
import '../../widgets/home_menu_artwork.dart';
import '../../widgets/game_modes_artwork.dart';
import '../../widgets/home_artwork.dart';
import '../../widgets/home_action_sidebar.dart';
import '../../widgets/home_character_artwork.dart';
import '../../widgets/play_stake_dialog.dart';
import '../../services/rate_game_service.dart';
import '../../services/cross_promo_service.dart';
import '../../widgets/adaptive_asset_image.dart';
import '../../widgets/online_match_recovery_card.dart';
import '../../widgets/sign_in_required_action.dart';
import '../../widgets/support_contact_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/guide/home_guide_steps.dart';
import '../../widgets/guide/page_guide.dart';
import '../../widgets/guide/page_guide_steps.dart';
import '../../widgets/guide/persistent_guide_button.dart';
import '../../widgets/guide/unified_guest_tour_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.campaignService, this.leaderboardService});

  final CampaignService? campaignService;
  final LeaderboardService? leaderboardService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, RouteAware {
  final _idleProgress = ValueNotifier<double>(0);
  late final Animation<double> _idleAnimation;
  final _idleClock = Stopwatch();
  Timer? _idleTimer;
  AppState? _observedAppState;
  bool _appActive = true;
  Timer? _clipboardTimer;
  Timer? _luckyWheelTimer;
  bool _syncingPendingRoomMatchResult = false;
  bool _handlingNativeLaunchAction = false;
  bool _checkingReferral = false;
  String? _shownReferral;
  bool _hasCheckedLuckyWheelThisLaunch = false;
  String? _initializedUserId;
  CampaignService? _campaignService;
  CampaignHomeProgress? _campaignProgress;
  int _campaignProgressRequest = 0;
  bool _campaignWasOnline = false;
  StreamSubscription<String>? _campaignProgressSubscription;
  LeaderboardService? _leaderboardService;
  StreamSubscription<int?>? _leaderboardRankSubscription;
  int? _leaderboardRank;
  int? _rankTrophies;
  int _leaderboardRankRequest = 0;
  int _leaderboardWatchGeneration = 0;

  // ── Guide Tour & Navigation Keys ─────────────────────────────
  final _guideTargets = {
    for (final target in HomeGuideTarget.values) target: GlobalKey(),
  };
  bool _hasInitializedUser = false;

  bool _showGuideTour = false;
  bool _hasCheckedTourGuide = false;

  @override
  void initState() {
    super.initState();
    PerformanceProbe.mark('home.mount');
    if (PerformanceProbe.enabled) {
      PerformanceProbe.idle.addListener(_syncIdleAnimation);
    }
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appActive = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _campaignProgressSubscription =
        CampaignService.progressUpdates.listen((uid) {
      if (mounted && context.read<AppState>().user?.uid == uid) {
        unawaited(_refreshCampaignProgress());
      }
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _idleAnimation = Animation<double>.fromValueListenable(_idleProgress);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(context.read<NativeBridgeService>().playLobbyMusic());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      campaignRouteObserver.subscribe(this, route);
    }
    _syncIdleAnimation();
    final appState = context.read<AppState>();
    if (_observedAppState != appState) {
      _observedAppState?.removeListener(_onAppStateChanged);
      _observedAppState = appState;
      appState.addListener(_onAppStateChanged);
    }
    _updateUserState(appState);
  }

  void _syncIdleAnimation() {
    if ((!PerformanceProbe.enabled || PerformanceProbe.idle.value) &&
        _appActive &&
        TickerMode.of(context) &&
        !MediaQuery.disableAnimationsOf(context)) {
      _idleClock.start();
      // Ambient highlights do not need to repaint at the panel's 90/120 Hz.
      // Interaction/entrance animations keep their normal display rate.
      _idleTimer ??= Timer.periodic(const Duration(microseconds: 41667), (_) {
        final phase = (_idleClock.elapsedMicroseconds / 3000000) % 2;
        _idleProgress.value = phase <= 1 ? phase : 2 - phase;
      });
    } else {
      _idleTimer?.cancel();
      _idleTimer = null;
      _idleClock.stop();
      if (MediaQuery.disableAnimationsOf(context)) _idleProgress.value = 0;
    }
  }

  void _onAppStateChanged() {
    if (mounted) _updateUserState(_observedAppState!);
  }

  void _updateUserState(AppState appState) {
    final uid = appState.user?.uid;
    final accountChanged = !_hasInitializedUser || _initializedUserId != uid;
    final reconnected = !_campaignWasOnline && appState.isOnline;
    final trophiesChanged = _rankTrophies != appState.trophies;
    _rankTrophies = appState.trophies;
    _campaignWasOnline = appState.isOnline;
    if (accountChanged) {
      _clipboardTimer?.cancel();
      _luckyWheelTimer?.cancel();
      _campaignProgressRequest++;
      _campaignProgress = null;
      _leaderboardRankRequest++;
      _leaderboardWatchGeneration++;
      _leaderboardRank = null;
      unawaited(_leaderboardRankSubscription?.cancel());
      _leaderboardRankSubscription = null;
    }
    if (uid != null && appState.isOnline && (accountChanged || reconnected)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || context.read<AppState>().user?.uid != uid) return;
        unawaited(_refreshCampaignProgress());
        _watchLeaderboardRank(uid);
      });
    } else if (uid != null && appState.isOnline && trophiesChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || context.read<AppState>().user?.uid != uid) return;
        unawaited(_refreshLeaderboardRank());
      });
    }
    if (_hasInitializedUser && _initializedUserId == uid) return;
    _hasInitializedUser = true;
    _initializedUserId = uid;
    _hasCheckedLuckyWheelThisLaunch = false;
    if (uid == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndTriggerGuideTour();
      });
      return;
    }
    if (_showGuideTour) {
      _showGuideTour = false;
      unawaited(_persistGuideCompletion());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || context.read<AppState>().user?.uid != uid) return;
      context.read<AppState>().loadCurrency();
      context.read<AppState>().loadLevelData();
      _consumePendingRoomMatchResult();
      CampaignResultHandler.consumeAndHandlePendingCampaignResult(
        context: context,
      );
      _consumeNativeLaunchAction();
      _checkPendingReferral();
      _clipboardTimer?.cancel();
      _clipboardTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted && context.read<AppState>().user?.uid == uid) {
          _checkClipboardForIncomingInvite();
        }
      });
      _checkAndShowLuckyWheel();
    });
  }

  Future<void> _refreshCampaignProgress() async {
    if (!mounted) return;
    final appState = context.read<AppState>();
    final uid = appState.user?.uid;
    if (uid == null || !appState.isOnline) return;
    final request = ++_campaignProgressRequest;
    try {
      final service =
          widget.campaignService ?? (_campaignService ??= CampaignService());
      final progress = await service.loadHomeProgress(uid: uid);
      if (!mounted ||
          request != _campaignProgressRequest ||
          context.read<AppState>().user?.uid != uid) {
        return;
      }
      if (_campaignProgress?.reachedStage != progress.reachedStage ||
          _campaignProgress?.totalStages != progress.totalStages) {
        setState(() => _campaignProgress = progress);
      }
    } catch (_) {
      // Keep the last known stage if a refresh is temporarily unavailable.
    }
  }

  LeaderboardService get _rankService =>
      widget.leaderboardService ??
      (_leaderboardService ??= LeaderboardService());

  void _watchLeaderboardRank(String uid) {
    final generation = ++_leaderboardWatchGeneration;
    unawaited(_leaderboardRankSubscription?.cancel());
    try {
      _leaderboardRankSubscription =
          _rankService.watchWorldRank(uid: uid).listen((rank) {
        if (!mounted ||
            generation != _leaderboardWatchGeneration ||
            context.read<AppState>().user?.uid != uid) {
          return;
        }
        _leaderboardRankRequest++;
        if (_leaderboardRank != rank) {
          setState(() => _leaderboardRank = rank);
        }
      }, onError: (Object _) {
        // A failed read cannot establish a new leaderboard position.
      });
    } catch (_) {
      // The medallion stays unranked until real leaderboard data is available.
    }
  }

  Future<void> _refreshLeaderboardRank() async {
    if (!mounted) return;
    final appState = context.read<AppState>();
    final uid = appState.user?.uid;
    if (uid == null || !appState.isOnline) return;
    final request = ++_leaderboardRankRequest;
    try {
      final rank = await _rankService.loadWorldRank(uid: uid);
      if (!mounted ||
          request != _leaderboardRankRequest ||
          context.read<AppState>().user?.uid != uid) {
        return;
      }
      if (_leaderboardRank != rank) {
        setState(() => _leaderboardRank = rank);
      }
    } catch (_) {
      // Retain this account's last confirmed position during a connection error.
    }
  }

  Future<void> _checkAndTriggerGuideTour() async {
    if (!mounted || _hasCheckedTourGuide) return;
    _hasCheckedTourGuide = true;

    final appState = context.read<AppState>();
    if (appState.user != null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCompleted =
          prefs.getBool(UnifiedGuestTourOverlay.completedPrefKey) ??
              prefs.getBool(UnifiedGuestTourOverlay.legacyHomePrefKey) ??
              false;
      if (!hasCompleted && mounted) {
        // Wait briefly for layout and orientation to settle
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (mounted &&
            context.read<AppState>().user == null &&
            ModalRoute.of(context)?.isCurrent != false) {
          setState(() => _showGuideTour = true);
        }
      }
    } catch (_) {}
  }

  void _startGuideTour() {
    setState(() => _showGuideTour = true);
  }

  Future<void> _completeGuideTour() async {
    setState(() => _showGuideTour = false);
    await _persistGuideCompletion();
  }

  Future<void> _persistGuideCompletion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(UnifiedGuestTourOverlay.completedPrefKey, true);
      await prefs.setBool(UnifiedGuestTourOverlay.legacyHomePrefKey, true);
    } catch (_) {}
  }

  @override
  void didPopNext() {
    if (mounted) {
      unawaited(context.read<NativeBridgeService>().playLobbyMusic());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncIdleAnimation();
    if (state == AppLifecycleState.resumed) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
        unawaited(context.read<NativeBridgeService>().playLobbyMusic());
      }
    }
    if (context.read<AppState>().user == null) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshCampaignProgress());
      unawaited(_refreshLeaderboardRank());
      context.read<AppState>().loadCurrency();
      context.read<AppState>().refreshCommerce();
      context.read<AppState>().loadLevelData();
      context.read<AppState>().checkAndAwardXpForGames();
      _consumePendingRoomMatchResult();
      CampaignResultHandler.consumeAndHandlePendingCampaignResult(
        context: context,
      );
      _consumeNativeLaunchAction();
      _checkPendingReferral();
      _checkClipboardForIncomingInvite();
      final promo = context.read<CrossPromoService>();
      final uid = context.read<AppState>().currentUser?.uid;
      promo.checkInstallation();
      promo.checkRewardClaimed(uid: uid);
    }
  }

  void _checkAndShowLuckyWheel() {
    if (!mounted || _hasCheckedLuckyWheelThisLaunch) return;
    _hasCheckedLuckyWheelThisLaunch = true;

    // مهلة قصيرة لإتاحة استقرار الشاشة وسلاسة الانتقال
    final uid = context.read<AppState>().user?.uid;
    _luckyWheelTimer?.cancel();
    _luckyWheelTimer = Timer(const Duration(milliseconds: 800),
        () => unawaited(_showLuckyWheelWhenReady(uid)));
  }

  Future<void> _showLuckyWheelWhenReady(String? uid,
      [int waitCount = 0]) async {
    if (!mounted || context.read<AppState>().user?.uid != uid) return;
    final appState = context.read<AppState>();
    // انتظر تحميل حالة اللفة اليومية قبل عرض الدولاب.
    if (!appState.dailyStreakLoaded && waitCount < 15) {
      _luckyWheelTimer = Timer(const Duration(milliseconds: 200),
          () => unawaited(_showLuckyWheelWhenReady(uid, waitCount + 1)));
      return;
    }
    if (!mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        _checkingReferral) {
      return;
    }

    // يُعرض الدولاب بعد تحميل الحالة ولحساب مسجل ومتصل فقط.
    if (!appState.dailyStreakLoaded ||
        !appState.isOnline ||
        appState.user == null) {
      if (mounted) {
        _checkAndShowSpecialOffer();
      }
      return;
    }

    // افتح الدولاب عندما تكون اللفة المجانية لهذا اليوم متاحة.
    final shouldShow = !appState.claimedToday;

    if (shouldShow && mounted) {
      await DailyRewardDialog.show(context);
    }

    // بعد إغلاق دولاب الحظ يتم التحقق من العرض الخاص.
    // لضمان عدم ظهور نافذتين فوق بعضهما مطلقاً
    if (mounted) {
      _checkAndShowSpecialOffer();
    }
  }

  Future<void> _checkAndShowSpecialOffer() async {
    if (!mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        _checkingReferral) {
      return;
    }
    final appState = context.read<AppState>();
    if (appState.user == null || appState.isVip) return;
    final shouldShow =
        await SpecialOfferDialog.shouldShowAuto(isVip: appState.isVip);
    if (shouldShow && mounted && appState.user != null && !appState.isVip) {
      await SpecialOfferDialog.show(context);
    }
  }

  Future<void> _checkClipboardForIncomingInvite() async {
    if (!mounted || context.read<AppState>().user == null) return;
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
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => IncomingInviteDialog(
        candidate: candidate,
        onDismiss: () {
          Navigator.of(ctx).pop();
          final inviteService = context.read<InviteService>();
          inviteService.dismissInviteCode(candidate.code);
          inviteService.dismissInviteCode(candidate.rawText);
        },
        onAccept: () async {
          Navigator.of(ctx).pop();
          final inviteService = context.read<InviteService>();
          await inviteService.dismissInviteCode(candidate.code);
          await inviteService.dismissInviteCode(candidate.rawText);

          if (!mounted) return;

          if (candidate.type == InviteType.friendChallenge) {
            FriendChallengeModal.show(
              context,
              initialFriendCode: candidate.code,
            );
          } else {
            final userId = context.read<AppState>().user?.uid;
            if (userId != null) {
              try {
                if (!await OnlineMatchFlow.prepare(context, userId,
                    roomId: candidate.code)) {
                  return;
                }
                if (!mounted) return;
                final joinResult = await context.read<RoomService>().joinRoom(
                      roomId: candidate.code,
                      userId: userId,
                    );
                if (!mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RoomLobbyScreen(
                      roomId: candidate.code,
                      isJoiningMidGame: joinResult.joinedMidGame,
                    ),
                  ),
                );
                return;
              } catch (_) {}
            }
            if (!mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RoomsScreen(initialRoomCode: candidate.code),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _consumeNativeLaunchAction() async {
    if (_handlingNativeLaunchAction ||
        !mounted ||
        context.read<AppState>().user == null) {
      return;
    }
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

  Future<void> _checkPendingReferral() async {
    if (!mounted || _checkingReferral) return;
    final app = context.read<AppState>();
    final uid = app.user?.uid;
    if (uid == null || !app.isOnline) return;
    _checkingReferral = true;
    try {
      final pending = await const ReferralService().pending();
      final code =
          ReferralService.extractCode(pending['code'] as String? ?? '');
      if (!mounted ||
          context.read<AppState>().user?.uid != uid ||
          code.isEmpty ||
          _shownReferral == '$uid:$code') {
        return;
      }
      // Keep the code pending when another route or dialog is in front.
      if (ModalRoute.of(context)?.isCurrent != true) return;
      _shownReferral = '$uid:$code';
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => InviteFriendsPage(initialCode: code)));
    } catch (_) {
      // Offline/older native builds retain the manual code entry path.
    } finally {
      _checkingReferral = false;
    }
  }

  Future<void> _openCampaignMap() async {
    final nativeBridgeService = context.read<NativeBridgeService>();
    try {
      await nativeBridgeService.stopLobbyMusic();
      await nativeBridgeService.playCampaignMapMusic();
    } catch (_) {}
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: CampaignMapScreen.routeName),
        builder: (_) => const CampaignMapScreen(),
      ),
    );
    if (mounted) {
      await _refreshCampaignProgress();
      await nativeBridgeService.playLobbyMusic();
    }
  }

  Future<void> _openLeaderboard() async {
    if (!context.read<AppState>().isOnline) {
      _showOnlineRequiredToast(context);
      return;
    }
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => LeaderboardScreen(service: _rankService)));
    if (mounted) await _refreshLeaderboardRank();
  }

  Future<void> _consumePendingRoomMatchResult() async {
    if (_syncingPendingRoomMatchResult) return;
    final userId = context.read<AppState>().user?.uid;
    if (userId == null) return;
    final nativeBridgeService = context.read<NativeBridgeService>();

    _syncingPendingRoomMatchResult = true;
    try {
      final payload = await nativeBridgeService.getPendingRoomMatchResult();
      if (payload == null) return;
      if (!mounted) return;
      final roomService = context.read<RoomService>();

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
    campaignRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_campaignProgressSubscription?.cancel());
    unawaited(_leaderboardRankSubscription?.cancel());
    _observedAppState?.removeListener(_onAppStateChanged);
    _clipboardTimer?.cancel();
    _luckyWheelTimer?.cancel();
    if (PerformanceProbe.enabled) {
      PerformanceProbe.idle.removeListener(_syncIdleAnimation);
    }
    _idleTimer?.cancel();
    _idleProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Identity changes affect the layout/tour; balances and progress subscribe
    // inside their own widgets so an unrelated update keeps the scene intact.
    context.select<AppState, (String?, String?, String?, String?)>((app) => (
          app.user?.uid,
          app.user?.displayName,
          app.user?.email,
          app.user?.photoURL,
        ));
    final appState = context.read<AppState>();
    final user = appState.user;
    final username =
        (user?.displayName ?? user?.email?.split('@').first ?? 'لاعب').trim();
    final displayUsername =
        username.isEmpty || username.contains('Ã') ? 'لاعب' : username;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: HomeBackground(
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

              // â”€â”€ CENTER arena â€” full screen width so content is truly centred â”€â”€
              Positioned.fill(
                child: SafeArea(
                  left: false,
                  child: _HomeLobbyLayout(
                    appState: appState,
                    username: displayUsername,
                    user: user,
                    idleCtrl: _idleAnimation,
                    campaignProgress: _campaignProgress,
                    leaderboardRank: _leaderboardRank,
                    onLeaderboardTap: () => unawaited(_openLeaderboard()),
                    onCampaignTap: () => unawaited(_openCampaignMap()),
                    guideTargets: _guideTargets,
                    showGuideTour: _showGuideTour,
                    onStartGuideTour: _startGuideTour,
                    onCompleteGuideTour: _completeGuideTour,
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
  GameNoticeMessenger.of(context)
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
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (sheetContext) => _GameModesSheet(rootContext: context),
  );
}

class _GameModesSheet extends StatefulWidget {
  const _GameModesSheet({required this.rootContext});

  final BuildContext rootContext;

  @override
  State<_GameModesSheet> createState() => _GameModesSheetState();
}

class _GameModesSheetState extends State<_GameModesSheet> {
  final _guideKey = GlobalKey<PageGuideState>();
  final _guideTargets = {
    for (final target in ModeGuideTarget.values) target: GlobalKey(),
  };
  bool _guiding = false;
  BuildContext get rootContext => widget.rootContext;

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
    context.select<AppState, bool>((app) => app.isOnline);
    final appState = context.read<AppState>();
    final media = MediaQuery.of(context);
    var width = math.min(
        900.0,
        math.min(
            media.size.width - media.padding.horizontal - 24,
            (media.size.height - media.padding.vertical - 24) *
                GameModesArtwork.aspectRatio));
    final landscape = media.size.width > media.size.height;
    if (_guiding) {
      width = math.min(
          width,
          landscape
              ? media.size.width * .5
              : media.size.height * .4 * GameModesArtwork.aspectRatio);
    }
    return PageGuide(
      key: _guideKey,
      id: 'modes',
      steps: buildModeGuideSteps(_guideTargets),
      completionLabel: 'اختر طريقة اللعب',
      onStart: () => setState(() => _guiding = true),
      onFinish: () => setState(() => _guiding = false),
      child: Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(12),
        alignment: _guiding
            ? (landscape ? Alignment.centerRight : Alignment.topCenter)
            : Alignment.center,
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: SizedBox(
            width: width,
            child: Stack(children: [
              GameModesArtwork(
                guideTargets: _guideTargets,
                isOnline: appState.isOnline,
                onClose: () => Navigator.of(context).pop(),
                onMainChallenge: () => _runMode(context,
                    () => rootContext.read<AppState>().openMainChallenge()),
                onGroupChallenge: () => _openOnlineRoute(
                    context, const RoomsScreen(), appState.isOnline),
                onFriendChallenge: () => _openOnlineRoute(
                    context, const SocialScreen(), appState.isOnline),
                onOffline: () => _runMode(context,
                    () => rootContext.read<AppState>().openOfflineGame()),
                onUnavailable: () => _runMode(
                    context, () => _showOnlineRequiredToast(rootContext)),
              ),
            ]),
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
    if (widget.appState.user == null) return;
    try {
      final data = await context.read<NativeBridgeService>().getAchievements();
      if (!mounted) return;
      final count = (data['unclaimedAchievements'] as num?)?.toInt() ?? 0;
      if (_pendingRewards != count) setState(() => _pendingRewards = count);
    } catch (_) {
      if (!mounted) return;
      if (_pendingRewards != 0) setState(() => _pendingRewards = 0);
    }
  }

  Future<void> _openMenu() async {
    AppSettings.playClick();
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
    final hasDailyReward = context.select<AppState, bool>((app) =>
        app.isOnline &&
        app.dailyStreakLoaded &&
        app.streakDay > 0 &&
        (!app.claimedToday || app.isLuckyWheelFreeAvailable));
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
                child: adaptiveAssetImage(HomeArtwork.menu,
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
    final menu = context.select<AppState, (bool, int, bool, String?)>((app) => (
          app.isOnline,
          app.level,
          app.isOnline &&
              app.dailyStreakLoaded &&
              app.streakDay > 0 &&
              (!app.claimedToday || app.isLuckyWheelFreeAvailable),
          app.currentUser?.uid,
        ));
    final liveState = context.read<AppState>();
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.padding.vertical - 24;
    final width = math.min(
        1000.0,
        math.min(media.size.width - media.padding.horizontal - 24,
            availableHeight * HomeMenuArtwork.aspectRatio));
    final dailyReady = menu.$3;
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
              future: RateGameService.instance.shouldShowRatingEntry(
                uid: user?.uid ?? liveState.currentUser?.uid,
              ),
              builder: (context, snapshot) {
                if (snapshot.data != true) return const SizedBox.shrink();
                return Tooltip(
                  message:
                      'شاركنا رأيك وادعمنا للحصول على 500 كوين + 10 جواهر 🎁',
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      RateGameService.instance.showRateDialog(
                        rootContext,
                        isManual: true,
                        uid: user?.uid ?? liveState.currentUser?.uid,
                      );
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
    required this.campaignProgress,
    required this.leaderboardRank,
    required this.onLeaderboardTap,
    required this.onCampaignTap,
    required this.guideTargets,
    required this.showGuideTour,
    required this.onStartGuideTour,
    required this.onCompleteGuideTour,
  });
  final AppState appState;
  final String username;
  final dynamic user;
  final Animation<double> idleCtrl;
  final CampaignHomeProgress? campaignProgress;
  final int? leaderboardRank;
  final VoidCallback onLeaderboardTap;
  final VoidCallback onCampaignTap;
  final Map<HomeGuideTarget, GlobalKey> guideTargets;
  final bool showGuideTour;
  final VoidCallback onStartGuideTour;
  final VoidCallback onCompleteGuideTour;

  void _openOnlineScreen(BuildContext context, Widget screen) {
    context.read<AppSettings?>()?.playButtonClick();
    if (!appState.isOnline) {
      _showOnlineRequiredToast(context);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    context.select<AppState, bool>((app) => app.isOnline);
    return LayoutBuilder(builder: (context, area) {
      // The background reaches the edge; every control clears the cutout.
      final safeLeft = MediaQuery.paddingOf(context).left;
      final width = area.maxWidth - safeLeft;
      final height = area.maxHeight;
      final portrait = height > width;
      final headerHeight = portrait ? 108.0 : 64.0;
      final panelHeight = portrait
          ? (height * .47).clamp(274.0, 480.0)
          : math.min(500.0, math.min(height * .80, height - headerHeight - 16));
      final panelWidth = math.min(
          portrait ? width - 32 : (width * .29).clamp(180.0, 340.0),
          panelHeight * .64);
      final panelTop = portrait ? height - panelHeight - 16 : headerHeight + 8;
      final heroLeftInset = portrait ? 64.0 : 76.0;
      final heroLeft = heroLeftInset + safeLeft;
      final heroWidth =
          portrait ? width - 80 : width - panelWidth - heroLeftInset - 40;
      // Leave room for the full-size presenter while explaining the contestant.
      final heroBottom = portrait
          ? math.min(panelTop - 10, showGuideTour ? height * .43 : height)
          : height - 16;
      final characterTop = headerHeight + 62;
      final characterHeight = math.max(1.0, heroBottom - characterTop);
      final maxWalletWidth =
          portrait ? width - 28 : (width - 100).clamp(280.0, 520.0);
      final balanceWidth = (maxWalletWidth - 12) / 4;
      const walletGap = 2.0;
      const resourceScale = .9;
      final keysWidth = math.min(balanceWidth, 44 * 1608 / 872) * resourceScale;
      final ticketsWidth =
          math.min(balanceWidth, 44 * 1616 / 884) * resourceScale;
      final walletWidth =
          balanceWidth * 2 + keysWidth + ticketsWidth + walletGap * 3;
      return Stack(children: [
        Positioned(
            key: guideTargets[HomeGuideTarget.menu],
            top: 6,
            left: safeLeft + 6,
            child: SignInRequiredAction(
                child: _HomeMenuButton(
                    appState: appState, username: username, user: user))),
        Positioned(
            top: portrait ? 60 : 8,
            right: portrait ? (width - walletWidth) / 2 : 16,
            width: walletWidth,
            height: 44,
            child: Builder(builder: (context) {
              context.select<AppState, (int, int, bool, int, int)>((app) => (
                    app.coins,
                    app.gems,
                    app.economyLoaded,
                    app.economyLoaded ? app.economyWallet.totalKeys : 0,
                    app.economyLoaded ? app.economyWallet.tickets : 0,
                  ));
              return SignInRequiredAction(
                  child: KeyedSubtree(
                      child: Row(textDirection: TextDirection.ltr, children: [
                for (final gems in [false, true]) ...[
                  if (gems) const SizedBox(width: walletGap),
                  SizedBox(
                      key: guideTargets[
                          gems ? HomeGuideTarget.gems : HomeGuideTarget.coins],
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
                    key: guideTargets[HomeGuideTarget.keys],
                    width: keysWidth,
                    child: HomeResourceArtwork(
                        key: const ValueKey('home-keys-balance'),
                        tickets: false,
                        value: appState.economyLoaded
                            ? '${appState.economyWallet.totalKeys}'
                            : user == null
                                ? '0'
                                : '…',
                        enabled: appState.isOnline,
                        onPressed: () => _openOnlineScreen(
                            context,
                            const StoreScreen(
                                initialKind: StoreProductKind.resource)))),
                const SizedBox(width: walletGap),
                SizedBox(
                    key: guideTargets[HomeGuideTarget.tickets],
                    width: ticketsWidth,
                    child: HomeResourceArtwork(
                        key: const ValueKey('home-tickets-balance'),
                        tickets: true,
                        value: appState.economyLoaded
                            ? '${appState.economyWallet.tickets}'
                            : user == null
                                ? '0'
                                : '…',
                        enabled: appState.isOnline,
                        onPressed: () => _openOnlineScreen(
                            context,
                            const StoreScreen(
                                initialKind: StoreProductKind.resource)))),
              ])));
            })),
        Positioned(
            top: headerHeight + 2,
            left: heroLeft,
            width: heroWidth,
            height: 56,
            child: Center(
                child: KeyedSubtree(
                    key: guideTargets[HomeGuideTarget.level],
                    child: _LevelBadge(appState: appState)))),
        Positioned(
            top: characterTop,
            left: heroLeft,
            width: heroWidth,
            height: characterHeight,
            child: SignInRequiredAction(
                child: Center(
              child: AspectRatio(
                  aspectRatio: 720 / 1280,
                  child: KeyedSubtree(
                      key: guideTargets[HomeGuideTarget.character],
                      child: Builder(builder: (context) {
                        context.select<AppState, int>(
                            (app) => app.selectedCharacter.index);
                        return HomeCharacterArtwork(
                            key: const ValueKey('home-selected-character'),
                            character: appState.selectedCharacter,
                            onTap: () {
                              AppSettings.playClick();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const CharacterSelectScreen(),
                                ),
                              );
                            });
                      }))),
            ))),
        Positioned(
            bottom: portrait ? height - heroBottom : 12,
            left: heroLeft,
            width: heroWidth,
            child: OnlineMatchRecoveryCard(userId: user?.uid ?? '')),
        Positioned(
            top: portrait ? headerHeight + 12 : 74,
            left: safeLeft + 6,
            child: KeyedSubtree(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              SignInRequiredAction(
                  key: guideTargets[HomeGuideTarget.store],
                  child: HomeQuickAction(
                      key: const ValueKey('home-store-shortcut'),
                      asset: HomeArtwork.store,
                      label: 'المتجر',
                      icon: Icons.shopping_basket_rounded,
                      color: const Color(0xFFFFD761),
                      animation: idleCtrl,
                      animationPhase: math.pi / 3,
                      isAvailable: appState.isOnline,
                      onPressed: () =>
                          _openOnlineScreen(context, const StoreScreen()))),
              const SizedBox(height: 12),
              SignInRequiredAction(
                  key: guideTargets[HomeGuideTarget.support],
                  child: HomeQuickAction(
                      key: const ValueKey('home-help-shortcut'),
                      asset: HomeArtwork.help,
                      label: 'تواصل معنا',
                      icon: Icons.question_mark_rounded,
                      color: const Color(0xFFFFD761),
                      animation: idleCtrl,
                      animationPhase: math.pi * 2 / 3,
                      onPressed: () => showSupportContact(context))),
            ]))),
        Positioned(
            key: const ValueKey('home-actions-panel'),
            top: panelTop,
            right: 16,
            width: panelWidth,
            height: panelHeight,
            child: Builder(builder: (context) {
              context.select<AppState, (int, bool)>(
                  (app) => (app.trophies, app.isVip));
              return HomeActionSidebar(
                animation: idleCtrl,
                leaderboardRank: leaderboardRank,
                campaignProgress: campaignProgress,
                trophies: appState.trophies,
                isOnline: appState.isOnline,
                isVip: appState.isVip,
                guideTargets: guideTargets,
                rotatePromotions: !showGuideTour,
                onLeaderboard: onLeaderboardTap,
                onCampaign: () {
                  if (appState.isOnline) {
                    onCampaignTap();
                  } else {
                    _showOnlineRequiredToast(context);
                  }
                },
                onVip: () => appState.isVip
                    ? _openOnlineScreen(
                        context,
                        const StoreScreen(
                            initialKind: StoreProductKind.subscription))
                    : SpecialOfferDialog.show(context),
                onLuckyWheel: () =>
                    _openOnlineScreen(context, const DailyStreakScreen()),
                onModes: () => _showGameModesSheet(context),
                onFriends: () =>
                    _openOnlineScreen(context, const InviteFriendsPage()),
                onPlay: () {
                  HapticFeedback.lightImpact();
                  if (!appState.isOnline) {
                    _showOnlineRequiredToast(context);
                    return;
                  }
                  PlayStakeDialog.show(context);
                },
              );
            })),

        // Persistent Guide Button for unregistered players
        if (user == null)
          Positioned(
            bottom: portrait ? 16 : 10,
            left: safeLeft + (portrait ? 16 : 12),
            child: PersistentGuideButton(
              key: guideTargets[HomeGuideTarget.guide],
              onRestartTour: onStartGuideTour,
            ),
          ),

        // Unified Guided Onboarding Tour Overlay for Guests
        if (showGuideTour)
          Positioned.fill(
            child: UnifiedGuestTourOverlay(
              rootContext: context,
              homeTargets: guideTargets,
              onComplete: onCompleteGuideTour,
              onSkip: onCompleteGuideTour,
            ),
          ),
      ]);
    });
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    context.select<AppState, (int, int, int)>(
        (app) => (app.level, app.xpInCurrentLevel, app.xpNeededForLevel));
    return HomeLevelBadge(
      key: const ValueKey('home-level-badge'),
      level: appState.level,
      xp: appState.xpInCurrentLevel,
      requiredXp: appState.xpNeededForLevel,
    );
  }
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
