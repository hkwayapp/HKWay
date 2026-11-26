"""Normalize official scheduled service data. No live ETA inputs."""

import ast
import csv
from decimal import Decimal
import html
import io
import re

ROUTES = {
    "7030": ("Central", "Tsim Sha Tsui", "star", "central_tsimshatsui"),
    "7031": ("Wan Chai", "Tsim Sha Tsui", "star", "wanchai_tsimshatsui"),
    "7005": ("Central", "Cheung Chau", "sun", "central_cc"),
    "7006": ("Central", "Mui Wo", "sun", "central_mw"),
    "7007": ("Central", "Peng Chau", "hkkf", "central_pc"),
    "7009": ("Central", "Yung Shue Wan", "hkkf", "central_ysw"),
    "7008": ("Central", "Sok Kwu Wan", "hkkf", "central_skw"),
    "7017": ("Ma Wan", "Central", "parkIsland", "mawan_c"),
    "7018": ("Ma Wan", "Tsuen Wan", "parkIsland", "mawan_tw"),
}
HKKF = {"7008": 1, "7009": 2, "7007": 3}
RULES = {
    "weekday": ([1, 2, 3, 4, 5], "excluded"),
    "mondayToSaturday": ([1, 2, 3, 4, 5, 6], "excluded"),
    "saturday": ([6], "excluded"),
    "sundayOrHoliday": ([7], "included"),
    "weekendOrHoliday": ([6, 7], "included"),
    "daily": (list(range(1, 8)), "included"),
}


def rows(body):
    reader = csv.reader(io.StringIO(body.lstrip("\ufeff"), newline=""), strict=True)
    table = [[cell.strip() for cell in line] for line in reader if any(line)]
    if len(table) < 2:
        raise ValueError("CSV missing header or records")
    return table[0], table[1:]


def td_rows(body, required, allowed):
    header, records = rows(body)
    columns = [key for key in header if key]
    if not required <= set(columns) <= allowed or len(columns) != len(set(columns)):
        raise ValueError(f"unexpected table columns: {header}")
    for record in records:
        if len(record) != len(header) or any(value for key, value in zip(header, record) if not key):
            raise ValueError("invalid CSV row width or unnamed value")
        yield {key: value for key, value in zip(header, record) if key}


def rule_key(label):
    key = re.sub(r"[^a-z ]", " ", label.lower()).replace("excluding", "except")
    key = " ".join(key.split()).replace("mondays", "monday").replace("fridays", "friday")
    key = key.replace("saturdays", "saturday").replace("sundays", "sunday")
    mapping = {
        "monday to friday except public holidays": "weekday",
        "mon fri except public holidays": "weekday",
        "monday to saturday except public holidays": "mondayToSaturday",
        "mon sat except public holidays": "mondayToSaturday",
        "sunday and public holidays": "sundayOrHoliday",
        "sunday public holidays": "sundayOrHoliday",
        "sun public holidays": "sundayOrHoliday",
        "saturday sunday and public holidays": "weekendOrHoliday",
        "sat sun public holidays": "weekendOrHoliday",
        "daily": "daily",
    }
    if key not in mapping:
        raise ValueError(f"unknown service-day rule: {label}")
    return mapping[key]


def calendar(key):
    days, holiday = RULES[key]
    return {"weekdays": days, "publicHoliday": holiday}


def clock(label):
    label = label.strip().lower().replace(".", "")
    match = re.fullmatch(r"(\d{1,2}):(\d{2})(?:\s*(am|pm|noon|midnight))?", label)
    if not match:
        raise ValueError(f"invalid time {label!r}")
    hour, minute, period = match.groups()
    hour, minute = int(hour), int(minute)
    if minute > 59 or (period and not 1 <= hour <= 12) or (not period and hour > 23):
        raise ValueError(f"invalid time {label!r}")
    if period in {"noon", "midnight"} and (hour, minute) != (12, 0):
        raise ValueError(f"invalid literal noon/midnight {label!r}")
    if period:
        hour = hour % 12 + (12 if period in {"pm", "noon"} else 0)
    return f"{hour:02}:{minute:02}"


def direction(route, label):
    a, b, *_ = ROUTES[route]
    name = " ".join(label.lower().split())
    name = name.replace("wanchai", "wan chai")
    for tag, origin, destination in (("outbound", a, b), ("inbound", b, a)):
        if name == f"{origin} to {destination}".lower():
            return tag
    if route == "7007" and name in {"peng chau to hei ling chau", "hei ling chau to peng chau"}:
        return None
    raise ValueError(f"unexpected direction {label!r} for {route}")


def departure(tag, key, time, offset=0, codes=(), **fields):
    return {"direction": tag, "serviceDays": calendar(key), "kind": "departure",
            "time": time, "dayOffset": offset, "remarkCodes": list(codes), **fields}


def td_timetable(route, body):
    required = {"Direction", "Service Date", "Remark"}
    records = []
    for row in td_rows(body, required, required | {"Service Hour", "Timetable"}):
        tag = direction(route, row["Direction"])
        if tag is None:
            continue
        key = rule_key(row["Service Date"])
        time = clock(row["Service Hour"] if "Service Hour" in row else row["Timetable"])
        code = row["Remark"].removesuffix(".0")
        extra = {}
        offset = 0
        if route == "7005":
            if code in {"1", "3", "4"}:
                extra.update(vesselType="ordinary", restrictions=["freightPermitted"])
            if code in {"2", "4", "5"}:
                key = "weekday"
            if code == "3":
                key = "saturday"
            if code == "5":
                extra.update(vesselType="fast", minimumCapacity=400)
            offset = int(code == "6")
        elif route == "7006":
            offset = int(code == "1")
            if code == "2":
                extra.update(vesselType="fast", minimumCapacity=400)
        elif route == "7007":
            offset = int(code == "1")
        elif route == "7009":
            offset = int(code == "2")
            if code == "1":
                key = "saturday"
        elif route == "7008" and code == "1":
            extra["conditions"] = ["subjectToDemand"]
        allowed = {"7005": "123456", "7006": "12", "7007": "1", "7009": "12", "7008": "1"}
        if code and code not in list(allowed.get(route, "")):
            raise ValueError(f"unrecognized timetable remark {route}/{code}")
        records.append(departure(tag, key, time, offset, [code] if code else [], **extra))
    return records


def cents(value):
    cleaned = value.strip().removeprefix("$")
    if re.fullmatch(r"\d+(?:\.\d{1,2})?", cleaned):
        return int(Decimal(cleaned) * 100)
    if cleaned.casefold() in {"free", "free 免費"}:
        return 0
    raise ValueError(f"unrecognized fare {value!r}")


def td_fares(route, body):
    required = {"Passenger", "Service Date", "Fare (HK$)", "Remark"}
    records = []
    for row in td_rows(body, required, required | {"Route", "Ferry Type"}):
        if "Route" in row:
            if route == "7007" and row["Route"] == "Peng Chau - Hei Ling Chau":
                continue
            a, b, *_ = ROUTES[route]
            if row["Route"] != f"{a} - {b}":
                raise ValueError(f"unexpected fare route {row['Route']!r}")
        if not row["Passenger"]:
            raise ValueError("missing fare category")
        code = row["Remark"].removesuffix(".0")
        item = {"category": row["Passenger"], "serviceDays": calendar(rule_key(row["Service Date"])),
                "currency": "HKD", "amountMinor": cents(row["Fare (HK$)"]),
                "fareClass": row.get("Ferry Type") or None, "remarkCodes": [code] if code else []}
        if route in {"7017", "7018"} and code in {"1", "2"}:
            item["eligibility"] = "registered" if code == "1" else "notRegistered"
        elif code == "1" and route in {"7005", "7006", "7007", "7008", "7009"}:
            item["restrictions"] = ["firstTripFromDestination"]
        elif code:
            raise ValueError(f"unrecognized fare remark {route}/{code}")
        records.append(item)
    return records


def plain_notes(value):
    value = re.sub(r"^\s*rgb\([^>]+>", "", value)
    return " ".join(html.unescape(re.sub(r"<[^>]*>", " ", value)).split())


def hkkf_timetable(route, tag, body, td_records):
    header, records = rows(body)
    if len(header) != 13 or len(records) != 1 or len(records[0]) != 13:
        raise ValueError("unexpected HKKF timetable layout")
    if [cell.split("/")[0].strip().lower() for cell in header] != [
        "route id", "direction", "origin_en", "出發碼頭", "出发码头", "destination_en",
        "目的地碼頭", "目的地码头", "remarks_en", "附註", "附注",
        "monday to saturday", "sunday and public holidays"
    ]:
        raise ValueError("unexpected HKKF timetable header")
    row = records[0]
    a, b, *_ = ROUTES[route]
    if row[0] != str(HKKF[route]) or row[1] != tag or (row[2], row[5]) != (a, b):
        raise ValueError("HKKF route, direction or endpoints mismatch")
    result = []
    for key, column in (("mondayToSaturday", 11), ("sundayOrHoliday", 12)):
        values = ast.literal_eval(row[column])
        if not isinstance(values, list) or not all(isinstance(value, str) for value in values):
            raise ValueError("HKKF departures must be a string list")
        for raw in filter(str.strip, values):
            match = re.fullmatch(r"([@^#*▲🞁{}\\\s]*)(\d{2}:\d{2})([}\s]*)", raw)
            if not match:
                raise ValueError(f"unknown HKKF departure format {raw!r}")
            prefix, time, suffix = match.groups()
            time = clock(time)
            markers = [ch for ch in prefix if ch not in "{}\\ \t"]
            if "{" in prefix and "}" in suffix:
                markers.append("{}")
            elif "{" in prefix or "}" in suffix or "}" in prefix:
                raise ValueError(f"unpaired HKKF marker {raw!r}")
            effective_key = key
            extra = {}
            if route == "7008" and "@" in markers:
                extra["conditions"] = ["optionalService"]
            if route == "7009" and "{}" in markers:
                if key != "mondayToSaturday":
                    raise ValueError("Saturday-only note contradicts HKKF service-day column")
                effective_key = "saturday"
            if "^" in markers:
                extra["lastSailing"] = True
            restrictions = []
            if route == "7008" and "^" in markers or route == "7007" and "{}" in markers:
                restrictions.append("freightRestricted")
            if route == "7009" and "#" in markers:
                restrictions.append("advanceFreightBooking")
            if route == "7009" and "*" in markers or route == "7007" and "▲" in markers:
                restrictions.append("smallFreightOnly")
            if route == "7007" and "#" in markers:
                extra["continuesTo"] = "Hei Ling Chau"
            if "🞁" in markers:
                extra["unresolvedRemarkCodes"] = ["🞁"]
            if restrictions:
                extra["restrictions"] = restrictions
            corroborated = [item["dayOffset"] for item in td_records
                            if item["direction"] == tag and item["time"] == time
                            and item["serviceDays"] == calendar(effective_key)]
            if time < "01:00" and not corroborated:
                raise ValueError(f"unverified overnight assignment on {route}/{tag}: {raw}")
            result.append(departure(tag, effective_key, time, max(corroborated, default=0), markers, **extra))
    return result, dict(zip(("en", "tc", "sc"), map(plain_notes, row[8:11])))


def frequency(tag, key, window, intervals):
    parts = re.split(r"\s*[-–—]\s*", window)
    if len(parts) != 2:
        raise ValueError(f"invalid service period {window!r}")
    start, end = map(clock, parts)
    range_match = re.fullmatch(r"(\d+)\s*(?:--|–|—)\s*(\d+)", intervals)
    if start == end or (not range_match and not re.fullmatch(r"\d+(?:\s*/\s*\d+)*", intervals)):
        raise ValueError(f"invalid frequency {intervals!r}")
    minutes = list(map(int, range_match.groups())) if range_match else [int(number) for number in intervals.split("/")]
    if not all(0 < n <= 120 for n in minutes) or (range_match and minutes[0] >= minutes[1]):
        raise ValueError("invalid headway minutes")
    return {"direction": tag, "serviceDays": calendar(key), "kind": "frequency",
            "start": start, "end": end, "endDayOffset": int(end < start), "intervalMinutes": minutes,
            "intervalKind": "range" if range_match else "listed", "sourceHeadway": intervals}


def star_table(route, body, first_column):
    first, lines = rows(body)
    a, b, *_ = ROUTES[route]
    if first[0] == first_column:
        return first, lines, ""
    expected = f"Ferry Service Details - {a} / {b} Service".casefold().replace("wan chai", "wanchai")
    if first[0].casefold().replace("wan chai", "wanchai") != expected:
        raise ValueError("unexpected Star Ferry route heading")
    notes = ""
    for index, row in enumerate(lines):
        if row[0] == "Remarks:" and len(row) > 1:
            notes = row[1]
        if row[0] == first_column:
            return row, lines[index + 1:], notes
    raise ValueError("missing Star Ferry table")


def star_timetable(route, body):
    heading, lines, _ = star_table(route, body, "Direction")
    supported = [
        ["Direction", "Service Date", "Service Hour", "Frequency (minutes)"],
        ["Direction", "Service Date", "Time", "Frequency (min)"],
    ]
    if [" ".join(cell.split()) for cell in heading] not in supported or any(len(row) != 4 for row in lines):
        raise ValueError("unexpected Star Ferry timetable columns")
    return [frequency(direction(route, tag), rule_key(day), window, interval)
            for tag, day, window, interval in lines]


def star_fares(route, body):
    heading, lines, notes = star_table(route, body, "Passenger")
    if heading[-1] != "Remarks" or len(heading) != (6 if route == "7030" else 4):
        raise ValueError("unexpected Star Ferry fare columns")
    column_rules = []
    for raw in heading[1:-1]:
        match = re.fullmatch(r"(.+?)(?: (Upper Deck|Lower Deck))? Fare\(HK\$\)", " ".join(raw.split()))
        if not match:
            raise ValueError(f"unexpected Star Ferry fare heading {raw!r}")
        day, seating = match.groups()
        column_rules.append((rule_key(day), seating))
    expected = [("weekday", "Upper Deck"), ("weekday", "Lower Deck"),
                ("weekendOrHoliday", "Upper Deck"), ("weekendOrHoliday", "Lower Deck")]
    if route == "7031":
        expected = [("weekday", None), ("weekendOrHoliday", None)]
    if column_rules != expected:
        raise ValueError("incomplete Star Ferry fare class/day coverage")
    records = []
    for row in lines:
        if len(row) != len(heading) or not row[0]:
            raise ValueError("invalid Star Ferry fare row")
        for amount, (day, seating) in zip(row[1:-1], column_rules):
            records.append({"category": row[0], "currency": "HKD", "amountMinor": cents(amount),
                            "serviceDays": calendar(day), "fareClass": seating,
                            "remarkCodes": [row[-1]] if row[-1] else []})
    if len(lines) < 6 or (any(row[-1] for row in lines) and not notes):
        raise ValueError("incomplete Star Ferry fare categories or notes")
    return records, notes
