#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
root="$(CDPATH= cd -- "$script_dir/.." && pwd)"
reference="$(CDPATH= cd -- "$root/../references/graphify" && pwd)"
expected_commit="cb96bdaa0c367bec8d5c5aee5d7c9ebb727e9780"
expected_version="0.9.17"
environment="${ZGRAPHY_GRAPHIFY_ENV:-$root/.zgraphy/benchmarks/graphify-0.9.17}"
graphify="${GRAPHIFY_BIN:-$environment/bin/graphify}"
python="${GRAPHIFY_PYTHON:-$environment/bin/python}"
zgraphy="${ZGRAPHY_BIN:-$root/zig-out/bin/zgraphy}"

actual_commit="$(git -C "$reference" rev-parse HEAD)"
if [[ "$actual_commit" != "$expected_commit" ]]; then
  echo "Graphify reference mismatch: expected $expected_commit, found $actual_commit" >&2
  exit 2
fi

if [[ ! -x "$graphify" || ! -x "$python" ]]; then
  echo "Graphify benchmark environment missing at $environment; follow benchmarks/README.md" >&2
  exit 2
fi
if [[ ! -x "$zgraphy" ]]; then
  echo "ReleaseSafe zgraphy binary missing; run: zig build install -Doptimize=ReleaseSafe" >&2
  exit 2
fi

actual_version="$($python -c 'from importlib.metadata import version; print(version("graphifyy"))')"
if [[ "$actual_version" != "$expected_version" ]]; then
  echo "Graphify package mismatch: expected $expected_version, found $actual_version" >&2
  exit 2
fi

cd "$root"

run_fixture() {
  local fixture_id="$1"
  local target="$2"
  local output_root=".zgraphy/benchmarks/runs/graphify/$fixture_id"
  env \
    -u ANTHROPIC_API_KEY \
    -u AZURE_OPENAI_API_KEY \
    -u DEEPSEEK_API_KEY \
    -u GEMINI_API_KEY \
    -u GOOGLE_API_KEY \
    -u GRAPHIFY_OUT \
    -u MOONSHOT_API_KEY \
    -u OPENAI_API_KEY \
    "$graphify" extract "$target" \
      --code-only \
      --no-cluster \
      --force \
      --timing \
      --out "$output_root" 1>&2
  "$zgraphy" benchmark graphify "$fixture_id" "$output_root/graphify-out/graph.json" --json
}

run_fixture "zig-ambiguity" "benchmarks/fixtures/zig-ambiguity"
run_fixture "fullstack-orders" "benchmarks/fixtures/fullstack-orders"
run_fixture "mutation-pruning" "benchmarks/fixtures/mutation-pruning/baseline"

source_revision="$(find src test benchmarks build.zig build.zig.zon zigeffect.project.json -type f \
  ! -path 'benchmarks/baselines/*' \
  ! -path '*/.zgraphy/*' \
  -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 | shasum -a 256 | awk '{print "sha256:" $1}')"
python_version="$($python -c 'import platform; print(platform.python_version())')"
environment_digest="$($python -m pip freeze | shasum -a 256 | awk '{print "sha256:" $1}')"

"$zgraphy" benchmark matrix \
  --source-revision "$source_revision" \
  --graphify-python "$python_version" \
  --graphify-environment "$environment_digest" \
  --json
