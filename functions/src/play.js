"use strict";

const { CommerceError, normalizeProductReceipt, normalizeSubscriptionReceipt } = require("./domain");

function createPlayVerifier({ publisher, packageName, now = Date.now }) {
  const verifier = {
    async verify(product, token) {
      try {
        if (product.type === "subscription") {
          const { data } = await publisher.purchases.subscriptionsv2.get({ packageName, token });
          return normalizeSubscriptionReceipt(data, product, now());
        }
        const { data } = await publisher.purchases.products.get({
          packageName, productId: product.storeId, token,
        });
        return normalizeProductReceipt(data, product);
      } catch (error) {
        if (error instanceof CommerceError) throw error;
        const status = Number(error.response?.status || error.code);
        // Never forward Google's error message: it can contain a URL with the purchase token.
        if ([400, 404, 410].includes(status)) {
          throw new CommerceError("failed-precondition", "Google Play could not verify this purchase.");
        }
        if ([401, 403].includes(status)) {
          throw new CommerceError("unavailable", "Purchase verification is not configured correctly. Please try later.");
        }
        throw new CommerceError("unavailable", "Google Play verification is temporarily unavailable.");
      }
    },
    async consume(product, token) {
      if (product.type !== "consumable") {
        throw new CommerceError("invalid-argument", "Only consumable purchases can be consumed.");
      }
      try {
        await publisher.purchases.products.consume({ packageName, productId: product.storeId, token });
      } catch (error) {
        // A client may have consumed concurrently, or Google's successful
        // response may have been lost. Confirm the state instead of treating
        // an already consumed purchase as a failed delivery.
        try {
          const current = await verifier.verify(product, token);
          if (current.state === "purchased" && current.consumed) return;
        } catch (_) { /* Retry later without exposing Play URLs or tokens. */ }
        throw new CommerceError("unavailable", "Purchase delivery confirmation is temporarily unavailable. Please try again.");
      }
    },
  };
  return verifier;
}

module.exports = { createPlayVerifier };
