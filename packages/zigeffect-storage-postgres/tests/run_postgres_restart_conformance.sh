#!/usr/bin/env bash
set -euo pipefail

name="zigeffect-storage-postgres-restart-$$"
port="25434"
password="$(openssl rand -hex 24)"
env_file="$(mktemp)"
chmod 600 "$env_file"
printf 'POSTGRES_PASSWORD=%s\nPOSTGRES_DB=zigeffect\n' "$password" >"$env_file"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; rm -f "$env_file"; }
trap cleanup EXIT
wait_ready() {
  for _ in $(seq 1 160); do
    if docker exec "$name" pg_isready -U postgres -d zigeffect >/dev/null 2>&1; then return 0; fi
    sleep 0.25
  done
  return 1
}

docker run --rm -d --name "$name" --env-file "$env_file" -p "127.0.0.1:${port}:5432" postgres:18-alpine >/dev/null
wait_ready
export PGPASSWORD="$password"
export ZIGEFFECT_TEST_DATABASE_URL="postgresql://postgres@127.0.0.1:${port}/zigeffect"
zig build restart-seed -Dlive-database=postgresql
docker restart "$name" >/dev/null
wait_ready
zig build restart-verify -Dlive-database=postgresql
