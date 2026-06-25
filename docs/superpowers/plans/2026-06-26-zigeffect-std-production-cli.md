# zigeffect-std Production CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Schema-powered production CLI layer that decodes typed Zig structs, reports rich redacted option issues, generates source-aware help, handles built-ins, and runs typed handlers through the effect runtime.

**Architecture:** Keep `packages/zigeffect-std/src/cli/root.zig` source-compatible by adding the typed CLI API beside the existing `CommandSpec`, `parse`, and `runEffect` APIs. Reuse `zstd.Schema` for option decoding and issue lists, existing `Env`/`Config` for source precedence, existing `Console` for output, and existing service causal facts for runtime observability.

**Tech Stack:** Zig std library, `zstd.Schema`, `zstd.Env`, `zstd.Config`, `zstd.Console`, `zstd.Service`, `bun run zigeffect:std:test`.

---

### Task 1: Typed Command Decode and Source Facts

**Files:**
- Modify: `packages/zigeffect-std/src/cli/root.zig`

- [ ] **Step 1: Write failing tests for typed decode precedence and issue accumulation**

Add tests named:

```zig
const TypedServeArgs = struct {
    workspace: []const u8,
    port: i64,
    watch: bool,
    mode: ?[]const u8,
};

test "Cli typed command decodes CLI env config defaults with source facts" {
    const command = typedCommand(TypedServeArgs, .{
        .name = "serve",
        .description = "run local server",
    }, .{
        option("workspace", @import("../schema/root.zig").string().nonEmpty(), .{
            .long = "workspace",
            .env = "ZG_WORKSPACE",
            .config_key = "workspace",
            .help = "workspace root",
            .required = true,
        }),
        option("port", @import("../schema/root.zig").integer().min(1).max(65535), .{
            .long = "port",
            .default_value = "5178",
            .help = "local port",
        }),
        flag("watch", .{ .long = "watch", .short = 'w', .help = "watch files" }),
        option("mode", @import("../schema/root.zig").optional(@import("../schema/root.zig").stringEnum(&.{ "local", "ci" })), .{
            .long = "mode",
            .config_key = "mode",
            .help = "mode",
        }),
    });

    var env = Env.EnvMap.init(std.testing.allocator);
    defer env.deinit();
    try env.put("ZG_WORKSPACE", "/env");

    var config = Config.LayeredConfig.init(std.testing.allocator);
    defer config.deinit();
    try config.put("workspace", "/config", false);
    try config.put("mode", "ci", false);

    var parsed = try parse(std.testing.allocator, command.toCommandSpec(), &.{ "--workspace", "/cli", "-w" });
    defer parsed.deinit(std.testing.allocator);

    var decoded = try decodeTypedCommandAlloc(std.testing.allocator, command, parsed, &env, &config);
    defer decoded.deinit();

    try std.testing.expect(decoded.ok());
    try std.testing.expectEqualStrings("/cli", decoded.value.?.workspace);
    try std.testing.expectEqual(@as(i64, 5178), decoded.value.?.port);
    try std.testing.expectEqual(true, decoded.value.?.watch);
    try std.testing.expectEqualStrings("ci", decoded.value.?.mode.?);
    try expectSource(decoded, "workspace", .cli);
    try expectSource(decoded, "port", .default);
    try expectSource(decoded, "watch", .cli);
    try expectSource(decoded, "mode", .config);
}

test "Cli typed command accumulates schema issues and redacts source facts" {
    const command = typedCommand(TypedServeArgs, .{
        .name = "serve",
    }, .{
        option("workspace", @import("../schema/root.zig").string().nonEmpty(), .{ .long = "workspace", .required = true }),
        option("port", @import("../schema/root.zig").integer().min(1).max(10), .{ .long = "port" }),
        flag("watch", .{ .long = "watch" }),
        option("mode", @import("../schema/root.zig").optional(@import("../schema/root.zig").stringEnum(&.{ "local", "ci" })), .{ .long = "mode" }),
    });

    var parsed = try parse(std.testing.allocator, command.toCommandSpec(), &.{ "--port", "999", "--mode", "prod", "--workspace", "token=abc123" });
    defer parsed.deinit(std.testing.allocator);

    var decoded = try decodeTypedCommandAlloc(std.testing.allocator, command, parsed, null, null);
    defer decoded.deinit();

    try std.testing.expect(!decoded.ok());
    try expectIssuePath(decoded.issues, "--port", .constraint_failed);
    try expectIssuePath(decoded.issues, "--mode", .unknown_enum);
    try std.testing.expect(std.mem.indexOf(u8, decoded.sources[0].redacted_value, "abc123") == null);
}
```

- [ ] **Step 2: Run the red tests**

Run:

```sh
bun run zigeffect:std:test
```

Expected: fail because `typedCommand`, `option`, `flag`, `decodeTypedCommandAlloc`, `expectSource`, and `expectIssuePath` do not exist.

- [ ] **Step 3: Implement typed command decode**

Add:

```zig
const Schema = @import("../schema/root.zig");

pub const OptionMeta = struct {
    long: []const u8,
    short: ?u8 = null,
    help: []const u8 = "",
    required: bool = false,
    default_value: ?[]const u8 = null,
    env: ?[]const u8 = null,
    config_key: ?[]const u8 = null,
    secret: bool = false,
};

pub const OptionSourceKind = enum { cli, env, config, default, missing };
pub const OptionSourceFact = struct {
    name: []const u8,
    source: OptionSourceKind,
    redacted_value: []const u8,
};
```

Implement `TypedOptionSpec`, `option`, `flag`, `TypedCommand`, `typedCommand`, `TypedDecodeResult`, `decodeTypedCommandAlloc`, `decodeOptionText`, `appendSourceFact`, `expectSource`, and `expectIssuePath`.

Decode precedence must be CLI, env, config, default, boolean false, optional null, then missing issue. Issue paths must be `--long`.

- [ ] **Step 4: Verify green**

Run:

```sh
bun run zigeffect:std:test
```

Expected: pass.

### Task 2: Production Help and Built-Ins

**Files:**
- Modify: `packages/zigeffect-std/src/cli/root.zig`

- [ ] **Step 1: Write failing tests for source-aware help and built-in requests**

Add tests named:

```zig
test "Cli typed help includes schema source metadata and required markers" {
    const command = typedCommand(TypedServeArgs, .{
        .name = "serve",
        .description = "run local server",
        .version = "0.1.0",
    }, .{
        option("workspace", @import("../schema/root.zig").string().nonEmpty(), .{
            .long = "workspace",
            .short = 'w',
            .env = "ZG_WORKSPACE",
            .config_key = "workspace",
            .help = "workspace root",
            .required = true,
        }),
        option("port", @import("../schema/root.zig").integer().min(1).max(65535), .{
            .long = "port",
            .default_value = "5178",
            .help = "local port",
        }),
    });

    const help = try formatTypedHelp(std.testing.allocator, command);
    defer std.testing.allocator.free(help);

    try std.testing.expect(std.mem.indexOf(u8, help, "Usage: serve [options]") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "--workspace") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "-w") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "required") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "env: ZG_WORKSPACE") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "config: workspace") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "default: 5178") != null);
}

test "Cli detects typed built-in help version and completions" {
    const command = typedCommand(TypedServeArgs, .{ .name = "serve", .version = "0.1.0" }, .{
        option("workspace", @import("../schema/root.zig").string(), .{ .long = "workspace" }),
        flag("watch", .{ .long = "watch" }),
    });

    try std.testing.expectEqual(BuiltinRequest.help, detectBuiltin(command, &.{"--help"}).?);
    try std.testing.expectEqual(BuiltinRequest.help, detectBuiltin(command, &.{ "help", "serve" }).?);
    try std.testing.expectEqual(BuiltinRequest.version, detectBuiltin(command, &.{"--version"}).?);
    try std.testing.expectEqual(BuiltinRequest.completions, detectBuiltin(command, &.{"completions"}).?);

    const completions = try formatTypedCompletions(std.testing.allocator, command);
    defer std.testing.allocator.free(completions);
    try std.testing.expect(std.mem.indexOf(u8, completions, "option --workspace") != null);
    try std.testing.expect(std.mem.indexOf(u8, completions, "option --watch") != null);
}
```

- [ ] **Step 2: Run the red tests**

Run:

```sh
bun run zigeffect:std:test
```

Expected: fail because typed help and built-ins are missing.

- [ ] **Step 3: Implement help and built-ins**

Add `TypedCommandMeta.version`, `formatTypedHelp`, `BuiltinRequest`, `detectBuiltin`, `formatTypedVersion`, and `formatTypedCompletions`. Use deterministic plain text and redact default values when an option is marked `secret`.

- [ ] **Step 4: Verify green**

Run:

```sh
bun run zigeffect:std:test
```

Expected: pass.

### Task 3: Typed Effect Runner and Docs

**Files:**
- Modify: `packages/zigeffect-std/src/cli/root.zig`
- Modify: `packages/zigeffect-std/README.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-25-zigeffect-std-effectts-grade-roadmap-design.md`
- Modify: `docs/superpowers/specs/2026-06-26-zigeffect-std-production-cli-design.md`

- [ ] **Step 1: Write failing test for typed effect runner**

Add test named:

```zig
test "Cli runTypedEffect decodes typed args handles builtins and records causal facts" {
    const zstd = @import("../root.zig");
    const Provider = zstd.Service.Provider(.{ Runner, zstd.Console.CapturedConsole });
    const HandlerFailure = error{Boom};
    const TestHandlers = struct {
        fn serve(ctx: *zstd.fx.Context(Provider), args: TypedServeArgs) HandlerFailure!void {
            try ctx.service(zstd.Console.CapturedConsole).writeOut(args.workspace);
        }
    };

    const command = typedCommand(TypedServeArgs, .{ .name = "serve", .version = "0.1.0" }, .{
        option("workspace", zstd.Schema.string().nonEmpty(), .{ .long = "workspace", .required = true }),
        option("port", zstd.Schema.integer().min(1).max(65535), .{ .long = "port", .default_value = "5178" }),
        flag("watch", .{ .long = "watch" }),
        option("mode", zstd.Schema.optional(zstd.Schema.stringEnum(&.{ "local", "ci" })), .{ .long = "mode" }),
    });
    const app = TypedApplication(Provider, TypedServeArgs, HandlerFailure){
        .command = command,
        .handler = TestHandlers.serve,
    };

    var runner = Runner{};
    var console = zstd.Console.CapturedConsole.init(std.testing.allocator);
    defer console.deinit();
    var provider = Provider.init(.{ &runner, &console });
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var runtime = zstd.fx.Runtime(Provider).init(std.testing.allocator, &provider)
        .provides(.{ Runner, zstd.Console.CapturedConsole })
        .withCausalStore(&store);

    var summary = try runtime.run(runTypedEffect(Provider, TypedServeArgs, HandlerFailure, app, &.{ "--workspace", "/repo" }));
    defer summary.deinit(std.testing.allocator);

    try std.testing.expectEqual(ExitCode.success, summary.exit_code);
    try std.testing.expectEqualStrings("/repo", console.stdoutText());
    try std.testing.expect(std.mem.indexOf(u8, summary.receipt_json, "cli_decode_completed") != null);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(zstd.Service.hasOperation(snapshot, Runner, "cli.typed.run", "success"));
}
```

- [ ] **Step 2: Run the red test**

Run:

```sh
bun run zigeffect:std:test
```

Expected: fail because typed runner APIs are missing.

- [ ] **Step 3: Implement typed effect runner**

Add `TypedHandler`, `TypedApplication`, `RunTypedEffect`, and `runTypedEffect`. The runner must:

- parse with `command.toCommandSpec()`;
- handle built-ins before handler execution;
- call `decodeTypedCommandAlloc`;
- write issue JSON to stderr on decode failure;
- build redacted receipts with facts for parse/decode/source/handler completion;
- record `cli.typed.run` and `cli.typed.decode` causal operations.

- [ ] **Step 4: Update docs**

README must include a typed CLI example using `zstd.Schema`. Roadmap row 15 must say M12 production CLI is delivered. The CLI design spec must include `Status: delivered on 2026-06-26.` The std roadmap design must mark M12 as delivered.

- [ ] **Step 5: Run final verification**

Run:

```sh
zig fmt packages/zigeffect-std/src/cli/root.zig
bun run zigeffect:std:test
bun run zigeffect:postgres:test
git diff --check
bun run zigeffect:local-agent-gate
```

Expected: all pass.

- [ ] **Step 6: Commit implementation**

Run:

```sh
git add docs/superpowers/plans/2026-06-26-zigeffect-std-production-cli.md \
  docs/superpowers/specs/2026-06-25-zigeffect-std-effectts-grade-roadmap-design.md \
  docs/superpowers/specs/2026-06-26-zigeffect-std-production-cli-design.md \
  packages/zigeffect-std/README.md \
  packages/zigeffect-std/src/cli/root.zig \
  packages/zigeffect/docs/roadmap.md
git diff --cached --check
git commit -m "Add production zigeffect std CLI"
```
