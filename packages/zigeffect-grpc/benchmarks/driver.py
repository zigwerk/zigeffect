#!/usr/bin/env python3
import argparse
import concurrent.futures
import json
import math
import os
import subprocess
import time

# The driver samples Docker cgroups between phases.  Disable gRPC's optional
# fork handlers before importing the C extension so those short-lived metric
# readers do not emit one warning per active completion-queue file descriptor.
os.environ.setdefault("GRPC_ENABLE_FORK_SUPPORT", "0")

import grpc


def varint(value):
    output = bytearray()
    while value >= 0x80:
        output.append((value & 0x7F) | 0x80)
        value >>= 7
    output.append(value)
    return bytes(output)


def varint_field(number, value):
    return varint(number << 3) + varint(value)


def bytes_field(number, value):
    return varint((number << 3) | 2) + varint(len(value)) + value


def parse_varints(message):
    values = {}
    offset = 0
    while offset < len(message):
        tag = 0
        shift = 0
        while True:
            byte = message[offset]
            offset += 1
            tag |= (byte & 0x7F) << shift
            if byte < 0x80:
                break
            shift += 7
        field = tag >> 3
        wire = tag & 7
        if wire == 0:
            value = 0
            shift = 0
            while True:
                byte = message[offset]
                offset += 1
                value |= (byte & 0x7F) << shift
                if byte < 0x80:
                    break
                shift += 7
            values[field] = value
        elif wire == 2:
            length = 0
            shift = 0
            while True:
                byte = message[offset]
                offset += 1
                length |= (byte & 0x7F) << shift
                if byte < 0x80:
                    break
                shift += 7
            offset += length
        else:
            raise ValueError(f"unsupported protobuf wire type {wire}")
    return values


def cgroup_value(container, path, key=None):
    output = subprocess.check_output(
        ["docker", "exec", container, "sh", "-c", f"cat {path}"],
        text=True,
    )
    if key is None:
        return int(output.strip())
    for line in output.splitlines():
        name, value = line.split()
        if name == key:
            return int(value)
    raise RuntimeError(f"{key} missing from {path}")


def percentile(sorted_values, percentile_value):
    index = max(0, math.ceil(len(sorted_values) * percentile_value) - 1)
    return sorted_values[index] * 1000


def run_shape(shape, calls, workers, methods, stream_messages, payload):
    message = varint_field(1, 1) + (bytes_field(2, payload) if payload else b"")
    unary_message = bytes_field(1, b"benchmark") + varint_field(2, 1) + (bytes_field(3, payload) if payload else b"")
    server_message = varint_field(1, stream_messages) + (bytes_field(2, payload) if payload else b"")

    def invoke(index):
        started = time.perf_counter()
        if shape == "unary":
            response = methods[shape](unary_message, timeout=30)
            if parse_varints(response).get(2) != 1:
                raise AssertionError("invalid unary response")
        elif shape == "client_streaming":
            response = methods[shape](iter([message] * stream_messages), timeout=30)
            if parse_varints(response).get(1) != stream_messages:
                raise AssertionError("invalid client-stream response")
        elif shape == "server_streaming":
            responses = list(methods[shape](server_message, timeout=30))
            if len(responses) != stream_messages:
                raise AssertionError("invalid server-stream response count")
        else:
            responses = list(methods[shape](iter([message] * stream_messages), timeout=30))
            if len(responses) != stream_messages:
                raise AssertionError("invalid bidi-stream response count")
        return time.perf_counter() - started

    started = time.perf_counter()
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
        latencies = list(executor.map(invoke, range(calls)))
    elapsed = time.perf_counter() - started
    ordered = sorted(latencies)
    return {
        "shape": shape,
        "calls": calls,
        "workers": workers,
        "stream_messages": stream_messages,
        "request_payload_bytes": len(payload),
        "elapsed_seconds": elapsed,
        "throughput_calls_per_second": calls / elapsed,
        "latency_ms": {
            "p50": percentile(ordered, 0.50),
            "p95": percentile(ordered, 0.95),
            "p99": percentile(ordered, 0.99),
            "max": ordered[-1] * 1000,
        },
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", required=True)
    parser.add_argument("--address", required=True)
    parser.add_argument("--container", required=True)
    parser.add_argument("--calls", type=int, default=400)
    parser.add_argument("--workers", type=int, default=32)
    parser.add_argument("--stream-messages", type=int, default=8)
    parser.add_argument("--payload-size", type=int, default=1024)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    if min(args.calls, args.workers, args.stream_messages) <= 0 or args.payload_size < 0:
        raise ValueError("benchmark bounds must be positive")

    channel = grpc.insecure_channel(
        args.address,
        options=[
            ("grpc.max_send_message_length", 16 * 1024 * 1024),
            ("grpc.max_receive_message_length", 16 * 1024 * 1024),
        ],
    )
    grpc.channel_ready_future(channel).result(timeout=30)
    identity = lambda value: value
    methods = {
        "unary": channel.unary_unary(
            "/zigeffect.grpc.v1.ConformanceService/Unary",
            request_serializer=identity,
            response_deserializer=identity,
        ),
        "client_streaming": channel.stream_unary(
            "/zigeffect.grpc.v1.ConformanceService/ClientStream",
            request_serializer=identity,
            response_deserializer=identity,
        ),
        "server_streaming": channel.unary_stream(
            "/zigeffect.grpc.v1.ConformanceService/ServerStream",
            request_serializer=identity,
            response_deserializer=identity,
        ),
        "bidirectional_streaming": channel.stream_stream(
            "/zigeffect.grpc.v1.ConformanceService/BidiStream",
            request_serializer=identity,
            response_deserializer=identity,
        ),
    }
    snapshot = channel.unary_unary(
        "/zigeffect.benchmark.v1.Stats/Snapshot",
        request_serializer=identity,
        response_deserializer=identity,
    )
    payload = b"x" * args.payload_size
    results = []
    for shape in methods:
        run_shape(shape, min(32, args.calls), min(8, args.workers), methods, args.stream_messages, payload)
        before_alloc = parse_varints(snapshot(b"", timeout=10))
        before_cpu = cgroup_value(args.container, "/sys/fs/cgroup/cpu.stat", "usage_usec")
        before_memory = cgroup_value(args.container, "/sys/fs/cgroup/memory.current")
        result = run_shape(shape, args.calls, args.workers, methods, args.stream_messages, payload)
        after_cpu = cgroup_value(args.container, "/sys/fs/cgroup/cpu.stat", "usage_usec")
        after_memory = cgroup_value(args.container, "/sys/fs/cgroup/memory.current")
        peak_memory = cgroup_value(args.container, "/sys/fs/cgroup/memory.peak")
        after_alloc = parse_varints(snapshot(b"", timeout=10))
        result["server_cpu_seconds"] = (after_cpu - before_cpu) / 1_000_000
        result["server_cpu_nanos_per_rpc"] = (after_cpu - before_cpu) * 1000 / args.calls
        result["server_memory_bytes"] = {
            "before": before_memory,
            "after": after_memory,
            "peak": peak_memory,
        }
        allocation_delta = after_alloc.get(1, 0) - before_alloc.get(1, 0)
        allocated_bytes_delta = after_alloc.get(3, 0) - before_alloc.get(3, 0)
        result["server_allocator"] = {
            "allocations": allocation_delta,
            "allocations_per_rpc": allocation_delta / args.calls,
            "allocated_bytes": allocated_bytes_delta,
            "allocated_bytes_per_rpc": allocated_bytes_delta / args.calls,
            "live_bytes_after": after_alloc.get(4, 0),
            "peak_live_bytes": after_alloc.get(5, 0),
        }
        results.append(result)
    channel.close()
    receipt = {
        "schema": "zigeffect.grpc-benchmark-target",
        "version": 1,
        "target": args.target,
        "status": "passed",
        "complete": True,
        "results": results,
    }
    with open(args.output, "w", encoding="utf-8") as output:
        json.dump(receipt, output, sort_keys=True)
        output.write("\n")


if __name__ == "__main__":
    main()
