#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/../../.." && pwd)"
registry="$repo/packages/zigeffect/conformance/production-release-evidence.v1.json"

jq -e '.schema == "zigeffect.production-release-evidence.v1" and .status == "passed" and (.artifacts | length >= 10) and (.limitations | length > 0)' "$registry" >/dev/null
while IFS=$'\t' read -r path expected; do
  file="$repo/$path"
  [[ -f "$file" ]]
  actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || { echo "digest mismatch: $path" >&2; exit 1; }
  if [[ "$path" == *live.v1.json ]]; then
    jq -e '.schema == "zigeffect.live-conformance-receipt.v1" and .status == "passed" and (.checks | length > 0)' "$file" >/dev/null
  fi
done < <(jq -r '.artifacts[] | [.receipt,.sha256] | @tsv' "$registry")

while IFS=$'\t' read -r source digest; do
  rg -F "sha256:$digest" "$repo/$source" >/dev/null || { echo "descriptor digest missing from $source" >&2; exit 1; }
done <<'MAP'
packages/zigeffect-http-tls-openssl/src/root.zig	6fb32bcb3bc3944f45e4101a72587839652a52523d205a5d65a8b05684262990
packages/zigeffect-http/src/root.zig	818cd10afbf38ff139a45541d33b54abdf58e60e20a5fdffe3d627ce2a9ae2df
packages/zigeffect-otel/src/root.zig	ca7db537af861210ae00800d0fc08ef1f03e0413c94ec76aefc5e1e4e31b2192
packages/zigeffect-postgres-libpq/src/root.zig	afc72df4c305d9911b20a8baf28d62f255308627f2d833054a7dcb34a67d81fa
packages/zigeffect-redis/src/root.zig	5c489050fc04a52d2c6ac96c4f3450c777af08e80d2e4298c1a055a025db5f3d
packages/zigeffect-s3/src/root.zig	6767bb1a464008824bb38d42eb880fbd451ffe2d55ecbb3271cd8d4e2f4edfc2
packages/zigeffect-std/src/system_capabilities.zig	fddc0718cbc27865cde9292dddfd68e7ec0ba093c27954aa9242292001de4d49
packages/zigeffect-storage-postgres/src/root.zig	bf137fe1648d1a46679c4a99dd440827b558074acc0d780d1e8b31379b3d8ca3
packages/zigeffect-transport/src/root.zig	6a324a28a11126e4481e7733a69a4ef613ca9e9982668f4b5f13662765c85bf0
packages/zigeffect-reference-system/zigeffect.project.json	4d62af459d76eefea4b1af0a23aa1daef8b6945444c68211f3caa8040e72bfc9
MAP

if rg -n -i '(postgresql://[^/@:]+:[^/@]+@|authorization: bearer [^[]|password=[^[]|secret[-_]?key[" ]*[:=][" ]*[^$({[])' "$repo/packages" --glob '*/conformance/*.json' --glob '*/.zigeffect/**/*.json' 2>/dev/null; then
  echo "secret-shaped material reached production evidence" >&2
  exit 1
fi

echo "production evidence registry verified"
