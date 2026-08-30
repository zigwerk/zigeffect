#!/usr/bin/env python3
"""Collect paired, process-isolated Graphify/zgraphy M0 resource samples."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parent.parent
REFERENCE = ROOT.parent / "references" / "graphify"
EXPECTED_COMMIT = "cb96bdaa0c367bec8d5c5aee5d7c9ebb727e9780"
EXPECTED_VERSION = "0.9.17"
ENVIRONMENT = Path(os.environ.get("ZGRAPHY_GRAPHIFY_ENV", ROOT / ".zgraphy/benchmarks/graphify-0.9.17"))
PYTHON = Path(os.environ.get("GRAPHIFY_PYTHON", ENVIRONMENT / "bin/python"))
GRAPHIFY = Path(os.environ.get("GRAPHIFY_BIN", ENVIRONMENT / "bin/graphify"))
ZGRAPHY = Path(os.environ.get("ZGRAPHY_BIN", ROOT / "zig-out/bin/zgraphy"))
RUN_ROOT = ROOT / ".zgraphy/benchmarks/runs/resources"
SAMPLE_FILE = RUN_ROOT / "resource-samples.v1.json"
MATRIX_FILE = RUN_ROOT / "resource-matrix.v1.json"
FIXTURE_ID = "mutation-pruning"
FIXTURE_ROOT = "benchmarks/fixtures/mutation-pruning/baseline"
WORKLOAD = "cold_build"
WARMUPS = 2
REPETITIONS = 7
SECRET_KEYS = {
    "ANTHROPIC_API_KEY",
    "AZURE_OPENAI_API_KEY",
    "DEEPSEEK_API_KEY",
    "GEMINI_API_KEY",
    "GOOGLE_API_KEY",
    "MOONSHOT_API_KEY",
    "OPENAI_API_KEY",
}


def digest_bytes(data: bytes) -> str:
    return "sha256:" + hashlib.sha256(data).hexdigest()


def source_digest() -> str:
    paths: list[Path] = []
    for root_name in ("src", "test", "benchmarks"):
        for path in (ROOT / root_name).rglob("*"):
            if not path.is_file() or "baselines" in path.parts or ".zgraphy" in path.parts:
                continue
            paths.append(path)
    paths.extend((ROOT / "build.zig", ROOT / "build.zig.zon", ROOT / "zigeffect.project.json"))
    digest = hashlib.sha256()
    for path in sorted(paths, key=lambda item: item.relative_to(ROOT).as_posix()):
        relative = path.relative_to(ROOT).as_posix().encode()
        digest.update(relative)
        digest.update(b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
        digest.update(b"\0")
    return "sha256:" + digest.hexdigest()


def redacted_environment() -> dict[str, str]:
    environment = dict(os.environ)
    for key in SECRET_KEYS:
        environment.pop(key, None)
    environment.pop("GRAPHIFY_OUT", None)
    return environment


def supervise(command: list[str], label: str) -> tuple[dict[str, int], bytes]:
    run_dir = RUN_ROOT / "processes" / label
    run_dir.mkdir(parents=True, exist_ok=True)
    stdout_path = run_dir / "stdout.log"
    stderr_path = run_dir / "stderr.log"
    with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
        started = time.perf_counter_ns()
        process = subprocess.Popen(
            command,
            cwd=ROOT,
            env=redacted_environment(),
            stdout=stdout,
            stderr=stderr,
        )
        _, status, usage = os.wait4(process.pid, 0)
        ended = time.perf_counter_ns()
        process.returncode = os.waitstatus_to_exitcode(status)
    if process.returncode != 0:
        raise RuntimeError(f"{label} failed with exit code {process.returncode}; inspect {stderr_path}")
    peak_rss = int(usage.ru_maxrss)
    if platform.system() != "Darwin":
        peak_rss *= 1024
    return {
        "elapsed_ns": ended - started,
        "user_cpu_ns": int(usage.ru_utime * 1_000_000_000),
        "system_cpu_ns": int(usage.ru_stime * 1_000_000_000),
        "peak_rss_bytes": peak_rss,
        "exit_code": process.returncode,
    }, stdout_path.read_bytes()


def verify_environment() -> tuple[str, str]:
    if platform.system() not in {"Darwin", "Linux"} or not hasattr(os, "wait4"):
        raise RuntimeError("the M0 process supervisor currently requires Darwin or Linux wait4 resource usage")
    if not GRAPHIFY.is_file() or not PYTHON.is_file() or not ZGRAPHY.is_file():
        raise RuntimeError("Graphify environment or ReleaseSafe zgraphy binary is missing; follow benchmarks/README.md")
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
        [str(PYTHON), "-c", "import platform; print(platform.python_version())"],
        text=True,
    ).strip()
    frozen = subprocess.check_output([str(PYTHON), "-m", "pip", "freeze"])
    return python_version, digest_bytes(frozen)


def graphify_command(output_root: Path) -> list[str]:
    return [
        str(GRAPHIFY),
        "extract",
        FIXTURE_ROOT,
        "--code-only",
        "--no-cluster",
        "--force",
        "--out",
        str(output_root.relative_to(ROOT)),
    ]


def validate_graphify(graph_path: Path) -> dict[str, object]:
    completed = subprocess.run(
        [str(ZGRAPHY), "benchmark", "graphify", FIXTURE_ID, str(graph_path.relative_to(ROOT)), "--json"],
        cwd=ROOT,
        env=redacted_environment(),
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return json.loads(completed.stdout)


def collect_graphify(samples: list[dict[str, object]]) -> None:
    for warmup in range(1, WARMUPS + 1):
        output_root = RUN_ROOT / "graphify" / f"warmup-{warmup}"
        shutil.rmtree(output_root, ignore_errors=True)
        supervise(graphify_command(output_root), f"graphify-warmup-{warmup}")
    for repetition in range(1, REPETITIONS + 1):
        output_root = RUN_ROOT / "graphify" / f"run-{repetition}"
        shutil.rmtree(output_root, ignore_errors=True)
        measured, _ = supervise(graphify_command(output_root), f"graphify-run-{repetition}")
        graph_path = output_root / "graphify-out/graph.json"
        differential = validate_graphify(graph_path)
        samples.append(
            {
                "fixture_id": FIXTURE_ID,
                "engine": "graphify",
                "workload": WORKLOAD,
                "repetition": repetition,
                **measured,
                "persisted_bytes": graph_path.stat().st_size,
                "nodes": differential["input"]["nodes"],
                "relations": differential["input"]["relations"],
                "facts": differential["facts"]["matched"],
                "projection_valid": True,
            }
        )


def zgraphy_command() -> list[str]:
    return [
        str(ZGRAPHY),
        "benchmark",
        "workload",
        FIXTURE_ID,
        "cold-build",
        FIXTURE_ROOT,
        "--json",
    ]


def collect_zgraphy(samples: list[dict[str, object]]) -> None:
    for warmup in range(1, WARMUPS + 1):
        supervise(zgraphy_command(), f"zgraphy-warmup-{warmup}")
    for repetition in range(1, REPETITIONS + 1):
        measured, stdout = supervise(zgraphy_command(), f"zgraphy-run-{repetition}")
        observation = json.loads(stdout)
        samples.append(
            {
                "fixture_id": FIXTURE_ID,
                "engine": "zgraphy",
                "workload": WORKLOAD,
                "repetition": repetition,
                **measured,
                "persisted_bytes": observation["persisted_bytes"],
                "nodes": observation["nodes"],
                "relations": observation["relations"],
                "facts": 0,
                "projection_valid": observation["dangling_edges"] == 0 and observation["true_orphans"] == 0,
            }
        )


def main() -> int:
    python_version, environment_digest = verify_environment()
    RUN_ROOT.mkdir(parents=True, exist_ok=True)
    samples: list[dict[str, object]] = []
    collect_graphify(samples)
    collect_zgraphy(samples)
    SAMPLE_FILE.write_text(
        json.dumps(
            {"schema": "zgraphy.resource-samples.v1", "schema_version": 1, "samples": samples},
            separators=(",", ":"),
        )
        + "\n"
    )

    configuration = {
        "fixture": FIXTURE_ID,
        "workload": WORKLOAD,
        "warmups": WARMUPS,
        "repetitions": REPETITIONS,
        "graphify": ["extract", "--code-only", "--no-cluster", "--force"],
        "zgraphy": ["benchmark", "workload"],
    }
    machine = {
        "system": platform.system(),
        "release": platform.release(),
        "machine": platform.machine(),
        "processor": platform.processor(),
        "logical_cpus": os.cpu_count(),
    }
    command = [
        str(ZGRAPHY),
        "benchmark",
        "resources",
        str(SAMPLE_FILE.relative_to(ROOT)),
        "--source-revision",
        source_digest(),
        "--graphify-python",
        python_version,
        "--graphify-environment",
        environment_digest,
        "--machine",
        digest_bytes(json.dumps(machine, sort_keys=True, separators=(",", ":")).encode()),
        "--configuration",
        digest_bytes(json.dumps(configuration, sort_keys=True, separators=(",", ":")).encode()),
        "--warmups",
        str(WARMUPS),
        "--repetitions",
        str(REPETITIONS),
        "--json",
    ]
    completed = subprocess.run(
        command,
        cwd=ROOT,
        env=redacted_environment(),
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    receipt = json.loads(completed.stdout)
    if receipt["toolchain"]["optimize"] != "ReleaseSafe":
        raise RuntimeError("resource baseline requires a ReleaseSafe zgraphy binary")
    MATRIX_FILE.write_bytes(completed.stdout)
    sys.stdout.buffer.write(completed.stdout)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
