"""Package the existing validated registry for the selective iOS updater. Offline only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile


UNITS = ("SharedTD", "KMB-LWB", "CTB", "NLB", "GMB", "LRTFeeder")
MANIFEST = "hkway-transport-manifest.json"


def read(path):
    return json.loads(path.read_bytes())


def digest(data):
    return hashlib.sha256(data).hexdigest()


def component(value):
    if not isinstance(value, str) or not re.fullmatch(r"[a-zA-Z0-9._-]{1,200}", value) or value in (".", ".."):
        raise ValueError("Invalid registry identity")
    return value


def package(binary, registry_root, destination, previous=None):
    registry = read(registry_root / "registry.json")
    baseline = registry["requiredBaseline"]
    identity = component(baseline["identity"])
    if set(registry["latest"]) != set(UNITS[1:]):
        raise ValueError("Expected five operator shards")
    subprocess.run([binary, "--offline-shard-verify", registry_root, identity], check=True)
    sources = {"SharedTD": registry_root / "baselines" / identity / "topology.json"}
    for unit in UNITS[1:]:
        revision = component(registry["latest"][unit])
        sources[unit] = registry_root / "operators" / unit / revision / "references.json"
    entries = {}
    payloads = {}
    for unit, path in sources.items():
        data = path.read_bytes()
        checksum = digest(data)
        if unit == "SharedTD" and checksum != baseline["sha256"]:
            raise ValueError("Shared baseline checksum mismatch")
        if unit != "SharedTD":
            shard = read(path.parent / "manifest.json")
            if shard["payloadSHA256"] != checksum or shard["requiredBaseline"] != baseline:
                raise ValueError(f"Incompatible or modified shard: {unit}")
        name = f"hkway-transport-{checksum}.json"
        entries[unit] = dict(revision=checksum, path=name, sha256=checksum, size=len(data),
                             requires=None if unit == "SharedTD" else baseline["sha256"])
        payloads[name] = data
    previous_manifest = read(previous) if previous is not None else None
    if previous_manifest is not None:
        if previous_manifest["schemaVersion"] != 1 or type(previous_manifest["generation"]) is not int:
            raise ValueError("Invalid previous selective manifest")
        generation = previous_manifest["generation"] + (previous_manifest["datasets"] != entries)
    else:
        generation = 1
    manifest = dict(schemaVersion=1, generation=generation, datasets=entries)
    if destination.exists():
        raise FileExistsError(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".selective-", dir=destination.parent) as tmp:
        stage = Path(tmp) / "snapshot"
        stage.mkdir()
        for name, data in payloads.items():
            (stage / name).write_bytes(data)
        (stage / MANIFEST).write_text(json.dumps(manifest, sort_keys=True, indent=2) + "\n")
        os.rename(stage, destination)
    print(f"Selective generation {generation}: " + ", ".join(f"{u}={e['size']}" for u, e in entries.items()))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path)
    parser.add_argument("registry", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--previous", type=Path)
    args = parser.parse_args()
    package(args.binary, args.registry, args.destination, args.previous)
