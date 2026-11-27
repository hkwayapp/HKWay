"""One bounded NLB v2 capture and offline reconciliation. Output is aggregate-only."""
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

BASE = "https://rt.data.gov.hk/v2/transport/nlb/"
CATALOGUE = BASE + "route.php?action=list"
STOPS = BASE + "stop.php?action=list&routeId="
SCOPE = set("1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 29 30 33 34 35 36 37 38 40 44 45 63 75 78 80 82 86 87 88 89 90 91 92 93 95 96 100 101 102 108 109 111 113 114 115 116".split())
BUDGET = 61
ARCHIVED_FARES = {'fare': 'fd19aed63995597758b7651f118ecfe781e43bcafc65331894497c8162be078c', 'fareHoliday': '4011a74f8c56ae3d7785b94e4456860ae06ced19e130e1c887843d2cac5900c0'}
MANIFEST_SHA = "1c17e62dee3b307f8dddc5fd1402aef65b3e93f00ec78e0f6eb4c66874eb0601"


class Hold(Exception):
    pass


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read(path):
    return json.loads(path.read_bytes())


def save(path, value):
    path.write_text(json.dumps(value, sort_keys=True) + "\n")


def utc():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def index(rows, key):
    result = {key(r): r for r in rows}
    if len(result) != len(rows):
        raise Hold("Duplicate identity")
    return result


def swift(binary, *arguments):
    return subprocess.run([binary, *map(str, arguments)], stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, text=True, timeout=150)


def fetch(url, path):
    return subprocess.run(["/usr/bin/curl", "-q", "--silent", "--show-error", "--proto", "=https",
                           "--connect-timeout", "8", "--max-time", "20", "--max-filesize", "2097152",
                           "--retry", "0", "--output", str(path), "--write-out", "%{http_code}", url],
                          text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=25)


def cents(raw):
    try:
        amount = Decimal(str(raw))
        value = amount * 100
        if amount.is_finite() and amount >= 0 and value == value.to_integral_value():
            return int(value)
    except (InvalidOperation, ValueError):
        pass
    return None


def fare_coverage(rows, journeys, stop_data):
    variants = {}
    for row in rows:
        variants.setdefault(row["journeyId"], {})[row["sequence"]] = row
    report = {kind: dict(same=0, different=0, unavailable=0)
              for kind in ("ordinaryFull", "holidayFull", "ordinarySection", "holidaySection")}
    for journey in journeys:
        mapped = variants.get(journey["id"], {})
        fares = []
        if journey.get("adultFullFareCents") is not None:
            fares.append(("Full", 1, journey["adultFullFareCents"]))
        fares.extend(("Section", tier["boardingStopSequence"], tier["fareCents"])
                     for tier in journey.get("sectionFareTiers") or [])
        for kind, sequence, expected in fares:
            mapping = mapped.get(sequence)
            stop = None if mapping is None else stop_data.get(mapping["operatorServiceType"], {}).get(mapping["operatorStopId"])
            for label, field in (("ordinary", "fare"), ("holiday", "fareHoliday")):
                actual = None if stop is None else cents(stop.get(field))
                key = "unavailable" if actual is None else "same" if actual == expected else "different"
                report[label+kind][key] += 1
    return report


def run(binary, dataset, serving, work, receipts, transport=fetch, pace=time.sleep):
    manifest_raw = (serving/"hkway-transport-manifest.json").read_bytes()
    if sha(manifest_raw) != MANIFEST_SHA:
        raise Hold("Generation 1 manifest pin mismatch")
    manifest = json.loads(manifest_raw)
    if (manifest["schemaVersion"], manifest["generation"]) != (1, 1):
        raise Hold("Unexpected manifest generation")

    def asset(unit):
        entry = manifest["datasets"][unit]
        data = (serving/entry["path"]).read_bytes()
        if len(data) != entry["size"] or sha(data) != entry["sha256"]:
            raise Hold("Published payload integrity failed")
        return json.loads(data)

    shared, old = asset("SharedTD"), asset("NLB")
    td_sha = manifest["datasets"]["SharedTD"]["sha256"]
    if manifest["datasets"]["NLB"]["requires"] != td_sha or len(old) != 2139:
        raise Hold("Published NLB baseline mismatch")
    topology = shared["topology"]
    routes = [row for row in topology["routes"] if any("NLB" in item.split("+") for item in row["operatorIds"])]
    numbers = {r["number"].upper() for r in routes}
    route_ids = {row["id"] for row in routes}
    journeys = [row for row in topology["journeys"] if row["routeId"] in route_ids]
    registry, raw, generated = [work / name for name in ("registry", "raw", "generated")]
    raw.mkdir(mode=0o700)
    baseline = swift(binary, "--offline-shard-baseline", dataset, registry)
    expected_identity = f"td-2026.08.29-{td_sha}"
    if baseline.returncode or f"TD baseline {expected_identity}" not in baseline.stdout.splitlines():
        raise Hold("Checked-out legacy topology does not match published TD baseline")

    def get(url, name, field):
        if len(receipts) >= BUDGET or not (url == CATALOGUE or url in {STOPS+i for i in SCOPE}):
            raise Hold("NLB request scope exceeded")
        if receipts:
            pace(2)
        path = raw / name
        record = dict(url=url, startedAt=utc())
        receipts.append(record)
        result = transport(url, path)
        record.update(http=result.stdout, completedAt=utc())
        if result.stdout in ("401", "403", "407", "429"):
            raise Hold(f"Provider access/rate restriction HTTP {result.stdout}")
        if result.returncode or result.stdout != "200":
            raise Hold(f"Acquisition stopped at HTTP {result.stdout if re.fullmatch('[0-9]{3}', result.stdout) else 'unknown'}")
        record["sha256"] = sha(path.read_bytes())
        record["file"] = name
        value = read(path)
        if not isinstance(value.get(field), list) or not value[field]:
            raise Hold("Invalid/empty provider response")
        return value[field]

    catalogue = get(CATALOGUE, "route.json", "routes")
    candidates = [row for row in catalogue if row["routeNo"].upper() in numbers]
    all_ids = index(candidates, lambda row: str(row["routeId"]))
    if not set(all_ids) <= SCOPE or not {row["operatorServiceType"] for row in old} <= set(all_ids):
        raise Hold("Catalogue drift requires separate approval")
    if len(all_ids) != len(SCOPE):
        raise Hold("Approved catalogue coverage no longer matches")
    stop_data = {}
    fare_frames = {field: [] for field in ARCHIVED_FARES}
    day_prices = dict(comparable=0, different=0, nonNumericOrUnavailable=0)
    for route_id in sorted(all_ids, key=int):
        rows = get(STOPS+route_id, f"stop-{route_id}.json", "stops")
        for sequence, row in enumerate(rows, 1):
            for field, frame in fare_frames.items():
                frame.append([route_id, sequence, str(row["stopId"]), row.get(field)])
            ordinary, holiday = cents(row.get("fare")), cents(row.get("fareHoliday"))
            if ordinary is None or holiday is None:
                day_prices["nonNumericOrUnavailable"] += 1
            else:
                day_prices["comparable"] += 1
                day_prices["different"] += ordinary != holiday
        # Repeated stop IDs can be legitimate; a single identity cannot establish which fare applies.
        counts = {str(row["stopId"]):None for row in rows}
        for row in rows:
            identifier = str(row["stopId"])
            counts[identifier] = row if counts[identifier] is None else False
        stop_data[route_id] = {k:v for k,v in counts.items() if v}
    responses = {e["url"]:dict(file=e["file"],status=200) for e in receipts}
    publisher = "New Lantao Bus Company (1973) Limited via DATA.GOV.HK (Government of the Hong Kong SAR)"
    save(raw/"responses.json", responses)
    save(raw/"sources.json", [dict(name=publisher, url=row["url"], retrievedAt=row["completedAt"]) for row in receipts])
    save(raw/"acquisition-provenance.json", receipts)
    (raw/"ATTRIBUTION.txt").write_text(publisher+"; NLB owns dataset IP. Original responses are unmodified.\n"
        "https://data.gov.hk/en-data/dataset/nlb-bus-nlb-bus-service-v2\n"
        "https://data.gov.hk/en/terms-and-conditions\n")

    result = swift(binary, "--offline-generate-operator", registry, expected_identity, "NLB", raw, generated)
    observation = raw/"nlb-observed.json"
    if not observation.is_file() or "IncompleteSources" in result.stdout:
        raise Hold("Offline replay did not yield a complete acquisition diagnostic")
    captured = read(observation)
    new = captured["references"]
    key = lambda row:(row["journeyId"], row["sequence"])
    a,b = index(old,key),index(new,key)
    common = set(a)&set(b)
    unchanged = sum(a[k]==b[k] for k in common)
    ambiguous = set(captured["ambiguousJourneys"])
    print("Mappings:", json.dumps(dict(unchanged=unchanged, changed=len(common)-unchanged, added=len(b.keys()-a.keys()),
          missing=len(a.keys()-b.keys()), ambiguousJourneys=len(ambiguous),
          priorPositionsOnAmbiguousJourneys=sum(k[0] in ambiguous for k in a),
          ambiguousJourneyIDs=sorted(ambiguous)),sort_keys=True))
    print("Fare comparisons (boarding position; adult legacy amounts compared separately to each day type):",
          json.dumps(fare_coverage(new,journeys,stop_data),sort_keys=True))
    digests = {field: sha(json.dumps(frame, separators=(",", ":"), ensure_ascii=True).encode())
               for field, frame in fare_frames.items()}
    print("Provider fare audit:", json.dumps(dict(
        orderedFieldMatchesNov26Archive={field: digests[field] == digest
                                        for field, digest in ARCHIVED_FARES.items()},
        dayTypePrices=day_prices, rowsCompared=len(fare_frames["fare"])), sort_keys=True))
    route_numbers = {row["id"]: row["number"] for row in routes}
    print("Ambiguity scope:", json.dumps([
        {"canonicalJourney": row["id"], "routeNumber": route_numbers[row["routeId"]],
         "catalogueCandidates": sum(x["routeNo"].upper() == route_numbers[row["routeId"]].upper()
                                    for x in candidates)}
        for row in journeys if row["id"] in ambiguous], sort_keys=True))
    print("Strict mapping validation:", "PASS" if result.returncode == 0 else "HOLD")
    print("Publication: HOLD; fare-rule and service-identity evidence required; no release candidate exported")
    if result.returncode:
        raise Hold("Strict mapping validation held")


def main():
    binary, dataset, serving = sys.argv[1:]
    receipts = []
    start = time.monotonic()
    try:
        with tempfile.TemporaryDirectory(prefix="hkway-nlb-live-") as tmp:
            run(binary,Path(dataset),Path(serving),Path(tmp),receipts)
    except Exception as error:
        print("Acquisition/validation hold:", str(error) if isinstance(error,Hold) else type(error).__name__)
        return 1
    finally:
        statuses = {}
        for record in receipts:
            status = record.get("http","transport-failure")
            status = status if re.fullmatch("[0-9]{3}",status) else "transport-failure"
            statuses[status] = statuses.get(status,0)+1
        print("NLB receipt:",json.dumps(dict(attempted=len(receipts), budget=BUDGET, statuses=statuses,
            elapsedSeconds=round(time.monotonic()-start,2), completedAt=utc(),
            rawReceiptSHA256=sha(json.dumps(receipts,sort_keys=True).encode())),sort_keys=True))
        print("Source: New Lantao Bus Company (1973) Limited via DATA.GOV.HK, Government of the Hong Kong SAR.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
