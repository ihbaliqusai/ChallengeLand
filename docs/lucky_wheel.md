# Lucky wheel

Each signed-in player receives one free spin per server UTC day, renewed at
00:00 UTC. `gameEconomy` always uses that free opportunity before deducting one
purchased spin from `economy_accounts/{uid}.wheelSpins`. Purchased spins do not
expire or reset at midnight. An existing daily-reward claim consumes the same
free opportunity; paid spins do not advance or reset the daily streak.

## Prizes and probabilities

Version 2 has twelve different outcomes, each selected with the exact probability
**1/12** (approximately **8.33%**). These odds apply equally to free and purchased
spins. Percentages below are rounded; the exact fractions sum to 100%.

| Outcome | Guaranteed grant | Chance |
| --- | --- | --- |
| One key | 1 key | 1/12 ≈ 8.33% |
| Two keys | 2 keys | 1/12 ≈ 8.33% |
| One ticket | 1 ticket | 1/12 ≈ 8.33% |
| Two tickets | 2 tickets | 1/12 ≈ 8.33% |
| Small coin prize | 250 coins | 1/12 ≈ 8.33% |
| Coin prize | 500 coins | 1/12 ≈ 8.33% |
| Large coin prize | 1,000 coins | 1/12 ≈ 8.33% |
| Small gem prize | 5 gems | 1/12 ≈ 8.33% |
| Gem prize | 10 gems | 1/12 ≈ 8.33% |
| Large gem prize | 20 gems | 1/12 ≈ 8.33% |
| Character | The displayed unowned character, permanently unlocked | 1/12 ≈ 8.33% |
| Lucky chest | 1,000 coins **and** 20 gems **and** 2 keys **and** 2 tickets | 1/12 ≈ 8.33% |

Grouped by prize type, coins have a 25% chance, gems 25%, keys 1/6 ≈ 16.67%,
tickets 1/6 ≈ 16.67%, character 1/12 ≈ 8.33%, and lucky chest 1/12 ≈ 8.33%.
The chest grants its complete bundle together; it does not contain another
random draw. When the character roster is complete, the character row becomes a
100-gem prize with the same 1/12 chance. Direct gem outcomes then total 1/3
(approximately 33.33%), excluding the separate chest bundle.

The character slot targets the first unowned purchasable character in this
catalog order: indices `2, 4, 7, 9, 11, 12, 14, 15` (Fahad, Mahmoud, Talia,
Rashid, Yazan, Renad, Salman, Adam). Owned characters are skipped. After winning
one, the slot changes to the next eligible character. If all eight are owned,
the same 1/12 outcome grants **100 gems** instead. It never grants a duplicate
character. The server returns the next preview as `state.wheelCharacterIndex`;
`null` means the gem compensation applies. A result is displayed with the actual
server-awarded character even if another device changed ownership after the
preview was shown.

The server selects the prize and saves its grant, spin debit, and receipt in one
transaction before the client animates the wheel. Every new spin requires a new
`operationId`; replaying the same account-bound ID returns the original prize
without another debit or grant. A replay returns current wallet totals, including
whether the current day's free spin is still available.

### Existing clients and pending receipts

New clients send `wheelCatalogVersion: 2`. Requests without that flag retain the
version-1 six-outcome distribution, with a 1/6 chance for each of: one key, one
ticket, 500 coins, 10 gems, a random unowned purchasable character, or the same
lucky chest. Version-1 character rewards retain their random selection among
unowned characters. This compatibility keeps installed clients working while
the updated Android app is distributed.

Catalog version is excluded only from the `spinWheel` receipt signature. A
pending version-1 operation can therefore be recovered after an app update;
changing the version cannot reroll a saved result, spend another spin, or alter
its original grants. Action, account, and other request fields remain bound to
the operation. Original prize IDs and indices 0–5 remain stable in the new client
so legacy results can still be displayed.

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
delivery is applied. A definitive `FAILED_PRECONDITION` no-credit rejection clears
the pending request and refreshes availability; uncertain transport or auth
failures must remain retryable with the original ID. Purchase completion refreshes
the server spin balance rather than granting spins optimistically in the UI.

The original wheel and paid-spin backend was deployed and verified on
25 October 2026. Its authenticated live smoke test confirmed a free grant,
idempotent replay, and rejection of an extra free request; the isolated test
account and documents were removed. Product creation and price configuration
were not performed by this implementation.

The version-2 prize and character update was deployed to `gameEconomy` on
26 October 2026, in codebase `commerce`, region `us-central1`. Its authenticated
live smoke test verified all twelve disclosed grants and exact 1/12 probabilities,
the initial unowned character preview, a real version-2 free grant, safe receipt
replay, and the daily limit. The synthetic Auth account and its user, economy, and
operation documents were deleted; document absence was verified. No real player
account or cash purchase was used. The deployed source was independently
downloaded and matched the isolated stage exactly, including the preserved
production referral support and other source files.

Install the updated Android client to use the twelve-outcome display and request
version 2. Existing commerce endpoints already handle `wheel_spins_3` and did not
need a catalog change for this prize update.

An isolated deployment source is prepared under
`build/wheel-variety-deploy-20261026` from the current production source downloaded
on 26 October 2026. Only `functions/src/economy.js` changes; existing production
referral support, question data, index exports, package versions, and environment
configuration are preserved. Unpublished workspace changes outside the wheel are
excluded. From that directory:

```powershell
$env:FUNCTIONS_DISCOVERY_TIMEOUT='60'
$env:FIREBASE_FUNCTIONS_DISCOVERY_OUTPUT_PATH='true'
firebase deploy --project challengeland --only functions:commerce:gameEconomy --non-interactive
```

The five wheel-related endpoints for a complete initial setup are:

- `gameEconomy`: free-spin gate, purchased-spin debit, random grant and receipt.
- `verifyPlayPurchase`: verified `wheel_spins_3` delivery and settlement.
- `restoreCommercePurchases`: keeps the shared commerce runtime consistent;
  outstanding Play purchases are separately reverified by native recovery.
- `playBillingNotifications`: pending purchase completion and refund notifications.
- `refreshPlaySubscriptions`: also repairs pending server resource settlements.

No new Firestore index or rule is required for the spin balance; the existing
server-owned economy and commerce collections remain authoritative. See
[`functions/README.md`](../functions/README.md) for Play API access, service
account permissions, RTDN configuration, and test-account setup.

Backend regression checks:

```powershell
cd functions
node --test test/lucky_wheel.test.js test/commerce.test.js test/economy.test.js
```

Before release, verify all twelve outcomes, their equal exact probabilities,
character-preview advancement, full-roster compensation, recovery of a legacy
pending operation, free-first spending, purchase cancellation, pending payment
completion, process death during delivery, and UTC midnight rollover. Actual cash
purchases should be checked with a Play license tester.
