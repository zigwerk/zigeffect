#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
INSTALL_PREFIX="$(mktemp -d "${TMPDIR:-/tmp}/zigeffect-release.XXXXXX")"
PROOF_PARENT="$ROOT_DIR/.zig-cache/zigeffect-release-proof.$$"
trap 'rm -rf "$INSTALL_PREFIX" "$PROOF_PARENT"' EXIT
cd "$ROOT_DIR"

ZIG_VERSION="$(zig version)"
case "$ZIG_VERSION" in
  0.16.*) ;;
  *) printf 'unsupported Zig version: %s (expected >= 0.16.0 and < 0.17.0)\n' "$ZIG_VERSION" >&2; exit 1 ;;
esac

bash packages/zigeffect/scripts/check_testing_v2_migration.sh

printf '== zigeffect stdlib ==\n'
(
  cd packages/zigeffect-std
  zig build test --summary all
  zig build examples --summary all
)

printf '== zigeffect CLI, install, scaffolds, and provider fixtures ==\n'
(
  cd packages/zigeffect-cli
  zig build test --summary all
  zig build integration-test --summary all
  zig build install --prefix "$INSTALL_PREFIX"
)
ZIGEFFECT_BIN="$INSTALL_PREFIX/bin/zigeffect"
test -x "$ZIGEFFECT_BIN"
test "$($ZIGEFFECT_BIN --version)" = "zigeffect 0.5.0"
for shell in bash zsh fish; do
  "$ZIGEFFECT_BIN" completions "$shell" > "$INSTALL_PREFIX/$shell.completion"
  test -s "$INSTALL_PREFIX/$shell.completion"
done
"$ZIGEFFECT_BIN" compatibility --json | jq -e '.compatible == true and .cli_version == "0.5.0"' > /dev/null
"$ZIGEFFECT_BIN" benchmark conformance \
  packages/zigeffect/benchmarks/fixtures/provider-conformance.v1.json \
  --root . --json | jq -e '.complete_provider_matrix == true and .passed == 14 and .failed == 0' > /dev/null
jq -e '.schema == "zigeffect.scaffold-contract-snapshot.v1" and (.cases | length) == 5' \
  packages/zigeffect-cli/src/snapshots/scaffold-contracts.v1.json > /dev/null

printf '== generated application Testing v2 proof ==\n'
mkdir -p "$PROOF_PARENT"
(
  cd "$PROOF_PARENT"
  "$ZIGEFFECT_BIN" new application release-proof \
    --target release-proof \
    --zigeffect-path ../../../packages/zigeffect \
    --zigeffect-std-path ../../../packages/zigeffect-std \
    --json | jq -e '.written > 0' > /dev/null
  "$ZIGEFFECT_BIN" project validate --root release-proof --json | jq -e '.status == "passed"' > /dev/null
  "$ZIGEFFECT_BIN" test list --root release-proof --json | jq -e '.selected == 1' > /dev/null
  "$ZIGEFFECT_BIN" test run --root release-proof --requirement req-bootstrap --json | jq -e '.status == "passed" and .receipts[0].execution.native_receipt == true' > /dev/null
  jq -e '.schema == "zigeffect.test-suite-receipt.v2" and .status == "passed" and .complete == true and .counts.discovered == .counts.executed and .counts.leaks == 0 and .counts.log_errors == 0' \
    release-proof/.zigeffect/tests/suites/release-proof-tests.json > /dev/null
  "$ZIGEFFECT_BIN" test coverage --root release-proof --requirement req-bootstrap --json | jq -e '.required_gaps == 0' > /dev/null
  "$ZIGEFFECT_BIN" test gaps --root release-proof --requirement req-bootstrap --json | jq -e '.required_gaps == 0' > /dev/null
  "$ZIGEFFECT_BIN" test replay bootstrap-boundaries --root release-proof --seed 42 --fault none:0 --json | jq -e '.status == "passed"' > /dev/null
  "$ZIGEFFECT_BIN" test stress --root release-proof --requirement req-bootstrap --runs 2 --seed 100 --json | jq -e '.failed_runs == 0 and .passed_runs == 2' > /dev/null
  "$ZIGEFFECT_BIN" test history --root release-proof --json | jq -e '.count >= 4' > /dev/null
  "$ZIGEFFECT_BIN" project check --root release-proof --agent --json | jq -e '.verdict == "passed"' > /dev/null
  "$ZIGEFFECT_BIN" agent handoff --root release-proof --provider codex --session release-proof --json | jq -e '.schema == "zigeffect.agent-handoff.v1"' > /dev/null
)
printf 'generated application Testing v2 proof passed\n'

printf '== zigeffect core ==\n'
(
  cd packages/zigeffect
  zig build test-raw --summary all
  zig build test-raw -Doptimize=ReleaseSafe --summary all
  zig build public-api-review --summary all
  zig build release-gate --summary all
)

printf '== local adapters ==\n'
(
  cd packages/zigeffect-postgres
  zig build test --summary all
  zig build examples --summary all
)
(
  cd packages/zigeffect-quic
  zig build test --summary all
  zig build examples --summary all
)
(
  cd packages/zigeffect-zio
  zig build test --summary all
)
(
  cd packages/ziac
  zig build test --summary all
  zig build examples --summary all
)
(
  cd packages/zgroach
  zig build test --summary all
)

printf '== workbench ==\n'
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:test
bun run zigeffect:workbench:build

printf '== honesty, redaction, and repository hygiene ==\n'
bash packages/zigeffect/tools/check_tool_hygiene.sh
if sed -n '/### M88/,/## Hardening milestone roadmap/p' packages/zigeffect/docs/roadmap.md | grep -Eq '\*\*Status:\*\* (planned|active)'; then
  printf 'M88-M95 contains a stale planned/active status\n' >&2
  exit 1
fi
git diff --check

printf 'zigeffect local release gate passed (Zig %s, CLI 0.5.0)\n' "$ZIG_VERSION"
