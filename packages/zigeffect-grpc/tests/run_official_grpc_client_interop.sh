#!/usr/bin/env bash
set -euo pipefail

client="$1"
python="$2"
ca="$3"
certificate="$4"
key="$5"
mode="${6:-plaintext}"
official_root="$7"
port=$((52000 + ($$ % 1000)))

PYTHONPATH="$official_root" "$python" "$(dirname "$0")/official_reference_server.py" \
  "$port" "$mode" "$certificate" "$key" &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true' EXIT

for _ in $(seq 1 100); do
  if "$python" - "$port" <<'PY'
import socket
import sys
s = socket.socket()
s.settimeout(0.1)
try:
    s.connect(("127.0.0.1", int(sys.argv[1])))
except OSError:
    raise SystemExit(1)
finally:
    s.close()
PY
  then
    break
  fi
  sleep 0.05
done

"$client" "$port" "$mode" "$ca"

kill "$server_pid" 2>/dev/null || true
wait "$server_pid" 2>/dev/null || true
trap - EXIT
echo "official gRPC Zig client -> Python server ($mode): 14/14 portable cases passed"
