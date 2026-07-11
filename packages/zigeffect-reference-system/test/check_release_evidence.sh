#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
receipt="$root/conformance/reference-stack-live.v1.json"
manifest="$root/zigeffect.project.json"

jq -e '.schema == "zigeffect.live-conformance-receipt.v1" and .status == "passed" and (.checks | length >= 10) and (.limitations | length >= 1)' "$receipt" >/dev/null
actual="$(shasum -a 256 "$receipt" | awk '{print $1}')"
jq -e --arg digest "sha256:$actual" 'all(.capability_descriptors[]; .conformance.content_sha256 == $digest and .conformance.receipt == "conformance/reference-stack-live.v1.json")' "$manifest" >/dev/null
jq -e '.schema == "zigeffect.reference.normalized-trace.v1" and .order.status == "completed" and .transport.authenticated and .telemetry.api and .telemetry.worker' "$root/conformance/reference-stack-trace.v1.json" >/dev/null

if rg -n -i '(postgresql://[^/@:]+:[^/@]+@|authorization: bearer [^[]|password=[^[]|secret[-_]?key[" ]*[:=][" ]*[^$({[])' "$root/conformance" "$root/.zigeffect" 2>/dev/null; then
  echo "secret-shaped material reached release evidence" >&2
  exit 1
fi

(cd "$root" && zig build test --summary all)
(cd "$root" && zig build fault-matrix --summary all)
