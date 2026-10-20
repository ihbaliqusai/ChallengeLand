"use strict";

const { CommerceError, sha256 } = require("./domain");
const DAY = 86400000;
const weekId = at => Math.floor((Math.floor(at / DAY) + 3) / 7); // Monday, UTC.
const FREE = ["جغرافيا", "حيوانات", "دين واسلاميات", "عواصم", "دول", "اختراعات", "عملات", "لغة وادب"];
const NO_ADS = ["أنمي", "مسلسل Friends", "مسلسلات أجنبية", "مسلسلات عربية", "أفلام أجنبية", "أفلام عربية", "سبيس تون"];
const CATEGORIES = [...FREE, ...NO_ADS, "معلومات عامة", "تاريخ", "رياضة", "علوم وفضاء", "ألغاز", "أمثال", "تقنية", "جسم الإنسان", "نباتات", "لغات", "صحة", "طعام وشراب", "سياحة وسفر", "سيرة ذاتية", "قصص الأنبياء", "منوعات", "خمن الصورة", "خمن الأغنية", "خمن الأكلة", "خمن الاسم", "خمن المدينة او الدولة", "زووم", "ركز شوي", "وضح شوي", "سيارات", "كأس العالم", "فنون وسينما", "فيروز", "كلثوميات"];
function normalize(s) {
  const n = String(s || "").trim().replace(/[أإآ]/g, "ا").replace(/ة/g, "ه").replace(/ى/g, "ي").replace(/\s+/g, " ").toLowerCase();
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
    keys: 0, hearts: 0, tickets: 3, categoryVouchers: 0, rentalVouchers: 0, claimedVipExpiry: 0,
    welcomeGrantedAt: at, rewardLog: [{ id: "welcome", kind: "welcome", at, grants: { keys: 3, tickets: 3, hearts: 3 } }],
    owned: [], rentals: {}, adPermits: {}, milestones: [], streak: 0, lastLoginDay: -1,
    week: weekId(at), weekDays: [], weekCorrect: 0, weekRewardClaimed: false, revision: 0, reservations: {} };
}
function refresh(data, at) {
  const s = { ...fresh(at), ...data, owned: [...(data?.owned || [])], rentals: { ...(data?.rentals || {}) }, adPermits: { ...(data?.adPermits || {}) }, milestones: [...(data?.milestones || [])], reservations: { ...(data?.reservations || {}) } };
  s.rewardLog = [...(data?.rewardLog || (!data ? s.rewardLog : []))];
  s.claimedVipExpiry = Number(data?.claimedVipExpiry || 0);
  // Existing accounts receive the introduction once, without overwriting banked purchases.
  // The initial three keys/hearts are the first day's free allowance, not a second grant.
  if (data && !data.welcomeGrantedAt) {
    s.welcomeGrantedAt = at;
    s.dailyKeys = Math.max(3, s.dailyKeys); s.dailyHearts = Math.max(3, s.dailyHearts);
    s.tickets = integer(data.tickets) + 3;
    recordReward(s, "welcome", "welcome", { keys: 3, tickets: 3, hearts: 3 }, at);
  }
  if (s.day !== Math.floor(at / DAY)) Object.assign(s, { day: Math.floor(at / DAY), dailyKeys: 3, dailyHearts: 3 });
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
  if (day === 7) { s.keys += 3; s.tickets += 2; }
  if (day === 14) { s.keys += 3; s.hearts++; }
  if (day === 21) s.keys += 4;
  if (day === 30) { s.keys += 5; s.hearts += 2; s.tickets += 3; s.rentalVouchers++; }
}
function milestone(s, order) {
  const id = String(order);
  if (s.milestones.includes(id)) return;
  s.milestones.push(id);
  if (order % 10 === 0) s.tickets++;
  if (order === 10) s.keys += 2;
  if (order === 25) { s.keys += 3; s.rentalVouchers++; }
  if (order === 50 || order === 100) s.categoryVouchers++;
  if (order === 75) { s.keys += 5; s.hearts += 2; }
}

function weeklyProgress(s, day, correct, at) {
  s.weekDays = [...new Set([...(s.weekDays || []), day])];
  s.weekCorrect = Math.min(100000, s.weekCorrect + correct);
  if (!s.weekRewardClaimed && s.weekDays.length >= 3 && s.weekCorrect >= 20) {
    rewarded(s, `week_${s.week}`, "weekly", at, () => { s.keys += 2; s.tickets++; });
    s.weekRewardClaimed = true;
  }
}

function createEconomyService({ db, now = Date.now }) {
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
      const signature = sha256(JSON.stringify(stable({ ...input, operationId: undefined })));
      if (!readOnly && receipt.exists) {
        const old = receipt.data();
        if (old.signature !== signature) throw new CommerceError("already-exists", "استُخدم معرّف العملية لطلب مختلف.");
        if (action === "begin" && (old.result.session?.status === "cancelled" || (old.result.session?.mode === "campaign" && old.result.session?.status !== "active"))) throw new CommerceError("failed-precondition", "انتهت هذه المباراة. ابدأ مباراة جديدة.");
        return { ...old.result, ...(old.result.currency ? { currency: { coins: integer(u.coins), gems: integer(u.gems) } } : {}), state: view(s, at) };
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
          s.adPermits[key] = 1;
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
      result.state = view(s, at);
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
function view(s, at) {
  return { ...s, keysTotal: s.dailyKeys + s.keys, heartsTotal: s.dailyHearts + s.hearts, serverTimeMillis: at, nextResetMillis: (s.day + 1) * DAY, offers: OFFERS, rentalPrices: RENTALS };
}
module.exports = { createEconomyService, refresh, fresh, normalize, canonical, free, allowsAd, OFFERS, RENTALS, milestone, streakReward };
