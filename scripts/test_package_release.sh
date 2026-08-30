#!/usr/bin/env bash

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
packager="$root/scripts/package_release.sh"

if [[ ! -x "$packager" ]]; then
  echo "release packager is missing or not executable: $packager" >&2
  exit 1
fi

output="$(mktemp -d)"
trap 'rm -rf "$output"' EXIT

"$packager" 0.1.0 "$output"

for package in zigeffect zigeffect-std zigeffect-postgres zgdb zgroach zgraphy zigeffect-cli; do
  asset="$output/${package}-0.1.0.tar.gz"
  test -f "$asset"
  grep -q "^${package}-0.1.0.tar.gz"$'\t' "$output/manifest.tsv"
done

expanded="$output/expanded"
mkdir -p "$expanded"
tar -xzf "$output/zigeffect-std-0.1.0.tar.gz" -C "$expanded"
zon="$(find "$expanded" -name build.zig.zon -type f -maxdepth 2 -print -quit)"

test -n "$zon"
if grep -q '\.path = "\.\./zigeffect"' "$zon"; then
  echo "published zigeffect-std package retained a monorepo path dependency" >&2
  exit 1
fi
grep -q 'https://github.com/zigwerk/zigeffect/releases/download/v0.1.0/zigeffect-0.1.0.tar.gz' "$zon"

cli_expanded="$output/cli-expanded"
mkdir -p "$cli_expanded"
tar -xzf "$output/zigeffect-cli-0.1.0.tar.gz" -C "$cli_expanded"
catalog="$(find "$cli_expanded" -name release_catalog.zig -type f -print -quit)"
test -n "$catalog"
grep -q 'pub const cli_version = "0.1.0";' "$cli_expanded/zigeffect-cli-0.1.0/src/distribution.zig"
grep -q 'pub const embedded = zstd.Project.DependencyRelease' "$catalog"
grep -q 'zgraphy-0.1.0.tar.gz' "$catalog"
grep -q 'zigeffect-std-0.1.0.tar.gz' "$catalog"
if grep -q '0.0.0-development' "$catalog"; then
  echo "published CLI retained the development release catalog" >&2
  exit 1
fi
cli_root="$cli_expanded/zigeffect-cli-0.1.0"
cli_install="$output/cli-install"
(cd "$cli_root" && zig build -Doptimize=ReleaseSafe --prefix "$cli_install")
"$cli_install/bin/zigeffect" create release-smoke --target "$output/release-smoke" --dry-run >/dev/null

zgraphy_expanded="$output/zgraphy-expanded"
mkdir -p "$zgraphy_expanded"
tar -xzf "$output/zgraphy-0.1.0.tar.gz" -C "$zgraphy_expanded"
zgraphy_zon="$(find "$zgraphy_expanded" -name build.zig.zon -type f -maxdepth 2 -print -quit)"
test -n "$zgraphy_zon"
if grep -q '\.path = "\.\./' "$zgraphy_zon"; then
  echo "published zgraphy package retained a monorepo path dependency" >&2
  exit 1
fi
grep -q '"benchmarks"' "$zgraphy_zon"
zgraphy_cache="$output/zgraphy-cache"
zgraphy_hash="$(cd "$root/packages/zigeffect" && zig fetch --global-cache-dir "$zgraphy_cache" "$output/zgraphy-0.1.0.tar.gz")"
zgraphy_cached_archive="$zgraphy_cache/p/${zgraphy_hash}.tar.gz"
test -f "$zgraphy_cached_archive"
tar -tzf "$zgraphy_cached_archive" | grep '/benchmarks/embedded\.zig$' >/dev/null

expected="$(awk -F '\t' '$1 == "zigeffect-std-0.1.0.tar.gz" { print $2 }' "$output/manifest.tsv")"
actual="$(cd "$root/packages/zigeffect" && zig fetch "$output/zigeffect-std-0.1.0.tar.gz")"
test "$actual" = "$expected"

echo "ZigEffect release package test passed."
