# HK Way — tvOS Submission Handoff

Updated: 14 September 2026 (Hong Kong)

## Important workspace note

- Repository: `/Users/ken/Documents/Programming/HKWay/HKWay`
- Xcode project: `HK Way.xcodeproj`
- tvOS scheme and target: `HKWayTV`
- iOS scheme: `HK Way`
- The worktree contains extensive intentional, uncommitted project-renaming and feature work. Do not reset, restore, or discard unrelated changes.
- GitHub remote: `https://github.com/kenwongtc/HKWay.git`

## Submission status

### iOS

- HK Way iOS version 1.0 is already in App Review.
- Do not replace or modify the selected iOS 1.0 build while review is in progress.
- The newer Bauhinia branding is present in the local iOS and watchOS source but should be submitted only after iOS version 1.0 is approved, as a later build/version.
- After first-run setup, iOS now presents a one-time localized “What’s New” sheet announcing that HK Way for Apple TV will be available soon. Dismissing it records announcement key `whatsNew.appleTVComingSoon.v1`, so it does not appear again. This local change is intended for the next iOS release rather than the build already in review.

### tvOS

- tvOS was added as a separate platform under the existing HK Way App Store Connect record.
- tvOS version: `1.0`
- Bundle identifier: `com.kenwong.hkway`
- Automatic signing is enabled with team `7KR8YWP2RB`.
- tvOS build 4 was archived, validated, uploaded, selected, and submitted after cancelling the earlier build 3 submission. It is currently Waiting for Review.
- Localized tvOS descriptions/metadata were added and saved for English, Traditional Chinese, and Simplified Chinese.
- App Review information, privacy answers, screenshots, IAP attachment, and final review submission should be rechecked before pressing Submit for Review.

## Critical distinction: submitted build versus current source

- Submitted tvOS build 4 is currently Waiting for Review.
- The local source contains additional post-build-4 improvements intended for build 5 or a later update.
- Do not archive or replace the submitted tvOS build while review is in progress. After approval, increment the build number before the next archive.
- Do not upload a new iOS build at this stage.

## Completed tvOS application work

- Full-screen scenic, weather/time-aware backgrounds that extend beyond the safe area.
- Dark presentation retained throughout the tvOS experience.
- Settings includes a background submenu with automatic selection, previews, and thumbnails suitable for a growing image list.
- Broken/black background assets were removed from the automatic lists, including Sunny 8, 9, and 10.
- Additional user-owned Hong Kong photographs were processed into the background collection.
- Home screen contains weather, Hong Kong traffic news, and bookmarked bus ETA display.
- Traffic news bypasses URL caching, refreshes every five minutes while active and immediately after returning to the foreground. Notices older than three hours (or without a valid timestamp) are hidden, and the source announcement time is displayed.
- The local post-build-4 home screen reads the broader official DATA.GOV.HK legacy Special Traffic News feed and displays up to 12 notices. Pages rotate every 12 seconds with a gentle crossfade and compact `(current/total)` indicator. Short notices are paired two per page; a long notice receives its own page with up to ten lines. Returning to the foreground resets the display to the first page. Repeated generic “Traffic News” headings were removed so the message receives more room.
- Debug builds include a localized **Settings → Sample Traffic News** switch. It replaces the home feed with three stable sample notices—including a long wrapping case—to test `(1/3)` rotation immediately. The switch and samples are excluded from Release/App Store builds with `#if DEBUG`.
- The local source now formats the home-page date and traffic-news timestamp using the selected tvOS language (`en_HK`, `zh_Hant_HK`, or `zh_Hans_CN`). This was added after build 4 was submitted and is therefore intended for build 5 or a later update unless build 4 is withdrawn again.
- The local post-build-4 greeting is now a localized 12-second crossfade carousel. It always rotates friendly check-in and journey messages, then adds context-sensitive advice when current HKO conditions or warnings indicate rain, heat, cool weather, thunderstorms, strong monsoon winds, or a tropical cyclone.
- Festival-aware greetings are generated entirely offline and appear first in the same carousel. Supported occasions are New Year, Labour Day, HKSAR Establishment Day, National Day, Christmas, Lunar New Year (first three days), Lantern Festival, Buddha's Birthday, Dragon Boat Festival, Mid-Autumn Festival, and Chung Yeung Festival, localized in English, Traditional Chinese, and Simplified Chinese.
- The local post-build-4 source also reduces the weather icon from 58 to 48 points, temperature from 64 to 52 points, and condition label from headline to subheadline sizing.
- The local post-build-4 ETA presentation replaces `0m`/`0分` with a localized transition: `Arrived` / `已到站` for the first 30 seconds after the ETA, followed by `Departing` / `正在開出` / `正在驶离` for the remainder of the existing one-minute grace period.
- The selected boarding stop on each home ETA row is now explicitly prefixed with localized `Boarding at`, `上車站：`, or `上车站：` wording; the destination remains on the line below.
- The local post-build-4 weather card now reads the HKO localized `warnsum` and `swt` feeds every five minutes and on foreground activation. It displays the highest-priority active warning, its issue/update time, a count of additional warnings, and the latest Special Weather Tip. Strong Monsoon uses a wind symbol. Tropical-cyclone warnings receive highest priority and now use locally bundled official HKO artwork for T1, T3, T8NE, T8SE, T8SW, T8NW, T9, and T10. An unknown future tropical-cyclone code falls back to the hurricane symbol and signal-code badge. Artwork source: `https://www.hko.gov.hk/en/informtc/precaution.htm`.
- Debug builds now include **Settings → Developer Testing → Weather Warning Preview**, with Live HKO Data, Amber/Red/Black Rainstorm, Strong Monsoon, Thunderstorm, Very Hot, Cold, Frost, Landslip, Tsunami, Fire Danger, pre-T8, T1, T3, all four directional T8 signals, T9, and T10. A selection exercises the same warning model and dashboard mapping as live data without altering the HKO feed. The menu and override are excluded from Release/App Store builds with `#if DEBUG`.
- Debug builds also include **Festival Greeting Preview**, covering all supported festival messages plus Automatic Date. It exercises the production greeting carousel and is excluded from Release/App Store builds. Developer Testing now contains three tools: weather-warning preview, festival-greeting preview, and sample traffic news.
- Every active weather-warning symbol now remains permanently visible beside the temperature while the text-only warning strip rotates through the warnings every 12 seconds with `(1/2)`, `(2/2)`, and similar counters. Bundled tropical-cyclone artwork is 62×62 points and other warning symbols are 44 points. The strip retains each warning's name and issue/update time. Monsoon, rainstorm, thunderstorm, heat, cold/frost, landslip, flooding/tsunami, fire, and pre-T8 notices have distinct system symbols.
- Amber, Red, and Black Rainstorm warnings now use separate high-contrast badges labelled with the full English colour name. The other non-typhoon warnings use consistent 62×62 colour-coded badges: landslip, monsoon, thunderstorm, heat, cold/frost, tsunami/flood, fire danger, pre-T8, and an unknown-warning fallback.
- The local post-build-4 home dashboard removes the `Weather & News` and `Bus ETA Display` card headers and their dividers, reclaiming vertical space for weather warnings, special tips, traffic news, and ETA content.
- The local post-build-4 weather layout further reduces its internal spacing from 20 to 12 points and changes the humidity/rainfall row from callout to caption size. The reclaimed room increases Special Weather Tips from two to three lines and traffic-news details from three to four lines.
- Special Weather Tip details now preserve their caption-sized font and natural wrapped height for up to three lines, preventing tvOS from vertically compressing the text into a single truncated line.
- The local post-build-4 ETA rows render `Boarding at` separately at a smaller 18-point size and allow the boarding-stop name itself two lines. Embedded `<br>`, `<br/>`, and `</br>` markup is converted to inline spacing, keeping the remaining endpoint text on the same line when room permits while still allowing natural wrapping.
- The same endpoint sanitizer now applies to the route-direction selector and its navigation title. Direction origins and destinations keep their normal font sizes, wrap over as many as two lines, and the direction cards expand vertically when needed instead of shrinking the names or displaying literal `<br>` markup.
- The local post-build-4 ETA layout now prioritizes the boarding-stop and destination column without shrinking its text. It reclaims horizontal room by reducing row spacing from 22 to 16 points, the route-number column from 110 to 90 points, the ETA column minimum width from 230 to 180 points, the main ETA from 48 to 40 points, and later ETAs from 18 to 16 points.
- More than four ETA display routes are now automatically paged in groups of four and rotate every 12 seconds with a crossfade. A compact range counter communicates both the visible routes and total saved count, for example `(1–4/10)`, `(5–8/10)`, and `(9/10)`; returning to the foreground resets the display to the first page.
- Repeated update timestamps were removed from individual ETA rows. The card now shows one shared localized update time below the visible routes, while each route's own timestamp remains stored internally for failed-request and stale-state handling.
- Bus ETA presentation shows the nearest arrival prominently with two smaller later arrivals below it.
- Route numbers were enlarged and forced onto one line where required.
- Longer home ETA route numbers such as `234X` explicitly use a single line with tightening and limited scaling inside the existing compact route column.
- English destinations can wrap when horizontal space is insufficient.
- Scheduled-bus wording was removed from the compact ETA presentation; update time remains at the bottom.
- The route flow supports operator selection, route/direction selection, and stop selection.
- Removing a displayed route no longer leaves the user trapped without access to operator selection.
- Route/direction lookup work was moved away from the navigation transition to avoid the apparent freeze.
- Free access is limited to two bookmarks; Full access removes the limit and reads the shared App Store entitlement used by the iPhone purchase.
- The tvOS app icon uses the transit logo on the left and `喂!香港` on the right.

## App icon and Top Shelf artwork

- The original upload initially failed validation because the AppIcon brand asset declared an empty wide Top Shelf slot, so the generated Info.plist lacked `TVTopShelfImage.TVTopShelfPrimaryImageWide`.
- Standard and wide Top Shelf images were populated at all required sizes:
  - standard: 1920×720 and 3840×1440;
  - wide: 2320×720 and 4640×1440.
- The generated tvOS Info.plist now contains both:
  - `TVTopShelfImage.TVTopShelfPrimaryImage`
  - `TVTopShelfImage.TVTopShelfPrimaryImageWide`
- Top Shelf artwork uses the user's own sunset photograph.
- The local iOS, watchOS, and tvOS icon backgrounds now use the Bauhinia color. Logo shapes and Chinese text were preserved pixel-for-pixel through a deterministic recolor rather than regenerated artwork.
- The iOS yellow indicator was intentionally preserved.
- Original red icon files remain recoverable under `Documentation/Branding/OriginalIcons/`.

## Current branding files

- iOS accent: `HK Way/Assets.xcassets/AccentColor.colorset/Contents.json`
- iOS icon: `HK Way/Assets.xcassets/AppIcon.appiconset/HKWay-AppIcon-Bauhinia-1024.png`
- watchOS accent: `HKWayWatch/Assets.xcassets/AccentColor.colorset/Contents.json`
- watchOS icon: `HKWayWatch/Assets.xcassets/AppIcon.appiconset/HKWay-Watch-AppIcon-Bauhinia-1024.png`
- tvOS icons: `HKWayTV/Assets.xcassets/AppIcon.brandassets/`
- Original icon backups: `Documentation/Branding/OriginalIcons/`

## Verification completed

- tvOS Release build succeeded after adding Top Shelf artwork.
- tvOS Release build succeeded again after applying the Bauhinia icon artwork.
- tvOS Release build 4 succeeded after adding traffic-news freshness filtering, timestamps, and foreground refresh.
- iOS Release build succeeded after applying the Bauhinia accent and iOS icon.
- watchOS Release build succeeded after applying the Bauhinia accent and watch icon; the generated square iOS and watchOS icons were also verified to contain no alpha channel.
- tvOS asset-catalog validation and generated Top Shelf Info.plist entries passed.
- The ETA widget `CFBundleVersion` was updated from 3 to 4 to match its containing iOS app, resolving the archive validation mismatch.
- tvOS Debug and Release simulator builds succeeded after adding the complete warning and festival preview tools. The latest tvOS Debug build also passed after adaptive traffic-news paging and the warning-badge changes.
- Xcode also logged that a connected iPhone was passcode protected during command-line verification; this did not prevent either generic Release build from succeeding.

## Deployment-target decision

- `HKWayTV` currently targets tvOS 26.5.
- This means the app can only install on Apple TVs running tvOS 26.5 or later.
- Before final review submission, either deliberately keep 26.5 or lower the target and verify the source compiles and functions on the chosen older tvOS release.

## Privacy policy

- App Store Connect requires an **Apple TV Privacy Policy** URL separately for:
  - English (U.S.);
  - Chinese (Traditional);
  - Chinese (Simplified).
- Existing bilingual policy source: `docs/index.md`.
- Intended public URL: `https://kenwongtc.github.io/HKWay/`.
- Open the URL in a private Safari window and confirm that it loads publicly before entering the same URL in all three localization fields. Do not submit with an inaccessible URL.

## Recommended next steps after the current tvOS review is approved

1. Increment the tvOS build number from 4 to 5 (or the next unused number).
2. Run the complete three-language visual smoke test, including long traffic notices and every Debug warning/festival preview; then return all previews to live/automatic and disable sample traffic news.
3. Select scheme `HKWayTV` and destination **Any tvOS Device (arm64)**.
4. Choose **Product → Archive**, validate, and upload to App Store Connect.
5. Test the processed build through TestFlight on the physical Apple TV.
6. Prepare the next tvOS version/update without modifying the already-approved 1.0 record unexpectedly.

## Physical Apple TV smoke test

- Fresh launch and language selection.
- Remote focus movement across Home, Routes, and Settings.
- Operator selector remains reachable with zero, one, or two displayed routes.
- Select an operator, route, direction, and stop.
- Verify nearest ETA and two later ETAs update correctly.
- Add and remove routes/bookmarks, including the two-bookmark Free limit.
- Purchase/restore Full access and confirm unlimited bookmarking entitlement.
- Confirm weather and traffic news load with internet access.
- Confirm automatic and manually selected backgrounds display correctly.
- Relaunch the app and confirm selections persist.
- Place the app in the top row on the Apple TV Home Screen and inspect the Top Shelf image.

## Useful verification commands

```sh
xcodebuild -project 'HK Way.xcodeproj' -scheme HKWayTV -configuration Release -destination 'generic/platform=tvOS' CODE_SIGNING_ALLOWED=NO build
```

```sh
xcodebuild -project 'HK Way.xcodeproj' -scheme 'HK Way' -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

```sh
xcodebuild -project 'HK Way.xcodeproj' -scheme HKWayWatch -configuration Release -destination 'generic/platform=watchOS' CODE_SIGNING_ALLOWED=NO build
```
