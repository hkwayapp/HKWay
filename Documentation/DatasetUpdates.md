# Weekly transport dataset updates

HK Way separates non-live network data from live arrival information.

- Live arrivals continue to come directly from the participating operators and DATA.GOV.HK APIs.
- The in-app updater compares `Dataset/dataset_info.json` with the copy published on GitHub. When the version is newer, the app downloads the complete replacement dataset.
- The `Weekly transport dataset update` GitHub Actions workflow runs every Monday at 2:00 AM Hong Kong time (Sunday 18:00 UTC). It can also be run manually from the repository's **Actions** tab.

The workflow downloads the official Transport Department route-and-fare XML resources from DATA.GOV.HK, rebuilds and validates the HK Way route, journey, stop and operator-reference JSON files, and commits the refreshed dataset only when it has changed. `journey_shapes.json` is intentionally retained because it is produced through its separate shape-update process.

If a source endpoint changes or the generator validation fails, the workflow stops without modifying the published `Dataset/` directory.
