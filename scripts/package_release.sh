#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <version> <output-directory>" >&2
  exit 64
fi

version="${1#v}"
output="$2"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
  echo "version must be a semantic version without a leading v" >&2
  exit 64
fi

mkdir -p "$output"
output="$(cd "$output" && pwd)"
workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT
manifest="$output/manifest.tsv"
: > "$manifest"

packages=(
  zigeffect
  zigeffect-std
  zigeffect-zio
  zigeffect-cli
  zigeffect-http
  zigeffect-otel
  zigeffect-parser
  zigeffect-postgres-libpq
  zigeffect-postgres
  zigeffect-quic
  zigeffect-redis
  zigeffect-s3
  zigeffect-transport
  zigeffect-grpc
  zigeffect-http-tls-openssl
  zigeffect-storage-postgres
  zigeffect-reference-system
)

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  else
    shasum -a 256 "$1" | awk '{ print $1 }'
  fi
}

for package in "${packages[@]}"; do
  package_root="packages/$package"
  zon="$root/$package_root/build.zig.zon"
  if [[ ! -f "$zon" ]]; then
    echo "package is missing build.zig.zon: $package_root" >&2
    exit 1
  fi

  prefix="${package}-${version}"
  stage="$workspace/$prefix"
  mkdir -p "$stage"

  while IFS= read -r tracked; do
    relative="${tracked#${package_root}/}"
    mkdir -p "$stage/$(dirname "$relative")"
    cp "$root/$tracked" "$stage/$relative"
  done < <(git -C "$root" ls-files "$package_root")

  staged_zon="$stage/build.zig.zon"
  while IFS= read -r dependency; do
    [[ -n "$dependency" ]] || continue
    dependency_asset="${dependency}-${version}.tar.gz"
    dependency_hash="$(awk -F '\t' -v asset="$dependency_asset" '$1 == asset { print $2 }' "$manifest")"
    if [[ -z "$dependency_hash" ]]; then
      echo "$package depends on $dependency before its release package exists" >&2
      exit 1
    fi

    dependency_url="https://github.com/zigwerk/zigeffect/releases/download/v${version}/${dependency_asset}"
    DEP_PATH="../$dependency" DEP_URL="$dependency_url" DEP_HASH="$dependency_hash" \
      perl -0pi -e 's{\.path = "\Q$ENV{DEP_PATH}\E"}{.url = "$ENV{DEP_URL}", .hash = "$ENV{DEP_HASH}"}g' "$staged_zon"
  done < <(grep -oE '\.path = "\.\./zigeffect[^"]*"' "$zon" | sed -E 's/.*"\.\.\/([^"]+)"/\1/' || true)

  if grep -q '\.path = "\.\./zigeffect' "$staged_zon"; then
    echo "unresolved monorepo dependency in $package" >&2
    exit 1
  fi

  asset="$output/${package}-${version}.tar.gz"
  COPYFILE_DISABLE=1 tar -czf "$asset" -C "$workspace" "$prefix"
  zig_hash="$(cd "$root/packages/zigeffect" && zig fetch "$asset")"
  archive_hash="$(sha256_file "$asset")"
  printf '%s\t%s\t%s\n' "$(basename "$asset")" "$zig_hash" "$archive_hash" >> "$manifest"
done

echo "Created ${#packages[@]} ZigEffect release packages in $output"
