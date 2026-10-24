These JVM regression checks compile the production campaign rules and Android
progression classes directly from source, using the compiled commerce companion
from an Android build. The small `android.*` stand-ins are used
only by this verification directory and are excluded from the APK.

The native scene checks exercise the real `GameActivity`, video surface, safe
insets and presenter bubble on Android. They assert that all background layers
share the full window, the callout touches the presenter's head without covering
navigation or the question, Home stays beside sound at the top right,
the stage HUD stays in its own safe rail,
confirmation buttons fit, and modal shading covers
the cutout gutters with the same opacity as the center. Screenshots are saved
for phone, wide phone and tablet sizes with left, right and absent cutouts,
for both the solo stage board and the classic campaign (18 scene configurations).
The script accepts emulator serials only and restores display settings afterward:

```powershell
Push-Location android
.\gradlew.bat :app:assembleDebug :app:assembleDebugAndroidTest --console=plain
Pop-Location
.\android\verification\check_game_scene.ps1 -Serial emulator-5560
```

From the repository root in PowerShell:

```powershell
Push-Location android
.\gradlew.bat :app:assembleDebug --console=plain
Pop-Location
.\android\verification\run_checks.ps1
```

The checks cover attainable score ceilings for solo and boss boards, question
budgets, player-only answer statistics, star boundaries, campaign difficulty
filtering, relative difficulty at each cell value, boss option penalties, and
idempotent currency claims. Currency checks also exercise a failed preference
commit, a successful retry, and simultaneous requests for the same claim.
Category access checks cover automatic themed/random picks, expired ownership,
resume validation, insufficient unlocked categories, and anime purchase aliases.
Stage challenge checks cover error limits, the deadline boundary (including an
expired saved deadline), distinct themed-category goals and legacy unconstrained
stages. Boss checks cover specialty choices, accuracy bonuses and weaknesses,
high-value choices, exhausted-category fallback and accuracy bounds.

Progression checks cover all ten game modes, XP and rank boundaries, local team
completion trophies, human opponent bonuses, ties, abandoning, empty lobbies,
answer/result retries, result-screen recreation, concurrent callbacks, account
switches, one-owner legacy migration, and failed disk commits. Cloud checks verify
the initial legacy baseline, pending rewards during a round trip, signed trophy
losses, hydration replay, and atomic hydration/checkpoint rollback. These checks
recompile the current progression sources on each run; the Android build also
validates the real activity integration.

Campaign pending results are tested for account isolation, legacy ownership,
consume retries, and failed writes. The script downloads the pinned JSON Java
20240303 test dependency from Maven Central on first use and verifies its SHA256;
subsequent runs reuse the local temporary-directory cache.

Installation checks use real temporary no-backup directories and copied
preferences to simulate restart, backup restore, and device transfer. Each
installation persists an atomic UUID outside Android backup; account checkpoints
retain their device stream only when their stored installation marker matches.
Unbound older checkpoints rotate once because their origin cannot be proven.
The tests verify preserved account totals, zero contributions for restored
baselines, independent gameplay on both devices, stable streams across account
switches, and deferred synchronization when the identity file is unreadable or
corrupt. UUIDs are never regenerated silently after an identity read failure.
