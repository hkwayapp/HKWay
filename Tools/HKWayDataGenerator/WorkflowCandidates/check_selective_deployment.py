"""Validate a local selective payload package or an already-landed payload Git tree."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

from package_selective_snapshot import MANIFEST, UNITS


PREFIX = "TransportDatasetV1/"


def validate_manifest(raw, load):
    if len(raw) >= 64_000:
        raise ValueError("Oversized manifest")
    manifest = json.loads(raw)
    entries = manifest["datasets"]
    if (manifest["schemaVersion"] != 1 or type(manifest["generation"]) is not int
            or manifest["generation"] < 1 or set(entries) != set(UNITS)):
        raise ValueError("Unexpected selective manifest schema")
    shared = entries["SharedTD"]["sha256"]
    for unit, entry in entries.items():
        checksum = entry["sha256"]
        if (not re.fullmatch("[a-f0-9]{64}", checksum) or entry["revision"] != checksum
                or entry["requires"] != (None if unit == "SharedTD" else shared)
                or entry["path"] != f"hkway-transport-{checksum}.json"
                or type(entry["size"]) is not int or not 1 <= entry["size"] <= 95_000_000):
            raise ValueError(f"Invalid manifest entry: {unit}")
        data = load(entry["path"])
        if len(data) != entry["size"] or hashlib.sha256(data).hexdigest() != checksum:
            raise ValueError(f"Invalid payload: {unit}")
    return manifest


def transition(previous, candidate):
    if not previous:
        if candidate["generation"] != 1:
            raise ValueError("Initial generation must be 1")
        return True
    if previous["datasets"] == candidate["datasets"]:
        if candidate != previous:
            raise ValueError("Unchanged payloads cannot advance generation")
        return False
    if candidate["generation"] != previous["generation"] + 1:
        raise ValueError("Changed payloads must advance generation once")
    return True


def git_payloads(repository, sha):
    if not re.fullmatch("[a-f0-9]{40}", sha):
        raise ValueError("Use the verified full Git commit SHA")
    return lambda name: subprocess.check_output(["git", "-C", str(repository), "show", f"{sha}:{PREFIX}{name}"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--repository", type=Path)
    parser.add_argument("--commit")
    args = parser.parse_args()
    if bool(args.repository) != bool(args.commit):
        parser.error("--repository and --commit must be used together")
    load = (git_payloads(args.repository, args.commit) if args.commit
            else lambda name: (args.manifest.parent / name).read_bytes())
    manifest = validate_manifest(args.manifest.read_bytes(), load)
    print(f"Verified generation {manifest['generation']}, {len(manifest['datasets'])} immutable payload paths")


if __name__ == "__main__":
    main()
