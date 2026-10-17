# Home screen artwork

Runtime images use pixel-identical lossless WebP files. `pubspec.yaml` explicitly
lists the seven active `.webp` files; original PNGs, this README and the unused
royal level frame are design sources and are not included in the app bundle.

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
| `New folder (14)` | `t.png` | `level.png` | Live level and XP progress |

The original 7746 and 299201 sample balances are covered with clean strips
from the same artwork; native text displays the player's actual balances.
All shortcuts keep their original routes, offline checks and touch targets.

The level control uses the original dark rounded badge, gold trophy and progress
bar, centered above the arena. Its native labels and clamped progress follow the
player's actual data. The supplied royal frame is retained as an unused asset.
