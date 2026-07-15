#!/usr/bin/env bash
set -euo pipefail

server="$1"
repo_root="$2"
image="envoyproxy/envoy@sha256:4d496918618a7ebd6c71ae8285e31ebff092f3a0a5ad642d50decf4a54eb2456"

"$server" 39051 &
server_pid=$!
container="zigeffect-connect-$server_pid"
cleanup() {
  docker rm -f "$container" >/dev/null 2>&1 || true
  kill "$server_pid" >/dev/null 2>&1 || true
  wait "$server_pid" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --rm -d --name "$container" -p 39052:39052 \
  -v "$repo_root/packages/zigeffect-grpc/tests/envoy-connect.yaml:/etc/envoy/envoy.yaml:ro" \
  "$image" -c /etc/envoy/envoy.yaml >/dev/null

ready=false
for _ in $(seq 1 100); do
  if curl -fsS -o /dev/null -X OPTIONS -H 'Origin: http://localhost:39052' http://127.0.0.1:39052/zigeffect.grpc.v1.ConformanceService/Unary 2>/dev/null; then
    ready=true
    break
  fi
  sleep 0.05
done
if [[ "$ready" != true ]]; then
  docker logs "$container"
  exit 1
fi

cd "$repo_root"
bun --cwd packages/zigeffect-grpc-web src/connect_interop.ts http://127.0.0.1:39052
