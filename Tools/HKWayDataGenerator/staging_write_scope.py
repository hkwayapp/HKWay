"""Application-side scope controls for the local staging writer."""
import re

from publication_controller import Hold

REF = "refs/heads/dataset-v3-staging"
SHA = r"[0-9a-f]{64}"
BASE = rf"td-[0-9.]{{1,32}}-{SHA}"
UNIT = r"(?:KMB-LWB|CTB|NLB|GMB|LRTFeeder)"
PATHS = re.compile(
    rf"state/(?:ctb-cache/(?:manifest\.json|objects/{SHA}\.json)|\.keep|lifecycle\.json|journal\.json|payloads/{SHA}\.json|publication/{SHA}\.json|"
    rf"registries/{BASE}/(?:registry\.json|baselines/{BASE}/(?:manifest|topology)\.json|"
    rf"operators/{UNIT}/{BASE}-{SHA}/(?:manifest|references)\.json))"
)
MUTABLE = re.compile(rf"state/(?:ctb-cache/manifest\.json|lifecycle\.json|journal\.json|registries/{BASE}/registry\.json)")


def require_write(destination, authorized, *, force=False):
    if not authorized or destination != REF:
        raise Hold("Explicit local staging authorization and its exact destination ref are required.")
    if force:
        raise Hold("Force or non-fast-forward updates are prohibited.")


def verify_index(git, repo):
    """Check staged changes before any object is transferred to the receiver."""
    verify_paths(git(repo, "diff", "--cached", "--raw", "--no-renames", "-z"))


def verify_commit(git, repo, commit):
    verify_paths(git(repo, "diff-tree", "--root", "--no-commit-id", "-r", "--raw", "--no-renames", "-z", commit))


def verify_paths(raw):
    fields = raw.split(b"\0")
    changes = fields[:-1]
    if len(changes) % 2:
        raise Hold("Invalid staging index.")
    for header, rawpath in zip(changes[::2], changes[1::2]):
        path = rawpath.decode("utf-8", errors="strict")
        old_mode, new_mode, _, _, status = header.decode("ascii").split()
        if (not PATHS.fullmatch(path) or new_mode != "100644"
                or (status != "A" and not (status == "M" and old_mode == ":100644" and MUTABLE.fullmatch(path)))):
            raise Hold(f"Staging write outside scope: {status} {path}")


def verify_parent(git, repo, commit, expected):
    parents = git(repo, "rev-list", "--parents", "-n", "1", commit).decode().split()
    if parents != ([commit, expected] if expected else [commit]):
        raise Hold("Force, merge or rewritten history cannot advance the staging ref.")
