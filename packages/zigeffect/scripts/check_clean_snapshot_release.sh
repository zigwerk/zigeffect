#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/../../.." && pwd)"
snapshot="$(mktemp -d)"
cleanup() { rm -rf "$snapshot"; }
trap cleanup EXIT

rsync -a \
  --exclude '.git' \
  --exclude '.zig-cache' \
  --exclude 'zig-out' \
  --exclude '.zigeffect' \
  --exclude '.tmp-*' \
  "$repo/" "$snapshot/"

find "$snapshot" -type d \( -name '.zig-cache' -o -name 'zig-out' -o -name '.zigeffect' \) -prune -exec rm -rf {} +
"$snapshot/packages/zigeffect/scripts/check_production_release.sh" unit

source_digest="$(find "$snapshot/packages" -type f \( -name '*.zig' -o -name '*.json' -o -name '*.md' -o -name '*.sh' \) -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256 | awk '{print $1}')"
printf '{"schema":"zigeffect.clean-snapshot-release.v1","status":"passed","source_sha256":"%s","lane":"unit"}\n' "$source_digest"
