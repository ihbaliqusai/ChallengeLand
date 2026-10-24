# Store art

Runtime images now use pixel-identical lossless WebP files. `pubspec.yaml`
explicitly lists the 19 active `.webp` files. Original PNGs and this README remain
as design sources outside the app bundle. The obsolete `coins.png` loot art and
its unused `GameStoreLoot` widget are no longer shipped.

`coins.png` was generated with the built-in imagegen tool for this project.
The existing character and treasure chest assets remain part of the shop.
Gem illustrations are drawn by Flutter in `game_store_widgets.dart`.

The offer banners were supplied by the user from
`C:\Users\Qusai\Downloads\New folder (2)` and copied without modification:

| Source | Asset | Product |
| --- | --- | --- |
| `1.png` | `offer_starter.png` | `pack_starter` |
| `2.png` | `offer_explorer.png` | `pack_value` |
| `3.png` | `offer_champion.png` | `pack_champion` |

Flutter overlays the price area in each image with the actual Google Play
price, loading/unavailable state, or ownership state. The original files and
their transparency are preserved. The carousel arrow and purchase interactions
remain interactive.

Currency card designs were supplied from
`C:\Users\Qusai\Downloads\New folder (3)` and copied without modification:

| Source | Asset | Product |
| --- | --- | --- |
| `5000.png` | `coins_5000.png` | `coins_5000` |
| `25000.png` | `coins_25000.png` | `coins_25000` |
| `100000.png` | `coins_100000.png` | `coins_100000` |
| `80.png` | `gems_80.png` | `gems_80` |
| `500.png` | `gems_500.png` | `gems_500` |
| `1200.png` | `gems_1200.png` | `gems_1200` |

Currency cards share a 3:4 frame and a fixed price footer. Flutter displays the
artwork region of each source, excluding its transparent margins and printed
price, inside a common gradient border. All six cards and their native glossy
price buttons have matching dimensions and alignment. The original source
files remain unchanged. Tapping the artwork opens the same purchase review as
the price button. Short landscape screens use smaller cards.

Reward tickets were supplied from
`C:\Users\Qusai\Downloads\New folder (4)` and copied without modification:

| Source | Asset | Action |
| --- | --- | --- |
| `1.png` | `reward_daily.png` | Claim the daily gift |
| `2.png` | `reward_watch.png` | Watch a rewarded ad |

Flutter aligns the visible frames independently of the transparent margins.
Native controls replace the printed button labels to reflect sign-in,
availability, claimed rewards, ad cooldowns and daily limits. The same designs
are used on the featured and gems pages.

Membership artwork was supplied from
`C:\Users\Qusai\Downloads\New folder (5)\1.png` and copied unchanged to
`membership.png`. Its original green button, bevel, highlights and padlock are
displayed directly from the image. A clean strip of the same button background
covers the printed price; a transparent native billing control displays the
live localized monthly price, pending state or membership-management label.
Renewal/cancellation information remains available as native text and in the
purchase review.

The "A reason to come back" cards were supplied from
`C:\Users\Qusai\Downloads\New folder (6)` and copied unchanged:

| Source | Asset | Action |
| --- | --- | --- |
| `1.png` | `return_daily.png` | Daily streak gift |
| `2.png` | `return_watch.png` | Rewarded ad |
| `3.png` | `return_download.png` | Verified Million Challenge download reward |

All cards share one frame size. Clean strips of the original artwork cover
printed account data; native labels display the actual streak day, daily gift,
remaining ad views, download eligibility and claimed/pending states. The
original button shapes remain visible and retain their existing reward flows.

Navigation artwork was supplied from
`C:\Users\Qusai\Downloads\New folder (7)\k.png` and copied unchanged to
`navigation.png`. Flutter composes the full-width frame, original icons,
gold selection panel and back button from this asset. Vector clips isolate
the icon silhouettes, and the gold panel follows the selected section.
Labels and tap targets remain native and support Arabic and English.
Each icon's crop and outline share pixel coordinates from the current atlas;
the key's inner opening stays transparent. Tabs keep equal widths and reserve
the same caption area so the icons stay aligned when selection changes.

The "Express yourself" cards were supplied from
`C:\Users\Qusai\Downloads\New folder (15)` and copied unchanged:

| Source | Asset | Character |
| --- | --- | --- |
| `1.png` | `character_fahad.png` | Fahad — 12,000 coins |
| `2.png` | `character_talia.png` | Talia — 800 gems |

Their visible gold frames share matching bounds despite different transparent
margins. The original glossy green buttons and currency emblems are retained;
clean green strips cover printed labels so native text reflects the catalog,
language and ownership state. Actions keep the existing character-picker flow.
Cards sit side by side in landscape and stack on narrow screens.

The Champions Club preview dialog was supplied from
`C:\Users\Qusai\Downloads\New folder (8)\1.png` and copied unchanged to
`champions_club_preview.png`. Its gold frame, blue close button and purple
explore button are retained. Native controls replace the printed price with
the live Google Play monthly price, loading/unavailable state or active
membership status. Explore opens the membership page without starting billing.

Generation prompt:

> Use case: stylized-concept. Asset type: transparent mobile casual game shop currency illustration. A generous pile of shiny chunky gold coins, several short stacks in back, loose tilted coins in front. One front facing oversized coin has a raised five-point star emblem. Polished cartoon game art like a premium casual mobile board game, bold dark golden outlines, rounded bevels, brilliant yellow gold, orange shadows, tiny white sparkles, three-quarter view. Isolated centered compact composition with 6% padding, actual transparent background. No letters, no words, no UI, no frame. This is a reusable currency product illustration for a violet game shop card.
