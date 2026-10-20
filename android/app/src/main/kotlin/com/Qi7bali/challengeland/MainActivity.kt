package com.qi7bali.landchallengeonline

import android.Manifest
import android.content.Intent
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val campaignMapMusicVolume = 0.5f

    private var pendingLaunchAction: String? = null
    private var campaignMapMusicPlayer: MediaPlayer? = null
    private var playBillingManager: PlayBillingManager? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        VerifiedCommerceStore.invalidateWalletHydration(this)
        super.onCreate(savedInstanceState)
        DuelNotifications.initialize(this)
        PlayerPresence.initialize(application)
        handleIntentData(intent)
        syncDailyReminderSchedule()
    }

    override fun onResume() {
        super.onResume()
        DuelNotifications.resume(this)
        syncDailyReminderSchedule()
        GameEconomy.flush(this)
    }

    override fun onDestroy() {
        playBillingManager?.close()
        stopCampaignMapMusic()
        super.onDestroy()
    }

    override fun onPause() {
        stopCampaignMapMusic()
        super.onPause()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 7502 || requestCode == 7401) {
            DuelNotifications.sync(this)
            syncDailyReminderSchedule()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntentData(intent)
    }

    private fun handleIntentData(intent: Intent?) {
        val recipient = intent?.getStringExtra("duelRecipientUid")
        if (recipient != null && recipient != com.google.firebase.auth.FirebaseAuth.getInstance().currentUser?.uid) return
        val uri = intent?.data
        if (uri != null && uri.scheme == "challengeland") {
            val host = uri.host ?: uri.path.orEmpty()
            val code = uri.getQueryParameter("code") ?: uri.getQueryParameter("id") ?: ""
            if (host.contains("challenge") || host.contains("friend")) {
                if (code.isNotEmpty()) {
                    pendingLaunchAction = "challenge:$code"
                }
            } else if (host.contains("room")) {
                if (code.isNotEmpty()) {
                    pendingLaunchAction = "room:$code"
                }
            }
        }
        val rawAction = intent?.getStringExtra("launchAction")
        if (rawAction != null) {
            pendingLaunchAction = rawAction
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "challengeland/home-character",
            HomeCharacterViewFactory(this, flutterEngine.dartExecutor.binaryMessenger)
        )
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "millionaire/native")
        playBillingManager = PlayBillingManager(this, channel)
        channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "gameEconomy" -> {
                        val data = (call.arguments as? Map<*, *>)?.entries
                            ?.filter { it.key is String && it.value != null }
                            ?.associate { it.key as String to it.value!! } ?: emptyMap()
                        GameEconomy.request(this, data) { value, error ->
                            if (error != null) result.error("ECONOMY_FAILED", error, null)
                            else result.success(value)
                        }
                    }
                    "friendStakes" -> {
                        val data = (call.arguments as? Map<*, *>)?.entries
                            ?.filter { it.key is String && it.value != null }
                            ?.associate { it.key as String to it.value!! } ?: emptyMap()
                        com.google.firebase.functions.FirebaseFunctions.getInstance("us-central1")
                            .getHttpsCallable("friendStakes").call(data)
                            .addOnSuccessListener { response -> result.success(response.data) }
                            .addOnFailureListener { error ->
                                val callableError = error as? com.google.firebase.functions.FirebaseFunctionsException
                                result.error(callableError?.code?.name ?: "FRIEND_STAKES_FAILED",
                                    error.message, callableError?.details)
                            }
                    }
                    "preloadLocalQuestions" -> {
                        LocalQuestions.preload(applicationContext) { result.success(true) }
                    }
                    "launchOriginal" -> {
                        startActivity(Intent(this, LegacyMainActivity::class.java))
                        result.success(true)
                        finish()
                    }
                    "launchOfflineGame" -> {
                        startActivity(Intent(this, OfflineGamesActivity::class.java))
                        result.success(true)
                    }
                    "launchMainChallenge" -> {
                        // التحدي الرئيسي: لوحة  بين فريقين على جهاز واحد.
                        val intent = Intent(this, LocalTeamsGamesActivity::class.java)
                        intent.putExtra("mode", "mono")
                        intent.putExtra("localTeams", true)
                        intent.putExtra(
                            "characterIndex",
                            AppPrefs.getEffectiveCharacter(this@MainActivity)
                        )
                        startActivity(intent)
                        result.success(true)
                    }
                    "launchStats" -> {
                        startActivity(Intent(this, StatsActivity::class.java))
                        result.success(true)
                    }
                    "launchAchievements" -> {
                        startActivity(Intent(this, AchievementsActivity::class.java))
                        result.success(true)
                    }
                    "launchStore" -> {
                        startActivity(Intent(this, StoreActivity::class.java))
                        result.success(true)
                    }
                    "launchSettings" -> {
                        startActivity(Intent(this, SettingsActivity::class.java))
                        result.success(true)
                    }
                    "launchSpeedBattle" -> {
                        val matchMode = call.argument<String>("matchMode") ?: ""
                        val friendCode = call.argument<String>("friendCode") ?: ""
                        if (matchMode == "friend") {
                            PlayerProgress.recordFriendMatchPlayed(this)
                        } else {
                            PlayerProgress.recordRandomMatchPlayed(this)
                        }
                        val intent = Intent(this, OpponentActivity::class.java).apply {
                            if (matchMode.isNotBlank()) putExtra("matchMode", matchMode)
                            if (friendCode.isNotBlank()) putExtra("friendCode", friendCode)
                        }
                        startActivity(intent)
                        result.success(true)
                    }
                    "launchRandomMatch" -> {
                        PlayerProgress.recordRandomMatchPlayed(this)
                        val stakeCoins = (call.argument<Number>("stakeCoins"))?.toInt() ?: 0
                        val intent = Intent(this, OpponentActivity::class.java).apply {
                            putExtra("matchMode", "random")
                            if (stakeCoins > 0) {
                                putExtra("stakeCoins", stakeCoins)
                            }
                        }
                        startActivity(intent)
                        result.success(true)
                    }
                    "setSocialBusy" -> {
                        PlayerPresence.setFlutterBusy(call.argument<Boolean>("busy") == true)
                        result.success(null)
                    }
                    "getSocialServerTime" -> result.success(PlayerPresence.serverTime())
                    "launchFriendChallenge" -> {
                        PlayerProgress.recordFriendMatchPlayed(this)
                        val friendCode = call.argument<String>("friendCode") ?: ""
                        val stakeMatchId = call.argument<String>("stakeMatchId")?.trim().orEmpty()
                        val intent = Intent(this, OpponentActivity::class.java).apply {
                            putExtra("matchMode", "friend")
                            putExtra("friendCode", friendCode)
                            putExtra("socialAccepted", true)
                            if (stakeMatchId.isNotEmpty()) {
                                putExtra("stakeMatchId", stakeMatchId)
                                putExtra("stakeGameplayVersion", 2)
                            }
                        }
                        startActivity(intent)
                        result.success(true)
                    }
                    "playCampaignMapMusic" -> {
                        playCampaignMapMusic()
                        result.success(true)
                    }
                    "stopCampaignMapMusic" -> {
                        stopCampaignMapMusic()
                        result.success(true)
                    }
                    "getUserCurrency" -> {
                        val coins = AppPrefs.getCoins(this)
                        val gems  = AppPrefs.getGems(this)
                        result.success(mapOf("coins" to coins, "gems" to gems))
                    }
                    "consumeLaunchAction" -> {
                        val action = pendingLaunchAction
                        pendingLaunchAction = null
                        result.success(action)
                    }
                    "isAppInstalled" -> {
                        val targetPackage = call.argument<String>("packageName") ?: ""
                        val isInstalled = if (targetPackage.isNotBlank()) {
                            try {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                    packageManager.getPackageInfo(
                                        targetPackage,
                                        android.content.pm.PackageManager.PackageInfoFlags.of(0)
                                    )
                                } else {
                                    @Suppress("DEPRECATION")
                                    packageManager.getPackageInfo(targetPackage, 0)
                                }
                                true
                            } catch (e: Exception) {
                                false
                            }
                        } else {
                            false
                        }
                        result.success(isInstalled)
                    }
                    "launchAppOrPlayStore" -> {
                        val targetPackage = call.argument<String>("packageName") ?: ""
                        val fallbackUrl = call.argument<String>("playStoreUrl")
                            ?: "https://play.google.com/store/apps/details?id=$targetPackage"
                        if (targetPackage.isBlank()) {
                            result.error("APP_LAUNCH_FAILED", "No target package was provided", null)
                        } else {
                            // Every launch can fail (disabled app, missing store,
                            // unavailable browser). Keep trying the next destination
                            // and always complete the Flutter method call.
                            val appOpened = try {
                                val launchIntent = packageManager.getLaunchIntentForPackage(targetPackage)
                                if (launchIntent == null) false else {
                                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    startActivity(launchIntent)
                                    true
                                }
                            } catch (e: Exception) {
                                Log.w("CrossPromo", "Unable to launch target app", e)
                                false
                            }
                            val marketOpened = if (appOpened) false else try {
                                startActivity(Intent(Intent.ACTION_VIEW,
                                    Uri.parse("market://details?id=$targetPackage")).apply {
                                    setPackage("com.android.vending")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                })
                                true
                            } catch (e: Exception) {
                                Log.w("CrossPromo", "Unable to open Play Store", e)
                                false
                            }
                            val webOpened = if (appOpened || marketOpened) false else try {
                                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(fallbackUrl)).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                })
                                true
                            } catch (e: Exception) {
                                Log.w("CrossPromo", "Unable to open store website", e)
                                false
                            }
                            when {
                                appOpened -> result.success("launched_app")
                                marketOpened -> result.success("opened_market")
                                webOpened -> result.success("opened_web")
                                else -> result.error("APP_LAUNCH_FAILED", "No available app could open the game or store", null)
                            }
                        }
                    }
                    "openStoreRating" -> {
                        val targetPkg = call.argument<String>("packageName") ?: packageName
                        var opened = false
                        try {
                            val marketIntent = Intent(
                                Intent.ACTION_VIEW,
                                Uri.parse("market://details?id=$targetPkg")
                            ).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                                setPackage("com.android.vending")
                            }
                            startActivity(marketIntent)
                            opened = true
                            result.success("market_vending")
                        } catch (e: Exception) {
                            // Google Play app package not found or failed
                        }

                        if (!opened) {
                            try {
                                val genericMarket = Intent(
                                    Intent.ACTION_VIEW,
                                    Uri.parse("market://details?id=$targetPkg")
                                ).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(genericMarket)
                                opened = true
                                result.success("market_generic")
                            } catch (e2: Exception) {
                                // Generic market failed
                            }
                        }

                        if (!opened) {
                            try {
                                val webIntent = Intent(
                                    Intent.ACTION_VIEW,
                                    Uri.parse("https://play.google.com/store/apps/details?id=$targetPkg")
                                ).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(webIntent)
                                result.success("web_browser")
                            } catch (e3: Exception) {
                                result.error("OPEN_STORE_FAILED", e3.message, null)
                            }
                        }
                    }
                    "grantCurrency" -> {
                        val coins = call.argument<Int>("coins") ?: 0
                        val gems = call.argument<Int>("gems") ?: 0
                        val claimId = call.argument<String>("claimId")
                        try {
                            if (!claimId.isNullOrBlank()) {
                                val currentUid = com.google.firebase.auth.FirebaseAuth.getInstance().currentUser?.uid
                                check(!currentUid.isNullOrBlank() && claimId.startsWith("$currentUid:")) {
                                    "The reward account changed. Retry after signing in."
                                }
                                check(VerifiedCommerceStore.isWalletHydrated(this)) {
                                    "Your account wallet is syncing. Retry the reward after sync."
                                }
                            }
                            val granted = PlayerProgress.grantCurrencyOnce(this, claimId, coins, gems)
                            result.success(
                                mapOf(
                                    "coins" to PlayerProgress.getCoins(this),
                                    "gems" to PlayerProgress.getGems(this),
                                    "granted" to granted
                                )
                            )
                        } catch (e: Exception) {
                            result.error("CURRENCY_GRANT_FAILED", e.message, null)
                        }
                    }
                    "setUserCurrency" -> {
                        val coins = call.argument<Int>("coins") ?: 0
                        val gems = call.argument<Int>("gems") ?: 0
                        val expectedUid = call.argument<String>("expectedUid")
                        try {
                            if (!expectedUid.isNullOrBlank()) {
                                val currentUid = com.google.firebase.auth.FirebaseAuth.getInstance().currentUser?.uid
                                check(currentUid == expectedUid && VerifiedCommerceStore.isWalletHydrated(this)) {
                                    "The reward account changed or its wallet is syncing. Retry after signing in."
                                }
                            }
                            PlayerProgress.setCurrency(this, coins, gems)
                            result.success(
                                mapOf(
                                    "coins" to PlayerProgress.getCoins(this),
                                    "gems" to PlayerProgress.getGems(this)
                                )
                            )
                        } catch (e: Exception) {
                            result.error("CURRENCY_SET_FAILED", e.message, null)
                        }
                    }
                    "launchRoomMatch" -> {
                        val matchMode = call.argument<String>("matchMode") ?: "battle"
                        val activityClass = when (matchMode) {
                            "elimination" -> EliminationGameActivity::class.java
                            "blitz"       -> BlitzGameActivity::class.java
                            "survival"    -> SurvivalGameActivity::class.java
                            "series"      -> SeriesGameActivity::class.java
                            // The group challenge ("تحدي جماعي") now plays the التحدي board
                            // in GameActivity for both variants — competition (solo) and team —
                            // instead of the classic simultaneous-question engine.
                            "team_battle" -> GameActivity::class.java
                            "battle"      -> GameActivity::class.java
                            else          -> BattleGameActivity::class.java
                        }
                        val intent = Intent(this, activityClass).apply {
                            putExtra("roomId", call.argument<String>("roomId") ?: "")
                            putExtra("mode", "online")
                            putExtra("opponentsJson", call.argument<String>("opponentsJson") ?: "[]")
                            putExtra("meOwner", call.argument<Boolean>("meOwner") ?: false)
                            putExtra("matchMode", matchMode)
                            putExtra("seriesTarget", call.argument<Int>("seriesTarget") ?: 2)
                            putExtra("roundDurationSeconds", call.argument<Int>("roundDurationSeconds") ?: 30)
                            putExtra("myTeam", call.argument<String>("myTeam") ?: "")
                            putExtra("roomRoundNumber", call.argument<Int>("roomRoundNumber") ?: 1)
                            putExtra("economyMatchId", call.argument<String>("economyMatchId") ?: "")
                            putExtra("resumeExistingGame", call.argument<Boolean>("resumeExistingGame") ?: false)
                            putExtra("seatSourceId", call.argument<String>("seatSourceId") ?: "")
                            putExtra("initialScore", call.argument<Int>("initialScore") ?: 0)
                            putExtra("initialAnsweredCount", call.argument<Int>("initialAnsweredCount") ?: 0)
                            putExtra("initialRoundWins", call.argument<Int>("initialRoundWins") ?: 0)
                            putExtra("initialLivesRemaining", call.argument<Int>("initialLivesRemaining") ?: 0)
                            putExtra("initiallyEliminated", call.argument<Boolean>("initiallyEliminated") ?: false)
                            putExtra("characterIndex", AppPrefs.getEffectiveCharacter(this@MainActivity))
                        }
                        startActivity(intent)
                        result.success(true)
                    }
                    "launchCampaignStage" -> {
                        try {
                            stopCampaignMapMusic()
                            val stageId = stringArg(call.argument<Any>("stageId"), "")
                            val campaignMode = stringArg(call.argument<Any>("campaignMode"), "classic")
                            val winCondition = stringArg(call.argument<Any>("winCondition"), "completeQuestions")
                            Log.d(
                                "CampaignStage",
                                "CAMPAIGN_LAUNCH_CONFIG mode=$campaignMode winCondition=$winCondition stageId=$stageId"
                            )
                            val intent = Intent(this, GameActivity::class.java).apply {
                                putExtra("mode", "campaign")
                                putExtra("campaignId", stringArg(call.argument<Any>("campaignId"), "main_campaign"))
                                putExtra("stageId", stageId)
                                putExtra("stageType", stringArg(call.argument<Any>("stageType"), "classic"))
                                putExtra("campaignMode", campaignMode)
                                putExtra("winCondition", winCondition)
                                putIntegerArrayListExtra("questionIds", intArrayListArg(call.argument<Any>("questionIds")))
                                putStringArrayListExtra("allowedLevels", stringArrayListArg(call.argument<Any>("allowedLevels")))
                                putExtra("questionCount", intArg(call.argument<Any>("questionCount"), 10))
                                putExtra("timeLimitSeconds", intArg(call.argument<Any>("timeLimitSeconds"), 0))
                                putExtra("allow5050", boolArg(call.argument<Any>("allow5050"), true))
                                putExtra("allowAudience", boolArg(call.argument<Any>("allowAudience"), true))
                                putExtra("allowCall", boolArg(call.argument<Any>("allowCall"), true))
                                putExtra("bossBotName", stringArg(call.argument<Any>("bossBotName"), ""))
                                putExtra("bossBotIntelligence", intArg(call.argument<Any>("bossBotIntelligence"), 0))
                                putExtra("lives", intArg(call.argument<Any>("lives"), 0))
                                putExtra("maxWrongAnswers", intArg(call.argument<Any>("maxWrongAnswers"), 0))
                                putExtra("targetScore", intArg(call.argument<Any>("targetScore"), 0))
                                putExtra("opponentName", stringArg(call.argument<Any>("opponentName"), ""))
                                putExtra("opponentAccuracy", intArg(call.argument<Any>("opponentAccuracy"), 0))
                                putExtra("opponentStartScore", intArg(call.argument<Any>("opponentStartScore"), 0))
                                putExtra("seriesRounds", intArg(call.argument<Any>("seriesRounds"), 0))
                                putExtra("seriesWinsRequired", intArg(call.argument<Any>("seriesWinsRequired"), 0))
                                putExtra("teamAllyName", stringArg(call.argument<Any>("teamAllyName"), ""))
                                putExtra("teamEnemyName", stringArg(call.argument<Any>("teamEnemyName"), ""))
                                // تحدي المراحل — التحدي board stage params
                                putExtra("campaignBoard", boolArg(call.argument<Any>("campaignBoard"), false))
                                putExtra("boardKind", stringArg(call.argument<Any>("boardKind"), "solo"))
                                putExtra("boardTargetScore", intArg(call.argument<Any>("boardTargetScore"), 0))
                                putExtra("boardSoloPicks", intArg(call.argument<Any>("boardSoloPicks"), 6))
                                putExtra("boardSoloCols", intArg(call.argument<Any>("boardSoloCols"), 4))
                                putExtra("boardTwoStarScore", intArg(call.argument<Any>("boardTwoStarScore"), 0))
                                putExtra("boardThreeStarScore", intArg(call.argument<Any>("boardThreeStarScore"), 0))
                                putExtra("boardBotCount", intArg(call.argument<Any>("boardBotCount"), 0))
                                putExtra("boardBotIntelligence", intArg(call.argument<Any>("boardBotIntelligence"), 0))
                                putExtra("boardRequiredCategoryCount", intArg(call.argument<Any>("boardRequiredCategoryCount"), 0))
                                putExtra("bossStyle", stringArg(call.argument<Any>("bossStyle"), "balanced"))
                                putExtra("boardAllowRevealOptions", call.argument<Boolean>("boardAllowRevealOptions") ?: true)
                                putExtra("boardDesignVersion", intArg(call.argument<Any>("boardDesignVersion"), 0))
                                putExtra("categoryPolicy", stringArg(call.argument<Any>("categoryPolicy"), "playerPick"))
                                putStringArrayListExtra("worldCategories", stringArrayListArg(call.argument<Any>("worldCategories")))
                                // The player's chosen character is the single source of truth (set
                                // from the Flutter picker); ignore any stale value from the call args.
                                putExtra("characterIndex", AppPrefs.getEffectiveCharacter(this@MainActivity))
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("CAMPAIGN_LAUNCH_FAILED", e.message, null)
                        }
                    }
                    "announceRoomSeatClaim" -> {
                        Data.announceRoomSeatClaim(
                            call.argument<String>("roomId") ?: "",
                            call.argument<String>("matchMode") ?: "battle",
                            call.argument<Int>("roomRoundNumber") ?: 1,
                            call.argument<String>("seatId") ?: "",
                            call.argument<String>("userId") ?: "",
                            call.argument<String>("username") ?: "لاعب",
                            call.argument<String>("photoUrl") ?: "",
                            call.argument<String>("teamId") ?: "",
                            call.argument<Int>("initialScore") ?: 0,
                            call.argument<Int>("initialRoundWins") ?: 0,
                            call.argument<Int>("initialLivesRemaining") ?: 0,
                            call.argument<Boolean>("initiallyEliminated") ?: false
                        )
                        result.success(true)
                    }
                    "consumePendingRoomMatchResult" -> {
                        result.success(AppPrefs.consumePendingRoomMatchResult(this))
                    }
                    "getPendingRoomMatchResult" -> {
                        result.success(AppPrefs.getPendingRoomMatchResult(this))
                    }
                    "clearPendingRoomMatchResult" -> {
                        AppPrefs.clearPendingRoomMatchResult(this)
                        result.success(true)
                    }
                    "consumePendingCampaignStageResult" -> {
                        result.success(AppPrefs.consumePendingCampaignStageResult(this))
                    }
                    "getPendingCampaignStageResult" -> {
                        result.success(AppPrefs.getPendingCampaignStageResult(this))
                    }
                    "clearPendingCampaignStageResult" -> {
                        AppPrefs.clearPendingCampaignStageResult(this)
                        result.success(true)
                    }
                    "syncLegacyUser" -> {
                        val uid = call.argument<String>("uid") ?: "guest_local"
                        val username = call.argument<String>("username") ?: "لاعب"
                        val photoUrl = call.argument<String>("photoUrl") ?: ""
                        if (uid != "guest_local" &&
                            com.google.firebase.auth.FirebaseAuth.getInstance().currentUser?.uid != uid) {
                            result.error("ACCOUNT_CHANGED", "The signed-in account changed", null)
                            return@setMethodCallHandler
                        }
                        val score = if (AppPrefs.getUserId(this) == uid) AppPrefs.getUserScore(this) else 0
                        // Bind before deriving the level so a previous account's
                        // cached identity cannot become this account's level.
                        AppPrefs.setUser(
                            this,
                            uid,
                            username,
                            photoUrl,
                            1,
                            score
                        )
                        val level = PlayerProgress.getLevel(this)
                        AppPrefs.setUser(this, uid, username, photoUrl, level, score)
                        // Establish the account's local baseline before any
                        // game can create a new contribution on this device.
                        ProgressionSyncState.capture(this)
                        if (uid != "guest_local") {
                            Data.syncUserProfile(uid, username, photoUrl, level, score)
                            Data.setUserActive(uid)
                        }
                        result.success(true)
                    }
                    "resetLegacyUser" -> {
                        VerifiedCommerceStore.invalidateWalletHydration(this)
                        AppPrefs.setGuestUser(this)
                        AppPrefs.clearUnlockedCategories(this)
                        AppPrefs.clearUnlockedCharacters(this)
                        AppPrefs.setSelectedCharacter(this, -1)
                        // Do NOT wipe VIP status on legacy reset; VIP subscriptions belong to Google Play / device.
                        // Account data remains in its own namespace for the
                        // next sign-in; logging out never deletes progression.
                        result.success(true)
                    }
                    "getPlayerStats" -> {
                        result.success(PlayerStats.snapshot(this))
                    }
                    "getProgressionSnapshot" -> {
                        OnlineDuelResultStore.replayPending(this) {
                            try {
                                result.success(ProgressionSyncState.capture(this))
                            } catch (error: RuntimeException) {
                                result.error("PROGRESSION_UNAVAILABLE", "Unable to persist player progression", null)
                            }
                        }
                    }
                    "hydrateProgression" -> {
                        val accountUid = call.argument<String>("accountUid") ?: ""
                        if (com.google.firebase.auth.FirebaseAuth.getInstance().currentUser?.uid != accountUid) {
                            result.error("ACCOUNT_CHANGED", "The signed-in account changed", null)
                            return@setMethodCallHandler
                        }
                        val stats = call.argument<Map<String, Number>>("stats") ?: emptyMap()
                        val acknowledged = call.argument<Map<String, Number>>("acknowledged") ?: emptyMap()
                        if (ProgressionSyncState.hydrate(this, accountUid, stats, acknowledged)) {
                            val level = PlayerProgress.getLevel(this)
                            AppPrefs.setUser(this, accountUid, AppPrefs.getUserName(this),
                                AppPrefs.getUserPhoto(this), level, AppPrefs.getUserScore(this))
                            Data.setUserLevel(accountUid, level)
                            result.success(ProgressionSyncState.capture(this))
                        } else {
                            result.error("ACCOUNT_CHANGED", "The progression account changed", null)
                        }
                    }
                    "getSettings" -> {
                        result.success(mapOf(
                            "sfx"                 to AppPrefs.isSoundEnabled(this),
                            "music"               to AppPrefs.isMusicEnabled(this),
                            "haptic"              to AppPrefs.isHapticEnabled(this),
                            "hapticAvailable"     to AppHaptics.hasVibrator(this),
                            "notifications"       to AppPrefs.isNotificationsEnabled(this),
                            "systemNotifications" to NotificationManagerCompat.from(this).areNotificationsEnabled(),
                            "dialogs"             to AppPrefs.isDialogsEnabled(this),
                            "language"            to AppPrefs.getLanguageCode(this)
                        ))
                    }
                    "setSoundEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        AppPrefs.setSoundEnabled(this, enabled)
                        result.success(true)
                    }
                    "setMusicEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        AppPrefs.setMusicEnabled(this, enabled)
                        result.success(true)
                    }
                    "setHapticEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        AppPrefs.setHapticEnabled(this, enabled)
                        var played = false
                        if (enabled) {
                            played = AppHaptics.medium(this)
                        }
                        result.success(played)
                    }
                    "playHaptic" -> {
                        val style = call.argument<String>("style") ?: "light"
                        val played = if (AppPrefs.isHapticEnabled(this)) {
                            AppHaptics.play(this, style)
                        } else {
                            false
                        }
                        result.success(played)
                    }
                    "setNotificationsEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        AppPrefs.setNotificationsEnabled(this, enabled)
                        DuelNotifications.sync(this)
                        if (enabled) {
                            NotificationScheduler.scheduleDailyReminder(this)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7401)
                            }
                        } else {
                            NotificationScheduler.cancelDailyReminder(this)
                        }
                        result.success(true)
                    }
                    "setDialogsEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        AppPrefs.setDialogsEnabled(this, enabled)
                        result.success(true)
                    }
                    "setLanguage" -> {
                        val language = call.argument<String>("language") ?: "ar"
                        AppPrefs.setLanguageCode(this, language)
                        result.success(true)
                    }
                    "openNotificationSettings" -> {
                        openAppNotificationSettings()
                        result.success(true)
                    }
                    "resetLocalProgress" -> {
                        val deletedUid = call.argument<String>("accountUid") ?: AppPrefs.getUserId(this)
                        val storage = getSharedPreferences("PlayerProgress_v2_$deletedUid", MODE_PRIVATE)
                        val editor = storage.edit()
                        storage.all.keys.filterNot { it.startsWith("commerce_") }.forEach(editor::remove)
                        // Retain the migration marker: a deleted account must
                        // never import its historical snapshot again.
                        editor.putBoolean("accountInitialized", true)
                        ProgressionAccount.commitOrRollback(storage, editor)
                        if (deletedUid == AppPrefs.getUserId(this)) AppPrefs.setGuestUser(this)
                        result.success(true)
                    }
                    "getCommerceState" -> result.success(VerifiedCommerceStore.state(this))
                    "hydrateCommerceWallet" -> result.success(VerifiedCommerceStore.hydrateWallet(
                        this, call.argument<String>("accountUid") ?: "",
                        call.argument<Int>("coins") ?: -1, call.argument<Int>("gems") ?: -1,
                        call.argument<List<String>>("appliedDeliveryIds") ?: emptyList()
                    ))
                    "syncCommerceDeliveryIds" -> result.success(VerifiedCommerceStore.syncDeliveryIds(
                        this, call.argument<List<String>>("appliedDeliveryIds") ?: emptyList()
                    ))
                    "confirmCommerceSnapshot" -> {
                        playBillingManager?.confirmCommerceSnapshot(
                            call.argument<List<String>>("appliedDeliveryIds") ?: emptyList(),
                            call.argument<String>("accountUid")
                        ) { result.success(it) } ?: result.success(false)
                    }
                    "getBillingProducts", "refreshBillingProducts" -> {
                        playBillingManager?.getBillingProducts { result.success(it) }
                            ?: result.success(mapOf("available" to false, "products" to emptyList<Any>(),
                                "error" to "Google Play is unavailable."))
                    }
                    "manageSubscriptions" -> result.success(playBillingManager?.manageSubscriptions() ?: false)
                    "launchBilling" -> {
                        val productId = call.argument<String>("productId") ?: ""
                        if (playBillingManager == null) {
                            val ch = MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return@setMethodCallHandler, "millionaire/native")
                            playBillingManager = PlayBillingManager(this, ch)
                        }
                        playBillingManager?.launchBilling(productId) { success, message ->
                            result.success(mapOf("success" to success, "message" to message))
                        }
                    }
                    "isBillingAvailable" -> {
                        result.success(playBillingManager?.isAvailable() ?: false)
                    }
                    "initBilling" -> {
                        playBillingManager?.startConnection()
                        result.success(true)
                    }
                    "buyCurrency" -> {
                        val coinAmount = call.argument<Int>("coinAmount") ?: 0
                        val gemCost    = call.argument<Int>("gemCost")    ?: 0
                        val exchanges = mapOf(1500 to 15, 6000 to 55, 14000 to 120, 35000 to 290, 90000 to 700)
                        val ok = exchanges[coinAmount] == gemCost &&
                            VerifiedCommerceStore.exchangeGemsForCoins(this, coinAmount, gemCost)
                        result.success(ok)
                    }
                    "restorePurchases" -> {
                        if (playBillingManager == null) {
                            val ch = MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return@setMethodCallHandler, "millionaire/native")
                            playBillingManager = PlayBillingManager(this, ch)
                        }
                        playBillingManager?.queryActivePurchases { result.success(it) }
                            ?: result.success(VerifiedCommerceStore.state(this) + mapOf("success" to false,
                                "message" to "Google Play is unavailable."))
                    }
                    "getAchievements" -> {
                        PlayerProgress.checkMilestoneAchievements(this)

                        val games = PlayerStats.getGamesPlayed(this)
                        val wins  = PlayerStats.getWins(this)
                        val losses = PlayerStats.getLosses(this)
                        val correct = PlayerStats.getCorrectAnswers(this)
                        val wrong = PlayerStats.getWrongAnswers(this)
                        val totalAnswered = PlayerStats.getTotalAnswered(this)
                        val accuracy = if (totalAnswered > 0) (correct * 100 / totalAnswered) else 0
                        val onlineWins = PlayerProgress.getOnlineWins(this)
                        val blitzFinishes = PlayerProgress.getBlitzFinishes(this)
                        val eliminationWins = PlayerProgress.getEliminationWins(this)
                        val survivalWins = PlayerProgress.getSurvivalWins(this)
                        val seriesWins = PlayerProgress.getSeriesWins(this)
                        val teamBattleWins = PlayerProgress.getTeamBattleWins(this)
                        val campaignCompletedStages = PlayerProgress.getCampaignCompletedStages(this)
                        val campaignStars = PlayerProgress.getCampaignStars(this)
                        val campaignBlitzCompletions = PlayerProgress.getCampaignBlitzCompletions(this)
                        val campaignSurvivalCompletions = PlayerProgress.getCampaignSurvivalCompletions(this)
                        val campaignRivalCompletions = PlayerProgress.getCampaignRivalCompletions(this)
                        val campaignSeriesCompletions = PlayerProgress.getCampaignSeriesCompletions(this)
                        val campaignTeamCompletions = PlayerProgress.getCampaignTeamCompletions(this)
                        val campaignNoHelpCompletions = PlayerProgress.getCampaignNoHelpCompletions(this)
                        val campaignBossWins = PlayerProgress.getCampaignBossWins(this)
                        val campaignPerfectCompletions = PlayerProgress.getCampaignPerfectCompletions(this)
                        val inventoryTotal =
                            PlayerProgress.getInventory5050(this) +
                            PlayerProgress.getInventoryAudience(this) +
                            PlayerProgress.getInventoryCall(this)
                        val map = mutableMapOf<String, Any>()
                        map["accountUid"] = ProgressionAccount.uid(this)
                        for (k in PlayerProgress.getAllAchievementKeys()) {
                            map[k] = PlayerProgress.isAchievementUnlocked(this, k)
                            map["${k}_CLAIMED"] = PlayerProgress.isAchievementRewardClaimed(this, k)
                        }
                        map["unclaimedAchievements"] = PlayerProgress.getUnclaimedAchievementCount(this)

                        map["gamesPlayed"]    = games
                        map["wins"]           = wins
                        map["losses"]          = losses
                        map["correctAnswers"] = correct
                        map["wrongAnswers"]   = wrong
                        map["totalAnswered"]  = totalAnswered
                        map["accuracy"]       = accuracy
                        map["bestStreak"]     = PlayerStats.getBestStreak(this)
                        map["winStreak"]      = PlayerStats.getCurrentWinStreak(this)
                        map["bestWinStreak"]  = PlayerStats.getBestWinStreak(this)
                        map["coins"]          = PlayerProgress.getCoins(this)
                        map["gems"]           = PlayerProgress.getGems(this)
                        map["level"]          = PlayerProgress.getLevel(this)
                        map["highestMoney"]   = PlayerStats.getHighestMoney(this)
                        map["totalEarnings"]  = PlayerStats.getTotalEarnings(this)
                        map["inventoryTotal"] = inventoryTotal
                        map["onlineWins"]     = onlineWins
                        map["blitzFinishes"]  = blitzFinishes
                        map["eliminationWins"] = eliminationWins
                        map["survivalWins"]   = survivalWins
                        map["seriesWins"]     = seriesWins
                        map["teamBattleWins"] = teamBattleWins
                        map["campaignCompletedStages"] = campaignCompletedStages
                        map["campaignStars"] = campaignStars
                        map["campaignBlitzCompletions"] = campaignBlitzCompletions
                        map["campaignSurvivalCompletions"] = campaignSurvivalCompletions
                        map["campaignRivalCompletions"] = campaignRivalCompletions
                        map["campaignSeriesCompletions"] = campaignSeriesCompletions
                        map["campaignTeamCompletions"] = campaignTeamCompletions
                        map["campaignNoHelpCompletions"] = campaignNoHelpCompletions
                        map["campaignBossWins"] = campaignBossWins
                        map["campaignPerfectCompletions"] = campaignPerfectCompletions

                        // Saved games may belong to another account. Achievement
                        // progress comes only from this account's counters.
                        map["localTeamsPlayed"] = PlayerProgress.getLocalTeamsPlayed(this)
                        map["offlineBoardPlayed"] = PlayerProgress.getOfflineBoardPlayed(this)
                        map["offlineBoardWins"] = PlayerProgress.getOfflineBoardWins(this)
                        map["tvCastCount"] = PlayerProgress.getTvCastCount(this)
                        map["friendMatchesPlayed"] = PlayerProgress.getFriendMatchesPlayed(this)
                        map["randomMatchesPlayed"] = PlayerProgress.getRandomMatchesPlayed(this)
                        map["unlockedCharactersCount"] = AppPrefs.getUnlockedCharacters(this).size

                        result.success(map)
                    }
                    "recordCampaignAchievementProgress" -> {
                        val owner = call.argument<String>("accountUid") ?: ""
                        val authenticatedUid = com.google.firebase.auth.FirebaseAuth.getInstance().currentUser?.uid ?: "guest_local"
                        if (owner.isEmpty() || owner != AppPrefs.getUserId(this) || owner != authenticatedUid) {
                            result.error("ACCOUNT_CHANGED", "The campaign account changed", null)
                            return@setMethodCallHandler
                        }
                        PlayerProgress.onCampaignStageFinished(
                            this,
                            call.argument<String>("campaignId") ?: "main_campaign",
                            call.argument<String>("stageId") ?: "",
                            call.argument<String>("campaignMode") ?: "classic",
                            call.argument<Boolean>("completed") ?: false,
                            call.argument<Int>("stars") ?: 0,
                            call.argument<Boolean>("bossDefeated") ?: false,
                            call.argument<Int>("usedLifelines") ?: 0
                        )
                        result.success(true)
                    }
                    "hydrateAchievementClaims" -> {
                        val owner = call.argument<String>("accountUid") ?: ""
                        val authenticatedUid = com.google.firebase.auth.FirebaseAuth.getInstance().currentUser?.uid
                        if (owner.isEmpty() || owner != AppPrefs.getUserId(this) || owner != authenticatedUid) {
                            result.error("ACCOUNT_CHANGED", "The achievement account changed", null)
                            return@setMethodCallHandler
                        }
                        result.success(PlayerProgress.hydrateAchievementClaims(this, owner,
                            call.argument<List<String>>("unlockedIds") ?: emptyList(),
                            call.argument<List<String>>("claimedIds") ?: emptyList()))
                    }
                    "claimAchievementReward" -> {
                        PlayerProgress.checkMilestoneAchievements(this)
                        val key = call.argument<String>("key") ?: ""
                        val claim = PlayerProgress.claimAchievementReward(this, key)
                        result.success(mapOf(
                            "success" to claim.success,
                            "coins" to claim.coins,
                            "xp" to claim.xp,
                            "totalCoins" to claim.totalCoins,
                            "totalGems" to claim.totalGems,
                            "totalXp" to claim.totalXp,
                            "unclaimedAchievements" to PlayerProgress.getUnclaimedAchievementCount(this)
                        ))
                    }
                    "claimAllAchievementRewards" -> {
                        PlayerProgress.checkMilestoneAchievements(this)
                        val claim = PlayerProgress.claimAllAchievementRewards(this)
                        result.success(mapOf(
                            "success" to claim.success,
                            "claimedCount" to claim.claimedCount,
                            "coins" to claim.coins,
                            "xp" to claim.xp,
                            "totalCoins" to claim.totalCoins,
                            "totalGems" to claim.totalGems,
                            "totalXp" to claim.totalXp,
                            "unclaimedAchievements" to PlayerProgress.getUnclaimedAchievementCount(this)
                        ))
                    }
                    "getCharacterArtwork" -> {
                        val artwork = intArrayOf(
                            R.drawable.contestant_khaled, R.drawable.contestant_omar,
                            R.drawable.contestant_fahad, R.drawable.contestant_mazen,
                            R.drawable.contestant_mahmoud, R.drawable.contestant_ellen,
                            R.drawable.contestant_sarah, R.drawable.contestant_talia,
                            R.drawable.contestant_layan, R.drawable.contestant_rashid,
                            R.drawable.contestant_jana, R.drawable.contestant_yazan,
                            R.drawable.contestant_nour, R.drawable.contestant_zaid,
                            R.drawable.contestant_salman, R.drawable.contestant_adam
                        )
                        val index = call.argument<Int>("index") ?: -1
                        if (index !in artwork.indices) {
                            result.error("INVALID_CHARACTER", "Unknown character index", null)
                        } else {
                            // Read the packaged PNG/WebP off the UI thread.
                            val appResources = applicationContext.resources
                            kotlin.concurrent.thread(name = "home-character-artwork") {
                                try {
                                    val bytes = appResources.openRawResource(artwork[index]).use { it.readBytes() }
                                    runOnUiThread { result.success(bytes) }
                                } catch (error: Exception) {
                                    runOnUiThread { result.error("CHARACTER_ARTWORK", error.message, null) }
                                }
                            }
                        }
                    }
                    "getCharacterState" -> {
                        val selected = AppPrefs.getSelectedCharacter(this)
                        val unlocked = AppPrefs.getUnlockedCharacters(this)
                            .mapNotNull { it.toIntOrNull() }
                        result.success(mapOf("selected" to selected, "unlocked" to unlocked))
                    }
                    "setSelectedCharacter" -> {
                        val index = call.argument<Int>("index") ?: -1
                        if (CharacterUnlocks.isValid(index)) {
                            AppPrefs.setSelectedCharacter(this, index)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "unlockCharacter" -> {
                        val index   = call.argument<Int>("index") ?: -1
                        val payWith = call.argument<String>("payWith") ?: "coins"
                        val cost    = call.argument<Int>("cost") ?: 0
                        val expectedCurrency = CharacterUnlocks.purchaseCurrency(index)
                        val expectedCost = CharacterUnlocks.purchaseCost(index)
                        if (expectedCurrency.isEmpty() || expectedCurrency != payWith || expectedCost != cost) {
                            result.success(false)
                        } else if (AppPrefs.isCharacterPurchased(this, index)) {
                            result.success(true)
                        } else {
                            val ok = if (payWith == "coins") {
                                PlayerProgress.spendCoins(this, cost)
                            } else {
                                PlayerProgress.spendGems(this, cost)
                            }
                            if (ok) {
                                AppPrefs.unlockCharacter(this, index)
                                PlayerProgress.checkMilestoneAchievements(this)
                            }
                            result.success(ok)
                        }
                    }
                    "getCategoryState" -> {
                        val unlocked = AppPrefs.getUnlockedCategories(this).toList()
                        val rentals = AppPrefs.getActiveRentals(this)
                        val isVip = AppPrefs.isVip(this)
                        result.success(mapOf(
                            "unlocked" to unlocked,
                            "rentals" to rentals,
                            "isVip" to isVip,
                            "allCategories" to VerifiedCommerceStore.hasAllCategories(this)
                        ))
                    }
                    "unlockCategory" -> {
                        val category = call.argument<String>("category") ?: ""
                        val gemCost = call.argument<Int>("gemCost") ?: CategoryConfig.DEFAULT_PERMANENT_GEM_COST
                        if (gemCost != CategoryConfig.DEFAULT_PERMANENT_GEM_COST) result.success(false)
                        else GameEconomy.request(this, mapOf("action" to "own", "category" to category)) { _, error ->
                            if (error == null) result.success(true) else result.error("ECONOMY_FAILED", error, null)
                        }
                    }
                    "rentCategory" -> {
                        val category = call.argument<String>("category") ?: ""
                        GameEconomy.request(this, mapOf("action" to "ad", "category" to category)) { _, error ->
                            if (error == null) result.success(true) else result.error("ECONOMY_FAILED", error, null)
                        }
                    }
                    "setCategoryState" -> {
                        val unlocked = (call.argument<List<String>>("unlocked") ?: emptyList()).toSet()
                        AppPrefs.setUnlockedCategories(this, unlocked)
                        result.success(true)
                    }
                    "setCharacterState" -> {
                        val selected = call.argument<Int>("selected") ?: -1
                        val unlocked = (call.argument<List<Int>>("unlocked") ?: emptyList()).map { it.toString() }.toSet()
                        AppPrefs.setSelectedCharacter(this, selected)
                        AppPrefs.setUnlockedCharacters(this, unlocked)
                        result.success(true)
                    }
                    else -> result.notImplemented()
            }
    }
    }

    private fun playCampaignMapMusic() {
        if (!AppPrefs.isMusicEnabled(this)) {
            stopCampaignMapMusic()
            return
        }
        val current = campaignMapMusicPlayer
        if (current != null) {
            try {
                if (current.isPlaying) return
            } catch (ignored: Exception) {
                stopCampaignMapMusic()
            }
        }
        stopCampaignMapMusic()
        campaignMapMusicPlayer = MediaPlayer.create(this, R.raw.sneaky_snitch)?.apply {
            isLooping = true
            setVolume(campaignMapMusicVolume, campaignMapMusicVolume)
            setOnErrorListener { player, _, _ ->
                try {
                    player.release()
                } catch (ignored: Exception) {
                }
                if (campaignMapMusicPlayer === player) {
                    campaignMapMusicPlayer = null
                }
                true
            }
            start()
        }
    }

    private fun stopCampaignMapMusic() {
        val player = campaignMapMusicPlayer
        campaignMapMusicPlayer = null
        if (player == null) return
        try {
            if (player.isPlaying) {
                player.stop()
            }
        } catch (ignored: Exception) {
        }
        try {
            player.release()
        } catch (ignored: Exception) {
        }
    }

    private fun openAppNotificationSettings() {
        val notificationIntent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        }
        try {
            startActivity(notificationIntent)
        } catch (ignored: Exception) {
            val appSettingsIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(appSettingsIntent)
        }
    }

    private fun syncDailyReminderSchedule() {
        if (AppPrefs.isNotificationsEnabled(this)) {
            NotificationScheduler.scheduleDailyReminder(this)
        } else {
            NotificationScheduler.cancelDailyReminder(this)
        }
    }

    private fun stringArg(value: Any?, defaultValue: String): String {
        val text = value?.toString()?.trim() ?: return defaultValue
        return text.ifEmpty { defaultValue }
    }

    private fun intArg(value: Any?, defaultValue: Int): Int {
        return when (value) {
            is Int -> value
            is Long -> value.toInt()
            is Number -> value.toInt()
            is String -> value.trim().toIntOrNull() ?: defaultValue
            else -> defaultValue
        }
    }

    private fun boolArg(value: Any?, defaultValue: Boolean): Boolean {
        return when (value) {
            is Boolean -> value
            is Number -> value.toInt() != 0
            is String -> {
                when (value.trim().lowercase()) {
                    "true", "1" -> true
                    "false", "0" -> false
                    else -> defaultValue
                }
            }
            else -> defaultValue
        }
    }

    private fun intArrayListArg(value: Any?): ArrayList<Int> {
        if (value !is Iterable<*>) return arrayListOf()
        val ids = arrayListOf<Int>()
        for (item in value) {
            when (item) {
                is Int -> ids.add(item)
                is Long -> ids.add(item.toInt())
                is Number -> ids.add(item.toInt())
                is String -> item.trim().toIntOrNull()?.let(ids::add)
            }
        }
        return ids
    }

    private fun stringArrayListArg(value: Any?): ArrayList<String> {
        if (value !is Iterable<*>) return arrayListOf()
        val values = arrayListOf<String>()
        for (item in value) {
            val text = item?.toString()?.trim().orEmpty()
            if (text.isNotEmpty()) values.add(text)
        }
        return values
    }

}
