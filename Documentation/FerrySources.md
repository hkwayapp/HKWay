# Ferry starter catalogue

## Central–Peng Chau scheduled departures (implemented 2026-08-31)

Only route 7007 now includes an in-app timetable, read from bundled
Resources/PengChauTimetable.csv. The other six routes retain external links.
The CSV is an unmodified-content snapshot (line endings normalized) retrieved from:
https://www.td.gov.hk/datagovhk_td/ferry-tt-ft/resources/en/ferry_central_pc_timetable_eng.csv
Registered resource:
https://data.gov.hk/en-data/dataset/hk-td-wcms_8-ferry-services-tt-ft/resource/8063da96-a761-4344-90f7-03851116565c
Covered by the published DATA.GOV.HK terms described above/below; UI retains
TD / DATA.GOV.HK attribution and ownership acknowledgement plus resource link.

Parser whitelists Central to Peng Chau and Peng Chau to Central; excludes all
Hei Ling Chau rows. Counts: Mon–Sat 28 outbound / 28 return; Sun/PH 23 outbound /
24 return. CSV remark 1.0 corresponds to the next-calendar-day departure. Verified
against TD #o03, which marks 00:30 with its next-calendar-day footnote. The 03:00
and 03:40 sailings have no such marker and are not automatically moved to tomorrow.
Times render in 24-hour notation; next-day sailings sort last and carry a label.
Unknown day, remark, clock or missing direction/day group fails closed to the
official-link fallback. No unverified vessel-type or freight interpretation added.

Day type is selected manually and fully labelled: Mon–Sat excludes public holidays.
No automatic holiday inference, date-based next departure, countdown or live ETA.
The route's departure selector drives the displayed direction. Data retrieval date
is shown, not misrepresented as the timetable's effective date. Scheduled data can
go stale; official notices remain linked. Future work: update pipeline and remaining
routes, separately scoped. Fare cards remain external. Device layout check pending.

## Original catalogue provenance

Checked 2026-08-31. Expanded to seven connections; not comprehensive
coverage or a live service-status feed. The existing imported bus dataset contains
a FERRY operator label but no ferry route records, so this small catalogue is
bundled separately without changing the shared bus importer or persistence schema.

## Primary open data

- Transport Department, Routes and fares of public transport (XML):
  https://data.gov.hk/en-data/dataset/hk-td-tis_14-routes-fares-xml/resource/8a8b06bf-c624-4f2c-b014-ea9586320a66
- https://static.data.gov.hk/td/routes-fares-xml/ROUTE_FERRY.xml
- DATA.GOV.HK terms: https://data.gov.hk/en/terms-and-conditions

Downloaded one small XML file, generated `2026-08-27T21:25:40`. The four original
records are preserved in Tests/Fixtures/FerryOpenDataSubset.json for verification.

Expansion (same XML snapshot, rechecked TD service page 2026-08-31):
- 7007 / #o03: Central Pier 6 **western berth** – Peng Chau Ferry Pier.
- 7009 / #o04: Central Pier 4 – Yung Shue Wan Ferry Pier.
- 7008 / #o05: Central Pier 4 – Sok Kwu Wan Pier 2.
All three are Hong Kong & Kowloon Ferry; the blue operator accent is app-authored.
These three source records are also included in the test fixture. Yung Shue Wan's
27-minute XML reference agrees with the TD service page. Peng Chau's XML 40 differs
from the current 25–30 minute service description, and Sok Kwu Wan has a range;
both duration cards remain official links. No fares or schedules newly imported.
East/west berths at Central Pier 6 remain separate and reverse selections are tested.

Research follow-up: TD also publishes a separate ferry time/fare table specification:
https://www.td.gov.hk/datagovhk_td/ferry-tt-ft/resources/en/dataspec/franchised_and_licensed_ferry_time_and_fare_tables_dataspec_eng.pdf
This is a candidate for a future open timetable dataset review, not proof that the
existing route XML includes schedules. Availability, resource terms and parsing
have not been reviewed in this expansion. Do not assume timetable data is unavailable.
Route IDs: 7030 (Tsim Sha Tsui–Central), 7031 (Tsim Sha Tsui–Wan Chai), 7005
(Central–Cheung Chau), 7006 (Central–Mui Wo). Endpoint order is normalized only for
display; both endpoint selections find the same connection. IDs are not displayed
as passenger-facing route numbers.

TD data attribution, owners' rights acknowledgement and source links appear in
the UI. DATA.GOV.HK terms are not a licence for arbitrary operator website content.
No operator photographs, descriptive copy, logos or timetable tables are copied.

## Boarding places and operators

Cross-checked basic factual mappings on the TD service-details page:
https://www.td.gov.hk/en/transport_in_hong_kong/public_transport/ferries/service_details/index.html

- 7030 / #i04: Star Ferry, Central Pier 7 and Tsim Sha Tsui Star Ferry Pier.
- 7031 / #i05: Star Ferry, Wan Chai Ferry Pier and Tsim Sha Tsui Star Ferry Pier.
- 7005 / #o01: Sun Ferry, Central Pier 5 and Cheung Chau Ferry Pier.
- 7006 / #o02: Sun Ferry, Central Pier 6 eastern berth and Mui Wo Ferry Pier.

Star Ferry's pier page also identifies its three piers:
https://www.starferry.com.hk/en/pier

The app uses short original place/operator labels and manually authored colour
accents, not copied website layouts or logos. Full service details open externally
on the TD page, in en/tc/sc according to the app language.

## Fare and duration limitations

- Star Ferry reference durations: XML 9 and 8 minutes; consistent with TD service
  details. Shown as approximate, not a live ETA or guaranteed crossing time.
- No single fare is displayed: XML FULL_FARE lacks the complete day/deck/vessel
  context (e.g. Star Ferry 6.5 is not a universal fare). Separate fare card links
  to official details.
- Cheung Chau: multiple vessel durations; do not present XML 60 as universal.
- Mui Wo: XML 55 differs from the checked service page's 35–40. Do not copy an
  alternative number into the app; duration card links to official details.
- No schedules, departures, opening status, vessel positions or service-frequency
  promises. No invented waiting-time countdown or refresh button.

## Fast-service information (checked 2026-09-01)

Central–Cheung Chau now offers a Fast Ferry / Ordinary Ferry reference selector.
TD service details (`index.html#o01`) specify approximately 35–40 / 55–60 minutes
respectively. These are factual reference ranges, not live predictions. Both
services use the same route and piers; fares remain on the official page. The
selector filters the bundled scheduled departures but does not promise availability.

The Central–Cheung Chau detail now bundles TD's English timetable CSV resource
`e291ac1b-83aa-4af7-b6ab-27d1e5b16fbf`, retrieved 2026-09-01. It contains 164
departures across both directions and the two published service-day groups. Remark
markers are preserved: ordinary ferry, weekday-only, Saturday-only, large fast
ferry on weekdays, and the following-calendar-day departure. The existing service
type selector filters this timetable as well as its reference duration. The app
does not automatically determine whether a date is a public holiday and does not
present these scheduled times as live ETA.

Central–Peng Chau's current TD service page (`index.html#o03`) and bundled licensed
CSV do not identify separate fast/ordinary departures. The page explicitly explains
this rather than inventing a fast-service filter. Its existing schedule is unchanged.
This supersedes the earlier blanket omission of Cheung Chau duration values above.

### Central–Mui Wo timetable (checked 2026-09-01)

The route detail bundles TD CSV resource `5c11c040-ab67-4a61-a304-fa176d232037`
(resource last updated 2026-08-10), containing 113 departures in both directions.
The source publishes Monday–Saturday and Sunday/public-holiday groups. Its remark
codes distinguish ordinary sailings and the one ordinary Mui Wo departure routed
via Peng Chau for alighting passengers. Blank remarks are fast sailings. The two
Central 00:30 entries are labelled following-calendar-day only after cross-checking
the current TD service page. The service-type selector filters this timetable; an
empty combination is shown honestly rather than implying service. No live ETA or
fare table is bundled.

### Central–Yung Shue Wan timetable (checked 2026-09-01)

The route detail bundles TD CSV resource `23f6be17-4b34-4296-be0e-4c67d7e62a4a`,
containing 127 departures across both directions and the published Monday–Saturday
and Sunday/public-holiday groups. The timetable data specification defines remark
`1` as Saturday-only and remark `2` as the following calendar day; both are shown
beside the affected times. The source does not classify departures as fast or
ordinary, so the app shows every published sailing without a vessel-type picker.
The app does not infer public holidays or present the schedule as live ETA. Fare
details and service changes remain on the official page.

### Central–Sok Kwu Wan timetable (checked 2026-09-01)

The route detail bundles TD CSV resource `b26944f0-22b9-4d8d-942c-b588d0ebcbab`,
containing 54 departures across both directions and the published Monday–Saturday
and Sunday/public-holiday groups. The timetable data specification defines remark
`1` as an additional sailing that may operate subject to passenger demand. All 10
affected holiday sailings are labelled rather than presented as guaranteed service.
The source does not classify departures as fast or ordinary, so no vessel-type
picker is shown. The schedule is not live ETA; fares and service changes remain on
the official page.

## UI and maintenance

### Ma Wan expansion (checked 2026-09-01)

Routes 7017 (Ma Wan–Central) and 7018 (Ma Wan–Tsuen Wan) come from TD's
`ROUTE_FERRY.xml`; physical piers, operator, 22/12-minute reference durations and
official anchors `o16`/`o17` were cross-checked against TD's current ferry service
details. Both appear in the main Ferry catalogue and the dedicated Ma Wan page.
Schedules and fares remain on the official page and are not bundled here.

By Pier defaults on opening. By Pier and By Location each split results into Hong
Kong & Kowloon and Outlying Islands cards. By Location groups physical piers by
locality (e.g. Central includes its distinct piers); By Operator groups by operator.
Direction selection defaults to the selected pier (or matching location); operator
browsing uses catalogue order. The departure picker swaps the labelled departure
and arrival piers. Official links still contain both directions and are not a
direction-specific timetable feed. Menu picker is used at accessibility text sizes.
All lead to the same route details. Return-pier lookup is included. All menu text
uses primary colour; names appear only in the selected app language, without
additional English subtitles (updated at the user's request). Fare and duration use
separate CustomInfoCardView cards. Accessibility sizes use one summary column and
a menu-style browsing picker. The catalogue is tiny and synchronous, so no network
loading state is necessary. Future remote loading must add loading/error feedback.

Recheck mappings and source dates when expanding/updating. Wider route coverage,
live departures and fare variant modelling remain deferred. Device visual checks
are still needed.
