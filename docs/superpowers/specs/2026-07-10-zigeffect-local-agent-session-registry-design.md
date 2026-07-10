# zigeffect Local Agent Session Registry Design

## Goal

Persist bounded, redacted local agent session state so local tooling can list,
recover, and honestly explain prior Codex/Claude/zigeffect process runs after a
collector or workbench restart.

## Decision

Add a versioned session registry in the workbench collector package. The
registry is independent of Bun and exposes deterministic in-memory operations;
a small storage contract handles loading and saving serialized snapshots. A Bun
file store supplies local atomic persistence through write-to-temp plus rename.

Each record owns:

- a unique local session ID;
- agent identity and kind;
- redacted command, cwd, task, and optional diagnostic;
- lifecycle status (`starting`, `running`, `done`, `failed`, `interrupted`);
- start/update/finish timestamps;
- terminal exit/interruption state;
- transcript line/turn/ignored counts and final sequence.

The process supervisor accepts an optional registry and session ID. It creates
the record before spawn, marks it running only after spawn succeeds, and records
every terminal path: success, non-zero exit, abort, spawn failure, stream
failure, or collector delivery failure.

## Recovery Semantics

Snapshots use `zigeffect.local-agent-sessions.v1`. Restore validates the entire
document into temporary state before replacing the registry. A malformed,
oversized, or incompatible snapshot returns false without changing live state.

No local process handle survives a registry-owner restart. Therefore restored
`starting` and `running` records become `interrupted`, receive a recovery
diagnostic, and get a finish timestamp. The registry never repeats a stale
“running” claim merely because it was persisted.

## Retention

The registry is bounded. When starting a new session at capacity, it evicts the
oldest terminal record. It never evicts an active record; if every retained
record is active, `begin` fails with a capacity error. This keeps local state
bounded without hiding live ownership.

Returned records and snapshots are copies so callers cannot mutate registry
state outside lifecycle methods.

## Persistence Contract

`LocalAgentSessionStore` reads and writes serialized text. Helpers parse,
restore, and save registry snapshots. The Bun implementation:

- creates the parent directory;
- writes JSON to a sibling temporary file;
- renames atomically on the same filesystem;
- treats a missing file as an empty registry;
- reports malformed JSON as invalid rather than crashing or partially restoring.

## Supervisor Cleanup Hardening

Once a child starts, any collector delivery failure must request child
termination and await settlement before rejecting. This includes failure to post
the initial `agent_status: running` event, which previously occurred before the
existing transcript cleanup block.

## Non-Goals

- Do not reattach to an OS process by PID.
- Do not persist unredacted transcript bodies or environment variables.
- Do not add HTTP start/stop/list routes yet; those belong to M85.
- Do not add PTY input yet.

## Acceptance Criteria

- Tests prove lifecycle transitions and summary counters are persisted.
- Tests prove commands, tasks, cwd values, and diagnostics are redacted.
- Tests prove restore marks stale active records interrupted.
- Tests prove malformed restore is all-or-nothing.
- Tests prove bounded eviction never removes active ownership.
- Tests prove fake and Bun file stores round-trip snapshots and reject corrupt
  JSON safely.
- Supervisor tests prove success, spawn failure, abort, stream failure, and
  initial collector failure update the registry honestly and never orphan a
  started child.
