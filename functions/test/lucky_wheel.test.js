"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");
const { MemoryFirestore } = require("./memory-firestore");
const { sha256 } = require("../src/domain");
const { createEconomyService, WHEEL_PRIZES, WHEEL_PRIZES_V2, WHEEL_CHARACTERS } = require("../src/economy");

function setup(prizeIndex = 0, user = {}, catalogVersion = 1) {
  const db = new MemoryFirestore();
  let time = Date.UTC(2026, 9, 25, 12);
  let selections = 0;
  const service = createEconomyService({ db, now: () => time, randomInt: max => {
    selections++;
    const catalogLength = catalogVersion === 2 ? WHEEL_PRIZES_V2.length : WHEEL_PRIZES.length;
    return max === catalogLength && (catalogVersion === 2 || selections === 1) ? prizeIndex : 0;
  } });
  db.seed("users/player", { coins: 100, gems: 5, username: "Player", ...user });
  return { db, call: input => service.execute("player", input),
    spin: operationId => service.execute("player", { action: "spinWheel", operationId,
      ...(catalogVersion === 2 ? { wheelCatalogVersion: 2 } : {}) }),
    at: () => time, advance: milliseconds => { time += milliseconds; },
    selections: () => selections };
}

test("all six equal wheel sectors deliver their real account prize", async () => {
  for (let index = 0; index < WHEEL_PRIZES.length; index++) {
    const x = setup(index);
    const before = (await x.call({ action: "state" })).state;
    const result = await x.spin(`sector_${index}`);
    const prize = WHEEL_PRIZES[index];
    assert.equal(result.spin.prizeIndex, index);
    assert.equal(result.spin.prizeId, prize.id);
    assert.equal(result.spin.newlyGranted, true);
    assert.equal(result.spin.usedFreeSpin, true);
    assert.deepEqual(result.spin.grants, prize.grants);
    assert.equal(result.state.keys - before.keys, prize.grants.keys || 0);
    assert.equal(result.state.tickets - before.tickets, prize.grants.tickets || 0);
    assert.equal(result.currency.coins, 100 + (prize.grants.coins || 0));
    assert.equal(result.currency.gems, 5 + (prize.grants.gems || 0));
    assert.equal(result.state.wheelClaimedToday, true);
    assert.equal(x.db.read("users/player").username, "Player");
    assert.equal(x.db.read("users/player").lastStreakClaimDate.getTime(), x.at());
    assert.equal(x.db.read("users/player").lastLuckyWheelSpinDate.getTime(), x.at());
    if (prize.id === "character") {
      assert.equal(result.spin.characterIndex, WHEEL_CHARACTERS[0]);
      assert.deepEqual(result.purchasedCharacters, [WHEEL_CHARACTERS[0]]);
      assert.deepEqual(x.db.read("users/player").purchasedCharacters, result.purchasedCharacters);
    }
  }
});

test("same-operation retries recover one committed daily result", async () => {
  const x = setup(5);
  const [first, second] = await Promise.all([x.spin("device_one"), x.spin("device_one")]);
  const repeated = await x.spin("device_one");
  assert.equal(first.spin.newlyGranted, true);
  assert.equal(second.spin.newlyGranted, false);
  assert.equal(repeated.spin.newlyGranted, false);
  assert.deepEqual(second.spin.grants, first.spin.grants);
  assert.deepEqual(repeated.spin.grants, first.spin.grants);
  assert.equal(x.selections(), 1);
  assert.equal(x.db.read("users/player").coins, 1100);
  assert.equal(second.state.keys, first.state.keys);
  assert.equal(second.state.rewardLog.filter(reward => reward.kind === "wheel").length, 1);
  await assert.rejects(x.spin("device_two"), { code: "failed-precondition" });
});

test("replayed currency reflects the current wallet instead of restoring spent coins", async () => {
  const x = setup(2);
  await x.spin("original_spin");
  x.db.seed("users/player", { ...x.db.read("users/player"), coins: 50 });
  assert.equal((await x.spin("original_spin")).currency.coins, 50);
  await assert.rejects(x.spin("another_device"), { code: "failed-precondition" });
  assert.equal(x.selections(), 1);
});

test("legacy daily claims consume the same UTC opportunity", async () => {
  const x = setup(0, { lastStreakClaimDate: new Date(Date.UTC(2026, 9, 25, 0, 1)) });
  assert.equal((await x.call({ action: "state" })).state.wheelClaimedToday, true);
  await assert.rejects(x.spin("after_legacy"), { code: "failed-precondition" });
  assert.equal(x.selections(), 0);
  assert.equal(x.db.read("users/player").coins, 100);
  x.advance(86400000);
  const next = await x.spin("following_day");
  assert.equal(next.spin.newlyGranted, true);
});

test("the next spin unlocks after 24 hours and old receipts remain idempotent", async () => {
  const x = setup(3);
  const first = await x.spin("before_cooldown");
  x.advance(24 * 3600000 - 1);
  await assert.rejects(x.spin("still_in_cooldown"), { code: "failed-precondition" });
  x.advance(1);
  assert.equal((await x.call({ action: "state" })).state.wheelClaimedToday, false);
  const old = await x.spin("before_cooldown");
  assert.equal(old.spin.newlyGranted, false);
  assert.deepEqual(old.spin.grants, first.spin.grants);
  const next = await x.spin("after_cooldown");
  assert.equal(next.spin.newlyGranted, true);
  assert.equal(next.state.wheelClaimedToday, true);
  assert.equal(x.db.read("users/player").streakDay, 2);
});

test("a free spin is used first and each extra spin consumes one paid credit", async () => {
  const x = setup(2);
  const initial = (await x.call({ action: "state" })).state;
  x.db.seed("economy_accounts/player", { ...initial, wheelSpins: 3 });
  const free = await x.spin("free");
  assert.equal(free.spin.usedFreeSpin, true);
  assert.equal(free.state.wheelSpins, 3);
  const streakDate = x.db.read("users/player").lastStreakClaimDate.getTime();
  for (let index = 0; index < 3; index++) {
    const paid = await x.spin(`paid_${index}`);
    assert.equal(paid.spin.usedFreeSpin, false);
    assert.equal(paid.spin.newlyGranted, true);
    assert.equal(paid.state.wheelSpins, 2 - index);
    assert.equal(paid.state.wheelClaimedToday, true);
    assert.equal(x.db.read("users/player").streakDay, 1);
    assert.equal(x.db.read("users/player").lastStreakClaimDate.getTime(), streakDate);
    const replay = await x.spin(`paid_${index}`);
    assert.equal(replay.spin.newlyGranted, false);
    assert.equal(replay.state.wheelSpins, 2 - index);
    assert.deepEqual(replay.spin.grants, paid.spin.grants);
  }
  assert.equal(x.selections(), 4);
  assert.equal(x.db.read("users/player").coins, 600);
  assert.equal(x.db.read("economy_accounts/player").keys, 3);
  await assert.rejects(x.spin("empty"), { code: "failed-precondition" });
  assert.equal(x.selections(), 4);
});

test("simultaneous different requests cannot overspend the final paid spin", async () => {
  const x = setup(0);
  await x.spin("today_free");
  const state = x.db.read("economy_accounts/player");
  x.db.seed("economy_accounts/player", { ...state, wheelSpins: 1 });
  const results = await Promise.allSettled([x.spin("device_a"), x.spin("device_b")]);
  assert.equal(results.filter(result => result.status === "fulfilled").length, 1);
  const rejected = results.find(result => result.status === "rejected");
  assert.equal(rejected.reason.code, "failed-precondition");
  assert.equal(x.db.read("economy_accounts/player").wheelSpins, 0);
  assert.equal(x.db.read("economy_accounts/player").keys, 2);
});

test("paid credits survive resets and old paid receipts do not consume today's free spin", async () => {
  const x = setup(0);
  await x.spin("first_free");
  x.db.seed("economy_accounts/player", { ...x.db.read("economy_accounts/player"), wheelSpins: 3 });
  const paid = await x.spin("first_paid");
  x.advance(86400000);
  const next = (await x.call({ action: "state" })).state;
  assert.equal(next.wheelSpins, 2);
  assert.equal(next.wheelClaimedToday, false);
  const old = await x.spin("first_paid");
  assert.equal(old.spin.newlyGranted, false);
  assert.deepEqual(old.spin.grants, paid.spin.grants);
  assert.equal(old.state.wheelSpins, 2);
  assert.equal(old.state.wheelClaimedToday, false);
  const free = await x.spin("next_free");
  assert.equal(free.spin.usedFreeSpin, true);
  assert.equal(free.state.wheelSpins, 2);
});

test("legacy daily users may spend paid spins without consuming another free opportunity", async () => {
  const claimedAt = Date.UTC(2026, 9, 25, 0, 1);
  const x = setup(1, { lastStreakClaimDate: new Date(claimedAt), streakDay: 7 });
  const initial = (await x.call({ action: "state" })).state;
  x.db.seed("economy_accounts/player", { ...initial, wheelSpins: 1 });
  const paid = await x.spin("legacy_paid");
  assert.equal(paid.spin.usedFreeSpin, false);
  assert.equal(paid.state.wheelSpins, 0);
  assert.equal(paid.state.wheelClaimedToday, true);
  assert.equal(x.db.read("users/player").lastStreakClaimDate.getTime(), claimedAt);
  assert.equal(x.db.read("users/player").streakDay, 7);
});

test("character prizes skip owned characters and compensate a complete roster", async () => {
  const remaining = WHEEL_CHARACTERS.at(-1);
  const x = setup(4, { purchasedCharacters: WHEEL_CHARACTERS.slice(0, -1) });
  const character = await x.spin("last_character");
  assert.equal(character.spin.characterIndex, remaining);
  assert.equal(character.spin.compensation, false);
  assert.deepEqual(character.purchasedCharacters, WHEEL_CHARACTERS);
  const full = setup(4, { purchasedCharacters: WHEEL_CHARACTERS });
  const compensation = await full.spin("full_roster");
  assert.equal(compensation.spin.prizeId, "character");
  assert.equal(compensation.spin.characterIndex, null);
  assert.equal(compensation.spin.compensation, true);
  assert.deepEqual(compensation.spin.grants, { gems: 100 });
  assert.equal(compensation.currency.gems, 105);
});

test("caller-supplied prize, amount and time cannot choose or enlarge a reward", async () => {
  const x = setup(0);
  const result = await x.call({ action: "spinWheel", operationId: "untrusted_selection",
    prizeIndex: 5, prizeId: "chest", grants: { gems: 100000 }, now: Date.UTC(2030, 0, 1) });
  assert.equal(result.spin.prizeId, "keys");
  assert.deepEqual(result.spin.grants, { keys: 1 });
  assert.equal(result.currency.gems, 5);
  assert.equal(result.state.lastWheelSpinDay, Math.floor(x.at() / 86400000));
});

test("wheel balances stay in the native signed integer range", async () => {
  const x = setup(5, { coins: 2147483646, gems: 2147483646 });
  const state = (await x.call({ action: "state" })).state;
  x.db.seed("economy_accounts/player", { ...state, keys: 2147483646, tickets: 2147483646 });
  const result = await x.spin("capped_chest");
  assert.deepEqual(result.currency, { coins: 2147483647, gems: 2147483647 });
  assert.equal(result.state.keys, 2147483647);
  assert.equal(result.state.tickets, 2147483647);
});

test("wheel operation IDs retain the economy account and payload checks", async () => {
  const x = setup();
  await assert.rejects(x.call({ action: "spinWheel", operationId: "account", expectedUid: "other" }), { code: "permission-denied" });
  await assert.rejects(x.call({ action: "spinWheel" }), { code: "invalid-argument" });
  await x.spin("payload_bound");
  await assert.rejects(x.call({ action: "buy", operationId: "payload_bound", offerId: "keys_1", currency: "coins" }), { code: "already-exists" });
});

test("v2 discloses twelve equal sectors and delivers every displayed quantity", async () => {
  for (let index = 0; index < WHEEL_PRIZES_V2.length; index++) {
    const x = setup(index, {}, 2);
    const before = (await x.call({ action: "state" })).state;
    assert.equal(before.wheelCatalogVersion, 2);
    assert.equal(before.wheelCharacterIndex, WHEEL_CHARACTERS[0]);
    assert.equal(before.wheelPrizesV2.length, 12);
    assert.equal(before.wheelPrizesV2.reduce((sum, prize) => sum + prize.probabilityNumerator, 0), 12);
    assert.ok(before.wheelPrizesV2.every(prize => prize.probabilityDenominator === 12));
    const result = await x.spin(`varied_sector_${index}`);
    const prize = WHEEL_PRIZES_V2[index];
    assert.equal(result.spin.catalogVersion, 2);
    assert.equal(result.spin.prizeIndex, index);
    assert.equal(result.spin.prizeId, prize.id);
    assert.deepEqual(result.spin.grants, prize.grants);
    assert.equal(result.spin.probabilityNumerator, 1);
    assert.equal(result.spin.probabilityDenominator, 12);
    assert.deepEqual(before.wheelPrizesV2[index], {
      id: prize.id, index, grants: prize.grants,
      probabilityNumerator: 1, probabilityDenominator: 12,
    });
    assert.equal(result.state.keys - before.keys, prize.grants.keys || 0);
    assert.equal(result.state.tickets - before.tickets, prize.grants.tickets || 0);
    assert.equal(result.currency.coins, 100 + (prize.grants.coins || 0));
    assert.equal(result.currency.gems, 5 + (prize.grants.gems || 0));
  }
});

test("v2 category chances and chest contents match the advertised twelve slots", async () => {
  const x = setup(5, {}, 2);
  const state = (await x.call({ action: "state" })).state;
  const counts = {};
  for (const prize of state.wheelPrizesV2) {
    const kind = prize.id.split("_")[0];
    counts[kind] = (counts[kind] || 0) + prize.probabilityNumerator;
  }
  assert.deepEqual(counts, { keys: 2, tickets: 2, coins: 3, gems: 3, character: 1, chest: 1 });
  const chest = state.wheelPrizesV2.find(prize => prize.id === "chest");
  assert.deepEqual(chest.grants, { coins: 1000, gems: 20, keys: 2, tickets: 2 });
  assert.deepEqual((await x.spin("chest_contents")).spin.grants, chest.grants);
});

test("v2 grants the previewed unowned character and then advances its replacement", async () => {
  const x = setup(4, { purchasedCharacters: [WHEEL_CHARACTERS[0]] }, 2);
  const before = (await x.call({ action: "state" })).state;
  x.db.seed("economy_accounts/player", { ...x.db.read("economy_accounts/player"), wheelSpins: 2 });
  assert.equal(before.wheelCharacterIndex, WHEEL_CHARACTERS[1]);
  for (let offset = 1; offset < 4; offset++) {
    const result = await x.spin(`new_character_${offset}`);
    assert.equal(result.spin.characterIndex, WHEEL_CHARACTERS[offset]);
    assert.equal(result.spin.compensation, false);
    assert.equal(result.state.wheelCharacterIndex, WHEEL_CHARACTERS[offset + 1]);
    assert.deepEqual(result.purchasedCharacters, WHEEL_CHARACTERS.slice(0, offset + 1));
    const retry = await x.spin(`new_character_${offset}`);
    assert.equal(retry.spin.characterIndex, WHEEL_CHARACTERS[offset]);
    assert.equal(retry.state.wheelCharacterIndex, WHEEL_CHARACTERS[offset + 1]);
    assert.equal(retry.state.wheelSpins, result.state.wheelSpins);
  }
});

test("v2 does not repeat legacy string character unlocks and compensates a complete roster", async () => {
  const x = setup(4, { purchasedCharacters: ["2", 4, "bad", -1, 20, 4] }, 2);
  assert.equal((await x.call({ action: "state" })).state.wheelCharacterIndex, WHEEL_CHARACTERS[2]);
  const result = await x.spin("legacy_character_unlocks");
  assert.equal(result.spin.characterIndex, WHEEL_CHARACTERS[2]);
  assert.deepEqual(result.purchasedCharacters, WHEEL_CHARACTERS.slice(0, 3));
  const full = setup(4, { purchasedCharacters: WHEEL_CHARACTERS.map(String) }, 2);
  assert.equal((await full.call({ action: "state" })).state.wheelCharacterIndex, null);
  const compensation = await full.spin("full_v2_roster");
  assert.equal(compensation.spin.characterIndex, null);
  assert.equal(compensation.spin.compensation, true);
  assert.equal(compensation.state.wheelCharacterIndex, null);
  assert.deepEqual(compensation.spin.grants, { gems: 100 });
  assert.equal(compensation.currency.gems, 105);
});

test("an outstanding pre-v2 receipt survives catalog upgrade without another debit or grant", async () => {
  const x = setup(2);
  const first = await x.spin("legacy_pending");
  const path = `economy_accounts/player/operations/${sha256("legacy_pending")}`;
  const oldReceipt = x.db.read(path);
  delete oldReceipt.result.spin.catalogVersion;
  delete oldReceipt.result.spin.probabilityNumerator;
  delete oldReceipt.result.spin.probabilityDenominator;
  x.db.seed(path, oldReceipt);
  const replay = await x.call({ action: "spinWheel", operationId: "legacy_pending", wheelCatalogVersion: 2 });
  assert.equal(replay.spin.newlyGranted, false);
  assert.equal(replay.spin.prizeId, first.spin.prizeId);
  assert.deepEqual(replay.spin.grants, first.spin.grants);
  assert.deepEqual(replay.currency, first.currency);
  assert.equal(replay.state.wheelSpins, 0);
  assert.equal(x.selections(), 1);
  await assert.rejects(x.call({ action: "spinWheel", operationId: "legacy_pending",
    wheelCatalogVersion: 2, grants: { gems: 9999 } }), { code: "already-exists" });
});

test("legacy clients retain their six-sector draw and random unowned character behavior", async () => {
  const db = new MemoryFirestore();
  const draws = [];
  const service = createEconomyService({ db, now: () => Date.UTC(2026, 9, 26), randomInt: max => {
    draws.push(max);
    return max === WHEEL_PRIZES.length ? 4 : max - 1;
  } });
  db.seed("users/old_client", { coins: 10, gems: 0 });
  const result = await service.execute("old_client", { action: "spinWheel", operationId: "old_client_draw" });
  assert.deepEqual(draws, [6, 8]);
  assert.equal(result.spin.catalogVersion, 1);
  assert.equal(result.spin.probabilityDenominator, 6);
  assert.equal(result.spin.characterIndex, WHEEL_CHARACTERS.at(-1));
  assert.equal(result.state.wheelCharacterIndex, WHEEL_CHARACTERS[0]);
});
