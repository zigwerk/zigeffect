#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
iterations="${ZIGEFFECT_DATABASE_STRESS_ITERATIONS:-3}"
[[ "$iterations" =~ ^[0-9]+$ && "$iterations" -ge 1 && "$iterations" -le 100 ]]

for iteration in $(seq 1 "$iterations"); do
  echo "database stress iteration ${iteration}/${iterations}"
  (cd "$root" && bash tests/run_postgres_conformance.sh)
  (cd "$root" && bash tests/run_cockroach_conformance.sh)
done
