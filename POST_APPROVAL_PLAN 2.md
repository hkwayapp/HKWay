# HK Way — Post-Approval Plan

Last updated: 11 September 2026

## Current status

- Version 1.0 is in App Review.
- Do not replace its selected build or submit another build while review is in progress.
- The GitHub repository has been renamed to `kenwongtc/HKWay`.
- The local Git remote now uses `https://github.com/kenwongtc/HKWay.git`.
- The Xcode targets are prepared under the new internal names:
  - `HKWay`
  - `HKWayETAWidget`
  - `HKWayWatch`
  - `HKWayTV`
- The customer-facing app name remains localized as `HK Way` and `喂!香港`.
- A Release archive validation passed with the iPhone app, widget, and Watch app.
- The first tvOS experience is implemented as a separate `HKWayTV` target. It provides big-screen MTR and Light Rail exploration, an MTR journey planner, and English, Traditional Chinese, and Simplified Chinese language settings.
- The tvOS simulator build and launch passed. App Store packaging still requires final layered tvOS app-icon artwork and Top Shelf artwork.
- Dataset updates are hosted in the HKWay repository.

## Immediately after version 1.0 is approved

1. Confirm that the App Store product page, icon, localized name, screenshots, privacy policy, and in-app purchase appear correctly.
2. Install the App Store build on a physical iPhone and run a short smoke test:
   - launch and initial data setup;
   - Nearby routes and live ETA;
   - Favorites and widget;
   - the ad-free experience and the Full-version purchase/restore flow;
   - route direction switching;
   - MTR and Light Rail interchange information.
3. Confirm whether release is automatic or manual in App Store Connect. If it is manual, release version 1.0 when ready.
4. Do not modify the approved 1.0 record. Prepare the next changes as version 1.1.

## Version 1.1 archive and submission

1. Pull or verify the latest `main` branch and preserve unrelated local work.
2. Set the marketing version to `1.1` and increment the build number from `3` to `4` or the next unused number.
3. Confirm the archive contains:
   - `HK Way.app`;
   - `HKWayETAWidget.appex`;
   - `HK Way Watch.app`.
4. Test on a physical iPhone and paired Apple Watch:
   - start a journey on iPhone;
   - confirm the Active Journey card appears in Favorites and Nearby;
   - verify the one-stop-before notification;
   - verify the approximately 300-metre final notification;
   - verify that End Journey clears the journey on both devices;
   - verify background notification behaviour while the iPhone app is not visible.
5. Archive with the `HK Way` scheme and upload to App Store Connect.
6. Wait for processing, answer export-compliance questions, and select the new build for version 1.1.
7. Update localized release notes and screenshots if the Watch journey feature is promoted.
8. Submit version 1.1 for review only after the uploaded build and metadata have been checked.

## tvOS release track

The tvOS app is a separate platform binary. It is not included in the iPhone archive and does not need to delay the iPhone/Watch version 1.1 update.

1. Finalize a two-to-five-layer tvOS app icon and Top Shelf artwork that use the existing HK Way identity.
2. In App Store Connect, add tvOS as a platform under the existing HK Way app record.
3. Complete the tvOS product-page metadata, privacy answers, review contact information, and localized descriptions.
4. Capture at least one 1920 × 1080 Apple TV screenshot; prepare separate localized screenshots only when the visible UI language differs.
5. Test remote focus, scrolling, MTR line direction selection, station selection, route reversal, and language switching on an Apple TV simulator and, if available, physical Apple TV hardware.
6. Archive and upload the `HKWayTV` scheme separately from the `HK Way` iPhone scheme.
7. Select the processed tvOS build and submit the tvOS platform for review when its artwork and metadata are complete.

## Development priorities

### 1. Stabilize journey alerts

- Test location tracking on a real Hong Kong journey.
- Confirm the alert is neither too early nor too late in dense urban areas.
- Confirm notification delivery behaviour when a paired Watch is worn and when no Watch is available.
- Add a clear recovery state if location permission or notification permission is disabled.

### 2. Finish the Watch companion

- Keep journey selection on iPhone.
- Show the active route, destination, current progress, and remaining stops on Watch.
- Keep Watch interactions short and suitable for a small display.
- Verify haptics and background behaviour on physical hardware.

### 3. Refine MTR and Light Rail interchange information

- Verify Light Rail route numbers at Yuen Long, Tin Shui Wai, Tuen Mun, and Siu Hong against the bundled official dataset.
- Keep interchange information on the MTR station list without overcrowding the journey origin/destination cards.

### 4. Repository and update maintenance

- A weekly Monday 9:00 AM Hong Kong automation checks for transport-data updates, validates them, builds the app, and pushes only successful updates.
- Review every automated update report before using new data in an App Store build.
- Consider renaming the separate dataset repository later; update all raw-content URLs in the same change if that happens.

## Later roadmap

1. Complete and ship the Watch companion.
2. Complete tvOS artwork, metadata, physical-device testing, and submission.
3. Design a dedicated iPad interface with maps, split views, transport details, and sightseeing information.
