"""Offline NLB plan and durable receipt. Production writes remain disabled."""
import argparse
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import publication_controller as pc
from staging_handoff import Handoff, REF, canonical, digest
from check_selective_deployment import MANIFEST, transition, validate_manifest


def load_snapshot(directory):
    raw = (directory / MANIFEST).read_bytes()
    return raw, validate_manifest(raw, lambda name: (directory / name).read_bytes())


def plan(previous, candidate, expected_published_digest, main_commit):
    if not re.fullmatch("[a-f0-9]{40}", main_commit):
        raise pc.Hold("A verified production base commit is required.")
    previous_raw, old = load_snapshot(previous)
    if digest(previous_raw) != expected_published_digest:
        raise pc.Hold("Published manifest changed; revalidate against the current publication.")
    candidate_raw, new = load_snapshot(candidate)
    changed = {unit for unit in old["datasets"] if old["datasets"][unit] != new["datasets"][unit]}
    if changed - {"NLB"}:
        raise pc.Hold("NLB-only preview changed TD or a different operator.")
    has_update = transition(old, new)
    if not has_update and candidate_raw != previous_raw:
        raise pc.Hold("Unchanged content must use the exact published manifest bytes.")
    return {
        "schemaVersion": 1,
        "unit": "NLB",
        "baseCommit": main_commit,
        "baseManifestSHA256": expected_published_digest,
        "candidateManifestSHA256": digest(candidate_raw),
        "requiredTDSHA256": old["datasets"]["SharedTD"]["sha256"],
        "previousGeneration": old["generation"],
        "candidateGeneration": new["generation"],
        "disposition": "hold" if has_update else "unchanged",
        "requiredPublicPayloads": [new["datasets"]["NLB"]["path"]] if has_update else [],
        "productionAuthorization": "disabled",
        "blockers": (["NLB fare equivalence and service identity require evidence", *pc.BLOCKERS]
                     if has_update else []),
    }


def record(handoff, review, before_cas=lambda: None):
    if review.get("unit") != "NLB" or review.get("productionAuthorization") != "disabled":
        raise pc.Hold("Only NLB receipts with production authorization disabled are accepted.")
    key = digest(canonical(review))

    def write(state):
        active = pc.read(state / "lifecycle.json").get("active")
        if not active:
            raise pc.Hold("No active staging TD baseline.")
        dependency = pc.read(pc.source_root(state, active) / "registry.json")["requiredBaseline"]
        if dependency["sha256"] != review["requiredTDSHA256"]:
            raise pc.Hold("Active staging TD baseline changed; discard the publication plan.")
        target = state / "publication" / f"{key}.json"
        target.parent.mkdir(exist_ok=True)
        if target.exists():
            if pc.read(target) != review:
                raise pc.Hold("Existing publication receipt is not identical.")
        else:
            pc.atomic_json(target, review)
        return key

    return handoff.transaction(write, before_cas)


def recover(handoff, key):
    if not re.fullmatch("[a-f0-9]{64}", key):
        raise pc.Hold("Invalid receipt digest.")

    def read(state):
        value = pc.read(state / "publication" / f"{key}.json")
        if digest(canonical(value)) != key:
            raise pc.Hold("Publication receipt checksum mismatch.")
        return value

    return handoff.transaction(read, read_only=True)


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("mode", choices=("record", "recover"))
    cli.add_argument("local_receiver", type=Path)
    cli.add_argument("binary", type=Path)
    cli.add_argument("args", nargs="+")
    cli.add_argument("--authorize-local-staging", action="store_true")
    args = cli.parse_args()
    store = Handoff(args.local_receiver, args.binary, destination=REF, authorized=args.authorize_local_staging)
    if args.mode == "record" and len(args.args) == 4:
        previous, candidate, pin, base = args.args
        review = plan(Path(previous), Path(candidate), pin, base)
        print(record(store, review))
    elif args.mode == "recover" and len(args.args) == 1:
        print(canonical(recover(store, args.args[0])).decode())
    else:
        cli.error("record requires previous, candidate, manifest digest and base commit; recover requires receipt digest")


if __name__ == "__main__":
    main()
