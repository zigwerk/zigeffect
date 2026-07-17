#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

POLICY="packages/zigeffect/docs/effectful-package-policy.json"
jq -e '.schema == "zigeffect.effectful-package-policy.v2" and .schema_version == 2' "$POLICY" >/dev/null

legacy="$(jq -r '.forbidden_regex | join("|")' "$POLICY")"
application_forbidden="$(jq -r '.application_forbidden_regex | join("|")' "$POLICY")"

canonical_paths=()
while IFS= read -r target; do canonical_paths+=("$target"); done < <(jq -r '.canonical_source_paths[]' "$POLICY")

if violations="$(rg -n "$legacy" "${canonical_paths[@]}" -g '*.zig' || true)" && [[ -n "$violations" ]]; then
  printf 'Legacy environment-shaped API found in canonical package source:\n%s\n' "$violations" >&2
  exit 1
fi

application_paths=()
while IFS= read -r target; do application_paths+=("$target"); done < <(jq -r '.application_paths[]' "$POLICY")
application_globs=(-g '*.zig')
while IFS= read -r pattern; do application_globs+=(-g "$pattern"); done < <(jq -r '.application_excluded_globs[]? // empty' "$POLICY")

if violations="$(rg -n "$application_forbidden" "${application_paths[@]}" "${application_globs[@]}" || true)" && [[ -n "$violations" ]]; then
  printf 'Application source manually owns a low-level runtime or causal backend:\n%s\n' "$violations" >&2
  exit 1
fi

template_path="$(jq -r '.generated_application_template.path' "$POLICY")"
template_start="$(jq -r '.generated_application_template.start' "$POLICY")"
template_end="$(jq -r '.generated_application_template.end' "$POLICY")"
template_source="$(awk -v start="$template_start" -v end="$template_end" '
  index($0, start) { active = 1 }
  active && index($0, end) { exit }
  active { print }
' "$template_path")"
if violations="$(printf '%s\n' "$template_source" | rg -n "$application_forbidden" || true)" && [[ -n "$violations" ]]; then
  printf 'Generated production application manually owns a low-level runtime or causal backend:\n%s\n' "$violations" >&2
  exit 1
fi

while IFS=$'\t' read -r file symbol; do
  if ! rg -q -F "$symbol" "$file"; then
    printf 'Canonical architecture contract missing: %s in %s\n' "$symbol" "$file" >&2
    exit 1
  fi
done < <(jq -r '.required_contracts[] | [.path, .symbol] | @tsv' "$POLICY")

printf 'Effectful architecture guard passed across %s canonical source roots.\n' "${#canonical_paths[@]}"
bash packages/zigeffect/scripts/check_agent_skill_sync.sh
