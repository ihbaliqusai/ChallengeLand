# Friend referral rewards

The `referrals` callable in `us-central1` creates a personal, opaque `CL-` code
and atomically credits both players after an eligible new player explicitly
accepts it. All amounts are in-game currency, not withdrawable cash.

| Reward | Coins | Gems |
| --- | ---: | ---: |
| Inviter, for every qualified new friend | 1,000 | 10 |
| New player accepting a friend's code | 500 | 5 |
| Inviter, once at 3 qualified friends | 1,000 | 10 |
| Inviter, once at 5 qualified friends | 2,500 | 25 |
| Inviter, once at 10 qualified friends | 5,000 | 50 |

Milestone grants are automatic and additional to the per-friend reward. There
is no claim button and no Facebook requirement.

The home friends shortcut opens the new invitation screen. Its magenta play
button opens the existing friends and players screen. An incoming Play install
referrer (`cl_referral`) or `challengeland://invite?code=CL-...` link prefills
acceptance after sign-in. The friend still explicitly confirms acceptance.
Manual code entry also works when installation attribution is unavailable.

## Callable contract

The caller must have a non-anonymous Firebase account. `state` accepts
`{action: "state", expectedUid, installId}`. `accept` additionally requires
`code`. Android supplies the native device identifier and checks the active
account; amounts, eligibility timestamps and milestone targets never come from
the caller.

Both actions return:

```json
{
  "state": {
    "code": "CL-A1B2C3D4E5F6",
    "qualifiedCount": 0,
    "totalCoins": 0,
    "totalGems": 0,
    "acceptedCode": null,
    "canAccept": true,
    "inviterReward": {"coins": 1000, "gems": 10},
    "inviteeReward": {"coins": 500, "gems": 5},
    "milestones": [{"count": 3, "coins": 1000, "gems": 10, "claimed": false}],
    "recent": []
  },
  "currency": {"coins": 100, "gems": 2},
  "referralRevision": 0,
  "newlyAccepted": false,
  "grants": {"coins": 0, "gems": 0}
}
```

The example abbreviates the three milestone entries. `totalCoins` and
`totalGems` count actual referral currency credited, including the player's own
welcome gift. `recent` retains the last ten qualified friends' game names and
acceptance times in milliseconds. `grants` reports the current caller's welcome
gift only when newly delivered. Replays return zero grants and the current
wallet, so replaying cannot restore already spent currency.

## Eligibility and synchronization

Acceptance is limited to seven days after the Firebase Auth account creation
time. Existing players can still invite friends. One account can accept only
one inviter; a code cannot refer its owner. Device identifiers are hashed again
on the server. The first account seen on a device reserves it; another account
on that device cannot qualify for an acceptance reward. The acceptance tombstone
and device record survive deleting the client-writable game profile.

Acceptance, the two wallet credits, device usage and milestone issuance share
one Firestore transaction. Both recipients' server-owned `referralRevision`
increments. Flutter compares that marker inside its wallet snapshot transaction
alongside `friendStakeRevision`, and hydrates both coins and gems when it sees a
new revision. Firestore rules forbid clients from creating a nonzero revision,
changing it or accessing referral code mappings, device records and acceptance
receipts. Owners may read their own referral summary only.

The legacy game still has client-authored currency earn/spend paths. This
referral implementation protects ordinary retries and stale snapshots; it does
not make the entire legacy economy server-authoritative. A native hash and Play
Install Referrer establish attribution and ordinary device deduplication, not
remote attestation, proof of a unique human or complete protection against
modified clients, emulators or device resets. Install Referrer alone cannot
prove to the backend that Google Play installed the game. A stronger abuse
system can add server-verified Play Integrity, gameplay qualification and risk
limits later.

## Activation and verification

The missing backend that caused the invitation screen to display `NOT_FOUND`
was activated on 26 October 2026. `referrals` and the referral-revision update to
`gameEconomy` were deployed with the referral Firestore rules. Both callables
report `ACTIVE`; verification at 04:35 UTC (07:35 Europe/Istanbul) confirmed the
referral URL returns HTTP 401 `UNAUTHENTICATED` without a token, replacing the
previous missing-service response.

Deployment used `build/referral_activation_20261026`, based on the freshly
downloaded live source, with only the referral export, wallet revision fields,
and referral rules added. This preserved the newer wheel and commerce changes
already running in production. Unrelated endpoints were not redeployed. The
live rules match the tested stage (SHA-256
`9186eb5b550047ddf4b5d34a141c46a6b0475281f46f1cfae6760fd9d557d73f`).
Deployment and verification evidence is saved in that build directory.

For a later release, review any other local changes before deploying the
following targets together. `gameEconomy` returns the referral revision so
Android can reject stale currency responses:

```powershell
firebase deploy --only functions:commerce:referrals,functions:commerce:gameEconomy,firestore:rules
```

The canonical privacy content and its Flutter, native and hosted copies include
the referral/device-deduplication description. Publish the updated hosted policy
with the app release. No hosting deployment was run by this change.

Publish the Android build through a Google Play testing track and verify a real
share → install → open → sign in → accept flow on two separate devices. Verify
the old account receives 1,000 coins and 10 gems after refreshing, the new
account receives 500 coins and 5 gems, and a repeated acceptance credits neither
again. Also check manual code entry and milestones at 3, 5 and 10 friends.

Local service tests run with `node --test test/referrals.test.js` from
`functions`. They cover concurrent retries, both wallet credits, automatic
milestones, self/unknown codes, server account age, device/account reuse,
payload tampering, code collisions and integer limits. They do not contact
production or establish deployment IAM. Activation verification passed 12
backend tests, 3 rules emulator tests, and 25 Flutter service, screen and actual
GameViewport layout tests. Layout coverage includes the reported 1600×826
screen, smaller landscape screens, safe insets, and the on-screen keyboard.
The real two-device Google Play install-and-accept flow still needs device
verification; the live endpoint probe does not credit any real player's wallet.
