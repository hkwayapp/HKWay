# Racecourse transport page

Implemented 2026-08-31 as a limited transport-only first version.

## Open dataset matching

Uses the app's existing imported open transport dataset. No website timetables,
visitor descriptions, admission fees, images or event schedules were imported.

- Sha Tin: exact stop ID `gmb-20010665`, Sha Tin Racecourse (Penfold Park).
  Current local snapshot matches GMB route `gmb-2003673`, number 60R. Its dataset
  description identifies a supplementary service. Do not classify this as daily
  or race-day-only service without verified operating information.
- Happy Valley: exact stop IDs `69`, `365`, `8055`, `gmb-20006937`,
  `gmb-20011592`, `gmb-20012606`. These are named racecourse stops on
  Wong Nai Chung Road / Morrison Hill Road, not general Happy Valley stops.
- Join JourneyStopEntity → JourneyEntity → RouteEntity; deduplicate route IDs,
  preserving separate dataset variants and operator identities. This avoids
  splitting composite GMB journey IDs or matching an unrelated route by number.
- The local JSON join found 43 route records total (one Sha Tin, 42 Happy Valley).
  Counts can change with dataset updates. Lists do not assert which direction
  serves the venue or that a service is operating now; users open route details.

## External official information

Official links only, checked 2026-08-31:

- https://entertainment.hkjc.com/en-us/visit-us/sha-tin-racecourse
- https://happywednesday.hkjc.com/en-US/plan-your-visit/

Website access is not a reuse licence. No HKJC website content is reproduced.
Avoid legacy mobile transport pages, which contain dated information. The UI
separates dataset connections from external race-day arrangements and does not
invent missing dedicated race-day bus data or Racecourse station patterns.

## Deferred

Sha Tin now includes an East Rail Line / Racecourse Station information card,
with a race-day service notice and this official MTR link (checked 2026-08-31):
https://www.mtr.com.hk/en/customer/services/service_hours_search.php?query_type=search&station=70
MTR notes that schedules can change and users should check with the station.
The card uses original app wording, provides no timetable or live status, and
does not add Racecourse to the planner or ETA station catalogue.

Dedicated race-day route lists, verified event availability / boarding locations,
and Racecourse station rail integration require a suitable source and validation.
Visitor information remains deferred. Device checks for card navigation, Chinese
localization, route-detail loading and large text are still needed.
