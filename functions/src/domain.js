"use strict";

const { createHash, timingSafeEqual } = require("node:crypto");

class CommerceError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "CommerceError";
    this.code = code;
  }
}

// These are delivered quantities, never client-supplied quantities or prices.
// Preserve amounts sold by previous Android releases under the same SKU.
const PRODUCTS = Object.freeze({
  keys_1: { type: "consumable", coins: 0, gems: 0, keys: 1 },
  hearts_1: { type: "consumable", coins: 0, gems: 0, hearts: 1 },
  tickets_1: { type: "consumable", coins: 0, gems: 0, tickets: 1 },
  keys_10: { type: "consumable", coins: 0, gems: 0, keys: 10 },
  hearts_10: { type: "consumable", coins: 0, gems: 0, hearts: 10 },
  tickets_10: { type: "consumable", coins: 0, gems: 0, tickets: 10 },
  resources_3_each: { type: "consumable", coins: 0, gems: 0, keys: 3, hearts: 3, tickets: 3 },
  resources_10_each: { type: "consumable", coins: 0, gems: 0, keys: 10, hearts: 10, tickets: 10 },
  gems_80: { type: "consumable", coins: 0, gems: 80 },
  gems_500: { type: "consumable", coins: 0, gems: 500 },
  gems_1200: { type: "consumable", coins: 0, gems: 1200 },
  gems_2500: { type: "consumable", coins: 0, gems: 2500 },
  gems_6500: { type: "consumable", coins: 0, gems: 6500 },
  gems_14000: { type: "consumable", coins: 0, gems: 14000 },
  coins_5000: { type: "consumable", coins: 5000, gems: 0 },
  coins_25000: { type: "consumable", coins: 25000, gems: 0 },
  coins_100000: { type: "consumable", coins: 100000, gems: 0 },
  pack_starter: { type: "nonconsumable", coins: 10000, gems: 100, oncePerAccount: true },
  pack_value: { type: "consumable", coins: 35000, gems: 600 },
  pack_champion: { type: "consumable", coins: 100000, gems: 1800 },
  vip_monthly: { type: "subscription", coins: 0, gems: 0 },
  category_all_access: { type: "nonconsumable", coins: 0, gems: 0, allCategories: true },
  noads: { type: "nonconsumable", coins: 0, gems: 0, removeAds: true },
});

const ALIASES = Object.freeze(Object.fromEntries(
  Object.keys(PRODUCTS).map((id) => [id.replaceAll("_", ""), id]),
));

function sha256(value) {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

function resolveProduct(productId, legacyVipIds = []) {
  if (typeof productId !== "string" || !/^[a-z0-9_]{1,100}$/.test(productId)) {
    throw new CommerceError("invalid-argument", "Invalid product ID.");
  }
  const canonicalId = Object.hasOwn(PRODUCTS, productId) ? productId :
    Object.hasOwn(ALIASES, productId) ? ALIASES[productId] : undefined;
  if (canonicalId) return { id: canonicalId, storeId: productId, ...PRODUCTS[canonicalId] };
  if (["vip_pass", "vippass", "vip"].includes(productId) && legacyVipIds.includes(productId)) {
    return { id: "vip_monthly", storeId: productId, ...PRODUCTS.vip_monthly };
  }
  throw new CommerceError("invalid-argument", "This product is not in the server catalog.");
}

function validateInput(data, packageName, legacyVipIds) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new CommerceError("invalid-argument", "Purchase details are required.");
  }
  if (data.packageName !== undefined && data.packageName !== packageName) {
    throw new CommerceError("permission-denied", "The purchase belongs to a different app.");
  }
  const token = data.purchaseToken;
  if (typeof token !== "string" || token.length < 1 || token.length > 4096 || /\s/.test(token)) {
    throw new CommerceError("invalid-argument", "A valid purchase token is required.");
  }
  return { product: resolveProduct(data.productId, legacyVipIds), token, tokenHash: sha256(token) };
}

function assertAccountBinding(uid, receipt, existingToken) {
  if (existingToken && existingToken.uid !== uid) {
    throw new CommerceError("permission-denied", "This purchase belongs to another game account.");
  }
  const bound = receipt.accountId;
  if (!bound) {
    // Only an administrator may seed this owner-locked migration permission.
    if (existingToken?.uid === uid && existingToken.allowLegacyBinding === true) return;
    throw new CommerceError("failed-precondition", "Legacy purchase requires an account ownership review.");
  }
  const actual = Buffer.from(bound, "utf8");
  const expected = Buffer.from(sha256(uid), "utf8");
  if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) {
    throw new CommerceError("permission-denied", "The purchase account does not match your game account.");
  }
}

function normalizeProductReceipt(raw, product) {
  if (!raw || ![0, 1, 2].includes(raw.purchaseState)) {
    throw new CommerceError("failed-precondition", "Play returned an unknown purchase state.");
  }
  if (raw.productId && raw.productId !== product.storeId) {
    throw new CommerceError("permission-denied", "The verified product ID does not match the request.");
  }
  const quantity = raw.quantity === undefined ? 1 : Number(raw.quantity);
  if (quantity !== 1) {
    throw new CommerceError("failed-precondition", "Multiple quantity purchases are not enabled for this catalog.");
  }
  return {
    state: raw.purchaseState === 0 ? "purchased" : raw.purchaseState === 2 ? "pending" : "revoked",
    accountId: raw.obfuscatedExternalAccountId || null,
    consumed: raw.consumptionState === 1,
    acknowledged: raw.acknowledgementState === 1,
    orderId: raw.orderId || null,
    purchasedAtMillis: Number(raw.purchaseTimeMillis) || null,
    expiresAtMillis: 0,
    autoRenewing: false,
    linkedTokenHash: null,
  };
}

function normalizeSubscriptionReceipt(raw, product, nowMillis) {
  if (!raw || !Array.isArray(raw.lineItems)) {
    throw new CommerceError("failed-precondition", "Play returned invalid subscription details.");
  }
  const items = raw.lineItems.filter((item) => item.productId === product.storeId);
  if (!items.length) {
    throw new CommerceError("permission-denied", "The verified subscription does not match the request.");
  }
  const latest = items.reduce((a, b) => Date.parse(a.expiryTime || "") > Date.parse(b.expiryTime || "") ? a : b);
  const expiresAtMillis = Date.parse(latest.expiryTime || "") || 0;
  const state = raw.subscriptionState;
  const pending = state === "SUBSCRIPTION_STATE_PENDING";
  const enabled = [
    "SUBSCRIPTION_STATE_ACTIVE",
    "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
    "SUBSCRIPTION_STATE_CANCELED",
  ].includes(state) && expiresAtMillis > nowMillis;
  return {
    state: pending ? "pending" : enabled ? "purchased" : "revoked",
    subscriptionState: state || "SUBSCRIPTION_STATE_UNSPECIFIED",
    accountId: raw.externalAccountIdentifiers?.obfuscatedExternalAccountId || null,
    consumed: false,
    acknowledged: raw.acknowledgementState === "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
    orderId: latest.latestSuccessfulOrderId || raw.latestOrderId || null,
    purchasedAtMillis: Date.parse(raw.startTime || "") || null,
    expiresAtMillis,
    autoRenewing: latest.autoRenewingPlan?.autoRenewEnabled === true,
    linkedTokenHash: raw.linkedPurchaseToken ? sha256(raw.linkedPurchaseToken) : null,
  };
}

function currentEntitlement(data = {}, nowMillis = Date.now()) {
  const subscriptions = Object.values(data.subscriptions || {});
  const active = subscriptions.filter((s) => s.active === true && s.expiresAtMillis > nowMillis);
  const expiresAtMillis = active.reduce((max, s) => Math.max(max, s.expiresAtMillis), 0);
  const allCategories = Object.values(data.categoryPurchases || {}).some((p) => p.active === true);
  const lifetimeAdFree = Object.values(data.adFreePurchases || {}).some((p) => p.active === true);
  return {
    isVip: active.length > 0,
    expiresAtMillis,
    allCategories,
    // Lifetime ad-free is separate from the subscription; cancellation cannot revoke it.
    removeAds: lifetimeAdFree,
  };
}

module.exports = {
  ALIASES, PRODUCTS, CommerceError, sha256, resolveProduct, validateInput,
  assertAccountBinding, normalizeProductReceipt, normalizeSubscriptionReceipt, currentEntitlement,
};
