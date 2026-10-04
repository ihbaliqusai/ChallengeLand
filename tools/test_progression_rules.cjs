// Local-only integration test. See docs/PROGRESSION_REVIEW_AR.md for setup.
// Uses the official Firebase rules testing SDK; never connects to production.
const { createRequire } = require('node:module');
const { resolve } = require('node:path');
const { readFileSync } = require('node:fs');
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');

const localRequire = createRequire(resolve(__dirname,
  '../build/progression-rules/package.json'));
const { initializeTestEnvironment, assertSucceeds, assertFails } =
  localRequire('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, deleteDoc, writeBatch, Timestamp, setLogLevel } =
  localRequire('firebase/firestore');
setLogLevel('silent'); // Expected denied writes are asserted by the test runner.

const address = process.env.FIRESTORE_EMULATOR_HOST;
if (!address || !/^(127\.0\.0\.1|localhost):\d+$/.test(address)) {
  throw new Error('Set FIRESTORE_EMULATOR_HOST to a local emulator host:port.');
}
const [host, rawPort] = address.split(':');
let environment;
let owner;
let stranger;
const uid = 'progression-owner';
const now = Timestamp.fromMillis(1800000000000);

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-challengeland-progression',
    firestore: {
      host, port: Number(rawPort),
      rules: readFileSync(resolve(__dirname, '../firestore.rules'), 'utf8'),
    },
  });
  owner = environment.authenticatedContext(uid).firestore();
  stranger = environment.authenticatedContext('other-player').firestore();
});
after(async () => { if (environment) await environment.cleanup(); });

function profile() {
  return {
    uid, username: 'Progression test', photoUrl: null, friendCode: 'PROGRESS1',
    xp: 250, level: 2, trophies: 22, bestTrophies: 22,
    wins: 1, losses: 0, draws: 1, gamesPlayed: 2, totalMatches: 2,
    totalScore: 250, correctAnswers: 10, wrongAnswers: 2,
    progressionVersion: 2, lastSeenAt: now,
  };
}

const cumulativeKeys = [
  'xp', 'gamesPlayed', 'wins', 'losses', 'draws', 'abandoned',
  'correctAnswers', 'wrongAnswers', 'totalEarnings', 'onlineWins',
  'trophiesEarned', 'trophiesLost', 'blitzFinishes', 'eliminationWins',
  'survivalWins', 'seriesWins', 'teamBattleWins', 'localTeamsPlayed',
  'offlineBoardPlayed', 'offlineBoardWins', 'friendMatchesPlayed',
  'randomMatchesPlayed',
];
const modes = ['campaign', 'offline', 'local_teams', 'board', 'battle',
  'team_battle', 'blitz', 'elimination', 'survival', 'series'];
const modeKeys = modes.flatMap(mode =>
  ['games', 'wins', 'losses', 'draws', 'abandoned']
    .map(outcome => `mode_${mode}_${outcome}`));

function completePublication() {
  const stats = {
    ...Object.fromEntries([...cumulativeKeys, ...modeKeys].map(key => [key, 0])),
    xp: 500, gamesPlayed: 6, wins: 4, losses: 2, trophies: 92,
    bestTrophies: 100, trophiesLost: 8, correctAnswers: 20, wrongAnswers: 3,
    bestStreak: 10, bestWinStreak: 4, highestMoney: 1000,
    winStreak: 0, lastPrize: 0, level: 3, totalAnswered: 23,
    accuracy: 87, winPercent: 67, progressionVersion: 2,
    mode_battle_games: 6, mode_battle_wins: 4, mode_battle_losses: 2,
  };
  const contributions = {
    ...Object.fromEntries([...cumulativeKeys, ...modeKeys].map(key => [key, 0])),
    xp: 180, gamesPlayed: 1, losses: 1, trophies: -8, trophiesLost: 8,
    wrongAnswers: 3, mode_battle_games: 1, mode_battle_losses: 1,
  };
  const publicData = {
    ...Object.fromEntries(Object.entries(stats)
      .filter(([key]) => !key.startsWith('mode_'))),
    uid, username: 'Full progression player', photoUrl: null,
    friendCode: 'PROGRESS1', rating: 1000, createdAt: now, lastSeenAt: now,
    totalMatches: 6, totalScore: 500,
  };
  const privateData = {
    playerStats: stats, xp: 500, level: 3, trophies: 92, bestTrophies: 100,
    wins: 4, losses: 2, draws: 0, totalMatches: 6, totalScore: 500,
    progressionVersion: 2, progressionUpdatedAt: now,
  };
  return { privateData, publicData, checkpoint: {
    contributions, version: 2, updatedAt: now,
  } };
}

test('owner atomically publishes progression, identity and device checkpoint', async () => {
  const publicData = profile();
  const batch = writeBatch(owner);
  const stats = { xp: 250, level: 2, trophies: 22, bestTrophies: 22,
    wins: 1, losses: 0, draws: 1, gamesPlayed: 2, correctAnswers: 10,
    wrongAnswers: 2, totalEarnings: 0 };
  batch.set(doc(owner, `users/${uid}`), {
    ...stats, playerStats: stats, totalMatches: 2, totalScore: 250,
    progressionVersion: 2, progressionUpdatedAt: now,
  });
  batch.set(doc(owner, `public_profiles/${uid}`), publicData);
  batch.set(doc(owner, `users/${uid}/progressionDevices/device-1`), {
    contributions: { xp: 250, trophies: 22, gamesPlayed: 2, wins: 1,
      losses: 0, draws: 1 },
    version: 2, updatedAt: now,
  });
  await assertSucceeds(batch.commit());
  const publicSnapshot = await assertSucceeds(
    getDoc(doc(stranger, `public_profiles/${uid}`)));
  assert.equal(publicSnapshot.data().xp, 250);
});

test('other accounts cannot write a profile or read and alter its checkpoint', async () => {
  await assertFails(setDoc(doc(stranger, `public_profiles/${uid}`), profile()));
  await assertFails(getDoc(doc(stranger, `users/${uid}/progressionDevices/device-1`)));
  await assertFails(setDoc(doc(stranger, `users/${uid}/progressionDevices/device-1`), {
    contributions: { xp: 99999 }, version: 2, updatedAt: now,
  }));
});

test('private identity and unrecognized fields cannot leak into public profiles', async () => {
  await assertFails(setDoc(doc(owner, `public_profiles/${uid}`), {
    ...profile(), email: 'private@example.test',
  }));
  await assertFails(setDoc(doc(owner, `public_profiles/${uid}`), {
    ...profile(), arbitraryAdminFlag: true,
  }));
});

test('malformed progression totals cannot enter leaderboard queries', async () => {
  await assertFails(setDoc(doc(owner, `public_profiles/${uid}`), {
    ...profile(), trophies: -10,
  }));
  await assertFails(setDoc(doc(owner, `public_profiles/${uid}`), {
    ...profile(), xp: '250',
  }));
});

test('anonymous clients cannot publish or read player leaderboards', async () => {
  const anonymous = environment.unauthenticatedContext().firestore();
  await assertFails(setDoc(doc(anonymous, `public_profiles/${uid}`), profile()));
  await assertFails(getDoc(doc(anonymous, `public_profiles/${uid}`)));
});

test('account owner can remove installation checkpoints during account deletion', async () => {
  await assertSucceeds(deleteDoc(doc(owner,
    `users/${uid}/progressionDevices/device-1`)));
});

test('complete production publication and all 73 device counters fit the rule budget',
    async () => {
  const { privateData, publicData, checkpoint } = completePublication();
  assert.equal(Object.keys(checkpoint.contributions).length, 73);
  assert.equal(Object.keys(privateData.playerStats)
    .filter(key => key.startsWith('mode_')).length, 50);
  const batch = writeBatch(owner);
  batch.set(doc(owner, `users/${uid}`), privateData, { merge: true });
  batch.set(doc(owner, `public_profiles/${uid}`), publicData, { merge: true });
  batch.set(doc(owner, `users/${uid}/progressionDevices/full`), checkpoint);
  await assertSucceeds(batch.commit());
  const stored = (await getDoc(doc(owner,
    `users/${uid}/progressionDevices/full`))).data();
  assert.equal(stored.contributions.trophies, -8);
  const publicSnapshot = await getDoc(doc(stranger, `public_profiles/${uid}`));
  assert.equal(publicSnapshot.data().xp, 500);
  assert.equal(publicSnapshot.data().trophies, 92);
  assert.equal(publicSnapshot.data().trophiesLost, 8);
});

test('mode checkpoint validation rejects negative, float and nonnumeric counters',
    async () => {
  for (const invalid of [-1, 0.5, '1', null]) {
    const { checkpoint } = completePublication();
    checkpoint.contributions.mode_campaign_games = invalid;
    await assertFails(setDoc(doc(owner,
      `users/${uid}/progressionDevices/invalid`), checkpoint));
  }
  // Two floats sum to an integer value, but their numeric type remains float.
  const { checkpoint } = completePublication();
  checkpoint.contributions.mode_campaign_games = 0.5;
  checkpoint.contributions.mode_campaign_wins = 0.5;
  await assertFails(setDoc(doc(owner,
    `users/${uid}/progressionDevices/invalid`), checkpoint));
});

test('signed trophy checkpoints accept losses and reject invalid trophy types',
    async () => {
  for (const invalid of ['-8', -0.5, -2147483648, 2147483648]) {
    const { checkpoint } = completePublication();
    checkpoint.contributions.trophies = invalid;
    await assertFails(setDoc(doc(owner,
      `users/${uid}/progressionDevices/invalid-trophies`), checkpoint));
  }
});

test('all published progression totals enforce integer types and native bounds',
    async () => {
  const { publicData } = completePublication();
  for (const key of [...cumulativeKeys, 'bestStreak', 'bestWinStreak',
      'highestMoney', 'bestTrophies', 'trophies', 'winStreak', 'lastPrize',
      'level', 'totalAnswered', 'accuracy', 'winPercent', 'progressionVersion',
      'totalMatches', 'totalScore', 'rating']) {
    await assertFails(setDoc(doc(owner, `public_profiles/${uid}`),
      { ...publicData, [key]: -1 }));
    await assertFails(setDoc(doc(owner, `public_profiles/${uid}`),
      { ...publicData, [key]: 0.5 }));
    await assertFails(setDoc(doc(owner, `public_profiles/${uid}`),
      { ...publicData, [key]: 2147483648 }));
  }
});
