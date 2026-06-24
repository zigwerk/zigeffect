#!/usr/bin/env bash
# tools/check_tool_hygiene.sh
# Anti-sprawl guardrail for packages/zigeffect/tools.
#
# Fails (exit 1) if any tools/*.zig file violates the hygiene rules that exist
# because an autonomous loop once generated ~120 near-duplicate "report about a
# report" tools, growing tools/ by ~178,000 lines while runtime src/ grew ~95.
#
# See packages/zigeffect/docs/tool-roadmap.md and AGENTS.md > Tool Hygiene Policy.
# Run from anywhere: it resolves its own directory.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PACKAGE_DIR/../.." && pwd)"

# --- Tunable limits -------------------------------------------------------
MAX_NAME_LEN=64        # max basename length WITHOUT the .zig extension
MAX_TOOL_FILES=60      # hard cap on number of tools/*.zig files
MAX_LINES=1200         # per-file line cap unless an allow-marker is present
MAX_REPORT_TOOL_FILES=8 # report-named tools are allowed, but not a new sprawl class
# A repeat of any of these filler tokens in one filename is a hard violation.
FILLER_TOKENS='report evaluation consumption remediation advisory boundary application integration production telemetry'
# Adjacent justification marker a human must add to exempt an oversized file:
#   //hygiene:allow-long-file reason=<short reason>
JUSTIFY_MARKER='hygiene:allow-long-file'
RUNTIME_ALLOW_MARKER='hygiene:allow-no-runtime-import'
# Approved pre-policy schema/report helpers that do not directly import the
# runtime facade. New tools should import zigeffect (or src/) unless a human adds
# RUNTIME_ALLOW_MARKER with a reason.
APPROVED_NO_RUNTIME_IMPORT='
causal_advice.zig
causal_app_application_readiness.zig
causal_app_apply.zig
causal_app_human_review.zig
causal_app_patch_proposal.zig
causal_app_policy_decision.zig
causal_app_remediation_audit.zig
causal_artifacts.zig
causal_audit_chain.zig
causal_compare.zig
causal_dev_agent.zig
causal_dev_session.zig
causal_diagnosis.zig
causal_handoff.zig
causal_loop.zig
causal_patch_proposal.zig
causal_policy_decision.zig
causal_query.zig
causal_registry_application_readiness.zig
causal_registry_apply.zig
causal_remediation_audit.zig
causal_remediation_decision.zig
causal_remediation_plan.zig
causal_scenario_proposal.zig
causal_scenario_registry_patch.zig
causal_schema_governance.zig
causal_snapshot.zig
causal_test_matrix.zig
causal_verdict.zig
causal_workbench.zig
causal_workbench_session.zig
release_gate_report.zig
scaffold_module.zig
'
# ------------------------------------------------------------------------

fail=0
problem() { printf 'TOOL HYGIENE VIOLATION: %s\n' "$1" >&2; fail=1; }

is_approved_no_runtime_import() {
  local name="$1"
  grep -qx "$name" <<<"$APPROVED_NO_RUNTIME_IMPORT"
}

shopt -s nullglob
files=("$TOOLS_DIR"/*.zig)
shopt -u nullglob

count=${#files[@]}
if (( count > MAX_TOOL_FILES )); then
  problem "tools/ contains $count .zig files, exceeding cap of $MAX_TOOL_FILES. A new tool must add runtime capability, not paperwork."
fi

report_tool_count=0

for path in "${files[@]}"; do
  f="$(basename "$path")"
  base="${f%.zig}"

  if printf '%s' "$base" | grep -Eq '(^|_)report($|_)'; then
    report_tool_count=$((report_tool_count + 1))
  fi

  # 1) Name length
  if (( ${#base} > MAX_NAME_LEN )); then
    problem "$f: name is ${#base} chars (max $MAX_NAME_LEN). Likely a recursive report-about-a-report name."
  fi

  # 2) Banned <number>_level_ counter series
  if printf '%s' "$base" | grep -Eq '_(two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen)_level_'; then
    problem "$f: matches banned '<number>_level_' counter series. These are auto-generated tier clones."
  fi

  # 3) Repeated single-word filler token (e.g. report ... report)
  for tok in $FILLER_TOKENS; do
    n=$(printf '%s' "$base" | tr '_' '\n' | grep -cx "$tok" || true)
    if (( n >= 2 )); then
      problem "$f: filler token '$tok' appears $n times. Report-about-a-report naming is banned."
      break
    fi
  done

  # 4) Any repeated bigram (e.g. evaluation_report twice)
  dup_bigram=$(printf '%s' "$base" | grep -oE '[a-z]+_[a-z]+' | sort | uniq -d | head -1 || true)
  if [ -n "$dup_bigram" ]; then
    problem "$f: bigram '$dup_bigram' repeats. Indicates a stacked/duplicated tool name."
  fi

  # 5) Per-file line cap unless an adjacent human justification marker exists
  lines=$(wc -l < "$path" | tr -d ' ')
  if (( lines > MAX_LINES )); then
    if grep -q "$JUSTIFY_MARKER" "$path"; then
      printf 'note: %s is %s lines but carries %s justification.\n' "$f" "$lines" "$JUSTIFY_MARKER"
    else
      problem "$f: $lines lines (max $MAX_LINES). If genuinely needed add a top-of-file comment: //$JUSTIFY_MARKER reason=<why>."
    fi
  fi

  # 6) Runtime capability check. A new tool must exercise the runtime rather than
  # only printing paperwork. Existing report/schema helpers are explicitly
  # grandfathered above; new exceptions require a human marker in the file.
  if ! grep -Eq '@import\("(zigeffect|\.\./src/|src/)' "$path"; then
    if is_approved_no_runtime_import "$f"; then
      :
    elif grep -q "$RUNTIME_ALLOW_MARKER" "$path"; then
      printf 'note: %s has no direct runtime import but carries %s justification.\n' "$f" "$RUNTIME_ALLOW_MARKER"
    else
      problem "$f: must import or explicitly exercise zigeffect runtime symbols from src/. Add a runtime import or a human //$RUNTIME_ALLOW_MARKER reason=<why> marker."
    fi
  fi
done

if (( report_tool_count > MAX_REPORT_TOOL_FILES )); then
  problem "tools/ contains $report_tool_count report-named tools, exceeding cap of $MAX_REPORT_TOOL_FILES. Extend existing runtime tools instead of growing generated-report surface."
fi

STALE_STATUS_PHRASES='
cluster transport is still in-process
live-attach collector endpoint, which is not yet built
engine-side live-attach collector endpoint, which is not yet built
workbench is static-only
static-only workbench
6 of 9 AsyncBackend methods still return
AsyncBackend methods still return error.Unsupported
zio backend is still a stub
scheduler-on-zio is future work
'

status_files=()
if [ -d "$PACKAGE_DIR/docs" ]; then
  while IFS= read -r -d '' path; do
    status_files+=("$path")
  done < <(find "$PACKAGE_DIR/docs" -type f -name '*.md' -print0)
fi

for candidate in \
  "$PACKAGE_DIR/README.md" \
  "$REPO_ROOT/AGENTS.md" \
  "$REPO_ROOT/CLAUDE.md" \
  "$REPO_ROOT/docs/superpowers/2026-06-24-future-agent-briefing.md" \
  "$REPO_ROOT/packages/zigeffect-zio/README.md"; do
  if [ -f "$candidate" ]; then
    status_files+=("$candidate")
  fi
done

for path in "${status_files[@]}"; do
  while IFS= read -r phrase; do
    [ -n "$phrase" ] || continue
    if grep -Fq "$phrase" "$path"; then
      rel="${path#$REPO_ROOT/}"
      problem "$rel: stale status claim '$phrase'. Update the current-status doc instead of preserving a future/not-yet contradiction."
    fi
  done <<<"$STALE_STATUS_PHRASES"
done

if (( fail )); then
  printf '\nTool hygiene check FAILED. See AGENTS.md > Tool Hygiene Policy.\n' >&2
  exit 1
fi
printf 'Tool hygiene check passed: %s tool file(s), all within limits.\n' "$count"
