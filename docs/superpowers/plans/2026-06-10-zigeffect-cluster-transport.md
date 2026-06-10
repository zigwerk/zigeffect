# zigeffect Cluster Transport Implementation Plan

Date: 2026-06-10

Milestone: 34 - Transport Abstraction

Spec: `docs/superpowers/specs/2026-06-10-zigeffect-cluster-transport-design.md`

## Objective

Add a public `ClusterTransport` contract with deterministic in-process and
loopback HTTP-shaped implementations. Transport sends must append durable
messages to `MessageStorage`, expose a versioned serialization boundary, and
support timeout/retry policy tests. Cluster runner acceptance must pass through
both transports.

## Architecture

Create `packages/zigeffect/src/cluster/transport.zig`.

The transport module owns:

- `ClusterTransport` vtable.
- `ClusterTransportKind`.
- `ClusterTransportPolicy`.
- `ClusterTransportRequest`.
- `ClusterTransportResponse`.
- `ClusterTransportError`.
- `InProcessClusterTransport`.
- `LoopbackHttpClusterTransport`.
- JSON request/response formatting and parsing helpers.
- HTTP-shaped request/response formatting and body extraction helpers.

The implementations reuse `MessageStorage.submit` and `routing.shardIdForAddress`
so transport messages are processed by the existing `LocalClusterRunner` path.

## Files

Create:

- `packages/zigeffect/src/cluster/transport.zig`
- `packages/zigeffect/test/cluster_transport_test.zig`

Modify:

- `packages/zigeffect/src/cluster/root.zig`
- `packages/zigeffect/src/zigeffect.zig`
- `packages/zigeffect/test/all_test.zig`
- `packages/zigeffect/docs/architecture.md`
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

## Task 1: Public Contract and Serialization

### Red

Create `packages/zigeffect/test/cluster_transport_test.zig` with tests that
currently fail because the transport module does not exist:

- `cluster transport public exports are available`
- `transport request json round-trips`
- `transport response json round-trips`
- `transport parser rejects incompatible schemas`

Add the test file to `packages/zigeffect/test/all_test.zig`.

Run:

```bash
bun run zigeffect:test
```

Expected result: compile failure for missing transport declarations.

### Green

Implement `transport.zig` contract types and JSON helpers:

- `transport_request_schema = "zigeffect.cluster.transport.request.v1"`
- `transport_response_schema = "zigeffect.cluster.transport.response.v1"`
- schema version `1`
- `formatClusterTransportRequestJson`
- `parseClusterTransportRequestJson`
- `formatClusterTransportResponseJson`
- `parseClusterTransportResponseJson`
- `deinit` helpers for owned parsed values/responses

Export the module and aliases through `cluster/root.zig` and top-level
`zigeffect.zig`.

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/transport.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_transport_test.zig packages/zigeffect/test/all_test.zig
```

Commit:

```bash
git add packages/zigeffect/src/cluster/transport.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_transport_test.zig packages/zigeffect/test/all_test.zig
git commit -m "feat(zigeffect): add cluster transport protocol"
```

## Task 2: In-Process Transport

### Red

Extend `cluster_transport_test.zig`:

- `in-process transport writes tell ask and interrupt messages`
- `in-process transport preserves duplicate idempotency keys`
- `timeout policy rejects before durable submission`

Run:

```bash
bun run zigeffect:test
```

Expected result: failures for missing `InProcessClusterTransport` behavior.

### Green

Implement `InProcessClusterTransport`:

- validate shard count
- expose `asClusterTransport`
- derive idempotency keys with prefix `transport-inprocess:{sequence}` when
  absent
- reject unsupported ingress kinds
- return `TransportTimeout` before storage mutation when `timeout_ms == 0`
- call `MessageStorage.submit`
- return response with attempts set to `1`

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/transport.zig packages/zigeffect/test/cluster_transport_test.zig
```

Commit:

```bash
git add packages/zigeffect/src/cluster/transport.zig packages/zigeffect/test/cluster_transport_test.zig
git commit -m "feat(zigeffect): add in-process cluster transport"
```

## Task 3: Loopback HTTP Transport and Retry Policy

### Red

Extend `cluster_transport_test.zig`:

- `loopback http transport stores messages through encoded request bytes`
- `loopback http transport retries transient unavailable attempts`
- `loopback http transport stops after retry limit`
- `http codec extracts request and response bodies`

Run:

```bash
bun run zigeffect:test
```

Expected result: failures for missing loopback HTTP and retry behavior.

### Green

Implement:

- `formatClusterTransportHttpRequest`
- `formatClusterTransportHttpResponse`
- `clusterTransportHttpBody`
- `LoopbackHttpClusterTransport`

Loopback behavior:

- own an `InProcessClusterTransport` handler internally
- serialize request to HTTP-shaped bytes
- parse request body on the handler side
- optionally fail `failures_before_success` attempts with
  `TransportUnavailable`
- retry while attempts are `<= 1 + max_retries`
- return `RetryLimitExceeded` once retry budget is exhausted
- serialize handler response and parse it client-side

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/transport.zig packages/zigeffect/test/cluster_transport_test.zig
```

Commit:

```bash
git add packages/zigeffect/src/cluster/transport.zig packages/zigeffect/test/cluster_transport_test.zig
git commit -m "feat(zigeffect): add loopback cluster transport"
```

## Task 4: Cluster Runner Acceptance Through Both Transports

### Red

Add a shared helper in `cluster_transport_test.zig` that:

- creates file-backed runner and message storage
- acquires the destination shard
- registers an entity
- sends an ask through a `ClusterTransport`
- ticks the runner
- reads the durable reply

Add two tests:

- `cluster runner processes ask sent through in-process transport`
- `cluster runner processes ask sent through loopback http transport`

Run:

```bash
bun run zigeffect:test
```

Expected result: any missing ownership, reply, or response lifecycle behavior
surfaces before closeout.

### Green

Adjust implementation only if the acceptance tests expose a contract gap. Keep
the path shared with `MessageStorage` and `LocalClusterRunner`.

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/transport.zig packages/zigeffect/test/cluster_transport_test.zig
```

Commit:

```bash
git add packages/zigeffect/src/cluster/transport.zig packages/zigeffect/test/cluster_transport_test.zig
git commit -m "test(zigeffect): cover cluster transport runner acceptance"
```

## Task 5: Documentation and Roadmap Closeout

Update `packages/zigeffect/docs/architecture.md` cluster section to include
`transport.zig`.

Mark Milestone 34 deliverables and acceptance complete in
`docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`.

Run:

```bash
bun run zigeffect:test
zig build examples
zig build cluster-runner -- --help
bun run zig:test
zig fmt --check packages/zigeffect/src/cluster/transport.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_transport_test.zig packages/zigeffect/test/all_test.zig packages/zigeffect/docs/architecture.md
git diff --check
rg "TO""DO|FIX""ME|st""ub|place""holder|not imple""mented|unimple""mented" packages/zigeffect/src/cluster/transport.zig packages/zigeffect/test/cluster_transport_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-10-zigeffect-cluster-transport-design.md docs/superpowers/plans/2026-06-10-zigeffect-cluster-transport.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
```

Run `zig build examples` and `zig build cluster-runner -- --help` from
`packages/zigeffect`.

Commit:

```bash
git add packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "docs(zigeffect): mark cluster transport complete"
```

## Completion Gate

Milestone 34 is complete when all task commits exist and the full closeout gate
passes without marker matches.
