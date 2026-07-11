#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

build_files=(
  packages/zigeffect/build.zig
  packages/zigeffect-std/build.zig
  packages/zigeffect-postgres/build.zig
  packages/zigeffect-quic/build.zig
  packages/zigeffect-zio/build.zig
  packages/ziac/build.zig
  packages/zgroach/build.zig
)

for file in "${build_files[@]}"; do
  if ! grep -q 'test_runner = .{ .path = runner, .mode = .server }' "$file"; then
    printf 'Testing v2 migration missing server runner helper: %s\n' "$file" >&2
    exit 1
  fi
  if grep -Eq '^[[:space:]]*const [^=]+=[[:space:]]*b\.addTest\(' "$file"; then
    printf 'unmigrated direct b.addTest artifact: %s\n' "$file" >&2
    exit 1
  fi
done

printf 'Testing v2 migration guard passed (%s build files)\n' "${#build_files[@]}"
