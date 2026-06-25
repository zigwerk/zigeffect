# zigeffect-std Package Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build the `packages/zigeffect-std` MVP as a one-import standard library facade on top of the existing zigeffect engine.

**Architecture:** `packages/zigeffect-std` is a separate Zig package that depends on `../zigeffect`, re-exports the engine as `fx`, and owns application-facing modules. The first implementation includes deterministic CLI parsing/help, fakeable Console/Env/FileSystem services, a CLI causal receipt helper, one hello example, and gate wiring.

**Tech Stack:** Zig 0.16 build package, `std.Build`, path dependency on `packages/zigeffect`, Bun root scripts for repo-level verification.

---

## File Structure

- Create `packages/zigeffect-std/build.zig`: package build, module registration, test step, example step.
- Create `packages/zigeffect-std/build.zig.zon`: package metadata and path dependency on `../zigeffect`.
- Create `packages/zigeffect-std/README.md`: public usage and verification commands.
- Create `packages/zigeffect-std/src/root.zig`: facade root, `fx` re-export, public module exports.
- Create `packages/zigeffect-std/src/cli/root.zig`: command spec, args/options parser, help text, receipt facts.
- Create `packages/zigeffect-std/src/console/root.zig`: deterministic captured console service.
- Create `packages/zigeffect-std/src/env/root.zig`: deterministic env map service with required lookup.
- Create `packages/zigeffect-std/src/filesystem/root.zig`: deterministic memory filesystem service.
- Create `packages/zigeffect-std/examples/hello.zig`: executable-style example that parses `--name`.
- Modify `package.json`: add `zigeffect:std:test`.
- Modify `packages/zigeffect/scripts/check-local-agentic-development.sh`: include std package tests.

## Task 1: Package Skeleton

**Files:**
- Create: `packages/zigeffect-std/build.zig`
- Create: `packages/zigeffect-std/build.zig.zon`
- Create: `packages/zigeffect-std/src/root.zig`
- Create: `packages/zigeffect-std/README.md`

- [x] **Step 1: Write the failing package root test**

Add this root test in `src/root.zig` before creating module content:

```zig
test "zigeffect-std re-exports the engine facade" {
    try std.testing.expect(@hasDecl(fx, "effect"));
}
```

- [x] **Step 2: Run test to verify it fails**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fails before package files exist, then fails until `fx` is imported.

- [x] **Step 3: Implement minimal package skeleton**

Create `build.zig`, `build.zig.zon`, and root exports:

```zig
pub const fx = @import("zigeffect");
```

- [x] **Step 4: Run package test**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: root test passes.

## Task 2: CLI Core

**Files:**
- Create: `packages/zigeffect-std/src/cli/root.zig`
- Modify: `packages/zigeffect-std/src/root.zig`

- [x] **Step 1: Write failing CLI parser tests**

Tests must cover:

```zig
test "Cli parses long string option and positional args" {}
test "Cli rejects unknown option" {}
test "Cli routes one subcommand" {}
test "Cli help text is deterministic" {}
```

- [x] **Step 2: Run package test to verify failures**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fails because `Cli` types/functions are missing.

- [x] **Step 3: Implement minimal CLI parser**

Implement:

```zig
pub const OptionKind = enum { string, boolean };
pub const OptionSpec = struct { name: []const u8, short: ?u8 = null, kind: OptionKind = .string, required: bool = false, help: []const u8 = "" };
pub const CommandSpec = struct { name: []const u8, description: []const u8 = "", options: []const OptionSpec = &.{}, subcommands: []const CommandSpec = &.{} };
pub const CliError = error{ UnknownOption, MissingOptionValue, MissingRequiredOption, UnknownSubcommand };
pub fn parse(allocator: std.mem.Allocator, spec: CommandSpec, args: []const []const u8) !ParsedCommand;
pub fn formatHelp(allocator: std.mem.Allocator, spec: CommandSpec) ![]const u8;
```

- [x] **Step 4: Run package test**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: CLI tests pass.

## Task 3: Console, Env, and FileSystem Services

**Files:**
- Create: `packages/zigeffect-std/src/console/root.zig`
- Create: `packages/zigeffect-std/src/env/root.zig`
- Create: `packages/zigeffect-std/src/filesystem/root.zig`
- Modify: `packages/zigeffect-std/src/root.zig`

- [x] **Step 1: Write failing service tests**

Tests must cover:

```zig
test "Console captures stdout and stderr" {}
test "Env require returns value or MissingVariable" {}
test "FileSystem writes reads exists and deletes memory files" {}
```

- [x] **Step 2: Run package test to verify failures**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fails because service modules are missing.

- [x] **Step 3: Implement deterministic fakeable services**

Implement captured console using owned `std.ArrayList(u8)`, env with owned
`std.StringHashMap([]const u8)`, and memory filesystem with owned
`std.StringHashMap([]const u8)`.

- [x] **Step 4: Run package test**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: service tests pass.

## Task 4: Causal CLI Receipts

**Files:**
- Modify: `packages/zigeffect-std/src/cli/root.zig`

- [x] **Step 1: Write failing receipt tests**

Tests must cover:

```zig
test "Cli formats command run receipt JSON" {}
```

Expected JSON includes `schema`, `command`, `status`, and `facts`.

- [x] **Step 2: Run package test to verify failure**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fails because receipt formatter is missing.

- [x] **Step 3: Implement receipt formatter**

Implement:

```zig
pub const CliRunFact = struct { kind: []const u8, detail: []const u8 = "" };
pub const CliRunReceipt = struct { schema: []const u8 = "zigeffect.std.cli-run.v1", command: []const u8, status: []const u8, facts: []const CliRunFact };
pub fn formatRunReceiptJson(allocator: std.mem.Allocator, receipt: CliRunReceipt) ![]const u8;
```

- [x] **Step 4: Run package test**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: receipt test passes.

## Task 5: Hello Example and Repo Gate

**Files:**
- Create: `packages/zigeffect-std/examples/hello.zig`
- Modify: `packages/zigeffect-std/build.zig`
- Modify: `package.json`
- Modify: `packages/zigeffect/scripts/check-local-agentic-development.sh`
- Modify: `packages/zigeffect-std/README.md`

- [x] **Step 1: Write failing example build step**

Add a build step named `examples` that compiles `examples/hello.zig`.

- [x] **Step 2: Run example build to verify failure**

Run:

```sh
cd packages/zigeffect-std && zig build examples
```

Expected: fails before `examples/hello.zig` exists.

- [x] **Step 3: Implement hello example**

The example imports `zigeffect_std`, parses `hello --name Sean`, writes the
greeting to captured console in a test, and exposes a normal `main`.

- [x] **Step 4: Wire repo scripts and gate**

Add:

```json
"zigeffect:std:test": "cd packages/zigeffect-std && zig build test && zig build examples"
```

Add `bun run zigeffect:std:test` to `check-local-agentic-development.sh`.

- [x] **Step 5: Run final verification**

Run:

```sh
bun run zigeffect:std:test
bun run zigeffect:local-agent-gate
git diff --check
```

Expected: all commands exit 0.

