// Real Firestore transaction checks. This file refuses production endpoints.
const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const { resolve } = require('node:path');
const address = process.env.FIRESTORE_EMULATOR_HOST;
if (!address || !/^(127\.0\.0\.1|localhost):\d+$/.test(address)) {
  throw new Error('A local FIRESTORE_EMULATOR_HOST is required.');
}
const load = createRequire(resolve(__dirname, '../functions/package.json'));
const { initializeApp, deleteApp } = load('firebase-admin/app');
const { getFirestore, Timestamp } = load('firebase-admin/firestore');
const { createFriendStakesService } = require('../functions/src/friend_stakes');
const app = initializeApp({ projectId: 'demo-challengeland-stakes-integration' }, 'paid-duel-test');
const db = getFirestore(app);
after(async () => { await db.terminate(); await deleteApp(app); });

test('real concurrent transactions debit and settle a complete paid match once', async () => {
  const prefix = `paid_${Date.now()}`;
  const owner = `${prefix}_owner`, guest = `${prefix}_guest`;
  let at = Date.now();
  const bank = ['جغرافيا', 'حيوانات'].flatMap(category => [0, 1, 2, 4, 6, 7].map(level => ({
    category, level, text: `${category} ${level}`, answers: ['لندن', 'باريس', 'دمشق', 'بيروت'],
  })));
  const service = createFriendStakesService({ db, now: () => at, draw: () => 0, questionBank: bank });
  await Promise.all([owner, guest].flatMap(uid => [
    db.doc(`users/${uid}`).set({ coins: 500, gems: 10 }),
    db.doc(`player_presence/${uid}`).set({ state: 'available', heartbeatAt: Timestamp.fromMillis(at) }),
  ]));
  let operation = 0;
  const call = (uid, input) => service.execute(uid, {
    ...(input.action === 'sync' ? {} : { operationId: `integration_${++operation}` }), ...input,
  });
  const invitation = await call(owner, { action: 'invite', peerUid: guest, stakeCoins: 50, gameplayVersion: 2 });
  const acceptance = { action: 'respond', challengeId: invitation.challengeId,
    expectedAmount: 50, status: 'accepted', operationId: 'same_acceptance', gameplayVersion: 2 };
  const accepted = await Promise.all([call(guest, acceptance), call(guest, acceptance)]);
  const matchId = accepted[0].matchId;
  assert.equal(accepted[1].matchId, matchId);
  assert.equal((await db.doc(`users/${owner}`).get()).data().coins, 450);
  assert.equal((await db.doc(`users/${guest}`).get()).data().coins, 450);
  await call(owner, { action: 'pickCategory', matchId, category: 'جغرافيا' });
  await call(guest, { action: 'pickCategory', matchId, category: 'حيوانات' });
  for (let turn = 0; turn < 12; turn++) {
    const uid = turn % 2 === 0 ? owner : guest;
    const col = turn % 2, row = Math.floor(turn / 2);
    await call(uid, { action: 'claim', matchId, turn, col, row });
    const begun = await call(uid, { action: 'beginAnswer', matchId, turn });
    assert.equal(begun.question.rightAnswer, undefined);
    assert.equal(begun.question.answers, undefined);
    const answer = { action: 'answer', matchId, turn,
      answerText: uid === owner ? 'لندن' : 'باريس',
      operationId: `answer_${turn}` };
    await Promise.all([call(uid, answer), call(uid, answer)]);
    at += 5000;
  }
  await Promise.all([call(owner, { action: 'sync', matchId }), call(guest, { action: 'sync', matchId })]);
  const [a, b, view] = await Promise.all([
    db.doc(`users/${owner}`).get(), db.doc(`users/${guest}`).get(),
    db.doc(`friend_stake_views/${matchId}`).get(),
  ]);
  assert.equal(a.data().coins, 550);
  assert.equal(b.data().coins, 450);
  assert.equal(a.data().friendStakeRevision, 2);
  assert.equal(b.data().friendStakeMatchId, '');
  assert.equal(view.data().settlement.payoutCoins, 100);
  assert.equal(view.data().settlement.winnerId, owner);
  assert.equal(view.data().currentTurn, 12);
  assert.equal(JSON.stringify(view.data()).includes('"correctOption":'), false);
  assert.equal(JSON.stringify(view.data()).includes('"answers":'), false);
});
