#!/usr/bin/env bash
set -euo pipefail

suffix="$$"
network="zigeffect-cockroach-failover-${suffix}"
nodes=("ze-crdb1-${suffix}" "ze-crdb2-${suffix}" "ze-crdb3-${suffix}")
ports=(26271 26272 26273)
cleanup() {
  docker rm -f "${nodes[@]}" >/dev/null 2>&1 || true
  docker network rm "$network" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker network create "$network" >/dev/null
join="${nodes[0]}:26257,${nodes[1]}:26257,${nodes[2]}:26257"
for index in 0 1 2; do
  docker run --rm -d --name "${nodes[$index]}" --hostname "${nodes[$index]}" --network "$network" \
    -p "127.0.0.1:${ports[$index]}:26257" cockroachdb/cockroach:v26.2.1 \
    start --insecure --listen-addr=0.0.0.0:26257 --advertise-addr="${nodes[$index]}:26257" \
    --http-addr=0.0.0.0:8080 --join="$join" >/dev/null
done

for _ in $(seq 1 240); do
  if docker exec "${nodes[0]}" cockroach node status --insecure --host="${nodes[0]}:26257" >/dev/null 2>&1; then break; fi
  docker exec "${nodes[0]}" cockroach init --insecure --host="${nodes[0]}:26257" >/dev/null 2>&1 || true
  sleep 0.25
done
docker exec "${nodes[0]}" cockroach sql --insecure --host="${nodes[0]}:26257" -e 'create database if not exists zigeffect' >/dev/null

export ZIGEFFECT_TEST_DATABASE_URL="postgresql://root@127.0.0.1:${ports[0]},127.0.0.1:${ports[1]},127.0.0.1:${ports[2]}/zigeffect?sslmode=disable&target_session_attrs=read-write"
zig build restart-seed -Dlive-database=cockroachdb
docker stop "${nodes[0]}" >/dev/null
for _ in $(seq 1 120); do
  if docker exec "${nodes[1]}" cockroach sql --insecure --host="${nodes[1]}:26257" -e 'select 1' >/dev/null 2>&1; then break; fi
  sleep 0.25
done
zig build restart-verify -Dlive-database=cockroachdb
