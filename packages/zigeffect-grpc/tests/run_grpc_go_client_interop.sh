#!/usr/bin/env bash
set -euo pipefail

zig_server="$1"
go_client="$2"
ca="$3"
certificate="$4"
key="$5"
mode="${6:-plaintext}"
port=$((44000 + ($$ % 1000)))

if [[ "$mode" == "tls" ]]; then
  "$zig_server" "$port" tls "$certificate" "$key" &
else
  "$zig_server" "$port" plaintext &
fi
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
  echo "Zig interop server did not become ready on port $port" >&2
  exit 1
fi

test_cases=(
  empty_unary
  large_unary
  client_streaming
  server_streaming
  ping_pong
  empty_stream
  cancel_after_begin
  cancel_after_first_response
  timeout_on_sleeping_server
  custom_metadata
  status_code_and_message
  special_status_message
  unimplemented_method
  unimplemented_service
)

for test_case in "${test_cases[@]}"; do
  args=(
    --server_host=127.0.0.1
    --server_port="$port"
    --test_case="$test_case"
  )
  if [[ "$mode" == "tls" ]]; then
    args+=(
      --use_tls
      --use_test_ca
      --ca_file="$ca"
      --server_host_override=foo.test.google.fr
    )
  fi
  if ! output="$("$go_client" "${args[@]}" 2>&1)"; then
    printf '%s\n' "$output" >&2
    exit 1
  fi
  if grep -q 'FATAL:' <<<"$output"; then
    printf '%s\n' "$output" >&2
    exit 1
  fi
done

echo "official grpc-go client -> Zig server ($mode): ${#test_cases[@]}/${#test_cases[@]} portable cases passed"
