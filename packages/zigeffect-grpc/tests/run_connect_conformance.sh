#!/usr/bin/env bash
set -euo pipefail

server="$1"
runner="$2"
config="$3"

"$runner" --conf "$config" --mode server -- "$server"
