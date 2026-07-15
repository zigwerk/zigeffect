#!/usr/bin/env python3
import argparse
import concurrent.futures
import json
import math
import os
import statistics
import subprocess
import time

# The driver samples Docker cgroups between phases. Disable gRPC's optional
# fork handlers before importing the C extension so metric readers do not emit
# one warning per active completion-queue file descriptor.
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


def latency_summary(latencies):
    ordered = sorted(latencies)
    return {
        "p50": percentile(ordered, 0.50),
        "p95": percentile(ordered, 0.95),
        "p99": percentile(ordered, 0.99),
        "p99_9": percentile(ordered, 0.999),
        "max": ordered[-1] * 1000,
        "mean": statistics.fmean(ordered) * 1000,
        "standard_deviation": statistics.pstdev(ordered) * 1000,
    }


def run_shape(shape, calls, workers, method_sets, stream_messages, payload, executor, duration_seconds):
    message = varint_field(1, 1) + (bytes_field(2, payload) if payload else b"")
    unary_message = bytes_field(1, b"benchmark") + varint_field(2, 1) + (bytes_field(3, payload) if payload else b"")
    server_message = varint_field(1, stream_messages) + (bytes_field(2, payload) if payload else b"")

    def invoke(index):
        methods = method_sets[index % len(method_sets)]
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
    if duration_seconds > 0:
        deadline = started + duration_seconds
        next_index = 0
        pending = set()
        for _ in range(workers):
            pending.add(executor.submit(invoke, next_index))
            next_index += 1
        latencies = []
        while pending:
            done, pending = concurrent.futures.wait(
                pending,
                return_when=concurrent.futures.FIRST_COMPLETED,
            )
            for future in done:
                latencies.append(future.result())
                if time.perf_counter() < deadline:
                    pending.add(executor.submit(invoke, next_index))
                    next_index += 1
    else:
        latencies = list(executor.map(invoke, range(calls)))
    elapsed = time.perf_counter() - started
    return {
        "shape": shape,
        "calls": len(latencies),
        "workers": workers,
        "connections": len(method_sets),
        "stream_messages": stream_messages,
        "request_payload_bytes": len(payload),
        "elapsed_seconds": elapsed,
        "throughput_calls_per_second": len(latencies) / elapsed,
        "latency_ms": latency_summary(latencies),
        "_latencies": latencies,
    }


def aggregate_repetitions(repetitions):
    latencies = []
    elapsed = 0.0
    calls = 0
    published = []
    for index, result in enumerate(repetitions):
        latencies.extend(result.pop("_latencies"))
        elapsed += result["elapsed_seconds"]
        calls += result["calls"]
        result["repetition"] = index + 1
        published.append(result)
    first = repetitions[0]
    return {
        "shape": first["shape"],
        "calls": calls,
        "workers": first["workers"],
        "connections": first["connections"],
        "stream_messages": first["stream_messages"],
        "request_payload_bytes": first["request_payload_bytes"],
        "elapsed_seconds": elapsed,
        "throughput_calls_per_second": calls / elapsed,
        "latency_ms": latency_summary(latencies),
        "sample_count": calls,
        "repetitions": published,
    }


def methods_for_channel(channel):
    identity = lambda value: value
    return {
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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", required=True)
    parser.add_argument("--address", required=True)
    parser.add_argument("--container", help="Docker container used for cgroup CPU/memory sampling")
    parser.add_argument("--calls", type=int, default=10_000)
    parser.add_argument("--workers", type=int, default=32)
    parser.add_argument("--connections", type=int, default=1)
    parser.add_argument("--warmup-calls", type=int, default=512)
    parser.add_argument("--warmup-seconds", type=float, default=2)
    parser.add_argument("--repetitions", type=int, default=5)
    parser.add_argument("--duration-seconds", type=float, default=0)
    parser.add_argument("--stream-messages", type=int, default=8)
    parser.add_argument("--payload-size", type=int, default=1024)
    parser.add_argument(
        "--shapes",
        default="unary,client_streaming,server_streaming,bidirectional_streaming",
        help="comma-separated RPC shapes",
    )
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    if min(args.calls, args.workers, args.connections, args.repetitions, args.stream_messages) <= 0:
        raise ValueError("benchmark bounds must be positive")
    if args.payload_size < 0 or args.warmup_calls < 0 or args.warmup_seconds < 0 or args.duration_seconds < 0:
        raise ValueError("benchmark sizes and durations cannot be negative")
    shapes = [shape.strip() for shape in args.shapes.split(",") if shape.strip()]
    supported_shapes = {"unary", "client_streaming", "server_streaming", "bidirectional_streaming"}
    if not shapes or any(shape not in supported_shapes for shape in shapes):
        raise ValueError("unsupported benchmark shape")

    channel_options = [
        ("grpc.max_send_message_length", 16 * 1024 * 1024),
        ("grpc.max_receive_message_length", 16 * 1024 * 1024),
    ]
    channels = [grpc.insecure_channel(args.address, options=channel_options) for _ in range(args.connections)]
    try:
        for channel in channels:
            grpc.channel_ready_future(channel).result(timeout=30)
        method_sets = [methods_for_channel(channel) for channel in channels]
        identity = lambda value: value
        snapshot = channels[0].unary_unary(
            "/zigeffect.benchmark.v1.Stats/Snapshot",
            request_serializer=identity,
            response_deserializer=identity,
        )
        payload = b"x" * args.payload_size
        results = []
        # Executor construction and teardown are deliberately outside every
        # measured interval.
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as executor:
            for shape in shapes:
                if args.warmup_calls:
                    run_shape(
                        shape,
                        args.warmup_calls,
                        args.workers,
                        method_sets,
                        args.stream_messages,
                        payload,
                        executor,
                        0,
                    )
                if args.warmup_seconds:
                    run_shape(
                        shape,
                        args.workers,
                        args.workers,
                        method_sets,
                        args.stream_messages,
                        payload,
                        executor,
                        args.warmup_seconds,
                    )
                before_alloc = parse_varints(snapshot(b"", timeout=10))
                before_cpu = cgroup_value(args.container, "/sys/fs/cgroup/cpu.stat", "usage_usec") if args.container else None
                before_memory = cgroup_value(args.container, "/sys/fs/cgroup/memory.current") if args.container else None
                samples = [
                    run_shape(
                        shape,
                        args.calls,
                        args.workers,
                        method_sets,
                        args.stream_messages,
                        payload,
                        executor,
                        args.duration_seconds,
                    )
                    for _ in range(args.repetitions)
                ]
                result = aggregate_repetitions(samples)
                after_cpu = cgroup_value(args.container, "/sys/fs/cgroup/cpu.stat", "usage_usec") if args.container else None
                after_memory = cgroup_value(args.container, "/sys/fs/cgroup/memory.current") if args.container else None
                peak_memory = cgroup_value(args.container, "/sys/fs/cgroup/memory.peak") if args.container else None
                after_alloc = parse_varints(snapshot(b"", timeout=10))
                total_calls = result["calls"]
                if args.container:
                    cpu_micros = after_cpu - before_cpu
                    result["server_cpu_seconds"] = cpu_micros / 1_000_000
                    result["server_cpu_nanos_per_rpc"] = cpu_micros * 1000 / total_calls
                    result["server_memory_bytes"] = {
                        "before": before_memory,
                        "after": after_memory,
                        "peak": peak_memory,
                    }
                allocation_delta = after_alloc.get(1, 0) - before_alloc.get(1, 0)
                allocated_bytes_delta = after_alloc.get(3, 0) - before_alloc.get(3, 0)
                result["server_allocator"] = {
                    "allocations": allocation_delta,
                    "allocations_per_rpc": allocation_delta / total_calls,
                    "allocated_bytes": allocated_bytes_delta,
                    "allocated_bytes_per_rpc": allocated_bytes_delta / total_calls,
                    "live_bytes_after": after_alloc.get(4, 0),
                    "peak_live_bytes": after_alloc.get(5, 0),
                }
                results.append(result)
    finally:
        for channel in channels:
            channel.close()

    receipt = {
        "schema": "zigeffect.grpc-benchmark-target",
        "version": 2,
        "target": args.target,
        "status": "passed",
        "complete": True,
        "configuration": {
            "calls_per_repetition": args.calls,
            "duration_seconds_per_repetition": args.duration_seconds,
            "warmup_calls": args.warmup_calls,
            "warmup_seconds": args.warmup_seconds,
            "repetition_count": args.repetitions,
            "worker_count": args.workers,
            "connection_count": args.connections,
            "shapes": shapes,
        },
        "results": results,
    }
    with open(args.output, "w", encoding="utf-8") as output:
        json.dump(receipt, output, sort_keys=True)
        output.write("\n")


if __name__ == "__main__":
    main()
