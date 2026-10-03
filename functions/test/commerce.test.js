"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  sha256, resolveProduct, assertAccountBinding, normalizeProductReceipt,
  normalizeSubscriptionReceipt, currentEntitlement,
} = require("../src/domain");
const { createCommerceService } = require("../src/commerce");
const { createPlayVerifier } = require("../src/play");
const { MemoryFirestore } = require("./memory-firestore");

const uid = "player-account-1";
const packageName = "com.qi7bali.landchallengeonline";
const clock = 1800000000000;

function receipt(overrides = {}) {
  return {
    state: "purchased", accountId: sha256(uid), consumed: false, acknowledged: true,
    orderId: "GPA.order-1", purchasedAtMillis: clock - 100,
    expiresAtMillis: 0, autoRenewing: false, linkedTokenHash: null,
    ...overrides,
  };
}

function harness() {
  const db = new MemoryFirestore();
  const receipts = new Map();
  const acknowledgements = [];
  const verifier = {
    verify: async (product, token) => structuredClone(receipts.get(token) || receipt()),
    acknowledge: async (product, token) => acknowledgements.push({ product, token }),
  };
  const service = createCommerceService({ db, verifier, packageName, now: () => clock });
  const buy = (productId, token = productId, data = {}, owner = uid) =>
    service.verifyPurchase(owner, { productId, purchaseToken: token, ...data });
  return { db, service, receipts, acknowledgements, buy };
}

test("explicit aliases preserve old SKU quantities and unconfigured VIP IDs fail closed", () => {
  assert.equal(resolveProduct("gems6500").gems, 6500);
  assert.equal(resolveProduct("packvalue").coins, 35000);
  assert.equal(resolveProduct("packvalue").gems, 600);
  assert.equal(resolveProduct("vipmonthly").type, "subscription");
  assert.throws(() => resolveProduct("vippass"), { code: "invalid-argument" });
  assert.equal(resolveProduct("vippass", ["vippass"]).type, "subscription");
  assert.throws(() => resolveProduct("gems_999999"), { code: "invalid-argument" });
  assert.equal(resolveProduct("noads").removeAds, true);
  assert.equal(resolveProduct("noads").type, "nonconsumable");
});

test("account binding is mandatory and legacy migration is owner-locked", () => {
  assertAccountBinding(uid, receipt(), undefined);
  assert.throws(() => assertAccountBinding(uid, receipt({ accountId: null })), { code: "failed-precondition" });
  assert.throws(() => assertAccountBinding(uid, receipt({ accountId: sha256("attacker") })), { code: "permission-denied" });
  assertAccountBinding(uid, receipt({ accountId: null }), { uid, allowLegacyBinding: true });
  assert.throws(() => assertAccountBinding("attacker", receipt({ accountId: null }), { uid, allowLegacyBinding: true }), { code: "permission-denied" });
});

test("product normalization rejects a different SKU, unknown states, and multiple quantities", () => {
  const product = resolveProduct("gems_80");
  assert.equal(normalizeProductReceipt({ purchaseState: 2 }, product).state, "pending");
  assert.equal(normalizeProductReceipt({ purchaseState: 1 }, product).state, "revoked");
  assert.throws(() => normalizeProductReceipt({ purchaseState: 0, productId: "gems_500" }, product), { code: "permission-denied" });
  assert.throws(() => normalizeProductReceipt({ purchaseState: 3 }, product), { code: "failed-precondition" });
  assert.throws(() => normalizeProductReceipt({ purchaseState: 0, quantity: 2 }, product), { code: "failed-precondition" });
});

test("subscriptions preserve canceled-but-paid access and revoke hold, paused, pending, and expired", () => {
  const product = resolveProduct("vip_monthly");
  const raw = {
    lineItems: [{ productId: "vip_monthly", expiryTime: new Date(clock + 5000).toISOString() }],
    externalAccountIdentifiers: { obfuscatedExternalAccountId: sha256(uid) },
  };
  for (const state of ["ACTIVE", "CANCELED", "IN_GRACE_PERIOD"]) {
    assert.equal(normalizeSubscriptionReceipt({ ...raw, subscriptionState: `SUBSCRIPTION_STATE_${state}` }, product, clock).state, "purchased");
  }
  for (const state of ["ON_HOLD", "PAUSED", "EXPIRED", "UNSPECIFIED", "PENDING_PURCHASE_CANCELED"]) {
    assert.equal(normalizeSubscriptionReceipt({ ...raw, subscriptionState: `SUBSCRIPTION_STATE_${state}` }, product, clock).state, "revoked");
  }
  assert.equal(normalizeSubscriptionReceipt({ ...raw, subscriptionState: "SUBSCRIPTION_STATE_PENDING" }, product, clock).state, "pending");
  assert.equal(normalizeSubscriptionReceipt({ ...raw, subscriptionState: "SUBSCRIPTION_STATE_ACTIVE" }, product, clock + 6000).state, "revoked");
});

test("server catalog ignores client grant amounts and retries return original delivery once", async () => {
  const { db, buy } = harness();
  const first = await buy("pack_value", "receipt-1", { grant: { gems: 1000000 }, coins: 99999999 });
  const duplicate = await buy("packvalue", "receipt-1");
  assert.deepEqual(first.grant, { coins: 35000, gems: 600 });
  assert.deepEqual(duplicate.grant, first.grant);
  assert.equal(first.deliveryId, duplicate.deliveryId);
  assert.equal(db.read(`commerce_accounts/${uid}`).grantedCoins, 35000);
  assert.equal(db.read(`commerce_accounts/${uid}`).grantedGems, 600);
  const ledger = db.read(`commerce_accounts/${uid}/transactions/${first.deliveryId}`);
  assert.equal(ledger.purchaseToken, undefined);
  assert.equal(ledger.token, undefined);
});

test("pending purchase gives no currency or starter eligibility flag until purchased", async () => {
  const { db, buy, receipts } = harness();
  receipts.set("pending-1", receipt({ state: "pending" }));
  const pending = await buy("pack_starter", "pending-1");
  assert.equal(pending.status, "pending");
  assert.deepEqual(pending.grant, { coins: 0, gems: 0 });
  assert.equal(pending.starterPurchased, false);
  assert.equal(db.read(`commerce_accounts/${uid}`), undefined);
  receipts.set("pending-1", receipt());
  const purchased = await buy("pack_starter", "pending-1");
  assert.equal(purchased.status, "delivered");
  assert.deepEqual(purchased.grant, { coins: 10000, gems: 100 });
  assert.equal(purchased.starterPurchased, true);
});

test("concurrent starter tokens cannot both grant on the same account", async () => {
  const { db, buy } = harness();
  const results = await Promise.allSettled([
    buy("pack_starter", "starter-a"), buy("packstarter", "starter-b"),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(results.find((r) => r.status === "rejected").reason.code, "already-exists");
  assert.equal(db.read(`commerce_accounts/${uid}`).grantedGems, 100);
});

test("another account or product cannot take ownership of an already delivered token", async () => {
  const { buy } = harness();
  await buy("gems_80", "owned-token");
  await assert.rejects(buy("gems_80", "owned-token", {}, "attacker"), { code: "permission-denied" });
  await assert.rejects(buy("gems_500", "owned-token"), { code: "permission-denied" });
  await assert.rejects(buy("gems_80", "new-token", { packageName: "foreign.package" }), { code: "permission-denied" });
});

test("a previously consumed token cannot mint currency; existing ledger still recovers a duplicate", async () => {
  const { receipts, buy } = harness();
  receipts.set("consumed", receipt({ consumed: true }));
  await assert.rejects(buy("gems_80", "consumed"), { code: "failed-precondition" });
  await buy("gems_80", "delivered");
  receipts.set("delivered", receipt({ consumed: true }));
  assert.deepEqual((await buy("gems_80", "delivered")).grant, { coins: 0, gems: 80 });
});

test("account restore refreshes subscription rights and never replays currency grants", async () => {
  const { service, receipts, buy, db } = harness();
  await buy("gems_500", "spent-coins");
  await buy("category_all_access", "category-lifetime");
  await buy("noads", "ads-lifetime");
  receipts.set("vip", receipt({ expiresAtMillis: clock + 10000, subscriptionState: "SUBSCRIPTION_STATE_ACTIVE" }));
  assert.equal((await buy("vip_monthly", "vip")).entitlement.isVip, true);
  receipts.set("vip", receipt({ state: "revoked", expiresAtMillis: clock + 10000, subscriptionState: "SUBSCRIPTION_STATE_ON_HOLD" }));
  const restored = await service.restorePurchases(uid);
  assert.deepEqual(restored.grant, { coins: 0, gems: 0 });
  assert.deepEqual(restored.entitlement, { isVip: false, expiresAtMillis: 0, allCategories: true, removeAds: true });
  assert.equal(db.read(`commerce_accounts/${uid}`).grantedGems, 500);
});

test("refunded permanent rights are revoked even while a stale product API says purchased", async () => {
  const { service, buy } = harness();
  await buy("category_all_access", "category-refund");
  const response = await service.processNotification({
    packageName, voidedPurchaseNotification: { purchaseToken: "category-refund", refundType: 1 },
  });
  assert.equal(response.status, "revoked");
  assert.equal(response.entitlement.allCategories, false);
  const stale = await buy("category_all_access", "category-refund");
  assert.equal(stale.status, "revoked");
  assert.equal(stale.entitlement.allCategories, false);
});

test("currency refunds record reconciliation without claiming a local wallet clawback", async () => {
  const { service, buy, db } = harness();
  const result = await buy("coins_5000", "coins-refund");
  const refunded = await service.processNotification({
    packageName, voidedPurchaseNotification: { purchaseToken: "coins-refund", refundType: 1 },
  });
  assert.deepEqual(refunded.grant, { coins: 0, gems: 0 });
  assert.equal(db.read(`commerce_accounts/${uid}/transactions/${result.deliveryId}`).walletReviewRequired, true);
});

test("replacement subscriptions prevent a second account from claiming a linked token", async () => {
  const { receipts, buy } = harness();
  receipts.set("old", receipt({ expiresAtMillis: clock + 10000, subscriptionState: "SUBSCRIPTION_STATE_ACTIVE" }));
  await buy("vip_monthly", "old");
  receipts.set("new", receipt({ accountId: sha256("attacker"), linkedTokenHash: sha256("old"), expiresAtMillis: clock + 20000, subscriptionState: "SUBSCRIPTION_STATE_ACTIVE" }));
  await assert.rejects(buy("vip_monthly", "new", {}, "attacker"), { code: "permission-denied" });
});

test("superseded subscription tokens cannot reactivate old rights on a delayed query", async () => {
  const { receipts, buy } = harness();
  receipts.set("old", receipt({ expiresAtMillis: clock + 10000, subscriptionState: "SUBSCRIPTION_STATE_ACTIVE" }));
  await buy("vip_monthly", "old");
  receipts.set("new", receipt({ linkedTokenHash: sha256("old"), expiresAtMillis: clock + 20000, subscriptionState: "SUBSCRIPTION_STATE_ACTIVE" }));
  await buy("vip_monthly", "new");
  const late = await buy("vip_monthly", "old");
  assert.equal(late.status, "revoked");
  assert.equal(late.entitlement.expiresAtMillis, clock + 20000);
});

test("runtime entitlement computation rejects stale persisted VIP flags after expiry", () => {
  const result = currentEntitlement({
    isVip: true, allCategories: true,
    subscriptions: { vip: { active: true, expiresAtMillis: clock - 1 } },
    categoryPurchases: {},
  }, clock);
  assert.deepEqual(result, { isVip: false, expiresAtMillis: 0, allCategories: false, removeAds: false });
});

test("Google verifier sanitizes API errors that include purchase token request URLs", async () => {
  const sensitive = "https://api/tokens/SECRET_PURCHASE_TOKEN";
  const publisher = { purchases: { products: { get: async () => { throw Object.assign(new Error(sensitive), { code: 403 }); } } } };
  const verifier = createPlayVerifier({ publisher, packageName });
  await assert.rejects(verifier.verify(resolveProduct("gems_80"), "secret-token"), (error) => {
    assert.equal(error.code, "unavailable");
    assert.equal(error.message.includes("SECRET_PURCHASE_TOKEN"), false);
    return true;
  });
});

test("unknown or foreign RTDN cannot grant rights without an authenticated owner", async () => {
  const { service, db } = harness();
  await assert.rejects(service.processNotification({ packageName: "foreign" }), { code: "permission-denied" });
  await assert.rejects(service.processNotification(null), { code: "invalid-argument" });
  assert.deepEqual(await service.processNotification({ packageName, oneTimeProductNotification: { purchaseToken: "unassigned" } }), { status: "unassigned" });
  assert.equal(db.documents.size, 0);
});

test("a delayed active subscription verification cannot overwrite a newer revocation", async () => {
  const db = new MemoryFirestore();
  let time = clock;
  let releaseActive;
  let verificationStarted;
  const started = new Promise((resolve) => { verificationStarted = resolve; });
  const delayed = new Promise((resolve) => { releaseActive = resolve; });
  const verifier = {
    verify: async () => {
      verificationStarted();
      await delayed;
      return receipt({ expiresAtMillis: clock + 10000, subscriptionState: "SUBSCRIPTION_STATE_ACTIVE" });
    },
  };
  const service = createCommerceService({ db, verifier, packageName, now: () => time });
  const token = "subscription-race";
  const hash = sha256(token);
  const oldResult = service.verifyPurchase(uid, { productId: "vip_monthly", purchaseToken: token });
  await started;
  time += 100;
  db.seed(`commerce_purchase_tokens/${hash}`, {
    uid, productId: "vip_monthly", storeId: "vip_monthly", type: "subscription",
    token, status: "revoked", checkedAtMillis: time,
  });
  db.seed(`commerce_accounts/${uid}/transactions/${hash}`, { status: "revoked", grant: { coins: 0, gems: 0 } });
  db.seed(`commerce_accounts/${uid}/entitlements/current`, {
    subscriptions: { [hash]: { active: false, expiresAtMillis: clock + 10000 } },
  });
  releaseActive();
  const result = await oldResult;
  assert.equal(result.status, "revoked");
  assert.equal(result.entitlement.isVip, false);
});

test("daily reconciliation pages across more than 100 subscriptions without replaying grants", async () => {
  const { service, db } = harness();
  for (let i = 0; i < 101; i += 1) {
    const token = `page-token-${i}`;
    db.seed(`commerce_purchase_tokens/${sha256(token)}`, {
      uid, productId: "vip_monthly", storeId: "vip_monthly", type: "subscription",
      token, status: "delivered", expiresAtMillis: clock + 10000,
    });
  }
  const result = await service.refreshSubscriptions();
  assert.equal(result.examined, 101);
  assert.equal(result.failureCount, 0);
  assert.equal(db.read(`commerce_accounts/${uid}`).grantedGems, 0);
});
