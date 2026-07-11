#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
requests="${ZIGEFFECT_REFERENCE_LOAD_REQUESTS:-25}"
max_seconds="${ZIGEFFECT_REFERENCE_LOAD_MAX_SECONDS:-30}"

cd "$root"
ZIGEFFECT_REFERENCE_REQUESTS="$requests" \
ZIGEFFECT_REFERENCE_MAX_WORKLOAD_SECONDS="$max_seconds" \
  bash test/run_process_stack.sh
