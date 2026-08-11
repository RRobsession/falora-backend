package com.rrlime.falora

import android.app.Activity
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.QueryProductDetailsParams
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.text.NumberFormat
import java.util.Currency
import java.util.Locale

class PlayOfferPriceHandler(private val activity: Activity) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "queryOfferPrices" -> {
                @Suppress("UNCHECKED_CAST")
                val productIds = call.argument<List<String>>("productIds") ?: emptyList()
                if (productIds.isEmpty()) {
                    result.success(emptyMap<String, Any>())
                    return
                }
                queryOfferPrices(productIds, result)
            }

            else -> result.notImplemented()
        }
    }

    private fun queryOfferPrices(
        productIds: List<String>,
        result: MethodChannel.Result,
    ) {
        val billingClient = BillingClient.newBuilder(activity)
            .setListener { _, _ -> }
            .enablePendingPurchases(
                PendingPurchasesParams.newBuilder()
                    .enableOneTimeProducts()
                    .build(),
            )
            .build()

        billingClient.startConnection(
            object : BillingClientStateListener {
                override fun onBillingSetupFinished(billingResult: BillingResult) {
                    if (billingResult.responseCode != BillingClient.BillingResponseCode.OK) {
                        billingClient.endConnection()
                        result.error(
                            "billing_unavailable",
                            billingResult.debugMessage,
                            null,
                        )
                        return
                    }

                    val params = QueryProductDetailsParams.newBuilder()
                        .setProductList(
                            productIds.map { productId ->
                                QueryProductDetailsParams.Product.newBuilder()
                                    .setProductId(productId)
                                    .setProductType(BillingClient.ProductType.INAPP)
                                    .build()
                            },
                        )
                        .build()

                    billingClient.queryProductDetailsAsync(params) { queryResult, detailsResult ->
                        billingClient.endConnection()

                        if (queryResult.responseCode != BillingClient.BillingResponseCode.OK) {
                            result.error(
                                "query_failed",
                                queryResult.debugMessage,
                                null,
                            )
                            return@queryProductDetailsAsync
                        }

                        val payload = linkedMapOf<String, Map<String, String?>>()
                        for (productDetails in detailsResult.productDetailsList) {
                            val offerInfo = bestOneTimeOffer(productDetails) ?: continue
                            payload[productDetails.productId] = offerInfo
                        }
                        result.success(payload)
                    }
                }

                override fun onBillingServiceDisconnected() {
                    // Retry is handled by the caller on next shop open.
                }
            },
        )
    }

    private fun bestOneTimeOffer(
        productDetails: ProductDetails,
    ): Map<String, String?>? {
        val offers = productDetails.oneTimePurchaseOfferDetailsList
            ?.takeIf { it.isNotEmpty() }
            ?: productDetails.oneTimePurchaseOfferDetails?.let { listOf(it) }
            ?: return null

        val selected = offers.minByOrNull { it.priceAmountMicros } ?: return null
        val compareAt = selected.fullPriceMicros
            ?.takeIf { it > selected.priceAmountMicros }
            ?.let { formatPrice(it, selected.priceCurrencyCode) }
            ?: offers.maxByOrNull { it.priceAmountMicros }
                ?.takeIf { it.priceAmountMicros > selected.priceAmountMicros }
                ?.formattedPrice

        return linkedMapOf(
            "price" to selected.formattedPrice,
            "compareAtPrice" to compareAt,
            "offerToken" to selected.offerToken,
        )
    }

    private fun formatPrice(priceMicros: Long, currencyCode: String): String {
        val amount = priceMicros / 1_000_000.0
        return try {
            val locale = Locale("tr", "TR")
            val format = NumberFormat.getCurrencyInstance(locale)
            format.currency = Currency.getInstance(currencyCode)
            format.format(amount)
        } catch (_: Exception) {
            String.format(Locale.US, "%.2f %s", amount, currencyCode)
        }
    }
}
