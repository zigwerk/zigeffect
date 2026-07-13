#!/usr/bin/env bash
set -euo pipefail

client="$1"
python="$2"
certificate="$3"
key="$4"
mode="${5:-plaintext}"
port=$((40000 + ($$ % 10000)))

"$python" - "$port" "$mode" "$certificate" "$key" <<'PY' &
from concurrent import futures
import pathlib
import signal
import sys
import grpc

port, mode, certificate, key = sys.argv[1:]
handler = grpc.method_handlers_generic_handler(
    "example.v1.Echo",
    {"Say": grpc.unary_unary_rpc_method_handler(
        lambda request, context: request,
        request_deserializer=lambda value: value,
        response_serializer=lambda value: value,
    )},
)
stream_handler = grpc.method_handlers_generic_handler(
    "example.v1.Stream",
    {
        "Upload": grpc.stream_unary_rpc_method_handler(lambda requests, context: b"received-two", request_deserializer=lambda v: v, response_serializer=lambda v: v),
        "Download": grpc.unary_stream_rpc_method_handler(lambda request, context: iter((b"part-one", b"part-two")), request_deserializer=lambda v: v, response_serializer=lambda v: v),
        "Chat": grpc.stream_stream_rpc_method_handler(lambda requests, context: requests, request_deserializer=lambda v: v, response_serializer=lambda v: v),
    },
)
server = grpc.server(futures.ThreadPoolExecutor(max_workers=2))
server.add_generic_rpc_handlers((handler, stream_handler))
address = f"127.0.0.1:{port}"
if mode == "tls":
    credentials = grpc.ssl_server_credentials(((pathlib.Path(key).read_bytes(), pathlib.Path(certificate).read_bytes()),))
    assert server.add_secure_port(address, credentials) != 0
else:
    assert server.add_insecure_port(address) != 0
server.start()
server.wait_for_termination()
PY
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT
sleep 0.25

"$client" "$port" "$mode" "$certificate"
kill "$server_pid" 2>/dev/null || true
wait "$server_pid" 2>/dev/null || true
trap - EXIT
