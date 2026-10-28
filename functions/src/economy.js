"use strict";

const { CommerceError, sha256 } = require("./domain");
const { randomInt: secureRandomInt } = require("node:crypto");
const DAY = 86400000;
// Version 1 remains available for existing clients and outstanding receipts.
const WHEEL_PRIZES = Object.freeze([
  { id: "keys", grants: { keys: 1 } },
  { id: "tickets", grants: { tickets: 1 } },
  { id: "coins", grants: { coins: 500 } },
  { id: "gems", grants: { gems: 10 } },
  { id: "character", grants: {} },
  { id: "chest", grants: { coins: 1000, gems: 20, keys: 2, tickets: 2 } },
]);
// Indices 0..5 and their IDs are stable so an older receipt can still be shown
// after an app update. Keep the complete order in sync with the v2 client.
const WHEEL_PRIZES_V2 = Object.freeze([
  ...WHEEL_PRIZES,
  { id: "keys_2", grants: { keys: 2 } },
  { id: "tickets_2", grants: { tickets: 2 } },
  { id: "coins_250", grants: { coins: 250 } },
  { id: "coins_1000", grants: { coins: 1000 } },
  { id: "gems_5", grants: { gems: 5 } },
  { id: "gems_20", grants: { gems: 20 } },
]);
const WHEEL_PRIZE_DISCLOSURE_V2 = Object.freeze(WHEEL_PRIZES_V2.map((prize, index) => Object.freeze({
  id: prize.id, index, grants: Object.freeze({ ...prize.grants }),
  probabilityNumerator: 1, probabilityDenominator: WHEEL_PRIZES_V2.length,
})));
const WHEEL_CHARACTERS = Object.freeze([2, 4, 7, 9, 11, 12, 14, 15]);
const purchasedWheelCharacters = user => [...new Set((Array.isArray(user.purchasedCharacters) ? user.purchasedCharacters : [])
  .filter(index => Number.isInteger(index) || (typeof index === "string" && /^(?:[0-9]|1[0-5])$/.test(index)))
  .map(Number).filter(index => index >= 0 && index < 16))];
const nextWheelCharacter = user => {
  const purchased = new Set(purchasedWheelCharacters(user));
  return WHEEL_CHARACTERS.find(index => !purchased.has(index)) ?? null;
};
const timestampMillis = value => typeof value?.toMillis === "function" ? value.toMillis()
  : value instanceof Date ? value.getTime() : -Infinity;
// Category trials share the ticket allowance: they cannot bypass the ad cap.
const AD_REWARD_LIMITS = Object.freeze({ keys: 2, hearts: 2, tickets: 2 });
const weekId = at => Math.floor((Math.floor(at / DAY) + 3) / 7); // Monday, UTC.
const FREE = ["جغرافيا", "حيوانات", "دين واسلاميات", "عواصم", "دول", "اختراعات", "عملات", "لغة وادب"];
// Keep names and ad restrictions aligned with CategoryCatalog in the app.
// category_catalog.test.js checks the client catalog to catch missing additions.
const NO_ADS = ["أنمي", "مسلسل Friends", "مسلسلات أجنبية", "مسلسلات عربية", "أفلام أجنبية", "أفلام عربية", "سبيس تون",
  "باب الحارة", "Game Of Thrones", "Breaking Bad", "Harry Potter", "Pokémon", "Demon Slayer",
  "Hunter × Hunter", "One Piece", "Attack on Titan", "Naruto"];
const CATEGORIES = [...FREE, ...NO_ADS, "معلومات عامة", "تاريخ", "رياضة", "لاعبين كرة قدم", "مسيرة لاعب", "علوم وفضاء", "ألغاز", "أمثال", "تقنية", "جسم الإنسان", "نباتات", "لغات", "صحة", "طعام وشراب", "سياحة وسفر", "سيرة ذاتية", "قصص الأنبياء", "منوعات", "خمن الصورة", "خمن الأغنية", "خمن الأكلة", "خمن الاسم", "خمن المدينة او الدولة", "زووم", "ركز شوي", "وضح شوي", "سيارات", "كأس العالم", "فنون وسينما", "فيروز", "كلثوميات",
  "دوري أبطال أوروبا", "NBA", "بنات وبس", "مسلسلات تركية", "دراما خليجية", "دراما سورية", "دراما مصرية"];
function normalize(s) {
  const n = String(s || "").trim().replace(/[أإآ]/g, "ا").replace(/ة/g, "ه").replace(/ى/g, "ي").replace(/é/g, "e").replace(/×/g, "x").replace(/\s+/g, " ").toLowerCase();
  return ["الانمي", "الانيمي", "انيمي"].includes(n) ? "انمي" : n;
}
const canonical = s => CATEGORIES.find(c => normalize(c) === normalize(s));
const free = c => FREE.some(s => normalize(s) === normalize(c));
const allowsAd = c => !free(c) && !NO_ADS.some(s => normalize(s) === normalize(c));
const OFFERS = Object.freeze({
  keys_1: { resource: "keys", amount: 1, coins: 700, gems: 7 },
  keys_3: { resource: "keys", amount: 3, coins: 1800, gems: 18 },
  hearts_1: { resource: "hearts", amount: 1, coins: 600, gems: 6 },
  hearts_3: { resource: "hearts", amount: 3, coins: 1500, gems: 15 },
  tickets_1: { resource: "tickets", amount: 1, coins: 900, gems: 9 },
  tickets_3: { resource: "tickets", amount: 3, coins: 2400, gems: 24 },
  play_bundle: { grants: { keys: 3, hearts: 3, tickets: 3 }, coins: 5100, gems: 51 },
  play_bundle_large: { grants: { keys: 10, hearts: 10, tickets: 10 }, coins: 16000, gems: 160 },
});
const RENTALS = Object.freeze({ day: { days: 1, coins: 1500, gems: 15 }, week: { days: 7, coins: 4500, gems: 45 }, month: { days: 30, coins: 9000, gems: 90 } });
const integer = v => Number.isSafeInteger(v) && v >= 0 ? Math.min(v, 2147483647) : 0;
function stable(value) {
  if (Array.isArray(value)) return value.map(stable);
  if (value && typeof value === "object") return Object.fromEntries(Object.keys(value).sort().map(key => [key, stable(value[key])]));
  return value;
}
function fresh(at) {
  return { version: 1, day: Math.floor(at / DAY), dailyKeys: 3, dailyHearts: 3,
    keys: 0, hearts: 0, tickets: 3, wheelSpins: 0, categoryVouchers: 0, rentalVouchers: 0, claimedVipExpiry: 0,
    welcomeGrantedAt: at, rewardLog: [{ id: "welcome", kind: "welcome", at, grants: { keys: 3, tickets: 3, hearts: 3 } }],
    owned: [], rentals: {}, adPermits: {}, milestones: [], streak: 0, lastLoginDay: -1,
    week: weekId(at), weekDays: [], weekCorrect: 0, weekRewardClaimed: false, revision: 0, reservations: {}, adRewardCounts: {} };
}
function refresh(data, at) {
  const s = { ...fresh(at), ...data, owned: [...(data?.owned || [])], rentals: { ...(data?.rentals || {}) }, adPermits: { ...(data?.adPermits || {}) }, milestones: [...(data?.milestones || [])], reservations: { ...(data?.reservations || {}) } };
  s.rewardLog = [...(data?.rewardLog || (!data ? s.rewardLog : []))];
  s.claimedVipExpiry = Number(data?.claimedVipExpiry || 0);
  s.wheelSpins = integer(data?.wheelSpins);
  s.adRewardCounts = Object.fromEntries(Object.keys(AD_REWARD_LIMITS).map(resource => [resource, integer(data?.adRewardCounts?.[resource])]));
  // Existing accounts receive the introduction once, without overwriting banked purchases.
  // The initial three keys/hearts are the first day's free allowance, not a second grant.
  if (data && !data.welcomeGrantedAt) {
    s.welcomeGrantedAt = at;
    s.dailyKeys = Math.max(3, s.dailyKeys); s.dailyHearts = Math.max(3, s.dailyHearts);
    s.tickets = integer(data.tickets) + 3;
    recordReward(s, "welcome", "welcome", { keys: 3, tickets: 3, hearts: 3 }, at);
  }
  if (s.day !== Math.floor(at / DAY)) Object.assign(s, { day: Math.floor(at / DAY), dailyKeys: 3, dailyHearts: 3, adRewardCounts: {} });
  if (s.week !== weekId(at)) Object.assign(s, { week: weekId(at), weekDays: [], weekCorrect: 0, weekRewardClaimed: false });
  return s;
}
function recordReward(s, id, kind, grants, at, details = {}) {
  s.rewardLog = [...(s.rewardLog || []), { id, kind, grants, at, ...details }].slice(-20);
}
function rewarded(s, id, kind, at, grant, details = {}) {
  const keys = ["keys", "hearts", "tickets", "categoryVouchers", "rentalVouchers"];
  const before = Object.fromEntries(keys.map(k => [k, s[k]]));
  grant();
  const amounts = Object.fromEntries(keys.filter(k => s[k] > before[k]).map(k => [k, s[k] - before[k]]));
  if (Object.keys(amounts).length) recordReward(s, id, kind, amounts, at, details);
}
function take(s, resource) {
  const daily = resource === "keys" ? "dailyKeys" : "dailyHearts";
  if (s[daily] > 0) { s[daily]--; return daily; }
  if (s[resource] > 0) { s[resource]--; return resource; }
  throw new CommerceError("resource-exhausted", resource === "keys" ? "نفدت المفاتيح. احصل على المزيد من المتجر." : "نفدت القلوب. انتظر التجديد أو احصل على قلوب إضافية.");
}
function streakReward(s, day) {
  if (day === 7) s.keys++;
  if (day === 14) { s.hearts++; s.tickets++; }
  if (day === 21) s.keys++;
  if (day === 30) { s.keys += 2; s.hearts++; s.tickets++; }
}
function milestone(s, order) {
  const id = String(order);
  if (s.milestones.includes(id)) return;
  s.milestones.push(id);
  if (order % 20 === 0) s.tickets++;
  if (order === 10 || order === 25) s.keys++;
  if (order === 50 || order === 75) { s.keys++; s.hearts++; }
  if (order === 100) { s.keys += 2; s.rentalVouchers++; }
}

function takeAdAllowance(s, resource) {
  const used = integer(s.adRewardCounts[resource]);
  if (used >= AD_REWARD_LIMITS[resource]) {
    throw new CommerceError("resource-exhausted", "اكتملت مكافآت إعلانات هذا المورد لليوم. تتجدد عند منتصف الليل UTC.");
  }
  s.adRewardCounts[resource] = used + 1;
}

function weeklyProgress(s, day, correct, at) {
  s.weekDays = [...new Set([...(s.weekDays || []), day])];
  s.weekCorrect = Math.min(100000, s.weekCorrect + correct);
  if (!s.weekRewardClaimed && s.weekDays.length >= 3 && s.weekCorrect >= 20) {
    rewarded(s, `week_${s.week}`, "weekly", at, () => { s.keys++; s.tickets++; });
    s.weekRewardClaimed = true;
  }
}

function createEconomyService({ db, now = Date.now, randomInt = secureRandomInt }) {
  async function execute(uid, input = {}) {
    if (!uid || uid.includes("/")) throw new CommerceError("unauthenticated", "سجّل الدخول لحفظ أرصدتك.");
    if (!input || typeof input !== "object" || Array.isArray(input)) throw new CommerceError("invalid-argument", "الطلب غير صالح.");
    if (input.expectedUid && input.expectedUid !== uid) throw new CommerceError("permission-denied", "تغيّر الحساب. أعد المحاولة.");
    const { action = "state" } = input;
    const readOnly = action === "state";
    if (!readOnly && (typeof input.operationId !== "string" || !/^[A-Za-z0-9_-]{1,160}$/.test(input.operationId))) throw new CommerceError("invalid-argument", "معرّف العملية غير صالح.");
    const at = now();
    const accountRef = db.doc(`economy_accounts/${uid}`);
    const receiptRef = db.doc(`economy_accounts/${uid}/operations/${sha256(input.operationId || "state")}`);
    const userRef = db.doc(`users/${uid}`);
    return db.runTransaction(async tx => {
      const [account, receipt, user, entitlement] = await Promise.all([
        tx.get(accountRef), tx.get(receiptRef), tx.get(userRef), tx.get(db.doc(`commerce_accounts/${uid}/entitlements/current`)),
      ]);
      const s = refresh(account.data(), at);
      const u = user.data() || {};
      const e = entitlement.data() || {};
      const member = e.allCategories === true || (e.isVip === true && e.expiresAtMillis > at);
      const permanentlyOwned = c => s.owned.some(x => normalize(x) === normalize(c)) || (u.unlockedCategories || []).some(x => normalize(x) === normalize(c));
      const access = c => free(c) || member || permanentlyOwned(c) || Number(s.rentals[normalize(c)] || 0) > at || Object.entries(u.categoryRentals || {}).some(([k, v]) => normalize(k) === normalize(c) && Number(v) > at);
      let result = {};
      const deferredWrites = [];
      // Bind replay IDs to their payload; do not let a begin receipt replay a purchase.
      const signatureInput = { ...input, operationId: undefined };
      // Catalog metadata may change while recovering a journal created before
      // an app update. It cannot change an existing receipt's prize or debit.
      if (action === "spinWheel") delete signatureInput.wheelCatalogVersion;
      const signature = sha256(JSON.stringify(stable(signatureInput)));
      if (!readOnly && receipt.exists) {
        const old = receipt.data();
        if (old.signature !== signature) throw new CommerceError("already-exists", "استُخدم معرّف العملية لطلب مختلف.");
        if (action === "begin" && (old.result.session?.status === "cancelled" || (old.result.session?.mode === "campaign" && old.result.session?.status !== "active"))) throw new CommerceError("failed-precondition", "انتهت هذه المباراة. ابدأ مباراة جديدة.");
        return { ...old.result, referralRevision: integer(u.referralRevision),
          ...(old.result.spin ? { spin: { ...old.result.spin, newlyGranted: false }, purchasedCharacters: purchasedWheelCharacters(u) } : {}),
          ...(old.result.currency ? { currency: { coins: integer(u.coins), gems: integer(u.gems) } } : {}), state: view(s, at, u) };
      }
      // Existing campaign progress also receives milestones, so returning players
      // do not have to repeat completed stages. Rewards are not based on a supplied order.
      if (readOnly || action === "login") {
        // Process death between reservation and gameplay must not lose paid resources.
        // Only uncommitted admissions expire; a started match never auto-refunds.
        for (const [hash, reservedAt] of Object.entries(s.reservations)) {
          if (at - reservedAt < 5 * 60000) continue;
          const ref = db.doc(`economy_accounts/${uid}/operations/${hash}`);
          const doc = await tx.get(ref);
          const previous = doc.data();
          const session = previous?.result?.session;
          if (session?.status === "active" && !session.committed) {
            refund(s, session);
            s.tickets += session.ticketCost || 0;
            for (const c of session.adCategories || []) s.adPermits[normalize(c)] = 1;
            deferredWrites.push([ref, { ...previous, result: { session: { ...session, status: "cancelled" } } }]);
          }
          delete s.reservations[hash];
        }
        const orders = [10, 20, 25, 30, 40, 50, 60, 70, 75, 80, 90, 100].filter(order => !s.milestones.includes(String(order)));
        const progress = await Promise.all(orders.map(order => tx.get(db.doc(`users/${uid}/campaignProgress/stage_${String(order).padStart(3, "0")}`))));
        // Older releases saved stage_10 instead of stage_010. Match the same
        // fallback used by CampaignService so returning players need no replay.
        await Promise.all(orders.map(async (order, i) => {
          if (!progress[i].exists && order < 100) progress[i] = await tx.get(db.doc(`users/${uid}/campaignProgress/stage_${order}`));
        }));
        progress.forEach((doc, i) => {
          const data = doc.data();
          if (data && (!data.campaignId || data.campaignId === "main_campaign") && (data.status === "completed" || integer(data.stars) > 0)) rewarded(s, `stage_${orders[i]}`, "campaign", at, () => milestone(s, orders[i]), { stage: orders[i] });
        });
      }
      let userUpdate;
      const debit = (cost, currency) => {
        if (!["coins", "gems"].includes(currency) || integer(u[currency]) < cost) throw new CommerceError("failed-precondition", "الرصيد غير كافٍ.");
        userUpdate = { [currency]: integer(u[currency]) - cost };
        result.currency = { coins: integer(u.coins), gems: integer(u.gems), ...userUpdate };
      };
      if (action === "buy") {
        const offer = Object.hasOwn(OFFERS, input.offerId) ? OFFERS[input.offerId] : null;
        if (!offer || !["coins", "gems"].includes(input.currency)) throw new CommerceError("invalid-argument", "العرض غير متاح.");
        const grants = offer.grants || { [offer.resource]: offer.amount };
        if (Object.entries(grants).some(([key, amount]) => s[key] + amount > 2147483647)) throw new CommerceError("failed-precondition", "بلغ الرصيد الحد الأقصى.");
        debit(offer[input.currency], input.currency);
        for (const [key, amount] of Object.entries(grants)) s[key] += amount;
      } else if (["rent", "ad", "ownVoucher", "own"].includes(action)) {
        const c = canonical(input.category);
        if (!c || free(c)) throw new CommerceError("invalid-argument", "التصنيف غير متاح للشراء.");
        const key = normalize(c);
        if (action === "ad") {
          if (!allowsAd(c)) throw new CommerceError("permission-denied", "هذا التصنيف لا يفتح بمشاهدة إعلان.");
          // A permit is category-specific and cannot be exchanged for a general ticket.
          if (!access(c) && !s.adPermits[key]) {
            takeAdAllowance(s, "tickets");
            s.adPermits[key] = 1;
          }
        } else if (action === "ownVoucher" || action === "own") {
          if (!permanentlyOwned(c) && e.allCategories !== true) {
            if (action === "ownVoucher") {
              if (s.categoryVouchers < 1) throw new CommerceError("failed-precondition", "لا توجد قسيمة امتلاك.");
              s.categoryVouchers--;
            } else debit(150, "gems");
            s.owned.push(c);
          }
        } else {
          if (permanentlyOwned(c) || member) throw new CommerceError("failed-precondition", "التصنيف مفتوح لديك بالفعل ولا يحتاج إلى استئجار.");
          const rental = Object.hasOwn(RENTALS, input.duration) ? RENTALS[input.duration] : null;
          if (!rental) throw new CommerceError("invalid-argument", "مدة الاستئجار غير صالحة.");
          if (input.currency === "voucher") {
            if (input.duration !== "week" || s.rentalVouchers < 1) throw new CommerceError("failed-precondition", "لا توجد قسيمة استئجار أسبوعية.");
            s.rentalVouchers--;
          } else {
            if (!["coins", "gems"].includes(input.currency)) throw new CommerceError("invalid-argument", "العملة غير صالحة.");
            debit(rental[input.currency], input.currency);
          }
          const legacyExpiry = Object.entries(u.categoryRentals || {}).filter(([k]) => normalize(k) === key).reduce((latest, [, v]) => Math.max(latest, Number(v) || 0), 0);
          s.rentals[key] = Math.max(at, Number(s.rentals[key] || 0), legacyExpiry) + rental.days * DAY;
        }
      } else if (action === "spinWheel") {
        const day = Math.floor(at / DAY);
        const purchased = purchasedWheelCharacters(u);
        const previousClaim = timestampMillis(u.lastStreakClaimDate);
        const lastFreeAt = lastWheelFreeSpinMillis(s, u);
        const usedFreeSpin = lastFreeAt <= 0 || (at - lastFreeAt) >= DAY;
        if (!usedFreeSpin && s.wheelSpins < 1) {
          throw new CommerceError("failed-precondition", "استخدمت اللفة المجانية. تتوفر اللفة المجانية القادمة بعد 24 ساعة، أو يمكنك استخدام لفات إضافية.");
        }
        // The receipt branch above is the only replay path. Each new operation
        // uses the 24-hour free opportunity first, then one banked purchased spin.
        if (!usedFreeSpin) s.wheelSpins--;
        const catalogVersion = input.wheelCatalogVersion === 2 ? 2 : 1;
        const catalog = catalogVersion === 2 ? WHEEL_PRIZES_V2 : WHEEL_PRIZES;
        const prizeIndex = randomInt(catalog.length);
        const prize = catalog[prizeIndex];
        const grants = { ...prize.grants };
        let characterIndex = null;
        let compensation = false;
        if (prize.id === "character") {
          const available = WHEEL_CHARACTERS.filter(index => !purchased.includes(index));
          if (available.length) {
            // V2 shows this exact character on the wheel, then replaces it with
            // the next unowned one after delivery. V1 keeps its original draw.
            characterIndex = catalogVersion === 2
              ? available[0] : available[randomInt(available.length)];
            purchased.push(characterIndex);
          } else {
            // Owning the whole roster must still produce a useful reward.
            compensation = true;
            grants.gems = 100;
          }
        }
        for (const resource of ["keys", "tickets"]) {
          if (grants[resource]) s[resource] = Math.min(2147483647, integer(s[resource]) + grants[resource]);
        }
        const currency = {
          coins: Math.min(2147483647, integer(u.coins) + (grants.coins || 0)),
          gems: Math.min(2147483647, integer(u.gems) + (grants.gems || 0)),
        };
        const savedDay = Math.min(30, Math.max(1, integer(u.streakDay) || 1));
        const nextStreak = Math.floor(previousClaim / DAY) === day - 1 ? savedDay % 30 + 1 : 1;
        userUpdate = { ...currency, purchasedCharacters: purchased,
          lastLuckyWheelSpinDate: new Date(at),
          ...(usedFreeSpin ? { streakDay: nextStreak, lastStreakClaimDate: new Date(at) } : {}) };
        result.spin = { prizeId: prize.id, prizeIndex, grants, characterIndex, compensation, newlyGranted: true, usedFreeSpin, catalogVersion,
          probabilityNumerator: 1, probabilityDenominator: catalog.length };
        if (usedFreeSpin) {
          s.lastFreeWheelSpinMillis = at;
          s.lastWheelSpinDay = day;
        }
        s.lastWheelSpin = result.spin;
        recordReward(s, `wheel_${sha256(input.operationId)}`, "wheel", grants, at, { prizeId: prize.id, characterIndex, usedFreeSpin });
        result.purchasedCharacters = purchased;
        result.currency = { coins: integer(u.coins), gems: integer(u.gems),
          ...(userUpdate ? { coins: userUpdate.coins, gems: userUpdate.gems } : {}) };
      } else if (action === "login") {
        const day = Math.floor(at / DAY);
        if (s.lastLoginDay !== day) {
          s.streak = s.lastLoginDay === day - 1 ? s.streak % 30 + 1 : 1;
          s.lastLoginDay = day;
          rewarded(s, `login_${day}`, "login", at, () => streakReward(s, s.streak), { streak: s.streak });
        }
      } else if (action === "begin") {
        if (!["challenge", "campaign"].includes(input.mode)) throw new CommerceError("invalid-argument", "نوع المباراة غير صالح.");
        const raw = input.categories || [];
        if (!Array.isArray(raw) || raw.length > 8) throw new CommerceError("invalid-argument", "قائمة التصنيفات غير صالحة.");
        const categories = [...new Set(raw.map(canonical))];
        if (categories.includes(undefined)) throw new CommerceError("invalid-argument", "تصنيف غير معروف.");
        const needed = categories.filter(c => !access(c));
        const tickets = needed.filter(c => !s.adPermits[normalize(c)]);
        if (tickets.length > s.tickets) throw new CommerceError("resource-exhausted", "تذاكر التصنيفات غير كافية.");
        if (input.mode === "campaign" && (!Number.isInteger(input.stageOrder) || input.stageOrder < 1 || input.stageOrder > 100)) throw new CommerceError("invalid-argument", "المرحلة غير صالحة.");
        const source = take(s, input.mode === "campaign" ? "hearts" : "keys");
        for (const c of needed) if (s.adPermits[normalize(c)]) delete s.adPermits[normalize(c)];
        s.tickets -= tickets.length;
        result = { session: { mode: input.mode, categories, stageOrder: input.stageOrder || 0, source, day: s.day, status: "active", ticketCost: tickets.length, adCategories: needed.filter(c => !tickets.includes(c)) } };
        s.reservations[sha256(input.operationId)] = at;
      } else if (action === "extend") {
        if (typeof input.sessionId !== "string" || !/^[A-Za-z0-9_-]{1,160}$/.test(input.sessionId)) throw new CommerceError("invalid-argument", "المباراة غير صالحة.");
        const raw = input.categories;
        if (!Array.isArray(raw) || raw.length > 8) throw new CommerceError("invalid-argument", "قائمة التصنيفات غير صالحة.");
        const categories = [...new Set(raw.map(canonical))];
        if (categories.includes(undefined)) throw new CommerceError("invalid-argument", "تصنيف غير معروف.");
        const ref = db.doc(`economy_accounts/${uid}/operations/${sha256(input.sessionId)}`);
        const start = await tx.get(ref);
        const record = start.data();
        const session = record?.result?.session;
        if (!session?.committed || session.mode !== "challenge" || session.status === "cancelled") throw new CommerceError("failed-precondition", "المباراة غير متاحة.");
        const previous = session.categories || [];
        const needed = categories.filter(c => !previous.includes(c) && !access(c));
        const tickets = needed.filter(c => !s.adPermits[normalize(c)]);
        if (tickets.length > s.tickets) throw new CommerceError("resource-exhausted", "تذاكر التصنيفات غير كافية.");
        s.tickets -= tickets.length;
        for (const c of needed) if (s.adPermits[normalize(c)]) delete s.adPermits[normalize(c)];
        result.session = { ...session, categories: [...new Set([...previous, ...categories])] };
        tx.set(ref, { ...record, result: { session: result.session } });
      } else if (action === "progressRound") {
        if (typeof input.sessionId !== "string" || !/^[A-Za-z0-9_-]{1,160}$/.test(input.sessionId)
            || typeof input.roundId !== "string" || input.roundId.length < 1 || input.roundId.length > 256
            || !Number.isInteger(input.answered) || input.answered < 1 || input.answered > 1000
            || !Number.isInteger(input.correct) || input.correct < 0 || input.correct > input.answered)
          throw new CommerceError("invalid-argument", "نتيجة الجولة غير صالحة.");
        const ref = db.doc(`economy_accounts/${uid}/operations/${sha256(input.sessionId)}`);
        const start = await tx.get(ref);
        const record = start.data();
        const session = record?.result?.session;
        if (!session?.committed || session.mode !== "challenge" || !["active", "finished"].includes(session.status))
          throw new CommerceError("failed-precondition", "المباراة غير متاحة.");
        const rounds = { ...(session.rounds || {}) };
        const roundKey = sha256(input.roundId);
        if (!Object.hasOwn(rounds, roundKey)) {
          if (Object.keys(rounds).length >= 100) throw new CommerceError("resource-exhausted", "بلغت المباراة الحد الأقصى للجولات.");
          rounds[roundKey] = { correct: input.correct, answered: input.answered, day: s.day };
          if (weekId(session.day * DAY) === s.week) weeklyProgress(s, s.day, input.correct, at);
          tx.set(ref, { ...record, result: { session: { ...session, rounds } } });
        } else if (rounds[roundKey].correct !== input.correct || rounds[roundKey].answered !== input.answered) {
          throw new CommerceError("already-exists", "سبق تسجيل هذه الجولة بنتيجة مختلفة.");
        }
      } else if (action === "finish" || action === "cancel") {
        if (typeof input.sessionId !== "string" || !/^[A-Za-z0-9_-]{1,160}$/.test(input.sessionId)) throw new CommerceError("invalid-argument", "المباراة غير صالحة.");
        const ref = db.doc(`economy_accounts/${uid}/operations/${sha256(input.sessionId)}`);
        const start = await tx.get(ref);
        const record = start.data();
        if (!record?.result?.session) throw new CommerceError("failed-precondition", "لم تبدأ هذه المباراة.");
        const session = { ...record.result.session };
        delete s.reservations[sha256(input.sessionId)];
        if (session.status === "active") {
          if (action === "cancel") {
            // Cancellation is only allowed before the client confirms gameplay.
            if (session.committed) throw new CommerceError("failed-precondition", "بدأ اللعب بالفعل.");
            refund(s, session);
            s.tickets += session.ticketCost || 0;
            for (const c of session.adCategories || []) s.adPermits[normalize(c)] = 1;
          } else if (session.mode === "campaign" && input.won === true) {
            refund(s, session);
          }
          if (action === "finish" && weekId(session.day * DAY) === s.week
              && !(session.mode === "challenge" && input.roundProgressVersion === 1)) {
            weeklyProgress(s, session.day, Math.min(1000, integer(input.correct)), at);
          }
          session.status = action === "cancel" ? "cancelled" : "finished";
          tx.set(ref, { ...record, result: { session } });
        }
      } else if (action === "commit") {
        const ref = db.doc(`economy_accounts/${uid}/operations/${sha256(String(input.sessionId || ""))}`);
        const start = await tx.get(ref);
        const r = start.data();
        if (!r?.result?.session || r.result.session.status === "cancelled" || (r.result.session.mode === "campaign" && r.result.session.status !== "active")) throw new CommerceError("failed-precondition", "المباراة غير متاحة.");
        tx.set(ref, { ...r, result: { session: { ...r.result.session, committed: true } } });
        delete s.reservations[sha256(String(input.sessionId))];
      } else if (action === "adReward") {
        const resource = String(input.resource || "");
        if (!["keys", "hearts", "tickets"].includes(resource)) {
          throw new CommerceError("invalid-argument", "نوع المورد غير صالح.");
        }
        if (s[resource] + 1 > 2147483647) {
          throw new CommerceError("failed-precondition", "بلغ الرصيد الحد الأقصى.");
        }
        takeAdAllowance(s, resource);
        s[resource] += 1;
        recordReward(s, `ad_${resource}_${at}`, "ad", { [resource]: 1 }, at);
      } else if (action === "claimVipBonus") {
        if (!e.isVip || Number(e.expiresAtMillis || 0) <= at) {
          throw new CommerceError("failed-precondition", "عضوية نادي الأبطال غير مفعلة.");
        }
        if (s.claimedVipExpiry >= Number(e.expiresAtMillis)) {
          throw new CommerceError("already-exists", "تم استلام هدية العضوية لهذه الفترة بالفعل.");
        }
        if (s.keys + 3 > 2147483647 || s.hearts + 3 > 2147483647 || s.tickets + 3 > 2147483647) {
          throw new CommerceError("failed-precondition", "بلغ الرصيد الحد الأقصى.");
        }
        s.keys += 3;
        s.hearts += 3;
        s.tickets += 3;
        s.claimedVipExpiry = Number(e.expiresAtMillis);
        const newCoins = Math.min(2147483647, integer(u.coins) + 1000);
        const newGems = Math.min(2147483647, integer(u.gems) + 100);
        userUpdate = { coins: newCoins, gems: newGems };
        result.currency = { coins: newCoins, gems: newGems };
        result.vipBonus = { coins: 1000, gems: 100, keys: 3, hearts: 3, tickets: 3 };
        recordReward(s, `vip_welcome_${e.expiresAtMillis}`, "vip_welcome", { coins: 1000, gems: 100, keys: 3, hearts: 3, tickets: 3 }, at);
      } else if (!readOnly) throw new CommerceError("invalid-argument", "العملية غير معروفة.");
      s.revision = integer(s.revision + 1);
      for (const [ref, data] of deferredWrites) tx.set(ref, data);
      tx.set(accountRef, s);
      if (userUpdate) tx.set(userRef, userUpdate, { merge: true });
      result.state = view(s, at, { ...u, ...userUpdate });
      // Native callers must not apply an out-of-order currency response over a
      // wallet already hydrated from a newer referral credit.
      result.referralRevision = integer(u.referralRevision);
      if (!readOnly) tx.set(receiptRef, { signature, result, createdAtMillis: at });
      return result;
    });
  }
  return { execute };
}
function refund(s, session) {
  if (session.source === "dailyKeys" || session.source === "dailyHearts") {
    if (s.day === session.day) s[session.source] = Math.min(3, s[session.source] + 1);
  } else s[session.source]++;
}
function lastWheelFreeSpinMillis(s, user = {}) {
  const explicit = Number(s?.lastFreeWheelSpinMillis || 0);
  if (explicit > 0) return explicit;
  const userSpinDate = timestampMillis(user?.lastLuckyWheelSpinDate);
  if (userSpinDate > 0) return userSpinDate;
  const legacyClaim = timestampMillis(user?.lastStreakClaimDate);
  if (legacyClaim > 0) return legacyClaim;
  if (s?.lastWheelSpinDay != null && s.lastWheelSpinDay >= 0) return s.lastWheelSpinDay * DAY;
  return 0;
}
function view(s, at, user = {}) {
  const day = Math.floor(at / DAY);
  const lastFree = lastWheelFreeSpinMillis(s, user);
  const wheelFreeAvailable = lastFree <= 0 || (at - lastFree) >= DAY;
  const wheelClaimedToday = !wheelFreeAvailable;
  const nextFreeWheelSpinMillis = wheelFreeAvailable ? at : lastFree + DAY;
  return { ...s, wheelClaimedToday, nextFreeWheelSpinMillis, lastFreeWheelSpinMillis: lastFree, wheelCatalogVersion: 2, wheelCharacterIndex: nextWheelCharacter(user), wheelPrizesV2: WHEEL_PRIZE_DISCLOSURE_V2, keysTotal: s.dailyKeys + s.keys, heartsTotal: s.dailyHearts + s.hearts, serverTimeMillis: at, nextResetMillis: (s.day + 1) * DAY, offers: OFFERS, rentalPrices: RENTALS, adRewardLimits: AD_REWARD_LIMITS };
}
module.exports = { createEconomyService, refresh, fresh, normalize, canonical, free, allowsAd, OFFERS, RENTALS, AD_REWARD_LIMITS, WHEEL_PRIZES, WHEEL_PRIZES_V2, WHEEL_CHARACTERS, milestone, streakReward };
