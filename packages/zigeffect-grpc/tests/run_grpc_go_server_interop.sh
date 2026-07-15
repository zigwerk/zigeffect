#!/usr/bin/env bash
set -euo pipefail

zig_client="$1"
go_server="$2"
ca="$3"
certificate="$4"
key="$5"
mode="${6:-plaintext}"
port=$((45000 + ($$ % 1000)))

args=(--port="$port")
if [[ "$mode" == "tls" ]]; then
  args+=(--use_tls --tls_cert_file="$certificate" --tls_key_file="$key")
fi
"$go_server" "${args[@]}" &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true' EXIT
ready=false
for _ in $(seq 1 100); do
  if python3 - "$port" <<'PY'
import socket
import sys

with socket.create_connection(("127.0.0.1", int(sys.argv[1])), timeout=0.1):
    pass
PY
  then
    ready=true
    break
  fi
  if ! kill -0 "$server_pid" 2>/dev/null; then
    wait "$server_pid"
  fi
  sleep 0.05
done
if [[ "$ready" != true ]]; then
  echo "grpc-go server did not become ready on port $port" >&2
  exit 1
fi

"$zig_client" "$port" "$mode" "$ca"

kill "$server_pid" 2>/dev/null || true
wait "$server_pid" 2>/dev/null || true
trap - EXIT
echo "Zig client -> official grpc-go server ($mode): 14/14 portable cases passed"
