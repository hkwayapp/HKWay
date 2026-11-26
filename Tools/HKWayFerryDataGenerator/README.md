# Ferry dataset generator

The weekly Ferry workflow owns only the three files in `FerryDataset`. The weekly transport workflow, its cache and `Dataset` are independent. This package uses Python's standard library and curl.

```sh
python3 -B -m unittest discover -s Tools/HKWayFerryDataGenerator
work=$(mktemp -d)
python3 -B Tools/HKWayFerryDataGenerator/generate.py --output "$work/staged"
python3 -B Tools/HKWayFerryDataGenerator/generate.py --validate-only --output "$work/staged"
```

## Contract

- `ferry_manifest.json` declares schema version, snapshot version and time, Hong Kong timezone, SHA-256 hashes of both data files and the exact nine-route catalogue. `verifiedAt` means when the source was fetched and checked, not its editorial effective date. A retained route keeps the previous timestamp and sources.
- `ferry_timetables.json` maps route IDs to operator, ordered endpoint pair, localized remarks and services. `outbound` is origin to destination and `inbound` is the reverse. `weekdays` is ISO 1–7; on a public holiday only rules with `publicHoliday: included` apply, regardless of weekday. A departure's `dayOffset` advances its calendar date from the service date. A frequency window carries its published headway and never expands to synthetic departures.
- `ferry_fares.json` maps the same route IDs to fare records with HKD minor units, fare category, calendar, class and optional eligibility or restrictions. A displayed fare may require reading the provider's category or remark text.
- Optional `conditions`, `restrictions` and `remarkCodes` accompany the official schedule. Unknown codes are preserved under `unresolvedRemarkCodes` and must be treated as unverified restrictions. Empty or omitted annotations do not imply a vessel class. HTML fragments in HKKF remarks are serialized as plain text.

## Sources and publication

Star Ferry's [operator CSVs](https://data.gov.hk/en-data/dataset/starferry-starferry-ferry-service-timetables-and-fare-tables-of-star-ferry) provide 7030 and 7031. The [operator service page](https://www.starferry.com.hk/en/service) is a guarded fallback only. The generator requires a verifiable allowed robots policy and complete, contiguous timetable windows. The service page currently omits two published CSV windows for Wan Chai-bound service, and the policy endpoint returned HTTP 404 in the local check.

[TD schedules and fares](https://data.gov.hk/en-data/dataset/hk-td-wcms_8-ferry-services-tt-ft) supply 7005, 7006, 7017 and 7018 and the fare tables for 7007, 7008 and 7009. The latter three use [HKKF directional timetables](https://data.gov.hk/en-data/dataset/hkkf-hkkfdata-hkkf-eta-data), with the TD files corroborating next-day assignments. The separate Peng Chau–Hei Ling Chau route is excluded. Some HKKF Peng Chau sailing tokens use a glyph that differs from the legend; the original marker and multilingual legend remain available for review.

Each run validates a previous snapshot before using it. A failed route can retain both prior files' records as one unit. A production run needs all nine routes, with at least one refreshed route, before it stages one snapshot and commits only its three files. A concurrent non-fast-forward push fails safely. The local-only `--allow-initial-partial` option emits explicit unavailable routes without creating records for them.
