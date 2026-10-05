# HK Way tvOS — Bus Display Plan

Last updated: 11 September 2026

## Implementation status

- Part 1 complete: bus-only tab structure, split-screen Home, persistent language/operator settings, Disclaimer, and Data Sources.
- Part 2 complete: cached route/journey/stop dataset loading, operator-filtered route-number search, direction selection, local Apple TV favorites, and favorite-route summaries on Home.
- Part 3 next: live ETA integration for the saved route directions.
- Weather/news integration and final App Store artwork remain later stages.

## Product direction

The Apple TV app is a bus information display, not a journey planner. Journey planning remains on iPhone, where selecting locations and handling detailed interactions is more appropriate.

The tvOS experience should prioritize glanceability, large type, simple remote navigation, and information that is useful when the television is visible across a room.

## Tab 1 — Home

Use a two-column split-screen dashboard.

### Left column

- Show weather or news.
- Keep this area visually calm and readable from a distance.
- If a live source is temporarily unavailable, show a useful fallback state rather than leaving the column blank.

### Right column

- Show live ETA for favorite bus routes or boarding stops.
- Use large route numbers, destination names, operator labels, and arrival times.
- Prioritize the next arrivals and avoid dense iPhone-style detail.
- Include clear loading, unavailable, stale-data, and no-favorites states.
- Refresh ETA automatically at an appropriate interval and provide a manual refresh action.

## Tab 2 — Routes

- Provide bus-route search suitable for the Siri Remote.
- Respect the operators enabled in Settings.
- Show route number, origin, destination, and operator clearly.
- Allow the user to choose the required direction or journey when necessary.
- Allow adding and removing a route/boarding-stop entry from tvOS favorites.
- Changes should update the Home ETA display.

## Tab 3 — Settings

- Language selection:
  - English
  - Traditional Chinese
  - Simplified Chinese
- Bus operator selection aligned with the iPhone app.
- Disclaimer page.
- Data Sources page.
- Persist tvOS preferences and favorites between launches.

## Data and synchronization decisions

- Reuse HK Way bus route, stop, operator, and ETA concepts where they are platform-neutral.
- Do not expose MTR/Light Rail planning in this tvOS version.
- The first implementation may keep favorites locally on Apple TV.
- Cross-device synchronization with iPhone requires an explicit shared mechanism such as CloudKit/iCloud; ordinary `AppStorage` does not automatically synchronize between the iPhone and Apple TV apps.
- Treat iPhone-to-tvOS favorite synchronization as a separate enhancement unless it is implemented and tested explicitly.

## Quality requirements

- All focusable controls must show an obvious focused state.
- Text must remain readable at television viewing distance.
- Avoid long vertical lists on the Home dashboard.
- The app must remain useful when weather/news or one ETA provider is unavailable.
- Verify English, Traditional Chinese, and Simplified Chinese layouts.
- Verify the tvOS simulator Release build before archive preparation.

## App Store prerequisites

- Final layered tvOS app icon.
- Top Shelf artwork.
- At least one 1920 × 1080 Apple TV screenshot.
- tvOS metadata, privacy answers, disclaimer/support links, and review information in App Store Connect.
- Archive and upload the `HKWayTV` scheme separately from the iPhone `HK Way` scheme.
