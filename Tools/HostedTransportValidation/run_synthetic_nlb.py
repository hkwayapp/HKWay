"""Exercise the existing NLB archive decoder, matcher and shard validator with invented data."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

PUBLISHED_SHA = "1c17e62dee3b307f8dddc5fd1402aef65b3e93f00ec78e0f6eb4c66874eb0601"
UNITS = {"SharedTD", "KMB-LWB", "CTB", "NLB", "GMB", "LRTFeeder"}
binary, fixture, expected, public = sys.argv[1:]
data = Path(fixture).read_bytes()
if hashlib.sha256(data).hexdigest() != expected:
    raise SystemExit("Unexpected synthetic fixture digest")
sample = json.loads(data)
if sample["fixture"] != "synthetic-only" or len(sample["stops"]) != 2:
    raise SystemExit("Expected two invented stops")
published = Path(public).read_bytes()
if hashlib.sha256(published).hexdigest() != PUBLISHED_SHA:
    raise SystemExit("Published generation 1 manifest bytes changed")
manifest = json.loads(published)
entries = manifest["datasets"]
if manifest["schemaVersion"] != 1 or manifest["generation"] != 1 or set(entries) != UNITS:
    raise SystemExit("Unexpected published manifest schema")
for unit, entry in entries.items():
    digest = entry["sha256"]
    if (entry["revision"] != digest or entry["path"] != f"hkway-transport-{digest}.json"
            or entry["requires"] != (None if unit == "SharedTD" else entries["SharedTD"]["sha256"])):
        raise SystemExit("Invalid published TD dependency")

with tempfile.TemporaryDirectory(prefix="hkway-synthetic-") as temp:
    root = Path(temp)
    baseline, raw, registry, generated = [root / n for n in ("baseline", "raw", "registry", "generated")]
    baseline.mkdir()
    raw.mkdir()

    def write(directory, name, value):
        (directory / (name + ".json")).write_text(json.dumps(value, sort_keys=True) + "\n")

    def command(*args):
        result = subprocess.run([binary, *args], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if result.returncode:
            raise SystemExit(result.stdout)
        return result.stdout

    stops = sample["stops"]
    names = ("English", "Traditional", "Simplified")
    operators = ["NLB", "GMB", "LRTFeeder"]
    write(baseline, "operators", [dict(id=op, transportTypes=["bus"],
                                      **{"name"+lang: "Imaginary "+op for lang in names}) for op in operators])
    write(baseline, "routes", [dict(id="fiction-route", number=sample["routeNumber"], operatorIds=operators,
                                   **{"origin"+lang: stops[0]["name"] for lang in names},
                                   **{"destination"+lang: stops[1]["name"] for lang in names})])
    write(baseline, "journeys", [dict(id="fiction-journey", routeId="fiction-route",
                                     originStopId=stops[0]["id"], destinationStopId=stops[1]["id"],
                                     direction="1", serviceType="R", adultFullFareCents=100)])
    write(baseline, "stops", [dict(id=s["id"], latitude=s["lat"], longitude=s["lon"],
                                   **{"name"+lang:s["name"] for lang in names}) for s in stops])
    write(baseline, "journey_stops", [dict(journeyId="fiction-journey", sequence=i, stopId=s["id"])
                                   for i,s in enumerate(stops,1)])
    expected_rows = [dict(operatorId="NLB", journeyId="fiction-journey", stopId=s["id"], sequence=i,
                          operatorStopId="api-"+s["id"], operatorServiceType=sample["routeId"],
                          operatorDirection="1") for i,s in enumerate(stops,1)]
    write(baseline, "operator_stop_references", expected_rows + [
        dict(expected_rows[0], operatorId=op, operatorStopId="fiction-"+op)
        for op in operators[1:]
    ])
    write(baseline, "schedules", [])
    write(baseline, "journey_shapes", [dict(journeyId="fiction-journey",
          coordinates=[[s["lat"],s["lon"]] for s in stops])])
    write(baseline, "dataset_info", dict(version="2000.01.01", generatedAt="2000-01-01T00:00:00Z",
                                        fareDataUpdatedAt="2000-01-01T00:00:00Z"))
    write(raw, "sources", [dict(name="Entirely synthetic NLB protocol fixture")])
    write(raw, "route", dict(routes=[dict(routeId=sample["routeId"], routeNo=sample["routeNumber"],
                              overnightRoute=0, specialRoute=0,
                              **{"routeName_"+lang: "Imaginary Gate to Imaginary Terminus" for lang in "cse"})]))
    write(raw, "stop", dict(stops=[dict(stopId="api-"+s["id"], latitude=str(s["lat"]), longitude=str(s["lon"]),
                             **{"stopName_"+lang:s["name"] for lang in "cse"},
                             **{"stopLocation_"+lang:"" for lang in "cse"}) for s in stops]))
    prefix = "https://rt.data.gov.hk/v2/transport/nlb/"
    write(raw, "responses", {
        prefix+"route.php?action=list": dict(file="route.json", status=200),
        prefix+"stop.php?action=list&routeId="+sample["routeId"]: dict(file="stop.json", status=200),
    })
    output = command("--offline-shard-baseline", baseline, registry, raw/"sources.json")
    identity = next(row.split()[-1] for row in output.splitlines() if row.startswith("TD baseline "))
    print(command("--offline-generate-operator", registry, identity, "NLB", raw, generated), end="")
    confirmed = json.loads((generated/"references.json").read_bytes())
    if confirmed != expected_rows:
        raise SystemExit("Unexpected synthetic mappings")
    print(command("--offline-shard-register", registry, identity, "NLB",
                  generated/"references.json", raw/"sources.json"), end="")
    command("--offline-shard-verify", registry, identity)
print("PASS: two synthetic NLB mappings, independent shard validation, and read-only generation 1 manifest check")
