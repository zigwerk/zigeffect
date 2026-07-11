#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
iterations="${ZIGEFFECT_REFERENCE_SOAK_ITERATIONS:-3}"
requests="${ZIGEFFECT_REFERENCE_SOAK_REQUESTS:-10}"

for iteration in $(seq 1 "$iterations"); do
  echo "reference soak iteration ${iteration}/${iterations}"
  ZIGEFFECT_REFERENCE_REQUESTS="$requests" \
  ZIGEFFECT_REFERENCE_MAX_WORKLOAD_SECONDS=30 \
    bash "$root/test/run_process_stack.sh"
done
