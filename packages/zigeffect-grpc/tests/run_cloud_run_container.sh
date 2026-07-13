#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
python="${1:-python3}"
image="zigeffect-grpc-cloud-run:smoke-${TARGETARCH:-native}"
name="zigeffect-grpc-cloud-run-smoke-$$"
port=$((35000 + ($$ % 10000)))
load_calls="${GRPC_LOAD_CALLS:-256}"
load_workers="${GRPC_LOAD_WORKERS:-32}"
soak_seconds="${GRPC_SOAK_SECONDS:-0}"
receipt="${GRPC_LOAD_RECEIPT:-}"
max_memory_growth_bytes="${GRPC_MAX_MEMORY_GROWTH_BYTES:-67108864}"
memory_samples_file="$(mktemp)"
load_result_file="$(mktemp)"
memory_monitor_pid=""

cleanup() {
  if [[ -n "$memory_monitor_pid" ]]; then
    kill "$memory_monitor_pid" >/dev/null 2>&1 || true
    wait "$memory_monitor_pid" 2>/dev/null || true
  fi
  rm -f "$memory_samples_file" "$load_result_file"
  docker rm -f "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker build --progress=plain \
  -f "$repo_root/packages/zigeffect-grpc/examples/cloud_run/Dockerfile" \
  -t "$image" "$repo_root"
docker run --name "$name" -d -e PORT=8080 -p "127.0.0.1:${port}:8080" "$image" >/dev/null

sample_memory() {
  docker exec "$name" sh -c 'cat /sys/fs/cgroup/memory.current 2>/dev/null || cat /sys/fs/cgroup/memory/memory.usage_in_bytes' >>"$memory_samples_file" 2>/dev/null || true
}

monitor_memory() {
  while docker inspect "$name" >/dev/null 2>&1; do
    sample_memory
    sleep 5
  done
}

monitor_memory &
memory_monitor_pid=$!

"$python" - "$port" "$load_calls" "$load_workers" "$soak_seconds" "$load_result_file" <<'PY'
import json
import sys
import time
import grpc
from concurrent.futures import ThreadPoolExecutor

channel = grpc.insecure_channel(f"127.0.0.1:{sys.argv[1]}")
minimum_calls = int(sys.argv[2])
worker_count = int(sys.argv[3])
soak_seconds = float(sys.argv[4])
result_path = sys.argv[5]
if minimum_calls <= 0 or worker_count <= 0 or soak_seconds < 0:
    raise ValueError("load calls/workers must be positive and soak seconds must be non-negative")
health = channel.unary_unary(
    "/grpc.health.v1.Health/Check",
    request_serializer=lambda value: value,
    response_deserializer=lambda value: value,
)
client_stream = channel.stream_unary(
    "/zigeffect.grpc.v1.ConformanceService/ClientStream",
    request_serializer=lambda value: value,
    response_deserializer=lambda value: value,
)
server_stream = channel.unary_stream(
    "/zigeffect.grpc.v1.ConformanceService/ServerStream",
    request_serializer=lambda value: value,
    response_deserializer=lambda value: value,
)
bidi_stream = channel.stream_stream(
    "/zigeffect.grpc.v1.ConformanceService/BidiStream",
    request_serializer=lambda value: value,
    response_deserializer=lambda value: value,
)
deadline = time.monotonic() + 30
while True:
    try:
        response = health(b"", timeout=2)
        assert response == b"\x08\x01", response
        break
    except grpc.RpcError:
        if time.monotonic() >= deadline:
            raise
        time.sleep(0.1)

def int64_message(value):
    encoded = bytearray((0x08,))
    while value >= 0x80:
        encoded.append((value & 0x7f) | 0x80)
        value >>= 7
    encoded.append(value)
    return bytes(encoded)

def check(index):
    started = time.monotonic()
    shape = index % 4
    if shape == 0:
        response = health(b"", timeout=5)
        assert response == b"\x08\x01", response
        name = "unary"
    elif shape == 1:
        response = client_stream(iter((int64_message(1), int64_message(2), int64_message(3))), timeout=5)
        assert response == int64_message(3), response
        name = "client_streaming"
    elif shape == 2:
        response = list(server_stream(int64_message(3), timeout=5))
        assert response == [b"", int64_message(1), int64_message(2)], response
        name = "server_streaming"
    else:
        response = list(bidi_stream(iter((int64_message(1), int64_message(2), int64_message(3))), timeout=5))
        assert response == [int64_message(1), int64_message(2), int64_message(3)], response
        name = "bidirectional_streaming"
    return time.monotonic() - started, name

started = time.monotonic()
soak_until = started + soak_seconds
completed = 0
latency_total = 0.0
latency_max = 0.0
histogram = {"le_5ms": 0, "le_25ms": 0, "le_100ms": 0, "le_500ms": 0, "gt_500ms": 0}
shapes = {"unary": 0, "client_streaming": 0, "server_streaming": 0, "bidirectional_streaming": 0}
batch_size = max(worker_count * 8, 1)
with ThreadPoolExecutor(max_workers=worker_count) as workers:
    while completed < minimum_calls or time.monotonic() < soak_until:
        observations = workers.map(check, range(completed, completed + batch_size))
        for duration, shape in observations:
            completed += 1
            shapes[shape] += 1
            latency_total += duration
            latency_max = max(latency_max, duration)
            if duration <= 0.005:
                histogram["le_5ms"] += 1
            elif duration <= 0.025:
                histogram["le_25ms"] += 1
            elif duration <= 0.100:
                histogram["le_100ms"] += 1
            elif duration <= 0.500:
                histogram["le_500ms"] += 1
            else:
                histogram["gt_500ms"] += 1
elapsed = time.monotonic() - started
result = {
    "schema": "zigeffect.grpc-cloud-run-load",
    "version": 1,
    "completed_calls": completed,
    "workers": worker_count,
    "requested_minimum_calls": minimum_calls,
    "requested_soak_seconds": soak_seconds,
    "elapsed_seconds": elapsed,
    "calls_per_second": completed / elapsed,
    "latency_mean_ms": latency_total * 1000 / completed,
    "latency_max_ms": latency_max * 1000,
    "latency_histogram": histogram,
    "completed_by_shape": shapes,
    "failures": 0,
}
encoded = json.dumps(result, sort_keys=True)
with open(result_path, "w", encoding="utf-8") as output:
    output.write(encoded + "\n")
channel.close()
PY

kill "$memory_monitor_pid" >/dev/null 2>&1 || true
wait "$memory_monitor_pid" 2>/dev/null || true
memory_monitor_pid=""
sample_memory

"$python" - "$load_result_file" "$memory_samples_file" "$max_memory_growth_bytes" "$receipt" <<'PY'
import json
import sys

result_path, samples_path, max_growth_raw, receipt_path = sys.argv[1:]
max_memory_growth_bytes = int(max_growth_raw)
if max_memory_growth_bytes <= 0:
    raise ValueError("maximum memory growth must be positive")
with open(result_path, encoding="utf-8") as source:
    result = json.load(source)
with open(samples_path, encoding="utf-8") as source:
    memory_samples = [int(line.strip()) for line in source if line.strip()]
if not memory_samples:
    raise RuntimeError("container memory sampling produced no evidence")
warmup_index = min(len(memory_samples) - 1, 2)
steady_samples = memory_samples[warmup_index:]
memory_growth_bytes = max(steady_samples) - min(steady_samples)
memory_qualified = memory_growth_bytes <= max_memory_growth_bytes
result["version"] = 2
result["memory"] = {
    "sample_interval_seconds": 5,
    "samples_bytes": memory_samples,
    "warmup_sample_index": warmup_index,
    "steady_min_bytes": min(steady_samples),
    "steady_peak_bytes": max(steady_samples),
    "growth_bytes": memory_growth_bytes,
    "max_growth_bytes": max_memory_growth_bytes,
    "qualified": memory_qualified,
}
encoded = json.dumps(result, sort_keys=True)
print(encoded)
if receipt_path:
    with open(receipt_path, "w", encoding="utf-8") as output:
        output.write(encoded + "\n")
if not memory_qualified:
    raise RuntimeError(f"container memory growth {memory_growth_bytes} exceeds {max_memory_growth_bytes}")
PY

docker stop --time 30 --signal SIGTERM "$name" >/dev/null
test "$(docker inspect -f '{{.State.ExitCode}}' "$name")" = "0"
trap - EXIT
docker rm "$name" >/dev/null
rm -f "$memory_samples_file" "$load_result_file"
