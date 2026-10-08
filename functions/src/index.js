"use strict";

const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getDatabase } = require("firebase-admin/database");
const { getMessaging } = require("firebase-admin/messaging");
const { createDuelNotifications, InviteError } = require("./duel_notifications");
const { setGlobalOptions } = require("firebase-functions/v2");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onMessagePublished } = require("firebase-functions/v2/pubsub");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineString, defineBoolean } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const { google } = require("googleapis");
const { CommerceError } = require("./domain");
const { createPlayVerifier } = require("./play");
const { createCommerceService } = require("./commerce");

initializeApp();
setGlobalOptions({ region: "us-central1", maxInstances: 20, memory: "256MiB", timeoutSeconds: 60 });

const packageName = defineString("PLAY_PACKAGE_NAME", { default: "com.qi7bali.landchallengeonline" });
const topic = defineString("PLAY_RTDN_TOPIC", { default: "play-billing-rtdn" });
const legacyVipIds = defineString("COMMERCE_LEGACY_VIP_IDS", { default: "" });
const enforceAppCheck = defineBoolean("COMMERCE_ENFORCE_APP_CHECK", { default: false });
let commerce;

function getCommerce() {
  if (!commerce) {
    const playPackage = packageName.value();
    const auth = new google.auth.GoogleAuth({ scopes: ["https://www.googleapis.com/auth/androidpublisher"] });
    const publisher = google.androidpublisher({ version: "v3", auth });
    commerce = createCommerceService({
      db: getFirestore(), packageName: playPackage,
      legacyVipIds: legacyVipIds.value().split(",").map((id) => id.trim()).filter(Boolean),
      verifier: createPlayVerifier({ publisher, packageName: playPackage }),
    });
  }
  return commerce;
}

function requireAccount(request) {
  if (!request.auth || request.auth.token.firebase?.sign_in_provider === "anonymous") {
    throw new HttpsError("unauthenticated", "Sign in to your game account before purchasing or restoring.");
  }
  return request.auth.uid;
}

function protectedCallable(handler) {
  return onCall({ enforceAppCheck }, async (request) => {
    const uid = requireAccount(request);
    try {
      return await handler(getCommerce(), uid, request.data);
    } catch (error) {
      const code = error instanceof CommerceError ? error.code : "internal";
      // Neither request data nor exception messages are logged: receipt tokens
      // and Google's request URLs must stay out of Cloud Logging.
      logger.warn("Commerce callable failed", { uid, code });
      throw new HttpsError(code, error instanceof CommerceError ? error.message : "Purchase processing failed. Please try again.");
    }
  });
}

exports.verifyPlayPurchase = protectedCallable((service, uid, data) => service.verifyPurchase(uid, data));
exports.restoreCommercePurchases = protectedCallable((service, uid) => service.restorePurchases(uid));

let duelNotifications;
function duelCallable(method) {
  return onCall(async request => {
    const uid = requireAccount(request);
    duelNotifications ||= createDuelNotifications({ db: getFirestore(), realtime: getDatabase(
      undefined, "https://challengeland-default-rtdb.firebaseio.com"), messaging: getMessaging() });
    try { return await duelNotifications[method](uid, request.data); }
    catch (error) {
      const code = error instanceof InviteError ? error.code : "internal";
      logger.warn("Duel notification operation failed", { uid, code });
      throw new HttpsError(code, error instanceof InviteError ? error.message : "Notification service unavailable.");
    }
  });
}
exports.registerDuelDevice = duelCallable("register");
exports.sendDuelInvite = duelCallable("send");

// Eventarc authenticates the Pub/Sub trigger. There is no public RTDN webhook.
// Only Google's Play notification publisher should be granted publish on topic.
exports.playBillingNotifications = onMessagePublished({ topic, retry: true }, async (event) => {
  let notification;
  try { notification = event.data.message.json; } catch (error) {
    logger.warn("Invalid commerce notification JSON", { eventId: event.id });
    return;
  }
  try {
    const result = await getCommerce().processNotification(notification);
    logger.info("Commerce notification processed", { eventId: event.id, status: result?.status });
  } catch (error) {
    const code = error instanceof CommerceError ? error.code : "internal";
    logger.warn("Commerce notification failed", { eventId: event.id, code });
    // Reject malformed/foreign input permanently; retry service outages.
    if (["permission-denied", "invalid-argument", "failed-precondition"].includes(code)) return;
    // Throw a sanitized message; the original Google API error can expose a token.
    throw new Error(`Commerce notification retry: ${code}`);
  }
});

// RTDN is primary; this also repairs missed events. Runtime expiry checks apply
// immediately even before this daily verification job runs.
exports.refreshPlaySubscriptions = onSchedule({
  schedule: "every 24 hours", timeZone: "UTC", timeoutSeconds: 540,
}, async () => {
  const result = await getCommerce().refreshSubscriptions();
  logger.info("Commerce subscription refresh completed", result);
});
