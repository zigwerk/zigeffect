# zigeffect-std Package Design

Date: 2026-06-25

## Decision

Create `packages/zigeffect-std` as the one-import standard library facade for
future zigeffect users.

`packages/zigeffect` remains the pure engine: effects, layers, fibers, runtime,
scope, schedules, streams, STM, causal services, and deterministic semantics.
`packages/zigeffect-std` depends on `packages/zigeffect` and exposes practical
application-building modules such as CLI, console, env, filesystem, process,
terminal, paths, JSON, and testing.

This gives users one ergonomic import without turning the core engine into a
grab bag of platform tooling.

## Package Shape

```text
packages/
  zigeffect/
    src/
      zigeffect.zig
  zigeffect-zio/
    src/
      root.zig
  zigeffect-std/
    build.zig
    build.zig.zon
    README.md
    src/
      root.zig
      cli/
      console/
      env/
      filesystem/
      process/
      terminal/
      path/
      json/
      testing/
    examples/
    test/
```

The public import should feel like:

```zig
const zstd = @import("zigeffect_std");
```

The package can re-export the engine as `zstd.fx` or `zstd.effect` for
convenience, but the core engine should still be importable directly from
`zigeffect` for users who want the small base.

## Public Modules

Initial modules:

- `Cli`: command tree, args parser, options, validation, help rendering, exit
  code mapping.
- `Console`: stdin/stdout/stderr service boundary with deterministic test
  implementation.
- `Env`: typed environment variable lookup with redacted diagnostics.
- `FileSystem`: file and directory effects with memory-backed test service.
- `Process`: child process spawning as an effect service, not a direct core
  dependency.
- `Terminal`: color/style capability detection, prompt helpers, terminal width.
- `Path`: path parsing/joining/normalization helpers.
- `Json`: small decode/encode helpers that compose with typed errors.
- `Test`: standard-lib test harness helpers and fake services.

MVP modules:

1. `Cli`
2. `Console`
3. `Env`
4. `FileSystem`

`Process` and `Terminal` come after the first CLI is causally observable and
tested.

## CLI Programming Model

The target user experience is:

```zig
const zstd = @import("zigeffect_std");

pub fn main() !void {
    const command = zstd.Cli.command("zg")
        .option(.{ .name = "name", .kind = .string })
        .run(greet);

    try zstd.Cli.run(command);
}
```

The internal shape should be effect-first:

- parsing args is deterministic and testable;
- command handlers are `Effect` programs;
- services such as console/env/filesystem are requirements;
- validation errors are typed;
- exit code selection is explicit;
- every command run can emit causal facts.

The first example should be intentionally small:

```sh
zig build zigeffect-std-examples
```

Example command:

```sh
zg hello --name Sean
```

It should prove args parsing, option decoding, console output, deterministic
tests, and a causal trace for parse/run/success/failure.

## Dependency Boundary

Allowed:

- `zigeffect-std` imports `zigeffect`.
- `zigeffect-std` may use Zig standard library APIs internally.
- `zigeffect-std` may provide real and fake platform service implementations.

Forbidden:

- `zigeffect` importing `zigeffect-std`.
- CLI, process, terminal, or filesystem APIs moving into the core engine.
- Hidden direct process/filesystem access from command handlers that should go
  through services.
- A first release that requires zio or real async.

Future:

- `zigeffect-std-zio` or `zigeffect-std/platform/zio` can provide richer async
  process/terminal implementations after the deterministic service contracts are
  stable.

## Causal Observability

The standard library should dogfood the local agentic development cockpit.

During development:

```sh
bun run zigeffect:self-improve:start
# edit packages/zigeffect-std
bun run zigeffect:self-improve:assess
bun run zigeffect:local-agent-gate
```

The emitted dev-session artifact should show:

- active agent;
- current package/module;
- command/check receipts;
- linked causal artifacts;
- guardrails and next action;
- failures as structured findings where possible.

At runtime, CLI command execution should be able to record causal facts:

- `cli_command_started`
- `cli_args_parsed`
- `cli_option_validation_failed`
- `cli_command_completed`
- `cli_command_failed`
- `console_write`
- `env_var_required`
- `filesystem_read`
- `filesystem_write`

The MVP can start with in-package event structs and tests, then connect them to
the existing `CausalStore` once the first command model is stable.

## Error Handling

Errors should be typed and composable:

- `CliParseError`
- `CliValidationError`
- `ConsoleError`
- `EnvError`
- `FileSystemError`

CLI exit mapping should be explicit:

- parse/validation errors map to usage exit codes;
- missing env/config maps to config exit codes;
- filesystem failures map to IO exit codes;
- interrupted commands map to interruption exit codes;
- unexpected defects remain visible as defects.

Error details must use redacted strings for env values, file paths that may
carry secrets, and process metadata.

## Testing Strategy

Every module must have deterministic tests first.

MVP test coverage:

- args parser accepts positional args and flags;
- parser rejects unknown flags with a typed error;
- command tree routes subcommands;
- help text is deterministic;
- console writes are captured by a fake console service;
- env lookup uses fake env service;
- filesystem tests use fake or memory filesystem service;
- command run emits a small causal trace or event fixture.

Package-level verification:

```sh
cd packages/zigeffect-std && zig build test
```

Repo-level local gate should eventually include the std package:

```sh
bun run zigeffect:local-agent-gate
```

## First Milestones

### S0 - Package Skeleton

Create `packages/zigeffect-std` with `build.zig`, `build.zig.zon`, `src/root.zig`,
`README.md`, examples, and a passing empty test target.

### S1 - CLI Core

Implement command tree, args/options parser, typed parse errors, and deterministic
help text.

### S2 - Console and Env Services

Add real and fake console/env services that can be required by effects and tested
without process globals.

### S3 - FileSystem Service

Add a bounded filesystem service with fake implementation and redacted errors.

### S4 - Causal CLI Run Receipts

Record command parse/run/success/failure facts and expose a sample artifact in
the local workbench.

### S5 - Dogfood Command

Add one real `zg hello --name <name>` example and run it through the local
agentic development cockpit.

## Naming Decision

Documentation and examples should recommend:

```zig
const zstd = @import("zigeffect_std");
```

`zstd` avoids shadowing Zig's built-in `std` while still reading clearly in
examples.
