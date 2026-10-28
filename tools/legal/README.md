# Shipped library and font notices

`assets/fonts/Baloo-OFL.txt` is the complete upstream Baloo SIL OFL 1.1,
including **Copyright (c) 2015 Ek Type**. It matches the existing font's
copyright generation; the font itself is not changed. Source:
https://raw.githubusercontent.com/EkType/Baloo/master/OFL.txt
SHA-256: `2c61ddde545d42bd30343d146c77b0006a72aba068256d7a15013ffb5c8bfc28`.

The generated Flutter manifest is `assets/licenses/third_party_notices.json`:

```json
{"entries": [{"packages": ["group:artifact:version"], "text": "complete notice", "source": "https://..."}]}
```

The native offline page is
`android/app/src/main/assets/licenses/index.html`. It uses the same full texts,
plus the complete Baloo, Noto Sans Arabic and Barlow Condensed OFL notices.
Flutter registers the three font files separately and combines this manifest
with Flutter's generated license registry. No network access is needed to read
the legal texts.

## Scope and evidence

The inventory resolves `:app:releaseRuntimeClasspath` from the current Gradle
project. On 28 October 2026 it contained **204 selected Maven components** and
**192 cached runtime AAR/JAR artifacts**. The component count includes BOM and
multiplatform metadata nodes; it is not a claim that 204 separate executable
libraries are shipped after resource/code shrinking.

`sources/native-components.json` records each exact version and the licenses
declared by its POM, following parent POMs where necessary. The downloaded
POMs and their hashes are retained in `sources/native-poms.json`. Sources are
Google Maven, Maven Central, JitPack and Flutter's artifact repository.

`sources/native-license-coverage.json` maps every selected component to its
full-text notice hash and source. `sources/upstream-notices.json` retains
additional upstream source/header/license evidence with hashes. The manifest
contains **55 distinct complete legal texts**, deduplicated by text hash and
with all associated package names retained.

Embedded `LICENSE`, `NOTICE`, copyright, and vendor
`third_party_licenses.txt` records are retained from the actual cached
artifacts. Concatenated Google notices are split only when every indexed
heading can be found in the original text; otherwise the complete document is
kept. Actual heading boundaries are used because some distributed JSON byte
offsets are stale. Text normalization changes line endings and outer whitespace
only. Vendor-supplied replacement characters in template punctuation are
retained rather than silently editing the legal wording.

The direct libraries flagged by the audit also have version-specific evidence:

- Picasso 2.5.2: its tagged source copyright header, Square 2013, plus Apache 2.0.
- CircleImageView 2.1.0: its tagged source copyright header, Henning Dodenhof
  2014–2016, plus that tag's full Apache 2.0 license.
- RingProgressBar V1.2.2: README at the tag's immutable commit
  `8d7e892387045399584904722b572859aa342964`, including HotBitmapGG 2016,
  plus the complete Apache 2.0 license. Its POM omits a license declaration.

The manifest does **not** classify all Google components as Apache. Android SDK,
Play Core and Play Integrity terms distributed with the actual artifacts are
included separately. MIT, MIT-0 and BSD notices retain their upstream copyright
statements. The four Flutter Maven artifacts have the core BSD notice here;
Flutter engine and Dart/plugin notices remain in Flutter's generated
`NOTICES.Z` and are accessible through the combined Flutter license registry.
This work concerns the Android application; it does not represent a fresh
audit of server npm dependencies or assets' separate intellectual-property rights.

## Rebuilding

Run from the workspace root, with an available Flutter/Android SDK and cached
release dependencies:

```powershell
Push-Location android
./gradlew.bat --offline --init-script ../tools/legal/runtime_licenses.init.gradle :app:exportRuntimeLicenseInventory
Pop-Location
powershell -NoProfile -File tools/legal/extract_artifact_notices.ps1
node tools/legal/collect_native_licenses.cjs
node tools/legal/build_native_notices.cjs
```

The `*.local.json` working files hold local cache paths and archive extraction;
they are ignored by Git and are not application assets. Source evidence and
rebuild tools also remain outside the runtime asset manifest. Re-resolve and
regenerate after changing native dependency versions. Validation checks that
all 204 selected component IDs map to a full-text hash, that no identical texts
are duplicated, and that native font/library content is present.
