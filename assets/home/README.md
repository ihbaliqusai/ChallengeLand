# Home screen artwork

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
| `New folder (17)` | `b.jfif` | `lobby_background.jfif` | Home lobby background |
| `New folder (18)` | `1.png` | `level_badge.png` | Current live level and XP frame |

The original 7746 and 299201 sample balances are covered with clean strips
from the same artwork; native text displays the player's actual balances.
All shortcuts keep their original routes, offline checks and touch targets.

The current level control keeps the supplied stone shield, gold trim, trophy
and star. Clean texture strips from the same image cover the sample numbers;
native labels and a clamped progress bar show live player data. It stays centered
above the chosen character, with room reserved so the frame cannot overlap it.
