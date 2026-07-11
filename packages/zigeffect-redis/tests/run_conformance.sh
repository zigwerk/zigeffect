#!/usr/bin/env bash
set -euo pipefail
port="${ZIGEFFECT_REDIS_PORT:-16379}"
dir="$(mktemp -d)"
password="$(openssl rand -hex 24)"
cleanup() { if [[ -f "$dir/redis.pid" ]]; then kill "$(cat "$dir/redis.pid")" 2>/dev/null || true; fi; rm -rf "$dir"; }
trap cleanup EXIT
printf 'bind 127.0.0.1\nport %s\nsave ""\nappendonly no\nrequirepass %s\ndaemonize yes\npidfile %s\ndir %s\n' "$port" "$password" "$dir/redis.pid" "$dir" >"$dir/redis.conf"
redis-server "$dir/redis.conf"
for _ in $(seq 1 100); do redis-cli --no-auth-warning -a "$password" -p "$port" ping >/dev/null 2>&1 && break; sleep 0.02; done
ZIGEFFECT_TEST_REDIS_PASSWORD="$password" zig build conformance -Dport="$port" --summary all
