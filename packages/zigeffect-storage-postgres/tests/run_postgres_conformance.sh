#!/usr/bin/env bash
set -euo pipefail

name="zigeffect-storage-postgres-$$"
port="25433"
password="$(openssl rand -hex 24)"
env_file="$(mktemp)"
chmod 600 "$env_file"
printf 'POSTGRES_PASSWORD=%s\nPOSTGRES_DB=zigeffect\n' "$password" >"$env_file"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; rm -f "$env_file"; }
trap cleanup EXIT

docker run --rm -d --name "$name" --env-file "$env_file" -p "127.0.0.1:${port}:5432" postgres:18-alpine >/dev/null
for _ in $(seq 1 120); do
  if docker exec "$name" pg_isready -U postgres -d zigeffect >/dev/null 2>&1; then
    PGPASSWORD="$password" ZIGEFFECT_TEST_DATABASE_URL="postgresql://postgres@127.0.0.1:${port}/zigeffect" zig build conformance -Dlive-database=postgresql
    exit 0
  fi
  sleep 0.25
done
echo "PostgreSQL storage conformance container did not become ready" >&2
exit 1
