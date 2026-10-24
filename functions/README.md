# ChallengeLand purchase backend

This code verifies Google Play purchases against the Developer API and persists grants in Firestore transactions. It does not deploy itself, create Play products, charge customers, or issue refunds. Deploy and complete the Play Console configuration before releasing the updated store.

## Product contract

Prices and available subscription offers come from Play `ProductDetails`. The server only defines the delivered content. Existing SKU quantities are preserved.

| Product ID | Delivery | Settlement |
| --- | --- | --- |
| `gems_80`, `gems_500`, `gems_1200` | 80, 500, 1,200 gems respectively | Consume after delivery snapshot |
| `gems_2500`, `gems_6500`, `gems_14000` | Existing legacy quantities, supported for recovery | Consume after delivery snapshot |
| `coins_5000`, `coins_25000`, `coins_100000` | 5,000, 25,000, 100,000 coins respectively | Consume after delivery snapshot |
| `pack_starter` | 10,000 coins + 100 gems, once per game account | Acknowledge; retain ownership |
| `pack_value` | 35,000 coins + 600 gems | Consume after delivery snapshot |
| `pack_champion` | 100,000 coins + 1,800 gems | Consume after delivery snapshot |
| `vip_monthly` | VIP and ad-free access until the verified subscription expiry; no currency bonus | Acknowledge |
| `category_all_access` | Permanent premium category access; no VIP membership | Acknowledge |
| `noads` | Legacy permanent ad-free access; no VIP membership | Acknowledge |

Underscore-less aliases such as `gems80`, `packstarter`, and `vipmonthly` are explicitly mapped to their canonical products. The actual Play SKU is still verified using the exact ID requested; an alias never makes an unrelated purchase valid. Enable `vip_pass`, `vippass`, or `vip` in `COMMERCE_LEGACY_VIP_IDS` only if that exact ID is a real subscription in your Play Console. A historical one-time VIP product must be migrated explicitly rather than interpreted as a subscription. Do not enable multiple-quantity purchase options for this catalog.

The starter product is a Play one-time product that the updated client does not consume. If an older client consumed it, the account-wide purchase flag blocks another delivery after migration. Retire old app releases that can still sell/consume starter bundles before relying on the new purchase limit.

## Callable API

Both functions run in `us-central1`. Firebase verifies the caller's Firebase ID token. A signed-in, non-anonymous game account is required; a UID supplied in the request body is ignored.

`verifyPlayPurchase` accepts:

```json
{
  "productId": "gems_80",
  "purchaseToken": "GOOGLE_PLAY_TOKEN",
  "packageName": "com.qi7bali.landchallengeonline"
}
```

`packageName` is optional but must match the configured app when provided. Native HTTP calls use the [Firebase callable protocol](https://firebase.google.com/docs/functions/callable-reference): `POST`, `Authorization: Bearer FIREBASE_ID_TOKEN`, `Content-Type: application/json`, and wrap this payload in `{"data": {...}}`. Unwrap `result` from the callable response.

A delivered result contains:

```json
{
  "verified": true,
  "status": "delivered",
  "deliveryId": "SHA256_PURCHASE_TOKEN",
  "grant": { "coins": 0, "gems": 80 },
  "entitlement": {
    "isVip": false,
    "expiresAtMillis": 0,
    "allCategories": false,
    "removeAds": false
  },
  "starterPurchased": false
}
```

`status` can also be `pending` or `revoked`; both return a zero grant. Pending payments never unlock paid content. Repeated delivered requests return the original grant and the same delivery ID. The client must apply each `uid:deliveryId` exactly once.

`restoreCommercePurchases` accepts an empty object. It re-verifies owned subscriptions and permanent category/ad-free purchases, then returns `status: "restored"`, current entitlements, `starterPurchased`, and a zero grant. Consumed, potentially spent currency purchases are never replayed by this endpoint. Device recovery queries outstanding purchases through Play and re-verifies those tokens individually.

`allCategories` means permanent category ownership. `removeAds` means permanent ownership of the legacy `noads` product. Category access checks use `isVip || allCategories`; ad access checks use `isVip || removeAds`. Check the VIP expiry against current time when reading stored entitlement snapshots. The persisted `isVip` cache can predate a natural expiry until RTDN or the daily job refreshes it.

## Account binding and legacy migration

Before launching billing, Android sets `setObfuscatedAccountId` to the lowercase hexadecimal SHA-256 hash of the authenticated Firebase UID. The server compares that value with Google's verified `obfuscatedExternalAccountId`. Tokens are globally owner-locked in the same transaction as delivery; replays into a different game account fail. Linked subscription replacement tokens cannot transfer an existing subscription to another account.

Previous app releases did not bind purchases to Firebase accounts. Missing binding fails with `failed-precondition`; a token alone does not prove which game account originally owned it. An administrator can review ownership and seed `commerce_purchase_tokens/{sha256(token)}` with `uid`, canonical `productId`, exact `storeId`, `type`, `token`, and `allowLegacyBinding: true`. Keep this an audited administrative process. A migrated paid entitlement needs its server entitlement record as well; restore only reads already registered durable entitlement sources. Do not enable a global bypass or accept client-written VIP flags. Consumed legacy tokens without an existing delivered ledger entry are denied a new currency grant.

## Firestore authority and wallet synchronization

- `commerce_accounts/{uid}` records the starter purchase flag and cumulative verified grant totals.
- `commerce_accounts/{uid}/transactions/{deliveryId}` records token-hash delivery IDs, product IDs, granted quantities, order IDs, and delivery/refund status. Owners may read their own records but cannot write them.
- `commerce_accounts/{uid}/entitlements/current` is the paid entitlement authority. Client-created fields under `users/{uid}` or local old VIP flags are not payment evidence.
- `commerce_purchase_tokens/{deliveryId}` is a private token vault. All client reads and writes are denied. Never export its raw tokens to logs, analytics, support URLs, or client snapshots. Restrict administrator access and apply your retention policy.

The existing game wallet still earns and spends currency locally. The purchase backend makes each paid grant authoritative, but `grantedCoins` and `grantedGems` are cumulative issuance totals, **not spendable wallet balances**.

Delivery order is: verify the receipt → transactionally save the server grant → atomically save native wallet credit and applied delivery ID → atomically save wallet balances with `appliedCommerceDeliveryIds` in the user snapshot → call native `confirmCommerceSnapshot` → consume or acknowledge through Play. Hydrate those receipt IDs with the cloud wallet before purchase recovery on another device. The backend deliberately does not acknowledge or consume purchases ahead of this snapshot.

The native pending settlement journal retries interrupted confirmations. Keep the UI in a recoverable processing state during synchronization failures. Google requires completed purchases to be acknowledged within its acknowledgment window, so test the save-and-confirm flow and monitor unacknowledged purchases. See the [Play integration guide](https://developer.android.com/google/play/billing/integrate).

This snapshot design avoids routine receipt replay after reinstall. Simultaneously spending or purchasing on multiple devices still shares the legacy wallet's last-write behavior. A fully authoritative cross-device economy requires moving earned rewards, spending, and balances to server transactions. Refund RTDN revokes subscription/category/ad-free rights; refunds of currency-bearing purchases mark `walletReviewRequired` for reconciliation because the server cannot automatically claw back an already spent local balance.

## Deployment configuration

1. Use Node.js 22 and `npm ci` inside `functions`. Run `npm test` and `npm run check`. The lockfile includes a targeted patched `uuid` override for the legacy `gaxios` dependency used by Firebase Admin's storage package.
2. Enable Firebase billing for Functions v2 and the Google Play Android Developer API in the Cloud project. Complete [Developer API access](https://developers.google.com/android-publisher/getting_started).
3. Identify the actual deployed Functions runtime service account in Google Cloud. Grant it Firestore access and add that account to Play Console with access to **this app** and the billing purchase/financial permissions needed to read purchases and subscriptions. Application Default Credentials are used; do not embed service account keys in the Android app or repository.
4. Copy `.env.example` to `.env.challengeland` and verify `PLAY_PACKAGE_NAME`, `PLAY_RTDN_TOPIC`, and optional subscription aliases. Keep `COMMERCE_ENFORCE_APP_CHECK=false` until the native caller supplies a valid App Check token, then enable it after testing.
5. Create `play-billing-rtdn` in the same Cloud project. Grant `roles/pubsub.publisher` on that topic to `google-play-developer-notifications@system.gserviceaccount.com`. Do not grant publish rights to app users or public principals. The `playBillingNotifications` Eventarc/Pub/Sub trigger is authenticated and has no public webhook. See [Google's RTDN setup](https://developer.android.com/google/play/billing/getting-ready).
6. In Play Console, configure RTDN to `projects/challengeland/topics/play-billing-rtdn`, enable subscription, one-time, and voided purchase events, and send a test notification.
7. Create/activate the products and the VIP monthly base plan in Play Console. Use localized prices and real offer eligibility from Play; the server has no fallback retail prices.
8. Deploy from the project root with `firebase deploy --only functions:commerce,firestore:rules`. This command is an operator step and was not run as part of this change. Ensure the codebase name matches `firebase.json` and that the native client targets the same project and region.

RTDN always re-queries Play; the notification is a trigger rather than proof of successful payment. Unknown unregistered tokens are not assigned to an arbitrary UID. Delayed authenticated verification recovers them. Transient verifier failures are retried without logging token-bearing errors. The daily `refreshPlaySubscriptions` job pages through registered subscriptions, repairs missed events, and skips tokens that have passed Play's historical lookup window. Monitor refresh failures and move the reconciliation scan to a task queue before its workload approaches the function timeout.

## Release verification

### Friend challenges on coins

`friendStakes` (us-central1) supports `invite`, `respond`, `start`, `claim`,
`answer`, `sync`, and `forfeit`. Mutations require a payload-bound `operationId`.
Invites accept `peerUid` and `stakeCoins` (50, 100, 250, 500, 1000, 2500, 5000).
Acceptance uses `challengeId`, `status: "accepted"`, and `expectedAmount` matching
the displayed contribution. Decline/cancel use `declined`/`cancelled`.

Acceptance atomically debits both `users/{uid}.coins`, writes an independent
`friend_stake_escrows/{matchId}` financial receipt and private
`friend_stake_matches/{matchId}`, reserves both players, and publishes a read-only
`friend_stake_views/{matchId}` for those participants. The private collections and
operation receipts have no client access. Paid games never read scores or winner
claims from the existing client-authored RTDB games and never consume a key.

Both participants must call `start` within two minutes. The server picks two free
text categories, selects six questions and shuffles options privately. `claim`
accepts `matchId`, `turn`, `col`, `row`; only that turn's player receives its
`question: {id,text,options}`. `answer` accepts `optionIndex` (0–3, or -1 for a
missed answer); correctness and 200/400/600 row points are computed by the server.
The first release uses multiple choice at full row points. No question answer key
is published in the match view, though the question source is the existing app's
bank, so this does not claim to defeat external question lookup or collusion.
Rebuild the bundled free question subset after bank changes with
`npm run questions:stakes` (currently 2,954 questions).

`forfeit` refunds before both players start and awards the entire pot to the
opponent after start. Six completed turns determine the winner from server
scores; a tie refunds both contributions. Selection has a 45-second server
deadline and answering 30 seconds; a missed deadline scores zero and advances
the turn. `sync` repairs deadlines; `recoverFriendStakes` runs every minute to
recover abandoned ready sessions, overdue turns and the 15-minute hard expiry.
Hard expiry or corrupt private gameplay state refunds from the independent
escrow receipt. Client reports cannot request a system-error refund. Settlement
and both account credits commit in the same transaction and cannot replay.

Every hold and settlement increments `users.friendStakeRevision`; an active hold
sets `friendStakeMatchId`, and settlement clears it. Clients cannot edit these
markers, delete an account with a hold, or overwrite coins during a hold. Wallet
snapshot writers must hydrate a newer revision before writing a stale balance.
The broader legacy wallet still permits client-authored coin changes outside a
hold. This change protects match settlement and concurrent wallet snapshots; it
does **not** make all existing earned/spent coins server-authoritative. Complete
that separate economy migration before treating these stakes as a secure
real-money or redeemable-value system.

The callable, recovery schedule, and Firestore rules were deployed together to
`challengeland` on 2026-10-19 at 18:47 UTC with explicit user approval. Both
functions report `ACTIVE`, the authenticated recovery job is `ENABLED` every
minute, and an unauthenticated callable probe returns 401 `UNAUTHENTICATED`
instead of the prior 404. Live rules match the local file (SHA256
`a544af3b8714e790fe774bd2df745d55c02a010087af3890ef21aff09067145d`).
The first automatic recovery execution completed successfully at 18:48:02 UTC
with `recovered: 0`, confirming the deployed scheduler and runtime access.
Release testing on two real accounts should still cover disconnects, process
termination, simultaneous acceptance, ties and retries.
`node --test --test-isolation=none test/*.test.js` runs the suite in sandboxes that
prohibit the test runner's child-process spawning.

### Social notifications

`notifyFriendRequest` and `notifySocialInvite` observe committed pending requests in
`social_links` and `social_challenges`. They reuse registered notification devices,
check the current request and both block directions, and deduplicate each request
generation. The Android notification opens the requests tab; acceptance remains
explicit. The global Flutter shell also shows friend requests while the app is open.

Deploy the two new triggers from the repository root with
`firebase deploy --only functions:commerce:notifyFriendRequest,functions:commerce:notifySocialInvite`.
This deployment has not been run locally. Existing `registerDuelDevice` must already
be deployed, and the recipient must enable system notifications. Verify receipt
on two accounts with the app open, backgrounded and closed before release.

Automated isolated tests cover catalog amounts, aliases, account binding and migration, idempotency, concurrent starter purchases, pending payments, expired/canceled/paused/on-hold subscriptions, entitlement-only restore, ownership of replacement subscriptions, refunds, and sanitized API errors. They do not contact a real Play account or prove deployment IAM.

Use license testers and the internal Play testing track to verify:

1. Localized price and subscription offer display, purchase cancellation, and declined payment.
2. Pending payment followed by successful payment; no reward while pending.
3. Network failure after server verification, after local credit, and after cloud save; one credit after recovery.
4. Reinstall and second-device login after the wallet snapshot; starter/currency grants must not duplicate.
5. VIP renewal, user cancellation before expiry, grace period, hold, pause, expiry, and refund. Membership must end correctly while permanent category/ad-free rights remain independent.
6. Restore under a different Firebase account; reject taking another account's receipt.
7. The Play RTDN test event and actual refund events; verify entitled rights disappear and currency refunds receive a reconciliation flag.
8. Legacy account migration with and without approved token ownership. Confirm no automatic lifetime VIP migration.
