# zigeffect QUIC Adapter Design

## Goal

Add an experimental QUIC/HTTP3/WebTransport adapter around
`endel/quic-zig` without destabilizing the stable `zstd.Http` contract.

## Context

`quic-zig` is a pure-Zig QUIC, HTTP/3, WebTransport, and MoQ implementation. Its
README says the project is not production-ready and public APIs may change, so
zigeffect should treat it like `zigeffect-postgres`: a separate adapter package
that imports `zigeffect-std`, not a dependency of the core engine or std facade.

## Architecture

- `packages/zigeffect-quic` imports `zigeffect_std` and `quic`.
- `zstd.Http.Request` and `zstd.Http.Response` remain the public HTTP boundary.
- `QuicHttpClient` implements `sendAlloc` so it can be used with
  `zstd.Http.sendEffect`.
- `WebTransportClient` exposes local session messages for future workbench live
  development feeds.
- `FakeQuicHttpClient` and `FakeWebTransportClient` provide deterministic tests
  with no UDP, certificate, or external server dependency.
- Receipts and causal details redact URLs, headers, payloads, and datagrams
  before they reach artifacts.

## Scope

- Pin `quic-zig` to the inspected commit.
- Add compile-tested QUIC HTTP/3 client wrapper.
- Add deterministic fake client and WebTransport session receipts.
- Add examples that local users can copy.
- Add docs and roadmap entry for M18.

## Non-Goals

- Do not replace `zstd.Http.LocalClient` as the default client.
- Do not require live network tests in CI.
- Do not implement production certificate provisioning.
- Do not add MoQ or browser WebTransport UX yet.

## Acceptance Criteria

- `bun run zigeffect:quic:test` builds tests and examples.
- A fake QUIC HTTP client works through `zstd.Http.sendEffect` and records
  redacted causal facts.
- A real `QuicHttpClient` compiles against `quic-zig` and has the same
  `sendAlloc` shape as std HTTP clients.
- WebTransport local messages produce redacted JSON receipts.
- Docs clearly mark the adapter experimental and optional.
