"""File-only CTB cache handoff. No acquisition or shard writes."""
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import tempfile

import publication_controller as pc

ID = re.compile(r"[0-9]+")
HASH = re.compile(r"[0-9a-f]{64}")


def timestamp(value):
    if not isinstance(value, str):
        raise pc.Hold("Invalid CTB cache timestamp.")
    try:
        date = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise pc.Hold("Invalid CTB cache timestamp.") from error
    if date.utcoffset() is None:
        raise pc.Hold("CTB cache timestamps require a timezone.")
    return date


def verified_object(cache, checksum):
    if not isinstance(checksum, str) or not HASH.fullmatch(checksum):
        raise pc.Hold("Invalid CTB cache object identity.")
    path = cache / "objects" / (checksum + ".json")
    if not path.is_file() or path.is_symlink():
        raise pc.Hold("Missing CTB cache object.")
    content = path.read_bytes()
    if hashlib.sha256(content).hexdigest() != checksum:
        raise pc.Hold("Corrupted CTB cache object.")
    return content


def read_manifest(cache):
    path = cache / "manifest.json"
    if not path.exists() and not path.is_symlink():
        if cache.exists():
            raise pc.Hold("CTB cache exists without a manifest.")
        return {"version": 1, "operator": "CTB", "topology": None, "topologyObservedAt": None, "entries": {}}
    if path.is_symlink() or cache.is_symlink() or (cache / "objects").is_symlink():
        raise pc.Hold("Invalid CTB cache path.")
    try:
        m = pc.read(path)
    except (ValueError, OSError) as error:
        raise pc.Hold("Corrupted CTB cache manifest.") from error
    if (not isinstance(m, dict) or set(m) != {"version", "operator", "topology", "topologyObservedAt", "entries"}
            or type(m["version"]) is not int or m["version"] != 1 or m["operator"] != "CTB"
            or not isinstance(m["entries"], dict) or not isinstance(m["topology"], str)
            or any(not ID.fullmatch(key) for key in m["entries"])):
        raise pc.Hold("Invalid CTB cache manifest.")
    timestamp(m["topologyObservedAt"])
    return m


def store_object(cache, content):
    checksum = hashlib.sha256(content).hexdigest()
    path = cache / "objects" / (checksum + ".json")
    if path.exists() or path.is_symlink():
        verified_object(cache, checksum)
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    return checksum


def stop_timestamp(content, stop_id):
    try:
        row = json.loads(content)
        if row["stopID"] != stop_id or row["operatorID"] != "CTB":
            raise pc.Hold("CTB cache stop identity mismatch.")
        return timestamp(row["originalRetrievalTimestamp"])
    except (TypeError, KeyError, ValueError) as error:
        raise pc.Hold("Invalid archived CTB cache entry.") from error


def update_cache(state, binary, archive, as_of, *, stage):
    clock = timestamp(as_of)
    cache = state / "ctb-cache"
    with stage("cache_manifest", manifest=cache / "manifest.json"):
        previous = read_manifest(cache)
    topology = previous["topology"]
    observed = previous["topologyObservedAt"]
    entries = dict(previous["entries"])
    updated = 0
    with tempfile.TemporaryDirectory(prefix="hkway-ctb-cache-") as tmp:
        root = Path(tmp)
        restored = root / "restored"
        with stage("cache_restoration", manifest=cache / "manifest.json", restored=restored):
            restored.mkdir()
            if topology is not None:
                if timestamp(observed) > clock:
                    raise pc.Hold("Staged CTB topology is newer than the runner clock.")
                (restored / "topology.json").write_bytes(verified_object(cache, topology))
            for stop_id, checksum in entries.items():
                body = verified_object(cache, checksum)
                stop_timestamp(body, stop_id)
                (restored / f"stop-{stop_id}.json").write_bytes(body)

        incoming = root / "incoming"
        plan_file = root / "plan.json"
        with stage("cache_validation", archive=archive, plan=plan_file):
            pc.call(binary, "--offline-bootstrap-ctb-cache", archive, incoming, as_of)
            pc.call(binary, "--offline-plan-ctb-cache", archive, restored, incoming, as_of, plan_file)
            plan = pc.read(plan_file)
            topology_bytes = (incoming / "topology.json").read_bytes()
            incoming_topology = json.dumps(json.loads(topology_bytes), sort_keys=True, separators=(",", ":")).encode()
            candidate_checksum = hashlib.sha256(incoming_topology).hexdigest()
            observations = pc.read(archive / "route-stop-journal.json")
            newest = max((row["retrievedAt"] for row in observations), key=timestamp)
            if timestamp(newest) > clock:
                raise pc.Hold("CTB topology observation is newer than the runner clock.")
            if observed is not None and timestamp(newest) <= timestamp(observed) and candidate_checksum != topology:
                raise pc.Hold("Stale or conflicting CTB topology observation.")

        unresolved = []
        unavailable = []
        pendingTopology = False
        for stop_id, reasons in plan.items():
            candidate = incoming / f"stop-{stop_id}.json"
            if not candidate.exists():
                unavailable.append(stop_id)
                pendingTopology |= "topologyChanged" in reasons
                if any(reason in ("missing", "expired", "invalid") for reason in reasons):
                    unresolved.append(stop_id)
                continue
            data = candidate.read_bytes()
            received = stop_timestamp(data, stop_id)
            existing = entries.get(stop_id)
            if existing is not None:
                old = verified_object(cache, existing)
                old_time = stop_timestamp(old, stop_id)
                if received == old_time and json.loads(old) != json.loads(data):
                    raise pc.Hold("Conflicting CTB stop responses at the same retrieval time.")
                if received <= old_time:
                    pendingTopology |= "topologyChanged" in reasons
                    if any(reason in ("missing", "expired", "invalid") for reason in reasons):
                        unresolved.append(stop_id)
                    continue
            entries[stop_id] = store_object(cache, data)
            updated += 1

        if observed is None or (timestamp(newest) > timestamp(observed) and not pendingTopology):
            topology = store_object(cache, incoming_topology)
            observed = newest
        manifest = dict(previous, topology=topology, topologyObservedAt=observed, entries=entries)
        if manifest != previous:
            pc.atomic_json(cache / "manifest.json", manifest)
    return {"plannedGET": len(plan), "restored": len(previous["entries"]), "updated": updated,
            "entries": len(entries), "refresh": plan, "unavailable": sorted(unavailable),
            "unresolved": sorted(unresolved), "liveAcquisition": "disabled", "actualGET": 0}
