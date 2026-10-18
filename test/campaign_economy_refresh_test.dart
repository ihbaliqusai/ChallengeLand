import 'package:challenge_land/core/app_state.dart';
import 'package:challenge_land/models/stage_attempt.dart';
import 'package:challenge_land/models/stage_progress.dart';
import 'package:challenge_land/services/campaign_result_handler.dart';
import 'package:challenge_land/services/campaign_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Wallet extends ChangeNotifier implements AppState {
  User account = _User('host');
  @override
  User get currentUser => account;
  int refreshes = 0;
  Future<void> Function()? refresh;
  @override
  Future<void> loadEconomy() async {
    refreshes++;
    await refresh?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LegacyWallet extends ChangeNotifier implements AppState {
  @override
  User get currentUser => _User('host');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Campaign implements CampaignService {
  int claimReads = 0;
  @override
  Future<CampaignRewardClaim?> loadRewardClaim(
      {required String uid, required String claimId}) async {
    claimReads++;
    return CampaignRewardClaim(
        claimId: claimId,
        uid: uid,
        campaignId: 'main_campaign',
        stageId: 'stage_050',
        previousStars: 0,
        newStars: 3,
        coins: 100,
        gems: 1,
        xp: 50,
        status: 'claimed',
        attemptId: 'attempt',
        currencyClaimed: true,
        xpClaimed: true,
        retryCount: 0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StageSubmissionResult _result({String? claimId}) => StageSubmissionResult(
    attempt: StageAttempt.fromMap({
      'uid': 'host',
      'stageId': 'stage_050',
      'attemptId': 'attempt',
      'completed': true,
      'stars': 3,
    }),
    updatedProgress: StageProgress.empty().copyWith(
        stageId: 'stage_050', stars: 3, status: StageProgressStatus.completed),
    previousStars: 0,
    newStars: 3,
    isFirstCompletion: true,
    improvedBestScore: true,
    improvedStars: true,
    leaderboardUpdated: true,
    rewardGranted: claimId != null,
    rewardCoinsGranted: 100,
    rewardGemsGranted: 1,
    rewardXpGranted: 50,
    rewardClaimId: claimId,
    motivationalMessage: '');

void main() {
  test(
      'saved milestone refreshes resources even without another currency claim',
      () async {
    final wallet = _Wallet();
    final campaign = _Campaign();
    final applied = await CampaignResultHandler.applySubmissionReward(
        appState: wallet, campaignService: campaign, result: _result());
    expect(wallet.refreshes, 1);
    expect(campaign.claimReads, 0);
    expect(applied, isFalse);
    wallet.dispose();
  });

  test('wallet service failure does not erase an already saved reward receipt',
      () async {
    final wallet = _Wallet()..refresh = () async => throw StateError('Offline');
    final campaign = _Campaign();
    final applied = await CampaignResultHandler.applySubmissionReward(
        appState: wallet,
        campaignService: campaign,
        result: _result(claimId: 'currency-claim'));
    expect(applied, isTrue);
    expect(wallet.refreshes, 1);
    expect(campaign.claimReads, 1);
    wallet.dispose();
  });

  test('a different active account does not refresh or deliver the old result',
      () async {
    final wallet = _Wallet()..account = _User('other');
    final campaign = _Campaign();
    final applied = await CampaignResultHandler.applySubmissionReward(
        appState: wallet,
        campaignService: campaign,
        result: _result(claimId: 'currency-claim'));
    expect(applied, isFalse);
    expect(wallet.refreshes, 0);
    expect(campaign.claimReads, 0);
    wallet.dispose();
  });

  test('switching accounts during a wallet refresh stops reward delivery',
      () async {
    final wallet = _Wallet();
    wallet.refresh = () async => wallet.account = _User('other');
    final campaign = _Campaign();
    final applied = await CampaignResultHandler.applySubmissionReward(
        appState: wallet,
        campaignService: campaign,
        result: _result(claimId: 'currency-claim'));
    expect(applied, isFalse);
    expect(campaign.claimReads, 0);
    wallet.dispose();
  });

  test('existing account test doubles without wallet methods stay compatible',
      () async {
    final wallet = _LegacyWallet();
    final applied = await CampaignResultHandler.applySubmissionReward(
        appState: wallet, campaignService: _Campaign(), result: _result());
    expect(applied, isFalse);
    wallet.dispose();
  });
}
