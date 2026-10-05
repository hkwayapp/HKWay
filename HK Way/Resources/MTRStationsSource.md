# MTR station open data

Retrieved 2026-08-31 from:
https://opendata.mtr.com.hk/data/mtr_lines_and_stations.csv

Published resource:
https://data.gov.hk/en-data/dataset/mtr-data-routes-fares-barrier-free-facilities

Data intellectual property owner: MTR Corporation Limited.
Provided via DATA.GOV.HK, HKSAR Government.
Reuse terms: https://data.gov.hk/en/terms-and-conditions

The CSV is retained as published (UTF-8 BOM omitted and line endings normalized).
Preserve direction/branch codes and sort each pattern by numeric Sequence.
Blank comma-only rows are ignored. These are station patterns, not guarantees
that each train serves every station or runs through between every branch.
The TKL TKS pattern lists Tiu Keng Leng–LOHAS Park; do not infer additional
through-service patterns. No first/last timetable, logos or map artwork copied.
Line colours are app-authored approximations for identification.

The app-authored journey planner builds directed edges only between consecutive
stations in each published pattern. Changes connect exact shared station codes,
including train changes between branches on the same line. It minimises train
changes, then ridden station intervals; it does not estimate the fastest route.
Airport Express, different-code walking connections, operating hours and live
disruption routing are excluded in this version. Use Tests/MTRJourneyPlannerChecks.swift
to verify pattern continuity, branch changes and the Tsuen Wan–Disneyland example.
