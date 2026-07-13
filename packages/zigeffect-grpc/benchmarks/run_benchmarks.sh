#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
python="${1:-python3}"
calls="${GRPC_BENCH_CALLS:-400}"
workers="${GRPC_BENCH_WORKERS:-32}"
stream_messages="${GRPC_BENCH_STREAM_MESSAGES:-8}"
sizes="${GRPC_BENCH_MESSAGE_SIZES:-0 1024 65536}"
receipt="${GRPC_BENCH_RECEIPT:-/tmp/zigeffect-grpc-benchmarks.json}"
work="$(mktemp -d)"
containers=()

cleanup() {
  for container in "${containers[@]:-}"; do docker rm -f "$container" >/dev/null 2>&1 || true; done
  rm -rf "$work"
}
trap cleanup EXIT

targets=(zig grpc-go tonic grpc-cpp)
dockerfiles=(Dockerfile.zig Dockerfile.go Dockerfile.tonic Dockerfile.cpp)

for index in "${!targets[@]}"; do
  target="${targets[$index]}"
  image="zigeffect-grpc-benchmark-${target}:local"
  docker build --progress=plain \
    -f "$repo_root/packages/zigeffect-grpc/benchmarks/${dockerfiles[$index]}" \
    -t "$image" "$repo_root"
  for size in $sizes; do
    container="zigeffect-grpc-benchmark-${target}-${size}-$$"
    port=$((46000 + (($$ + index * 101 + size) % 1500)))
    containers+=("$container")
    docker run --name "$container" -d -e PORT=8080 -p "127.0.0.1:${port}:8080" "$image" >/dev/null
    "$python" "$repo_root/packages/zigeffect-grpc/benchmarks/driver.py" \
      --target "$target" \
      --address "127.0.0.1:${port}" \
      --container "$container" \
      --calls "$calls" \
      --workers "$workers" \
      --stream-messages "$stream_messages" \
      --payload-size "$size" \
      --output "$work/${target}-${size}.json"
    docker rm -f "$container" >/dev/null
    containers=("${containers[@]:0:${#containers[@]}-1}")
  done
done

"$python" - "$work" "$receipt" "$repo_root" <<'PY'
import glob
import hashlib
import json
import os
import platform
import re
import sys

work, receipt_path, repo_root = sys.argv[1:]
results = []
for path in sorted(glob.glob(os.path.join(work, "*.json"))):
    with open(path, encoding="utf-8") as source:
        results.append(json.load(source))
if len(results) != 12 or any(not result.get("complete") for result in results):
    raise SystemExit("all four runtimes and three message sizes are required")
hasher = hashlib.sha256()
for relative in (
    "packages/zigeffect-grpc/src",
    "packages/zigeffect-grpc/benchmarks",
    "packages/zigeffect-grpc/build.zig",
    "packages/zigeffect-grpc/build.zig.zon",
):
    path = os.path.join(repo_root, relative)
    files = [path] if os.path.isfile(path) else sorted(
        candidate for candidate in glob.glob(os.path.join(path, "**"), recursive=True)
        if os.path.isfile(candidate)
    )
    for candidate in files:
        hasher.update(os.path.relpath(candidate, repo_root).encode())
        with open(candidate, "rb") as source:
            content = source.read()
        if os.path.relpath(candidate, repo_root) == "packages/zigeffect-grpc/src/root.zig":
            content = re.sub(
                rb'\.content_sha256\s*=\s*"sha256:[0-9a-f]{64}"',
                b'.content_sha256 = "sha256:' + (b"0" * 64) + b'"',
                content,
            )
        hasher.update(content)
receipt = {
    "schema": "zigeffect.grpc-differential-benchmarks",
    "version": 1,
    "status": "passed",
    "complete": True,
    "source_sha256": hasher.hexdigest(),
    "host": {"system": platform.system(), "machine": platform.machine()},
    "methodology": {
        "transport": "plaintext HTTP/2 loopback through Docker port forwarding",
        "latency": "end-to-end client-observed per RPC",
        "cpu": "server cgroup usage_usec delta",
        "memory": "server cgroup current and peak bytes",
        "allocations": "runtime-instrumented server allocator delta",
        "source_binding": "implementation bytes with only the embedded conformance receipt digest normalized",
    },
    "targets": results,
}
with open(receipt_path, "w", encoding="utf-8") as output:
    json.dump(receipt, output, sort_keys=True)
    output.write("\n")
print(receipt_path)
PY

trap - EXIT
cleanup
