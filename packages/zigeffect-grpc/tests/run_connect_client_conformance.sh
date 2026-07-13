#!/usr/bin/env bash
set -euo pipefail

client="$1"
runner="$2"
config="$3"

"$runner" --conf "$config" --mode client -- "$client"
