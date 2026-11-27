"""Generate or validate a synthetic-only NLB hosted acceptance checkpoint."""
import argparse
import json
from pathlib import Path
import tempfile

from check_selective_deployment import MANIFEST, git_payloads, validate_manifest
from nlb_release_plan import canonical, digest, plan
from package_selective_snapshot import UNITS
from prepare_nlb_handoff import GENERATION_ONE


def checkpoint():
    entries, payloads = {}, {}
    shared = None
    for unit in UNITS:
        value = {"synthetic": True, "fixtureUnit": unit, "rows": []}
        raw = canonical(value)
        checksum = digest(raw)
        path = f"hkway-transport-{checksum}.json"
        entries[unit] = dict(path=path, size=len(raw), sha256=checksum,
                             revision=checksum, requires=shared)
        payloads[path] = value
        if unit == "SharedTD":
            shared = checksum
    return {"manifest": dict(schemaVersion=1, generation=1, datasets=entries),
            "payloads": payloads}


def accept(path, expected, repository, head):
    raw = path.read_bytes()
    if digest(raw) != expected or raw != canonical(checkpoint()):
        raise ValueError("Checkpoint is not the pinned synthetic fixture.")
    load = git_payloads(repository, head)
    serving = load(MANIFEST)
    if digest(serving) != GENERATION_ONE:
        raise ValueError("Serving Generation 1 manifest pin mismatch.")
    validate_manifest(serving, load)

    fixture = json.loads(raw)
    manifest = canonical(fixture["manifest"])
    with tempfile.TemporaryDirectory(prefix="nlb-synthetic-acceptance-") as directory:
        snapshot = Path(directory)
        (snapshot / MANIFEST).write_bytes(manifest)
        for name, value in fixture["payloads"].items():
            (snapshot / name).write_bytes(canonical(value))
        review = plan(snapshot, snapshot, digest(manifest), head)
        if review["disposition"] != "unchanged" or review["requiredPublicPayloads"]:
            raise ValueError("Synthetic no-op planned a release.")

    bad_entry = fixture["manifest"]["datasets"]["NLB"]["path"]
    for bad_bytes in (None, b"invalid"):
        def candidate_load(name):
            if name != bad_entry:
                return canonical(fixture["payloads"][name])
            if bad_bytes is None:
                raise FileNotFoundError(name)
            return bad_bytes
        try:
            validate_manifest(manifest, candidate_load)
        except (ValueError, FileNotFoundError):
            continue
        raise ValueError("Incomplete or corrupt synthetic candidate was accepted.")

    receipt = {
        "kind": "synthetic-read-only-acceptance",
        "checkpointSHA256": expected,
        "servingManifestSHA256": GENERATION_ONE,
        "baseCommit": head,
        "checks": ["serving-payload-integrity", "synthetic-no-op",
                   "missing-payload-rejected", "corrupt-payload-rejected"],
        "productionAuthorization": "disabled",
    }
    return canonical(receipt)


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    commands = cli.add_subparsers(dest="command", required=True)
    generate = commands.add_parser("generate")
    generate.add_argument("checkpoint", type=Path)
    verify = commands.add_parser("verify")
    verify.add_argument("checkpoint", type=Path)
    verify.add_argument("--sha256", required=True)
    verify.add_argument("--repository", required=True, type=Path)
    verify.add_argument("--head", required=True)
    verify.add_argument("--receipts", required=True, type=Path)
    args = cli.parse_args()
    if args.command == "generate":
        raw = canonical(checkpoint())
        with args.checkpoint.open("xb") as output:
            output.write(raw)
        print(digest(raw))
    else:
        receipt = accept(args.checkpoint, args.sha256, args.repository, args.head)
        digest_hex = digest(receipt)
        args.receipts.mkdir(parents=True, exist_ok=True)
        (args.receipts / f"{digest_hex}.json").write_bytes(receipt)
        print(f"Synthetic acceptance PASS; receipt SHA-256 {digest_hex}")


if __name__ == "__main__":
    main()
