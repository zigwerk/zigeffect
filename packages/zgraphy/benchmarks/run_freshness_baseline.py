#!/usr/bin/env python3
"""Exercise the canonical modify/rename/delete sequence on disposable states."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parent.parent
ZGRAPHY = Path(os.environ.get("ZGRAPHY_BIN", ROOT / "zig-out/bin/zgraphy"))
RUN_ROOT = ROOT / ".zgraphy/benchmarks/runs/freshness"
OBSERVED_ROOT = RUN_ROOT / "observed"
CLEAN_ROOT = RUN_ROOT / "clean"
TRANSITION_FILE = RUN_ROOT / "freshness-transitions.v1.json"
RECEIPT_FILE = RUN_ROOT / "freshness-receipt.v1.json"
BASELINE_ROOT = ROOT / "benchmarks/fixtures/mutation-pruning/baseline/src"
MUTATION_ROOT = ROOT / "benchmarks/fixtures/mutation-pruning/mutations"


def digest_state(state_root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(state_root.rglob("*.zig"), key=lambda item: item.relative_to(state_root).as_posix()):
        digest.update(path.relative_to(state_root).as_posix().encode())
        digest.update(b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
        digest.update(b"\0")
    return "sha256:" + digest.hexdigest()


def reset_state(state_root: Path, files: dict[str, bytes]) -> None:
    shutil.rmtree(state_root, ignore_errors=True)
    source = state_root / "src"
    source.mkdir(parents=True)
    for name, content in files.items():
        (source / name).write_bytes(content)


def observe(state_root: Path, workload: str) -> dict[str, object]:
    completed = subprocess.run(
        [
            str(ZGRAPHY),
            "benchmark",
            "workload",
            "mutation-pruning",
            workload,
            str(state_root.relative_to(ROOT)),
            "--json",
        ],
        cwd=ROOT,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return json.loads(completed.stdout)


def identity(observation: dict[str, object], kind: str, label: str, path: str) -> int:
    for probe in observation["identities"]:
        if probe["kind"] == kind and probe["label"] == label and probe["path"] == path:
            return int(probe["id"])
    raise RuntimeError(f"missing identity probe {kind}:{path}:{label}")


def absent_count(observation: dict[str, object], identifiers: list[int]) -> int:
    active = {int(probe["id"]) for probe in observation["identities"]}
    return sum(identifier not in active for identifier in identifiers)


def preserved_count(previous: dict[str, object], current: dict[str, object], selectors: list[tuple[str, str, str, str]]) -> int:
    preserved = 0
    for kind, label, previous_path, current_path in selectors:
        if identity(previous, kind, label, previous_path) == identity(current, kind, label, current_path):
            preserved += 1
    return preserved


def transition(
    mutation_id: str,
    operation: str,
    before_digest: str,
    after_digest: str,
    observed: dict[str, object],
    clean: dict[str, object],
    preserved_expected: int,
    preserved_observed: int,
    removed_expected: int,
    removed_observed: int,
    invalidated_expected: int,
) -> dict[str, object]:
    return {
        "mutation_id": mutation_id,
        "operation": operation,
        "update_mode": "full_rebuild",
        "before_digest": before_digest,
        "after_digest": after_digest,
        "observed_graph_fingerprint": observed["graph_fingerprint"],
        "clean_graph_fingerprint": clean["graph_fingerprint"],
        "canonical_equivalent": observed["graph_fingerprint"] == clean["graph_fingerprint"],
        "preserved_expected": preserved_expected,
        "preserved_observed": preserved_observed,
        "removed_expected": removed_expected,
        "removed_observed": removed_observed,
        "invalidated_expected": invalidated_expected,
        "invalidated_observed": 0,
        "stale_nodes": removed_expected - removed_observed,
        "stale_edges": 0,
        "dangling_edges": observed["dangling_edges"],
        "true_orphans": observed["true_orphans"],
        "unowned_vectors": observed["unowned_vectors"],
        "snapshot_complete": observed["snapshot_complete"],
        "persisted_bytes": observed["persisted_bytes"],
    }


def main() -> int:
    if not ZGRAPHY.is_file():
        raise RuntimeError("ReleaseSafe zgraphy binary is missing; run zig build install -Doptimize=ReleaseSafe")
    baseline_files = {
        "main.zig": (BASELINE_ROOT / "main.zig").read_bytes(),
        "catalog.zig": (BASELINE_ROOT / "catalog.zig").read_bytes(),
    }
    modified_files = {
        "main.zig": baseline_files["main.zig"],
        "catalog.zig": (MUTATION_ROOT / "01-modify/catalog.zig").read_bytes(),
    }
    renamed_files = {
        "main.zig": baseline_files["main.zig"],
        "inventory.zig": (MUTATION_ROOT / "02-rename/inventory.zig").read_bytes(),
    }
    deleted_files = {"main.zig": baseline_files["main.zig"]}

    reset_state(OBSERVED_ROOT, baseline_files)
    baseline_digest = digest_state(OBSERVED_ROOT)
    baseline = observe(OBSERVED_ROOT, "cold-build")
    transitions: list[dict[str, object]] = []

    (OBSERVED_ROOT / "src/catalog.zig").write_bytes(modified_files["catalog.zig"])
    reset_state(CLEAN_ROOT, modified_files)
    modified_digest = digest_state(OBSERVED_ROOT)
    modified = observe(OBSERVED_ROOT, "one-file-modify")
    modified_clean = observe(CLEAN_ROOT, "one-file-modify")
    transitions.append(
        transition(
            "modify-catalog",
            "modify",
            baseline_digest,
            modified_digest,
            modified,
            modified_clean,
            2,
            preserved_count(
                baseline,
                modified,
                [
                    ("symbol", "feature", "src/catalog.zig", "src/catalog.zig"),
                    ("symbol", "orphaned", "src/catalog.zig", "src/catalog.zig"),
                ],
            ),
            0,
            0,
            1,
        )
    )

    old_catalog_ids = [identity(modified, "file", "catalog.zig", "src/catalog.zig")]
    (OBSERVED_ROOT / "src/catalog.zig").unlink()
    (OBSERVED_ROOT / "src/inventory.zig").write_bytes(renamed_files["inventory.zig"])
    reset_state(CLEAN_ROOT, renamed_files)
    renamed_digest = digest_state(OBSERVED_ROOT)
    renamed = observe(OBSERVED_ROOT, "rename")
    renamed_clean = observe(CLEAN_ROOT, "rename")
    transitions.append(
        transition(
            "rename-catalog-to-inventory",
            "rename",
            modified_digest,
            renamed_digest,
            renamed,
            renamed_clean,
            2,
            preserved_count(
                modified,
                renamed,
                [
                    ("symbol", "feature", "src/catalog.zig", "src/inventory.zig"),
                    ("symbol", "orphaned", "src/catalog.zig", "src/inventory.zig"),
                ],
            ),
            1,
            absent_count(renamed, old_catalog_ids),
            0,
        )
    )

    old_inventory_ids = [
        identity(renamed, "file", "inventory.zig", "src/inventory.zig"),
        identity(renamed, "symbol", "feature", "src/inventory.zig"),
        identity(renamed, "symbol", "orphaned", "src/inventory.zig"),
    ]
    (OBSERVED_ROOT / "src/inventory.zig").unlink()
    reset_state(CLEAN_ROOT, deleted_files)
    deleted_digest = digest_state(OBSERVED_ROOT)
    deleted = observe(OBSERVED_ROOT, "delete")
    deleted_clean = observe(CLEAN_ROOT, "delete")
    transitions.append(
        transition(
            "delete-inventory",
            "delete",
            renamed_digest,
            deleted_digest,
            deleted,
            deleted_clean,
            2,
            preserved_count(
                renamed,
                deleted,
                [
                    ("file", "main.zig", "src/main.zig", "src/main.zig"),
                    ("symbol", "main", "src/main.zig", "src/main.zig"),
                ],
            ),
            3,
            absent_count(deleted, old_inventory_ids),
            1,
        )
    )

    TRANSITION_FILE.parent.mkdir(parents=True, exist_ok=True)
    TRANSITION_FILE.write_text(
        json.dumps(
            {"schema": "zgraphy.freshness-transitions.v1", "schema_version": 1, "transitions": transitions},
            separators=(",", ":"),
        )
        + "\n"
    )
    completed = subprocess.run(
        [str(ZGRAPHY), "benchmark", "freshness", str(TRANSITION_FILE.relative_to(ROOT)), "--json"],
        cwd=ROOT,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    receipt = json.loads(completed.stdout)
    if receipt["freshness_gate_passed"]:
        raise RuntimeError("current M0 baseline unexpectedly claims the freshness target is complete")
    RECEIPT_FILE.write_bytes(completed.stdout)
    sys.stdout.buffer.write(completed.stdout)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
