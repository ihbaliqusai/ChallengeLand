// LOCAL EMULATOR ONLY; reuses the official SDK from progression rule checks.
const { createRequire } = require('node:module');
const { resolve } = require('node:path');
const { readFileSync } = require('node:fs');
const { test, before, beforeEach, after } = require('node:test');
const assert = require('node:assert/strict');
const load = createRequire(resolve(__dirname, '../build/progression-rules/package.json'));
const { initializeTestEnvironment, assertSucceeds, assertFails } = load('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, deleteDoc, setLogLevel } = load('firebase/firestore');
setLogLevel('silent');

const address = process.env.FIRESTORE_EMULATOR_HOST;
if (!address || !/^(127\.0\.0\.1|localhost):\d+$/.test(address)) throw Error('Local FIRESTORE_EMULATOR_HOST required.');
let env, owner, stranger, guest;
const uid = 'referral-owner';
before(async () => {
  const [host, port] = address.split(':');
  env = await initializeTestEnvironment({ projectId: 'demo-challengeland-referrals', firestore: {
    host, port: Number(port), rules: readFileSync(resolve(__dirname, '../firestore.rules'), 'utf8'),
  } });
  owner = env.authenticatedContext(uid).firestore();
  stranger = env.authenticatedContext('other').firestore();
  guest = env.unauthenticatedContext().firestore();
});
beforeEach(async () => env.clearFirestore());
after(async () => { if (env) await env.cleanup(); });

test('only the owner reads a summary and no client can mint, edit or remove it', async () => {
  const path = `referral_accounts/${uid}`;
  await env.withSecurityRulesDisabled(async context => setDoc(doc(context.firestore(), path), { code: 'CL-1234567890AB', qualifiedCount: 2 }));
  assert.equal((await assertSucceeds(getDoc(doc(owner, path)))).data().qualifiedCount, 2);
  await assertFails(getDoc(doc(stranger, path)));
  await assertFails(getDoc(doc(guest, path)));
  await assertFails(setDoc(doc(owner, path), { qualifiedCount: 999 }));
  await assertFails(deleteDoc(doc(owner, path)));
});

test('code mappings, device hashes and acceptance tombstones are private to the backend', async () => {
  for (const path of ['referral_codes/CL-1234567890AB', 'referral_devices/hash', `referral_acceptances/${uid}`]) {
    await env.withSecurityRulesDisabled(async context => setDoc(doc(context.firestore(), path), { uid }));
    for (const db of [owner, stranger, guest]) {
      await assertFails(getDoc(doc(db, path)));
      await assertFails(setDoc(doc(db, path), { uid }));
      await assertFails(deleteDoc(doc(db, path)));
    }
  }
});

test('users cannot forge, clear or advance referral revisions, while normal merge saves still work', async () => {
  const ref = doc(owner, `users/${uid}`);
  await assertFails(setDoc(ref, { coins: 50, referralRevision: 5 }));
  await assertSucceeds(setDoc(ref, { coins: 50, gems: 2 }));
  await env.withSecurityRulesDisabled(async context => setDoc(doc(context.firestore(), `users/${uid}`), { referralRevision: 1 }, { merge: true }));
  await assertFails(setDoc(ref, { referralRevision: 2 }, { merge: true }));
  await assertFails(setDoc(ref, { referralRevision: 0 }, { merge: true }));
  await assertFails(setDoc(ref, { coins: 60, gems: 3 }));
  await assertSucceeds(setDoc(ref, { coins: 60, gems: 3 }, { merge: true }));
  assert.equal((await getDoc(ref)).data().referralRevision, 1);
});
