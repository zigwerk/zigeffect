# zigeffect-std Local Process Workspace FileSystem Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete M6 by making local development operations real and traceable:
effect-native `FileSystem`, `Process`, and `Workspace` services with memory/fake
and live local adapters.

**Architecture:** Keep existing pure helpers, add service wrappers, and add live
local adapters backed by Zig std APIs. `FileSystem.MemoryFileSystem` remains the
deterministic fake. `FileSystem.LocalFileSystem` uses `std.Io.Dir` and
`std.Io.Threaded.global_single_threaded.io()` for local test/dev reads and
writes. `Process.FakeRunner` remains the deterministic fake; `Process.LocalRunner`
uses `std.process.run` with bounded stdout/stderr capture. `Workspace.Service`
uses a filesystem service for snapshot/diff effects. All service effects declare
requirements, redact paths/argv/stdout/stderr in diagnostics/receipts, and emit
causal facts.

**Tech Stack:** Zig 0.16, `std.Io.Dir`, `std.process.run`, `zstd.Service`,
`zstd.Sink`, `zstd.Stream`, `bun run zigeffect:std:test`.

---

## File Structure

- Modify `packages/zigeffect-std/src/filesystem/root.zig`: memory service
  effects plus live local adapter.
- Modify `packages/zigeffect-std/src/process/root.zig`: runner services,
  live process runner, stdout/stderr JSONL/event receipts, run effects.
- Modify `packages/zigeffect-std/src/workspace/root.zig`: workspace service
  effects for root resolution, snapshot, diff, and ignore filtering.
- Modify `packages/zigeffect-std/README.md`: document live local adapters.
- Modify `packages/zigeffect/docs/roadmap.md`: update std-library status.

## Task 1: FileSystem Service And Live Adapter

- [x] **Step 1: Write failing tests**

Add tests:

```zig
test "FileSystem memory service effects read write delete and record facts" {}
test "FileSystem local adapter writes reads exists and deletes in a temp dir" {}
```

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because effect APIs and local adapter are missing.

- [x] **Step 2: Implement FileSystem APIs**

Implement:

```zig
pub fn writeFileEffect(comptime EffectEnv: type, path: []const u8, content: []const u8) WriteFileEffect(EffectEnv);
pub fn readFileEffect(comptime EffectEnv: type, path: []const u8) ReadFileEffect(EffectEnv);
pub fn deleteFileEffect(comptime EffectEnv: type, path: []const u8) DeleteFileEffect(EffectEnv);
pub fn existsEffect(comptime EffectEnv: type, path: []const u8) ExistsEffect(EffectEnv);
pub const LocalFileSystem = struct { ... };
```

Memory and local adapters must share the same small method surface where
possible and redact path/content diagnostics.

- [x] **Step 3: Verify**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: tests pass.

## Task 2: Process Service And Live Runner

- [x] **Step 1: Write failing tests**

Add tests:

```zig
test "Process runEffect uses fake runner and records redacted causal facts" {}
test "Process local runner executes a real local command with bounded capture" {}
```

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because runner services/effects and live runner are missing.

- [x] **Step 2: Implement Process APIs**

Implement:

```zig
pub const RunOutput = struct { receipt: Receipt, stdout: []const u8, stderr: []const u8, ... };
pub fn RunnerService(comptime Runner: type) type;
pub fn runEffect(comptime EffectEnv: type, comptime Runner: type, command: Command) RunEffect(EffectEnv, Runner);
pub const LocalRunner = struct { ... };
```

The local runner must use `std.process.run`, enforce stdout/stderr limits, free
owned process buffers, redact argv/env/cwd/stdout/stderr receipts, and record
causal facts.

- [x] **Step 3: Verify**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: tests pass.

## Task 3: Workspace Service Effects

- [x] **Step 1: Write failing tests**

Add tests:

```zig
test "Workspace service resolves and snapshots through FileSystem effects" {}
test "Workspace diff filters ignored paths and records causal facts" {}
```

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because workspace service/effects and ignore filtering are
missing.

- [x] **Step 2: Implement Workspace APIs**

Implement:

```zig
pub const IgnoreRule = struct { prefix: []const u8 };
pub const Service = struct { workspace: Workspace, ignores: []const IgnoreRule, ... };
pub fn resolveEffect(...);
pub fn snapshotEffect(...);
pub fn diffEffect(...);
```

Workspace effects must use the filesystem service and record root/snapshot/diff
facts while keeping paths secret-safe.

- [x] **Step 3: Verify**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: tests pass.

## Task 4: Docs And Gate

- [x] **Step 1: Update docs**

Update README and roadmap wording for delivered M6 local adapters.

- [x] **Step 2: Mark checkboxes complete**

Replace completed `- [ ]` with `- [x]`.

- [x] **Step 3: Final verification**

Run:

```sh
bun run zigeffect:std:test
bun run zigeffect:local-agent-gate
git diff --check
```

Expected: all commands exit 0.
