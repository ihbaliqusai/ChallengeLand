"use strict";
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { MemoryFirestore } = require("./memory-firestore");
const { createEconomyService, allowsAd, free, canonical, fresh, OFFERS, RENTALS } = require("../src/economy");
const { PRODUCTS, sha256 } = require("../src/domain");

function setup() {
  const db = new MemoryFirestore();
  let time = Date.UTC(2026, 9, 18, 12);
  const service = createEconomyService({ db, now: () => time });
  return { db, call: data => service.execute("p1", data), advance: days => { time += days * 86400000; } };
}

test("resource units and bundles preserve consistent quantities and offer increasing value", () => {
  const resources = ["keys", "hearts", "tickets"];
  const small = OFFERS.play_bundle;
  const large = OFFERS.play_bundle_large;
  for (const resource of resources) {
    const single = OFFERS[`${resource}_1`];
    const triple = OFFERS[`${resource}_3`];
    assert.equal(single.resource, resource);
    assert.equal(triple.resource, resource);
    assert.equal(single.amount, 1);
    assert.equal(triple.amount, 3);
    assert.equal(small.grants[resource], triple.amount);
    assert.equal(large.grants[resource], 10);
    assert.equal(PRODUCTS[`${resource}_1`][resource], single.amount);
    assert.equal(PRODUCTS[`${resource}_10`][resource], large.grants[resource]);
    assert.equal(PRODUCTS.resources_3_each[resource], small.grants[resource]);
    assert.equal(PRODUCTS.resources_10_each[resource], large.grants[resource]);
    for (const currency of ["coins", "gems"]) {
      assert.ok(triple[currency] < single[currency] * triple.amount, `${resource}: three units must save ${currency}`);
    }
  }
  for (const currency of ["coins", "gems"]) {
    const separate = resources.reduce((total, resource) => total + OFFERS[`${resource}_3`][currency], 0);
    assert.ok(small[currency] < separate, `small mixed bundle must save ${currency}`);
    assert.ok(large[currency] * 3 < small[currency] * 10, `large mixed bundle must cost less ${currency} per unit`);
  }
  for (const [id, offer] of Object.entries(OFFERS)) {
    assert.ok(Number.isSafeInteger(offer.coins) && offer.coins > 0, `${id}: valid coin price`);
    assert.ok(Number.isSafeInteger(offer.gems) && offer.gems > 0, `${id}: valid gem price`);
    assert.equal(offer.coins, offer.gems * 100, `${id}: consistent exchange rate`);
    const grants = offer.grants || { [offer.resource]: offer.amount };
    for (const [resource, quantity] of Object.entries(grants)) {
      assert.ok(resources.includes(resource), `${id}: known resource`);
      assert.ok(Number.isSafeInteger(quantity) && quantity > 0, `${id}: valid quantity`);
    }
  }
});

test("every listed virtual offer delivers its full contents once for either currency", async () => {
  for (const [offerId, offer] of Object.entries(OFFERS)) {
    for (const currency of ["coins", "gems"]) {
      const x = setup();
      x.db.seed("users/p1", { coins: 100000, gems: 1000 });
      const before = (await x.call({ action: "state" })).state;
      const purchase = { action: "buy", operationId: "catalog_purchase", offerId, currency };
      await x.call(purchase);
      const { state } = await x.call(purchase);
      const grants = offer.grants || { [offer.resource]: offer.amount };
      for (const resource of ["keys", "hearts", "tickets"]) {
        assert.equal(state[resource] - before[resource], grants[resource] || 0, `${offerId}/${currency}/${resource}`);
      }
      assert.deepEqual(x.db.read("users/p1"), {
        coins: 100000 - (currency === "coins" ? offer.coins : 0),
        gems: 1000 - (currency === "gems" ? offer.gems : 0),
      });
    }
  }
});

test("rental durations and prices reward longer use while remaining below permanent ownership", async () => {
  assert.deepEqual(RENTALS, {
    day: { days: 1, coins: 1500, gems: 15 },
    week: { days: 7, coins: 4500, gems: 45 },
    month: { days: 30, coins: 9000, gems: 90 },
  });
  for (const currency of ["coins", "gems"]) {
    assert.ok(RENTALS.week[currency] < RENTALS.day[currency] * 7);
    assert.ok(RENTALS.month[currency] < RENTALS.day[currency] * 30);
    assert.ok(RENTALS.month[currency] < RENTALS.week[currency] * 4 + RENTALS.day[currency] * 2);
    assert.ok(RENTALS.month[currency] * 7 < RENTALS.week[currency] * 30);
  }
  for (const [duration, rental] of Object.entries(RENTALS)) {
    assert.ok(rental.gems < 150, `${duration}: rental below permanent ownership`);
    assert.equal(rental.coins, rental.gems * 100);
    for (const currency of ["coins", "gems"]) {
      const x = setup();
      x.db.seed("users/p1", { coins: 100000, gems: 1000 });
      const request = { action: "rent", operationId: "rental_catalog", category: "أنمي", duration, currency };
      const result = await x.call(request);
      await x.call(request);
      assert.equal(result.state.rentals["انمي"], Date.UTC(2026, 9, 18, 12) + rental.days * 86400000);
      assert.deepEqual(x.db.read("users/p1"), {
        coins: 100000 - (currency === "coins" ? rental.coins : 0),
        gems: 1000 - (currency === "gems" ? rental.gems : 0),
      });
    }
  }
});

test("weekly progress counts every distinct series round without charging another key or counting retries", async () => {
  const x = setup();
  x.advance(1); // Start on Monday so all three days belong to the same week.
  x.db.seed("economy_accounts/p1", { ...fresh(Date.UTC(2026, 9, 19, 12)), dailyKeys: 0, keys: 5 });
  await x.call({ action: "begin", operationId: "weekly_series", mode: "challenge" });
  await x.call({ action: "commit", operationId: "weekly_series_commit", sessionId: "weekly_series" });
  const report = { action: "progressRound", sessionId: "weekly_series", roundId: "round_one", correct: 7, answered: 10, operationId: "first_report" };
  let result = await x.call(report);
  assert.equal(result.state.weekCorrect, 7);
  assert.equal(result.state.keys, 4);
  await x.call(report);
  result = await x.call({ ...report, operationId: "repeated_round_new_operation" });
  assert.equal(result.state.weekCorrect, 7);
  await x.call({ action: "finish", operationId: "first_round_finish", sessionId: "weekly_series", correct: 7, roundProgressVersion: 1 });
  x.advance(1);
  result = await x.call({ ...report, roundId: "round_two", operationId: "second_report" });
  assert.equal(result.state.weekCorrect, 14);
  assert.equal(result.state.weekDays.length, 2);
  assert.equal(result.state.weekRewardClaimed, false);
  x.advance(1);
  result = await x.call({ ...report, roundId: "round_three", operationId: "third_report" });
  assert.equal(result.state.weekCorrect, 21);
  assert.equal(result.state.weekDays.length, 3);
  assert.equal(result.state.weekRewardClaimed, true);
  assert.equal(result.state.keys, 5); // Five banked keys - one admission + one weekly reward.
  assert.equal(result.state.tickets, 4);
  const repeated = await x.call({ ...report, roundId: "round_three", operationId: "third_report_retry" });
  assert.equal(repeated.state.weekCorrect, 21);
  assert.equal(repeated.state.keys, 5);
  assert.equal(Object.keys(x.db.read(`economy_accounts/p1/operations/${sha256("weekly_series")}`).result.session.rounds).length, 3);
});

test("round progress rejects unstarted, campaign and invalid score reports", async () => {
  const x = setup();
  await x.call({ action: "begin", operationId: "not_committed", mode: "challenge" });
  const report = { action: "progressRound", sessionId: "not_committed", roundId: "round_one", correct: 7, answered: 10, operationId: "uncommitted_report" };
  await assert.rejects(x.call(report), { code: "failed-precondition" });
  await x.call({ action: "begin", operationId: "campaign_attempt", mode: "campaign", stageOrder: 1 });
  await x.call({ action: "commit", operationId: "campaign_commit", sessionId: "campaign_attempt" });
  await assert.rejects(x.call({ ...report, operationId: "campaign_report", sessionId: "campaign_attempt" }), { code: "failed-precondition" });
  await x.call({ action: "commit", operationId: "challenge_commit", sessionId: "not_committed" });
  for (const [id, invalid] of Object.entries({
    zero: { correct: 0, answered: 0 },
    incorrect_count: { correct: 11 },
    too_many: { answered: 1001 },
    negative: { correct: -1 },
    fractional: { correct: 1.5 },
    missing_round: { roundId: "" },
    long_round: { roundId: "r".repeat(257) },
  })) {
    await assert.rejects(x.call({ ...report, ...invalid, operationId: `invalid_${id}` }), { code: "invalid-argument" });
  }
  assert.equal((await x.call({ action: "state" })).state.weekCorrect, 0);
});

test("every account starts with exactly three of each; refresh, devices and daily reset never replay the gift", async () => {
  const x = setup();
  const states = await Promise.all([x.call({ action: "state" }), x.call({ action: "login", operationId: "first_login" })]);
  for (const { state } of states) {
    assert.equal(state.keysTotal, 3);
    assert.equal(state.heartsTotal, 3);
    assert.equal(state.tickets, 3);
    assert.equal(state.rewardLog.filter(r => r.id === "welcome").length, 1);
  }
  await x.call({ action: "begin", operationId: "use_welcome", mode: "challenge", categories: ["أنمي"] });
  await x.call({ action: "commit", operationId: "commit_welcome", sessionId: "use_welcome" });
  const result = await x.call({ action: "login", operationId: "another_device" });
  assert.equal(result.state.keysTotal, 2);
  assert.equal(result.state.tickets, 2);
  x.advance(1);
  const tomorrow = await x.call({ action: "login", operationId: "tomorrow" });
  assert.equal(tomorrow.state.keysTotal, 3);
  assert.equal(tomorrow.state.heartsTotal, 3);
  assert.equal(tomorrow.state.tickets, 2);
  const other = await createEconomyService({ db: x.db }).execute("p2", { action: "state" });
  assert.equal(other.state.tickets, 3);
  assert.equal(other.state.keysTotal, 3);
});

test("introducing the welcome gift to an existing wallet preserves purchased balances and pays once", async () => {
  const x = setup();
  const old = fresh(Date.UTC(2026, 9, 18, 12));
  delete old.welcomeGrantedAt; delete old.rewardLog;
  Object.assign(old, { keys: 8, hearts: 9, tickets: 7, dailyKeys: 0, dailyHearts: 1 });
  x.db.seed("economy_accounts/p1", old);
  await x.call({ action: "state" });
  const { state } = await x.call({ action: "state" });
  assert.equal(state.keys, 8); assert.equal(state.hearts, 9);
  assert.equal(state.tickets, 10); assert.equal(state.dailyKeys, 3); assert.equal(state.dailyHearts, 3);
  assert.equal(state.rewardLog.length, 1);
  x.db.seed("economy_accounts/p1", {});
  assert.equal((await x.call({ action: "state" })).state.tickets, 3);
});

test("VIP members may redeem permanent category rewards but cannot pay for a redundant rental", async () => {
  const x = setup();
  x.db.seed("economy_accounts/p1", { ...fresh(Date.UTC(2026, 9, 18, 12)), categoryVouchers: 1 });
  x.db.seed("commerce_accounts/p1/entitlements/current", { isVip: true, expiresAtMillis: Date.UTC(2026, 10, 18) });
  x.db.seed("users/p1", { coins: 10000 });
  await assert.rejects(x.call({ action: "rent", operationId: "vip_rent", category: "أنمي", duration: "day", currency: "coins" }), { code: "failed-precondition" });
  const result = await x.call({ action: "ownVoucher", operationId: "vip_own", category: "أنمي" });
  assert.equal(result.state.categoryVouchers, 0);
  assert.deepEqual(result.state.owned, ["أنمي"]);
  assert.equal(x.db.read("users/p1").coins, 10000);
});

test("legacy stage identifiers earn milestones once while foreign campaign progress is ignored", async () => {
  const x = setup();
  x.db.seed("users/p1/campaignProgress/stage_50", { campaignId: "main_campaign", stars: 3 });
  x.db.seed("users/p1/campaignProgress/stage_075", { campaignId: "other_campaign", stars: 3 });
  await x.call({ action: "state" });
  x.db.seed("users/p1/campaignProgress/stage_050", { campaignId: "main_campaign", stars: 3 });
  const { state } = await x.call({ action: "state" });
  assert.equal(state.categoryVouchers, 0);
  assert.equal(state.tickets, 3);
  assert.equal(state.keys, 1);
  assert.equal(state.hearts, 1);
  assert.deepEqual(state.milestones, ["50"]);
});

test("single units and mixed bundles debit once, deliver exact contents, and insufficient funds deliver nothing", async () => {
  const x = setup();
  x.db.seed("users/p1", { coins: 10000, gems: 200 });
  await x.call({ action: "buy", operationId: "single", offerId: "keys_1", currency: "coins" });
  const bundle = { action: "buy", operationId: "bundle", offerId: "play_bundle", currency: "gems" };
  await Promise.all([x.call(bundle), x.call(bundle)]);
  const before = (await x.call({ action: "state" })).state;
  assert.equal(before.keys, 4); assert.equal(before.hearts, 3); assert.equal(before.tickets, 6);
  assert.deepEqual(x.db.read("users/p1"), { coins: 9300, gems: 149 });
  await assert.rejects(x.call({ ...bundle, operationId: "unaffordable", offerId: "play_bundle_large" }), { code: "failed-precondition" });
  const after = (await x.call({ action: "state" })).state;
  assert.equal(after.tickets, before.tickets); assert.equal(after.keys, before.keys);
  for (const offerId of ["constructor", "toString", "__proto__"])
    await assert.rejects(x.call({ ...bundle, operationId: `invalid_${offerId}`, offerId }), { code: "invalid-argument" });
  await assert.rejects(x.call(null), { code: "invalid-argument" });
});

test("owned categories cannot be rented and legacy rental time is preserved", async () => {
  const x = setup();
  const expiry = Date.UTC(2026, 9, 20, 12);
  x.db.seed("users/p1", { coins: 10000, unlockedCategories: ["أنمي"], categoryRentals: { "رياضة": expiry } });
  const rent = { action: "rent", duration: "day", currency: "coins" };
  await assert.rejects(x.call({ ...rent, category: "أنمي", operationId: "owned_rental" }), { code: "failed-precondition" });
  const result = await x.call({ ...rent, category: "رياضة", operationId: "legacy_rental" });
  assert.equal(result.state.rentals["رياضه"], expiry + 86400000);
  assert.equal(x.db.read("users/p1").coins, 10000 - RENTALS.day.coins);
});

test("series rounds share a key and charge each new locked category only once", async () => {
  const x = setup();
  await x.call({ action: "begin", operationId: "series", mode: "challenge", categories: ["أنمي"] });
  await x.call({ action: "commit", operationId: "series_commit", sessionId: "series" });
  await x.call({ action: "finish", operationId: "round_result", sessionId: "series", correct: 7 });
  const extension = { action: "extend", sessionId: "series", categories: ["أنمي", "سبيس تون"] };
  await x.call({ ...extension, operationId: "round_two" });
  let result = await x.call({ ...extension, operationId: "round_two_retry" });
  assert.equal(result.state.keysTotal, 2);
  assert.equal(result.state.tickets, 1);
  assert.deepEqual(result.session.categories, ["أنمي", "سبيس تون"]);
  await x.call({ action: "ad", category: "رياضة", operationId: "round_ad" });
  result = await x.call({ ...extension, operationId: "round_three", categories: ["رياضة"] });
  assert.equal(result.state.tickets, 1);
  assert.equal(result.state.adPermits["رياضه"], undefined);
  await assert.rejects(x.call({ ...extension, operationId: "too_many", categories: ["أفلام عربية", "أفلام أجنبية"] }), { code: "resource-exhausted" });
  result = await x.call({ action: "state" });
  assert.equal(result.state.tickets, 1);
  assert.equal(result.state.keysTotal, 2);
});

test("weekly activity resets on Monday and a previous week's result cannot earn the new reward", async () => {
  const x = setup(); // Sunday.
  await x.call({ action: "begin", operationId: "sunday", mode: "challenge" });
  await x.call({ action: "commit", operationId: "commit_sunday", sessionId: "sunday" });
  x.advance(1);
  const result = await x.call({ action: "finish", operationId: "late_sunday", sessionId: "sunday", correct: 20 });
  assert.deepEqual(result.state.weekDays, []);
  assert.equal(result.state.weekCorrect, 0);
  assert.equal(result.state.weekRewardClaimed, false);
});

test("thirty-day loyalty and stage rewards remain banked and cannot be farmed by replaying", async () => {
  const x = setup();
  for (let d = 1; d <= 30; d++) {
    await x.call({ action: "login", operationId: `day_${d}` });
    await x.call({ action: "login", operationId: `replay_day_${d}` });
    if (d < 30) x.advance(1);
  }
  let { state } = await x.call({ action: "state" });
  assert.equal(state.keys, 4); assert.equal(state.hearts, 2);
  assert.equal(state.tickets, 5); assert.equal(state.rentalVouchers, 0);
  assert.equal(state.rewardLog.filter(r => r.kind === "login").length, 4);
  for (const stage of [10, 25, 50, 75, 100])
    x.db.seed(`users/p1/campaignProgress/stage_${String(stage).padStart(3, "0")}`, { status: "completed", stars: 3 });
  await x.call({ action: "state" });
  state = (await x.call({ action: "state" })).state;
  assert.equal(state.categoryVouchers, 0);
  assert.equal(state.keys, 10); assert.equal(state.hearts, 4);
  assert.equal(state.tickets, 6); assert.equal(state.rentalVouchers, 1);
  assert.equal(state.rewardLog.filter(r => r.kind === "campaign").length, 5);
});
test("category policies normalize aliases and restrict ads", () => {
  assert.equal(canonical("الأنيمي"), "أنمي");
  assert.equal(free("دين وإسلاميات"), true);
  assert.equal(free("معلومات عامة"), false);
  for (const c of ["أنمي", "مسلسل Friends", "سبيس تون", "أفلام أجنبية"]) assert.equal(allowsAd(c), false);
  assert.equal(allowsAd("خمن الصورة"), true);
});
test("concurrent match admission cannot overspend keys; replay does not debit again", async () => {
  const x = setup();
  const request = i => ({ action: "begin", operationId: `game_${i}`, mode: "challenge", categories: ["جغرافيا"] });
  const results = await Promise.allSettled([0, 1, 2, 3].map(i => x.call(request(i))));
  assert.equal(results.filter(r => r.status === "fulfilled").length, 3);
  assert.equal((await x.call(request(0))).state.keysTotal, 0);
  assert.equal((await x.call({ categories: ["جغرافيا"], mode: "challenge", operationId: "game_0", action: "begin" })).state.keysTotal, 0);
  await assert.rejects(x.call({ ...request(0), mode: "campaign", stageOrder: 1 }), { code: "already-exists" });
});
test("paid hearts survive reset; wins restore reserved heart; losses consume once", async () => {
  const x = setup();
  const state = fresh(Date.UTC(2026, 9, 18, 12)); state.hearts = 7;
  x.db.seed("economy_accounts/p1", state);
  await x.call({ action: "begin", operationId: "stage_a", mode: "campaign", stageOrder: 1 });
  let result = await x.call({ action: "finish", operationId: "win_a", sessionId: "stage_a", won: true });
  assert.equal(result.state.heartsTotal, 10);
  await x.call({ action: "begin", operationId: "stage_b", mode: "campaign", stageOrder: 1 });
  result = await x.call({ action: "finish", operationId: "loss_b", sessionId: "stage_b", won: false });
  assert.equal(result.state.heartsTotal, 9);
  result = await x.call({ action: "finish", operationId: "loss_b2", sessionId: "stage_b", won: false });
  assert.equal(result.state.heartsTotal, 9);
  x.advance(1);
  result = await x.call({ action: "state" });
  assert.equal(result.state.hearts, 7); assert.equal(result.state.dailyHearts, 3);
});
test("ad permits are category bound; tickets are used only for locked categories", async () => {
  const x = setup();
  x.db.seed("economy_accounts/p1", { ...fresh(Date.UTC(2026, 9, 18, 12)), tickets: 0 });
  await assert.rejects(x.call({ action: "ad", operationId: "ad_bad", category: "سبيس تون" }), { code: "permission-denied" });
  await x.call({ action: "ad", operationId: "ad_ok", category: "رياضة" });
  await x.call({ action: "begin", operationId: "match_ad", mode: "challenge", categories: ["رياضة", "جغرافيا"] });
  await assert.rejects(x.call({ action: "begin", operationId: "match_again", mode: "challenge", categories: ["رياضة"] }), { code: "resource-exhausted" });
  x.db.seed("users/p1", { coins: 2400, gems: 0 });
  await x.call({ action: "buy", operationId: "buy_tickets", offerId: "tickets_3", currency: "coins" });
  const result = await x.call({ action: "begin", operationId: "premium_match", mode: "challenge", categories: ["أنمي", "جغرافيا"] });
  assert.equal(result.state.tickets, 2); assert.equal(x.db.read("users/p1").coins, 0);
});
test("rentals extend, insufficient purchases are atomic, cancelled launch refunds", async () => {
  const x = setup();
  x.db.seed("users/p1", { coins: 10000, gems: 0 });
  const r = { action: "rent", category: "سبيس تون", duration: "day", currency: "coins" };
  let result = await x.call({ ...r, operationId: "r1" });
  const expires = result.state.rentals["سبيس تون"];
  result = await x.call({ ...r, operationId: "r2" });
  assert.equal(result.state.rentals["سبيس تون"], expires + 86400000);
  await assert.rejects(x.call({ ...r, operationId: "bad", duration: "month" }), { code: "failed-precondition" });
  await x.call({ action: "begin", operationId: "cancel_game", mode: "challenge", categories: ["سبيس تون"] });
  result = await x.call({ action: "cancel", operationId: "cancel_it", sessionId: "cancel_game" });
  assert.equal(result.state.keysTotal, 3);
});
test("committed matches cannot be cancelled and stage milestone resources pay once", async () => {
  const x = setup();
  await x.call({ action: "begin", operationId: "stage_50", mode: "campaign", stageOrder: 50 });
  await x.call({ action: "commit", operationId: "commit_50", sessionId: "stage_50" });
  await assert.rejects(x.call({ action: "cancel", operationId: "cancel_50", sessionId: "stage_50" }), { code: "failed-precondition" });
  let result = await x.call({ action: "finish", operationId: "finish_50", sessionId: "stage_50", won: true });
  assert.equal(result.state.categoryVouchers, 0);
  x.db.seed("users/p1/campaignProgress/stage_050", { status: "completed", stars: 1 });
  result = await x.call({ action: "state" });
  assert.equal(result.state.categoryVouchers, 0);
  assert.equal(result.state.keys, 1);
  assert.equal(result.state.hearts, 1);
  await x.call({ action: "begin", operationId: "stage_50_again", mode: "campaign", stageOrder: 50 });
  result = await x.call({ action: "finish", operationId: "finish_50_again", sessionId: "stage_50_again", won: true });
  assert.equal(result.state.keys, 1);
  assert.equal(result.state.hearts, 1);
  await assert.rejects(x.call({ action: "ownVoucher", operationId: "voucher", category: "أنمي" }), { code: "failed-precondition" });
});
test("loyalty uses server days and grants weekly keys once", async () => {
  const x = setup();
  for (let i = 0; i < 7; i++) {
    await x.call({ action: "login", operationId: `login_${i}` });
    if (i < 6) x.advance(1);
  }
  let result = await x.call({ action: "login", operationId: "login_repeat" });
  assert.equal(result.state.keys, 1); assert.equal(result.state.tickets, 3);
  x.advance(2);
  result = await x.call({ action: "login", operationId: "after_gap" });
  assert.equal(result.state.streak, 1); assert.equal(result.state.keys, 1);
});

test("weekly play rewards are earned once and account switching cannot redirect an operation", async () => {
  const x = setup();
  x.advance(1); // Monday: all three activity days belong to the same week.
  for (let i = 0; i < 3; i++) {
    await x.call({ action: "begin", operationId: `weekly_game_${i}`, mode: "challenge" });
    await x.call({ action: "finish", operationId: `weekly_finish_${i}`, sessionId: `weekly_game_${i}`, correct: 7 });
    if (i < 2) x.advance(1);
  }
  let result = await x.call({ action: "state" });
  assert.equal(result.state.keys, 1); assert.equal(result.state.tickets, 4);
  await x.call({ action: "finish", operationId: "another_finish", sessionId: "weekly_game_2", correct: 100 });
  result = await x.call({ action: "state" });
  assert.equal(result.state.keys, 1);
  await assert.rejects(x.call({ action: "state", expectedUid: "another-account" }), { code: "permission-denied" });
});

test("cancelled category admission restores both tickets and the category ad permit", async () => {
  const x = setup();
  const state = fresh(Date.UTC(2026, 9, 18, 12)); state.tickets = 2;
  x.db.seed("economy_accounts/p1", state);
  await x.call({ action: "ad", operationId: "advert", category: "رياضة" });
  const begin = { action: "begin", operationId: "cancel_paid", mode: "challenge", categories: ["أنمي", "رياضة"] };
  await x.call(begin);
  const result = await x.call({ action: "cancel", operationId: "cancel_paid_now", sessionId: "cancel_paid" });
  assert.equal(result.state.tickets, 2);
  assert.equal(result.state.adPermits["رياضه"], 1);
  assert.equal(result.state.keysTotal, 3);
  await assert.rejects(x.call(begin), { code: "failed-precondition" });
  await assert.rejects(x.call({ action: "commit", operationId: "cancelled_commit", sessionId: "cancel_paid" }), { code: "failed-precondition" });
});

test("the free question pool covers every campaign world's board width", () => {
  const fs = require("node:fs"), path = require("node:path");
  const questions = JSON.parse(fs.readFileSync(path.join(__dirname, "../../assets/questions.json"), "utf8"));
  const worlds = [["0", "1"], ["0", "1", "2"], ["1", "2"], ["2", "4"], ["2", "5"], ["4", "5"], ["5", "6"], ["6", "7"], ["7", "8"], ["3", "8"]];
  const { normalize } = require("../src/economy");
  for (const levels of worlds) {
    const pool = questions.filter(q => free(q.Category) && levels.includes(String(q.Level)));
    assert.equal(new Set(pool.map(q => normalize(q.Category))).size, 8);
    assert.ok(pool.length >= 48);
  }
});

test("an uncommitted admission is refunded after a crash without refunding started games", async () => {
  const x = setup();
  const state = fresh(Date.UTC(2026, 9, 18, 12));
  state.dailyHearts = 0; state.hearts = 5; state.tickets = 2;
  x.db.seed("economy_accounts/p1", state);
  await x.call({ action: "begin", operationId: "crashed_start", mode: "campaign", stageOrder: 1, categories: ["أنمي"] });
  x.advance(0.01);
  let result = await x.call({ action: "state" });
  assert.equal(result.state.hearts, 5); assert.equal(result.state.tickets, 2);
  await x.call({ action: "begin", operationId: "played_start", mode: "campaign", stageOrder: 1 });
  await x.call({ action: "commit", operationId: "played_commit", sessionId: "played_start" });
  x.advance(0.01);
  result = await x.call({ action: "state" });
  assert.equal(result.state.hearts, 4);
});

test("VIP bonus requires active membership, grants exact bundle once per cycle, and prevents duplicates", async () => {
  const x = setup();
  const time = Date.UTC(2026, 9, 18, 12);
  const expiry = time + 30 * 86400000;
  x.db.seed("users/p1", { coins: 500, gems: 20 });
  x.db.seed("economy_accounts/p1", fresh(time));

  // Non-VIP claim rejected
  await assert.rejects(
    x.call({ action: "claimVipBonus", operationId: "vip_claim_1" }),
    { code: "failed-precondition" }
  );

  // Seed active VIP
  x.db.seed("commerce_accounts/p1/entitlements/current", {
    isVip: true,
    expiresAtMillis: expiry,
  });

  // Successful claim
  const result = await x.call({ action: "claimVipBonus", operationId: "vip_claim_2" });
  assert.equal(result.currency.coins, 1500);
  assert.equal(result.currency.gems, 120);
  assert.equal(result.state.keys, 3);
  assert.equal(result.state.tickets, 6); // 3 welcome + 3 bonus
  assert.equal(result.state.hearts, 3);
  assert.equal(result.state.claimedVipExpiry, expiry);

  // Duplicate claim rejected
  await assert.rejects(
    x.call({ action: "claimVipBonus", operationId: "vip_claim_3" }),
    { code: "already-exists" }
  );

  // After subscription renewal with new expiry, can claim new cycle bonus
  const newExpiry = expiry + 30 * 86400000;
  x.db.seed("commerce_accounts/p1/entitlements/current", {
    isVip: true,
    expiresAtMillis: newExpiry,
  });
  const renewed = await x.call({ action: "claimVipBonus", operationId: "vip_claim_4" });
  assert.equal(renewed.currency.coins, 2500);
  assert.equal(renewed.currency.gems, 220);
  assert.equal(renewed.state.keys, 6);
  assert.equal(renewed.state.tickets, 9);
  assert.equal(renewed.state.hearts, 6);
  assert.equal(renewed.state.claimedVipExpiry, newExpiry);
  // An older entitlement arriving late must never reopen an already claimed period.
  x.db.seed("commerce_accounts/p1/entitlements/current", { isVip: true, expiresAtMillis: expiry });
  await assert.rejects(x.call({ action: "claimVipBonus", operationId: "old_period" }), { code: "already-exists" });
});

test("ad resource rewards grant exactly one unit, bind retries, and reject unsupported resources", async () => {
  const x = setup();
  let state = (await x.call({ action: "state" })).state;
  for (const resource of ["keys", "hearts", "tickets"]) {
    const input = { action: "adReward", resource, operationId: `ad_${resource}` };
    const first = await x.call(input);
    const replay = await x.call(input);
    assert.equal(first.state[resource], state[resource] + 1);
    assert.equal(replay.state[resource], first.state[resource]);
    state = replay.state;
  }
  await assert.rejects(x.call({ action: "adReward", resource: "coins", operationId: "bad_resource" }), { code: "invalid-argument" });
  await assert.rejects(x.call({ action: "adReward", resource: "tickets", operationId: "ad_keys" }), { code: "already-exists" });
  const full = fresh(Date.UTC(2026, 9, 18, 12)); full.keys = 2147483647;
  x.db.seed("economy_accounts/p1", full);
  await assert.rejects(x.call({ action: "adReward", resource: "keys", operationId: "full_wallet" }), { code: "failed-precondition" });
});

test("ad limits are atomic across devices, replay safely and reset without erasing banked resources", async () => {
  for (const resource of ["keys", "hearts", "tickets"]) {
    const x = setup();
    const before = (await x.call({ action: "state" })).state;
    const request = i => ({ action: "adReward", resource, operationId: `limited_ad_${i}` });
    const responses = await Promise.allSettled([0, 1, 2, 3].map(i => x.call(request(i))));
    assert.equal(responses.filter(r => r.status === "fulfilled").length, 2);
    for (const r of responses.filter(r => r.status === "rejected")) assert.equal(r.reason.code, "resource-exhausted");
    let { state } = await x.call(request(0));
    assert.equal(state[resource], before[resource] + 2);
    assert.equal(state.adRewardCounts[resource], 2);
    assert.equal(state.adRewardLimits[resource], 2);
    x.advance(1);
    // A stale receipt must never award a second unit or consume tomorrow's cap.
    ({ state } = await x.call(request(0)));
    assert.equal(state[resource], before[resource] + 2);
    assert.equal(state.adRewardCounts[resource] || 0, 0);
    ({ state } = await x.call(request(4)));
    assert.equal(state[resource], before[resource] + 3);
    assert.equal(state.adRewardCounts[resource], 1);
  }
});

test("category ads share the ticket limit and existing or refunded permits cannot farm extra trials", async () => {
  const x = setup();
  await x.call({ action: "adReward", resource: "tickets", operationId: "ticket_ad" });
  await x.call({ action: "ad", category: "رياضة", operationId: "category_ad" });
  let result = await x.call({ action: "ad", category: "رياضة", operationId: "same_permit" });
  assert.equal(result.state.adRewardCounts.tickets, 2);
  await assert.rejects(x.call({ action: "ad", category: "تاريخ", operationId: "extra_trial" }), { code: "resource-exhausted" });
  await assert.rejects(x.call({ action: "adReward", resource: "tickets", operationId: "extra_ticket" }), { code: "resource-exhausted" });
  await x.call({ action: "begin", mode: "campaign", stageOrder: 1, categories: ["رياضة"], operationId: "cancel_trial" });
  result = await x.call({ action: "cancel", sessionId: "cancel_trial", operationId: "cancel_trial_now" });
  assert.equal(result.state.adPermits["رياضه"], 1);
  assert.equal(result.state.adRewardCounts.tickets, 2);
  assert.equal(result.state.tickets, 4);
  x.advance(1);
  result = await x.call({ action: "ad", category: "تاريخ", operationId: "tomorrow_trial" });
  assert.equal(result.state.adRewardCounts.tickets, 1);
});

test("campaign resource budget is finite and previous rewards and purchases are grandfathered", async () => {
  const x = setup();
  const old = fresh(Date.UTC(2026, 9, 18, 12));
  Object.assign(old, { keys: 19, hearts: 17, tickets: 13, categoryVouchers: 2, rentalVouchers: 3, milestones: ["10", "50"] });
  x.db.seed("economy_accounts/p1", old);
  for (let order = 1; order <= 100; order++)
    x.db.seed(`users/p1/campaignProgress/stage_${String(order).padStart(3, "0")}`, { status: "completed", stars: 3 });
  await x.call({ action: "state" });
  const { state } = await x.call({ action: "state" });
  // New full-campaign budget: six keys, two hearts, five tickets, one rental.
  // Stages 10 and 50 were already paid; never grant them again under a new policy.
  assert.equal(state.keys, 19 + 4);
  assert.equal(state.hearts, 17 + 1);
  assert.equal(state.tickets, 13 + 5);
  assert.equal(state.categoryVouchers, 2);
  assert.equal(state.rentalVouchers, 4);
  assert.equal(new Set(state.milestones).size, state.milestones.length);
});

test("football player and player career categories accept a single-match ticket", async () => {
  for (const category of ["لاعبين كرة قدم", "مسيرة لاعب"]) {
    const x = setup();
    const result = await x.call({
      action: "begin",
      operationId: `ticket_${category === "مسيرة لاعب" ? "career" : "football"}`,
      mode: "challenge",
      categories: [category],
    });
    assert.deepEqual(result.session.categories, [category]);
    assert.equal(result.session.ticketCost, 1);
    assert.equal(result.state.tickets, 2);
  }
});
