# zigeffect-transport

Real process-to-process ZigEffect cluster transport over bounded TCP framing.
The package owns client and server sockets and adapts the public
`ClusterTransport` request/response codec.

The transport descriptor is `production_candidate`. Its checked-in live
external conformance receipt covers the TLS multi-process boundary, while the
descriptor records support for TLS 1.2/1.3, peer verification, mutual TLS,
bounded framing, request deadlines, credential rotation, caller-supplied
discovery, connection pooling, and graceful drain. This status is
capability-specific: deployments still require a compatible system OpenSSL 3
installation, and service discovery remains the caller's responsibility.

Run `zig build test` for deterministic coverage and inspect the receipt named
by the capability descriptor before treating live conformance as current.
