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

# --- Tunable limits -------------------------------------------------------
MAX_NAME_LEN=64        # max basename length WITHOUT the .zig extension
MAX_TOOL_FILES=60      # hard cap on number of tools/*.zig files
MAX_LINES=1200         # per-file line cap unless an allow-marker is present
# A repeat of any of these filler tokens in one filename is a hard violation.
FILLER_TOKENS='report evaluation consumption remediation advisory boundary application integration production telemetry'
# Adjacent justification marker a human must add to exempt an oversized file:
#   //hygiene:allow-long-file reason=<short reason>
JUSTIFY_MARKER='hygiene:allow-long-file'
# ------------------------------------------------------------------------

fail=0
problem() { printf 'TOOL HYGIENE VIOLATION: %s\n' "$1" >&2; fail=1; }

shopt -s nullglob
files=("$TOOLS_DIR"/*.zig)
shopt -u nullglob

count=${#files[@]}
if (( count > MAX_TOOL_FILES )); then
  problem "tools/ contains $count .zig files, exceeding cap of $MAX_TOOL_FILES. A new tool must add runtime capability, not paperwork."
fi

for path in "${files[@]}"; do
  f="$(basename "$path")"
  base="${f%.zig}"

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
done

if (( fail )); then
  printf '\nTool hygiene check FAILED. See AGENTS.md > Tool Hygiene Policy.\n' >&2
  exit 1
fi
printf 'Tool hygiene check passed: %s tool file(s), all within limits.\n' "$count"
