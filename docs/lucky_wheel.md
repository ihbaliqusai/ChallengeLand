# Lucky wheel

Each signed-in player receives one free spin per server UTC day, renewed at
00:00 UTC. `gameEconomy` always uses that free opportunity before deducting one
purchased spin from `economy_accounts/{uid}.wheelSpins`. Purchased spins do not
expire or reset at midnight. An existing daily-reward claim consumes the same
free opportunity; paid spins do not advance or reset the daily streak.

The server selects the prize and saves its grant, spin debit, and receipt in one
transaction before the client animates the wheel. The six prize types have equal
probability, represented by two sectors each. Every new spin requires a new
`operationId`; replaying the same account-bound ID returns the original prize
without another debit or grant. A replay returns current wallet totals, including
whether the current day's free spin is still available.

## Google Play setup

Create and activate the one-time consumable product `wheel_spins_3` for package
`com.qi7bali.landchallengeonline`. One verified purchase delivers exactly three
banked spins. Configure the real regional prices and availability in Play
Console; the app displays the live Play price and has no fixed or fallback cash
price. Keep multiple-quantity checkout disabled for this catalog.

The native billing catalog and server product catalog recognize this SKU.
Pending, canceled, revoked, and unverified payments do not grant spins. Verified
delivery credits the server wallet once, then the server consumes the Play
purchase so the pack can be bought again. Reverification of the same token never
restores already-spent spins. Interrupted consumption is repaired by the existing
settlement journal, RTDN processing, and scheduled reconciliation.

## Recovery and deployment

The client persists an account-scoped pending operation ID under
`lucky_wheel_operation_<uid>` before requesting a spin. Network failures retain
that ID so reopening the app retries the same receipt. The ID is removed after
delivery is applied. A definitive server rejection that committed no spin clears
the pending request and refreshes availability; uncertain transport failures must
remain retryable with the original ID. Purchase completion refreshes the server
spin balance rather than granting spins optimistically in the UI.

Release the Android client together with the updated Functions in codebase
`commerce`, region `us-central1`:

- `gameEconomy`: free-spin gate, purchased-spin debit, random grant and receipt.
- `verifyPlayPurchase`: verified `wheel_spins_3` delivery and settlement.
- `restoreCommercePurchases`: keeps the shared commerce runtime consistent;
  outstanding Play purchases are separately reverified by the native recovery flow.
- `playBillingNotifications`: pending purchase completion and refund notifications.
- `refreshPlaySubscriptions`: also repairs pending server resource settlements.

From the repository root, the operator deployment command is:

```powershell
firebase deploy --only functions:commerce:gameEconomy,functions:commerce:verifyPlayPurchase,functions:commerce:restoreCommercePurchases,functions:commerce:playBillingNotifications,functions:commerce:refreshPlaySubscriptions
```

No new Firestore index or rule is required for the spin balance; the existing
server-owned economy and commerce collections remain authoritative. See
[`functions/README.md`](../functions/README.md) for Play API access, service
account permissions, RTDN configuration, and test-account setup. Product creation,
price configuration, and deployment were not performed by this implementation.

Backend regression checks:

```powershell
cd functions
node --test test/lucky_wheel.test.js test/commerce.test.js test/economy.test.js
```

Before release, use a Play license tester to verify a free spin, a three-spin
purchase, three separate additional prizes, purchase cancellation, pending
payment completion, process death during delivery, and UTC midnight rollover.
