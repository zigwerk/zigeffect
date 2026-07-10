#!/usr/bin/env bash
set -euo pipefail

for command in docker zig; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'required command not found: %s\n' "$command" >&2
    exit 1
  fi
done

if ! docker info >/dev/null 2>&1; then
  printf 'Docker is not running\n' >&2
  exit 1
fi

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
package_dir="$(CDPATH= cd -- "$script_dir/.." && pwd)"
image="${COCKROACH_TEST_IMAGE:-cockroachdb/cockroach:v26.2.3}"
name="ziac-crdb-native-$RANDOM-$$"
work_dir="$(mktemp -d)"
certs="$work_dir/certs"
mkdir -p "$certs"

cleanup() {
  docker rm -f "$name" >/dev/null 2>&1 || true
  rm -rf "$work_dir"
}
trap cleanup EXIT INT TERM

docker run --rm -v "$certs:/certs" "$image" \
  cert create-ca --certs-dir=/certs --ca-key=/certs/ca.key
docker run --rm -v "$certs:/certs" "$image" \
  cert create-node localhost 127.0.0.1 0.0.0.0 "$name" \
  --certs-dir=/certs --ca-key=/certs/ca.key
docker run --rm -v "$certs:/certs" "$image" \
  cert create-client root --certs-dir=/certs --ca-key=/certs/ca.key

docker run -d --name "$name" -p 127.0.0.1::26257 -v "$certs:/certs:ro" "$image" \
  start \
  --certs-dir=/certs \
  --store=type=mem,size=768MiB \
  --listen-addr=0.0.0.0:26257 \
  --advertise-addr="$name:26257" \
  --advertise-sql-addr=localhost:26257 \
  --http-addr=0.0.0.0:8080 \
  --advertise-http-addr=localhost:8080 \
  --join="$name:26257" >/dev/null

initialized=false
for _ in $(seq 1 60); do
  if docker exec "$name" cockroach init \
    --host=localhost:26257 --certs-dir=/certs \
    >"$work_dir/init.out" 2>"$work_dir/init.err"; then
    initialized=true
    break
  fi
  if grep -q 'cluster has already been initialized' "$work_dir/init.err"; then
    initialized=true
    break
  fi
  if ! docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null | grep -q true; then
    docker logs "$name" >&2
    exit 1
  fi
  sleep 1
done

if [[ "$initialized" != true ]]; then
  cat "$work_dir/init.err" >&2
  docker logs "$name" >&2
  exit 1
fi

docker exec "$name" cockroach sql \
  --host=localhost:26257 --certs-dir=/certs \
  --execute="CREATE USER ziac WITH PASSWORD 'ziac-local-password'; GRANT admin TO ziac; CREATE USER app_user WITH PASSWORD 'ziac-app-password';"

host_port="$(docker port "$name" 26257/tcp | head -n 1)"
host_port="${host_port##*:}"
if [[ ! "$host_port" =~ ^[0-9]+$ ]]; then
  printf 'could not determine mapped CockroachDB SQL port\n' >&2
  exit 1
fi

(
  cd "$package_dir"
  SSL_CERT_FILE="$certs/ca.crt" \
    ZIGEFFECT_POSTGRES_LIVE_URL="postgresql://ziac:ziac-local-password@localhost:$host_port/defaultdb?sslmode=verify-full" \
    zig build test
)

(
  cd "$package_dir/../ziac"
  SSL_CERT_FILE="$certs/ca.crt" \
    ZIAC_COCKROACH_ADMIN_LIVE_URL="postgresql://ziac:ziac-local-password@localhost:$host_port/defaultdb?sslmode=verify-full" \
    ZIAC_COCKROACH_APP_LIVE_URL="postgresql://app_user:ziac-app-password@localhost:$host_port/ziac_native_gate?sslmode=verify-full" \
    zig build test
)

printf 'native CockroachDB verified-TLS pool and Ziac SQL lifecycle integration passed (%s)\n' "$image"
