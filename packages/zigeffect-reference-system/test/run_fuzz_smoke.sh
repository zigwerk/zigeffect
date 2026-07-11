#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cases="${ZIGEFFECT_FUZZ_SMOKE_CASES:-1000}"
[[ "$cases" =~ ^[0-9]+$ && "$cases" -ge 1 && "$cases" -le 100000 ]]
cd "$root/zigeffect-http"
zig build test --fuzz="$cases" --test-timeout 5m --summary all
