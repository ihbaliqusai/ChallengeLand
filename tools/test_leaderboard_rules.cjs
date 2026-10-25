// LOCAL EMULATOR ONLY. Reuses the official SDK installed for progression tests.
const { createRequire } = require('node:module');
const { resolve } = require('node:path');
const { readFileSync } = require('node:fs');
const { test, before, beforeEach, after } = require('node:test');
const assert = require('node:assert/strict');

const load = createRequire(resolve(__dirname,
  '../build/progression-rules/package.json'));
const { initializeTestEnvironment, assertSucceeds, assertFails } =
  load('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, setLogLevel } = load('firebase/firestore');
setLogLevel('silent');

const address = process.env.FIRESTORE_EMULATOR_HOST;
if (!address || !/^(127\.0\.0\.1|localhost):\d+$/.test(address)) {
  throw Error('A local FIRESTORE_EMULATOR_HOST is required.');
}
let env, owner, stranger;
const uid = 'leaderboard-owner';

before(async () => {
  const [host, port] = address.split(':');
  env = await initializeTestEnvironment({
    projectId: 'demo-challengeland-leaderboard',
    firestore: {
      host, port: Number(port),
      rules: readFileSync(resolve(__dirname, '../firestore.rules'), 'utf8'),
    },
  });
  owner = env.authenticatedContext(uid).firestore();
  stranger = env.authenticatedContext('other-player').firestore();
});
beforeEach(async () => env.clearFirestore());
after(async () => { if (env) await env.cleanup(); });

test('owner can create and update their country before progression exists',
    async () => {
  const ref = doc(owner, `public_profiles/${uid}`);
  await assertSucceeds(setDoc(ref, { uid, countryCode: 'JO' }, { merge: true }));
  assert.equal((await getDoc(ref)).data().countryCode, 'JO');
  await assertSucceeds(setDoc(ref, { uid, countryCode: 'TR' }, { merge: true }));
  assert.equal((await getDoc(ref)).data().countryCode, 'TR');
});

test('malformed country codes are denied on create and merge update', async () => {
  const ref = doc(owner, `public_profiles/${uid}`);
  for (const countryCode of ['', 'jo', 'Jordan', 'J', 'JOR', 'J1', 12, null]) {
    await assertFails(setDoc(ref, { uid, countryCode }));
  }
  await assertSucceeds(setDoc(ref, { uid, countryCode: 'JO' }));
  for (const countryCode of ['', 'jo', 'Jordan', 'J', 'JOR', 'J1', 12, null]) {
    await assertFails(setDoc(ref, { countryCode }, { merge: true }));
  }
  assert.equal((await getDoc(ref)).data().countryCode, 'JO');
});

test('another account cannot create or change the owner country', async () => {
  const foreign = doc(stranger, `public_profiles/${uid}`);
  await assertFails(setDoc(foreign, { uid, countryCode: 'JO' }, { merge: true }));
  await assertSucceeds(setDoc(doc(owner, `public_profiles/${uid}`),
    { uid, countryCode: 'JO' }));
  await assertFails(setDoc(foreign, { countryCode: 'TR' }, { merge: true }));
  assert.equal((await getDoc(foreign)).data().countryCode, 'JO');
});

test('country identity merge preserves progression and later progression preserves country',
    async () => {
  const ref = doc(owner, `public_profiles/${uid}`);
  const progression = { uid, username: 'Player', xp: 250, level: 2,
    trophies: 22, bestTrophies: 22, wins: 1, gamesPlayed: 2 };
  await assertSucceeds(setDoc(ref, progression));
  await assertSucceeds(setDoc(ref, { uid, countryCode: 'JO' }, { merge: true }));
  assert.deepEqual((await getDoc(ref)).data(),
    { ...progression, countryCode: 'JO' });
  await assertSucceeds(setDoc(ref, { xp: 300, trophies: 30 }, { merge: true }));
  const saved = (await getDoc(ref)).data();
  assert.equal(saved.countryCode, 'JO');
  assert.equal(saved.xp, 300);
  assert.equal(saved.trophies, 30);
});
