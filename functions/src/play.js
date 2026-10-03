"use strict";

const { CommerceError, normalizeProductReceipt, normalizeSubscriptionReceipt } = require("./domain");

function createPlayVerifier({ publisher, packageName, now = Date.now }) {
  return {
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
  };
}

module.exports = { createPlayVerifier };
