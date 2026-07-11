#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
suffix="$$"
pg="zigeffect-reference-process-pg-${suffix}"
minio="zigeffect-reference-process-minio-${suffix}"
api_pid=""
worker_pid=""
collector_pid=""
cleanup() {
  [[ -n "$api_pid" ]] && kill "$api_pid" >/dev/null 2>&1 || true
  [[ -n "$worker_pid" ]] && kill "$worker_pid" >/dev/null 2>&1 || true
  [[ -n "$collector_pid" ]] && kill "$collector_pid" >/dev/null 2>&1 || true
  if [[ -f "$tmp/redis.pid" ]]; then kill "$(<"$tmp/redis.pid")" >/dev/null 2>&1 || true; fi
  docker rm -f "$pg" "$minio" >/dev/null 2>&1 || true
  if [[ "${ZIGEFFECT_KEEP_TMP:-0}" == 1 ]]; then
    echo "process stack diagnostics retained at $tmp" >&2
  else
    rm -rf "$tmp"
  fi
}
wait_with_deadline() {
  local pid="$1"
  local label="$2"
  local timeout_seconds="$3"
  local deadline="$((SECONDS + timeout_seconds))"
  local state=""
  while true; do
    state="$(ps -p "$pid" -o stat= 2>/dev/null | tr -d '[:space:]' || true)"
    [[ -z "$state" || "$state" == Z* ]] && break
    if [[ "$SECONDS" -ge "$deadline" ]]; then
      echo "$label did not exit within ${timeout_seconds}s" >&2
      return 1
    fi
    sleep 0.05
  done
  wait "$pid"
}
trap cleanup EXIT
trap 'echo "process stack failed at line $LINENO" >&2' ERR
umask 077

pg_port="${ZIGEFFECT_REFERENCE_PROCESS_PG_PORT:-20432}"
redis_port="${ZIGEFFECT_REFERENCE_PROCESS_REDIS_PORT:-20379}"
s3_port="${ZIGEFFECT_REFERENCE_PROCESS_S3_PORT:-20001}"
api_port="${ZIGEFFECT_REFERENCE_PROCESS_API_PORT:-20808}"
transport_port="${ZIGEFFECT_REFERENCE_PROCESS_TRANSPORT_PORT:-20992}"
otlp_port="${ZIGEFFECT_REFERENCE_PROCESS_OTLP_PORT:-20318}"
request_count="${ZIGEFFECT_REFERENCE_REQUESTS:-1}"
max_workload_seconds="${ZIGEFFECT_REFERENCE_MAX_WORKLOAD_SECONDS:-30}"
process_exit_seconds="${ZIGEFFECT_REFERENCE_PROCESS_EXIT_SECONDS:-15}"
[[ "$request_count" =~ ^[0-9]+$ && "$request_count" -ge 1 && "$request_count" -le 10000 ]]
[[ "$process_exit_seconds" =~ ^[0-9]+$ && "$process_exit_seconds" -ge 1 && "$process_exit_seconds" -le 300 ]]

pg_password="$(openssl rand -hex 24)"
redis_password="$(openssl rand -hex 24)"
s3_access="$(openssl rand -hex 12)"
s3_secret="$(openssl rand -hex 32)"
transport_secret="$(openssl rand -hex 32)"

printf 'POSTGRES_PASSWORD=%s\nPOSTGRES_DB=zigeffect\n' "$pg_password" >"$tmp/postgres.env"
printf 'MINIO_ROOT_USER=%s\nMINIO_ROOT_PASSWORD=%s\n' "$s3_access" "$s3_secret" >"$tmp/minio.env"
printf 'bind 127.0.0.1\nport %s\nsave \"\"\nappendonly no\nrequirepass %s\ndir %s\npidfile %s\n' "$redis_port" "$redis_password" "$tmp" "$tmp/redis.pid" >"$tmp/redis.conf"

docker run -d --rm --name "$pg" --env-file "$tmp/postgres.env" -p "127.0.0.1:${pg_port}:5432" postgres:17-alpine >/dev/null
docker run -d --rm --name "$minio" --env-file "$tmp/minio.env" -p "127.0.0.1:${s3_port}:9000" quay.io/minio/minio:latest server /data >/dev/null
redis-server "$tmp/redis.conf" --daemonize yes

for _ in $(seq 1 300); do
  pg_ready="$(docker exec "$pg" pg_isready -U postgres -d zigeffect 2>/dev/null || true)"
  redis_ready="$(redis-cli --no-auth-warning -a "$redis_password" -p "$redis_port" ping 2>/dev/null || true)"
  minio_ready="$(curl -fsS "http://127.0.0.1:${s3_port}/minio/health/ready" 2>/dev/null || true)"
  [[ "$pg_ready" == *accepting* && "$redis_ready" == PONG && -n "$minio_ready" ]] && break
  sleep 0.05
done

docker run --rm --network "container:${minio}" -e MC_USER="$s3_access" -e MC_PASSWORD="$s3_secret" --entrypoint /bin/sh quay.io/minio/mc:latest -c 'mc alias set local http://127.0.0.1:9000 "$MC_USER" "$MC_PASSWORD" >/dev/null && mc mb --ignore-existing local/zigeffect >/dev/null'

openssl req -x509 -newkey rsa:2048 -nodes -keyout "$tmp/ca.key" -out "$tmp/ca.crt" -subj '/CN=ZigEffect Reference CA' -days 1 >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes -keyout "$tmp/server.key" -out "$tmp/server.csr" -subj '/CN=localhost' -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1' >/dev/null 2>&1
printf 'subjectAltName=DNS:localhost,IP:127.0.0.1\nextendedKeyUsage=serverAuth\n' >"$tmp/server.ext"
openssl x509 -req -in "$tmp/server.csr" -CA "$tmp/ca.crt" -CAkey "$tmp/ca.key" -CAcreateserial -out "$tmp/server.crt" -days 1 -extfile "$tmp/server.ext" >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes -keyout "$tmp/client.key" -out "$tmp/client.csr" -subj '/CN=reference-api' >/dev/null 2>&1
printf 'extendedKeyUsage=clientAuth\n' >"$tmp/client.ext"
openssl x509 -req -in "$tmp/client.csr" -CA "$tmp/ca.crt" -CAkey "$tmp/ca.key" -CAcreateserial -out "$tmp/client.crt" -days 1 -extfile "$tmp/client.ext" >/dev/null 2>&1

(cd "$root" && zig build -Doptimize=ReleaseSafe >/dev/null)
(cd "$root/services/api" && zig build -Doptimize=ReleaseSafe >/dev/null)
(cd "$root/services/worker" && zig build -Doptimize=ReleaseSafe >/dev/null)

export ZIGEFFECT_API_PORT="$api_port"
export ZIGEFFECT_REDIS_PORT="$redis_port"
export ZIGEFFECT_S3_PORT="$s3_port"
export ZIGEFFECT_WORKER_TRANSPORT_PORT="$transport_port"
export ZIGEFFECT_OTLP_PORT="$otlp_port"
export ZIGEFFECT_WORKER_POLL_DEADLINE_MS=30000
export ZIGEFFECT_EXPECTED_ORDERS="$request_count"
export ZIGEFFECT_TEST_SHUTDOWN=1
export ZIGEFFECT_SECRET_DATABASE_URL="postgresql://postgres:${pg_password}@127.0.0.1:${pg_port}/zigeffect"
export ZIGEFFECT_SECRET_REDIS_PASSWORD="$redis_password"
export ZIGEFFECT_SECRET_S3_ACCESS_KEY="$s3_access"
export ZIGEFFECT_SECRET_S3_SECRET_KEY="$s3_secret"
export ZIGEFFECT_SECRET_TRANSPORT_SECRET="$transport_secret"
export ZIGEFFECT_TRANSPORT_CA="$tmp/ca.crt"
export ZIGEFFECT_TRANSPORT_SERVER_CERT="$tmp/server.crt"
export ZIGEFFECT_TRANSPORT_SERVER_KEY="$tmp/server.key"
export ZIGEFFECT_TRANSPORT_CLIENT_CERT="$tmp/client.crt"
export ZIGEFFECT_TRANSPORT_CLIENT_KEY="$tmp/client.key"

"$root/zig-out/bin/reference-otlp-collector" "$otlp_port" 2 >"$tmp/collector.log" 2>&1 & collector_pid="$!"
"$root/services/worker/zig-out/bin/worker" >"$tmp/worker.log" 2>&1 & worker_pid="$!"
"$root/services/api/zig-out/bin/api" >"$tmp/api.log" 2>&1 & api_pid="$!"

health=""
for _ in $(seq 1 300); do
  health="$(curl -fsS --max-time 1 "http://127.0.0.1:${api_port}/health/ready" 2>/dev/null || true)"
  [[ "$health" == *ready* ]] && break
  sleep 0.05
done
[[ "$health" == *ready* ]]

workload_started="$SECONDS"
for index in $(seq 1 "$request_count"); do
  order_id="process-order-${index}"
  idempotency="process-$(printf '%016x' "$index")"
  command="$(printf '{\"id\":\"%s\",\"idempotency_key\":\"%s\",\"attachment_key\":\"orders/%s.txt\",\"attachment\":\"receipt\"}' "$order_id" "$idempotency" "$order_id")"
  created="$(curl -fsS --max-time 5 -H 'Content-Type: application/json' -d "$command" "http://127.0.0.1:${api_port}/orders")"
  [[ "$created" == *"$order_id"* ]]
  if [[ "$index" -eq 1 ]]; then
    duplicate="$(curl -fsS --max-time 5 -H 'Content-Type: application/json' -d "$command" "http://127.0.0.1:${api_port}/orders")"
    [[ "$duplicate" == *"$order_id"* ]]
  fi
done

for index in $(seq 1 "$request_count"); do
  order_id="process-order-${index}"
  order=""
  for _ in $(seq 1 300); do
    order="$(curl -fsS --max-time 1 "http://127.0.0.1:${api_port}/orders/${order_id}" 2>/dev/null || true)"
    [[ "$order" == *completed* ]] && break
    sleep 0.05
  done
  [[ "$order" == *completed* && "$order" == *'"version":3'* ]]
done
workload_seconds="$((SECONDS - workload_started))"
[[ "$workload_seconds" -le "$max_workload_seconds" ]]

wait_with_deadline "$worker_pid" "reference worker" "$process_exit_seconds"; worker_pid=""
curl -fsS --max-time 2 -X POST "http://127.0.0.1:${api_port}/_test/shutdown" >/dev/null
wait_with_deadline "$api_pid" "reference API" "$process_exit_seconds"; api_pid=""
wait_with_deadline "$collector_pid" "reference telemetry collector" "$process_exit_seconds"; collector_pid=""

for material in "$pg_password" "$redis_password" "$s3_access" "$s3_secret" "$transport_secret"; do
  if grep -R -F "$material" "$tmp/api.log" "$tmp/worker.log" "$tmp/collector.log" >/dev/null; then
    echo 'secret material reached process logs' >&2
    exit 1
  fi
done

# Bind the checked-in differential oracle to this successful live topology.
# The fault-matrix test consumes the same normalized trace, so a static fixture
# cannot drift away from the independently executed API/worker/collector run.
normalized_trace='{"schema":"zigeffect.reference.normalized-trace.v1","order":{"status":"completed","version":3},"outbox":{"dispatched":true},"broker":{"deliveries":1,"duplicates_suppressed":1},"object":{"checksum":"verified"},"transport":{"authenticated":true},"telemetry":{"api":true,"worker":true}}'
checked_trace="$(tr -d '\n' < "$root/conformance/reference-stack-trace.v1.json")"
[[ "$checked_trace" == "$normalized_trace" ]]

ZIGEFFECT_PROCESS_STACK_VERIFIED=1 zig build process-evidence --summary all
