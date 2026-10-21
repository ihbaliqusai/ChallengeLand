"use strict";
const assert = require("node:assert/strict");
// n blue-eyed reasoners wait for the n-1 case to leave, then leave on night n.
const departure = n => n === 1 ? 1 : departure(n - 1) + 1;
assert.equal(departure(100), 100);
// Pirate proposals: buy the cheapest floor(n/2) other votes, with one more
// coin than those voters would get after rejecting the current proposer.
function pirates(n) {
  if (n === 1) return [100];
  const next = pirates(n - 1), proposal = Array(n).fill(0);
  const votesNeeded = Math.ceil(n / 2) - 1;
  const prices = next.map((coins, i) => ({ coins: coins + 1, i: i + 1 })).sort((a, b) => a.coins - b.coins);
  for (const vote of prices.slice(0, votesNeeded)) proposal[vote.i] = vote.coins;
  proposal[0] = 100 - proposal.reduce((a, b) => a + b, 0);
  assert.ok(proposal[0] >= 0);
  return proposal;
}
assert.deepEqual(pirates(5), [98, 0, 1, 0, 1]);
// With n=2, deleting the first and last horse leaves disjoint singletons.
assert.deepEqual([new Set([1]), new Set([2])].map(s => s.size), [1, 1]);
assert.equal(64 / 2 - 2, 30);
assert.equal(64 / 2, 32); // mutilated board has 30 of one color, 32 of the other.
let best = { probability: -1 };
for (let white = 0; white <= 50; white++) for (let black = 0; black <= 50; black++) {
  const first = white + black, second = 100 - first;
  if (!first || !second) continue;
  const probability = 0.5 * (white / first + (50 - white) / second);
  if (probability > best.probability) best = { probability, white, black };
}
assert.ok(Math.abs(best.probability - 74 / 99) < 1e-12);
assert.ok(best.white === 1 && best.black === 0 || best.white === 49 && best.black === 50);
assert.equal(Math.round(100 / (2 * Math.PI)), 16);
const properSum = n => { let sum = 0; for (let i = 1; i < n; i++) if (n % i === 0) sum += i; return sum; };
let firstOdd;
for (let n = 1; n < 1000; n += 2) if (properSum(n) > n) { firstOdd = n; break; }
assert.equal(firstOdd, 945);
assert.equal(properSum(945), 975);
console.log("Puzzle assumptions and numeric answers verified.");
