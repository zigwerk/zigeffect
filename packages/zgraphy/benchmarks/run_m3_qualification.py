#!/usr/bin/env python3
"""Run correctness-bound M3 one-file qualification against pinned Graphify.

The script owns disposable corpora and OS process observation. It does not
decide claims: the ReleaseSafe zgraphy validator recomputes the authoritative
receipt from retained integer samples.
"""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
REFERENCE = ROOT.parent / "references" / "graphify"
EXPECTED_COMMIT = "cb96bdaa0c367bec8d5c5aee5d7c9ebb727e9780"
EXPECTED_VERSION = "0.9.17"
ENVIRONMENT = Path(os.environ.get("ZGRAPHY_GRAPHIFY_ENV", ROOT / ".zgraphy/benchmarks/graphify-0.9.17"))
PYTHON = Path(os.environ.get("GRAPHIFY_PYTHON", ENVIRONMENT / "bin/python"))
GRAPHIFY = Path(os.environ.get("GRAPHIFY_BIN", ENVIRONMENT / "bin/graphify"))
ZGRAPHY = Path(os.environ.get("ZGRAPHY_BIN", ROOT / "zig-out/bin/zgraphy"))
RUN_ROOT = ROOT / ".zgraphy/benchmarks/runs/m3-qualification"
WORK_ROOT = Path(tempfile.gettempdir()) / "zgraphy-m3-qualification-work"
SAMPLE_FILE = RUN_ROOT / "performance-samples.v1.json"
RECEIPT_FILE = RUN_ROOT / "performance-receipt.v1.json"
WORKLOAD_ID = "m3-selfhost-one-file-managed-update"
MUTATION_PATH = Path("src/search.zig")
MUTATION_LINE = b"\n// zgraphy-m3-qualification-one-file-mutation\n"
SUPERVISOR_VERSION = "zgraphy-m3-qualification-supervisor-v2"
PROCESS_POLL_SECONDS = 0.001
WARMUPS = int(os.environ.get("ZGRAPHY_BENCH_WARMUPS", "2"))
REPETITIONS = int(os.environ.get("ZGRAPHY_BENCH_REPETITIONS", "7"))
TIMEOUT_SECONDS = int(os.environ.get("ZGRAPHY_BENCH_TIMEOUT", "300"))
SECRET_KEYS = {
    "ANTHROPIC_API_KEY",
    "AZURE_OPENAI_API_KEY",
    "DEEPSEEK_API_KEY",
    "GEMINI_API_KEY",
    "GOOGLE_API_KEY",
    "MOONSHOT_API_KEY",
    "OPENAI_API_KEY",
}
CORPUS_FILES = ("build.zig", "build.zig.zon", "zigeffect.project.json")
CORPUS_TREES = ("src", "test", "benchmarks/fixtures/fullstack-orders")


def digest_bytes(data: bytes) -> str:
    return "sha256:" + hashlib.sha256(data).hexdigest()


def canonical_json(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode()


def redacted_environment() -> dict[str, str]:
    environment = dict(os.environ)
    for key in SECRET_KEYS:
        environment.pop(key, None)
    environment.pop("GRAPHIFY_OUT", None)
    environment["GRAPHIFY_NO_TIPS"] = "1"
    environment["NO_COLOR"] = "1"
    return environment


def source_digest() -> str:
    paths: list[Path] = []
    for root_name in ("src", "test", "benchmarks"):
        for path in (ROOT / root_name).rglob("*"):
            if not path.is_file() or path.is_symlink() or "baselines" in path.parts or ".zgraphy" in path.parts:
                continue
            paths.append(path)
    paths.extend(ROOT / name for name in ("build.zig", "build.zig.zon", "zigeffect.project.json"))
    digest = hashlib.sha256()
    for path in sorted(paths, key=lambda item: item.relative_to(ROOT).as_posix()):
        relative = path.relative_to(ROOT).as_posix().encode()
        digest.update(relative)
        digest.update(b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
        digest.update(b"\0")
    return "sha256:" + digest.hexdigest()


def selected_corpus_paths() -> list[Path]:
    paths = [ROOT / name for name in CORPUS_FILES]
    for tree_name in CORPUS_TREES:
        tree = ROOT / tree_name
        for path in tree.rglob("*"):
            if path.is_symlink():
                raise RuntimeError(f"qualification corpus contains a symlink: {path.relative_to(ROOT)}")
            if path.is_file() and ".zgraphy" not in path.parts and ".zig-cache" not in path.parts and "zig-out" not in path.parts:
                paths.append(path)
    return sorted(set(paths), key=lambda item: item.relative_to(ROOT).as_posix())


def corpus_digest(paths: list[Path]) -> str:
    digest = hashlib.sha256()
    for path in paths:
        relative = path.relative_to(ROOT).as_posix().encode()
        digest.update(relative)
        digest.update(b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
        digest.update(b"\0")
    return "sha256:" + digest.hexdigest()


def materialize_corpus(destination: Path, paths: list[Path]) -> None:
    shutil.rmtree(destination, ignore_errors=True)
    destination.mkdir(parents=True)
    for source in paths:
        relative = source.relative_to(ROOT)
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target, follow_symlinks=False)


def mutate(repository: Path) -> None:
    path = repository / MUTATION_PATH
    before = path.read_bytes()
    if MUTATION_LINE in before:
        raise RuntimeError("qualification mutation is already present in a fresh corpus")
    path.write_bytes(before + MUTATION_LINE)


def owned_bytes(root: Path) -> int:
    total = 0
    if not root.is_dir():
        raise RuntimeError(f"missing owned output directory: {root}")
    for path in root.rglob("*"):
        if path.is_symlink():
            raise RuntimeError(f"owned benchmark state contains a symlink: {path}")
        if path.is_file():
            total += path.stat().st_size
    if total <= 0:
        raise RuntimeError(f"empty owned output directory: {root}")
    return total


def supervise(command: list[str], label: str) -> tuple[dict[str, int], bytes]:
    run_dir = RUN_ROOT / "processes" / label
    run_dir.mkdir(parents=True, exist_ok=True)
    stdout_path = run_dir / "stdout.log"
    stderr_path = run_dir / "stderr.log"
    environment = redacted_environment()
    with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
        started = time.perf_counter_ns()
        process = subprocess.Popen(command, cwd=ROOT, env=environment, stdout=stdout, stderr=stderr)
        usage = None
        status = None
        deadline = time.monotonic() + TIMEOUT_SECONDS
        while True:
            pid, observed_status, observed_usage = os.wait4(process.pid, os.WNOHANG)
            if pid == process.pid:
                status = observed_status
                usage = observed_usage
                break
            if time.monotonic() >= deadline:
                process.send_signal(signal.SIGKILL)
                _, status, usage = os.wait4(process.pid, 0)
                raise RuntimeError(f"{label} exceeded {TIMEOUT_SECONDS}s; inspect {stderr_path}")
            time.sleep(PROCESS_POLL_SECONDS)
        ended = time.perf_counter_ns()
        process.returncode = os.waitstatus_to_exitcode(status)
    if process.returncode != 0:
        raise RuntimeError(f"{label} failed with exit code {process.returncode}; inspect {stderr_path}")
    peak_rss = int(usage.ru_maxrss)
    if platform.system() != "Darwin":
        peak_rss *= 1024
    stdout_bytes = stdout_path.read_bytes()
    if not stdout_bytes:
        raise RuntimeError(f"{label} produced no stdout")
    return {
        "elapsed_ns": ended - started,
        "user_cpu_ns": int(usage.ru_utime * 1_000_000_000),
        "system_cpu_ns": int(usage.ru_stime * 1_000_000_000),
        "peak_rss_bytes": peak_rss,
        "exit_code": process.returncode,
    }, stdout_bytes


def run_unmeasured(command: list[str], label: str) -> bytes:
    completed = subprocess.run(
        command,
        cwd=ROOT,
        env=redacted_environment(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=TIMEOUT_SECONDS,
    )
    if completed.returncode != 0:
        diagnostic = RUN_ROOT / "processes" / label
        diagnostic.mkdir(parents=True, exist_ok=True)
        (diagnostic / "stdout.log").write_bytes(completed.stdout)
        (diagnostic / "stderr.log").write_bytes(completed.stderr)
        raise RuntimeError(f"{label} failed with exit code {completed.returncode}; inspect {diagnostic}")
    return completed.stdout


def relative_to_root(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def zgraphy_command(command: str, repository: Path) -> list[str]:
    return [str(ZGRAPHY), command, "--root", str(repository), "--json"]


def configure_zgraphy(repository: Path, repository_id: str | None = None) -> None:
    config_path = repository / ".zgraphy/config.json"
    config = json.loads(config_path.read_text())
    config["automatic_gc"] = True
    config["retention_generations"] = 4
    config["retention_grace_ms"] = 0
    if repository_id is not None:
        config["repository_id"] = repository_id
    config_path.write_text(json.dumps(config, sort_keys=True, separators=(",", ":")) + "\n")


def read_active(repository: Path) -> dict[str, Any]:
    active = json.loads((repository / ".zgraphy/active-generation.json").read_text())
    required = {
        "generation",
        "graph_fingerprint",
        "secondary_index_fingerprint",
        "origin_fingerprint",
        "complete",
    }
    if not required.issubset(active) or not active["complete"]:
        raise RuntimeError("zgraphy active generation is incomplete")
    return active


def setup_zgraphy(
    repository: Path, label: str, repository_id: str | None = None
) -> tuple[dict[str, Any], dict[str, Any]]:
    run_unmeasured(zgraphy_command("init", repository), f"{label}-init")
    configure_zgraphy(repository, repository_id)
    build = json.loads(run_unmeasured(zgraphy_command("build", repository), f"{label}-cold-build"))
    if build.get("schema") != "zgraphy.build.v9" or build.get("status") != "complete":
        raise RuntimeError("zgraphy cold build did not publish schema v9 complete output")
    return build, read_active(repository)


def graphify_command(repository: Path, state_root: Path, *, force: bool) -> list[str]:
    command = [
        str(GRAPHIFY),
        "extract",
        str(repository),
        "--code-only",
        "--out",
        str(state_root),
    ]
    if force:
        command.append("--force")
    return command


def load_graphify_graph(path: Path) -> dict[str, Any]:
    graph = json.loads(path.read_text())
    nodes = graph.get("nodes")
    relations = graph.get("links", graph.get("edges", []))
    if not isinstance(nodes, list) or not nodes or not isinstance(relations, list) or not relations:
        raise RuntimeError("Graphify graph is empty or malformed")
    identifiers = [node.get("id") for node in nodes]
    if any(not isinstance(identifier, str) or not identifier for identifier in identifiers):
        raise RuntimeError("Graphify graph has an invalid node identity")
    if len(set(identifiers)) != len(identifiers):
        raise RuntimeError("Graphify graph has duplicate node identities")
    return {"raw": graph, "nodes": nodes, "relations": relations}


def graphify_topology_digest(graph: dict[str, Any]) -> str:
    nodes = sorted(
        (
            str(node.get("id", "")),
            str(node.get("type", "")),
            str(node.get("label", "")),
            str(node.get("source_file", "")),
        )
        for node in graph["nodes"]
    )
    relations = sorted(
        (
            str(edge.get("source", edge.get("from", ""))),
            str(edge.get("target", edge.get("to", ""))),
            str(edge.get("relation", "")),
        )
        for edge in graph["relations"]
    )
    return digest_bytes(canonical_json({"nodes": nodes, "relations": relations}))


def graphify_source_count(graph: dict[str, Any], source: Path) -> int:
    expected = source.as_posix()
    return sum(
        1
        for node in graph["nodes"]
        if str(node.get("source_file", "")).replace("\\", "/").endswith(expected)
    )


def setup_graphify(repository: Path, state_root: Path, label: str) -> dict[str, Any]:
    run_unmeasured(graphify_command(repository, state_root, force=True), f"{label}-cold-extract")
    return load_graphify_graph(state_root / "graphify-out/graph.json")


def collect_zgraphy(paths: list[Path], label: str, repetition: int, correctness: str) -> dict[str, Any]:
    state_root = WORK_ROOT / "states" / label
    repository = state_root / "repo"
    materialize_corpus(repository, paths)
    cold_build, cold_active = setup_zgraphy(repository, label)
    repository_id = json.loads((repository / ".zgraphy/config.json").read_text())["repository_id"]
    mutate(repository)
    measured, stdout = supervise(zgraphy_command("build", repository), f"{label}-measured")
    build = json.loads(stdout)
    active = read_active(repository)
    status = json.loads(run_unmeasured(zgraphy_command("status", repository), f"{label}-status"))

    clean_root = WORK_ROOT / "oracles" / f"{label}-clean"
    clean_repository = clean_root / "repo"
    materialize_corpus(clean_repository, paths)
    mutate(clean_repository)
    _, clean_active = setup_zgraphy(clean_repository, f"{label}-clean", repository_id)
    refresh = build.get("refresh", {})
    retention = build.get("retention", {})
    equivalent = (
        active["graph_fingerprint"] == clean_active["graph_fingerprint"]
        and active["secondary_index_fingerprint"] == clean_active["secondary_index_fingerprint"]
    )
    current = status.get("generation") == active["generation"] == build.get("generation")
    reconciled = cold_active["generation"] != active["generation"] and refresh.get("reparsed_files") == 1
    retention_healthy = retention.get("status") not in {"failed", "disabled"} and int(retention.get("failed_actions", 0)) == 0
    summary = build.get("summary", {})
    nodes = int(summary.get("nodes", 0))
    relations = int(summary.get("edges", 0))
    if build.get("schema") != "zgraphy.build.v9" or build.get("status") != "complete":
        raise RuntimeError("measured zgraphy build is incomplete")
    if build.get("update_kind") != "semantic_noop":
        raise RuntimeError(f"zgraphy did not use semantic no-op publication for {label}")
    if nodes <= 0 or relations <= 0 or not equivalent or not current or not reconciled or not retention_healthy:
        raise RuntimeError(f"zgraphy correctness gate failed for {label}")
    if int(refresh.get("cache_hits", 0)) <= 0:
        raise RuntimeError(f"zgraphy did not report cache reuse for {label}")
    return {
        "engine": "zgraphy",
        "repetition": repetition,
        **measured,
        "persisted_bytes": owned_bytes(repository / ".zgraphy"),
        "nodes": nodes,
        "relations": relations,
        "correctness_digest": correctness,
        "correctness_passed": True,
        "graph_healthy": True,
        "changed_source_reconciled": reconciled,
        "incremental_clean_equivalent": equivalent,
        "active_generation_current": current,
        "retention_healthy": retention_healthy,
        "reparsed_files": int(refresh["reparsed_files"]),
        "cache_hits": int(refresh["cache_hits"]),
    }


def collect_graphify(paths: list[Path], label: str, repetition: int, correctness: str) -> dict[str, Any]:
    state_root = WORK_ROOT / "states" / label
    repository = state_root / "repo"
    materialize_corpus(repository, paths)
    cold = setup_graphify(repository, state_root, label)
    cold_digest = graphify_topology_digest(cold)
    cold_source_count = graphify_source_count(cold, MUTATION_PATH)
    mutate(repository)
    measured, _ = supervise(graphify_command(repository, state_root, force=False), f"{label}-measured")
    graph_path = state_root / "graphify-out/graph.json"
    graph = load_graphify_graph(graph_path)
    incremental_digest = graphify_topology_digest(graph)

    clean_root = WORK_ROOT / "oracles" / f"{label}-clean"
    clean_repository = clean_root / "repo"
    materialize_corpus(clean_repository, paths)
    mutate(clean_repository)
    clean = setup_graphify(clean_repository, clean_root, f"{label}-clean")
    clean_digest = graphify_topology_digest(clean)
    source_count = graphify_source_count(graph, MUTATION_PATH)
    equivalent = incremental_digest == clean_digest
    reconciled = cold_source_count > 0 and source_count == cold_source_count
    stable_semantics = incremental_digest == cold_digest
    if not equivalent or not reconciled or not stable_semantics:
        raise RuntimeError(f"Graphify correctness gate failed for {label}")
    return {
        "engine": "graphify",
        "repetition": repetition,
        **measured,
        "persisted_bytes": owned_bytes(state_root / "graphify-out"),
        "nodes": len(graph["nodes"]),
        "relations": len(graph["relations"]),
        "correctness_digest": correctness,
        "correctness_passed": True,
        "graph_healthy": True,
        "changed_source_reconciled": reconciled,
        "incremental_clean_equivalent": equivalent,
        "active_generation_current": True,
        "retention_healthy": True,
        "reparsed_files": 0,
        "cache_hits": 0,
    }


def verify_environment() -> tuple[str, str, str]:
    if platform.system() not in {"Darwin", "Linux"} or not hasattr(os, "wait4"):
        raise RuntimeError("M3 qualification currently requires Darwin or Linux wait4")
    if WARMUPS <= 0 or REPETITIONS < 7 or REPETITIONS > 256:
        raise RuntimeError("qualification requires at least one warmup and 7..256 repetitions")
    if not GRAPHIFY.is_file() or not PYTHON.is_file() or not ZGRAPHY.is_file():
        raise RuntimeError("Graphify environment or ReleaseSafe zgraphy binary is missing")
    commit = subprocess.check_output(["git", "-C", str(REFERENCE), "rev-parse", "HEAD"], text=True).strip()
    if commit != EXPECTED_COMMIT:
        raise RuntimeError(f"Graphify reference mismatch: expected {EXPECTED_COMMIT}, found {commit}")
    version = subprocess.check_output(
        [str(PYTHON), "-c", 'from importlib.metadata import version; print(version("graphifyy"))'],
        text=True,
    ).strip()
    if version != EXPECTED_VERSION:
        raise RuntimeError(f"Graphify package mismatch: expected {EXPECTED_VERSION}, found {version}")
    python_version = subprocess.check_output(
        [str(PYTHON), "-c", "import platform; print(platform.python_version())"], text=True
    ).strip()
    frozen = subprocess.check_output([str(PYTHON), "-m", "pip", "freeze"])
    environment_digest = digest_bytes(frozen)
    zgraphy_help = subprocess.check_output([str(ZGRAPHY), "--help"], cwd=ROOT, env=redacted_environment())
    if b"benchmark performance" not in zgraphy_help:
        raise RuntimeError("zgraphy binary does not contain the M3 performance command; rebuild ReleaseSafe")
    return python_version, environment_digest, commit


def main() -> int:
    python_version, environment_digest, commit = verify_environment()
    paths = selected_corpus_paths()
    corpus_identity = corpus_digest(paths)
    source_identity = source_digest()
    machine = {
        "system": platform.system(),
        "release": platform.release(),
        "machine": platform.machine(),
        "processor": platform.processor(),
        "logical_cpus": os.cpu_count(),
    }
    machine_digest = digest_bytes(canonical_json(machine))
    configuration = {
        "workload": WORKLOAD_ID,
        "mutation_path": MUTATION_PATH.as_posix(),
        "mutation_digest": digest_bytes(MUTATION_LINE),
        "warmups": WARMUPS,
        "repetitions": REPETITIONS,
        "zgraphy": ["build", "--json", "automatic_gc", "retention=4", "grace=0"],
        "graphify": ["extract", "--code-only", "manifest_incremental", "clustered_correctness_path"],
        "arm_order": "alternating",
    }
    configuration_digest = digest_bytes(canonical_json(configuration))
    quality_digest = digest_bytes((ROOT / "benchmarks/baselines/quality-matrix.v1.json").read_bytes())
    resource_digest = digest_bytes((ROOT / "benchmarks/baselines/resource-matrix.v1.json").read_bytes())
    correctness = {
        "corpus": corpus_identity,
        "mutation": configuration["mutation_digest"],
        "gates": [
            "incremental_clean_graph_equal",
            "incremental_clean_index_equal",
            "changed_source_reconciled",
            "active_generation_current",
            "retention_healthy",
            "graphify_incremental_clean_topology_equal",
        ],
    }
    correctness_digest = digest_bytes(canonical_json(correctness))
    identity = {
        "workload_id": WORKLOAD_ID,
        "corpus_digest": corpus_identity,
        "source_revision": source_identity,
        "machine_digest": machine_digest,
        "operating_system": platform.system().lower(),
        "target": f"{platform.machine().lower()}-{platform.system().lower()}",
        "toolchain": f"zig-0.16.0_python-{python_version}",
        "graphify_python": python_version,
        "optimize": "ReleaseSafe",
        "adapter_version": SUPERVISOR_VERSION,
        "provider_version": f"Graphify-{EXPECTED_VERSION}-{commit[:8]}",
        "configuration_digest": configuration_digest,
        "correctness_digest": correctness_digest,
        "quality_matrix_digest": quality_digest,
        "resource_matrix_digest": resource_digest,
        "graphify_environment_digest": environment_digest,
    }

    shutil.rmtree(RUN_ROOT, ignore_errors=True)
    shutil.rmtree(WORK_ROOT, ignore_errors=True)
    RUN_ROOT.mkdir(parents=True)
    for warmup in range(1, WARMUPS + 1):
        collect_graphify(paths, f"warmup-{warmup}-graphify", warmup, correctness_digest)
        collect_zgraphy(paths, f"warmup-{warmup}-zgraphy", warmup, correctness_digest)

    samples: list[dict[str, Any]] = []
    for repetition in range(1, REPETITIONS + 1):
        order = ("graphify", "zgraphy") if repetition % 2 else ("zgraphy", "graphify")
        for engine in order:
            label = f"run-{repetition}-{engine}"
            if engine == "graphify":
                samples.append(collect_graphify(paths, label, repetition, correctness_digest))
            else:
                samples.append(collect_zgraphy(paths, label, repetition, correctness_digest))

    sample_document = {
        "schema": "zgraphy.performance-samples.v1",
        "schema_version": 1,
        "identity": identity,
        "sampling": {
            "warmups": WARMUPS,
            "repetitions": REPETITIONS,
            "supervisor": SUPERVISOR_VERSION,
        },
        "targets": {
            "minimum_speedup_basis_points": 50_000,
            "maximum_rss_ratio_basis_points": 5_000,
        },
        "samples": samples,
    }
    SAMPLE_FILE.write_bytes(canonical_json(sample_document) + b"\n")
    command = [
        str(ZGRAPHY),
        "benchmark",
        "performance",
        relative_to_root(SAMPLE_FILE),
        "--source-revision",
        source_identity,
        "--machine",
        machine_digest,
        "--configuration",
        configuration_digest,
        "--correctness",
        correctness_digest,
        "--quality",
        quality_digest,
        "--resources",
        resource_digest,
        "--graphify-python",
        python_version,
        "--graphify-environment",
        environment_digest,
        "--warmups",
        str(WARMUPS),
        "--repetitions",
        str(REPETITIONS),
        "--json",
    ]
    receipt = run_unmeasured(command, "native-receipt")
    parsed_receipt = json.loads(receipt)
    if parsed_receipt.get("schema") != "zgraphy.performance-receipt.v1":
        raise RuntimeError("native M3 performance receipt has an unexpected schema")
    RECEIPT_FILE.write_bytes(receipt)
    shutil.rmtree(WORK_ROOT, ignore_errors=True)
    sys.stdout.buffer.write(receipt)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
