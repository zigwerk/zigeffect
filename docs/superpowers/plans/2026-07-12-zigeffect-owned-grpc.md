# ZigEffect-Owned gRPC Implementation Plan

**Goal:** Deliver a repository-owned gRPC protocol and Effect boundary in
`zigeffect-std`, then qualify a native HTTP/2 adapter without depending on the
upstream gRPC-zig package.

**Architecture:** `zstd.Grpc` owns portable protocol, service, deterministic,
and evidence contracts. `zigeffect-grpc` owns native sockets, TLS/ALPN, HTTP/2,
and live interoperability. Capability maturity remains evidence-driven.

**Toolchain:** Zig 0.16, ZigEffect Testing v2, package-native Zig builds.

## Task 1: Provenance And Public Contract

Files:

- Create `packages/zigeffect-std/THIRD_PARTY_NOTICES.md`
- Create `packages/zigeffect-std/src/grpc/root.zig`
- Modify `packages/zigeffect-std/src/root.zig`
- Modify `packages/zigeffect-std/build.zig.zon`

- [x] Record the inspected gRPC-zig revision and Unlicense provenance.
- [x] Add failing facade and capability tests for `zstd.Grpc`.
- [x] Add `grpc_client` and `grpc_server` capability kinds and deterministic
      built-ins.

## Task 2: Wire Contract

Files:

- Modify `packages/zigeffect-std/src/grpc/root.zig`

- [x] Add failing message framing and fragmented decoder tests.
- [x] Implement bounded per-message framing and incremental decoding.
- [x] Add failing metadata, timeout, response-header, and trailer tests.
- [x] Implement ASCII/binary metadata, timeout encoding, canonical statuses,
      percent-safe messages, and trailers-only validation.

## Task 3: Effect Client And Deterministic Providers

Files:

- Modify `packages/zigeffect-std/src/grpc/root.zig`

- [x] Add failing fake, scripted, cancellation, and causal tests.
- [x] Implement owned unary responses, erased clients, fake/scripted clients,
      and typed call failures.
- [x] Implement `invokeEffect` with `grpc.call` causal facts.
- [x] Add bounded redacted call receipts and retry classification.

## Task 4: Server, Routing, Streaming, And Health

Files:

- Modify `packages/zigeffect-std/src/grpc/root.zig`

- [x] Add failing exact routing and unknown-method tests.
- [x] Implement service/method registry and in-process client transport.
- [x] Add bounded ordered message streams for all four gRPC call shapes.
- [x] Add health registry behavior matching gRPC health status semantics.

## Task 5: Shared Consumer Migration And Documentation

Files:

- Modify `packages/ziac/src/gcp/grpc.zig`
- Modify `packages/ziac/test/gcp_grpc_test.zig`
- Modify `packages/zigeffect-std/README.md`
- Create `packages/zigeffect-std/examples/grpc_unary.zig`
- Modify `packages/zigeffect-std/build.zig`

- [x] Alias Ziac's generic codec and qualification contract to `zstd.Grpc`.
- [x] Add a compiling one-import unary example.
- [x] Document ownership, supported behavior, and qualification limits.

## Task 6: Native HTTP/2 Adapter

Files:

- Create `packages/zigeffect-grpc/build.zig`
- Create `packages/zigeffect-grpc/build.zig.zon`
- Create `packages/zigeffect-grpc/src/root.zig`
- Create focused HTTP/2 modules and tests under `packages/zigeffect-grpc/src/`
- Modify `package.json`

- [x] Port and correct the useful upstream HTTP/2 frame and stream concepts.
- [x] Implement partial-I/O-safe frame parsing, settings, HPACK, stream state,
      flow control, cancellation, GOAWAY, and graceful drain.
- [x] Implement TLS/ALPN provider integration and reusable client connections.
- [x] Bind unary calls to `zstd.Grpc.Transport` and all streaming shapes to the
      bounded `zstd.Grpc.StreamingRequest`/`StreamingResponse` contract.
- [x] Promote the descriptor only after Task 7 passes with a content-bound live
      receipt.

## Task 7: Verification And Qualification

- [x] Run `zig fmt --check` for every changed Zig package.
- [x] Run `zig build test` and `zig build examples` in `zigeffect-std`.
- [x] Inspect `.zigeffect/tests/suites/zigeffect-std-tests.json` for a complete
      pass, equal discovered/executed counts, zero pending tests, leaks, and
      logged errors.
- [x] Run Ziac's focused gRPC tests and package suite.
- [x] Run native byte-vector and process-local interoperability tests.
- [x] Run external gRPC interoperability and record a bounded, redacted live
      conformance receipt before promoting capability maturity.
- [x] Run `packages/zigeffect/scripts/check_testing_v2_migration.sh` because a
      standard-library build file changes.
- [x] Run `git diff --check` and report every unrun or unsupported gate.
