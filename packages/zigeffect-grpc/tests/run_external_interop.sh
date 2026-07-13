#!/usr/bin/env bash
set -euo pipefail

server="$1"
python="$2"
certificate="$3"
key="$4"
mode="${5:-plaintext}"
port=$((30000 + ($$ % 10000)))

if [[ "$mode" == "tls" ]]; then
  "$server" "$port" tls "$certificate" "$key" &
else
  "$server" "$port" plaintext &
fi
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT
sleep 0.25

"$python" - "$port" "$mode" "$certificate" <<'PY'
import pathlib
import sys
import grpc

port, mode, certificate = sys.argv[1], sys.argv[2], sys.argv[3]
target = f"127.0.0.1:{port}"
if mode == "tls":
    credentials = grpc.ssl_channel_credentials(pathlib.Path(certificate).read_bytes())
    channel = grpc.secure_channel(target, credentials, options=(("grpc.ssl_target_name_override", "localhost"),))
else:
    channel = grpc.insecure_channel(target)
grpc.channel_ready_future(channel).result(timeout=10)
call = channel.unary_unary(
    "/example.v1.Echo/Say",
    request_serializer=lambda value: value,
    response_deserializer=lambda value: value,
)
response = call(b"python-grpc-interoperability", timeout=10)
assert response == b"python-grpc-interoperability", response
upload = channel.stream_unary("/example.v1.Stream/Upload", request_serializer=lambda v: v, response_deserializer=lambda v: v)
assert upload(iter((b"one", b"two")), timeout=10) == b"received-two"
download = channel.unary_stream("/example.v1.Stream/Download", request_serializer=lambda v: v, response_deserializer=lambda v: v)
assert list(download(b"request", timeout=10)) == [b"part-one", b"part-two"]
chat = channel.stream_stream("/example.v1.Stream/Chat", request_serializer=lambda v: v, response_deserializer=lambda v: v)
assert list(chat(iter((b"hello", b"world")), timeout=10)) == [b"hello", b"world"]
channel.close()
PY

wait "$server_pid"
trap - EXIT
