"""Offline shard orchestration and legacy publication simulation. No network operations."""
import argparse
from contextlib import contextmanager
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from time import monotonic
from zoneinfo import ZoneInfo

FILES = ("dataset_info", "operators", "routes", "journeys", "journey_stops", "stops",
         "schedules", "operator_stop_references", "journey_shapes")
UNITS = ("KMB-LWB", "CTB", "NLB", "GMB", "LRTFeeder")
BLOCKERS = (
    "Native KMB Swift HTTP 403",
    "Legacy API equivalence sampling",
    "45 potential service truncation indicators",
    "246 changed mappings with unchanged TD sequences",
    "12 missing mappings with unchanged TD sequences",
    "Unverified route 38 full fare change",
    "Unverified N50 section fare addition",
)
HK = ZoneInfo("Asia/Hong_Kong")


class Hold(RuntimeError):
    pass


def read(path):
    return json.loads(path.read_bytes())


def atomic_json(path, value):
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as file:
        partial = Path(file.name)
        try:
            file.write(json.dumps(value, sort_keys=True).encode())
            file.flush()
            os.fsync(file.fileno())
            partial.replace(path)
        finally:
            partial.unlink(missing_ok=True)


@contextmanager
def lock(path):
    try:
        path.mkdir()
    except FileExistsError as error:
        raise Hold(f"Busy or interrupted lock {path}; retain staged inputs for retry.") from error
    try:
        yield
    finally:
        path.rmdir()


def call(*args, env=None):
    return subprocess.run([str(a) for a in args], env=env, check=True, capture_output=True).stdout


def identity(registry):
    return read(registry / "registry.json")["requiredBaseline"]["identity"]


def coverage(binary, registry, baseline):
    call(binary, "--offline-shard-verify", registry, baseline)
    selection = registry / "registry.json"
    return set(read(selection)["latest"]) if selection.exists() else set()


def source_root(state, baseline):
    if not baseline or Path(baseline).name != baseline or baseline in (".", ".."):
        raise Hold("Invalid baseline identifier")
    return state / "registries" / baseline


def nominate(binary, production, state, provenance=None):
    """Build a candidate in isolation; an existing active selection is untouched."""
    state.mkdir(parents=True, exist_ok=True)
    registries = state / "registries"
    registries.mkdir(exist_ok=True)
    with lock(state / ".lifecycle-lock"), tempfile.TemporaryDirectory(dir=state) as work:
        root = Path(work)
        args = [provenance] if provenance is not None else []
        call(binary, "--offline-shard-baseline", production, root, *args)
        baseline, = (p.name for p in (root / "baselines").iterdir())
        dest = source_root(state, baseline)
        if not dest.exists():
            root.rename(dest)
        path = state / "lifecycle.json"
        current = read(path) if path.exists() else {"active": None}
        if current["active"] != baseline:
            current["candidate"] = baseline
            atomic_json(path, current)
        return baseline


def promote(binary, state, baseline):
    """Explicit approval for local activation only. No legacy publication."""
    with lock(state / ".lifecycle-lock"):
        lifecycle = read(state / "lifecycle.json")
        if lifecycle.get("candidate") != baseline:
            raise Hold("Only the nominated TD candidate may be promoted.")
        registry = source_root(state, baseline)
        with lock(registry / ".registry-lock"):
            if coverage(binary, registry, baseline) != set(UNITS):
                raise Hold("TD candidate has incomplete compatible coverage.")
            if active := lifecycle.get("active"):
                call(binary, "--offline-shard-verify-fares", source_root(state, active), active, registry, baseline)
            atomic_json(state / "lifecycle.json", {"active": baseline, "candidate": None})


def worker(binary, registry, baseline, unit, inputs, report):
    """Acquire one local operator input, validate and stage it, then record terminal status."""
    start = monotonic()
    terminal = {"unit": unit, "baseline": baseline, "status": "failed"}
    try:
        with tempfile.TemporaryDirectory() as raw:
            work = Path(raw)
            for item in ("references.json", "sources.json"):
                shutil.copyfile(inputs / item, work / item)
            with lock(registry / ".collection-lock"):
                before = read(registry / "registry.json")["latest"].get(unit) if (registry / "registry.json").exists() else None
                output = call(binary, "--offline-shard-register", registry, baseline, unit,
                              work / "references.json", work / "sources.json")
                version = read(registry / "registry.json")["latest"][unit]
                terminal.update(status="unchanged" if before == version else "validated",
                                version=version, previousVersion=before, diagnostics=output.decode(), acquisition="local-fixture")
    except (Hold, OSError, subprocess.CalledProcessError, KeyError, ValueError) as error:
        terminal["diagnostics"] = ((error.stdout or b"") + (error.stderr or b"")).decode(errors="replace")             if isinstance(error, subprocess.CalledProcessError) else str(error)
    terminal["elapsedSeconds"] = monotonic() - start
    atomic_json(report, terminal)
    return terminal


def package_result(registry, report, artifact):
    item = read(report)
    artifact.mkdir(parents=True)
    if item["status"] != "failed":
        source = registry / "operators" / item["unit"] / item["version"]
        for name in ("manifest.json", "references.json"):
            shutil.copyfile(source / name, artifact / name)
    shutil.copyfile(report, artifact / "report.json")


def collect(binary, registry, baseline, artifacts, expected):
    terminal_reports([read(a / "report.json") for a in artifacts], expected, baseline)
    failures = []
    for artifact in artifacts:
        try:
            item = read(artifact / "report.json")
            if item["status"] in {"failed", "unchanged"}:
                continue
            unit, version = item["unit"], item["version"]
            with lock(registry / ".collection-lock"):
                selected = read(registry / "registry.json")["latest"].get(unit)
                if selected not in (item["previousVersion"], version):
                    raise Hold(f"{unit} changed after the worker snapshot; retain this artifact for revalidation.")
                manifest = read(artifact / "manifest.json")
                rows = (artifact / "references.json").read_bytes()
                digest = hashlib.sha256(rows).hexdigest()
                if (manifest["unit"] != unit or manifest["version"] != version
                        or manifest["requiredBaseline"] != read(registry / "registry.json")["requiredBaseline"]
                        or manifest["payloadSHA256"] != digest or version != f"{baseline}-{digest}"):
                    raise Hold(f"Invalid worker artifact for {unit}.")
                with tempfile.TemporaryDirectory() as raw:
                    sources = Path(raw) / "sources.json"
                    atomic_json(sources, manifest["sources"])
                    call(binary, "--offline-shard-register", registry, baseline, unit,
                         artifact / "references.json", sources)
                if read(registry / "registry.json")["latest"].get(unit) != version:
                    raise Hold("Imported artifact differs from the validated worker revision.")

        except (Hold, OSError, subprocess.CalledProcessError, KeyError, ValueError) as error:
            failures.append(f"{artifact.name}: {error}")
    if failures:
        raise Hold("One or more artifacts rejected; independent successful units retained: " + "; ".join(failures))


def terminal_reports(reports, expected, baseline=None):
    by_unit = {}
    for item in reports:
        unit = item.get("unit")
        if (unit in by_unit or item.get("status") not in {"failed", "validated", "unchanged"}
                or (baseline is not None and item.get("baseline") != baseline)):
            raise Hold("Duplicate, incompatible or nonterminal worker result.")
        by_unit[unit] = item
    if set(by_unit) != set(expected):
        raise Hold("All expected jobs must report terminal outcomes.")
    return by_unit


class LocalPublicationSimulation:
    """Git plumbing confined to an explicit local simulation ref. No transfer operations."""
    ref = "refs/heads/hkway-v3-simulation"

    def __init__(self, repo, registry, compose):
        self.repo = repo.resolve()
        self.registry = registry
        self.compose = compose
        if subprocess.run(["git", "-C", str(repo), "remote"], check=True, capture_output=True).stdout.strip():
            raise Hold("Simulation requires a repository without any remotes.")

    def git(self, *args, env=None):
        return call("git", "-C", self.repo, *args, env=env)

    def head(self):
        return self.git("rev-parse", self.ref).decode().strip()

    def previous(self, head, directory):
        directory.mkdir()
        for name in FILES:
            file = name + ".json"
            (directory / file).write_bytes(self.git("show", f"{head}:Dataset/{file}"))

    def run(self, as_of, *, dry_run=True, authorize_simulation=False, before_compare_and_swap=lambda: None):
        if as_of.utcoffset() is None:
            raise Hold("Simulation requires an explicit time zone.")
        if not dry_run and not authorize_simulation:
            raise Hold("Publication is disabled without explicit local simulation authorization.")
        if not dry_run and f"branch {self.ref}" in self.git("worktree", "list", "--porcelain").decode().splitlines():
            raise Hold("Simulation ref must not be checked out.")
        with lock(self.repo / ".git" / "hkway-v3-publication-lock"):
            for _ in range(3):
                head = self.head()
                # Keep the exact registry pending until a later eligible day.
                with lock(self.registry / ".registry-lock"), tempfile.TemporaryDirectory() as raw:
                    root = Path(raw)
                    previous = root / "previous"
                    self.previous(head, previous)
                    candidate = root / "candidate"
                    self.compose(previous, candidate)
                    if any(not (candidate / f"{name}.json").is_file() for name in FILES):
                        raise Hold("Composer did not produce all nine legacy files.")
                    if read(candidate / "dataset_info.json") != read(previous / "dataset_info.json"):
                        raise Hold("Staged metadata differs from last published metadata.")
                    changed = any(read(candidate / f"{name}.json") != read(previous / f"{name}.json")
                                  for name in FILES if name != "dataset_info")
                    manifest = read(previous / "dataset_info.json")
                    version = as_of.astimezone(HK).strftime("%Y.%m.%d")
                    if not changed:
                        return "unchanged"
                    if version <= manifest["version"]:
                        return "pending"
                    if dry_run:
                        return "dry-run"
                    manifest.update(version=version, generatedAt=as_of.astimezone(HK).isoformat(timespec="seconds"))
                    atomic_json(candidate / "dataset_info.json", manifest)
                    before_compare_and_swap()
                    if self.head() != head:
                        continue
                    if self.commit(head, candidate, root, version):
                        return "simulated"
            raise Hold("HEAD moved during three attempts; staged shards remain pending.")

    def commit(self, head, candidate, scratch, version):
        env = {**os.environ, "GIT_INDEX_FILE": str(scratch / "index"),
               "GIT_AUTHOR_NAME": "HK Way offline simulation", "GIT_AUTHOR_EMAIL": "simulation@example.invalid",
               "GIT_COMMITTER_NAME": "HK Way offline simulation", "GIT_COMMITTER_EMAIL": "simulation@example.invalid"}
        self.git("read-tree", head, env=env)
        for name in FILES:
            file = name + ".json"
            blob = self.git("hash-object", "-w", candidate / file, env=env).decode().strip()
            self.git("update-index", "--add", "--cacheinfo", f"100644,{blob},Dataset/{file}", env=env)
        tree = self.git("write-tree", env=env).decode().strip()
        commit = self.git("commit-tree", tree, "-p", head, "-m", f"Offline simulation {version}", env=env).decode().strip()
        try:
            self.git("update-ref", self.ref, commit, head)
        except subprocess.CalledProcessError:
            if self.head() == head:
                raise
            return False
        return True


def dry_run(binary, production, state, previous, output, reports, expected, as_of):
    with lock(state / ".lifecycle-lock"):
        active = read(state / "lifecycle.json")["active"]
        if not active:
            raise Hold("No active TD baseline.")
        terminal_reports(reports, expected, active)
        registry = source_root(state, active)
        with lock(registry / ".registry-lock"):
            return call(binary, "--offline-compose-legacy", production, registry, active, output, as_of, previous).decode()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("nominate", "promote", "worker", "package", "collect", "fan-in", "authorize-production"))
    parser.add_argument("arguments", nargs="*")
    args = parser.parse_args()
    a = args.arguments
    if args.command == "authorize-production":
        raise Hold("Production publication disabled: " + "; ".join(BLOCKERS))
    if args.command == "nominate" and len(a) == 3:
        print(nominate(a[0], Path(a[1]), Path(a[2])))
    elif args.command == "promote" and len(a) == 3:
        promote(a[0], Path(a[1]), a[2])
    elif args.command == "worker" and len(a) == 6 and a[3] in UNITS:
        print(json.dumps(worker(a[0], Path(a[1]), a[2], a[3], Path(a[4]), Path(a[5]))))
    elif args.command == "package" and len(a) == 3:
        package_result(*map(Path, a))
    elif args.command == "collect" and len(a) >= 5:
        collect(a[0], Path(a[1]), a[2], [Path(path) for path in a[4:]], a[3].split(","))
    elif args.command == "fan-in" and len(a) >= 8:
        print(dry_run(a[0], *(Path(value) for value in a[1:5]),
                      [read(Path(value)) for value in a[7:]], a[6].split(","), a[5]))
    else:
        parser.error("Invalid command arguments; see WORKFLOW_CANDIDATES.md")


if __name__ == "__main__":
    try:
        main()
    except (Hold, OSError, subprocess.CalledProcessError, ValueError, KeyError) as error:
        print(str(error))
        if isinstance(error, subprocess.CalledProcessError):
            print(((error.stdout or b"") + (error.stderr or b"")).decode(errors="replace"))
        raise SystemExit(1)
