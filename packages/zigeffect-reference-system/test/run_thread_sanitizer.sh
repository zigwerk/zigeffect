#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root/zigeffect"
zig build thread-sanitizer --summary all
