# zigeffect-quic

`zigeffect-quic` is the experimental QUIC/HTTP3/WebTransport adapter package
for `zigeffect-std`.

The package wraps [`endel/quic-zig`](https://github.com/endel/quic-zig) behind
zigeffect request/response contracts, redaction, deterministic fakes, and
causal receipts. It is intentionally optional because upstream marks its public
API as not production-ready yet.

## Verify

From the repository root:

```sh
bun run zigeffect:quic:test
```

This builds unit tests plus examples. The tests do not open sockets; they prove
the zigeffect-facing contracts, deterministic fakes, redaction, and causal
effect integration.

## HTTP/3

`QuicHttpClient` has the same `sendAlloc` shape as `zstd.Http` clients:

```zig
const zquic = @import("zigeffect_quic");

var client = zquic.QuicHttpClient.init(.{
    .address = "127.0.0.1",
    .port = 4433,
    .server_name = "localhost",
    .skip_cert_verify = true, // local testing only
});

var response = try client.sendAlloc(allocator, .{
    .method = "GET",
    .url = "https://localhost/health",
});
defer response.deinit(allocator);
```

For deterministic tests and local agent receipts, use `FakeQuicHttpClient`
through `zstd.Http.sendEffect`.

## WebTransport

The package includes receipt helpers and deterministic message capture for
WebTransport streams and datagrams. Its local development-session bridge:

- `bridgeLocalDevSessionJsonlAlloc` wraps `zstd.Agent.Session` JSONL as
  redacted `zigeffect.webtransport.local-dev-frame.v1` JSONL.
- The bridge records every frame into `FakeWebTransportClient` so CI can prove
  the transport boundary without opening sockets.
- Bridge receipts redact URLs, tokens, passwords, and payload details before
  they can reach causal artifacts or workbench payloads.
- The Solid workbench can unwrap these frames and show transport status in the
  Dev Session view.

Copyable examples:

- `examples/http3_smoke.zig`
- `examples/webtransport_receipt.zig`
