#!/usr/bin/env bash
set -euo pipefail
pg_port="${ZIGEFFECT_REFERENCE_PG_PORT:-19432}"
redis_port="${ZIGEFFECT_REFERENCE_REDIS_PORT:-19379}"
s3_port="${ZIGEFFECT_REFERENCE_S3_PORT:-19001}"
suffix="$$"
pg="zigeffect-reference-pg-${suffix}"
minio="zigeffect-reference-minio-${suffix}"
tmp="$(mktemp -d)"
umask 077
pg_password="$(openssl rand -hex 24)"
redis_password="$(openssl rand -hex 24)"
s3_access="$(openssl rand -hex 12)"
s3_secret="$(openssl rand -hex 32)"
printf 'POSTGRES_PASSWORD=%s\n' "$pg_password" >"$tmp/postgres.env"
printf 'MINIO_ROOT_USER=%s\nMINIO_ROOT_PASSWORD=%s\n' "$s3_access" "$s3_secret" >"$tmp/minio.env"
printf 'bind 127.0.0.1\nport %s\nsave ""\nappendonly no\nrequirepass %s\ndir %s\npidfile %s\n' "$redis_port" "$redis_password" "$tmp" "$tmp/redis.pid" >"$tmp/redis.conf"
cleanup() { docker rm -f "$pg" "$minio" >/dev/null 2>&1 || true; if [[ -f "$tmp/redis.pid" ]]; then kill "$(<"$tmp/redis.pid")" 2>/dev/null || true; fi; rm -rf "$tmp"; }
trap cleanup EXIT
docker run -d --rm --name "$pg" -p "127.0.0.1:${pg_port}:5432" --env-file "$tmp/postgres.env" postgres:17-alpine >/dev/null
docker run -d --rm --name "$minio" -p "127.0.0.1:${s3_port}:9000" --env-file "$tmp/minio.env" quay.io/minio/minio:latest server /data >/dev/null
redis-server "$tmp/redis.conf" --daemonize yes
for _ in $(seq 1 300); do pg_isready="$(docker exec "$pg" pg_isready -U postgres 2>/dev/null || true)"; redis_ok="$(redis-cli --no-auth-warning -a "$redis_password" -p "$redis_port" ping 2>/dev/null || true)"; minio_ok="$(curl -fsS "http://127.0.0.1:${s3_port}/minio/health/ready" 2>/dev/null || true)"; [[ "$pg_isready" == *accepting* && "$redis_ok" == PONG && -n "$minio_ok" ]] && break; sleep 0.05; done
docker run --rm --network "container:${minio}" -e MC_USER="$s3_access" -e MC_PASSWORD="$s3_secret" --entrypoint /bin/sh quay.io/minio/mc:latest -c 'mc alias set local http://127.0.0.1:9000 "$MC_USER" "$MC_PASSWORD" >/dev/null && mc mb --ignore-existing local/zigeffect >/dev/null'
PGPASSWORD="$pg_password" ZIGEFFECT_TEST_DATABASE_URL="postgresql://postgres@127.0.0.1:${pg_port}/postgres" ZIGEFFECT_TEST_REDIS_PASSWORD="$redis_password" ZIGEFFECT_TEST_S3_ACCESS_KEY="$s3_access" ZIGEFFECT_TEST_S3_SECRET_KEY="$s3_secret" zig build live-conformance -Dredis-port="$redis_port" -Ds3-port="$s3_port" --summary all
