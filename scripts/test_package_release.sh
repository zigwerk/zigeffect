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

for package in zigeffect zigeffect-std zigeffect-postgres; do
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

expected="$(awk -F '\t' '$1 == "zigeffect-std-0.1.0.tar.gz" { print $2 }' "$output/manifest.tsv")"
actual="$(cd "$root/packages/zigeffect" && zig fetch "$output/zigeffect-std-0.1.0.tar.gz")"
test "$actual" = "$expected"

echo "ZigEffect release package test passed."
