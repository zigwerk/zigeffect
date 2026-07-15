#!/usr/bin/env bash
set -euo pipefail

server="$1"
python="$2"
certificate="$3"
key="$4"
mode="${5:-plaintext}"
official_root="$6"
port=$((32000 + ($$ % 10000)))

if [[ "$mode" == "tls" ]]; then
  "$server" "$port" tls "$certificate" "$key" &
else
  "$server" "$port" plaintext &
fi
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true' EXIT
sleep 0.25

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
    -m tests.interop.client
    --server_host=127.0.0.1
    --server_port="$port"
    --test_case="$test_case"
  )
  if [[ "$mode" == "tls" ]]; then
    args+=(
      --use_tls=true
      --use_test_ca=true
      --server_host_override=foo.test.google.fr
    )
  fi
  PYTHONPATH="$official_root" "$python" "${args[@]}"
done

echo "official gRPC Python client passed ${#test_cases[@]} portable cases in $mode mode"
