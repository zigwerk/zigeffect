#!/usr/bin/env python3
"""Run the upstream gRPC Python interoperability TestService locally."""

from concurrent import futures
import pathlib
import signal
import sys

import grpc

from src.proto.grpc.testing import test_pb2_grpc
from tests.interop import service


def main() -> None:
    port, mode, certificate, key = sys.argv[1:]
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=16))
    test_pb2_grpc.add_TestServiceServicer_to_server(service.TestService(), server)
    address = f"127.0.0.1:{port}"
    if mode == "tls":
        credentials = grpc.ssl_server_credentials(
            ((pathlib.Path(key).read_bytes(), pathlib.Path(certificate).read_bytes()),)
        )
        assert server.add_secure_port(address, credentials) != 0
    else:
        assert server.add_insecure_port(address) != 0
    server.start()
    signal.signal(signal.SIGTERM, lambda *_: server.stop(0))
    server.wait_for_termination()


if __name__ == "__main__":
    main()
