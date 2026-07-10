#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:test
bun run zigeffect:workbench:build
bun run zigeffect:std:test
bun run zigeffect:cli:test

(
  cd packages/zigeffect
  zig build test --summary all
  zig build test-raw
)

bash packages/zigeffect/tools/check_tool_hygiene.sh
git diff --check

echo "local agentic development gate passed"
