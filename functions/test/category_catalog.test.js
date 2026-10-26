"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { join } = require("node:path");
const { MemoryFirestore } = require("./memory-firestore");
const { createEconomyService, canonical, normalize, free, allowsAd } = require("../src/economy");

const catalog = readFileSync(join(__dirname, "../../lib/models/game_category.dart"), "utf8");
function section(start, end) {
  assert.ok(catalog.includes(start) && catalog.includes(end), "client catalog declarations must exist");
  return catalog.split(start)[1].split(end)[0];
}
const premium = [...section("premiumCategories = [", "static const List<GameCategory> coreFreeCategories")
  .matchAll(/GameCategory\(name: '([^']+)'/g)].map(match => match[1]);
const coreFree = [...section("coreFreeCategories = [", "static bool allowsAd")
  .matchAll(/GameCategory\(name: '([^']+)'/g)].map(match => match[1]);
const noAds = [...section("return !const [", "].any(").matchAll(/'([^']+)'/g)].map(match => match[1]);

test("server accepts every client category with the same free and ad access policy", () => {
  assert.ok(premium.length > 0 && coreFree.length > 0 && noAds.length > 0);
  for (const category of [...premium, ...coreFree]) {
    assert.equal(canonical(category), category, category);
    assert.equal(free(category), coreFree.includes(category), category);
    assert.equal(allowsAd(category), premium.includes(category) && !noAds.includes(category), category);
  }
});

const addedCategories = [
  "دوري أبطال أوروبا", "NBA", "بنات وبس", "باب الحارة", "مسلسلات تركية",
  "دراما خليجية", "دراما سورية", "دراما مصرية", "Game Of Thrones", "Breaking Bad",
  "Harry Potter", "Pokémon", "Demon Slayer", "Hunter × Hunter", "One Piece",
  "Attack on Titan", "Naruto",
];
function setup() {
  const db = new MemoryFirestore();
  const at = Date.UTC(2026, 9, 26, 12);
  const service = createEconomyService({ db, now: () => at });
  return { db, at, call: input => service.execute("player", input) };
}

test("each added category starts and extends a challenge with one ticket and refunds an unstarted match", async () => {
  for (const category of addedCategories) {
    const x = setup();
    const begin = { action: "begin", operationId: "begin", mode: "challenge", categories: [category] };
    const result = await x.call(begin);
    assert.deepEqual(result.session.categories, [category]);
    assert.equal(result.state.keysTotal, 2, category);
    assert.equal(result.state.tickets, 2, category);
    assert.equal((await x.call(begin)).state.tickets, 2, "retry must not charge again");
    const cancelled = await x.call({ action: "cancel", operationId: "cancel", sessionId: "begin" });
    assert.equal(cancelled.state.keysTotal, 3, category);
    assert.equal(cancelled.state.tickets, 3, category);

    await x.call({ action: "begin", operationId: "series", mode: "challenge", categories: ["جغرافيا"] });
    await x.call({ action: "commit", operationId: "commit", sessionId: "series" });
    const extend = { action: "extend", operationId: "extend", sessionId: "series", categories: [category] };
    const extended = await x.call(extend);
    assert.deepEqual(extended.session.categories, ["جغرافيا", category]);
    assert.equal(extended.state.tickets, 2, category);
    assert.equal((await x.call({ ...extend, operationId: "extend_again" })).state.tickets, 2, category);
  }
});

test("each added category supports ownership, rental and the client's ad restriction", async () => {
  for (const category of addedCategories) {
    const x = setup();
    x.db.seed("users/player", { gems: 500, coins: 10000 });
    const rent = await x.call({ action: "rent", operationId: "rent", category, duration: "day", currency: "coins" });
    assert.equal(rent.state.rentals[normalize(category)], x.at + 86400000, category);
    const owned = await x.call({ action: "own", operationId: "own", category, currency: "gems" });
    assert.deepEqual(owned.state.owned, [category]);
    const match = await x.call({ action: "begin", operationId: "owned_match", mode: "challenge", categories: [category] });
    assert.equal(match.state.tickets, 3, "owned categories do not consume tickets");

    const trial = setup();
    const ad = { action: "ad", operationId: "ad", category };
    if (noAds.includes(category)) {
      await assert.rejects(trial.call(ad), { code: "permission-denied" }, category);
    } else {
      await trial.call(ad);
      const admitted = await trial.call({ action: "begin", operationId: "ad_match", mode: "challenge", categories: [category] });
      assert.equal(admitted.state.tickets, 3, category);
    }
  }
});

test("English aliases resolve to one category and do not charge duplicate tickets", async () => {
  assert.equal(canonical(" pokemon "), "Pokémon");
  assert.equal(canonical("Hunter x Hunter"), "Hunter × Hunter");
  const x = setup();
  const result = await x.call({ action: "begin", operationId: "aliases", mode: "challenge",
    categories: ["Pokémon", "pokemon", "Hunter × Hunter", "hunter x hunter"] });
  assert.deepEqual(result.session.categories, ["Pokémon", "Hunter × Hunter"]);
  assert.equal(result.state.tickets, 1);
});

test("unknown categories remain rejected without debiting the wallet", async () => {
  const x = setup();
  const before = (await x.call({ action: "state" })).state;
  await assert.rejects(x.call({ action: "begin", operationId: "unknown", mode: "challenge",
    categories: ["Breaking Bad", "unlisted category"] }), { code: "invalid-argument" });
  const after = (await x.call({ action: "state" })).state;
  assert.equal(after.tickets, before.tickets);
  assert.equal(after.keysTotal, before.keysTotal);
});
