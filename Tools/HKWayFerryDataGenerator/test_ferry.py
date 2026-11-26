import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from adapters import ROUTES, calendar, clock, hkkf_timetable, star_timetable, td_fares, td_timetable
from generate import FARES, MANIFEST, TIMETABLE, read_snapshot, resolve_route, serialize, validate_frequency_coverage, validate_route


class FerryTests(unittest.TestCase):
    def test_td_departures_and_overnight(self):
        source = ("Direction,Service Date,Service Hour,Remark\n"
                  "Central to Mui Wo,Sundays and public holidays,12:30 a.m.,1.0\n"
                  "Mui Wo to Central,Sundays and public holidays,12:00 noon,2.0\n")
        first, second = td_timetable("7006", source)
        self.assertEqual((first["time"], first["dayOffset"]), ("00:30", 1))
        self.assertEqual((second["time"], second["vesselType"], second["minimumCapacity"]), ("12:00", "fast", 400))
        self.assertEqual(clock("3:00 a.m."), "03:00")

    def test_td_saturday_excludes_public_holidays(self):
        source = ("Direction,Service Date,Service Hour,Remark\n"
                  "Central to Cheung Chau,Mondays to Saturdays except public holidays,6:10 a.m.,3.0\n")
        item, = td_timetable("7005", source)
        self.assertEqual(item["serviceDays"], {"weekdays": [6], "publicHoliday": "excluded"})
        self.assertEqual(item["vesselType"], "ordinary")

    def test_td_fare_blank_columns_and_passenger_class(self):
        source = "Passenger,Service Date,Fare (HK$),Remark,,\nAdult,Daily,$10.20,1,,\n"
        item, = td_fares("7018", source)
        self.assertEqual((item["amountMinor"], item["eligibility"]), (1020, "registered"))
        source = "Passenger,Service Date,Ferry Type,Fare (HK$),Remark\nAdult,Daily,Deluxe Class,26.1,\n"
        item, = td_fares("7005", source)
        self.assertEqual((item["category"], item["fareClass"]), ("Adult", "Deluxe Class"))

    def test_hkkf_direction_conditional_sailing_and_notes(self):
        body = (
            "route id/航綫,direction/方向,origin_en,出發碼頭,出发码头,destination_en,目的地碼頭,目的地码头,"
            "remarks_en,附註,附注,Monday to Saturday/星期一至星期六,Sunday and Public Holidays/星期日及公眾假期\n"
            '1,inbound,Central,中環,中环,Sok Kwu Wan,索罟灣,索罟湾,<span>@ Optional Service</span>,'
            '''@ 或加開,@ 或加开,"['07:20', '']", "['@12:50']"'''
        ).replace(', "', ',"')
        records, notes = hkkf_timetable("7008", "inbound", body, [])
        self.assertEqual(records[1]["conditions"], ["optionalService"])
        self.assertEqual(records[1]["serviceDays"]["publicHoliday"], "included")
        self.assertEqual(notes, {"en": "@ Optional Service", "tc": "@ 或加開", "sc": "@ 或加开"})
        with self.assertRaisesRegex(ValueError, "mismatch"):
            hkkf_timetable("7008", "outbound", body, [])

    def test_star_retains_frequency_without_departures(self):
        data = ("Direction,Service Date,Time,Frequency (min)\n"
                "Central to Tsim Sha Tsui,Mondays to Fridays except public holidays,06:30 – 07:25,10 / 12\n"
                "Central to Tsim Sha Tsui,Mondays to Fridays except public holidays,07:25 – 09:55,6\n")
        records = star_timetable("7030", data)
        self.assertEqual(records[0]["intervalMinutes"], [10, 12])
        self.assertNotIn("time", records[0])
        validate_frequency_coverage(records)
        records[1]["start"] = "07:30"
        with self.assertRaisesRegex(ValueError, "window gap"):
            validate_frequency_coverage(records)

    def test_star_official_csv_preamble_and_range(self):
        data = ('Ferry Service Details - Wanchai / Tsim Sha Tsui Service,,,\n'
                'Operator:,Star Ferry,,\n'
                'Direction,Service Date,Service Hour,"Frequency\n(minutes)"\n'
                'Tsim Sha Tsui to Wanchai,Mon – Sat (Except Public Holidays),4:36pm-6:12pm,8\n'
                'Tsim Sha Tsui to Wanchai,Mon – Sat (Except Public Holidays),6:12pm-7:36pm,10 --14\n')
        first, last = star_timetable("7031", data)
        self.assertEqual((first["start"], first["end"]), ("16:36", "18:12"))
        self.assertEqual((last["intervalKind"], last["intervalMinutes"]), ("range", [10, 14]))
        validate_frequency_coverage([first, last])

    def test_exclude_unrelated_pang_chau_branch(self):
        data = ("Direction,Service Date,Service Hour,Remark\n"
                "Central to Peng Chau,Sundays and public holidays,7:00 a.m.,\n"
                "Peng Chau to Hei Ling Chau,Daily,8:00 a.m.,\n")
        self.assertEqual(len(td_timetable("7007", data)), 1)
        with self.assertRaises(ValueError):
            td_timetable("7006", data)

    def test_malformed_tables_and_missing_direction(self):
        with self.assertRaises(ValueError):
            td_timetable("7018", "not a timetable")
        with self.assertRaises(ValueError):
            clock("24:75")
        with self.assertRaisesRegex(ValueError, "missing timetable or fares"):
            validate_route("7018", [], [])

    def test_historical_fallback_preserves_verified_at(self):
        previous = ({"routes": {"7018": {"state": "fresh", "verifiedAt": "2026-10-01T00:00:00Z"}}},
                    {"7018": {"services": ["old"]}}, {"7018": ["old"]})
        info, schedule, fare = resolve_route("7018", None, previous, "2026-11-01T00:00:00Z")
        self.assertEqual(info["verifiedAt"], "2026-10-01T00:00:00Z")
        self.assertEqual((info["state"], schedule, fare), ("retained", previous[1]["7018"], previous[2]["7018"]))
        self.assertEqual(resolve_route("7017", None, previous, None)[0]["state"], "unavailable")

    def test_manifest_and_checksum(self):
        route = "7018"
        moment = "2026-11-01T00:00:00Z"
        data = {
            TIMETABLE: {route: {"origin": "Ma Wan", "destination": "Tsuen Wan", "operator": "parkIsland",
                                "remarks": {}, "services": [
                                    {"kind": "departure", "direction": tag, "time": "10:00",
                                     "dayOffset": 0, "serviceDays": calendar("daily"), "remarkCodes": []}
                                    for tag in ("outbound", "inbound")
                                ]}},
            FARES: {route: [{"category": "Adult", "currency": "HKD", "amountMinor": 1200,
                             "serviceDays": calendar("daily"), "fareClass": None, "remarkCodes": []}]},
        }
        manifest = {"schemaVersion": 1, "timezone": "Asia/Hong_Kong", "version": moment, "generatedAt": moment,
                    "routes": {r: {"state": "unavailable", "verifiedAt": None, "sources": []} for r in ROUTES},
                    "sha256": {}}
        manifest["routes"][route] = {"state": "fresh", "verifiedAt": moment,
                                     "sources": ["https://www.td.gov.hk/fixture.csv"]}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, value in data.items():
                payload = serialize(value)
                (root / name).write_bytes(payload)
                manifest["sha256"][name] = hashlib.sha256(payload).hexdigest()
            (root / MANIFEST).write_text(json.dumps(manifest))
            self.assertEqual(read_snapshot(root)[0]["routes"][route]["verifiedAt"], moment)
            (root / FARES).write_text("{}")
            with self.assertRaisesRegex(ValueError, "checksum mismatch"):
                read_snapshot(root)
