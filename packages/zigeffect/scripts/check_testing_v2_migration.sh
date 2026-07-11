#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

build_files=(
  packages/zigeffect/build.zig
  packages/zigeffect-std/build.zig
  packages/zigeffect-cli/build.zig
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

template_file=packages/zigeffect-cli/src/templates.zig
template_tests="$(grep -c 'const tests = b.addTest' "$template_file")"
template_v2_tests="$(grep 'const tests = b.addTest' "$template_file" | grep -c 'test_runner = .{ .path = testing_runner, .mode = .server }')"
if [[ "$template_tests" -eq 0 || "$template_tests" -ne "$template_v2_tests" ]]; then
  printf 'generated project template contains an unmigrated test artifact (%s/%s migrated)\n' "$template_v2_tests" "$template_tests" >&2
  exit 1
fi

printf 'Testing v2 migration guard passed (%s build files, %s generated templates)\n' "${#build_files[@]}" "$template_v2_tests"
