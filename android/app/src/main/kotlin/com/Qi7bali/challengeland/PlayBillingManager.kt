package com.qi7bali.landchallengeonline

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.android.billingclient.api.*
import io.flutter.plugin.common.MethodChannel

class PlayBillingManager(
    private val activity: Activity,
    private val channel: MethodChannel
) : PurchasesUpdatedListener {

    companion object {
        private const val TAG = "PlayBillingManager"
    }

    private var billingClient: BillingClient? = null
    private val cachedProductDetails = mutableMapOf<String, ProductDetails>()
    private var isConnected = false
    private val mainHandler = Handler(Looper.getMainLooper())

    private val consumableProductIds = listOf(
        "pack_starter",
        "pack_value",
        "pack_champion",
        "gems_80",
        "gems_500",
        "gems_1200"
    )

    private val subscriptionProductIds = listOf(
        "vip_monthly"
    )

    init {
        setupBillingClient()
    }

    private fun setupBillingClient() {
        try {
            billingClient = BillingClient.newBuilder(activity)
                .setListener(this)
                .enablePendingPurchases(
                    PendingPurchasesParams.newBuilder()
                        .enableOneTimeProducts()
                        .build()
                )
                .build()
            startConnection()
        } catch (e: Exception) {
            Log.e(TAG, "Error creating BillingClient: ${e.message}", e)
        }
    }

    fun startConnection(onReady: (() -> Unit)? = null) {
        val client = billingClient ?: return
        if (isConnected) {
            onReady?.invoke()
            return
        }

        client.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(billingResult: BillingResult) {
                if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    isConnected = true
                    Log.d(TAG, "BillingClient 8.0.0 connected successfully")
                    queryAllProducts(onReady)
                } else {
                    Log.e(TAG, "Billing setup failed: ${billingResult.debugMessage} (code: ${billingResult.responseCode})")
                }
            }

            override fun onBillingServiceDisconnected() {
                isConnected = false
                Log.w(TAG, "Billing service disconnected. Will reconnect on demand.")
            }
        })
    }

    fun queryAllProducts(onComplete: (() -> Unit)? = null) {
        val client = billingClient ?: return

        // 1. Query One-time In-App products
        val inAppList = consumableProductIds.map { id ->
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(id)
                .setProductType(BillingClient.ProductType.INAPP)
                .build()
        }
        val inAppParams = QueryProductDetailsParams.newBuilder().setProductList(inAppList).build()

        client.queryProductDetailsAsync(inAppParams) { billingResult, queryResult ->
            if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                for (p in queryResult.productDetailsList) {
                    cachedProductDetails[p.productId] = p
                    cachedProductDetails[p.productId.replace("_", "").lowercase()] = p
                }
                Log.d(TAG, "Loaded in-app products: ${queryResult.productDetailsList.map { it.productId }}")
            } else {
                Log.e(TAG, "Query in-app failed: ${billingResult.debugMessage} (code: ${billingResult.responseCode})")
            }

            // 2. Query Subscriptions
            val subList = subscriptionProductIds.map { id ->
                QueryProductDetailsParams.Product.newBuilder()
                    .setProductId(id)
                    .setProductType(BillingClient.ProductType.SUBS)
                    .build()
            }
            val subParams = QueryProductDetailsParams.newBuilder().setProductList(subList).build()

            client.queryProductDetailsAsync(subParams) { subResult, subQueryResult ->
                if (subResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    for (p in subQueryResult.productDetailsList) {
                        cachedProductDetails[p.productId] = p
                        cachedProductDetails[p.productId.replace("_", "").lowercase()] = p
                    }
                    Log.d(TAG, "Loaded subscription products: ${subQueryResult.productDetailsList.map { it.productId }}")
                } else {
                    Log.e(TAG, "Query subscriptions failed: ${subResult.debugMessage} (code: ${subResult.responseCode})")
                }

                mainHandler.post {
                    onComplete?.invoke()
                }
            }
        }
    }

    fun launchBilling(productId: String, callback: (Boolean, String) -> Unit) {
        if (!isConnected || billingClient == null) {
            startConnection {
                launchBillingInternal(productId, callback)
            }
            return
        }
        launchBillingInternal(productId, callback)
    }

    private fun launchBillingInternal(productId: String, callback: (Boolean, String) -> Unit) {
        val cleanId = productId.replace("_", "").lowercase()
        val details = cachedProductDetails[productId] ?: cachedProductDetails[cleanId]

        if (details == null) {
            // Direct targeted query for this product
            val client = billingClient
            if (client == null) {
                callback(false, "خدمة Google Play غير جاهزة حالياً")
                return
            }

            val isSub = subscriptionProductIds.any { it.replace("_", "").lowercase() == cleanId }
            val productType = if (isSub) BillingClient.ProductType.SUBS else BillingClient.ProductType.INAPP
            val targetParams = QueryProductDetailsParams.newBuilder()
                .setProductList(
                    listOf(
                        QueryProductDetailsParams.Product.newBuilder()
                            .setProductId(productId)
                            .setProductType(productType)
                            .build()
                    )
                )
                .build()

            client.queryProductDetailsAsync(targetParams) { billingResult, queryResult ->
                val found = queryResult.productDetailsList.firstOrNull()
                mainHandler.post {
                    if (found != null) {
                        cachedProductDetails[found.productId] = found
                        cachedProductDetails[found.productId.replace("_", "").lowercase()] = found
                        startFlowWithDetails(found, callback)
                    } else {
                        val unfetched = queryResult.unfetchedProductList.map { it.productId }
                        val errorDetail = if (unfetched.isNotEmpty()) {
                            "لم يتم العثور على: $unfetched"
                        } else {
                            "رمز المتجر: ${billingResult.responseCode}"
                        }
                        callback(false, "هذا المنتج غير مفعّل أو غير متاح في متجر Google Play ($errorDetail)")
                    }
                }
            }
            return
        }

        startFlowWithDetails(details, callback)
    }

    private fun startFlowWithDetails(productDetails: ProductDetails, callback: (Boolean, String) -> Unit) {
        val productDetailsParamsBuilder = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(productDetails)

        if (productDetails.productType == BillingClient.ProductType.SUBS) {
            val offerToken = productDetails.subscriptionOfferDetails?.firstOrNull()?.offerToken
            if (offerToken != null) {
                productDetailsParamsBuilder.setOfferToken(offerToken)
            }
        }

        val flowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(productDetailsParamsBuilder.build()))
            .build()

        val result = billingClient?.launchBillingFlow(activity, flowParams)
        val ok = result?.responseCode == BillingClient.BillingResponseCode.OK
        mainHandler.post {
            if (ok) {
                callback(true, "")
            } else {
                callback(false, "تعذر فتح نافذة الدفع (رمز: ${result?.responseCode})")
            }
        }
    }

    override fun onPurchasesUpdated(billingResult: BillingResult, purchases: List<Purchase>?) {
        if (billingResult.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
            for (purchase in purchases) {
                handlePurchase(purchase)
            }
        } else if (billingResult.responseCode == BillingClient.BillingResponseCode.USER_CANCELED) {
            Log.d(TAG, "User canceled billing flow")
        } else {
            Log.e(TAG, "Purchase failed: ${billingResult.debugMessage} (code: ${billingResult.responseCode})")
        }
    }

    private fun handlePurchase(purchase: Purchase) {
        if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED) {
            val deliveryKey = purchase.orderId ?: purchase.purchaseToken
            for (productId in purchase.products) {
                MainActivity.deliverPurchaseDirectly(activity, productId, deliveryKey)
                mainHandler.post {
                    channel.invokeMethod("onPurchaseDelivered", mapOf("productId" to productId))
                }
            }

            // Consume consumable items so they can be bought again
            val isConsumable = purchase.products.any { p ->
                val clean = p.replace("_", "").lowercase()
                consumableProductIds.any { it.replace("_", "").lowercase() == clean }
            }

            if (isConsumable) {
                val consumeParams = ConsumeParams.newBuilder()
                    .setPurchaseToken(purchase.purchaseToken)
                    .build()
                billingClient?.consumeAsync(consumeParams) { result, _ ->
                    Log.d(TAG, "Purchase consumed: ${result.responseCode}")
                }
            } else if (!purchase.isAcknowledged) {
                val ackParams = AcknowledgePurchaseParams.newBuilder()
                    .setPurchaseToken(purchase.purchaseToken)
                    .build()
                billingClient?.acknowledgePurchase(ackParams) { result ->
                    Log.d(TAG, "Subscription purchase acknowledged: ${result.responseCode}")
                }
            }
        }
    }

    fun isAvailable(): Boolean = isConnected

    fun getLoadedProductIds(): List<String> = cachedProductDetails.keys.toList()
}
