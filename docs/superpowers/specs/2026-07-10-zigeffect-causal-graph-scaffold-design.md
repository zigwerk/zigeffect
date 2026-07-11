# zigeffect Embedded Causal Graph Scaffold Design

Date: 2026-07-10

## Goal

Every generated executable zigeffect project records its causal events into a
real, local, Zig-native graph database from the first run. Agents can inspect
that durable graph through stable CLI queries without reconstructing behavior
from logs or requiring hosting.

## Honest Boundary

The core already exposes `CausalNendbStorageBackendState` and deterministic
NenDB node/parent-edge schemas, but no concrete upstream NenDB dependency is
installed. Upstream NenDB currently has no `build.zig.zon`, conditionally uses
sibling repositories, and does not provide a stable Zig 0.16 package contract.

The delivered default is therefore `zstd.CausalGraph.LocalDatabase`: an
embedded graph write-ahead database implemented in Zig over the existing
NenDB-compatible writer contract. It is not branded as upstream NenDB. The
writer boundary remains replaceable by a future pinned NenDB adapter.

## Storage Contract

The database stores one complete JSONL graph-write transaction per causal
event under `.zigeffect/graph/causal-graph.jsonl`. Each row contains:

- a versioned graph-record schema and monotonic sequence;
- a durable event id and per-process source event id;
- a durable session id so event ids never collide across restarts;
- the existing redacted NenDB-compatible node payload; and
- an optional remapped parent edge written atomically with the node.

Opening a writable database scans and validates every complete row, rebuilds
bounded indexes, truncates only a trailing partial row, rejects corruption in
the committed prefix, and starts a new durable session. Writes preflight
capacity, duplicate ids, parent existence, row size, and WAL size before
appending. Flush uses the filesystem sync boundary.

## Query Contract

`zstd.CausalGraph.Snapshot` opens a bounded read snapshot and supports record
summary, durable event lookup, and child traversal. The project CLI exposes:

```sh
zigeffect graph status --json
zigeffect graph event <durable-event-id> --json
zigeffect graph children <durable-event-id> --json
```

Queries resolve the graph path from the validated project manifest and accept
no arbitrary file path or command execution. System projects require
`--component <manifest-id>` and resolve that component's graph beneath its
validated manifest path, so independently running services remain inspectable.

## Scaffold Contract

Application and service templates, including both services in a generated
system, contain `src/causal_graph.zig`. Startup opens the local database,
attaches `CausalNendbStorageBackendState` before recording any application
fact, records graph artifact evidence, flushes, and fails when the causal store
reports a backend write failure. Tests use isolated temporary graph roots and
prove persisted records through the CLI.

The project manifest adds the `causal_graph` capability and the
`.zigeffect/graph` artifact path. Graph data is ignored by Git; compatibility
metadata, scaffold snapshots, READMEs, and Codex/Claude skills describe the
query workflow.

## Safety And Limits

- Paths are validated relative paths and opened beneath a caller-owned root.
- Row text is bounded and rejected if secret-shaped values survive core
  redaction.
- Record count and WAL bytes are bounded.
- Committed corruption fails closed; only an incomplete final row is repaired.
- A single writer holds the local file lock; readers use bounded snapshots.
- Every allocation and file handle has explicit ownership and cleanup.
- Generated source remains user-owned and upgrades never overwrite it.

## Acceptance

- Persistence, restart id uniqueness, traversal, corruption, partial recovery,
  capacity, redaction, and allocation-failure tests pass.
- CLI status/event/children tests pass against a real temporary database.
- Every scaffold kind still builds in Debug and ReleaseSafe; generated
  executable tests create and query real graph files.
- Versioned scaffold snapshots are intentionally updated.
- `bun run zigeffect:local-release` passes.
