#!/usr/bin/env bash
# Regression tests for check_tool_hygiene.sh. These tests intentionally create
# temporary tool files in this directory, then remove them before exiting.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/check_tool_hygiene.sh"
DOCS_DIR="$(cd "$SCRIPT_DIR/../docs" && pwd)"
TMP_REPORT_ONLY_TOOL="$SCRIPT_DIR/zz_hygiene_tmp_clean_report_only.zig"
TMP_REPEATED_REPORT_TOOL="$SCRIPT_DIR/zz_hygiene_tmp_report_report.zig"
TMP_STALE_DOC="$DOCS_DIR/zz_hygiene_tmp_stale_status.md"
OUT="/tmp/zigeffect-hygiene-test.out"
ERR="/tmp/zigeffect-hygiene-test.err"

cleanup() {
  rm -f "$TMP_REPORT_ONLY_TOOL" "$TMP_REPEATED_REPORT_TOOL" "$TMP_STALE_DOC"
}
trap cleanup EXIT

expect_hygiene_failure() {
  local expected="$1"
  if "$CHECK" >"$OUT" 2>"$ERR"; then
    echo "expected hygiene check to fail: $expected" >&2
    cat "$OUT" >&2 || true
    cat "$ERR" >&2 || true
    exit 1
  fi

  if ! grep -q "$expected" "$ERR"; then
    echo "hygiene failed for the wrong reason; wanted: $expected" >&2
    cat "$ERR" >&2 || true
    exit 1
  fi
}

cat > "$TMP_REPORT_ONLY_TOOL" <<'ZIG'
const std = @import("std");

pub fn main() void {
    std.debug.print("this only prints a report\n", .{});
}
ZIG

expect_hygiene_failure "must import or explicitly exercise zigeffect runtime symbols"
rm -f "$TMP_REPORT_ONLY_TOOL"

cat > "$TMP_REPEATED_REPORT_TOOL" <<'ZIG'
const fx = @import("../src/zigeffect.zig");

pub fn main() void {
    _ = fx.CausalEventKind.run_started;
}
ZIG

expect_hygiene_failure "filler token 'report' appears"
rm -f "$TMP_REPEATED_REPORT_TOOL"

cat > "$TMP_STALE_DOC" <<'MD'
# temporary stale status fixture

The scheduler runs on zio; the cluster transport is still in-process.
MD

expect_hygiene_failure "stale status claim"
rm -f "$TMP_STALE_DOC"

echo "check_tool_hygiene_test passed"
