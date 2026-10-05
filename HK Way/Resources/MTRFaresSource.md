# MTR adult fare snapshots

Retrieved 2026-08-31 from MTR's open-data resources listed by DATA.GOV.HK:

- https://data.gov.hk/en-data/dataset/mtr-data-routes-fares-barrier-free-facilities
- https://opendata.mtr.com.hk/data/mtr_lines_fares.csv
- https://opendata.mtr.com.hk/data/airport_express_fares.csv

Data provider and intellectual-property owner: MTR Corporation Limited. Reuse is subject to the applicable DATA.GOV.HK terms and source acknowledgement. These files are derived from the published open CSVs, not ordinary website fare tables.

Bundled columns: `from,to,octopus,single`. Regular source columns: SRC_STATION_ID, DEST_STATION_ID, OCT_ADT_FARE, SINGLE_ADT_FARE (positions 2,4,5,8). Airport source positions: 2,4,5,7. Prices are unchanged. Snapshot retrieval date is not an asserted effective date.

Regular table contains 9,216 rows; Airport Express contains 14. The app excludes self-pairs and zero walking-link placeholders, leaving 9,116 regular priced pairs. Destinations must also exist in the bundled official station catalogue. No missing price is inferred.

Airport Express uses distinct fare IDs for Hong Kong (44 vs 39), Kowloon (45 vs 40), and Tsing Yi (46 vs 42). Never merge these tables or fall back between them. No combined Airport Express/regular journey fare is calculated. No First Class, concessions, promotions or journey-planning guarantee is included.

Refresh these snapshots from the same open resources when updating fares; validate station-ID mappings and run Tests/MTRFaresChecks.swift.
