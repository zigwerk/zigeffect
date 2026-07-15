#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "$0")/.." && pwd)"
python="${1:-python3}"
duration="${GRPC_SOAK_SECONDS:-86400}"
receipt="${GRPC_LOAD_RECEIPT:-/tmp/zigeffect-grpc-24h-soak.json}"

if ! [[ "$duration" =~ ^[0-9]+$ ]] || (( duration < 86400 )); then
  echo "GRPC_SOAK_SECONDS must be at least 86400 for release qualification" >&2
  exit 2
fi

GRPC_SOAK_SECONDS="$duration" \
GRPC_LOAD_CALLS="${GRPC_LOAD_CALLS:-100000}" \
GRPC_LOAD_WORKERS="${GRPC_LOAD_WORKERS:-64}" \
GRPC_MAX_MEMORY_GROWTH_BYTES="${GRPC_MAX_MEMORY_GROWTH_BYTES:-67108864}" \
GRPC_LOAD_RECEIPT="$receipt" \
  "$package_root/tests/run_cloud_run_container.sh" "$python"

"$python" - "$receipt" "$duration" <<'PY'
import json
import sys

path, required_duration = sys.argv[1], float(sys.argv[2])
with open(path, encoding="utf-8") as source:
    receipt = json.load(source)
if receipt.get("failures") != 0:
    raise SystemExit("24-hour soak reported failures")
if receipt.get("elapsed_seconds", 0) < required_duration:
    raise SystemExit("24-hour soak ended before its required duration")
if not receipt.get("memory", {}).get("qualified", False):
    raise SystemExit("24-hour soak did not satisfy the memory bound")
shapes = receipt.get("completed_by_shape", {})
required_shapes = {
    "unary",
    "client_streaming",
    "server_streaming",
    "bidirectional_streaming",
}
if set(shapes) != required_shapes or any(shapes[name] <= 0 for name in required_shapes):
    raise SystemExit("24-hour soak did not exercise every gRPC call shape")
receipt["qualification"] = {
    "kind": "mixed-shape-24h",
    "complete": True,
    "required_seconds": required_duration,
}
with open(path, "w", encoding="utf-8") as output:
    json.dump(receipt, output, sort_keys=True)
    output.write("\n")
print(path)
PY
