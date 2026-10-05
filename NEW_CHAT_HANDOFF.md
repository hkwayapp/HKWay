# HK Way — New Chat Handoff

Updated: 2026-09-07 (Hong Kong)

## Source of truth

Continue using `PROJECT_AGENDA.md` as the long-term source of truth. This file is only a concise handoff for the next chat.

For the latest tvOS implementation, artwork, upload status, and submission steps, read `TVOS_SUBMISSION_HANDOFF.md`; it supersedes older tvOS status notes in this file and `POST_APPROVAL_PLAN.md`.

## Workspace

- Repository: `/Users/ken/Documents/Programming/HKWay/HKWay`
- Xcode project: `HK Way.xcodeproj`
- Scheme: `HK Way`
- The worktree is intentionally very dirty because the app project rename to HK Way is not committed. Preserve all existing changes and do not reset or restore deleted paths.

## Latest completed work

- Settings is available both as a dedicated bottom tab and through the existing gear button inside More Transport. Re-tapping the Settings tab resets its navigation stack.
- A first-run welcome wizard now runs concurrently with initial dataset preparation, with Traditional Chinese as the initial language, followed by separate pages for the default opening page, favourite operators, and an introduction to bookmarking route directions, bus stops and MTR station directions. The operator list waits for the dataset to be completely ready. SwiftData import loops yield every 50 records; operators/routes/stops/journeys use preloaded in-memory existing-entity lookups rather than per-record SwiftData fetches to reduce lag and import time. The same Setup Assistant can be reopened from Settings and exited with Close. Existing-user loading has expanded HK Way branding and clearer messaging. Device verification remains pending.
- Smart Route Search was removed from the first-build interface because its recommendations need correction. Its source files remain for a post-submission update. Normal route-number Search remains.
- Route Search operator filtering now offers All Operators, Use Settings Preferences, and individual operators; results strictly respect the chosen filter.
- Bus route favourites are direction-specific. Multi-direction routes such as KMB 34 can save both directions separately; each favourite displays `To` / `往` and opens its saved journey stop list.
- Nearby boarding-stop groups are collapsible by tapping their headers, including the two long Yeung Uk Road / Citywalk 2 stop groups.
- StoreKit 2 Full purchase and Restore Purchases flows exist. Product loading can be retried, purchase success is reported, and purchase/restore cannot overlap.
- The correct non-consumable `com.kenwong.hkway.full` is configured in App Store Connect at HKD 8 and in the synced Xcode StoreKit configuration. A local Xcode purchase succeeds. Route, bus-stop, MTR and Light Rail favourite limits now observe `PurchaseManager.accessTier` directly so a completed purchase takes effect immediately instead of retaining a stale Free-tier value.
- The latest unsigned iOS Simulator build passed.

## New Apple identity already applied in Xcode

- Main bundle ID: `com.kenwong.hkway`
- Widget bundle ID: `com.kenwong.hkway.ETAWidget`
- App Group: `group.com.kenwong.hkway`
- URL scheme: `hkway`
- Non-consumable Full product ID: `com.kenwong.hkway.full`
- Display name: `HK Way`

The GitHub repository/dataset URLs and internal Xcode target names still contain TransitGo wording. They are implementation details and were deliberately left unchanged.

## Immediate external setup required

In Apple Developer / App Store Connect, the user needs guided help to:

1. Register App ID `com.kenwong.hkway` with the App Groups capability.
2. Register widget App ID `com.kenwong.hkway.ETAWidget` with the App Groups capability.
3. Register App Group `group.com.kenwong.hkway` and attach both App IDs.
4. Let Xcode refresh signing/provisioning, then test a signed device/archive build.
5. Create a new App Store Connect record named HK Way using `com.kenwong.hkway`. The unrelated existing TransitHK-Go record can remain untouched.
6. Create a non-consumable IAP with exact product ID `com.kenwong.hkway.full`, add English/Traditional Chinese/Simplified Chinese metadata, choose price/territories, and provide review information.
7. Create a Sandbox Apple Account and test purchase, relaunch entitlement, reinstall/restore, cancellation, pending purchase, and product-load retry.
8. Later, create a free Offer Code for founder/promotional Full access. The current entitlement observer should recognize App Store redemption; an optional in-app Redeem Code button has been recommended but not implemented.

The monetization model is finalized: no advertising and no subscriptions. `com.kenwong.hkway.full` is a single HKD 8 one-time non-consumable purchase that unlocks all Full functionality.

## Still outstanding before submission

- Complete the Apple registrations and signed-device/archive verification above.
- AdMob, its package dependency, identifiers, banner UI and consent/privacy integration have been removed. Both Free and Full are completely ad-free.
- Run final device smoke testing and App Store submission checks.
- Smart Route Search stays hidden until the later update.

## Verification command

```sh
xcodebuild -project 'HK Way.xcodeproj' -scheme 'HK Way' -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/HKWayDerivedData CODE_SIGNING_ALLOWED=NO build
```

## Suggested first message for the new chat

> Continue HK Way using `PROJECT_AGENDA.md` and `NEW_CHAT_HANDOFF.md` as context. Preserve the dirty worktree. The Xcode identifiers have been changed to the new HK Way identity and the simulator build passes. Please guide me one step at a time through registering the two App IDs and App Group in Apple Developer, then creating the new HK Way App Store Connect record and non-consumable Full purchase. Do not set a price until I choose it. Smart Route Search must remain hidden for the first submission.
