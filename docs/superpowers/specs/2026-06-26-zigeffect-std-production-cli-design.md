# zigeffect-std Production CLI Design

Date: 2026-06-26

Status: delivered on 2026-06-26.

## Decision

Upgrade `zstd.Cli` from a deterministic parser/effect runner into a production
application boundary powered by `zstd.Schema`.

The current API stays source-compatible:

```zig
try zstd.Cli.parse(allocator, spec, args);
try runtime.run(zstd.Cli.runEffect(Env, Failure, app, args));
```

The production path adds typed schemas beside it:

```zig
const Args = struct {
    workspace: []const u8,
    port: i64,
    watch: bool,
    mode: ?[]const u8,
};

const command = zstd.Cli.typedCommand(Args, .{
    .name = "serve",
    .description = "run local server",
    .version = "0.1.0",
}, .{
    zstd.Cli.option("workspace", zstd.Schema.string().nonEmpty(), .{
        .long = "workspace",
        .env = "ZG_WORKSPACE",
        .config_key = "workspace",
        .help = "workspace root",
    }),
    zstd.Cli.option("port", zstd.Schema.integer().min(1).max(65535), .{
        .long = "port",
        .default_value = "5178",
        .help = "local HTTP port",
    }),
    zstd.Cli.flag("watch", .{
        .long = "watch",
        .short = 'w',
        .help = "rerun on file changes",
    }),
    zstd.Cli.option("mode", zstd.Schema.optional(
        zstd.Schema.stringEnum(&.{ "local", "ci" }),
    ), .{
        .long = "mode",
        .config_key = "mode",
        .help = "execution mode",
    }),
});

var decoded = try zstd.Cli.decodeTypedCommandAlloc(
    allocator,
    command,
    parsed,
    env,
    config,
);
defer decoded.deinit();
```

## Goals

- Decode command input into typed Zig structs with `zstd.Schema`.
- Preserve source precedence: CLI argument, env var, config key, default.
- Report all option validation failures as redacted Schema issue lists.
- Generate useful deterministic help from schema-backed option metadata.
- Add built-in `--help`, `help <command>`, `--version`, and completion helpers.
- Emit causal facts for parse, decode, selected command, option source, and
  handler completion.
- Keep existing CLI tests and public APIs passing unchanged.

## Non-Goals

- No terminal color/styling in this milestone.
- No interactive prompts.
- No shell-specific completion scripts beyond deterministic completion records.
- No variadic positional schema decoding beyond a named positional list.
- No breaking change to `OptionSpec`, `CommandSpec`, `parse`, or `runEffect`.

## Public API Shape

### Typed Options

`TypedOptionSpec` stores metadata and a schema value:

```zig
pub fn TypedOptionSpec(comptime SchemaType: type, comptime field_name: []const u8) type;
pub fn option(comptime field_name: []const u8, schema: anytype, comptime meta: OptionMeta) TypedOptionSpec(@TypeOf(schema), field_name, meta);
pub fn flag(comptime field_name: []const u8, comptime meta: OptionMeta) TypedOptionSpec(Schema.BooleanSchema, field_name, meta);
```

`OptionMeta` includes:

- `long`
- `short`
- `help`
- `required`
- `default_value`
- `env`
- `config_key`
- `secret`

Boolean flags default to false when absent unless a source supplies a value.

### Typed Command

```zig
pub fn TypedCommand(comptime Args: type, comptime meta: TypedCommandMeta, comptime Options: type) type;
pub fn typedCommand(comptime Args: type, comptime meta: TypedCommandMeta, options: anytype) TypedCommand(Args, meta, @TypeOf(options));
```

`TypedCommandMeta` includes command name, description, version, and optional
positionals.

### Decode Result

```zig
pub fn TypedDecodeResult(comptime Args: type) type {
    return struct {
        value: ?Args,
        issues: Schema.IssueList,
        sources: []const OptionSourceFact,

        pub fn ok(self: @This()) bool;
        pub fn deinit(self: *@This()) void;
    };
}
```

Option source facts record which source won:

```zig
pub const OptionSourceKind = enum { cli, env, config, default, missing };
pub const OptionSourceFact = struct {
    name: []const u8,
    source: OptionSourceKind,
    redacted_value: []const u8,
};
```

### Input Resolution

For each typed field:

1. CLI `--long` or `-s`
2. env var
3. config key
4. default value
5. boolean flag fallback false
6. optional fallback null
7. missing required issue

Every resolved text value is decoded through the field schema using detailed
config-style decoding with the issue path set to the option long name.

### Help and Completions

Production help must show:

- usage
- command description
- long and short option forms
- env/config/default sources
- required marker
- schema hint: string, integer, boolean, enum choices, constraints where known

Completion records stay deterministic text lines:

```text
command serve run local server
option --workspace workspace root
option --port local HTTP port
```

### Effect Runner

Add a typed runner beside the existing parsed-command runner:

```zig
pub fn TypedHandler(comptime EffectEnv: type, comptime Args: type, comptime Failure: type) type;
pub fn TypedApplication(comptime EffectEnv: type, comptime Args: type, comptime Failure: type, comptime Command: type) type;
pub fn runTypedEffect(
    comptime EffectEnv: type,
    comptime Args: type,
    comptime Failure: type,
    comptime Command: type,
    app: TypedApplication(EffectEnv, Args, Failure, Command),
    args: []const []const u8,
) RunTypedEffect(EffectEnv, Args, Failure, Command);
```

`runTypedEffect` parses argv, handles built-ins, decodes typed args, calls the
handler, writes errors to `CapturedConsole`, returns `RunSummary`, and records
causal service facts.

## Error Handling

- Syntax parse errors remain `CliError`.
- Typed option errors are `Schema.IssueList` values and map to usage exit code.
- Env/config lookup failures map to config exit code only when the lookup API
  itself fails; missing optional values become issues or fallbacks.
- Receipts redact command text, issue details, and source facts.

## Testing

The implementation must be test-first. Required coverage:

- typed command decodes CLI/env/config/default precedence;
- missing and invalid options accumulate multiple Schema issues;
- boolean flags default false and parse true;
- help includes constraints, defaults, env/config metadata, required markers;
- built-in `--help`, `help <command>`, `--version`, and completions work;
- typed effect runner records causal facts and returns receipts;
- secret-shaped values are redacted from source facts, errors, and receipts;
- old parser/effect tests remain green.

## Documentation

Update:

- `packages/zigeffect-std/README.md`
- `packages/zigeffect/docs/roadmap.md`
- `docs/superpowers/specs/2026-06-25-zigeffect-std-effectts-grade-roadmap-design.md`

## Completion Criteria

- `bun run zigeffect:std:test` passes.
- `bun run zigeffect:postgres:test` passes.
- `git diff --check` passes.
- `bun run zigeffect:local-agent-gate` passes.
- Roadmap row 15 says M12 production CLI is delivered.
