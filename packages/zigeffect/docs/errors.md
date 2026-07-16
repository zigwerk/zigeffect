# Errors and diagnostics

ZigEffect keeps expected failures in Zig error sets and adds focused diagnostics
at composition boundaries. Applications should preserve structured failure
information until the boundary that owns recovery, translation, or reporting.

## Typed effect failures

```zig
const Load = kernel.Effect(Order, error{
    NotFound,
    RepositoryUnavailable,
}, .{Repository});
```

The effect type states its complete expected failure channel. Compose recovery
where responsibility is clear:

```zig
const program = load(order_id)
    .catchAll(recoverLoad)
    .named("orders.load");
```

Use `mapError` to translate one domain boundary into another. A mapper must
return an error set, and `catchAll` recovery must preserve the original success
type; invalid shapes fail at compile time with a ZigEffect-owned diagnostic.

## Undeclared service access

An operation may resolve only the tags listed in its effect requirements:

```zig
const Load = kernel.Effect(Order, error{NotFound}, .{Repository});

fn run(ctx: *Load.Context) error{NotFound}!Order {
    return ctx.service(Repository).load();
}
```

Accessing an absent tag fails compilation with:

```text
zigeffect undeclared service requirement

service: <stable-service-key>

Add the service tag to Effect(..., Requirements).
```

This is verified by `test/compile_fail/kernel_undeclared_service.zig`.

## Unsatisfied root-layer inputs

Layer types expose `InputServices`. A managed runtime refuses to compile when
the root still has construction inputs:

```text
zigeffect ManagedRuntime root layer has unsatisfied inputs; wire them explicitly with Layer.provide
```

Fix the topology rather than manually creating a context:

```zig
const RepositoryLive = kernel.Layer.sync(
    Repository,
    .{Config},
    makeRepository,
).provide(ConfigLive);
```

Use `provideMerge` only when the dependency should remain externally visible.

## Runtime-handle requirements

Transports and dispatchers may derive a runtime handle limited to an available
service set. Running an effect that needs a service outside that set fails at
compile time:

```text
zigeffect RuntimeHandle cannot run effect: the handle does not contain every required service
```

Ordinary application operations should compose effects instead of requesting a
runtime handle.

## Registry failures

The managed runtime may report:

- `error.DuplicateService` when two built layers own the same stable tag;
- `error.MissingService` when corrupted or invalid internal wiring reaches the
  registry; and
- `error.ServiceTypeMismatch` when a stable key is reused with a different API
  type.

Treat duplicate keys as an architecture error. Prefer one explicit layer owner
and dependency provision over last-writer-wins replacement.

## Startup and acquisition failures

Fallible and scoped layers preserve their declared startup error set:

```zig
const DatabaseLive = kernel.Layer.scoped(
    Database,
    error{ConnectFailed, AuthenticationFailed},
    .{Config},
    connectDatabase,
    closeDatabase,
).provide(ConfigLive);
```

If startup fails after earlier layers have acquired resources, the root scope
closes those resources in reverse order. A failed root is never returned as a
partially usable runtime.

## Exit and cause

Use a throwing `run` when the caller simply propagates typed failure. Use the
runtime's exit API when the caller must inspect the complete termination shape.

`Exit` distinguishes success from structured failure. `Cause` and `CauseTree`
can retain:

- expected typed failures;
- defects;
- interruption;
- finalizer failures;
- sequential or parallel relationships; and
- annotations and causal references.

Do not convert this structure into an arbitrary message inside a domain
service. Format it at CLI, protocol, test-receipt, or operator boundaries.

## Cleanup failures

A finalizer may fail independently of the operation that caused scope closure.
ZigEffect preserves both failures rather than hiding one. Resource owners should
make finalizers idempotent and bounded, and tests should exercise acquisition
failure, operation failure, interruption, and disposal.

## Config, schema, and protocol errors

External inputs should use typed boundary errors that carry safe location and
repair information:

- config paths or descriptor names, never secret values;
- schema issue paths and expected shapes;
- gRPC/HTTP status and bounded public details;
- SQLSTATE and outcome category, never connection credentials; and
- process exit status with bounded, redacted output.

Semantic causal facts may reference the boundary and error category. They must
not retain credentials, personal data, unbounded payloads, or raw terminal
scrollback.

## Testing failures

Testing v2 separates process termination from test completeness. Exit zero is
not a pass unless the receipt reports:

- `complete: true`;
- equal discovered and executed counts;
- zero failed and pending tests;
- zero leaks and logged errors; and
- no unsupported or truncated required evidence.

Use the receipt's exact replay command and assertion causal IDs before reading
unstructured terminal output.

## Legacy diagnostic surface

The repository still contains environment mismatch, static provider tuple,
`LayerGraph`, and `serviceNotFound` diagnostics for unmigrated modules. They are
compatibility diagnostics, not patterns to copy into new application code. New
work should produce diagnostics in terms of canonical service tags, effect
requirements, layer inputs, and managed runtime boundaries.
