#!/bin/sh

set -eu

repository="https://github.com/zigwerk/zigeffect"
install_dir="${ZIGEFFECT_INSTALL_DIR:-$HOME/.local}"
requested_version="${ZIGEFFECT_VERSION:-}"

fail() {
  echo "zigeffect installer: $*" >&2
  exit 1
}

command -v curl >/dev/null 2>&1 || fail "curl is required"
command -v tar >/dev/null 2>&1 || fail "tar is required"
command -v zig >/dev/null 2>&1 || fail "Zig >= 0.16.0 and < 0.17.0 is required"

zig_version="$(zig version)"
case "$zig_version" in
  0.16.*) ;;
  *) fail "Zig >= 0.16.0 and < 0.17.0 is required; found $zig_version" ;;
esac

if [ -n "${ZIGEFFECT_RELEASE_BASE_URL:-}" ]; then
  release_base="$ZIGEFFECT_RELEASE_BASE_URL"
elif [ -n "$requested_version" ]; then
  case "$requested_version" in
    *[!0-9A-Za-z.+-]*|'') fail "invalid ZIGEFFECT_VERSION" ;;
  esac
  release_base="$repository/releases/download/v$requested_version"
else
  release_base="$repository/releases/latest/download"
fi

workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT HUP INT TERM
manifest="$workspace/manifest.tsv"
curl -fsSL "$release_base/manifest.tsv" -o "$manifest" || fail "could not download release manifest"

release_line="$(awk -F '\t' '$1 ~ /^zigeffect-cli-[0-9][0-9A-Za-z.+-]*\.tar\.gz$/ { print; exit }' "$manifest")"
[ -n "$release_line" ] || fail "release manifest does not contain a CLI archive"
asset="$(printf '%s\n' "$release_line" | awk -F '\t' '{ print $1 }')"
expected_sha256="$(printf '%s\n' "$release_line" | awk -F '\t' '{ print $3 }')"
version="${asset#zigeffect-cli-}"
version="${version%.tar.gz}"

if [ -n "$requested_version" ] && [ "$requested_version" != "$version" ]; then
  fail "release manifest resolved $version, expected $requested_version"
fi
[ "${#expected_sha256}" -eq 64 ] || fail "release manifest has an invalid CLI checksum"

archive="$workspace/$asset"
curl -fsSL "$release_base/$asset" -o "$archive" || fail "could not download $asset"
if command -v sha256sum >/dev/null 2>&1; then
  actual_sha256="$(sha256sum "$archive" | awk '{ print $1 }')"
elif command -v shasum >/dev/null 2>&1; then
  actual_sha256="$(shasum -a 256 "$archive" | awk '{ print $1 }')"
else
  fail "sha256sum or shasum is required"
fi
[ "$actual_sha256" = "$expected_sha256" ] || fail "checksum mismatch for $asset"

tar -xzf "$archive" -C "$workspace"
source_dir="$workspace/zigeffect-cli-$version"
[ -f "$source_dir/build.zig" ] || fail "CLI archive has an unexpected layout"

mkdir -p "$install_dir"
(
  cd "$source_dir"
  zig build -Doptimize=ReleaseSafe --prefix "$install_dir"
) || fail "CLI build failed"

[ -x "$install_dir/bin/zigeffect" ] || fail "CLI build did not install bin/zigeffect"

echo "Installed ZigEffect $version to $install_dir/bin/zigeffect"
case ":${PATH:-}:" in
  *":$install_dir/bin:"*) ;;
  *) echo "Add $install_dir/bin to PATH to run zigeffect." ;;
esac
echo "Run 'zigeffect completions <bash|zsh|fish>' to install shell completions."
