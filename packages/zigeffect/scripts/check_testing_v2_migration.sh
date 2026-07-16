#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

mapfile_compat() {
  local output_var="$1"
  shift
  local values=()
  while IFS= read -r value; do values+=("$value"); done < <("$@")
  eval "$output_var=(\"\${values[@]}\")"
}

list_build_files() {
  git ls-files '**/build.zig' |
    grep -Ev '^(packages/references/|.*/(zig-pkg|zig-out|\.zig-cache)/)'
}

mapfile_compat build_files list_build_files
checked=0
for file in "${build_files[@]}"; do
  if ! grep -q 'b\.addTest(' "$file"; then
    continue
  fi
  checked=$((checked + 1))
  if ! grep -q 'test_runner' "$file" || ! grep -q '\.mode = \.server' "$file"; then
    printf 'Testing v2 server runner missing from tracked test build: %s\n' "$file" >&2
    exit 1
  fi
  if ! grep -q 'zigeffect_test_runner' "$file"; then
    printf 'Testing v2 runner must come from an exported dependency module: %s\n' "$file" >&2
    exit 1
  fi
done

template_file=packages/zigeffect-cli/src/templates.zig
template_tests="$(grep -c 'const tests = b.addTest(test_options)' "$template_file")"
template_v2_tests="$(grep -c 'var test_options = std.Build.TestOptions{.*test_runner = .{ .path = testing_runner, .mode = .server }' "$template_file")"
if [[ "$template_tests" -eq 0 || "$template_tests" -ne "$template_v2_tests" ]]; then
  printf 'generated project template contains an unmigrated test artifact (%s/%s migrated)\n' "$template_v2_tests" "$template_tests" >&2
  exit 1
fi

printf 'Testing v2 migration guard passed (%s tracked test builds, %s generated templates).\n' "$checked" "$template_v2_tests"
