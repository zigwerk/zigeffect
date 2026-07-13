#!/usr/bin/env python3
"""Authenticated four-shape gRPC probe for a private Cloud Run service."""

from __future__ import annotations

import argparse
import json
import os
from urllib.parse import urlparse


def int64_message(value: int) -> bytes:
    encoded = bytearray((0x08,))
    while value >= 0x80:
        encoded.append((value & 0x7F) | 0x80)
        value >>= 7
    encoded.append(value)
    return bytes(encoded)


def authority(target: str) -> str:
    parsed = urlparse(target)
    if parsed.scheme != "https" or not parsed.hostname:
        raise ValueError("GRPC_TARGET must be an https Cloud Run URL")
    return f"{parsed.hostname}:{parsed.port or 443}"


def self_test() -> None:
    assert int64_message(0) == b"\x08\x00"
    assert int64_message(128) == b"\x08\x80\x01"
    assert authority("https://service.example.run.app") == "service.example.run.app:443"


def run_probe(target: str, audience: str) -> dict[str, object]:
    import grpc
    from google.auth.transport.requests import Request
    from google.oauth2 import id_token

    token = id_token.fetch_id_token(Request(), audience)
    metadata = (("authorization", f"Bearer {token}"),)
    channel = grpc.secure_channel(authority(target), grpc.ssl_channel_credentials())
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
    bidi = channel.stream_stream(
        "/zigeffect.grpc.v1.ConformanceService/BidiStream",
        request_serializer=lambda value: value,
        response_deserializer=lambda value: value,
    )
    checks: list[str] = []
    try:
        assert health(b"", metadata=metadata, timeout=15) == b"\x08\x01"
        checks.append("unary")
        assert client_stream(
            iter((int64_message(1), int64_message(2), int64_message(3))),
            metadata=metadata,
            timeout=15,
        ) == int64_message(3)
        checks.append("client_streaming")
        assert list(server_stream(int64_message(3), metadata=metadata, timeout=15)) == [
            b"",
            int64_message(1),
            int64_message(2),
        ]
        checks.append("server_streaming")
        assert list(
            bidi(
                iter((int64_message(1), int64_message(2), int64_message(3))),
                metadata=metadata,
                timeout=15,
            )
        ) == [int64_message(1), int64_message(2), int64_message(3)]
        checks.append("bidirectional_streaming")
    finally:
        channel.close()
    return {
        "schema": "zigeffect.grpc-gcp-probe",
        "version": 1,
        "status": "passed",
        "complete": True,
        "authentication": "metadata-server-oidc-id-token",
        "tls": "platform-trust-and-hostname-verified",
        "checks": checks,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    target = os.environ["GRPC_TARGET"]
    receipt = run_probe(target, os.environ.get("GRPC_AUDIENCE", target))
    print("ZIGEFFECT_GRPC_GCP_PROBE=" + json.dumps(receipt, sort_keys=True))


if __name__ == "__main__":
    main()
