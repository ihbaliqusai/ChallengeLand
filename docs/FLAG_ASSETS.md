# Country flags

This provenance note is kept outside `assets/flags/` so the Flutter directory
declaration bundles only the flag images.

These 249 static PNG assets were downloaded from [Flagcdn.com](https://flagcdn.com/)
at `https://flagcdn.com/w40/{lowercase ISO country code}.png` on 2026-10-25.
Each source image is 40 pixels wide; original flag proportions are preserved in
the files. The Flutter application bundles these files and makes no network
request to display them.

Flagcdn is provided by [Flagpedia.net](https://flagpedia.net/) and its flag images
are based on vector files from [Wikimedia Commons](https://commons.wikimedia.org/).
The set covers every code in `lib/core/leaderboard_countries.dart`. Every file
came from its matching country-code endpoint; no substituted flags are used.
