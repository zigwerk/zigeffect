#!/usr/bin/env bash
set -euo pipefail
port="${ZIGEFFECT_MINIO_PORT:-19000}"
name="zigeffect-minio-$$"
access_key="$(openssl rand -hex 12)"
secret_key="$(openssl rand -hex 32)"
env_file="$(mktemp)"
chmod 600 "$env_file"
printf 'MINIO_ROOT_USER=%s\nMINIO_ROOT_PASSWORD=%s\n' "$access_key" "$secret_key" >"$env_file"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; rm -f "$env_file"; }
trap cleanup EXIT
docker run -d --rm --name "$name" -p "127.0.0.1:${port}:9000" --env-file "$env_file" quay.io/minio/minio:latest server /data >/dev/null
for _ in $(seq 1 200); do curl -fsS "http://127.0.0.1:${port}/minio/health/ready" >/dev/null 2>&1 && break; sleep 0.05; done
docker run --rm --network "container:${name}" -e MC_USER="$access_key" -e MC_PASSWORD="$secret_key" --entrypoint /bin/sh quay.io/minio/mc:latest -c 'mc alias set local http://127.0.0.1:9000 "$MC_USER" "$MC_PASSWORD" >/dev/null && mc mb --ignore-existing local/zigeffect >/dev/null'
ZIGEFFECT_TEST_S3_ACCESS_KEY="$access_key" ZIGEFFECT_TEST_S3_SECRET_KEY="$secret_key" zig build conformance -Dport="$port" --summary all
