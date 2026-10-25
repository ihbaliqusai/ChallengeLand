package com.qi7bali.landchallengeonline

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.android.billingclient.api.*
import com.google.firebase.auth.FirebaseAuth
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class PlayBillingManager(
    private val activity: Activity,
    private val channel: MethodChannel
) : PurchasesUpdatedListener {
    companion object {
        private const val TAG = "PlayBillingManager"
        private val DISPLAY_IDS = listOf(
            "pack_starter", "pack_value", "pack_champion",
            "gems_80", "gems_500", "gems_1200",
            "coins_5000", "coins_25000", "coins_100000",
            "vip_monthly", "category_all_access", "keys_10", "hearts_10", "tickets_10",
            "keys_1", "hearts_1", "tickets_1", "resources_3_each", "resources_10_each",
            "wheel_spins_3"
        )
        private val INAPP_IDS = DISPLAY_IDS.filter { it != "vip_monthly" } +
            listOf("gems_2500", "gems_6500", "gems_14000", "noads")
        private val SUBS_IDS = listOf("vip_monthly", "vip_pass", "vipmonthly", "vippass", "vip")
        private val aliases: Map<String, String> = buildMap {
            (INAPP_IDS + SUBS_IDS).forEach { put(it, it) }
            INAPP_IDS.forEach { put(it.replace("_", ""), it) }
            listOf("vip_pass", "vipmonthly", "vippass", "vip").forEach { put(it, "vip_monthly") }
        }
        private fun canonical(id: String): String? = aliases[id.lowercase()]
        private fun isConsumable(id: String): Boolean = PlayProductRules.isConsumable(canonical(id))
    }

    private val main = Handler(Looper.getMainLooper())
    private val verifier = CommerceVerifier()
    private val cachedProducts = mutableMapOf<String, ProductDetails>()
    private val connectionWaiters = mutableListOf<(Boolean, String) -> Unit>()
    private val verifyingTokens = mutableMapOf<String, MutableList<(Boolean, String) -> Unit>>()
    private val unavailableProducts = mutableMapOf<String, String>()
    private var connecting = false
    private var closed = false
    private var launchedProduct: String? = null
    private var verifiedSubscriptionId: String? = null
    private var activeRestore = false
    private val restoreWaiters = mutableListOf<(Map<String, Any>) -> Unit>()
    private val billingClient = BillingClient.newBuilder(activity)
        .setListener(this)
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .build()

    init { startConnection() }

    private fun status(productId: String = "", value: String, message: String = "", code: Int? = null) {
        main.post {
            if (!closed) channel.invokeMethod("onPurchaseStatus", buildMap<String, Any> {
                put("productId", canonical(productId) ?: productId)
                put("status", value)
                put("message", message)
                if (code != null) put("code", code)
            })
        }
    }

    fun startConnection(onReady: (() -> Unit)? = null) {
        connect { success, _ -> if (success) onReady?.invoke() }
    }

    private fun connect(callback: (Boolean, String) -> Unit) {
        if (closed) { callback(false, "The store is closed."); return }
        if (billingClient.isReady) { callback(true, ""); return }
        connectionWaiters.add(callback)
        if (connecting) return
        connecting = true
        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                main.post {
                    connecting = false
                    val success = result.responseCode == BillingClient.BillingResponseCode.OK
                    val waiters = connectionWaiters.toList()
                    connectionWaiters.clear()
                    waiters.forEach { it(success, if (success) "" else "Google Play is unavailable. ${result.debugMessage}") }
                }
            }

            override fun onBillingServiceDisconnected() {
                main.post {
                    connecting = false
                    val waiters = connectionWaiters.toList()
                    connectionWaiters.clear()
                    waiters.forEach { it(false, "Google Play disconnected. Please try again.") }
                }
            }
        })
        main.postDelayed({
            if (connecting) {
                connecting = false
                val waiters = connectionWaiters.toList()
                connectionWaiters.clear()
                waiters.forEach { it(false, "Google Play connection timed out. Please try again.") }
            }
        }, 15_000)
    }

    /** Refreshes Play's localized prices and marks missing catalog products unavailable. */
    fun getBillingProducts(callback: (Map<String, Any>) -> Unit) {
        connect { connected, message ->
            if (!connected) {
                callback(mapOf("available" to false, "products" to productMaps(), "error" to message))
            } else {
                queryAllProducts {
                    callback(mapOf("available" to billingClient.isReady, "products" to productMaps(), "error" to it))
                }
            }
        }
    }

    fun queryAllProducts(onComplete: (String) -> Unit) {
        val batches = buildList {
            aliases.keys.filter { canonical(it) in INAPP_IDS }.chunked(20)
                .forEach { add(BillingClient.ProductType.INAPP to it) }
            SUBS_IDS.chunked(20).forEach { add(BillingClient.ProductType.SUBS to it) }
        }
        val fresh = mutableMapOf<String, ProductDetails>()
        val missing = mutableMapOf<String, String>()
        val errors = mutableListOf<String>()
        fun queryBatch(index: Int) {
            if (index >= batches.size) {
                cachedProducts.clear()
                cachedProducts.putAll(fresh)
                unavailableProducts.clear()
                unavailableProducts.putAll(missing)
                onComplete(errors.joinToString(" "))
                return
            }
            val (type, ids) = batches[index]
            val params = QueryProductDetailsParams.newBuilder().setProductList(ids.map {
                QueryProductDetailsParams.Product.newBuilder().setProductId(it).setProductType(type).build()
            }).build()
            billingClient.queryProductDetailsAsync(params) { result, details ->
                main.post {
                    if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                        details.productDetailsList.forEach { fresh[it.productId] = it }
                        details.unfetchedProductList.forEach {
                            missing[it.productId] = "Product not returned by Google Play. Check its active purchase option, country and testing account."
                            Log.i(TAG, "Product ${it.productId} unavailable (${it.statusCode}).")
                        }
                    } else {
                        val message = "Google Play product query failed (${result.responseCode})."
                        errors.add(message)
                        ids.forEach { missing[it] = message }
                    }
                    queryBatch(index + 1)
                }
            }
        }
        queryBatch(0)
    }

    private fun findProduct(id: String): ProductDetails? {
        val catalogId = canonical(id) ?: return null
        if (catalogId == "vip_monthly") {
            if (id in listOf("vip_monthly", "vipmonthly")) cachedProducts[id]?.let { return it }
            return listOf("vip_monthly", "vipmonthly").firstNotNullOfOrNull { cachedProducts[it] }
        }
        return cachedProducts[id] ?: cachedProducts[catalogId] ?: cachedProducts.values.firstOrNull {
            canonical(it.productId) == catalogId
        }
    }

    private fun selectedOffer(details: ProductDetails) = details.subscriptionOfferDetails?.firstOrNull {
        val phases = it.pricingPhases.pricingPhaseList
        val recurring = phases.singleOrNull()
        it.offerId == null && recurring?.billingPeriod == "P1M" &&
            recurring.recurrenceMode == ProductDetails.RecurrenceMode.INFINITE_RECURRING
    }

    /** New Console products may not have a backwards-compatible purchase option. */
    private fun selectedOneTimeOffer(details: ProductDetails): ProductDetails.OneTimePurchaseOfferDetails? {
        val options = details.oneTimePurchaseOfferDetailsList
            ?.takeIf { it.isNotEmpty() }
            ?: listOfNotNull(details.oneTimePurchaseOfferDetails)
        // The catalog promises an immediate, permanent grant: choose a normal buy option.
        // Introductory/preorder offers and rentals require their own delivery contract.
        val eligible = options.filter { it.rentalDetails == null && it.offerId.isNullOrBlank() }
        return eligible.firstOrNull { it.purchaseOptionId == "standard" }
            ?: eligible.sortedBy { it.purchaseOptionId.orEmpty() }.firstOrNull()
    }

    private fun productMaps(): List<Map<String, Any>> = DISPLAY_IDS.map { id ->
        val details = findProduct(id)
        val phase = details?.let { selectedOffer(it)?.pricingPhases?.pricingPhaseList?.lastOrNull() }
        val oneTime = details?.let { selectedOneTimeOffer(it) }
        val price = phase?.formattedPrice ?: oneTime?.formattedPrice ?: ""
        val unavailable = when {
            details == null -> unavailableProducts[id]
                ?: "Product not returned by Google Play. Check its active purchase option, country and testing account."
            id == "vip_monthly" && phase == null -> "A monthly auto-renewing base plan is not available."
            id != "vip_monthly" && oneTime == null -> "No eligible buy purchase option is available. Activate the standard purchase option in Google Play."
            else -> ""
        }
        mapOf(
            "id" to id,
            "productId" to id,
            "storeProductId" to (details?.productId ?: id),
            "title" to (details?.title ?: ""),
            "description" to (details?.description ?: ""),
            "price" to price,
            "currencyCode" to (phase?.priceCurrencyCode ?: oneTime?.priceCurrencyCode ?: ""),
            "rawPrice" to ((phase?.priceAmountMicros ?: oneTime?.priceAmountMicros ?: 0L) / 1_000_000.0),
            "billingPeriod" to (phase?.billingPeriod ?: ""),
            "available" to (details != null && price.isNotEmpty()),
            "availabilityMessage" to unavailable
        )
    }

    fun launchBilling(productId: String, callback: (Boolean, String) -> Unit) {
        val id = canonical(productId)
        if (id == null) { callback(false, "This product is not in the purchase catalog."); return }
        val user = FirebaseAuth.getInstance().currentUser
        if (user == null || user.isAnonymous) {
            callback(false, "Sign in to protect and restore your purchases.")
            return
        }
        if (!VerifiedCommerceStore.isWalletHydrated(activity)) {
            callback(false, "Your account wallet is syncing. Please try again in a moment.")
            return
        }
        val accountUid = user.uid
        run {
            // Require a reachable verifier before charging for any product, including currency.
            // This also prevents a duplicate permanent purchase on another device.
            status(id, "verifying", "Checking your account purchases before payment.")
            verifier.call("restoreCommercePurchases", JSONObject()) { verifiedUid, response, error ->
                try {
                    check(error == null && response != null && verifiedUid == accountUid) {
                        error ?: "Could not verify your account purchases. Please try again."
                    }
                    check(FirebaseAuth.getInstance().currentUser?.uid == accountUid &&
                        VerifiedCommerceStore.isWalletHydrated(activity)) {
                        "The signed-in account changed. Please try again."
                    }
                    VerifiedCommerceStore.applyRestore(activity, accountUid, response)
                    val state = VerifiedCommerceStore.state(activity)
                    val owned = when (id) {
                        "pack_starter" -> state["starterPurchased"] == true
                        "category_all_access" -> state["allCategories"] == true
                        "vip_monthly" -> state["isVip"] == true
                        "noads" -> state["removeAds"] == true
                        else -> false
                    }
                    if (owned) {
                        val message = if (id == "vip_monthly") "Your VIP subscription is already active. Manage it in Google Play."
                            else "This permanent purchase is already owned by your account."
                        status(id, "error", message)
                        callback(false, message)
                    } else launchPreparedBilling(productId, id, accountUid, callback)
                } catch (exception: Exception) {
                    val message = exception.message ?: "Could not verify your account purchases. Please try again."
                    status(id, "error", message)
                    callback(false, message)
                }
            }
            return
        }
    }

    private fun launchPreparedBilling(productId: String, id: String, accountUid: String,
                                      callback: (Boolean, String) -> Unit) {
        connect { success, message ->
            if (!success) { callback(false, message); return@connect }
            // ProductDetails must be refreshed before opening the payment sheet.
            queryAllProducts {
                val details = findProduct(productId)
                if (details == null) {
                    callback(false, "This product is currently unavailable in Google Play.")
                    return@queryAllProducts
                }
                if (FirebaseAuth.getInstance().currentUser?.uid != accountUid ||
                    !VerifiedCommerceStore.isWalletHydrated(activity)) {
                    callback(false, "The signed-in account changed. Please try again.")
                    return@queryAllProducts
                }
                val product = BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(details)
                if (details.productType == BillingClient.ProductType.SUBS) {
                    val offer = selectedOffer(details)
                    if (offer == null) {
                        callback(false, "No eligible subscription offer is available.")
                        return@queryAllProducts
                    }
                    product.setOfferToken(offer.offerToken)
                } else {
                    val oneTime = selectedOneTimeOffer(details)
                    if (oneTime == null) {
                        callback(false, "No eligible purchase option is available.")
                        return@queryAllProducts
                    }
                    oneTime.offerToken?.takeIf { it.isNotBlank() }?.let(product::setOfferToken)
                }
                val params = BillingFlowParams.newBuilder()
                    .setObfuscatedAccountId(CommerceVerifier.accountBinding(accountUid))
                    .setProductDetailsParamsList(listOf(product.build())).build()
                launchedProduct = id
                status(id, "launching")
                val flowResult = billingClient.launchBillingFlow(activity, params)
                val opened = flowResult.responseCode == BillingClient.BillingResponseCode.OK
                if (!opened) {
                    status(id, "error", "Could not open the Google Play purchase sheet.", flowResult.responseCode)
                    launchedProduct = null
                    if (flowResult.responseCode == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) queryActivePurchases()
                }
                callback(opened, if (opened) "" else "Could not open the Google Play purchase sheet (${flowResult.responseCode}).")
            }
        }
    }

    override fun onPurchasesUpdated(result: BillingResult, purchases: List<Purchase>?) {
        main.post {
            when (result.responseCode) {
                BillingClient.BillingResponseCode.OK -> purchases.orEmpty().forEach { handlePurchase(it) { _, _ -> } }
                BillingClient.BillingResponseCode.USER_CANCELED -> {
                    status(launchedProduct.orEmpty(), "cancelled", "Purchase cancelled.")
                    launchedProduct = null
                }
                else -> {
                    status(launchedProduct.orEmpty(), "error", "Google Play could not complete this purchase.", result.responseCode)
                    launchedProduct = null
                }
            }
        }
    }

    private fun handlePurchase(purchase: Purchase, onComplete: (Boolean, String) -> Unit) {
        val productId = purchase.products.singleOrNull()
        if (productId == null || canonical(productId) == null) { onComplete(false, "Unsupported purchase product."); return }
        if (purchase.purchaseState == Purchase.PurchaseState.PENDING) {
            status(productId, "pending", "Payment is pending. Rewards arrive after Google Play confirms payment.")
            // Register an owner-bound pending token so a later RTDN can resolve the account.
            if (VerifiedCommerceStore.isWalletHydrated(activity)) {
                verifier.call("verifyPlayPurchase", JSONObject().put("productId", productId)
                    .put("purchaseToken", purchase.purchaseToken).put("packageName", activity.packageName)) {
                        accountUid, response, _ ->
                    if (accountUid != null && response?.optBoolean("verified") == true) {
                        try { VerifiedCommerceStore.applyEntitlementSnapshot(activity, accountUid, response) }
                        catch (_: Exception) { /* Play will retry the receipt during restore. */ }
                    }
                }
            }
            onComplete(false, "")
            return
        }
        if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) { onComplete(false, "Purchase is not completed."); return }
        if (!VerifiedCommerceStore.isWalletHydrated(activity)) {
            status(productId, "error", "Your account wallet is syncing. Restore purchases after signing in.")
            onComplete(false, "Your account wallet is syncing. Restore purchases after signing in.")
            return
        }
        val waiting = verifyingTokens[purchase.purchaseToken]
        if (waiting != null) { waiting.add(onComplete); return }
        verifyingTokens[purchase.purchaseToken] = mutableListOf(onComplete)
        status(productId, "verifying", "Verifying your purchase securely.")
        verifier.call("verifyPlayPurchase", JSONObject()
            .put("productId", productId).put("purchaseToken", purchase.purchaseToken)
            .put("packageName", activity.packageName)) { accountUid, response, error ->
            var delivered = false
            var failure = ""
            try {
                check(error == null && response != null && accountUid != null) { error ?: "Purchase verification failed." }
                if (response.optBoolean("verified") && response.optString("status") in listOf("pending", "revoked")) {
                    VerifiedCommerceStore.applyEntitlementSnapshot(activity, accountUid, response)
                    val pending = response.optString("status") == "pending"
                    if (!pending) failure = "This purchase was refunded, revoked or expired."
                    status(productId, if (pending) "pending" else "error", if (pending)
                        "Payment is pending. Rewards arrive after Google Play confirms payment."
                        else "This purchase was refunded, revoked or expired.")
                    return@call
                }
                val newlyApplied = VerifiedCommerceStore.applyVerified(activity, accountUid, response,
                    productId, purchase.purchaseToken, isConsumable(productId) || !purchase.isAcknowledged)
                delivered = true
                if (canonical(productId) == "vip_monthly") verifiedSubscriptionId = productId
                val requested = launchedProduct == canonical(productId)
                if (newlyApplied || requested) {
                    channel.invokeMethod("onPurchaseDelivered", mapOf("productId" to (canonical(productId) ?: productId)))
                }
                status(productId, "delivered", "Purchase delivered.")
                if (requested) launchedProduct = null
                settleConfirmedPurchases()
            } catch (exception: Exception) {
                failure = exception.message ?: "Purchase verification failed. Restore purchases to retry."
                status(productId, "error", failure)
            } finally {
                verifyingTokens.remove(purchase.purchaseToken)?.forEach { it(delivered, failure) }
            }
        }
    }

    /** Rewards and receipt IDs have reached the same cloud snapshot before consuming a token. */
    fun confirmCommerceSnapshot(deliveryIds: List<String>, accountUid: String?, callback: (Boolean) -> Unit) {
        if (accountUid != null && FirebaseAuth.getInstance().currentUser?.uid != accountUid) {
            callback(false)
            return
        }
        if (!VerifiedCommerceStore.isWalletHydrated(activity)) { callback(false); return }
        if (!VerifiedCommerceStore.syncDeliveryIds(activity, deliveryIds)) { callback(false); return }
        connect { connected, _ ->
            if (connected) settleConfirmedPurchases()
            callback(connected)
        }
    }

    private val settlingKeys = mutableSetOf<String>()

    private fun settleConfirmedPurchases() {
        if (!billingClient.isReady) return
        VerifiedCommerceStore.pendingConfirmed(activity).forEach { (key, productId, token, needsSettlement) ->
            if (!settlingKeys.add(key)) return@forEach
            if (!needsSettlement) {
                try { VerifiedCommerceStore.markSettled(activity, key) }
                catch (_: Exception) { Log.w(TAG, "Purchase settlement journal will retry.") }
                settlingKeys.remove(key)
                return@forEach
            }
            fun completed(result: BillingResult) {
                main.post {
                    settlingKeys.remove(key)
                    if (result.responseCode == BillingClient.BillingResponseCode.OK ||
                        result.responseCode == BillingClient.BillingResponseCode.ITEM_NOT_OWNED) {
                        try { VerifiedCommerceStore.markSettled(activity, key) }
                        catch (_: Exception) { Log.w(TAG, "Purchase settlement journal will retry.") }
                    } else Log.w(TAG, "Verified purchase settlement will retry (${result.responseCode}).")
                }
            }
            if (isConsumable(productId)) {
                billingClient.consumeAsync(ConsumeParams.newBuilder().setPurchaseToken(token).build()) { result, _ -> completed(result) }
            } else {
                billingClient.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder()
                    .setPurchaseToken(token).build()) { completed(it) }
            }
        }
    }

    /** Restores account entitlements, then waits for every owned Play receipt to be verified. */
    fun queryActivePurchases(onComplete: ((Map<String, Any>) -> Unit)? = null) {
        if (onComplete != null) restoreWaiters.add(onComplete)
        if (activeRestore || closed) return
        val user = FirebaseAuth.getInstance().currentUser
        if (user == null || user.isAnonymous) {
            completeRestore(false, 0, 0, "Sign in to restore purchases.")
            return
        }
        if (!VerifiedCommerceStore.isWalletHydrated(activity)) {
            completeRestore(false, 0, 0, "Your account wallet is syncing. Please try again in a moment.")
            return
        }
        activeRestore = true
        verifier.call("restoreCommercePurchases", JSONObject()) { accountUid, response, error ->
            try {
                check(error == null && response != null && accountUid != null) { error ?: "Could not restore purchases." }
                VerifiedCommerceStore.applyRestore(activity, accountUid, response)
                connect { connected, message ->
                    if (!connected) { completeRestore(false, 0, 0, message); return@connect }
                    queryOwnedPurchases()
                }
            } catch (exception: Exception) {
                completeRestore(false, 0, 0, exception.message ?: "Could not restore purchases.")
            }
        }
    }

    private fun queryOwnedPurchases() {
        val purchases = mutableListOf<Purchase>()
        var queryError = ""
        fun queryType(index: Int) {
            if (index == 2) {
                val unique = purchases.filter { canonical(it.products.singleOrNull().orEmpty()) != null }
                    .distinctBy { it.purchaseToken }
                val pending = unique.count { it.purchaseState == Purchase.PurchaseState.PENDING }
                if (unique.isEmpty()) { completeRestore(queryError.isEmpty(), 0, pending, queryError); return }
                var remaining = unique.size
                var verified = 0
                var failed = false
                var firstFailure = ""
                unique.forEach { purchase ->
                    handlePurchase(purchase) { success, error ->
                        if (success) verified++
                        else if (purchase.purchaseState != Purchase.PurchaseState.PENDING) {
                            failed = true
                            if (firstFailure.isEmpty()) firstFailure = error
                        }
                        remaining--
                        if (remaining == 0) completeRestore(!failed && queryError.isEmpty(), verified, pending,
                            if (failed) firstFailure.ifEmpty { "Some purchases could not be verified. Please try again." } else queryError)
                    }
                }
                return
            }
            val type = if (index == 0) BillingClient.ProductType.SUBS else BillingClient.ProductType.INAPP
            billingClient.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(type).build()) { result, owned ->
                main.post {
                    if (result.responseCode == BillingClient.BillingResponseCode.OK) purchases.addAll(owned)
                    else queryError = "Could not query Google Play purchases (${result.responseCode})."
                    queryType(index + 1)
                }
            }
        }
        queryType(0)
    }

    private fun completeRestore(success: Boolean, restored: Int, pending: Int, message: String) {
        activeRestore = false
        val response = VerifiedCommerceStore.state(activity) + mapOf(
            "success" to success, "restoredCount" to restored, "pendingCount" to pending, "message" to message
        )
        restoreWaiters.toList().forEach { it(response) }
        restoreWaiters.clear()
    }

    fun manageSubscriptions(): Boolean = try {
        val uri = Uri.parse("https://play.google.com/store/account/subscriptions").buildUpon()
        if (VerifiedCommerceStore.isVip(activity)) {
            uri.appendQueryParameter("package", activity.packageName)
                .appendQueryParameter("sku", verifiedSubscriptionId
                    ?: findProduct("vip_monthly")?.productId ?: "vip_monthly")
        }
        val intent = Intent(Intent.ACTION_VIEW, uri.build())
        try { activity.startActivity(Intent(intent).setPackage("com.android.vending")) }
        catch (_: Exception) { activity.startActivity(intent) }
        true
    } catch (_: Exception) { false }

    fun isAvailable(): Boolean = billingClient.isReady && !closed
    fun getLoadedProductIds(): List<String> = cachedProducts.keys.toList()

    fun close() {
        closed = true
        main.removeCallbacksAndMessages(null)
        billingClient.endConnection()
        verifier.close()
    }
}
