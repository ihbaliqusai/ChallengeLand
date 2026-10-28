# ChallengeLand replacement audio

The build script combines CC0 source recordings with original procedural sound
design. It never reads, samples or imitates the previous soundtrack to create
the new recordings. The legacy Android resource names and aliases stay stable.
The publisher later requested restoration of the previous anticipation roll,
`drum1.mp3`; it is retained separately and is not represented as CC0 or original
DSP. Its current license status is unverified.

```powershell
node tools/audio/build_audio.cjs
node tools/audio/verify_audio.cjs
node tools/audio/build_audio.cjs --apply
node tools/audio/verify_audio.cjs android/app/src/main/res/raw
node tools/audio/write_preview.cjs
powershell -NoProfile -File tools/audio/verify_bundle.ps1
```

Set `CHALLENGELAND_FFMPEG` to use a different FFmpeg executable. The script
defaults to the existing local FFmpeg installation used by the project's other
media tools. Output is staged under `build/audio-replacement/`; `--apply`
replaces only the 18 selected MP3s and the search WAV, and writes `raw/audio_provenance.json`.
`main_theme_320bit_chosic.mp3` and `sneaky_snitch.mp3` remain unchanged.
`retained_assets.json` protects the restored `drum1.mp3` from future generation
or `--apply` runs, and records its exact prior SHA-256.

The per-file ledger records sources, authors, license links, source hashes,
processing, durations, and output hashes. `docs/audio-replacement-before.json`
records the prior audio hashes, including the two retained licensed tracks.
The sources below are needed to rebuild the recordings; they are outside the
application asset manifest.

| Source | Author | Original page |
|---|---|---|
| Interface Sounds, four selected effects | Kenney | https://kenney.nl/assets/interface-sounds |
| Unsolved Investigation | isaiah658 | https://opengameart.org/content/unsolved-investigation |
| Suspense | wipics | https://opengameart.org/content/suspense-0 |
| Opening Theme [Action/Suspense] | nene | https://opengameart.org/content/opening-theme-actionsuspense |

All selected third-party sources are published as CC0 1.0. See the retained
CC0 legal code and Kenney license in `sources/`. The opening WAV was converted
losslessly to FLAC for source storage. Attribution is included in the app even
though CC0 does not require it.

Original DSP components include timer tones, telephone tones,
wordless robotic chatter, bright success/failure cues, impact/whoosh effects,
and a new major-key victory score. They use mathematical oscillators, envelopes
and seeded noise, without sampled performers or external voice recordings.
These are procedurally synthesized recordings, not output from an external
generative-audio model.

`match_search.wav` is an original, quiet radar loop for opponent searching:
1.6 seconds of 44100 Hz mono PCM16 audio with evenly spaced pings, quiet echoes,
and silent boundary samples. Regenerate only this effect and update its ledger
record with `node tools/audio/generate_match_search.cjs --apply`; this command
does not replace other recordings. The full build script also includes the loop.

The welcome video's audio track was removed at the publisher's request. Both
canonical and editable video copies match, and the login player is muted.

Runtime routing and recording-specific gains live in `GameAudioProfile.java`.
Both game engines use `GameSoundController.java` for separate music/effect
channels, bounded outgoing fades, preference handling and player cleanup.
Question beds follow the 1–5 / 6–10 / 11+ bands; board questions use their
200 / 400 / 600 cell values. The million-prize fanfare is reserved for the
corresponding victory screen. The preview plays isolated recordings at browser
volume; in-game mixing applies the runtime gains.

Run `node tools/test_game_audio.cjs` to execute the production controller/profile
against strict MediaPlayer stubs and a virtual clock. It verifies fade levels,
channel isolation, completion/error cleanup, cancellation on release, cue routing
and gain balance. It does not replace a listening pass on a physical device.
