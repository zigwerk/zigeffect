#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

same() {
  if ! cmp -s "$1" "$2"; then
    printf 'Agent/skill copy drift: %s != %s\n' "$1" "$2" >&2
    exit 1
  fi
}

requires() {
  local file="$1"
  shift
  for contract in "$@"; do
    if ! rg -q -F "$contract" "$file"; then
      printf 'Proof-loop contract missing from %s: %s\n' "$file" "$contract" >&2
      exit 1
    fi
  done
}

same .agents/skills/zigeffect-development/SKILL.md .claude/skills/zigeffect-development/SKILL.md
same packages/zigeffect-reference-system/.agents/skills/zigeffect-development/SKILL.md packages/zigeffect-reference-system/.claude/skills/zigeffect-development/SKILL.md
same packages/zgraphy/.agents/skills/zigeffect-development/SKILL.md packages/zgraphy/.claude/skills/zigeffect-development/SKILL.md
same .agents/skills/ziac/SKILL.md .claude/skills/ziac/SKILL.md
same .agents/skills/ziac/SKILL.md .gemini/skills/ziac/SKILL.md

for skill in ziac-provider-development ziac-provider-maintenance ziac-provider-qualification; do
  canonical="packages/ziac/src/agent-kit/skills/$skill/SKILL.md"
  same "$canonical" ".agents/skills/$skill/SKILL.md"
  same "$canonical" ".claude/skills/$skill/SKILL.md"
  same "$canonical" ".gemini/skills/$skill/SKILL.md"
  same "packages/ziac/src/agent-kit/skills/$skill/agents/openai.yaml" ".agents/skills/$skill/agents/openai.yaml"
  requires "$canonical" "project-mounted graph"
done

for harness in codex claude gemini; do
  extension=md
  [[ "$harness" == codex ]] && extension=toml
  for role in creator maintainer qualifier; do
    name="ziac-provider-$role.$extension"
    same "packages/ziac/src/agent-kit/agents/$harness/$name" ".$harness/agents/$name"
  done
done

proof_contracts=(
  "zigeffect agent context"
  ".zigeffect/tests/process-receipts/"
  ".zigeffect/tests/raw-receipts/"
  ".zigeffect/handoffs/tests/"
  "zigeffect graph path"
  "work packet"
  "fencing token"
  "project-mounted graph"
)
requires .agents/skills/zigeffect-development/SKILL.md "${proof_contracts[@]}"
requires .gemini/skills/zigeffect-development/SKILL.md "${proof_contracts[@]}"
requires packages/zigeffect-reference-system/.agents/skills/zigeffect-development/SKILL.md "${proof_contracts[@]}"
requires packages/zgraphy/.agents/skills/zigeffect-development/SKILL.md "${proof_contracts[@]}"
requires packages/zgraphy/.gemini/skills/zigeffect-development/SKILL.md "${proof_contracts[@]}"
requires .agents/skills/ziac/SKILL.md "ziac_context" "${proof_contracts[@]}"

causal_ownership_contracts=(
  "CausalStore.init*"
  "ctx.recordCausal"
  "test injection"
)
requires .agents/skills/zigeffect-development/SKILL.md "${causal_ownership_contracts[@]}"
requires .claude/skills/zigeffect-development/SKILL.md "${causal_ownership_contracts[@]}"
requires .gemini/skills/zigeffect-development/SKILL.md "${causal_ownership_contracts[@]}"
requires packages/zigeffect-reference-system/.agents/skills/zigeffect-development/SKILL.md "${causal_ownership_contracts[@]}"
requires packages/zigeffect-reference-system/.claude/skills/zigeffect-development/SKILL.md "${causal_ownership_contracts[@]}"
requires .agents/skills/ziac/SKILL.md "CausalStore.init*" "recorders threaded through" "provider APIs as product-code defects"
requires packages/ziac/src/scaffold.zig "CausalStore.init*" "Test-only injection"
requires packages/zigeffect-cli/src/templates.zig "CausalStore.init*" "Test-only injection"
requires packages/ziac/src/agent-kit/skills/ziac-provider-development/SKILL.md "must not construct causal stores"
requires packages/ziac/src/agent-kit/skills/ziac-provider-maintenance/SKILL.md "not add causal stores"
requires packages/ziac/src/agent-kit/skills/ziac-provider-qualification/SKILL.md "constructs causal stores"
requires packages/zigeffect/docs/runtime-owned-causal-applications.md "application code must not manually record"

cli_template_version="$(sed -n 's/^pub const template_version: u32 = \([0-9][0-9]*\);$/\1/p' packages/zigeffect-cli/src/distribution.zig)"
if [[ -z "$cli_template_version" ]]; then
  printf 'Unable to read the ZigEffect CLI template version.\n' >&2
  exit 1
fi
requires packages/ziac/src/scaffold.zig "\"template_version\":${cli_template_version}"

printf 'Agent/skill synchronization guard passed.\n'
