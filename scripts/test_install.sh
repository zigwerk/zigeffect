#!/usr/bin/env bash

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
installer="$root/install.sh"
workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT

version="9.8.7"
release="$workspace/release"
package="$workspace/zigeffect-cli-$version"
mkdir -p "$release" "$package/src" "$workspace/fake-bin"
printf '.{ .name = .fixture, .version = "%s", .paths = .{"build.zig"} }\n' "$version" > "$package/build.zig.zon"
printf 'pub fn build() void {}\n' > "$package/build.zig"
printf 'fixture\n' > "$package/src/release_catalog.zig"
tar -czf "$release/zigeffect-cli-$version.tar.gz" -C "$workspace" "zigeffect-cli-$version"

if command -v sha256sum >/dev/null 2>&1; then
  checksum="$(sha256sum "$release/zigeffect-cli-$version.tar.gz" | awk '{ print $1 }')"
else
  checksum="$(shasum -a 256 "$release/zigeffect-cli-$version.tar.gz" | awk '{ print $1 }')"
fi
printf 'zigeffect-cli-%s.tar.gz\tfixture-hash\t%s\n' "$version" "$checksum" > "$release/manifest.tsv"

cat > "$workspace/fake-bin/zig" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "version" ]]; then
  echo "0.16.0"
  exit 0
fi
if [[ "${1:-}" != "build" ]]; then
  exit 64
fi
prefix=""
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "--prefix" ]]; then
    prefix="$2"
    shift 2
  else
    shift
  fi
done
test -n "$prefix"
mkdir -p "$prefix/bin"
printf '#!/bin/sh\necho zigeffect fixture\n' > "$prefix/bin/zigeffect"
chmod +x "$prefix/bin/zigeffect"
SH
chmod +x "$workspace/fake-bin/zig"

install_prefix="$workspace/prefix"
output="$(
  PATH="$workspace/fake-bin:$PATH" \
  ZIGEFFECT_VERSION="$version" \
  ZIGEFFECT_RELEASE_BASE_URL="file://$release" \
  ZIGEFFECT_INSTALL_DIR="$install_prefix" \
  sh "$installer"
)"
test -x "$install_prefix/bin/zigeffect"
grep -q "Installed ZigEffect $version" <<<"$output"

bad_release="$workspace/bad-release"
mkdir -p "$bad_release"
cp "$release/zigeffect-cli-$version.tar.gz" "$bad_release/"
printf 'zigeffect-cli-%s.tar.gz\tfixture-hash\t%s\n' "$version" "0000000000000000000000000000000000000000000000000000000000000000" > "$bad_release/manifest.tsv"
if PATH="$workspace/fake-bin:$PATH" \
  ZIGEFFECT_VERSION="$version" \
  ZIGEFFECT_RELEASE_BASE_URL="file://$bad_release" \
  ZIGEFFECT_INSTALL_DIR="$workspace/refused-prefix" \
  sh "$installer" > "$workspace/refused.out" 2>&1; then
  echo "installer accepted a checksum mismatch" >&2
  exit 1
fi
grep -q "checksum mismatch" "$workspace/refused.out"
test ! -e "$workspace/refused-prefix/bin/zigeffect"

echo "ZigEffect installer test passed."
