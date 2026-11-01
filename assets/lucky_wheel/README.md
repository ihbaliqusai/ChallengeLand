# Lucky Wheel supplied artwork

Imported on 2026-10-30 from the three PNGs supplied for the Lucky Wheel redesign:
`C:\Users\Qusai\Downloads\New folder (5)`.

| Runtime file | Supplied file | Dimensions | Role |
| --- | --- | --- | --- |
| stage.webp | 1.png | 1000 × 558 | Purple star field and velvet curtains |
| emblem.webp | 2.png | 200 × 208 | Fixed gold presenter medallion |
| wheel.webp | 3.png | 500 × 500 | Fixed gold illuminated rim |

The supplied PNGs were encoded as lossless WebP on 2026-10-31 without resizing.
Every alpha value and all visible RGB pixels were verified against the originals;
only RGB values behind fully transparent pixels may be normalized. `source.json`
records original and runtime SHA-256 hashes. No image generation was used.

The six reward icons were subsequently supplied from
`C:\Users\Qusai\Downloads\New folder (11)`:

| Runtime file | Supplied file | Role |
| --- | --- | --- |
| icons/chest.webp | 1.png | Lucky chest |
| icons/coins.webp | 2.png | Coin rewards |
| icons/key.webp | 3.png | Keys |
| icons/gems.webp | 4.png | Gems and character compensation |
| icons/ticket.webp | 5.png | Tickets |
| icons/character_frame.webp | 6.png | Frame around the live character portrait |

All twelve prize wedges are drawn live with these icons and catalog quantities.
The original wheel bitmap is used only for the fixed outer rim, so no baked
sample prize or character remains on the rotating disc. The same icons appear
in the legend, details and reward reveal. `source.json` also records icon hashes.

The disc has twelve rotating boundary pegs. A smooth launch and friction curve
drive its 4.8-second rotation, while a damped contact spring moves the gold
pointer around its stationary mounting rivet. The server receipt still owns
the final prize and angle.

The back control, gold heading, spin/purchase button, spin counter, countdown,
legend, lights, pointer and reward overlay remain live Flutter controls.

Only these nine runtime images are explicitly declared in `pubspec.yaml`.
They total 959,870 bytes, down from 1,353,646 bytes (29.1% saved). No duplicate
PNGs remain here; originals stay in the supplied source directories. This README,
`source.json`, tests and preview PNG/GIF files are excluded from the app bundle.
The unused former weekly-reward widget and its 1,161,636-byte runtime WebP were
also removed. Relative to the assets bundled before this cleanup, the combined
reduction is 1,559,505 bytes. The original weekly-reward PNG remains unbundled
as a design source.
