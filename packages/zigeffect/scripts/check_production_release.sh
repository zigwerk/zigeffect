#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/../../.." && pwd)"
lane="${1:-full}"

run_zig() {
  local package="$1"
  shift
  echo "release gate: ${package} $*"
  (cd "$repo/packages/$package" && zig build "$@" --summary all)
}

unit_lane() {
  "$repo/packages/zigeffect/tools/check_tool_hygiene.sh"
  "$repo/packages/zigeffect/scripts/check_testing_v2_migration.sh"
  "$repo/packages/zigeffect/scripts/check_production_evidence.sh"

  run_zig zigeffect test-raw -Doptimize=Debug
  run_zig zigeffect test-raw -Doptimize=ReleaseSafe
  run_zig zigeffect-std test -Doptimize=Debug
  run_zig zigeffect-std test -Doptimize=ReleaseSafe
  run_zig zigeffect-cli test -Doptimize=Debug
  run_zig zigeffect-cli test -Doptimize=ReleaseSafe

  for package in zigeffect-http zigeffect-http-tls-openssl zigeffect-postgres-libpq zigeffect-storage-postgres zigeffect-transport zigeffect-otel zigeffect-redis zigeffect-s3; do
    run_zig "$package" test -Doptimize=Debug
    run_zig "$package" test -Doptimize=ReleaseSafe
  done

  run_zig zigeffect-reference-system test -Doptimize=Debug
  run_zig zigeffect-reference-system test -Doptimize=ReleaseSafe
  run_zig zigeffect-reference-system fault-matrix -Doptimize=ReleaseSafe
  run_zig zigeffect-cli integration-test

  (cd "$repo" && bun run zigeffect:workbench:typecheck && bun run zigeffect:workbench:test && bun run zigeffect:workbench:build)
}

live_lane() {
  (cd "$repo/packages/zigeffect-postgres-libpq" && bash tests/run_postgres_conformance.sh && bash tests/run_cockroach_conformance.sh)
  (cd "$repo/packages/zigeffect-storage-postgres" && bash tests/run_postgres_conformance.sh && bash tests/run_cockroach_conformance.sh && bash tests/run_postgres_restart_conformance.sh && bash tests/run_cockroach_restart_conformance.sh && bash tests/run_cockroach_failover_conformance.sh)
  (cd "$repo/packages/zigeffect-redis" && bash tests/run_conformance.sh)
  (cd "$repo/packages/zigeffect-s3" && bash tests/run_conformance.sh)
  (cd "$repo/packages/zigeffect-reference-system" && bash test/run_live_stack.sh && bash test/run_process_stack.sh && bash test/run_load_conformance.sh)
  "$repo/packages/zigeffect/scripts/check_production_evidence.sh"
}

case "$lane" in
  unit) unit_lane ;;
  live) live_lane ;;
  full) unit_lane; live_lane ;;
  *) echo "usage: $0 [unit|live|full]" >&2; exit 2 ;;
esac
