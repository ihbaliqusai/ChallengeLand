package com.qi7bali.landchallengeonline

import android.content.Context
import com.google.firebase.auth.FirebaseAuth
import org.json.JSONObject

/** Verified entitlements and the local delivery ledger share the wallet transaction. */
object VerifiedCommerceStore {
    private const val PREFIX = "commerce_"
    private const val OWNER = "${PREFIX}owner"
    private const val WALLET_OWNER = "${PREFIX}wallet_owner"
    private const val DELIVERIES = "${PREFIX}deliveries"
    private const val CONFIRMED = "${PREFIX}confirmed_deliveries"
    private const val PENDING = "${PREFIX}pending_settlement"
    private const val VIP = "${PREFIX}vip"
    private const val EXPIRY = "${PREFIX}vip_expiry"
    private const val CATEGORIES = "${PREFIX}all_categories"
    private const val REMOVE_ADS = "${PREFIX}remove_ads"
    private const val STARTER = "${PREFIX}starter"
    private const val REFERRAL_REVISION = "${PREFIX}referral_revision"

    private fun prefs(context: Context) =
        ProgressionAccount.preferences(context)

    private fun uid(): String? = try {
        FirebaseAuth.getInstance().currentUser?.takeUnless { it.isAnonymous }?.uid
    } catch (_: Exception) { null }

    @JvmStatic
    fun isVip(context: Context): Boolean {
        val prefs = prefs(context)
        return uid() != null && prefs.getString(OWNER, "") == uid() &&
            prefs.getBoolean(VIP, false) && prefs.getLong(EXPIRY, 0L) > System.currentTimeMillis()
    }

    @JvmStatic
    fun hasAllCategories(context: Context): Boolean =
        uid() != null && prefs(context).getString(OWNER, "") == uid() &&
            prefs(context).getBoolean(CATEGORIES, false)

    @JvmStatic
    fun isAdFree(context: Context): Boolean = isVip(context) ||
        (uid() != null && prefs(context).getString(OWNER, "") == uid() &&
            prefs(context).getBoolean(REMOVE_ADS, false))

    @JvmStatic
    @Synchronized
    fun state(context: Context): Map<String, Any> {
        val prefs = prefs(context)
        val snapshot = prefs.all
        val currentUid = uid()
        val ownsState = currentUid != null && snapshot[OWNER] == currentUid
        val starter = ownsState && snapshot[STARTER] == true
        val categories = ownsState && snapshot[CATEGORIES] == true
        val ads = ownsState && snapshot[REMOVE_ADS] == true
        val expiry = if (ownsState) snapshot[EXPIRY] as? Long ?: 0L else 0L
        val confirmed = snapshot[CONFIRMED] as? Set<*> ?: emptySet<String>()
        val pending = JSONObject(snapshot[PENDING] as? String ?: "{}")
        val pendingGrants = pending.keys().asSequence().filter {
            currentUid != null && it.startsWith("$currentUid:") && it !in confirmed
        }.map {
            val receipt = pending.getJSONObject(it)
            mapOf("deliveryId" to it.substringAfter(':'), "coins" to receipt.optInt("coins"),
                "gems" to receipt.optInt("gems"))
        }.toList()
        return mapOf(
            "accountUid" to (currentUid ?: ""),
            "walletAccountUid" to (snapshot[WALLET_OWNER] as? String ?: ""),
            "isVip" to (ownsState && snapshot[VIP] == true && expiry > System.currentTimeMillis()),
            "expiresAtMillis" to expiry,
            "allCategories" to categories,
            "removeAds" to ads,
            "starterPurchased" to starter,
            "walletCoins" to (snapshot["coins"] as? Int ?: 0),
            "walletGems" to (snapshot["gems"] as? Int ?: 0),
            "pendingSnapshotGrants" to pendingGrants,
            "appliedDeliveryIds" to (snapshot[DELIVERIES] as? Set<*> ?: emptySet<String>()).filterIsInstance<String>().filter {
                currentUid != null && it.startsWith("$currentUid:")
            }.map { it.substringAfter(':') },
            "purchasedOneTime" to buildList {
                if (starter) add("pack_starter")
                if (categories) add("category_all_access")
                if (ads) add("noads")
            }
        )
    }

    /** Returns whether this delivery was newly applied. Throws before success if durability fails. */
    @Synchronized
    fun applyVerified(context: Context, accountUid: String, response: JSONObject,
                      productId: String, purchaseToken: String, needsSettlement: Boolean): Boolean {
        check(uid() == accountUid) { "The signed-in account changed. Restore purchases with your account." }
        check(isWalletHydrated(context)) { "Your account wallet is syncing. Please restore purchases after signing in." }
        check(response.optBoolean("verified") && response.optString("status") == "delivered") {
            "Google Play purchase verification was not completed."
        }
        val deliveryId = response.optString("deliveryId")
        check(deliveryId.matches(Regex("[a-fA-F0-9]{64}"))) { "Invalid server delivery identifier." }
        val grant = response.optJSONObject("grant") ?: error("Missing verified purchase grant.")
        val coins = grant.optLong("coins", -1)
        val gems = grant.optLong("gems", -1)
        check(coins in 0..Int.MAX_VALUE.toLong() && gems in 0..Int.MAX_VALUE.toLong()) {
            "Invalid verified currency amount."
        }
        val prefs = prefs(context)
        val ledger = prefs.getStringSet(DELIVERIES, emptySet())!!.toMutableSet()
        val key = "$accountUid:$deliveryId"
        val newlyApplied = !ledger.contains(key)
        val editor = prefs.edit()
        if (newlyApplied) {
            val totalCoins = prefs.getInt("coins", 0).toLong() + coins
            val totalGems = prefs.getInt("gems", 0).toLong() + gems
            check(totalCoins <= Int.MAX_VALUE && totalGems <= Int.MAX_VALUE) { "Wallet capacity exceeded." }
            ledger.add(key)
            editor.putInt("coins", totalCoins.toInt()).putInt("gems", totalGems.toInt())
                .putStringSet(DELIVERIES, ledger)
        }
        val pending = JSONObject(prefs.getString(PENDING, "{}")!!)
        pending.put(key, JSONObject().put("productId", productId).put("purchaseToken", purchaseToken)
            .put("coins", coins).put("gems", gems).put("needsSettlement", needsSettlement))
        editor.putString(PENDING, pending.toString())
        writeEntitlement(editor, accountUid, response)
        if (productId == "pack_starter" || productId == "packstarter") editor.putBoolean(STARTER, true)
        check(editor.commit()) { "Could not save the verified purchase. Please restore purchases." }
        return newlyApplied
    }

    @Synchronized
    fun applyRestore(context: Context, accountUid: String, response: JSONObject) {
        check(uid() == accountUid) { "The signed-in account changed. Please try again." }
        check(response.optBoolean("verified") && response.optString("status") == "restored") {
            "Account entitlements could not be verified."
        }
        val editor = prefs(context).edit()
        writeEntitlement(editor, accountUid, response)
        check(editor.commit()) { "Could not save your account entitlements." }
    }

    @Synchronized
    fun applyEntitlementSnapshot(context: Context, accountUid: String, response: JSONObject) {
        check(uid() == accountUid && response.optBoolean("verified")) { "Account verification failed." }
        val editor = prefs(context).edit()
        writeEntitlement(editor, accountUid, response)
        check(editor.commit()) { "Could not save your account entitlements." }
    }

    private fun writeEntitlement(
        editor: android.content.SharedPreferences.Editor,
        accountUid: String,
        response: JSONObject
    ) {
        val entitlement = response.optJSONObject("entitlement") ?: error("Missing verified entitlements.")
        val expiry = entitlement.optLong("expiresAtMillis", 0L)
        editor.putString(OWNER, accountUid)
            .putBoolean(VIP, entitlement.optBoolean("isVip") && expiry > System.currentTimeMillis())
            .putLong(EXPIRY, expiry)
            .putBoolean(CATEGORIES, entitlement.optBoolean("allCategories"))
            .putBoolean(REMOVE_ADS, entitlement.optBoolean("removeAds"))
        if (response.has("starterPurchased")) editor.putBoolean(STARTER, response.optBoolean("starterPurchased"))
    }

    /** Cloud wallet and receipt IDs were read or saved together before these IDs are confirmed. */
    @JvmStatic
    @Synchronized
    fun syncDeliveryIds(context: Context, deliveryIds: List<String>): Boolean {
        val accountUid = uid() ?: return false
        if (deliveryIds.any { !it.matches(Regex("[a-fA-F0-9]{64}")) }) return false
        val prefs = prefs(context)
        val ledger = prefs.getStringSet(DELIVERIES, emptySet())!!.toMutableSet()
        val confirmed = prefs.getStringSet(CONFIRMED, emptySet())!!.toMutableSet()
        deliveryIds.forEach { ledger.add("$accountUid:$it"); confirmed.add("$accountUid:$it") }
        return prefs.edit().putStringSet(DELIVERIES, ledger).putStringSet(CONFIRMED, confirmed).commit()
    }

    @JvmStatic
    @JvmOverloads
    @Synchronized
    fun hydrateWallet(context: Context, accountUid: String, coins: Int, gems: Int,
                      deliveryIds: List<String>, referralRevision: Long? = null): Boolean {
        if (uid() != accountUid || accountUid.isBlank() || coins < 0 || gems < 0 ||
            (referralRevision != null && referralRevision < 0) ||
            deliveryIds.any { !it.matches(Regex("[a-fA-F0-9]{64}")) }) return false
        val prefs = prefs(context)
        if (referralRevision != null && referralRevision < prefs.getLong(REFERRAL_REVISION, 0)) return false
        val ledger = prefs.getStringSet(DELIVERIES, emptySet())!!.toMutableSet()
        val confirmed = prefs.getStringSet(CONFIRMED, emptySet())!!.toMutableSet()
        deliveryIds.forEach { ledger.add("$accountUid:$it"); confirmed.add("$accountUid:$it") }
        val editor = prefs.edit().putInt("coins", coins).putInt("gems", gems)
            .putString(WALLET_OWNER, accountUid).putStringSet(DELIVERIES, ledger)
            .putStringSet(CONFIRMED, confirmed)
        if (referralRevision != null) editor.putLong(REFERRAL_REVISION, referralRevision)
        return editor.commit()
    }

    @JvmStatic
    @Synchronized
    fun applyServerCurrency(context: Context, accountUid: String, coins: Int, gems: Int,
                            referralRevision: Long): Boolean {
        if (uid() != accountUid || accountUid != ProgressionAccount.uid(context) ||
            coins < 0 || gems < 0 || referralRevision < 0) return false
        val prefs = prefs(context)
        if (referralRevision < prefs.getLong(REFERRAL_REVISION, 0)) return false
        return prefs.edit().putInt("coins", coins).putInt("gems", gems)
            .putLong(REFERRAL_REVISION, referralRevision).commit()
    }

    fun isWalletHydrated(context: Context): Boolean {
        val accountUid = uid() ?: return false
        return prefs(context).getString(WALLET_OWNER, "") == accountUid
    }

    @JvmStatic
    @Synchronized
    fun invalidateWalletHydration(context: Context) {
        prefs(context).edit().remove(WALLET_OWNER).commit()
    }

    data class PendingSettlement(val key: String, val productId: String, val token: String,
                                 val needsSettlement: Boolean)

    fun pendingConfirmed(context: Context): List<PendingSettlement> {
        val accountUid = uid() ?: return emptyList()
        val prefs = prefs(context)
        val confirmed = prefs.getStringSet(CONFIRMED, emptySet())!!
        val pending = JSONObject(prefs.getString(PENDING, "{}")!!)
        return pending.keys().asSequence().filter { it.startsWith("$accountUid:") && it in confirmed }.map {
            val receipt = pending.getJSONObject(it)
            PendingSettlement(it, receipt.getString("productId"), receipt.getString("purchaseToken"),
                receipt.optBoolean("needsSettlement", true))
        }.toList()
    }

    @Synchronized
    fun markSettled(context: Context, key: String) {
        val prefs = prefs(context)
        val pending = JSONObject(prefs.getString(PENDING, "{}")!!)
        pending.remove(key)
        check(prefs.edit().putString(PENDING, pending.toString()).commit()) { "Could not save purchase settlement." }
    }

    /** Gameplay reset keeps purchase receipts, so spent currency cannot be delivered twice. */
    @JvmStatic
    @Synchronized
    fun resetGameplayProgress(context: Context) {
        val prefs = prefs(context)
        val editor = prefs.edit()
        prefs.all.keys.filterNot { it.startsWith(PREFIX) }.forEach(editor::remove)
        check(editor.commit()) { "Could not reset gameplay progress." }
    }

    @Synchronized
    fun exchangeGemsForCoins(context: Context, coins: Int, gems: Int): Boolean {
        if (coins <= 0 || gems <= 0) return false
        val prefs = prefs(context)
        val balanceGems = prefs.getInt("gems", 0)
        val nextCoins = prefs.getInt("coins", 0).toLong() + coins
        if (balanceGems < gems || nextCoins > Int.MAX_VALUE) return false
        return prefs.edit().putInt("coins", nextCoins.toInt()).putInt("gems", balanceGems - gems).commit()
    }
}
