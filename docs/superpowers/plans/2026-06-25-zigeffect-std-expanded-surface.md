# zigeffect-std Expanded Surface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved `zigeffect-std` public surface so local zigeffect applications can import one package for JSON, CLI, config, local workspace, process, SQL/HTTP contracts, and agent session tooling.

**Architecture:** Build dependency-first modules inside `packages/zigeffect-std/src/`, exporting each from `src/root.zig`. Keep the std package deterministic and local-first: every service gets a fake or memory implementation before any real adapter, and every string/artifact boundary routes through `Secrets` redaction helpers. `Sql` and `Http` define contracts and fakes only; real Postgres/network adapters stay outside this package.

**Tech Stack:** Zig 0.16, `std.Build`, `std.ArrayList`, `std.StringHashMap`, `std.json`, existing `packages/zigeffect` dependency, Bun scripts for repo-level gates.

---

## File Structure

- Create `packages/zigeffect-std/src/secrets/root.zig`: redaction and secret wrapper helpers.
- Create `packages/zigeffect-std/src/json/root.zig`: deterministic JSON field writer and string escaping.
- Create `packages/zigeffect-std/src/jsonl/root.zig`: NDJSON append/parse helpers.
- Create `packages/zigeffect-std/src/path/root.zig`: path join/normalize/basename/dirname helpers.
- Create `packages/zigeffect-std/src/config/root.zig`: layered key/value config with redaction metadata.
- Create `packages/zigeffect-std/src/clock/root.zig`: fake clock, instant type, and deterministic sleep recording.
- Create `packages/zigeffect-std/src/schedule/root.zig`: fixed/exponential schedules and stepper.
- Modify `packages/zigeffect-std/src/filesystem/root.zig`: add list, atomic write, and redacted diagnostics.
- Create `packages/zigeffect-std/src/workspace/root.zig`: local project root model, path resolution, snapshots, diffs.
- Create `packages/zigeffect-std/src/process/root.zig`: fake process runner, command model, output receipt.
- Create `packages/zigeffect-std/src/testing/root.zig`: golden assertions and sentinel leak assertions.
- Modify `packages/zigeffect-std/src/cli/root.zig`: add integer options, short flags, exit code mapping, and receipt redaction.
- Create `packages/zigeffect-std/src/sql/root.zig`: SQL contract and fake query results.
- Create `packages/zigeffect-std/src/http/root.zig`: HTTP request/response/client contract and fake client.
- Create `packages/zigeffect-std/src/agent/root.zig`: local agent session events and NDJSON feed writer.
- Modify `packages/zigeffect-std/src/root.zig`: export all public modules.
- Modify `packages/zigeffect-std/README.md`: document the expanded module surface and verification command.

## Task 1: Secrets Foundation

**Files:**
- Create: `packages/zigeffect-std/src/secrets/root.zig`
- Modify: `packages/zigeffect-std/src/root.zig`

- [ ] **Step 1: Write failing tests**

Add tests named:

```zig
test "Secrets redacts sentinel token password and auth URL" {}
test "SecretString never exposes raw display text" {}
```

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because `Secrets` is not exported.

- [ ] **Step 2: Implement `Secrets`**

Implement:

```zig
pub const redacted = "[REDACTED]";
pub const SecretString = struct {
    value: []const u8,
    pub fn expose(self: SecretString) []const u8;
    pub fn display(self: SecretString) []const u8;
};
pub fn containsSecret(input: []const u8) bool;
pub fn redactAlloc(allocator: std.mem.Allocator, input: []const u8) ![]const u8;
```

The redactor must detect `sentinel-secret`, `password=`, `token=`, `authorization:`, `bearer `, `sk-`, and URLs with userinfo such as `postgres://user:pass@host/db`.

- [ ] **Step 3: Verify**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: tests pass.

## Task 2: Json and Jsonl

**Files:**
- Create: `packages/zigeffect-std/src/json/root.zig`
- Create: `packages/zigeffect-std/src/jsonl/root.zig`
- Modify: `packages/zigeffect-std/src/root.zig`

- [ ] **Step 1: Write failing tests**

Add tests named:

```zig
test "Json writes stable redacted object fields" {}
test "Json escapes strings deterministically" {}
test "Jsonl appends records and parses complete lines" {}
test "Jsonl retains trailing partial line" {}
```

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because `Json` and `Jsonl` are not exported.

- [ ] **Step 2: Implement `Json`**

Implement:

```zig
pub const Field = struct { name: []const u8, value: []const u8, redact: bool = false };
pub fn escapeStringAlloc(allocator: std.mem.Allocator, value: []const u8) ![]const u8;
pub fn objectFromFieldsAlloc(allocator: std.mem.Allocator, fields: []const Field) ![]const u8;
```

`objectFromFieldsAlloc` must emit fields in caller-provided order and redact
fields where `redact` is true or `Secrets.containsSecret(value)` returns true.

- [ ] **Step 3: Implement `Jsonl`**

Implement:

```zig
pub const ParsedLines = struct {
    lines: []const []const u8,
    trailing: []const u8,
    pub fn deinit(self: *ParsedLines, allocator: std.mem.Allocator) void;
};
pub fn appendRecordAlloc(allocator: std.mem.Allocator, existing: []const u8, record_json: []const u8) ![]const u8;
pub fn parseLinesAlloc(allocator: std.mem.Allocator, input: []const u8) !ParsedLines;
```

- [ ] **Step 4: Verify**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: tests pass.

## Task 3: Path, Config, Clock, and Schedule

**Files:**
- Create: `packages/zigeffect-std/src/path/root.zig`
- Create: `packages/zigeffect-std/src/config/root.zig`
- Create: `packages/zigeffect-std/src/clock/root.zig`
- Create: `packages/zigeffect-std/src/schedule/root.zig`
- Modify: `packages/zigeffect-std/src/root.zig`

- [ ] **Step 1: Write failing tests**

Add tests named:

```zig
test "Path joins normalizes and splits project paths" {}
test "Config resolves layered values and redacts sensitive keys" {}
test "Clock fake advances and records sleeps" {}
test "Schedule fixed and exponential steppers are deterministic" {}
```

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because the modules are not exported.

- [ ] **Step 2: Implement `Path`**

Implement:

```zig
pub fn joinAlloc(allocator: std.mem.Allocator, parts: []const []const u8) ![]const u8;
pub fn normalizeAlloc(allocator: std.mem.Allocator, path: []const u8) ![]const u8;
pub fn basename(path: []const u8) []const u8;
pub fn dirname(path: []const u8) []const u8;
pub fn extension(path: []const u8) []const u8;
```

- [ ] **Step 3: Implement `Config`**

Implement:

```zig
pub const ConfigError = error{ MissingValue };
pub const Entry = struct { key: []const u8, value: []const u8, secret: bool = false };
pub const LayeredConfig = struct {
    pub fn init(allocator: std.mem.Allocator) LayeredConfig;
    pub fn deinit(self: *LayeredConfig) void;
    pub fn put(self: *LayeredConfig, key: []const u8, value: []const u8, secret: bool) !void;
    pub fn get(self: LayeredConfig, key: []const u8) ?[]const u8;
    pub fn require(self: LayeredConfig, key: []const u8) ConfigError![]const u8;
    pub fn displayValueAlloc(self: LayeredConfig, allocator: std.mem.Allocator, key: []const u8) ![]const u8;
};
```

- [ ] **Step 4: Implement `Clock` and `Schedule`**

Implement:

```zig
pub const Instant = struct { millis: u64 };
pub const FakeClock = struct {
    pub fn init(start_millis: u64) FakeClock;
    pub fn now(self: FakeClock) Instant;
    pub fn advance(self: *FakeClock, millis: u64) void;
    pub fn sleep(self: *FakeClock, millis: u64) void;
};
```

and:

```zig
pub const Stepper = struct { pub fn next(self: *Stepper) ?u64; };
pub fn fixed(delay_millis: u64, count: usize) Stepper;
pub fn exponential(initial_millis: u64, factor: u64, count: usize) Stepper;
```

- [ ] **Step 5: Verify**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: tests pass.

## Task 4: FileSystem Expansion and Workspace

**Files:**
- Modify: `packages/zigeffect-std/src/filesystem/root.zig`
- Create: `packages/zigeffect-std/src/workspace/root.zig`
- Modify: `packages/zigeffect-std/src/root.zig`

- [ ] **Step 1: Write failing tests**

Add tests named:

```zig
test "FileSystem lists paths and atomic write replaces content" {}
test "FileSystem redacts secret-shaped paths in diagnostics" {}
test "Workspace resolves relative paths and captures snapshots" {}
test "Workspace diff reports changed files" {}
```

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because new filesystem APIs and `Workspace` are missing.

- [ ] **Step 2: Expand `FileSystem`**

Add:

```zig
pub fn listPaths(self: MemoryFileSystem, allocator: std.mem.Allocator) ![]const []const u8;
pub fn atomicWriteFile(self: *MemoryFileSystem, path: []const u8, content: []const u8) !void;
pub fn diagnosticPathAlloc(allocator: std.mem.Allocator, path: []const u8) ![]const u8;
```

- [ ] **Step 3: Implement `Workspace`**

Implement:

```zig
pub const FileSnapshot = struct { path: []const u8, content: []const u8 };
pub const Workspace = struct {
    root: []const u8,
    pub fn init(root: []const u8) Workspace;
    pub fn resolveAlloc(self: Workspace, allocator: std.mem.Allocator, relative: []const u8) ![]const u8;
    pub fn snapshotAlloc(self: Workspace, allocator: std.mem.Allocator, fs: FileSystem.MemoryFileSystem) ![]const FileSnapshot;
    pub fn diffAlloc(allocator: std.mem.Allocator, before: []const FileSnapshot, after: []const FileSnapshot) ![]const []const u8;
};
pub fn freeSnapshot(allocator: std.mem.Allocator, snapshot: []const FileSnapshot) void;
pub fn freeDiff(allocator: std.mem.Allocator, diff: []const []const u8) void;
```

- [ ] **Step 4: Verify**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: tests pass.

## Task 5: Process, Testing, and Cli Expansion

**Files:**
- Create: `packages/zigeffect-std/src/process/root.zig`
- Create: `packages/zigeffect-std/src/testing/root.zig`
- Modify: `packages/zigeffect-std/src/cli/root.zig`
- Modify: `packages/zigeffect-std/src/root.zig`

- [ ] **Step 1: Write failing tests**

Add tests named:

```zig
test "Process fake runner returns redacted receipts" {}
test "Testing assertNoSentinelSecrets catches leaks" {}
test "Cli parses short flags and integer options" {}
test "Cli maps errors to deterministic exit codes" {}
```

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because modules and CLI APIs are missing.

- [ ] **Step 2: Implement `Process`**

Implement:

```zig
pub const Command = struct { argv: []const []const u8, cwd: []const u8 = "", env: []const EnvVar = &.{} };
pub const EnvVar = struct { name: []const u8, value: []const u8, secret: bool = false };
pub const Result = struct { exit_code: i32, stdout: []const u8 = "", stderr: []const u8 = "" };
pub const Receipt = struct { command: []const u8, status: []const u8, exit_code: i32 };
pub const FakeRunner = struct {
    pub fn init(result: Result) FakeRunner;
    pub fn runAlloc(self: FakeRunner, allocator: std.mem.Allocator, command: Command) !Receipt;
};
```

- [ ] **Step 3: Implement `Testing`**

Implement:

```zig
pub fn assertEqualJson(expected: []const u8, actual: []const u8) !void;
pub fn assertNoSentinelSecrets(text: []const u8) !void;
```

- [ ] **Step 4: Expand `Cli`**

Add integer option support, short flag parsing such as `-v`, and:

```zig
pub const ExitCode = enum(i32) { success = 0, usage = 64, config = 78, io = 74, interrupted = 130, defect = 70 };
pub fn exitCodeForError(err: anyerror) ExitCode;
```

- [ ] **Step 5: Verify**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: tests pass.

## Task 6: Sql and Http Contracts

**Files:**
- Create: `packages/zigeffect-std/src/sql/root.zig`
- Create: `packages/zigeffect-std/src/http/root.zig`
- Modify: `packages/zigeffect-std/src/root.zig`

- [ ] **Step 1: Write failing tests**

Add tests named:

```zig
test "Sql fake database returns deterministic rows" {}
test "Sql redacts connection metadata" {}
test "Http fake client returns configured responses" {}
test "Http redacts authorization headers and secret URLs" {}
```

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because modules are missing.

- [ ] **Step 2: Implement `Sql`**

Implement:

```zig
pub const Value = union(enum) { null, text: []const u8, integer: i64, boolean: bool };
pub const Row = struct { fields: []const Field };
pub const Field = struct { name: []const u8, value: Value };
pub const QueryResult = struct { rows: []const Row };
pub const FakeDatabase = struct {
    pub fn init(result: QueryResult) FakeDatabase;
    pub fn query(self: FakeDatabase, sql: []const u8, binds: []const Value) QueryResult;
};
pub fn redactConnectionAlloc(allocator: std.mem.Allocator, connection: []const u8) ![]const u8;
```

- [ ] **Step 3: Implement `Http`**

Implement:

```zig
pub const Header = struct { name: []const u8, value: []const u8 };
pub const Request = struct { method: []const u8, url: []const u8, headers: []const Header = &.{}, body: []const u8 = "" };
pub const Response = struct { status: u16, headers: []const Header = &.{}, body: []const u8 = "" };
pub const FakeClient = struct {
    pub fn init(response: Response) FakeClient;
    pub fn send(self: FakeClient, request: Request) Response;
};
pub fn redactRequestAlloc(allocator: std.mem.Allocator, request: Request) ![]const u8;
```

- [ ] **Step 4: Verify**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: tests pass.

## Task 7: Agent Session Layer

**Files:**
- Create: `packages/zigeffect-std/src/agent/root.zig`
- Modify: `packages/zigeffect-std/src/root.zig`
- Modify: `packages/zigeffect-std/README.md`

- [ ] **Step 1: Write failing tests**

Add tests named:

```zig
test "Agent formats local session events as redacted JSONL" {}
test "Agent run receipt includes agent workspace and status" {}
```

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because `Agent` is missing.

- [ ] **Step 2: Implement `Agent`**

Implement:

```zig
pub const Event = struct { sequence: u64, agent: []const u8, kind: []const u8, detail: []const u8 };
pub const RunReceipt = struct { agent: []const u8, workspace: []const u8, status: []const u8 };
pub fn eventJsonAlloc(allocator: std.mem.Allocator, event: Event) ![]const u8;
pub fn appendEventJsonlAlloc(allocator: std.mem.Allocator, feed: []const u8, event: Event) ![]const u8;
pub fn receiptJsonAlloc(allocator: std.mem.Allocator, receipt: RunReceipt) ![]const u8;
```

- [ ] **Step 3: Update README**

Document the full module list:

```zig
zstd.Json
zstd.Jsonl
zstd.Cli
zstd.Console
zstd.Env
zstd.Config
zstd.Secrets
zstd.FileSystem
zstd.Path
zstd.Workspace
zstd.Process
zstd.Testing
zstd.Clock
zstd.Schedule
zstd.Sql
zstd.Http
zstd.Agent
```

- [ ] **Step 4: Verify**

Run:

```sh
bun run zigeffect:std:test
bun run zigeffect:local-agent-gate
git diff --check
```

Expected: all commands exit 0.

