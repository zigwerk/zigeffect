#!/usr/bin/env bash
set -euo pipefail

package_root="$(cd "$(dirname "$0")/.." && pwd)"
iterations="${GRPC_ADVERSARIAL_ITERATIONS:-10}"
optimize="${GRPC_ADVERSARIAL_OPTIMIZE:-ReleaseSafe}"

if ! [[ "$iterations" =~ ^[1-9][0-9]*$ ]]; then
  echo "GRPC_ADVERSARIAL_ITERATIONS must be a positive integer" >&2
  exit 2
fi

cd "$package_root"
echo "running ${iterations} in-process malformed-frame/certificate-rotation iterations"
zig build adversarial-test -Doptimize="$optimize" \
  -Dadversarial-iterations="$iterations" \
  --summary all
