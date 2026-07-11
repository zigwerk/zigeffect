#!/usr/bin/env bash
set -euo pipefail

name="zigeffect-storage-cockroach-restart-$$"
port="26261"
password="$(openssl rand -hex 24)"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT
wait_ready() {
  for _ in $(seq 1 200); do
    if docker exec "$name" cockroach sql --certs-dir=certs --host=127.0.0.1:26257 -e 'select 1' >/dev/null 2>&1; then return 0; fi
    sleep 0.25
  done
  return 1
}

docker run --rm -d --name "$name" \
  -e COCKROACH_DATABASE=zigeffect -e COCKROACH_USER=zigeffect -e COCKROACH_PASSWORD="$password" \
  -p "127.0.0.1:${port}:26257" cockroachdb/cockroach:v26.2.1 start-single-node --http-addr=localhost:8080 >/dev/null
wait_ready
export PGPASSWORD="$password"
export ZIGEFFECT_TEST_DATABASE_URL="postgresql://zigeffect@127.0.0.1:${port}/zigeffect?sslmode=require"
zig build restart-seed -Dlive-database=cockroachdb
docker restart "$name" >/dev/null
wait_ready
zig build restart-verify -Dlive-database=cockroachdb
