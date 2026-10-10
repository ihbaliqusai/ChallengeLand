package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.content.SharedPreferences;
import android.os.Bundle;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

/** Exercises the production native ledger, rules, account store and cloud checkpoint. */
public final class NativeProgressionCheck {
    private static int assertions;

    public static void main(String[] args) {
        verifyAllModes();
        verifyCampaignCoinPolicy();
        verifyAnswerAndResultReceipts();
        verifyDrawsAbandonmentAndEmptyLobbies();
        verifyAccountIsolationAndMigration();
        verifyDynamicAccountLevel();
        verifyDiskFailureRetries();
        verifyCloudCheckpointAndHydration();
        verifyInstallationBackupIsolation();
        verifyPendingCampaignOwnership();
        verifyLevelBoundariesAndClaims();
        verifyAchievementReceiptRestore();
        verifyConcurrentAnswersAndResults();
        System.out.println("Native progression regression checks passed (" + assertions + " assertions)");
    }

    private static void verifyAchievementReceiptRestore() {
        VerificationContext device = new VerificationContext();
        device.switchAccount("receipt-owner");
        device.account().values.put("coins", 500);
        device.account().values.put("xp", 100);
        PlayerProgress.getUnclaimedAchievementCount(device); // Initialize legacy migration.
        java.util.List<String> ids = java.util.Arrays.asList(PlayerProgress.ACH_FIRST_GAME);
        check(PlayerProgress.hydrateAchievementClaims(device, "receipt-owner", ids, ids), "cloud receipts restored");
        check(PlayerProgress.isAchievementRewardClaimed(device, PlayerProgress.ACH_FIRST_GAME), "restored reward remains claimed");
        equal(PlayerProgress.getCoins(device), 500, "receipt restore never grants coins");
        equal(PlayerProgress.getXp(device), 100, "receipt restore never grants XP");
        check(PlayerProgress.hydrateAchievementClaims(device, "receipt-owner", java.util.Collections.emptyList(), java.util.Collections.emptyList()), "empty restore accepted");
        check(PlayerProgress.isAchievementRewardClaimed(device, PlayerProgress.ACH_FIRST_GAME), "stale restore cannot erase a claim");
        check(!PlayerProgress.claimAchievementReward(device, PlayerProgress.ACH_FIRST_GAME).success, "legacy endpoint cannot repay restored receipt");
        device.account().failNextCommit = true;
        java.util.List<String> next = java.util.Arrays.asList(PlayerProgress.ACH_FIRST_WIN);
        try {
            PlayerProgress.hydrateAchievementClaims(device, "receipt-owner", next, next);
            throw new AssertionError("receipt disk failure must be reported");
        } catch (IllegalStateException expected) {
            check(!PlayerProgress.isAchievementRewardClaimed(device, PlayerProgress.ACH_FIRST_WIN), "failed receipt rolled back");
        }
        check(PlayerProgress.hydrateAchievementClaims(device, "receipt-owner", next, next), "receipt retry succeeds");
        device.switchAccount("other-owner");
        check(!PlayerProgress.hydrateAchievementClaims(device, "receipt-owner", ids, ids), "wrong account rejected");
        check(!PlayerProgress.isAchievementRewardClaimed(device, PlayerProgress.ACH_FIRST_GAME), "claims do not cross accounts");
    }

    private static void verifyAllModes() {
        for (String mode : new String[]{"campaign", "offline", "local_teams", "board", "battle",
                "team_battle", "blitz", "elimination", "survival", "series"}) {
            VerificationContext device = new VerificationContext();
            boolean online = !mode.equals("campaign") && !mode.equals("offline")
                    && !mode.equals("local_teams") && !mode.equals("board");
            Match game = new Match(device, mode, mode, online, online);
            answer(game, "q1", true);
            answer(game, "q2", false);
            String outcome = mode.equals("local_teams") ? ProgressionRules.DRAW : ProgressionRules.WIN;
            PlayerStats.recordGameEnd(game, outcome, 1000);
            equal(PlayerStats.getGamesPlayed(game), 1, mode + " records one match");
            equal(PlayerStats.snapshot(game).get("mode_" + mode + "_games"), 1, mode + " mode stats");
            equal(PlayerStats.matchTrophies(game), mode.equals("local_teams") ? 6 : online ? 30 : 22,
                    mode + " trophy payout");
            equal(PlayerProgress.getXp(game), 13 + (mode.equals("local_teams") ? 40 : online ? 100 : 80),
                    mode + " answer and completion XP");
            equal(PlayerStats.matchXp(game), PlayerProgress.getXp(game), mode + " receipt XP");
            equal(PlayerStats.getWins(game), mode.equals("local_teams") ? 0 : 1, mode + " personal wins");
        }
        equal(ProgressionRules.trophyDelta(ProgressionRules.WIN, true, 8, 3, 9, 10), 37, "online streak and accuracy");
        equal(ProgressionRules.trophyDelta(ProgressionRules.WIN, false, 0, 0, 3, 4), 22, "accuracy bonus requires five answers");
        equal(ProgressionRules.trophyDelta(ProgressionRules.WIN, false, 8, Integer.MAX_VALUE, 4, 5), 35,
                "streak arithmetic does not overflow");
        equal(ProgressionRules.trophyDelta(ProgressionRules.LOSS, true, 7, 0, 0, 5), -10, "beginner loss protection");
        equal(ProgressionRules.trophyDelta(ProgressionRules.LOSS, true, 8, 0, 0, 5), -18, "regular loss");
    }

    private static void verifyCampaignCoinPolicy() {
        VerificationContext device = new VerificationContext();
        Match campaign = new Match(device, "campaign_coin_policy", "campaign", false, false);
        answer(campaign, "board:1:0", true); // Legacy board calls the default grantCoins overload.
        campaign.question = "classic:q1";
        PlayerStats.recordCorrectAnswer(campaign, false); // Classic campaign already opts out.
        answer(campaign, "board:1:1", false);
        equal(PlayerProgress.getCoins(campaign), 0, "campaign default overload cannot duplicate stage currency");
        equal(PlayerProgress.getXp(campaign), 23, "campaign still earns answer XP");
        equal(PlayerStats.getCorrectAnswers(campaign), 2, "campaign correct answers still tracked");
        equal(PlayerStats.getWrongAnswers(campaign), 1, "campaign wrong answers still tracked");
        PlayerStats.recordGameEnd(campaign, true, 1000);
        equal(PlayerStats.matchXp(campaign), 103, "campaign completion XP preserved without answer coins");
        equal(PlayerStats.matchTrophies(campaign), 22, "campaign trophies preserved without answer coins");
        equal(PlayerProgress.getCoins(campaign), 0, "campaign currency exclusively comes from stage payout");
    }

    private static void verifyAnswerAndResultReceipts() {
        VerificationContext device = new VerificationContext();
        Match game = new Match(device, "receipt", "offline", false, false);
        answer(game, "q1", true);
        answer(game, "q1", false); // The same question callback cannot change or reward its answer twice.
        equal(PlayerStats.getCorrectAnswers(game), 1, "answer receipt records correct once");
        equal(PlayerStats.getWrongAnswers(game), 0, "late wrong callback ignored");
        equal(PlayerProgress.getXp(game), 10, "answer XP deduplicated");
        equal(PlayerProgress.getCoins(game), 20, "answer coins deduplicated");
        Bundle saved = new Bundle();
        NativeProgression.save(game, saved);
        Match recreated = new Match(device, null, "offline", false, false);
        NativeProgression.restore(recreated, saved);
        equal(recreated.progressionMatchId(), game.progressionMatchId(), "recreation restores match identity");
        answer(recreated, "q1", true);
        answer(recreated, "q2", false);
        PlayerProgress.onGameFinished(recreated, true, 1000, 1, false, false);
        PlayerProgress.onGameFinished(game, false, 9999, 1, false, false);
        equal(PlayerStats.getGamesPlayed(game), 1, "result replay does not duplicate games");
        equal(PlayerStats.getWins(game), 1, "first committed outcome remains authoritative");
        equal(PlayerStats.getLastPrize(game), 1000, "replay cannot change prize");
        equal(PlayerProgress.getXp(game), 93, "completion XP granted once");
        equal(PlayerProgress.getCoins(game), 270, "completion currency granted once");
        answer(game, "q3", true);
        equal(PlayerStats.getCorrectAnswers(game), 1, "answers after match receipt ignored");
        Result result = new Result(device);
        NativeProgression.copyToResult(game, result.getIntent());
        NativeProgression.restore(result, null);
        PlayerStats.recordGameEnd(result, true, 0);
        equal(PlayerStats.getGamesPlayed(result), 1, "result activity uses carried receipt");
        equal(PlayerStats.matchXp(result), 93, "result activity reads same XP receipt");
        equal(PlayerStats.matchTrophies(result), 22, "result activity reads same trophy receipt");
        Match invalid = new Match(device, "", "offline", false, false);
        check(!invalid.progressionMatchId().isEmpty(), "blank match identity receives a stable UUID");
    }

    private static void verifyDrawsAbandonmentAndEmptyLobbies() {
        VerificationContext device = new VerificationContext();
        Match empty = new Match(device, "empty", "battle", true, true);
        PlayerStats.recordGameEnd(empty, ProgressionRules.WIN, 10000);
        PlayerProgress.onOnlineMatchFinished(empty, true, 0, "battle", true, "empty");
        equal(PlayerStats.getGamesPlayed(empty), 0, "empty lobby cannot inflate game stats");
        equal(PlayerProgress.getOnlineWins(empty), 0, "empty lobby cannot inflate online wins");
        equal(PlayerProgress.getXp(empty), 0, "empty lobby grants no XP");
        equal(PlayerProgress.getCoins(empty), 0, "empty lobby grants no completion coins");
        check(PlayerStats.matchOutcome(empty).isEmpty(), "empty result can be retried after actual gameplay");
        Match draw = new Match(device, "draw", "board", false, false);
        answer(draw, "cell:1:0:0", true);
        PlayerStats.recordGameEnd(draw, ProgressionRules.DRAW, 0);
        equal(PlayerStats.getDraws(draw), 1, "tie tracked as draw");
        equal(PlayerStats.getWins(draw), 0, "tie does not inflate wins");
        equal(PlayerStats.matchTrophies(draw), 0, "competitive draw preserves trophies");
        equal(PlayerStats.matchXp(draw), 50, "draw includes answer plus completion XP");
        device.account().edit().putInt("trophies", 5).commit();
        Match abandon = new Match(device, "leave", "battle", true, true);
        answer(abandon, "q1", true);
        PlayerStats.recordGameEnd(abandon, ProgressionRules.ABANDON, 0);
        PlayerProgress.onOnlineMatchFinished(abandon, true, 3, "battle", true, "leave");
        equal(PlayerStats.getAbandoned(abandon), 1, "mid-match leaving is tracked");
        equal(PlayerStats.getTrophies(abandon), 0, "trophies never become negative");
        equal(PlayerStats.matchTrophies(abandon), -5, "receipt reports actual bounded loss");
        equal(PlayerStats.getTrophiesLost(abandon), 5, "lost trophies tracks actual loss");
        equal(PlayerStats.matchXp(abandon), 10, "abandon preserves earned answer XP only");
        equal(PlayerProgress.getCoins(abandon), 40, "abandon grants no completion currency");
        equal(PlayerStats.getCurrentStreak(abandon), 0, "answer streak resets on match end");
    }

    private static void verifyAccountIsolationAndMigration() {
        VerificationContext device = new VerificationContext();
        device.namespace("PlayerProgress").edit().putInt("xp", 1234).putInt("coins", 77).commit();
        device.namespace("PlayerStats").edit().putInt("wins", 2).putInt("trophies", 44).commit();
        device.switchAccount("alice");
        equal(PlayerProgress.getXp(device), 1234, "first account imports legacy XP");
        equal(PlayerStats.getTrophies(device), 44, "legacy stats imported into same account");
        Map<String, Long> baseline = contributions(ProgressionSyncState.capture(device));
        equal(baseline.get("xp"), 0L, "legacy baseline is not a device contribution");
        Match game = new Match(device, "account_match", "offline", false, false);
        answer(game, "q1", true);
        device.switchAccount("bob");
        equal(PlayerProgress.getXp(device), 0, "other account starts with separate XP");
        equal(PlayerProgress.getCoins(device), 0, "other account has separate wallet");
        equal(PlayerStats.getTrophies(device), 0, "legacy snapshot imported once only");
        answer(game, "q2", true);
        PlayerStats.recordGameEnd(game, true, 0);
        equal(PlayerProgress.getXp(device), 0, "old activity cannot reward newly active account");
        check(!ProgressionSyncState.hydrate(device, "alice", numbers("xp", 9999), numbers()),
                "late cloud response cannot hydrate a different account");
        device.switchAccount("alice");
        equal(PlayerProgress.getXp(device), 1244, "returning account retains answer XP");
        answer(game, "q1", true);
        PlayerStats.recordGameEnd(game, true, 0);
        equal(PlayerProgress.getXp(device), 1324, "old receipt resumes without duplicate answer XP");
        device.switchAccount("bob");
        PlayerProgress.checkProgressionAchievements(device);
        check(!PlayerProgress.isAchievementUnlocked(device, PlayerProgress.ACH_LOCAL_TEAMS),
                "other account does not inherit device-local board history achievements");
        VerificationContext guestFirst = new VerificationContext();
        guestFirst.namespace("PlayerProgress").edit().putInt("xp", 500).commit();
        equal(PlayerProgress.getXp(guestFirst), 500, "guest can own old device snapshot");
        guestFirst.switchAccount("signed_in_later");
        equal(PlayerProgress.getXp(guestFirst), 0, "guest baseline is not copied to a later account");
    }

    private static void verifyDynamicAccountLevel() {
        VerificationContext device = new VerificationContext();
        AppPrefs.setUser(device, "alice", "alice", "", 99, 0);
        PlayerProgress.setXp(device, 720);
        equal(AppPrefs.getUserLevel(device), 5, "native level derives from account XP instead of cached user level");
        PlayerProgress.addXp(device, 320);
        equal(AppPrefs.getUserLevel(device), 6, "new native XP updates user level before Flutter hydration");
        AppPrefs.setUser(device, "bob", "bob", "", 6, 0);
        equal(AppPrefs.getUserLevel(device), 1, "new account cannot inherit previous account's cached level");
        PlayerProgress.addXp(device, 120);
        equal(AppPrefs.getUserLevel(device), 2, "second account level reflects its own XP");
        AppPrefs.setUser(device, "alice", "alice", "", 1, 0);
        equal(AppPrefs.getUserLevel(device), 6, "returning account restores its actual level despite stale cache");
    }

    private static void verifyDiskFailureRetries() {
        VerificationContext device = new VerificationContext();
        Match game = new Match(device, "failure", "offline", false, false);
        device.account().failNextCommit = true;
        expectFailure(() -> answer(game, "q1", true), "answer failure reports disk error");
        equal(PlayerProgress.getXp(game), 0, "failed answer rolls back XP");
        equal(PlayerProgress.getCoins(game), 0, "failed answer rolls back currency");
        equal(PlayerStats.getCorrectAnswers(game), 0, "failed answer rolls back statistics");
        answer(game, "q1", true);
        device.account().failNextCommit = true;
        expectFailure(() -> PlayerStats.recordGameEnd(game, true, 1000), "match failure reports disk error");
        check(PlayerStats.matchOutcome(game).isEmpty(), "failed match receipt remains retryable");
        equal(PlayerProgress.getXp(game), 10, "failed completion retains committed answer XP");
        PlayerProgress.onGameFinished(game, true, 1000, 1, false, false);
        equal(PlayerStats.getGamesPlayed(game), 1, "retry records one match");
        equal(PlayerProgress.getXp(game), 90, "retry awards completion XP once");
        VerificationContext migrationFailure = new VerificationContext();
        migrationFailure.namespace("ProgressionMigration").failNextCommit = true;
        expectFailure(() -> PlayerProgress.getXp(migrationFailure), "migration owner failure reports error");
        check(!migrationFailure.namespace("ProgressionMigration").contains("legacyOwner"),
                "failed migration claim rolls back owner");
        equal(PlayerProgress.getXp(migrationFailure), 0, "migration can retry");
    }

    private static void verifyCloudCheckpointAndHydration() {
        VerificationContext device = new VerificationContext();
        device.switchAccount("sync_account");
        device.account().edit().putInt("xp", 1000).putInt("trophies", 100).putInt("bestTrophies", 100).commit();
        String installation = (String) ProgressionSyncState.capture(device).get("deviceId");
        Match win = new Match(device, "sync_win", "battle", true, true);
        answer(win, "q1", true);
        PlayerStats.recordGameEnd(win, true, 0);
        Map<String, Long> sent = contributions(ProgressionSyncState.capture(device));
        equal(sent.get("xp"), 110L, "device contributes only new answer and match XP");
        equal(sent.get("trophies"), 30L, "device contributes new trophies");
        answer(new Match(device, "pending", "offline", false, false), "q1", false);
        check(ProgressionSyncState.hydrate(device, "sync_account",
                numbers("xp", 5110, "trophies", 600, "gamesPlayed", 10, "wins", 8, "bestTrophies", 600),
                new HashMap<String, Number>(sent)), "cloud hydration succeeds");
        equal(PlayerProgress.getXp(device), 5113, "unacknowledged answer survives cloud round trip");
        equal(PlayerStats.getTrophies(device), 600, "acknowledged trophies are not added twice");
        Map<String, Object> rebased = ProgressionSyncState.capture(device);
        equal(contributions(rebased).get("xp"), 113L, "cloud totals never become local contributions");
        equal(rebased.get("deviceId"), installation, "installation ID persists through hydrate");
        check(ProgressionSyncState.hydrate(device, "sync_account",
                numbers("xp", 5110, "trophies", 600), new HashMap<String, Number>(sent)), "same cloud response can retry");
        equal(PlayerProgress.getXp(device), 5113, "hydration retries preserve pending XP once");
        Match lost = new Match(device, "sync_loss", "battle", true, true);
        answer(lost, "q1", false);
        PlayerStats.recordGameEnd(lost, false, 0);
        Map<String, Long> loss = contributions(ProgressionSyncState.capture(device));
        equal(loss.get("trophies"), 12L, "negative trophy change remains in contribution ledger");
        check(ProgressionSyncState.hydrate(device, "sync_account", numbers("trophies", 600),
                numbers("trophies", 30)), "hydrate pending trophy loss");
        equal(PlayerStats.getTrophies(device), 582, "pending loss survives older cloud response");
        int xpBefore = PlayerProgress.getXp(device);
        // hydrate first captures, then commits totals + observed keys together.
        device.account().failOnCommit = device.account().commits + 2;
        expectFailure(() -> ProgressionSyncState.hydrate(device, "sync_account", numbers("xp", 100000), numbers()),
                "hydrate disk failure reports error");
        equal(PlayerProgress.getXp(device), xpBefore, "failed hydration restores previous XP");
        equal(contributions(ProgressionSyncState.capture(device)).get("xp"), loss.get("xp"),
                "failed hydration cannot turn cloud XP into local contributions");
        device.account().failNextCommit = true;
        expectFailure(() -> ProgressionSyncState.capture(device), "capture disk failure reports error");
        equal(ProgressionSyncState.capture(device).get("deviceId"), installation, "capture retry keeps durable ID");
    }

    private static void verifyInstallationBackupIsolation() {
        VerificationContext original = new VerificationContext();
        original.switchAccount("alice");
        PlayerProgress.setXp(original, 1000);
        original.account().edit().putInt("trophies", 100).commit();
        Map<String, Object> aliceInitial = ProgressionSyncState.capture(original);
        String aliceStream = (String) aliceInitial.get("deviceId");
        String installation = original.account().getString("sync_installationId", "");
        check(!installation.isEmpty(), "checkpoint bound to durable installation epoch");
        Match aliceMatch = new Match(original, "original_alice", "offline", false, false);
        answer(aliceMatch, "q1", true);
        PlayerStats.recordGameEnd(aliceMatch, true, 0);
        equal(contributions(ProgressionSyncState.capture(original)).get("xp"), 90L,
                "original installation tracks its own rewards");
        original.switchAccount("bob");
        PlayerProgress.setXp(original, 2200);
        String bobStream = (String) ProgressionSyncState.capture(original).get("deviceId");
        equal(original.account().getString("sync_installationId", ""), installation,
                "accounts on one installation share the no-backup epoch");
        original.switchAccount("alice");
        equal(ProgressionSyncState.capture(original).get("deviceId"), aliceStream,
                "account switch preserves the original account stream");

        VerificationContext restarted = new VerificationContext(original.getNoBackupFilesDir());
        restarted.restorePreferencesFrom(original);
        equal(ProgressionSyncState.capture(restarted).get("deviceId"), aliceStream,
                "same installation and restored preferences preserve its existing stream");
        restarted.switchAccount("bob");
        equal(ProgressionSyncState.capture(restarted).get("deviceId"), bobStream,
                "same installation preserves the other account's existing stream");

        VerificationContext transferred = new VerificationContext();
        transferred.restorePreferencesFrom(original); // Android transfers prefs, but not no-backup files.
        equal(PlayerProgress.getXp(transferred), 1090, "transferred account keeps restored XP");
        Map<String, Object> aliceTransferred = ProgressionSyncState.capture(transferred);
        String newAliceStream = (String) aliceTransferred.get("deviceId");
        check(!aliceStream.equals(newAliceStream), "different installation cannot reuse restored stream ID");
        check(!installation.equals(transferred.account().getString("sync_installationId", "")),
                "transferred preferences rebound to the new no-backup epoch");
        equal(contributions(aliceTransferred).get("xp"), 0L, "transferred totals are a baseline, not replayed XP");
        equal(contributions(aliceTransferred).get("trophies"), 0L, "transferred trophies are not replayed");
        equal(PlayerProgress.getXp(transferred), 1090, "rebasing leaves player XP intact");
        equal(PlayerStats.getTrophies(transferred), 122, "rebasing leaves player trophies intact");
        equal(PlayerStats.getGamesPlayed(transferred), 1, "rebasing leaves player game statistics intact");
        equal(transferred.account().getLong("sync_observed_xp", -1L), 1090L,
                "new installation observes restored XP as its baseline");
        Match transferredMatch = new Match(transferred, "transferred_alice", "offline", false, false);
        answer(transferredMatch, "q1", true);
        PlayerStats.recordGameEnd(transferredMatch, true, 0);
        equal(contributions(ProgressionSyncState.capture(transferred)).get("xp"), 90L,
                "transferred installation contributes only gameplay after transfer");
        equal(contributions(ProgressionSyncState.capture(original)).get("xp"), 90L,
                "original installation contributions remain independent");
        equal(ProgressionSyncState.capture(original).get("deviceId"), aliceStream,
                "transferring another copy does not rotate original stream ID");
        transferred.switchAccount("bob");
        Map<String, Object> bobTransferred = ProgressionSyncState.capture(transferred);
        check(!bobStream.equals(bobTransferred.get("deviceId")), "other restored account also receives a new stream");
        equal(contributions(bobTransferred).get("xp"), 0L, "other restored account receives its own baseline");
        equal(PlayerProgress.getXp(transferred), 2200, "other restored account retains its XP");
        transferred.switchAccount("alice");
        equal(ProgressionSyncState.capture(transferred).get("deviceId"), newAliceStream,
                "new installation preserves its new account stream across switches");

        VerificationContext unbound = new VerificationContext();
        unbound.account().edit().putInt("xp", 1000).putString("sync_deviceId", "old-unbound-stream")
                .putBoolean("sync_initialized", true).putLong("sync_observed_xp", 900L)
                .putLong("sync_contribution_xp", 50L).commit();
        Map<String, Object> migrated = ProgressionSyncState.capture(unbound);
        check(!"old-unbound-stream".equals(migrated.get("deviceId")),
                "an unbound legacy checkpoint cannot prove its installation and rotates once");
        equal(contributions(migrated).get("xp"), 0L, "unbound checkpoint cannot replay old device contributions");
        equal(PlayerProgress.getXp(unbound), 1000, "unbound checkpoint migration preserves XP");
        equal(ProgressionSyncState.capture(unbound).get("deviceId"), migrated.get("deviceId"),
                "migration binds the new stream durably rather than rotating every capture");

        try {
            java.io.File epoch = new java.io.File(original.getNoBackupFilesDir(), "progression-installation-v1");
            java.nio.file.Files.write(epoch.toPath(), "invalid".getBytes(java.nio.charset.StandardCharsets.US_ASCII));
            expectFailure(() -> ProgressionSyncState.capture(original), "corrupt installation identity defers synchronization");
            equal(original.account().getString("sync_deviceId", ""), aliceStream,
                    "identity read failure never replaces the durable account stream");
            equal(original.account().getLong("sync_contribution_xp", -1L), 90L,
                    "identity read failure keeps checkpoint contributions intact");
            equal(new String(java.nio.file.Files.readAllBytes(epoch.toPath()), java.nio.charset.StandardCharsets.US_ASCII),
                    "invalid", "identity read failure does not overwrite a damaged file with a transient UUID");
            java.nio.file.Files.write(epoch.toPath(), installation.getBytes(java.nio.charset.StandardCharsets.US_ASCII));
            equal(ProgressionSyncState.capture(original).get("deviceId"), aliceStream,
                    "identity recovery resumes the original stream");
            VerificationContext unavailable = new VerificationContext(java.nio.file.Files.createTempFile(
                    "challengeland-unavailable-no-backup-", ".file").toFile());
            expectFailure(() -> ProgressionSyncState.capture(unavailable), "unavailable no-backup directory defers capture");
            check(!unavailable.account().contains("sync_deviceId"), "filesystem failure cannot create an ephemeral checkpoint");
        } catch (java.io.IOException failure) { throw new AssertionError(failure); }
    }

    private static void verifyPendingCampaignOwnership() {
        VerificationContext device = new VerificationContext();
        String alice = "{\"accountUid\":\"alice\",\"stageId\":\"stage_a\"}";
        String bob = "{\"accountUid\":\"bob\",\"stageId\":\"stage_b\"}";
        device.switchAccount("alice");
        AppPrefs.setPendingCampaignStageResult(device, alice);
        device.switchAccount("bob");
        equal(AppPrefs.getPendingCampaignStageResult(device), "", "another account cannot view pending campaign result");
        equal(AppPrefs.consumePendingCampaignStageResult(device), "", "another account cannot consume pending result");
        AppPrefs.clearPendingCampaignStageResult(device);
        AppPrefs.setPendingCampaignStageResult(device, bob);
        equal(AppPrefs.consumePendingCampaignStageResult(device), bob, "second account consumes its own pending result");
        equal(AppPrefs.consumePendingCampaignStageResult(device), "", "pending result consumed once");
        device.switchAccount("alice");
        equal(AppPrefs.consumePendingCampaignStageResult(device), alice, "original account result retained through switch");
        VerificationPreferences bridge = device.namespace(AppPrefs.PREF_ROOM);
        bridge.edit().putString("pending_campaign_stage_result", alice).commit();
        device.switchAccount("bob");
        equal(AppPrefs.getPendingCampaignStageResult(device), "", "legacy owned result hidden from wrong account");
        AppPrefs.clearPendingCampaignStageResult(device);
        check(bridge.contains("pending_campaign_stage_result"), "clear preserves legacy result owned by another account");
        equal(AppPrefs.consumePendingCampaignStageResult(device), "", "consume preserves mismatched legacy owner");
        device.switchAccount("alice");
        equal(AppPrefs.consumePendingCampaignStageResult(device), alice, "legacy owned result available to its owner");
        String legacy = "{\"stageId\":\"old_stage\"}";
        bridge.edit().putString("pending_campaign_stage_result", legacy).commit();
        equal(AppPrefs.consumePendingCampaignStageResult(device), legacy, "legacy result without owner remains compatible");
        bridge.failNextCommit = true;
        expectFailure(() -> AppPrefs.setPendingCampaignStageResult(device, alice), "pending result save disk failure");
        equal(AppPrefs.getPendingCampaignStageResult(device), "", "failed pending save remains retryable");
        AppPrefs.setPendingCampaignStageResult(device, alice);
        bridge.failNextCommit = true;
        expectFailure(() -> AppPrefs.consumePendingCampaignStageResult(device), "pending consume disk failure");
        equal(AppPrefs.getPendingCampaignStageResult(device), alice, "failed consume preserves pending payload");
        equal(AppPrefs.consumePendingCampaignStageResult(device), alice, "pending consume retry succeeds");
        try {
            AppPrefs.setPendingCampaignStageResult(device, bob);
            throw new AssertionError("pending writer cannot persist another account's result");
        } catch (IllegalArgumentException expected) { assertions++; }
    }

    private static void verifyLevelBoundariesAndClaims() {
        VerificationContext device = new VerificationContext();
        PlayerProgress.setXp(device, 119);
        equal(PlayerProgress.getLevel(device), 1, "one XP before first level threshold");
        PlayerProgress.addXp(device, 1);
        equal(PlayerProgress.getLevel(device), 2, "first level threshold");
        equal(PlayerProgress.getXpIntoLevel(device), 0, "XP bar resets at exact threshold");
        PlayerProgress.setXp(device, 720);
        equal(PlayerProgress.getLevel(device), 5, "rank threshold at level five");
        for (int level : new int[]{10, 20, 30, 45, 50, 60, 100}) {
            int xp = xpForLevel(level);
            PlayerProgress.setXp(device, xp - 1);
            equal(PlayerProgress.getLevel(device), level - 1, "level " + level + " lower boundary");
            PlayerProgress.addXp(device, 1);
            equal(PlayerProgress.getLevel(device), level, "level " + level + " exact boundary");
        }
        check(PlayerProgress.isAchievementUnlocked(device, PlayerProgress.ACH_LEVEL_50), "level fifty achievement unlocks");
        PlayerProgress.setXp(device, Integer.MAX_VALUE);
        PlayerProgress.addXp(device, 500);
        equal(PlayerProgress.getXp(device), Integer.MAX_VALUE, "XP saturates at native maximum");
        check(PlayerProgress.getXpIntoLevel(device) < PlayerProgress.getXpNeededForNextLevel(device), "XP bar bounded at cap");
        VerificationContext claims = new VerificationContext();
        PlayerProgress.unlockAchievement(claims, PlayerProgress.ACH_FIRST_GAME);
        claims.account().failNextCommit = true;
        expectFailure(() -> PlayerProgress.claimAchievementReward(claims, PlayerProgress.ACH_FIRST_GAME),
                "achievement disk failure reports error");
        check(!PlayerProgress.isAchievementRewardClaimed(claims, PlayerProgress.ACH_FIRST_GAME), "failed achievement claim retryable");
        equal(PlayerProgress.getXp(claims), 0, "failed achievement claim rolls back XP");
        equal(PlayerProgress.getCoins(claims), 0, "failed achievement claim rolls back wallet");
        check(PlayerProgress.claimAchievementReward(claims, PlayerProgress.ACH_FIRST_GAME).success, "achievement retry succeeds");
        check(!PlayerProgress.claimAchievementReward(claims, PlayerProgress.ACH_FIRST_GAME).success, "achievement cannot pay twice");
        equal(PlayerProgress.getXp(claims), 30, "achievement XP delivered once");
    }

    private static void verifyConcurrentAnswersAndResults() {
        VerificationContext device = new VerificationContext();
        Match game = new Match(device, "concurrent", "battle", true, true);
        game.question = "q1";
        AtomicInteger failures = new AtomicInteger();
        Thread[] callbacks = new Thread[8];
        for (int i = 0; i < callbacks.length; i++) {
            callbacks[i] = new Thread(() -> {
                try {
                    PlayerStats.recordCorrectAnswer(game);
                    PlayerStats.recordGameEnd(game, true, 0);
                    PlayerProgress.onOnlineMatchFinished(game, true, 1, "battle", true, "concurrent");
                } catch (Throwable failure) { failures.incrementAndGet(); }
            });
            callbacks[i].start();
        }
        for (Thread callback : callbacks) {
            try { callback.join(); } catch (InterruptedException failure) { throw new AssertionError(failure); }
        }
        equal(failures.get(), 0, "concurrent callbacks complete");
        equal(PlayerStats.getCorrectAnswers(game), 1, "concurrent answer callbacks deduplicated");
        equal(PlayerStats.getGamesPlayed(game), 1, "concurrent result callbacks deduplicated");
        equal(PlayerProgress.getXp(game), 110, "concurrent XP grants once");
        equal(PlayerProgress.getCoins(game), 220, "concurrent completion currency grants once");
    }

    private static int xpForLevel(int level) {
        // Independent explicit threshold schedule, matching the public rank specification.
        int total = 0;
        for (int current = 1; current < level; current++) {
            if (current < 5) total += 120 + (current - 1) * 40;
            else if (current < 10) total += 320 + (current - 5) * 55;
            else if (current < 20) total += 620 + (current - 10) * 80;
            else if (current < 30) total += 1450 + (current - 20) * 130;
            else if (current < 45) total += 2850 + (current - 30) * 210;
            else if (current < 60) total += 6000 + (current - 45) * 360;
            else total += 11500 + (current - 60) * 550;
        }
        return total;
    }

    private static void answer(Match game, String question, boolean correct) {
        game.question = question;
        if (correct) PlayerStats.recordCorrectAnswer(game);
        else PlayerStats.recordWrongAnswer(game);
    }
    @SuppressWarnings("unchecked")
    private static Map<String, Long> contributions(Map<String, Object> payload) {
        return (Map<String, Long>) payload.get("contributions");
    }
    private static Map<String, Number> numbers(Object... values) {
        Map<String, Number> result = new HashMap<>();
        for (int i = 0; i < values.length; i += 2) result.put((String) values[i], (Number) values[i + 1]);
        return result;
    }
    private static void expectFailure(Runnable action, String message) {
        try { action.run(); } catch (IllegalStateException expected) { assertions++; return; }
        throw new AssertionError(message);
    }
    private static void equal(Object actual, Object expected, String message) {
        check(expected.equals(actual), message + ": expected " + expected + ", got " + actual);
    }
    private static void check(boolean condition, String message) {
        assertions++;
        if (!condition) throw new AssertionError(message);
    }

    private static class Result extends Activity {
        final VerificationContext device;
        Result(VerificationContext device) { this.device = device; }
        @Override public SharedPreferences getSharedPreferences(String name, int mode) {
            return device.getSharedPreferences(name, mode);
        }
        @Override public java.io.File getNoBackupFilesDir() { return device.getNoBackupFilesDir(); }
    }
    private static final class Match extends Result implements ProgressionMatchHost {
        final String mode;
        final boolean online, human;
        volatile String question = "";
        Match(VerificationContext device, String id, String mode, boolean online, boolean human) {
            super(device);
            this.mode = mode; this.online = online; this.human = human;
            if (id != null) getIntent().putExtra("progressionMatchId", id);
            NativeProgression.restore(this, null);
        }
        @Override public String progressionMatchId() { return NativeProgression.fallbackId(this); }
        @Override public String progressionMode() { return mode; }
        @Override public String progressionAnswerId() { return question; }
        @Override public boolean progressionOnline() { return online; }
        @Override public boolean progressionHumanOpponents() { return human; }
    }
}
