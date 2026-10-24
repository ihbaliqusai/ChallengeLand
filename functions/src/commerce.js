"use strict";

const {
  CommerceError, validateInput, resolveProduct, assertAccountBinding, sha256, currentEntitlement,
} = require("./domain");
const { refresh } = require("./economy");

/**
 * Dependencies are injected so accounting and ownership can be tested without
 * production credentials. Raw Play tokens only enter the private token vault.
 */
function createCommerceService({ db, verifier, packageName, legacyVipIds = [], now = Date.now }) {
  const accountRef = (uid) => db.doc(`commerce_accounts/${uid}`);
  const entitlementRef = (uid) => db.doc(`commerce_accounts/${uid}/entitlements/current`);
  const transactionRef = (uid, hash) => db.doc(`commerce_accounts/${uid}/transactions/${hash}`);
  const tokenRef = (hash) => db.doc(`commerce_purchase_tokens/${hash}`);
  const resources = ["keys", "hearts", "tickets"];
  const serverResourceProduct = product => product.type === "consumable" &&
    !product.coins && !product.gems && resources.some(key => product[key] > 0);

  function assertUid(uid) {
    if (typeof uid !== "string" || !uid || uid.includes("/")) {
      throw new CommerceError("unauthenticated", "Sign in to your game account before buying.");
    }
  }

  async function persist(uid, product, token, receipt) {
    const hash = sha256(token);
    const observedAtMillis = now();
    return db.runTransaction(async (transaction) => {
      const [tokenSnapshot, accountSnapshot, entitlementSnapshot, purchaseSnapshot, economySnapshot] = await Promise.all([
        transaction.get(tokenRef(hash)),
        transaction.get(accountRef(uid)),
        transaction.get(entitlementRef(uid)),
        transaction.get(transactionRef(uid, hash)),
        transaction.get(db.doc(`economy_accounts/${uid}`)),
      ]);
      const previousToken = tokenSnapshot.exists ? tokenSnapshot.data() : undefined;
      const previousPurchase = purchaseSnapshot.exists ? purchaseSnapshot.data() : undefined;
      const account = accountSnapshot.exists ? accountSnapshot.data() : {};
      const rights = entitlementSnapshot.exists ? entitlementSnapshot.data() : {};
      assertAccountBinding(uid, receipt, previousToken);
      if (previousToken && previousToken.productId !== product.id) {
        throw new CommerceError("permission-denied", "The purchase token is already assigned to a different product.");
      }
      if (previousToken?.status === "superseded" ||
          (receipt.checkedAtMillis && previousToken?.checkedAtMillis > receipt.checkedAtMillis)) {
        const status = previousToken.status === "superseded" ? "revoked" : previousPurchase?.status || previousToken.status;
        return {
          verified: true, status, deliveryId: hash,
          grant: status === "delivered" ? previousPurchase?.grant || { coins: 0, gems: 0 } : { coins: 0, gems: 0 },
          entitlement: currentEntitlement(rights, observedAtMillis),
          starterPurchased: account.starterPurchased === true,
        };
      }
      if (previousToken?.revokedPermanently && product.type !== "subscription") receipt.state = "revoked";
      // Subscription changes link old/new tokens. Never let a linked token
      // transfer a paid subscription to a second game account.
      let linkedToken;
      if (receipt.linkedTokenHash && receipt.linkedTokenHash !== hash) {
        const linked = await transaction.get(tokenRef(receipt.linkedTokenHash));
        linkedToken = linked.exists ? linked.data() : undefined;
        if (linkedToken && linkedToken.uid !== uid) {
          throw new CommerceError("permission-denied", "The previous subscription belongs to another game account.");
        }
      }
      if (receipt.state === "pending") {
        // No wallet grant, starter flag, or entitlement is delivered while pending.
        transaction.set(tokenRef(hash), {
          ...(previousToken || {}), uid, productId: product.id, storeId: product.storeId,
          token, type: product.type, status: "pending", updatedAtMillis: observedAtMillis,
          checkedAtMillis: receipt.checkedAtMillis || observedAtMillis,
        });
        return {
          verified: true, status: "pending", deliveryId: hash,
          grant: { coins: 0, gems: 0 }, entitlement: currentEntitlement(rights, observedAtMillis),
          starterPurchased: account.starterPurchased === true,
        };
      }
      if (receipt.state === "purchased" && receipt.consumed && !previousPurchase) {
        throw new CommerceError("failed-precondition", "A consumed legacy purchase cannot create a new wallet grant.");
      }
      if (receipt.state === "purchased" && !previousPurchase && product.oncePerAccount && account.starterPurchased) {
        throw new CommerceError("already-exists", "The starter bundle has already been purchased on this account.");
      }

      const granted = receipt.state === "purchased" && !previousPurchase;
      const grant = previousPurchase?.grant || {
        coins: granted ? product.coins : 0,
        gems: granted ? product.gems : 0,
      };
      if (granted && resources.some(key => product[key])) {
        const wallet = refresh(economySnapshot.data(), observedAtMillis);
        if (resources.some(key => product[key] && wallet[key] + product[key] > 2147483647)) {
          // Leave the Play purchase undelivered and retryable. Charging for a
          // full pack while silently clipping its contents loses paid items.
          throw new CommerceError("failed-precondition", "Spend some resources before retrying this purchase delivery; the balance limit would be exceeded.");
        }
        for (const key of resources) {
          if (product[key]) {
            grant[key] = product[key];
            wallet[key] += product[key];
          }
        }
        wallet.revision++;
        transaction.set(db.doc(`economy_accounts/${uid}`), wallet);
      }
      const active = receipt.state === "purchased";
      const updatedRights = {
        ...rights,
        schemaVersion: 1,
        subscriptions: { ...(rights.subscriptions || {}) },
        categoryPurchases: { ...(rights.categoryPurchases || {}) },
        adFreePurchases: { ...(rights.adFreePurchases || {}) },
      };
      if (product.type === "subscription") {
        updatedRights.subscriptions[hash] = {
          active, expiresAtMillis: receipt.expiresAtMillis,
          autoRenewing: receipt.autoRenewing, productId: product.id,
          state: receipt.subscriptionState, updatedAtMillis: observedAtMillis,
        };
        if (linkedToken && updatedRights.subscriptions[receipt.linkedTokenHash]) {
          updatedRights.subscriptions[receipt.linkedTokenHash].active = false;
          transaction.set(tokenRef(receipt.linkedTokenHash), {
            supersededBy: hash, status: "superseded", updatedAtMillis: observedAtMillis,
          }, { merge: true });
        }
      }
      if (product.allCategories) updatedRights.categoryPurchases[hash] = { active, productId: product.id };
      if (product.removeAds) updatedRights.adFreePurchases[hash] = { active, productId: product.id };
      const entitlement = currentEntitlement(updatedRights, observedAtMillis);
      Object.assign(updatedRights, entitlement, { updatedAtMillis: observedAtMillis });

      transaction.set(entitlementRef(uid), updatedRights);
      const createdAtMillis = previousPurchase?.createdAtMillis || observedAtMillis;
      transaction.set(transactionRef(uid, hash), {
        schemaVersion: 1, deliveryId: hash, productId: product.id, storeId: product.storeId,
        type: product.type, grant, status: active ? "delivered" : "revoked",
        orderId: receipt.orderId, expiresAtMillis: receipt.expiresAtMillis,
        purchasedAtMillis: receipt.purchasedAtMillis,
        createdAtMillis, updatedAtMillis: observedAtMillis,
        // Currencies remain local in this game. Store a refund record for reconciliation;
        // never falsely claim to have clawed back an already spent local balance.
        ...(receipt.state === "revoked" && (grant.coins || grant.gems || grant.keys || grant.hearts || grant.tickets) ? { walletReviewRequired: true } : {}),
      });
      transaction.set(tokenRef(hash), {
        ...(previousToken || {}), uid, productId: product.id, storeId: product.storeId,
        token, type: product.type, status: active ? "delivered" : "revoked",
        expiresAtMillis: receipt.expiresAtMillis, updatedAtMillis: observedAtMillis,
        checkedAtMillis: receipt.checkedAtMillis || observedAtMillis,
        revokedPermanently: previousToken?.revokedPermanently === true ||
          (receipt.state === "revoked" && product.type !== "subscription"),
        ...(serverResourceProduct(product) ? {
          resourceSettlementPending: active && !receipt.consumed && !previousToken?.resourceConsumedAtMillis,
          ...(receipt.consumed ? { resourceConsumedAtMillis: previousToken?.resourceConsumedAtMillis || observedAtMillis } : {}),
        } : {}),
      });
      transaction.set(accountRef(uid), {
        ...account, schemaVersion: 1, uid, updatedAtMillis: observedAtMillis,
        starterPurchased: account.starterPurchased === true || (granted && product.oncePerAccount === true),
        grantedCoins: (account.grantedCoins || 0) + (granted ? grant.coins : 0),
        grantedGems: (account.grantedGems || 0) + (granted ? grant.gems : 0),
      });
      return {
        verified: true, status: active ? "delivered" : "revoked", deliveryId: hash,
        // Repeating delivery returns its original grant, enabling crash recovery.
        // Revoked purchases never cause a fresh local credit.
        grant: active ? grant : { coins: 0, gems: 0 }, entitlement,
        starterPurchased: account.starterPurchased === true || (granted && product.oncePerAccount === true),
      };
    });
  }

  async function settleResources(uid, product, token, result) {
    if (!serverResourceProduct(product) || result.status !== "delivered") return;
    const hash = sha256(token);
    const at = now();
    const claimed = await db.runTransaction(async transaction => {
      const [vaultDoc, purchaseDoc] = await Promise.all([
        transaction.get(tokenRef(hash)), transaction.get(transactionRef(uid, hash)),
      ]);
      const vault = vaultDoc.data();
      const purchase = purchaseDoc.data();
      // Settlement always follows a durable complete server grant. A short
      // lease avoids duplicate API calls from concurrent app/RTDN requests;
      // process death leaves a durable pending marker for the scheduled retry.
      if (!vault || vault.uid !== uid || vault.productId !== product.id ||
          vault.status !== "delivered" || purchase?.status !== "delivered" ||
          resources.some(key => product[key] && purchase.grant?.[key] !== product[key]) ||
          vault.resourceConsumedAtMillis || vault.resourceSettlementLeaseUntilMillis > at) return false;
      transaction.set(tokenRef(hash), {
        resourceSettlementPending: true, resourceSettlementLeaseUntilMillis: at + 60000,
      }, { merge: true });
      return true;
    });
    if (!claimed) return;
    try {
      await verifier.consume(product, token);
      await db.runTransaction(async transaction => {
        const snapshot = await transaction.get(tokenRef(hash));
        if (snapshot.data()?.uid !== uid) return;
        transaction.set(tokenRef(hash), {
          resourceSettlementPending: false, resourceSettlementLeaseUntilMillis: 0,
          resourceConsumedAtMillis: now(), resourceSettlementLastErrorCode: null,
        }, { merge: true });
      });
    } catch (error) {
      await db.runTransaction(async transaction => {
        const snapshot = await transaction.get(tokenRef(hash));
        const vault = snapshot.data();
        if (!vault || vault.uid !== uid || vault.resourceConsumedAtMillis) return;
        transaction.set(tokenRef(hash), {
          resourceSettlementPending: vault.status === "delivered", resourceSettlementLeaseUntilMillis: 0,
          resourceSettlementLastErrorCode: error instanceof CommerceError ? error.code : "internal",
        }, { merge: true });
      });
      throw new CommerceError("unavailable", "Purchase delivery confirmation is temporarily unavailable. Please try again.");
    }
  }

  async function verifyPurchase(uid, data) {
    assertUid(uid);
    const { product, token } = validateInput(data, packageName, legacyVipIds);
    const checkedAtMillis = now();
    const receipt = await verifier.verify(product, token);
    receipt.checkedAtMillis = checkedAtMillis;
    const result = await persist(uid, product, token, receipt);
    await settleResources(uid, product, token, result);
    // Legacy currency settlement still waits for the client's durable wallet
    // snapshot. Resource-only products are safe to settle on the server.
    return result;
  }

  async function refreshToken(vault) {
    if (!vault?.token || !vault.uid || !vault.storeId || vault.status === "superseded") return;
    const product = resolveProduct(vault.storeId, legacyVipIds);
    const checkedAtMillis = now();
    const receipt = await verifier.verify(product, vault.token);
    receipt.checkedAtMillis = checkedAtMillis;
    const result = await persist(vault.uid, product, vault.token, receipt);
    await settleResources(vault.uid, product, vault.token, result);
    return result;
  }

  async function restorePurchases(uid) {
    assertUid(uid);
    const currentRights = await entitlementRef(uid).get();
    const rightsData = currentRights.exists ? currentRights.data() : {};
    const durableHashes = new Set([
      ...Object.keys(rightsData.subscriptions || {}),
      ...Object.keys(rightsData.categoryPurchases || {}),
      ...Object.keys(rightsData.adFreePurchases || {}),
    ]);
    // Restore durable entitlements, not spent consumables. Recheck every owned
    // subscription, including ON_HOLD, because Play can reactivate it.
    for (const hash of durableHashes) {
      const document = await tokenRef(hash).get();
      if (!document.exists) continue;
      const vault = document.data();
      if (vault.type === "subscription" &&
          vault.expiresAtMillis < now() - 59 * 86400000) continue;
      if (vault.type !== "consumable" && vault.status !== "superseded") await refreshToken(vault);
    }
    const [account, rights] = await Promise.all([accountRef(uid).get(), entitlementRef(uid).get()]);
    return {
      verified: true, status: "restored", grant: { coins: 0, gems: 0 },
      entitlement: currentEntitlement(rights.exists ? rights.data() : {}, now()),
      starterPurchased: account.exists && account.data().starterPurchased === true,
    };
  }

  async function processNotification(notification) {
    if (!notification || typeof notification !== "object" || Array.isArray(notification)) {
      throw new CommerceError("invalid-argument", "Invalid purchase notification.");
    }
    if (notification.packageName !== packageName) {
      throw new CommerceError("permission-denied", "The notification belongs to another app.");
    }
    if (notification.testNotification) return { status: "test" };
    const event = notification.subscriptionNotification || notification.oneTimeProductNotification || notification.voidedPurchaseNotification;
    if (!event?.purchaseToken || typeof event.purchaseToken !== "string") return { status: "ignored" };
    const hash = sha256(event.purchaseToken);
    const stored = await tokenRef(hash).get();
    // An unregistered receipt has no proven Firebase owner. A later authenticated
    // verify request will fetch the current Play state and recover the purchase.
    if (!stored.exists) return { status: "unassigned" };
    const vault = stored.data();
    if (notification.voidedPurchaseNotification && vault.type !== "subscription") {
      const product = resolveProduct(vault.storeId, legacyVipIds);
      const checkedAtMillis = now();
      const receipt = await verifier.verify(product, vault.token);
      receipt.checkedAtMillis = checkedAtMillis;
      // For this single-quantity catalog, a full refund revokes permanent rights
      // even if the product API has not yet reflected the cancellation.
      if (event.refundType === undefined || event.refundType === 1) receipt.state = "revoked";
      return persist(vault.uid, product, vault.token, receipt);
    }
    // RTDN is a signal to query the Developer API, never proof of an active purchase.
    return (await refreshToken(vault)) || { status: "superseded" };
  }

  async function refreshSubscriptions() {
    const query = db.collection("commerce_purchase_tokens").where("type", "==", "subscription");
    let cursor;
    let examined = 0;
    let failureCount = 0;
    const failures = [];
    do {
      const page = await (cursor ? query.startAfter(cursor) : query).limit(100).get();
      for (const document of page.docs) {
        examined += 1;
        const vault = document.data();
        if (vault.status === "superseded") continue;
        // Expired subscriptions are unreadable from Play after 60 days. Their
        // known expiry already disables access, regardless of persisted status.
        if (vault.expiresAtMillis < now() - 59 * 86400000) continue;
        try { await refreshToken(vault); } catch (error) {
          failureCount += 1;
          if (failures.length < 50) failures.push({ deliveryId: document.id, code: error.code || "internal" });
        }
      }
      cursor = page.size === 100 ? page.docs.at(-1) : undefined;
    } while (cursor);
    // Resource purchases can complete through RTDN while the app is closed.
    // Retry their durable settlement outbox before Play's acknowledgement
    // window expires; never replay client-delivered coin/gem purchases.
    const pendingResources = db.collection("commerce_purchase_tokens").where("resourceSettlementPending", "==", true);
    cursor = undefined;
    do {
      const page = await (cursor ? pendingResources.startAfter(cursor) : pendingResources).limit(100).get();
      for (const document of page.docs) {
        examined += 1;
        try { await refreshToken(document.data()); } catch (error) {
          failureCount += 1;
          if (failures.length < 50) failures.push({ deliveryId: document.id, code: error.code || "internal" });
        }
      }
      cursor = page.size === 100 ? page.docs.at(-1) : undefined;
    } while (cursor);
    return { examined, failureCount, failures };
  }

  return { verifyPurchase, restorePurchases, processNotification, refreshSubscriptions };
}

module.exports = { createCommerceService };
