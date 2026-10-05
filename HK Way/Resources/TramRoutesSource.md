# Tram routes offline snapshot

- Source: https://static.data.gov.hk/td/routes-fares-geojson/JSON_TRAM.json
- Publisher: Transport Department via DATA.GOV.HK
- Retrieved: 2026-09-02 (Hong Kong)
- Source `lastUpdateDate` values: 2025-05-13T00:00:00 and 2026-06-24T00:00:00
- Snapshot: 427 features across route IDs 4001, 4002, 4003, 4004, 4005 and 4007
- Reuse conditions: https://data.gov.hk/en/terms-and-conditions

The bundled JSON provides first-launch and offline tram access. At runtime the app
loads a validated saved refresh when one exists, otherwise this bundled snapshot,
then requests the official URL. A successfully decoded refresh is stored atomically
in Application Support for later offline launches. Network or decoding failures do
not replace the last usable data.
