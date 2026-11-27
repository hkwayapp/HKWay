"""Bounded read-only TD, GMB and LRTFeeder capture and private replay."""
from pathlib import Path
import json
import re
import shutil
import subprocess
import sys
import tempfile
import time

from run_live_nlb import Hold, MANIFEST_SHA, save, sha, swift, utc

SECTION_FARES_SHA = "cd724699609b9a83422067fd19c721ed6dcee8e524c3d4b14f47d65f75c5c94c"
TD = "https://static.data.gov.hk/td/routes-fares-xml/"
SOURCES = {
    "TD": ("Transport Department via DATA.GOV.HK",
           "https://data.gov.hk/en-data/dataset/hk-td-tis_14-routes-fares-xml",
           {name: TD + name for name in ("COMPANY_CODE.xml", "ROUTE_BUS.xml", "RSTOP_BUS.xml", "STOP_BUS.xml")}),
    "GMB": ("Transport Department via DATA.GOV.HK",
            "https://data.gov.hk/en-data/dataset/hk-td-tis_14-routes-fares-xml",
            {name: TD + name for name in ("ROUTE_GMB.xml", "RSTOP_GMB.xml", "STOP_GMB.xml")}),
    "LRTFeeder": ("MTR Corporation Limited via DATA.GOV.HK",
                  "https://data.gov.hk/en-data/dataset/mtr-data-routes-fares-barrier-free-facilities/resource/f49a3cfc-3537-4c9a-ac0f-637ca09afdb4",
                  {"mtr_bus_stops.csv": "https://opendata.mtr.com.hk/data/mtr_bus_stops.csv"}),
}


def fetch(url, path, kind):
    timeout, cap = (60, 64 * 1024 * 1024) if kind == "xml" else (20, 2 * 1024 * 1024)
    return subprocess.run([
        "/usr/bin/curl", "-q", "--silent", "--show-error", "--proto", "=https",
        "--connect-timeout", "8", "--max-time", str(timeout), "--max-filesize", str(cap),
        "--retry", "0", "--output", str(path), "--write-out", "%{http_code}", url,
    ], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout+5)


def archive(unit, destination, receipts, transport=fetch, pace=time.sleep):
    provider, source, files = SOURCES[unit]
    for name, url in files.items():
        if receipts:
            pace(2)
        entry = dict(url=url, startedAt=utc(), file=name)
        receipts.append(entry)
        target = destination / name
        kind = name.rsplit(".",1)[-1].lower()
        result = transport(url, target, kind)
        entry.update(http=result.stdout, completedAt=utc())
        if result.stdout in ("401", "403", "407", "429"):
            raise Hold(f"Provider access/rate restriction HTTP {result.stdout}")
        if result.returncode or result.stdout != "200":
            raise Hold("Acquisition stopped after an unsuccessful request")
        data = target.read_bytes()
        if not data or re.match(rb"\s*<(?:!doctype\s+html|html\b)", data[:512], re.I):
            raise Hold("Provider body missing or unexpected")
        entry["sha256"] = sha(data)
    # TD uses presence of responses.json to request optional HAD geography. Leave it absent.
    if unit != "TD":
        save(destination/"responses.json",
             {r["url"]: {"file": r["file"], "status": 200} for r in receipts})
    save(destination/"sources.json",
         [{"name": provider, "url": r["url"], "retrievedAt": r["completedAt"]} for r in receipts])
    save(destination/"acquisition-provenance.json", receipts)
    (destination/"ATTRIBUTION.txt").write_text(
        provider + "\n" + source + "\nhttps://data.gov.hk/en/terms-and-conditions\n"
        "Official response bytes are unmodified. Processed output remains private.\n")


def run(unit, binary, dataset, serving, section_fares, work, receipts, transport=fetch, pace=time.sleep):
    manifest_bytes = (serving/"hkway-transport-manifest.json").read_bytes()
    if sha(manifest_bytes) != MANIFEST_SHA:
        raise Hold("Serving manifest changed; re-approval required before requests")
    manifest = json.loads(manifest_bytes)
    td = manifest["datasets"]["SharedTD"]["sha256"]
    identity = f"td-2026.08.29-{td}"
    registry, raw, generated = [work / name for name in ("registry","raw","generated")]
    raw.mkdir(mode=0o700)
    baseline = swift(binary, "--offline-shard-baseline", dataset, registry)
    if baseline.returncode or f"TD baseline {identity}" not in baseline.stdout.splitlines():
        raise Hold("Verified serving TD baseline does not match the local legacy input")
    if unit == "TD":
        if sha(section_fares.read_bytes()) != SECTION_FARES_SHA:
            raise Hold("Existing section-fare input no longer matches the reviewed bytes")
        shutil.copyfile(section_fares, raw/"section_fares.json")
    archive(unit, raw, receipts, transport, pace)
    print("Acquisition: PASS")
    if unit == "TD":
        result = swift(binary, "--offline-generate-td", dataset, raw, generated)
    else:
        result = swift(binary, "--offline-generate-operator", registry, identity, unit, raw, generated)
    print("Private replay:", "PASS" if result.returncode == 0 else "HOLD")
    if not result.returncode and unit != "TD":
        expected = manifest["datasets"][unit]
        original = (serving/expected["path"]).read_bytes()
        if len(original) != expected["size"] or sha(original) != expected["sha256"]:
            raise Hold("Published operator payload hash mismatch")
        key = lambda row: (row["operatorId"],row["journeyId"],row["sequence"])
        old = {key(r):r for r in json.loads(original)}
        new = {key(r):r for r in json.loads((generated/"references.json").read_bytes())}
        common = old.keys() & new.keys()
        same = sum(old[k]==new[k] for k in common)
        print("Mapping comparison:",json.dumps(dict(unchanged=same,changed=len(common)-same,
              added=len(new.keys()-old.keys()),missing=len(old.keys()-new.keys())),sort_keys=True))
    if result.returncode:
        raise Hold("Strict existing replay gate held; previous data remains untouched")


def main():
    unit, binary, dataset, serving, section = sys.argv[1:]
    if unit not in SOURCES:
        raise SystemExit("Unsupported operator")
    receipts = []
    started = time.monotonic()
    try:
        with tempfile.TemporaryDirectory(prefix="hkway-operator-private-") as temp:
            run(unit,binary,Path(dataset),Path(serving),Path(section),Path(temp),receipts)
    except Exception as error:
        print("Validation held:", str(error) if isinstance(error,Hold) else type(error).__name__)
        return 1
    finally:
        counts = {}
        for row in receipts:
            status = row.get("http", "")
            status = status if re.fullmatch("[0-9]{3}",status) else "transport-failure"
            counts[status] = counts.get(status,0)+1
        print("Acquisition receipt:",json.dumps(dict(unit=unit, budget=len(SOURCES[unit][2]), attempted=len(receipts),
              statuses=counts, completedAt=utc(), elapsedSeconds=round(time.monotonic()-started,2),
              rawReceiptSHA256=sha(json.dumps(receipts,sort_keys=True).encode())),sort_keys=True))
        print("Source:",SOURCES[unit][0],SOURCES[unit][1])
        print("Publication: disabled")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
