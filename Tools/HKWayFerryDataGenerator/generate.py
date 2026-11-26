"""Fetch, normalize and stage an independent Hong Kong ferry snapshot."""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import csv
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import time
from urllib.robotparser import RobotFileParser

from adapters import (HKKF, ROUTES, RULES, calendar, clock, frequency, hkkf_timetable,
                      star_fares, star_timetable, td_fares, td_timetable)
from star_service import parse_service

TD = "https://www.td.gov.hk/datagovhk_td/ferry-tt-ft/resources/en"
TD_SPEC = TD + "/dataspec/franchised_and_licensed_ferry_time_and_fare_tables_dataspec_eng.pdf"
HKKF_SPEC = "https://www.hkkfeta.com/datagovhk/HKKF_ETA_API_Specification.pdf"
STAR_SITE = "https://www.starferry.com.hk"
STAR_CSV = STAR_SITE + "/sites/default/files/upload/open_data/csv"
STAR_PAGE = STAR_SITE + "/en/service"
USER_AGENT = "HKWayFerryDataGenerator/1.0"
TIMETABLE = "ferry_timetables.json"
FARES = "ferry_fares.json"
MANIFEST = "ferry_manifest.json"


def utc_now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def fetch(url):
    start = time.monotonic()
    status = "failed"
    try:
        result = subprocess.run(
            ["curl", "--silent", "--show-error", "--fail", "--location", "--proto", "=https",
             "--proto-redir", "=https", "--connect-timeout", "5", "--max-time", "12",
             "--max-filesize", "4000000", "--retry", "2", "--retry-all-errors",
             "--retry-max-time", "30", "--user-agent", USER_AGENT, url],
            capture_output=True, check=True, timeout=47,
        )
        body = result.stdout.decode("utf-8-sig")
        if not body.strip():
            raise ValueError("empty response")
        status = "ok"
        return body
    except subprocess.CalledProcessError as error:
        raise ValueError(error.stderr.decode("utf-8", errors="replace").strip()) from error
    finally:
        print(f"source {status} {time.monotonic() - start:.2f}s {url}", flush=True)


def route_data(route, get=fetch):
    _, _, operator, stem = ROUTES[route]
    documents = []

    def source(url):
        response = get(url)
        documents.append(url)
        return response

    if operator == "star":
        errors = []
        results = {}
        for kind, parser in (("timetable", star_timetable), ("faretable", star_fares)):
            url = f"{STAR_CSV}/ferry_sf_{stem}_{kind}_eng.csv"
            try:
                results[kind] = parser(route, source(url))
            except (ValueError, KeyError, csv.Error, OSError, subprocess.SubprocessError) as error:
                errors.append(f"{kind} CSV: {error}")
        if errors:
            documents.clear()
            try:
                robots = RobotFileParser()
                policy = get(STAR_SITE + "/robots.txt")
                if "<html" in policy.lower() or not re.search(r"(?im)^user-agent\s*:", policy):
                    raise ValueError("unable to verify operator robots policy")
                robots.parse(policy.splitlines())
                if not robots.can_fetch(USER_AGENT, STAR_PAGE):
                    raise ValueError("operator robots policy disallows service-page retrieval")
                times, fares, notes = parse_service(route, source(STAR_PAGE))
            except (ValueError, KeyError, csv.Error, OSError, subprocess.SubprocessError) as error:
                raise ValueError("; ".join([*errors, f"official service-page fallback: {error}"])) from error
        else:
            times = results["timetable"]
            fares, notes = results["faretable"]
        validate_frequency_coverage(times)
        return times, fares, {"fare": {"en": notes}} if notes else {}, documents

    td_time = source(f"{TD}/ferry_{stem}_timetable_eng.csv")
    td_price = source(f"{TD}/ferry_{stem}_faretable_eng.csv")
    dates, fares = td_timetable(route, td_time), td_fares(route, td_price)
    documents.append(TD_SPEC)
    notes = {}
    if route in HKKF:
        dates, reference = [], dates
        for tag in ("inbound", "outbound"):
            url = f"https://www.hkkfeta.com/opendata/time_table/{HKKF[route]}/{tag}"
            records, notes[tag] = hkkf_timetable(route, tag, source(url), reference)
            dates.extend(records)
        documents.append(HKKF_SPEC)
    return dates, fares, notes, documents


def validate_frequency_coverage(times):
    groups = {}
    for row in times:
        key = (row["direction"], tuple(row["serviceDays"]["weekdays"]),
               row["serviceDays"]["publicHoliday"])
        groups.setdefault(key, []).append(row)
    for group in groups.values():
        ordered = sorted(group, key=lambda item: item["start"])
        for previous, current in zip(ordered, ordered[1:]):
            if previous["endDayOffset"] or previous["end"] != current["start"]:
                raise ValueError("Star Ferry frequency window gap or overlap; needs official confirmation")


def validate_route(route, times, fares):
    if not isinstance(times, list) or not isinstance(fares, list) or not fares:
        raise ValueError(f"{route}: missing timetable or fares")
    expected_kind = "frequency" if ROUTES[route][2] == "star" else "departure"
    allowed_calendars = [calendar(key) for key in RULES]
    for tag in ("outbound", "inbound"):
        records = [row for row in times if row["direction"] == tag]
        if not records or set().union(*(set(row["serviceDays"]["weekdays"]) for row in records)) != set(range(1, 8)):
            raise ValueError(f"{route}: incomplete direction/day coverage: {tag}")
        if not any(row["serviceDays"]["publicHoliday"] == "included" for row in records):
            raise ValueError(f"{route}: missing holiday coverage: {tag}")
    for row in times:
        if row["kind"] != expected_kind or row["direction"] not in {"outbound", "inbound"} or row["serviceDays"] not in allowed_calendars:
            raise ValueError(f"{route}: invalid timetable record")
        if expected_kind == "departure":
            if row["time"] != clock(row["time"]) or type(row["dayOffset"]) is not int or row["dayOffset"] not in (0, 1):
                raise ValueError(f"{route}: invalid departure time or offset")
        elif (any(row[k] != clock(row[k]) for k in ("start", "end")) or row["start"] == row["end"]
              or row["endDayOffset"] != int(row["end"] < row["start"]) or not row["intervalMinutes"]
              or any(type(n) is not int or not 0 < n <= 120 for n in row["intervalMinutes"])):
            raise ValueError(f"{route}: invalid headway")
        elif expected_kind == "frequency":
            rule = next(key for key in RULES if calendar(key) == row["serviceDays"])
            reference = frequency(row["direction"], rule, f"{row['start']}-{row['end']}", row["sourceHeadway"])
            if any(row.get(field) != value for field, value in reference.items()):
                raise ValueError(f"{route}: inconsistent headway representation")
    if expected_kind == "frequency":
        validate_frequency_coverage(times)
    for row in fares:
        if (row["currency"] != "HKD" or not isinstance(row["category"], str) or not row["category"].strip()
            or type(row["amountMinor"]) is not int or row["amountMinor"] < 0
            or row["serviceDays"] not in allowed_calendars):
            raise ValueError(f"{route}: invalid fare")


def read_snapshot(root):
    def read(name):
        return json.loads((root / name).read_bytes())

    manifest = read(MANIFEST)
    if (manifest["schemaVersion"] != 1 or manifest["timezone"] != "Asia/Hong_Kong"
        or set(manifest["routes"]) != set(ROUTES) or set(manifest["sha256"]) != {TIMETABLE, FARES}
        or manifest["version"] != manifest["generatedAt"]):
        raise ValueError("invalid manifest schema, route set or version")
    timestamp(manifest["generatedAt"])
    for name in (TIMETABLE, FARES):
        if hashlib.sha256((root / name).read_bytes()).hexdigest() != manifest["sha256"][name]:
            raise ValueError(f"checksum mismatch: {name}")
    times, fares = read(TIMETABLE), read(FARES)
    available = set()
    for route, metadata in manifest["routes"].items():
        if metadata["state"] == "unavailable":
            if metadata["verifiedAt"] is not None or metadata["sources"]:
                raise ValueError(f"{route}: unavailable route claims freshness")
            continue
        if metadata["state"] not in {"fresh", "retained"} or not metadata["sources"]:
            raise ValueError(f"{route}: invalid availability metadata")
        if any(not url.startswith(("https://www.td.gov.hk/", "https://www.hkkfeta.com/", STAR_SITE + "/"))
               for url in metadata["sources"]):
            raise ValueError(f"{route}: unofficial source attribution")
        if timestamp(metadata["verifiedAt"]) > timestamp(manifest["generatedAt"]):
            raise ValueError(f"{route}: verification timestamp in the future")
        available.add(route)
        if ([times[route][key] for key in ("origin", "destination", "operator")] != list(ROUTES[route][:3])
            or not isinstance(times[route]["remarks"], dict)):
            raise ValueError(f"{route}: invalid pier, operator or remarks metadata")
        validate_route(route, times[route]["services"], fares[route])
    if set(times) != available or set(fares) != available or not available:
        raise ValueError("timetable and fare coverage disagree with manifest")
    return manifest, times, fares


def timestamp(value):
    if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", value):
        raise ValueError(f"invalid UTC timestamp: {value!r}")
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def resolve_route(route, candidate, previous, verified_at):
    manifest, old_times, old_fares = previous
    if candidate is not None:
        services, fares, notes, sources = candidate
        validate_route(route, services, fares)
        a, b, operator, _ = ROUTES[route]
        return ({"state": "fresh", "sources": sources, "verifiedAt": verified_at},
                {"origin": a, "destination": b, "operator": operator, "services": services, "remarks": notes}, fares)
    if route in old_times:
        return manifest["routes"][route] | {"state": "retained"}, old_times[route], old_fares[route]
    return {"state": "unavailable", "verifiedAt": None, "sources": []}, None, None


def process(route):
    started = time.monotonic()
    try:
        return route_data(route), utc_now()
    finally:
        print(f"route {route} {time.monotonic() - started:.2f}s", flush=True)


def generate(output, baseline, allow_initial_partial=False):
    previous = read_snapshot(baseline) if baseline.exists() else ({}, {}, {})
    by_route, times, fares = {}, {}, {}
    with ThreadPoolExecutor(max_workers=4) as pool:
        tasks = {pool.submit(process, route): route for route in ROUTES}
        for future in as_completed(tasks):
            route = tasks[future]
            try:
                candidate, verified_at = future.result()
                metadata, schedule, fare = resolve_route(route, candidate, previous, verified_at)
            except (ValueError, TypeError, OSError, SyntaxError, KeyError, csv.Error, subprocess.SubprocessError) as error:
                metadata, schedule, fare = resolve_route(route, None, previous, None)
                print(f"{route}: {metadata['state']} ({error})", flush=True)
            by_route[route] = metadata
            if schedule is not None:
                times[route], fares[route] = schedule, fare
    fresh = sum(item["state"] == "fresh" for item in by_route.values())
    summary = {state: sum(row["state"] == state for row in by_route.values())
               for state in ("fresh", "retained", "unavailable")}
    print(f"Ferry snapshot coverage: {summary}", flush=True)
    if not fresh:
        raise ValueError("no routes refreshed; previous snapshot remains unchanged")
    if any(item["state"] == "unavailable" for item in by_route.values()) and not allow_initial_partial:
        raise ValueError("incomplete production route coverage; previous snapshot remains unchanged")
    now = utc_now()
    with tempfile.TemporaryDirectory(dir=output.parent) as scratch:
        stage = Path(scratch) / "snapshot"
        stage.mkdir()
        checksums = {}
        for name, content in ((TIMETABLE, times), (FARES, fares)):
            payload = serialize(content)
            (stage / name).write_bytes(payload)
            checksums[name] = hashlib.sha256(payload).hexdigest()
        manifest = {"schemaVersion": 1, "timezone": "Asia/Hong_Kong", "version": now,
                    "generatedAt": now, "routes": by_route, "sha256": checksums}
        (stage / MANIFEST).write_bytes(serialize(manifest))
        read_snapshot(stage)
        stage.rename(output)


def serialize(value):
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, default=Path("FerryDataset"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--allow-initial-partial", action="store_true", help="local preview only")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    if args.validate_only:
        manifest, _, _ = read_snapshot(args.output)
        if any(item["state"] == "unavailable" for item in manifest["routes"].values()):
            print("Validated local preview with explicit unavailable routes.")
        else:
            print("Validated complete ferry snapshot.")
    else:
        if args.output.exists():
            parser.error("output must be a new staging directory")
        generate(args.output, args.baseline, args.allow_initial_partial)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError) as error:
        raise SystemExit(f"Ferry publication blocked: {error}") from error
