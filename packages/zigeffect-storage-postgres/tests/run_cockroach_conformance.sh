#!/usr/bin/env bash
set -euo pipefail

name="zigeffect-storage-cockroach-$$"
port="26260"
password="$(openssl rand -hex 24)"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run --rm -d --name "$name" \
  -e COCKROACH_DATABASE=zigeffect \
  -e COCKROACH_USER=zigeffect \
  -e COCKROACH_PASSWORD="$password" \
  -p "127.0.0.1:${port}:26257" \
  cockroachdb/cockroach:v26.2.1 start-single-node --http-addr=localhost:8080 >/dev/null
for _ in $(seq 1 160); do
  if docker exec "$name" cockroach sql --certs-dir=certs --host=127.0.0.1:26257 -e 'select 1' >/dev/null 2>&1; then
    PGPASSWORD="$password" ZIGEFFECT_TEST_DATABASE_URL="postgresql://zigeffect@127.0.0.1:${port}/zigeffect?sslmode=require" zig build conformance -Dlive-database=cockroachdb
    exit 0
  fi
  sleep 0.25
done
echo "CockroachDB storage conformance container did not become ready" >&2
exit 1
