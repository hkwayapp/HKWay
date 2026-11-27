"""Prepare an NLB-only review receipt from a local checkout. No network or writes to Git."""
import argparse
import json
from pathlib import Path
import tempfile
import shutil

import nlb_release_plan as release
from check_selective_deployment import MANIFEST, git_payloads, validate_manifest
from package_selective_snapshot import UNITS, component, package

pc = release.pc
GENERATION_ONE = "1c17e62dee3b307f8dddc5fd1402aef65b3e93f00ec78e0f6eb4c66874eb0601"
ATTRIBUTION = {
    "source": "https://data.gov.hk/en-data/dataset/nlb-bus-nlb-bus-service-v2",
    "terms": "https://data.gov.hk/en/terms-and-conditions",
    "portal": "DATA.GOV.HK, Government of the Hong Kong Special Administrative Region",
    "rightsHolder": "New Lantao Bus Company (1973) Limited",
    "modification": "HK Way aligned NLB route identities and ordered stops to canonical TD journeys.",
}


def hydrate_registry(metadata, destination, previous, entries):
    selection = pc.read(metadata / "registry.json")
    if set(selection["latest"]) != set(UNITS[1:]):
        raise pc.Hold("Expected metadata for all five selected operator shards.")
    baseline = component(selection["requiredBaseline"]["identity"])
    if selection["requiredBaseline"]["sha256"] != entries["SharedTD"]["sha256"]:
        raise pc.Hold("Registry metadata does not identify the pinned Shared TD.")
    baseline_path = Path("baselines") / baseline
    shards = {unit: Path("operators") / unit / component(revision)
              for unit, revision in selection["latest"].items()}
    destination.mkdir()
    shutil.copyfile(metadata / "registry.json", destination / "registry.json")
    for unit, path in {"SharedTD": baseline_path, **shards}.items():
        target = destination / path
        target.mkdir(parents=True)
        shutil.copyfile(metadata / path / "manifest.json", target / "manifest.json")
        payload = "topology.json" if unit == "SharedTD" else "references.json"
        if unit == "NLB":
            source = metadata / path / payload
        else:
            source = previous / entries[unit]["path"]
        shutil.copyfile(source, target / payload)
    return shards["NLB"]

def prepare(repository, head, registry, binary, verified_legacy, as_of, output):
    load = git_payloads(repository, head)
    raw = load(MANIFEST)
    if release.digest(raw) != GENERATION_ONE:
        raise pc.Hold("Serving manifest does not match the reviewed Generation 1 pin.")
    baseline = validate_manifest(raw, load)
    if baseline["generation"] != 1:
        raise pc.Hold("Expected the reviewed initial generation.")
    expected_legacy = pc.read(Path(__file__).with_name("nlb-verified-legacy-sha256.json"))
    if any(release.digest((verified_legacy / name).read_bytes()) != checksum
           for name, checksum in expected_legacy.items()):
        raise pc.Hold("Legacy inputs do not match the verified production baseline.")
    with tempfile.TemporaryDirectory(prefix="hkway-nlb-preview-") as scratch:
        work = Path(scratch)
        previous = work / "previous"
        previous.mkdir()
        (previous / MANIFEST).write_bytes(raw)
        for entry in baseline["datasets"].values():
            (previous / entry["path"]).write_bytes(load(entry["path"]))

        hydrated = work / "registry"
        nlb_path = hydrate_registry(registry, hydrated, previous, baseline["datasets"])
        candidate = work / "candidate"
        package(binary, hydrated, candidate, previous / MANIFEST)
        review = release.plan(previous, candidate, GENERATION_ONE, head)
        composed = work / "legacy"
        pc.call(binary, "--offline-compose-legacy", verified_legacy, hydrated,
                pc.identity(hydrated), composed, as_of, verified_legacy)
        hashes = {name + ".json": release.digest((composed / (name + ".json")).read_bytes())
                  for name in pc.FILES}
        nlb = pc.read(candidate / MANIFEST)["datasets"]["NLB"]
        notice = {**ATTRIBUTION, "payloadSHA256": nlb["sha256"],
                  "sourceProvenance": pc.read(hydrated / nlb_path / "manifest.json")["sources"]}
        receipt = {
            "review": review,
            "legacyDryRunSHA256": hashes,
            "attribution": notice,
            "attributionSHA256": release.digest(release.canonical(notice)),
            "candidatePayloadSHA256": nlb["sha256"],
            "servingEntries": baseline["datasets"],
            "manifestCAS": {
                "expectedMainBeforePayload": head,
                "expectedManifestSHA256": GENERATION_ONE,
                "nextManifestSHA256": review["candidateManifestSHA256"],
                "verifyPublicPayloadBeforeManifest": bool(review["requiredPublicPayloads"]),
                "repinMainAfterPayload": bool(review["requiredPublicPayloads"]),
            },
        }
        key = release.digest(json.dumps(receipt, sort_keys=True).encode())
        output.mkdir(parents=True, exist_ok=True)
        pc.atomic_json(output / f"{key}.json", receipt)
        return key, review["disposition"]


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    for name in ("repository", "registry", "binary", "verified_legacy", "output"):
        cli.add_argument(f"--{name.replace('_', '-')}", required=True, type=Path)
    cli.add_argument("--head", required=True)
    cli.add_argument("--as-of", required=True)
    args = cli.parse_args()
    key, disposition = prepare(**vars(args))
    print(f"NLB validation: {disposition}; receipt SHA-256 {key}; publication disabled")


if __name__ == "__main__":
    main()
