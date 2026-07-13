#!/usr/bin/env bash
set -euo pipefail

buf="${1:-../../node_modules/.bin/buf}"
buf="$(cd "$(dirname "$buf")" && pwd)/$(basename "$buf")"
package_dir="$(cd "$(dirname "$0")/.." && pwd)"
baseline="$package_dir/conformance/buf-v1.binpb"

test -s "$baseline"
cd "$package_dir"
"$buf" lint
"$buf" breaking --against "$baseline"

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
cp "$package_dir/buf.yaml" "$fixture/buf.yaml"
cp -R "$package_dir/proto" "$fixture/proto"
python3 - "$fixture/proto/zigeffect/grpc/v1/conformance.proto" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
needle = "  string id = 1;\n"
if needle not in source:
    raise SystemExit("breaking fixture anchor is missing")
path.write_text(source.replace(needle, "", 1), encoding="utf-8")
PY

if (cd "$fixture" && "$buf" breaking --against "$baseline") >"$fixture/breaking.log" 2>&1; then
  echo "Buf accepted a fixture that deletes zigeffect.grpc.v1.UnaryRequest.id" >&2
  exit 1
fi
grep -q 'field "1" with name "id" on message "UnaryRequest" was deleted' "$fixture/breaking.log"
echo "Buf compatibility: current schema passed; deliberate field deletion rejected"
