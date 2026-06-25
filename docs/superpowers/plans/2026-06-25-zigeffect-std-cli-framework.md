# zigeffect-std CLI Application Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `zstd.Cli` from a parser/helper module into an effect-native
local CLI application framework with typed option defaults, nested subcommands,
command handlers, receipts, and causal facts.

**Architecture:** Preserve the current plain parser API, then add an
effect-native runner. The runner receives a `CommandSpec`, route handlers, and
argv; declares `Cli.Runner` and `Console.CapturedConsole` service requirements;
runs handlers through `fx.Context`; maps typed handler/parse errors to
deterministic exit codes; writes user-visible errors through `Console`; formats a
redacted command receipt; and records `cli.run`, `cli.parse`, and `cli.handler`
operation facts through `zstd.Service.recordOperation`.

**Tech Stack:** Zig 0.16, `zstd.Service`, `zstd.Console`, `zstd.Env`,
`zstd.Config`, existing `fx.Runtime`, `bun run zigeffect:std:test`.

---

## File Structure

- Modify `packages/zigeffect-std/src/cli/root.zig`: nested parser, option
  default resolution, completion formatting, runner service, application/handler
  types, and tests.
- Modify `packages/zigeffect-std/README.md`: document CLI framework behavior.
- Modify `packages/zigeffect/docs/roadmap.md`: update std-library milestone
  status for M4.

## Task 1: Nested Commands And Typed Defaults

- [x] **Step 1: Write failing tests**

Add tests:

```zig
test "Cli routes nested subcommands" {}
test "Cli resolves option defaults from CLI env config and literal defaults" {}
```

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because recursive routing and default resolution are missing.

- [x] **Step 2: Implement parser/default APIs**

Implement:

```zig
pub const OptionSpec = struct {
    ...
    default_value: ?[]const u8 = null,
    env: ?[]const u8 = null,
    config_key: ?[]const u8 = null,
};

pub fn activeCommandSpec(root: CommandSpec, parsed: ParsedCommand) CliError!CommandSpec;
pub fn resolveOptionValue(... ) (CliError || Config.ConfigError || Env.EnvError || std.mem.Allocator.Error)!?[]const u8;
```

Required-option validation must allow values supplied by default/env/config.

- [x] **Step 3: Verify**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: tests pass.

## Task 2: Help And Completion Output

- [x] **Step 1: Write failing tests**

Add tests:

```zig
test "Cli help includes subcommands deterministically" {}
test "Cli formats deterministic completions for active command" {}
```

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because completion formatting is missing.

- [x] **Step 2: Implement help/completions**

Implement:

```zig
pub fn formatCompletions(allocator: std.mem.Allocator, spec: CommandSpec, args: []const []const u8) ![]const u8;
```

Completion output must list subcommands first and options second in spec order.

- [x] **Step 3: Verify**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: tests pass.

## Task 3: Effect-Native Runner

- [x] **Step 1: Write failing tests**

Add tests:

```zig
test "Cli runEffect executes handler through services and records receipt facts" {}
test "Cli runEffect maps handler errors to exit codes without throwing" {}
test "Cli runEffect participates in runtime dependency validation" {}
```

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because runner service/effect APIs are missing.

- [x] **Step 2: Implement runner APIs**

Implement:

```zig
pub const Runner = struct {};
pub fn Handler(comptime EffectEnv: type, comptime Failure: type) type;
pub fn Application(comptime EffectEnv: type, comptime Failure: type) type;
pub fn RunEffect(comptime EffectEnv: type, comptime HandlerFailure: type) type;
pub fn runEffect(comptime EffectEnv: type, comptime HandlerFailure: type, app: Application(EffectEnv, HandlerFailure), args: []const []const u8) RunEffect(EffectEnv, HandlerFailure);
```

The runner must:

- require `Runner` and `Console.CapturedConsole`;
- record parse, handler, and run causal facts;
- map parse and handler errors to `ExitCode`;
- return a `RunSummary` with an owned redacted receipt JSON;
- write usage/handler errors to captured stderr.

- [x] **Step 3: Verify**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: tests pass.

## Task 4: Docs And Gate

- [x] **Step 1: Update docs**

Update README and roadmap wording for the delivered CLI framework.

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
