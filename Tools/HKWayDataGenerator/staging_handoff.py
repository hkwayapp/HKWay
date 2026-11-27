"""Persistent offline staging on a local Git ref. No push or network transport."""
import argparse
from contextlib import contextmanager, nullcontext
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

import publication_controller as pc
from staging_ctb_cache import update_cache
from staging_write_scope import REF, require_write, verify_commit, verify_index, verify_parent
GIT_ENV = {**os.environ, "GIT_ALLOW_PROTOCOL": "file",
           "GIT_AUTHOR_NAME": "HK Way staging simulation", "GIT_COMMITTER_NAME": "HK Way staging simulation",
           "GIT_AUTHOR_EMAIL": "staging@example.invalid", "GIT_COMMITTER_EMAIL": "staging@example.invalid"}


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode()


def digest(data):
    return hashlib.sha256(data).hexdigest()


class Handoff:
    def __init__(self, repository, binary, *, destination=None, authorized=False):
        self.repository = Path(repository).resolve()
        self.binary = Path(binary).resolve()
        self.destination = destination
        self.authorized = authorized
        if not self.repository.is_relative_to(Path(tempfile.gettempdir()).resolve()) and not self.repository.is_relative_to(Path("/tmp").resolve()):
            raise pc.Hold("The staging repository must be in temporary storage.")
        if self.git(self.repository, "rev-parse", "--is-bare-repository") != b"true\n" or self.git(self.repository, "remote").strip():
            raise pc.Hold("Use a temporary bare repository without remotes.")

    @staticmethod
    def git(repo, *args):
        # These repositories have a bounded lifetime. Git must not launch
        # detached maintenance that can outlive the foreground subprocess.
        return pc.call("git", "-c", "maintenance.auto=false", "-c", "gc.auto=0",
                       "-C", repo, *args, env=GIT_ENV)

    @staticmethod
    @contextmanager
    def runner_directory(stage):
        directory = tempfile.TemporaryDirectory(prefix="hkway-runner-")
        try:
            yield Path(directory.name) / "repo"
        finally:
            with stage("git_runner_cleanup", directory=directory.name):
                directory.cleanup()

    def bootstrap(self):
        require_write(self.destination, self.authorized)
        with tempfile.TemporaryDirectory(prefix="hkway-bootstrap-") as tmp:
            seed = Path(tmp)
            self.git(seed, "init", "-q", "-b", "dataset-v3-staging")
            (seed / "state").mkdir()
            (seed / "state" / ".keep").touch()
            self.git(seed, "add", "--all")
            verify_index(self.git, seed)
            self.git(seed, "commit", "-qm", "Initialize offline staging")
            commit = self.git(seed, "rev-parse", "HEAD").decode().strip()
            verify_parent(self.git, seed, commit, None)
            verify_commit(self.git, seed, commit)
            self.git(self.repository, "fetch", "--no-tags", "--no-write-fetch-head", seed.as_uri(), commit)
        self.git(self.repository, "update-ref", REF, commit, "0" * len(commit))
        return commit

    def transaction(self, mutate, before_cas=lambda: None, *, read_only=False, stage=None):
        if not read_only:
            require_write(self.destination, self.authorized)
        stage = stage or (lambda *args, **kwargs: nullcontext())
        for _ in range(3):
            old = self.git(self.repository, "rev-parse", REF).decode().strip()
            with self.runner_directory(stage) as runner:
                self.git(self.repository, "clone", "--quiet", "--single-branch", "--branch", "dataset-v3-staging",
                         self.repository.as_uri(), runner)
                if self.git(runner, "rev-parse", "HEAD").decode().strip() != old:
                    continue
                result = mutate(runner / "state")
                self.git(runner, "add", "--all")
                verify_index(self.git, runner)
                if not self.git(runner, "diff", "--cached", "--name-only").strip():
                    if self.git(self.repository, "rev-parse", REF).decode().strip() == old:
                        return result
                    continue
                if read_only:
                    raise pc.Hold("A read-only operation attempted to modify staging.")
                self.git(runner, "commit", "-qm", "Stage offline dataset handoff")
                new = self.git(runner, "rev-parse", "HEAD").decode().strip()
                verify_parent(self.git, runner, new, old)
                verify_commit(self.git, runner, new)
                # Transfer objects while the clone exists, without changing the receiver ref.
                self.git(self.repository, "fetch", "--no-tags", "--no-write-fetch-head", runner.as_uri(), new)

            # No owned clone remains to clean up after publishing the local ref.
            before_cas()
            try:
                with stage("git_ref_compare_and_swap", previous=old, commit=new, repository=self.repository):
                    self.git(self.repository, "update-ref", REF, new, old)
            except subprocess.CalledProcessError:
                if self.git(self.repository, "rev-parse", REF).decode().strip() == old:
                    raise
                continue
            return result
        raise pc.Hold("Staging HEAD kept moving; retry the same update identity.")

    def nominate(self, production, provenance=None):
        return self.transaction(lambda state: pc.nominate(self.binary, production, state, provenance))

    def promote(self, baseline):
        return self.transaction(lambda state: pc.promote(self.binary, state, baseline))

    def status(self):
        def inspect(state):
            lifecycle = state / "lifecycle.json"
            journal = self.journal(state)
            return {"lifecycle": pc.read(lifecycle) if lifecycle.exists() else None,
                    "pending": sorted(key for key, entry in journal["updates"].items() if entry["status"] == "pending"),
                    "terminalCounts": {status: sum(entry["status"] == status for entry in journal["updates"].values())
                                       for status in ("validated", "unchanged", "failed", "stale")},
                    "recordedAcquisitionFailures": len(journal.get("failures", {}))}
        return self.transaction(inspect, read_only=True)

    def unit_state(self, baseline, unit):
        if unit not in pc.UNITS:
            raise pc.Hold("Unsupported operator unit.")

        def inspect(state):
            registry = pc.source_root(state, baseline)
            journal = self.journal(state)
            if not registry.is_dir() or self.actual_selection(registry) != self.registry_selection(journal, baseline):
                raise pc.Hold("Unknown baseline or registry recovery required.")
            return {"previous": self.selected(registry, unit),
                    "pending": sorted(key for key, item in journal["updates"].items()
                                      if item["baseline"] == baseline and item["unit"] == unit and item["status"] == "pending")}
        return self.transaction(inspect, read_only=True)

    def refresh_ctb_cache(self, archive, as_of, before_cas=lambda: None, *, stage=None):
        archive = Path(archive).resolve()
        stage = stage or (lambda *args, **kwargs: nullcontext())
        with stage("cache_persistence", repository=self.repository, destination=self.destination):
            return self.transaction(lambda state: update_cache(state, self.binary, archive, as_of, stage=stage),
                                    before_cas, stage=stage)

    def generate_operator(self, baseline, unit, raw):
        if unit not in pc.UNITS:
            raise pc.Hold("Unsupported operator unit.")

        def generate(state):
            registry = pc.source_root(state, baseline)
            with tempfile.TemporaryDirectory(prefix="hkway-generated-") as tmp:
                output = Path(tmp) / "generated"
                details = pc.call(self.binary, "--offline-generate-operator", registry, baseline, unit, raw, output)
                return pc.read(output / "references.json"), pc.read(output / "sources.json"), details.decode()
        return self.transaction(generate, read_only=True)

    def checkpoint(self, production, previous, as_of, *, stage_selective=None):
        """Persist a dry-run decision and its evidence without allocating a publication day."""
        def mutate(state):
            active = pc.read(state / "lifecycle.json")["active"]
            if not active:
                raise pc.Hold("No active TD baseline.")
            journal = self.journal(state)
            registry = pc.source_root(state, active)
            selection = self.actual_selection(registry)
            if selection != self.registry_selection(journal, active):
                raise pc.Hold("Registry differs from the durable journal.")
            with tempfile.TemporaryDirectory() as work:
                output = Path(work) / "legacy"
                details = pc.call(self.binary, "--offline-compose-legacy", production, registry, active,
                                  output, as_of, previous).decode()
                policy = next(line for line in details.splitlines() if line.startswith("Daily version policy:"))
                evidence = {
                    "baseline": active, "asOf": as_of, "registry": selection, "policy": policy,
                    "lastPublished": pc.read(previous / "dataset_info.json"),
                    "lastPublishedSHA256": {name: digest((previous / (name + ".json")).read_bytes()) for name in pc.FILES},
                    "legacySHA256": {name: digest((output / (name + ".json")).read_bytes()) for name in pc.FILES},
                    "productionAuthorization": "disabled", "blockers": list(pc.BLOCKERS),
                }
            key = digest(canonical(evidence))
            folder = state / "publication"
            folder.mkdir(exist_ok=True)
            file = folder / (key + ".json")
            if not file.exists():
                pc.atomic_json(file, evidence)
            return evidence

        evidence = self.transaction(mutate)
        if stage_selective is not None:
            def export(state):
                active = pc.read(state / "lifecycle.json")["active"]
                registry = pc.source_root(state, active)
                if active != evidence["baseline"] or self.actual_selection(registry) != evidence["registry"]:
                    raise pc.Hold("Registry changed after legacy validation; selective package deferred.")
                stage_selective(Path(registry))
            self.transaction(export, read_only=True)
        return evidence

    @staticmethod
    def journal(state):
        file = state / "journal.json"
        return pc.read(file) if file.exists() else {"schemaVersion": 1, "updates": {}, "applied": []}

    @staticmethod
    def selected(registry, unit):
        file = registry / "registry.json"
        return pc.read(file)["latest"].get(unit) if file.exists() else None

    def submit(self, baseline, unit, previous, references, sources, before_cas=lambda: None):
        if unit not in pc.UNITS:
            raise pc.Hold("Unsupported operator unit.")
        rows = canonical(sorted(references, key=lambda row: (row["operatorId"], row["journeyId"], row["sequence"])))
        payload = digest(rows)
        key = {"baseline": baseline, "unit": unit, "previous": previous, "sha256": payload}
        update_id = digest(canonical(key))

        def mutate(state):
            if not pc.source_root(state, baseline).is_dir():
                raise pc.Hold("The nominated baseline is missing.")
            journal = self.journal(state)
            path = state / "payloads" / (payload + ".json")
            if update_id in journal["updates"]:
                if digest(path.read_bytes()) != payload:
                    raise pc.Hold("Duplicate submission has missing or corrupted durable input.")
                return update_id
            path.parent.mkdir(exist_ok=True)
            if path.exists() and path.read_bytes() != rows:
                raise pc.Hold("Immutable input hash mismatch.")
            if not path.exists():
                path.write_bytes(rows)
            journal["updates"][update_id] = {**key, "sources": sources, "status": "pending"}
            pc.atomic_json(state / "journal.json", journal)
            return update_id

        return self.transaction(mutate, before_cas)

    def process(self, update_id, before_cas=lambda: None):
        def mutate(state):
            journal = self.journal(state)
            entry = journal["updates"][update_id]
            unit, baseline = entry["unit"], entry["baseline"]
            registry = pc.source_root(state, baseline)
            raw = (state / "payloads" / (entry["sha256"] + ".json")).read_bytes()
            key = {field: entry[field] for field in ("baseline", "unit", "previous", "sha256")}
            if digest(raw) != entry["sha256"] or digest(canonical(key)) != update_id:
                raise pc.Hold("Durable update identity or input checksum mismatch.")
            if entry["status"] != "pending":
                return entry["status"]
            # Check the persisted selection against the journal before applying a revision.
            if self.registry_selection(journal, baseline) != self.actual_selection(registry):
                raise pc.Hold("Registry differs from the durable journal; recover before processing.")
            with tempfile.TemporaryDirectory() as tmp:
                inputs = Path(tmp)
                (inputs / "references.json").write_bytes(raw)
                pc.atomic_json(inputs / "sources.json", entry["sources"])
                if self.selected(registry, unit) != entry["previous"]:
                    entry["status"] = "stale"
                else:
                    result = pc.worker(self.binary, registry, baseline, unit, inputs, inputs / "report.json")
                    entry.update(status=result["status"], report=result)
                    if result["status"] in ("validated", "unchanged"):
                        entry["version"] = result["version"]
                        journal["applied"].append(update_id)
            pc.atomic_json(state / "journal.json", journal)
            return entry["status"]

        return self.transaction(mutate, before_cas)

    @staticmethod
    def registry_selection(journal, baseline):
        selected = {}
        for update_id in journal["applied"]:
            entry = journal["updates"][update_id]
            if entry["baseline"] == baseline:
                selected[entry["unit"]] = entry["version"]
        return selected

    @staticmethod
    def actual_selection(registry):
        file = registry / "registry.json"
        return pc.read(file)["latest"] if file.exists() else {}

    def recover(self, baseline):
        def mutate(state):
            registry = pc.source_root(state, baseline)
            manifest = pc.read(registry / "baselines" / baseline / "manifest.json")
            expected = self.registry_selection(self.journal(state), baseline)
            if not expected:
                raise pc.Hold("No validated journal entries to recover.")
            file = registry / "registry.json"
            previous = digest(file.read_bytes()) if file.exists() else None
            encoded = canonical({"schemaVersion": 1, "requiredBaseline": manifest["dependency"], "latest": expected})
            file.write_bytes(encoded)  # Private clone, never made durable before revalidation.

            if pc.coverage(self.binary, registry, baseline) != set(expected):
                raise pc.Hold("Recovered registry coverage differs.")
            if previous != digest(encoded):
                journal = self.journal(state)
                recovery = {"baseline": baseline, "priorRegistrySHA256": previous, "recoveredRegistrySHA256": digest(encoded)}
                journal.setdefault("recoveries", {})[digest(canonical(recovery))] = recovery
                pc.atomic_json(state / "journal.json", journal)
            return expected

        return self.transaction(mutate)

    def record_failure(self, baseline, unit, attempt_id, diagnostics):
        """Record an acquisition failure even when no reference payload was obtained."""
        if unit not in pc.UNITS or not attempt_id:
            raise pc.Hold("Invalid failure identity.")
        key = digest(canonical([baseline, unit, attempt_id]))

        def mutate(state):
            if not pc.source_root(state, baseline).is_dir():
                raise pc.Hold("Unknown failure baseline.")
            journal = self.journal(state)
            failures = journal.setdefault("failures", {})
            event = {"baseline": baseline, "unit": unit, "attempt": attempt_id, "diagnostics": diagnostics}
            if key in failures and failures[key] != event:
                raise pc.Hold("Failure identity already exists with different metadata.")
            failures[key] = event
            pc.atomic_json(state / "journal.json", journal)
            return key

        return self.transaction(mutate)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destination-ref")
    parser.add_argument("--authorize-local-staging", action="store_true")
    parser.add_argument("repository", type=Path)
    parser.add_argument("binary", type=Path)
    parser.add_argument("operation", choices=("bootstrap", "nominate", "promote", "submit", "process", "recover", "record-failure", "checkpoint", "status"))
    parser.add_argument("args", nargs="*")
    options = parser.parse_args()
    handoff = Handoff(options.repository, options.binary, destination=options.destination_ref,
                      authorized=options.authorize_local_staging)
    a = options.args
    if options.operation == "bootstrap" and not a:
        result = handoff.bootstrap()
    elif options.operation == "status" and not a:
        result = handoff.status()
    elif options.operation == "nominate" and len(a) == 1:
        result = handoff.nominate(Path(a[0]))
    elif options.operation == "promote" and len(a) == 1:
        result = handoff.promote(a[0])
    elif options.operation == "submit" and len(a) == 5:
        result = handoff.submit(a[0], a[1], None if a[2] == "-" else a[2], pc.read(Path(a[3])), pc.read(Path(a[4])))
    elif options.operation in ("process", "recover") and len(a) == 1:
        result = getattr(handoff, options.operation)(a[0])
    elif options.operation == "checkpoint" and len(a) == 3:
        result = handoff.checkpoint(Path(a[0]), Path(a[1]), a[2])
    elif options.operation == "record-failure" and len(a) == 4:
        result = handoff.record_failure(*a)
    else:
        parser.error("Invalid arguments; see PERSISTENT_HANDOFF.md")
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    try:
        main()
    except (pc.Hold, OSError, KeyError, ValueError, subprocess.CalledProcessError) as error:
        print(str(error))
        if isinstance(error, subprocess.CalledProcessError):
            print(((error.stdout or b"") + (error.stderr or b"")).decode(errors="replace"))
        raise SystemExit(1)
