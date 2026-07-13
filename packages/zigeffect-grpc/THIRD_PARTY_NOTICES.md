# Third-Party Notices

## ziglana/gRPC-zig

The original protocol investigation used public-domain source material from
[`ziglana/gRPC-zig`](https://github.com/ziglana/gRPC-zig), revision
`ab34a7778193a309fc61117230643d2cbb5c2aaf`. That project is distributed under
the Unlicense. ZigEffect's API, HTTP/2 transport, server, channel, streaming,
security, Connect, generation, and evidence implementations are
repository-owned rewrites and do not preserve the upstream API.

## Arwalk/zig-protobuf

The package vendors the Zig 0.16-compatible `Arwalk/zig-protobuf` runtime and
generator at revision `2b7103e1f71a02cb19bb464820ab6fa7376e5a17`. It is
licensed under the MIT License; its complete license remains in the vendored
package directory.

ZigEffect carries defensive patches in the vendored Protobuf decoder: a
negative signed packed/repeated length is rejected as `InvalidInput` before
conversion to `usize`, and unknown-field scalar/length varints are bounded to
the Protobuf ten-byte representation before shifting or allocating. Minimized
regression seeds and fuzz tests are retained in `zigeffect-grpc`; this notice
records the local divergence until the fixes are upstreamed.

## gRPC standard service schemas

The Health, Reflection, and Channelz protocol schemas under `proto/grpc` come
from the gRPC project and retain their Apache License 2.0 notices in the source
files.

## Official gRPC interoperability sources

The portable gRPC interoperability schemas, Python reference client/service
sources, and test credentials under `tests/official` are derived from the gRPC
project at revision `e3e0c8b891643a50062f836b9decb39e57a56171`. They are
licensed under Apache License 2.0; the complete license is retained as
`tests/official/GRPC_LICENSE`.

## Connect conformance schemas and runner

The Connect conformance schemas under `tests/connect-conformance` and the CI
runner used to verify this package are from `connectrpc/conformance` revision
`5b2b709b99e2c8d4aa872fe51bb6a75f09d370e4` (`v1.1.0-dev`). They are
licensed under Apache License 2.0; the complete license is retained as
`tests/connect-conformance/LICENSE`. The runner is built from that exact
revision in CI and is not redistributed with the Zig package.

## grpc-go interoperability executables

CI builds the official grpc-go interoperability client and server from
`google.golang.org/grpc` version `v1.81.1` to run the gRPC differential matrix
in both roles over plaintext and TLS. grpc-go is licensed under Apache License
2.0. These executables are qualification dependencies and are not redistributed
with the Zig package.

## Differential benchmark runtimes

The reproducible qualification harness builds grpc-go `v1.81.1`, tonic
`0.12.3`, and Debian 12's gRPC C++ `1.51.x` in isolated containers. grpc-go and
gRPC C++ are licensed under Apache License 2.0. Tonic is dual-licensed under
MIT or Apache License 2.0. These are benchmark-only qualification dependencies;
their binaries and container images are not redistributed with the Zig
package.

## GCP deployment qualification probe

The optional Cloud Run qualification job installs grpcio `1.82.1` and
google-auth `2.40.3` in its probe image. grpcio is Apache License 2.0 and
google-auth is Apache License 2.0. The image is a temporary qualification
artifact and is not part of the Zig package runtime.
