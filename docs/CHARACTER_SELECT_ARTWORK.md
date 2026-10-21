# Character selection artwork

The character picker follows the reference supplied at
`C:\Users\Qusai\Downloads\New folder (33)\1.png`.

Runtime background: `assets/ui/character_select_room.webp` (1951 × 806,
73,390 bytes). Created with the built-in image generation tool, then encoded
as WebP at quality 92. The original background remains available at
`assets/ui/character_select_bg.jpg` for design history and is no longer bundled.

The title, character cards, standing character, reflected character, selection
badge and actions are live Flutter widgets. Characters retain the game's
existing artwork, unlock requirements, prices and saved selection. The reflection
uses the same decoded video frame as the standing character and clips it
to the mirror glass. One muted, looping native decoder drives both views, so
their movement stays synchronized. The video's empty black canvas is cropped
using the visible bounds of the complete idle loop, with padding for movement.
The full-body artwork remains visible while the first frame loads and when
reduced motion is enabled. Without native animation support, both previews
share the same subtle breathing animation with their feet anchored.

Each preview has its own output surface and Flutter texture ID. The native
renderer latches the decoder once and publishes that frame to both surfaces.
This avoids repeatedly painting one external texture at two different sizes
and transforms, which can invalidate the cached image during a frame. Flutter's
[SurfaceTexture paint path](https://github.com/flutter/flutter/blob/ef0cd000916d64fa0c5d09cc809fa7ad244a5767/engine/src/flutter/shell/platform/android/surface_texture_external_texture.cc)
processes each paint, and its
[Vulkan texture cache](https://github.com/flutter/flutter/blob/ef0cd000916d64fa0c5d09cc809fa7ad244a5767/engine/src/flutter/shell/platform/android/surface_texture_external_texture_vk_impeller.cc)
depends on the transformed bounds. Playback commands are also sent only when
the pause state changes. Both output surfaces are released after EGL teardown.

The background and stage share the full screen coordinate space. Device safe
area insets cannot push the reflection sideways across the wooden frame.
The standing preview sits to the left of the mirror, and the reflection is
centered in the glass with a horizontal flip and the mirror's slight tilt.
Three columns are visible in landscape; swipe horizontally to see the remaining
characters. Opening a store preview scrolls its card into view.

## Final generation prompt

Use case: precise-object-edit. Asset type: background plate for an interactive
Flutter character selection game. Edit the reference into a CLEAN EMPTY
BACKGROUND at the SAME ultrawide 2752:1136 aspect ratio. Preserve exactly the
original room, blue purple soft cinematic lighting, cyan rounded neon outer
frame, floor, background blur, and wooden standing mirror in their original
locations. Remove ALL people, including the standing man and his reflection,
ALL five character cards and their colored frames and checkmark badge, and ALL
Arabic title text and glints belonging to text. Inpaint these removed areas with
the same soft blue and violet room backdrop. Keep the wooden standing mirror at
x=22%-42%, y=8%-91%, with empty blue glass ready for a real-time character
reflection. Preserve the same tilted mirror perspective, wooden easel, original
mirror glass light diagonal bands, and small magical sparkles. The left
x=7%-21% area must be empty floor/room where the live character will be placed.
The right x=46%-94% area must be empty blue-purple softly blurred room for
programmatic title and cards. No characters, no text, no cards, no UI controls.
This is a background only, not a screenshot of UI. Match original composition,
proportions, palette and neon border closely.

## Validation

`flutter test test/synchronized_character_animation_test.dart test/character_select_screen_test.dart test/home_quick_action_test.dart`

`flutter analyze lib/widgets/synchronized_character_animation.dart lib/screens/character/character_select_screen.dart test/synchronized_character_animation_test.dart test/character_select_screen_test.dart`

Native compilation: from `android`, run
`./gradlew.bat :app:compileDebugKotlin :app:compileDebugJavaWithJavac --console=plain`.

The character screen tests export `build/character-select-reference.png`,
`build/character-select-landscape.png` and `build/character-select-portrait.png`.
