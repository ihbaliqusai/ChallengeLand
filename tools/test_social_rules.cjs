// LOCAL EMULATOR ONLY. No production credentials or project are used.
const { createRequire } = require('node:module');
const { resolve } = require('node:path');
const { readFileSync } = require('node:fs');
const { test, before, beforeEach, after } = require('node:test');
const load = createRequire(resolve(__dirname, '../build/progression-rules/package.json'));
const { initializeTestEnvironment, assertSucceeds, assertFails } = load('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, getDoc, getDocs, query, collection, where, deleteDoc, writeBatch, Timestamp, serverTimestamp, setLogLevel } = load('firebase/firestore');
setLogLevel('silent');
const address = process.env.FIRESTORE_EMULATOR_HOST;
if (!address || !/^(127\.0\.0\.1|localhost):\d+$/.test(address)) throw Error('A local FIRESTORE_EMULATOR_HOST is required.');
let env, alice, bob, carol;
const stamp = offset => Timestamp.fromMillis(Date.now() + offset);
const pair = (a, b) => [a, b].sort().join(':');
const invitation = (a = 'alice', b = 'bob', challenge = true) => ({
  members: [a, b].sort(), fromUid: a, toUid: b, status: 'pending',
  createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  expiresAt: stamp(challenge ? 30000 : 7 * 86400000), ...(challenge ? { mode: 'duel' } : {}),
});
async function seed(path, data) {
  await env.withSecurityRulesDisabled(async ctx => setDoc(doc(ctx.firestore(), path), data));
}
function send(db, a = 'alice', b = 'bob', challenge = true, changes = {}) {
  const batch = writeBatch(db);
  batch.set(doc(db, `social_limits/${a}`), { [challenge ? 'challengeSentAt' : 'friendSentAt']: serverTimestamp() }, { merge: true });
  batch.set(doc(db, `${challenge ? 'social_challenges' : 'social_links'}/${pair(a, b)}`), { ...invitation(a, b, challenge), ...changes });
  return batch.commit();
}
function accept(db, a = 'alice', b = 'bob', changes = {}) {
  const id = pair(a, b);
  const batch = writeBatch(db);
  batch.update(doc(db, `social_challenges/${id}`), { status: 'accepted', acceptedAt: serverTimestamp(), updatedAt: serverTimestamp(), ...changes });
  for (const uid of [a, b]) batch.set(doc(db, `social_reservations/${uid}`), {
    challengeId: id, acceptedAt: serverTimestamp(), expiresAt: stamp(120000),
  });
  return batch.commit();
}
before(async () => {
  const [host, port] = address.split(':');
  env = await initializeTestEnvironment({ projectId: 'demo-challengeland-social', firestore: { host, port: Number(port), rules: readFileSync(resolve(__dirname, '../firestore.rules'), 'utf8') } });
  alice = env.authenticatedContext('alice').firestore();
  bob = env.authenticatedContext('bob').firestore();
  carol = env.authenticatedContext('carol').firestore();
});
beforeEach(async () => {
  await env.clearFirestore();
  for (const uid of ['alice', 'bob', 'carol']) {
    await seed(`users/${uid}`, { uid });
    await seed(`player_presence/${uid}`, { uid, heartbeatAt: stamp(0), state: 'available', discoverable: true });
  }
});
after(async () => { if (env) await env.cleanup(); });

test('owner heartbeat works; forged account, state and timestamp fail', async () => {
  await assertSucceeds(setDoc(doc(alice, 'player_presence/alice'), { uid: 'alice', heartbeatAt: serverTimestamp(), state: 'available', discoverable: true }));
  await assertFails(setDoc(doc(bob, 'player_presence/alice'), { uid: 'alice', heartbeatAt: serverTimestamp(), state: 'available', discoverable: true }));
  await assertFails(updateDoc(doc(alice, 'player_presence/alice'), { state: 'invented', heartbeatAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(alice, 'player_presence/alice'), { heartbeatAt: stamp(3600000) }));
});
test('hidden player is absent from discovery, visible only to self and friends', async () => {
  await seed('social_settings/bob', { discoverable: false, allowChallenges: 'friends' });
  await assertSucceeds(setDoc(doc(bob, 'player_presence/bob'), { uid: 'bob', state: 'available', discoverable: false, heartbeatAt: serverTimestamp() }));
  await assertFails(getDoc(doc(alice, 'player_presence/bob')));
  await seed('social_links/alice:bob', { ...invitation('alice', 'bob', false), status: 'accepted' });
  await assertSucceeds(getDoc(doc(alice, 'player_presence/bob')));
  await assertSucceeds(getDocs(query(collection(alice, 'player_presence'), where('discoverable', '==', true))));
});
test('friend request requires recipient consent and participant queries', async () => {
  await assertSucceeds(send(alice, 'alice', 'bob', false));
  const ref = db => doc(db, 'social_links/alice:bob');
  await assertFails(updateDoc(ref(alice), { status: 'accepted', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(ref(carol), { status: 'accepted', updatedAt: serverTimestamp() }));
  await assertFails(getDoc(ref(carol)));
  await assertSucceeds(getDocs(query(collection(bob, 'social_links'), where('members', 'array-contains', 'bob'))));
  await assertSucceeds(updateDoc(ref(bob), { status: 'accepted', updatedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(ref(alice), { status: 'removed', updatedAt: serverTimestamp() }));
});
test('sender can cancel and recipient can decline; identities stay immutable', async () => {
  await assertSucceeds(send(alice, 'alice', 'bob', false));
  await assertFails(updateDoc(doc(bob, 'social_links/alice:bob'), { fromUid: 'bob', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(bob, 'social_links/alice:bob'), { status: 'cancelled', updatedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(doc(bob, 'social_links/alice:bob'), { status: 'declined', updatedAt: serverTimestamp() }));
});
test('rate limit spans targets and cannot be erased while account exists', async () => {
  await assertSucceeds(send(alice, 'alice', 'bob', false));
  await assertFails(send(alice, 'alice', 'carol', false));
  await assertFails(deleteDoc(doc(alice, 'social_limits/alice')));
  await assertFails(setDoc(doc(alice, 'social_limits/alice'), { friendSentAt: stamp(-60000) }));
});
test('forged sender, self invite, extended expiry, reversed pair and chat fields fail', async () => {
  await assertFails(send(bob));
  await assertFails(send(alice, 'alice', 'alice'));
  await assertFails(send(alice, 'alice', 'bob', true, { expiresAt: stamp(3600000) }));
  await assertFails(send(alice, 'alice', 'bob', true, { message: 'not supported' }));
  const batch = writeBatch(alice);
  batch.set(doc(alice, 'social_limits/alice'), { challengeSentAt: serverTimestamp() });
  batch.set(doc(alice, 'social_challenges/bob:alice'), invitation());
  await assertFails(batch.commit());
});
test('challenge needs fresh and available players', async () => {
  await seed('player_presence/bob', { uid: 'bob', heartbeatAt: stamp(-76000), state: 'available', discoverable: true });
  await assertFails(send(alice));
  await seed('player_presence/bob', { uid: 'bob', heartbeatAt: stamp(0), state: 'in_match', discoverable: true });
  await assertFails(send(alice));
});
test('friends-only policy permits a friend within rules read budget', async () => {
  await seed('social_settings/bob', { discoverable: true, allowChallenges: 'friends' });
  await assertFails(send(alice));
  await seed('social_links/alice:bob', { ...invitation('alice', 'bob', false), status: 'accepted' });
  await assertSucceeds(send(alice));
  await assertSucceeds(accept(bob));
});
test('none policy rejects challenges even from friends', async () => {
  await seed('social_settings/bob', { discoverable: true, allowChallenges: 'none' });
  await seed('social_links/alice:bob', { ...invitation('alice', 'bob', false), status: 'accepted' });
  await assertFails(send(alice));
});
test('block in either direction prevents new requests and acceptance', async () => {
  await assertSucceeds(send(alice));
  await assertSucceeds(setDoc(doc(bob, 'social_blocks/bob:alice'), { ownerUid: 'bob', targetUid: 'alice', createdAt: serverTimestamp() }));
  await assertFails(accept(bob));
  await assertFails(send(alice, 'alice', 'bob', false));
  await assertFails(send(bob, 'bob', 'alice', false));
  await assertFails(deleteDoc(doc(alice, 'social_blocks/bob:alice')));
});
test('acceptance atomically reserves both players; unreserved or sender acceptance fails', async () => {
  await assertSucceeds(send(alice));
  await assertFails(updateDoc(doc(bob, 'social_challenges/alice:bob'), { status: 'accepted', acceptedAt: serverTimestamp(), updatedAt: serverTimestamp() }));
  await assertFails(accept(alice));
  await assertSucceeds(accept(bob));
  await assertFails(send(carol, 'carol', 'bob'));
  await assertFails(setDoc(doc(carol, 'social_reservations/bob'), { challengeId: 'bob:carol', acceptedAt: serverTimestamp(), expiresAt: stamp(120000) }));
});
test('two pending challenges cannot both be accepted into simultaneous games', async () => {
  await assertSucceeds(send(alice));
  await assertSucceeds(send(carol, 'carol', 'bob'));
  await assertSucceeds(accept(bob));
  await assertFails(accept(bob, 'carol', 'bob'));
});
test('expired, cancelled and already accepted invitations cannot return', async () => {
  await seed('social_challenges/alice:bob', { ...invitation(), createdAt: stamp(-40000), updatedAt: stamp(-40000), expiresAt: stamp(-1000) });
  await assertFails(accept(bob));
  await assertSucceeds(send(alice));
  await assertSucceeds(updateDoc(doc(alice, 'social_challenges/alice:bob'), { status: 'cancelled', updatedAt: serverTimestamp() }));
  await assertFails(accept(bob));
  await assertFails(send(alice));
});
test('outsiders cannot change privacy, read invitations or enumerate friend lists', async () => {
  await assertSucceeds(send(alice));
  await assertFails(getDoc(doc(carol, 'social_challenges/alice:bob')));
  await assertFails(getDocs(collection(carol, 'social_links')));
  await assertFails(setDoc(doc(carol, 'social_settings/bob'), { discoverable: true, allowChallenges: 'everyone' }));
  await assertFails(setDoc(doc(bob, 'social_settings/bob'), { discoverable: true, allowChallenges: 'everyone', email: 'private' }));
});

test('anonymous accounts cannot create social requests', async () => {
  const guest = env.authenticatedContext('alice', { firebase: { sign_in_provider: 'anonymous' } }).firestore();
  await assertFails(send(guest, 'alice', 'bob', false));
  await assertFails(send(guest));
});
test('simultaneous acceptances allow exactly one game for the recipient', async () => {
  await assertSucceeds(send(alice));
  await assertSucceeds(send(carol, 'carol', 'bob'));
  const results = await Promise.allSettled([accept(bob), accept(bob, 'carol', 'bob')]);
  const assert = require('node:assert/strict');
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
});
test('reservation stays locked until expiry or a genuine presence return transition', async () => {
  await assertSucceeds(send(alice)); await assertSucceeds(accept(bob));
  await assertFails(deleteDoc(doc(alice, 'social_reservations/alice')));
  await seed('player_presence/alice', { uid: 'alice', heartbeatAt: stamp(0), state: 'in_match', discoverable: true });
  const batch = writeBatch(alice);
  batch.set(doc(alice, 'player_presence/alice'), { uid: 'alice', heartbeatAt: serverTimestamp(), state: 'available', discoverable: true });
  batch.delete(doc(alice, 'social_reservations/alice'));
  await assertSucceeds(batch.commit());
});

test('paid invitations can only be created and changed by the server', async () => {
  await assertFails(send(alice, 'alice', 'bob', true, {
    serverStake: true, stakeCoins: 50, prizeCoins: 100, stakeMatchId: 'paid-match',
  }));
  await seed('social_challenges/alice:bob', {
    ...invitation(), createdAt: stamp(-1000), updatedAt: stamp(-1000),
    serverStake: true, stakeCoins: 50, prizeCoins: 100, stakeMatchId: 'paid-match',
  });
  await assertSucceeds(getDoc(doc(bob, 'social_challenges/alice:bob')));
  await assertFails(updateDoc(doc(bob, 'social_challenges/alice:bob'), {
    status: 'accepted', acceptedAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(alice, 'social_challenges/alice:bob'), {
    stakeCoins: 1000, updatedAt: serverTimestamp(),
  }));
  await assertFails(deleteDoc(doc(alice, 'social_challenges/alice:bob')));
});

test('paid match answers, escrow and operation records remain server-only', async () => {
  await seed('friend_stake_matches/paid-match', {
    members: ['alice', 'bob'], correctOption: 2, status: 'active',
  });
  await seed('friend_stake_views/paid-match', {
    members: ['alice', 'bob'], status: 'active', scores: { alice: 0, bob: 0 },
  });
  await assertFails(getDoc(doc(alice, 'friend_stake_matches/paid-match')));
  await assertFails(setDoc(doc(alice, 'friend_stake_matches/paid-match'), {
    members: ['alice', 'bob'], winnerId: 'alice', status: 'settled',
  }));
  await assertSucceeds(getDoc(doc(alice, 'friend_stake_views/paid-match')));
  await assertSucceeds(getDoc(doc(bob, 'friend_stake_views/paid-match')));
  await assertFails(getDoc(doc(carol, 'friend_stake_views/paid-match')));
  await assertFails(updateDoc(doc(alice, 'friend_stake_views/paid-match'), {
    status: 'settled', winnerId: 'alice',
  }));
  await assertFails(setDoc(doc(alice, 'friend_stake_locks/alice'), { active: false }));
  await seed('friend_stake_escrows/paid-match', {
    members: ['alice', 'bob'], stakeCoins: 50, status: 'held',
  });
  await assertFails(getDoc(doc(alice, 'friend_stake_escrows/paid-match')));
  await assertFails(updateDoc(doc(alice, 'friend_stake_escrows/paid-match'), { status: 'refunded' }));
  await assertFails(setDoc(doc(alice, 'friend_stake_operations/alice/items/replay'), {
    result: { winnerId: 'alice' },
  }));
});

test('a held stake cannot be undone by a wallet snapshot or account deletion', async () => {
  await seed('users/alice', {
    uid: 'alice', coins: 485, gems: 10,
    friendStakeRevision: 1, friendStakeMatchId: 'paid-match',
  });
  await assertFails(updateDoc(doc(alice, 'users/alice'), { coins: 500 }));
  await assertFails(updateDoc(doc(alice, 'users/alice'), { friendStakeMatchId: '' }));
  await assertFails(updateDoc(doc(alice, 'users/alice'), { friendStakeRevision: 0 }));
  await assertFails(deleteDoc(doc(alice, 'users/alice')));
  await assertSucceeds(updateDoc(doc(alice, 'users/alice'), { username: 'Alice' }));
  await seed('users/alice', {
    uid: 'alice', coins: 515, gems: 10,
    friendStakeRevision: 2, friendStakeMatchId: '',
  });
  await assertFails(updateDoc(doc(alice, 'users/alice'), { friendStakeRevision: 3 }));
});

test('paid reservations survive presence changes and cannot be replaced by free acceptance', async () => {
  await seed('social_reservations/alice', {
    challengeId: 'alice:bob', stakeMatchId: 'paid-match', serverStake: true,
    acceptedAt: stamp(-1000), expiresAt: stamp(120000),
  });
  await assertFails(deleteDoc(doc(alice, 'social_reservations/alice')));
  await assertFails(updateDoc(doc(alice, 'social_reservations/alice'), {
    serverStake: false, expiresAt: stamp(-1000),
  }));
  await seed('player_presence/alice', {
    uid: 'alice', heartbeatAt: stamp(0), state: 'in_match', discoverable: true,
  });
  const batch = writeBatch(alice);
  batch.set(doc(alice, 'player_presence/alice'), {
    uid: 'alice', heartbeatAt: serverTimestamp(), state: 'available', discoverable: true,
  });
  batch.delete(doc(alice, 'social_reservations/alice'));
  await assertFails(batch.commit());
});

test('free challenges resume after paid invitation expiry or settlement, but not during a paid match', async () => {
  const oldPaid = {
    ...invitation(), serverStake: true, stakeCoins: 50, prizeCoins: 100,
    stakeMatchId: 'paid-match', createdAt: stamp(-60000), updatedAt: stamp(-40000),
    expiresAt: stamp(-1000),
  };
  await seed('social_challenges/alice:bob', oldPaid);
  await assertSucceeds(send(alice));
  await seed('social_challenges/alice:bob', { ...oldPaid, status: 'accepted' });
  await seed('friend_stake_views/paid-match', {
    members: ['alice', 'bob'], status: 'active',
  });
  await seed('social_limits/alice', { challengeSentAt: stamp(-20000) });
  await assertFails(send(alice));
  await seed('friend_stake_views/paid-match', {
    members: ['alice', 'bob'], status: 'settled',
  });
  await assertSucceeds(send(alice));
});
