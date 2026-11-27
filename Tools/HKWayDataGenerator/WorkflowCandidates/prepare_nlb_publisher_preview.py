"""Read-only NLB publication preflight against the exact public serving snapshot."""
import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
import tempfile

from check_selective_deployment import MANIFEST, git_payloads, validate_manifest
from prepare_nlb_handoff import GENERATION_ONE, pc, prepare, release


def preview(repository, head, binary, output):
    load = git_payloads(repository, head)
    raw = load(MANIFEST)
    if release.digest(raw) != GENERATION_ONE:
        raise pc.Hold("Serving Generation 1 changed. Review and re-pin before proceeding.")
    serving = validate_manifest(raw, load)
    metadata = pc.read(Path(__file__).with_name("nlb-generation-one-registry-metadata.json"))
    nlb = serving["datasets"]["NLB"]
    with tempfile.TemporaryDirectory(prefix="nlb-publisher-preflight-") as temp:
        registry = Path(temp)
        for name, value in metadata.items():
            path = registry / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(value.encode())
        selection = json.loads(metadata["registry.json"])
        nlb_path = registry / "operators" / "NLB" / selection["latest"]["NLB"]
        (nlb_path / "references.json").write_bytes(load(nlb["path"]))
        at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        key, disposition = prepare(repository, head, registry, binary,
                                   repository / "Dataset", at, output)
        if disposition != "unchanged":
            raise pc.Hold("Preflight must reproduce the byte-identical serving manifest.")
        print(f"Transport Publisher read-only preflight PASS; receipt SHA-256 {key}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repository", type=Path)
    parser.add_argument("head")
    parser.add_argument("binary", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    preview(**vars(args))


if __name__ == "__main__":
    main()
