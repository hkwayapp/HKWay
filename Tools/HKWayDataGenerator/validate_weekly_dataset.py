"""Validate a staged snapshot before the weekly workflow can publish it."""

import json
import re
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path


TABLES = {
    "operators": ("id",),
    "routes": ("id", "operatorIds"),
    "journeys": ("id", "routeId"),
    "journey_stops": ("journeyId", "stopId", "sequence"),
    "stops": ("id",),
    "schedules": (),
    "operator_stop_references": ("operatorId", "journeyId", "stopId", "sequence"),
}


def read(directory, name):
    with (directory / f"{name}.json").open(encoding="utf-8") as file:
        return json.load(file)


def check_floor(name, previous, current):
    # A large reduction may be legitimate, but requires review before publication.
    if current * 100 < previous * 95:
        raise ValueError(f"{name}: suspicious drop from {previous} to {current}")


def validate(baseline, staged):
    tables = {}
    for name, keys in TABLES.items():
        previous, current = read(baseline, name), read(staged, name)
        if not isinstance(previous, list) or not isinstance(current, list):
            raise ValueError(f"{name}: expected a JSON array")
        # The generator intentionally exports no schedules today.
        if name != "schedules" and not current:
            raise ValueError(f"{name}: required dataset is empty")
        if any(not isinstance(row, dict) or not row.keys() >= set(keys) for row in current):
            raise ValueError(f"{name}: invalid record structure")
        check_floor(name, len(previous), len(current))
        tables[name] = current
        print(f"{name}: {len(previous)} -> {len(current)}")

    old_refs = Counter(row["operatorId"] for row in read(baseline, "operator_stop_references"))
    new_refs = Counter(row["operatorId"] for row in tables["operator_stop_references"])
    for operator, previous in old_refs.items():
        check_floor(f"{operator} stop references", previous, new_refs[operator])

    route_ids = {row["id"] for row in tables["routes"]}
    journey_ids = {row["id"] for row in tables["journeys"]}
    stop_ids = {row["id"] for row in tables["stops"]}
    if any(row["routeId"] not in route_ids for row in tables["journeys"]):
        raise ValueError("journeys: unresolved route")
    for name in ("journey_stops", "operator_stop_references"):
        if any(row["journeyId"] not in journey_ids or row["stopId"] not in stop_ids
               for row in tables[name]):
            raise ValueError(f"{name}: unresolved journey or stop")

    manifest = read(staged, "dataset_info")
    previous_manifest = read(baseline, "dataset_info")
    expected_keys = {"version", "generatedAt"}
    if "fareDataUpdatedAt" in previous_manifest:
        expected_keys.add("fareDataUpdatedAt")
    if not isinstance(manifest, dict) or manifest.keys() != expected_keys:
        raise ValueError("dataset_info: incompatible manifest keys")
    if manifest.get("fareDataUpdatedAt") != previous_manifest.get("fareDataUpdatedAt"):
        raise ValueError("dataset_info: fareDataUpdatedAt must be preserved")
    if not re.fullmatch(r"\d{4}\.\d{2}\.\d{2}", manifest["version"]):
        raise ValueError("dataset_info: incompatible version format")
    generated = datetime.fromisoformat(manifest["generatedAt"].replace("Z", "+00:00"))
    if generated.tzinfo is None or generated.strftime("%Y.%m.%d") != manifest["version"]:
        raise ValueError("dataset_info: inconsistent generation timestamp")


if __name__ == "__main__":
    try:
        validate(Path(sys.argv[1]), Path(sys.argv[2]))
    except (OSError, ValueError, TypeError, KeyError) as error:
        sys.exit(f"Publication blocked: {error}")
