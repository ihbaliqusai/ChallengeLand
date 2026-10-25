"use strict";

const { randomBytes } = require("node:crypto");
const { CommerceError, sha256 } = require("./domain");

const NEW_ACCOUNT_WINDOW = 7 * 86400000;
const MAX_BALANCE = 2147483647;
const INVITER_REWARD = Object.freeze({ coins: 1000, gems: 10 });
const INVITEE_REWARD = Object.freeze({ coins: 500, gems: 5 });
const MILESTONES = Object.freeze([
  { count: 3, coins: 1000, gems: 10 },
  { count: 5, coins: 2500, gems: 25 },
  { count: 10, coins: 5000, gems: 50 },
]);
const integer = value => Number.isSafeInteger(value) && value >= 0 ? Math.min(value, MAX_BALANCE) : 0;
const wallet = user => ({ coins: integer(user?.coins), gems: integer(user?.gems) });
const fresh = (uid, code, at) => ({ uid, code, qualifiedCount: 0, totalCoins: 0, totalGems: 0,
  acceptedCode: null, claimedMilestones: [], recent: [], createdAt: at });

function stateView(account, canAccept) {
  return {
    code: account.code,
    qualifiedCount: integer(account.qualifiedCount),
    totalCoins: integer(account.totalCoins), totalGems: integer(account.totalGems),
    acceptedCode: account.acceptedCode || null,
    canAccept: canAccept && !account.acceptedCode,
    inviterReward: INVITER_REWARD, inviteeReward: INVITEE_REWARD,
    milestones: MILESTONES.map(reward => ({ ...reward,
      claimed: (account.claimedMilestones || []).includes(reward.count) })),
    recent: (account.recent || []).slice(-10),
  };
}

function credit(user, grant) {
  const before = wallet(user);
  const currency = { coins: Math.min(MAX_BALANCE, before.coins + grant.coins),
    gems: Math.min(MAX_BALANCE, before.gems + grant.gems) };
  return { currency, applied: { coins: currency.coins - before.coins, gems: currency.gems - before.gems } };
}

/**
 * Device identifiers and Play Install Referrer help attribution and ordinary
 * deduplication; they are not remote attestation or proof against modified apps.
 * Account age always comes from Firebase Auth, never a client profile timestamp.
 */
function createReferralService({ db, lookupAccount, now = Date.now,
  makeCode = () => `CL-${randomBytes(6).toString("hex").toUpperCase()}` }) {
  async function ensureAccount(uid, installationHash, at) {
    // A separate, bounded code-allocation transaction makes a rare collision
    // retry safe, including when Firestore retries a transaction callback.
    for (let attempt = 0; attempt < 8; attempt++) {
      const candidate = makeCode();
      if (!/^CL-[A-F0-9]{12}$/.test(candidate)) throw new Error("Invalid generated referral code");
      const result = await db.runTransaction(async tx => {
        const accountRef = db.doc(`referral_accounts/${uid}`);
        const accountDoc = await tx.get(accountRef);
        const candidateRef = db.doc(`referral_codes/${candidate}`);
        const candidateDoc = accountDoc.exists ? null : await tx.get(candidateRef);
        const userDoc = await tx.get(db.doc(`users/${uid}`));
        const deviceRef = installationHash ? db.doc(`referral_devices/${installationHash}`) : null;
        const deviceDoc = deviceRef ? await tx.get(deviceRef) : null;
        if (!accountDoc.exists && candidateDoc.exists) return null;
        const account = accountDoc.data() || fresh(uid, candidate, at);
        if (!accountDoc.exists) {
          tx.set(accountRef, account);
          tx.set(candidateRef, { uid, createdAt: at });
        }
        if (deviceRef && !deviceDoc.exists) tx.set(deviceRef, { firstUid: uid, createdAt: at });
        return { account, user: userDoc.data() || {},
          deviceAvailable: !deviceDoc?.exists || deviceDoc.data().firstUid === uid };
      });
      if (result) return result;
    }
    throw new CommerceError("resource-exhausted", "تعذّر إنشاء كود الدعوة. حاول مجددًا.");
  }

  async function execute(uid, input = {}) {
    if (typeof uid !== "string" || !uid || uid.includes("/")) {
      throw new CommerceError("unauthenticated", "سجّل الدخول لتفعيل دعوات الأصدقاء.");
    }
    if (!input || typeof input !== "object" || Array.isArray(input)) throw new CommerceError("invalid-argument", "الطلب غير صالح.");
    if (input.expectedUid && input.expectedUid !== uid) throw new CommerceError("permission-denied", "تغيّر الحساب. أعد المحاولة.");
    const action = input.action || "state";
    if (!["state", "accept"].includes(action)) throw new CommerceError("invalid-argument", "عملية الدعوة غير صالحة.");
    const installationId = input.installId ?? input.installationId;
    if (installationId !== undefined && (typeof installationId !== "string" || !/^[A-Za-z0-9_-]{16,200}$/.test(installationId))) {
      throw new CommerceError("invalid-argument", "تعذّر التحقق من تثبيت اللعبة على هذا الجهاز.");
    }
    if (action === "accept" && !installationId) throw new CommerceError("failed-precondition", "افتح الدعوة من اللعبة على جهازك لقبولها.");
    const at = now();
    const auth = await lookupAccount(uid);
    if (!auth || auth.disabled) throw new CommerceError("unauthenticated", "سجّل الدخول بحساب صالح لقبول الدعوة.");
    const age = at - auth.createdAtMillis;
    const newAccount = Number.isFinite(age) && age >= 0 && age <= NEW_ACCOUNT_WINDOW;
    const installationHash = installationId ? sha256(installationId) : null;
    const own = await ensureAccount(uid, installationHash, at);
    const response = (account, user, eligible, newlyAccepted = false, grants = { coins: 0, gems: 0 }) => ({
      state: stateView(account, eligible), currency: wallet(user),
      referralRevision: integer(user.referralRevision), newlyAccepted, grants,
    });
    if (action === "state") return response(own.account, own.user, newAccount && own.deviceAvailable);

    const code = typeof input.code === "string" ? input.code.trim().toUpperCase() : "";
    if (!/^CL-[A-F0-9]{12}$/.test(code)) throw new CommerceError("invalid-argument", "أدخل كود دعوة صحيحًا يبدأ بـ CL-.");
    return db.runTransaction(async tx => {
      const accountRef = db.doc(`referral_accounts/${uid}`);
      const acceptanceRef = db.doc(`referral_acceptances/${uid}`);
      const deviceRef = db.doc(`referral_devices/${installationHash}`);
      const userRef = db.doc(`users/${uid}`);
      const [accountDoc, acceptanceDoc, deviceDoc, userDoc, codeDoc] = await Promise.all([
        tx.get(accountRef), tx.get(acceptanceRef), tx.get(deviceRef), tx.get(userRef),
        tx.get(db.doc(`referral_codes/${code}`)),
      ]);
      const account = accountDoc.data();
      const user = userDoc.data() || {};
      if (acceptanceDoc.exists || account.acceptedCode) {
        const acceptedCode = acceptanceDoc.data()?.code || account.acceptedCode;
        if (acceptedCode !== code) throw new CommerceError("already-exists", "سبق لك قبول دعوة صديق آخر.");
        // A retry recovers current balances, never the historic credited balance.
        return response(account, user, false);
      }
      if (!codeDoc.exists) throw new CommerceError("not-found", "كود الدعوة غير موجود. تأكد من الكود مع صديقك.");
      const inviterUid = codeDoc.data().uid;
      if (inviterUid === uid) throw new CommerceError("invalid-argument", "لا يمكنك قبول دعوتك الخاصة.");
      if (!newAccount) throw new CommerceError("failed-precondition", "قبول الدعوات متاح للحسابات الجديدة خلال أول 7 أيام من التسجيل.");
      if (!userDoc.exists) throw new CommerceError("failed-precondition", "أكمل إنشاء حسابك في اللعبة ثم أعد المحاولة.");
      const device = deviceDoc.data();
      if (!device || device.firstUid !== uid || device.rewardedUid) {
        throw new CommerceError("already-exists", "استُخدم هذا الجهاز من قبل. مكافأة الانضمام متاحة مرة واحدة لكل جهاز.");
      }
      const inviterRef = db.doc(`referral_accounts/${inviterUid}`);
      const inviterUserRef = db.doc(`users/${inviterUid}`);
      const [inviterDoc, inviterUserDoc] = await Promise.all([tx.get(inviterRef), tx.get(inviterUserRef)]);
      if (!inviterDoc.exists || !inviterUserDoc.exists) throw new CommerceError("failed-precondition", "حساب صاحب الدعوة غير متاح حاليًا.");
      const inviter = inviterDoc.data();
      const inviterUser = inviterUserDoc.data();
      const count = integer(inviter.qualifiedCount) + 1;
      const claimed = new Set(inviter.claimedMilestones || []);
      const grant = { ...INVITER_REWARD };
      for (const milestone of MILESTONES) {
        if (count >= milestone.count && !claimed.has(milestone.count)) {
          grant.coins += milestone.coins; grant.gems += milestone.gems;
          claimed.add(milestone.count);
        }
      }
      const inviterCredit = credit(inviterUser, grant);
      const inviteeCredit = credit(user, INVITEE_REWARD);
      const nextAccount = { ...account, acceptedCode: code,
        totalCoins: integer(account.totalCoins) + inviteeCredit.applied.coins,
        totalGems: integer(account.totalGems) + inviteeCredit.applied.gems };
      const nextUser = { ...user, ...inviteeCredit.currency, referralRevision: integer(user.referralRevision) + 1 };
      tx.set(accountRef, nextAccount);
      tx.set(inviterRef, { ...inviter, qualifiedCount: count,
        totalCoins: integer(inviter.totalCoins) + inviterCredit.applied.coins,
        totalGems: integer(inviter.totalGems) + inviterCredit.applied.gems,
        claimedMilestones: [...claimed],
        recent: [...(inviter.recent || []), {
          name: String(user.username || user.displayName || "صديق جديد").slice(0, 60), at,
        }].slice(-10) });
      tx.set(userRef, { ...inviteeCredit.currency, referralRevision: nextUser.referralRevision }, { merge: true });
      tx.set(inviterUserRef, { ...inviterCredit.currency, referralRevision: integer(inviterUser.referralRevision) + 1 }, { merge: true });
      tx.set(acceptanceRef, { uid, inviterUid, code, installationHash, acceptedAt: at,
        inviterGrants: inviterCredit.applied, inviteeGrants: inviteeCredit.applied });
      tx.set(deviceRef, { ...device, rewardedUid: uid, rewardedAt: at });
      return response(nextAccount, nextUser, false, true, inviteeCredit.applied);
    });
  }
  return { execute };
}

module.exports = { createReferralService, NEW_ACCOUNT_WINDOW, INVITER_REWARD, INVITEE_REWARD, MILESTONES };
