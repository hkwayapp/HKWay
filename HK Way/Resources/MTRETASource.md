# MTR Next Train integration

Dataset: https://data.gov.hk/en-data/dataset/mtr-data2-nexttrain-data
Endpoint: https://rt.data.gov.hk/v1/transport/mtr/getSchedule.php
API specification: https://opendata.mtr.com.hk/doc/Next_Train_API_Spec_v1.7.pdf
Data dictionary: https://opendata.mtr.com.hk/doc/Next_Train_DataDictionary_v1.7.pdf
Checked 2026-08-31. The documents are referenced, not redistributed.
Data intellectual property: MTR Corporation Limited; provided via DATA.GOV.HK.
Reuse conditions: https://data.gov.hk/en/terms-and-conditions

Fetch by line and station code; EN or TC controls operator messages.
The app uses the actual timestamp (Hong Kong time), not the dummy ttnt/valid fields.
Regular CSV UT patterns map to UP, DT to DOWN, including their branch prefixes.
All reported destinations in a direction are retained, including short workings.
East Rail RAC route flags and A/D time types are displayed. Do not infer that a
train reaches the route list's selected terminus or every intermediate station.
Status 0, missing station data and empty arrays are handled separately from
network errors. Network errors retain the prior snapshot with a warning.
Refresh every 30 seconds while visible and active, plus manual/pull refresh.
Expired predictions are removed after a 30-second grace period; timestamps
older than 90 seconds show a stale warning. No first/last timetable is imported.
