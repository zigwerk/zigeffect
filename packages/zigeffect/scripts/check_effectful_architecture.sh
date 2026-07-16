#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

POLICY="packages/zigeffect/docs/effectful-package-policy.json"
jq -e '.schema == "zigeffect.effectful-package-policy.v1" and .schema_version == 1' "$POLICY" >/dev/null
legacy="$(jq -r '.forbidden_regex | join("|")' "$POLICY")"

strict_paths=()
while IFS= read -r target; do strict_paths+=("$target"); done < <(jq -r '.canonical_paths[]' "$POLICY")

if violations="$(rg -n "$legacy" "${strict_paths[@]}" -g '*.zig' || true)" && [[ -n "$violations" ]]; then
  printf 'Legacy environment-shaped API found in a canonical gRPC surface:\n%s\n' "$violations" >&2
  exit 1
fi

while IFS=$'\t' read -r file symbol; do
  if ! rg -q -F "$symbol" "$file"; then
    printf 'Canonical architecture contract missing: %s in %s\n' "$symbol" "$file" >&2
    exit 1
  fi
done < <(jq -r '.required_contracts[] | [.path, .symbol] | @tsv' "$POLICY")

# Legacy packages are migrated incrementally. These ceilings are ratchets: a
# migration may lower them, but no change may add a new environment-shaped
# dependency boundary while the remaining consumers are being deleted.
while IFS=$'\t' read -r target ceiling; do
  count="$( (rg -n "$legacy" "$target" -g '*.zig' 2>/dev/null || true) | wc -l | tr -d ' ')"
  if (( count > ceiling )); then
    printf 'Effectful architecture ratchet regressed: %s has %s legacy references (ceiling %s)\n' "$target" "$count" "$ceiling" >&2
    exit 1
  fi
  printf '%-48s %4s / %s legacy references\n' "$target" "$count" "$ceiling"
done < <(jq -r '.ratchets[] | [.path, .maximum] | @tsv' "$POLICY")

printf 'Effectful architecture guard passed; canonical gRPC surfaces are legacy-free.\n'
bash packages/zigeffect/scripts/check_agent_skill_sync.sh
