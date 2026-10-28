# Home screen artwork

The current home action sidebar uses the supplied cutouts in `sidebar/`.
It places the leaderboard above the campaign and Champions Club cards, followed
by game modes, friends, and Play. See `sidebar/README.md` for the original files,
crop bounds, and hashes. The friends and Play artwork is tinted green at runtime
to match the supplied layout; the originals retain their gold colors. Labels,
world rank, trophy progress, and the current campaign stage are live Flutter content.
The campaign label uses saved progress and the actual stage count (for example,
`5/100` after completing the first four stages). The leaderboard medallion shows
the player's actual global leaderboard position, centered in the original
circular face. It follows the board's trophy and account-ID tie ordering,
including positions beyond the first 200 players. Missing or unavailable ranks
show a dash. The player's level remains in the separate level frame. The controls keep their
sign-in checks, routes, and guide targets. Play adds a pulsing outline, moving
edge light, and a periodic sheen, with reduced-motion support.

The Champions Club slot alternates with the supplied lucky wheel card every
five seconds. A short fade keeps the card in the same bounds. Rotation pauses
while the home route is hidden, the app is in the background, the guided tour is
open, or the player is interacting with the card. Reduced motion keeps the
five-second alternation and removes the animated transition. The wheel opens
the existing manual wheel page, including after today's reward is claimed.

The seven original home controls use pixel-identical lossless WebP files.
The lobby background (`lobby_background.jfif`, folder 17) and the current level
frame (`level_badge.png`, folder 18) are also explicitly listed in `pubspec.yaml`.
Original control PNGs, this README and the superseded royal level frame remain
unbundled design sources.

The supplied PNG files are copied unchanged and keep their transparency.

| Source folder | Source | Asset | Control |
| --- | --- | --- | --- |
| `New folder (12)` | `1.png` | `menu.png` | Main menu |
| `New folder (12)` | `2.png` | `friends.png` | Friends and players |
| `New folder (12)` | `3.png` | `store.png` | Store |
| `New folder (13)` | `1.png` | `campaign.png` | Campaign stages |
| `New folder (13)` | `2.png` | `modes.png` | Game modes |
| `New folder (13)` | `3.png` | `gems.png` | Live gem balance / store |
| `New folder (13)` | `4.png` | `coins.png` | Live coin balance / store |
| `New folder (14)` | `t.png` | `level.png` | Superseded design source (unbundled) |
| `New folder (5)` | `1.png` | `lobby_background.png` | Home lobby background |
| `New folder (18)` | `1.png` | `level_badge.png` | Current live level and XP frame |

The original 7746 and 299201 sample balances are covered with clean strips
from the same artwork; native text displays the player's actual balances.
All shortcuts keep their original routes, offline checks and touch targets.

The current level control keeps the supplied stone shield, gold trim, trophy
and star. Clean texture strips from the same image cover the sample numbers;
native labels and a clamped progress bar show live player data. It stays centered
above the chosen character, with room reserved so the frame cannot overlap it.
