These JVM regression checks use the campaign board rules and the compiled Android
`PlayerProgress` currency store. The small `android.content` stand-ins are used
only by this verification directory and are excluded from the APK.

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
