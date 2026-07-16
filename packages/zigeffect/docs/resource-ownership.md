# Resource ownership

ZigEffect has one ownership rule: the scope that registers a finalizer owns the
resource. Canonical layers and managed runtimes make the relevant scope explicit
without requiring application code to pass it around.

## Managed-runtime resources

Use `kernel.Layer.scoped` for dependencies that live across requests or jobs:

```zig
fn acquireDatabase(ctx: *kernel.ContextView(.{Config})) error{ConnectFailed}!Database.API {
    return connect(ctx.service(Config));
}

fn releaseDatabase(database: *Database.API) void {
    database.close();
}

const DatabaseLive = kernel.Layer.scoped(
    Database,
    error{ConnectFailed},
    .{Config},
    acquireDatabase,
    releaseDatabase,
).provide(ConfigLive);
```

The root scope owns the database from successful construction until
`ManagedRuntime.deinit`. Shared layer values are acquired once by identity.
If a later layer fails, already-acquired resources close in reverse order and
no partial runtime escapes.

Suitable runtime-lifetime resources include:

- database and cache pools;
- persistent HTTP or gRPC channels;
- listening servers and bounded worker pools;
- telemetry exporters and queues;
- provider processes; and
- long-lived filesystem, storage, or workflow handles.

## Per-run resources

Every `runtime.run` creates a child scope. Resources acquired for one request,
job, command, or test belong to that scope and close on success, typed failure,
defect, or interruption.

Use the canonical scoped-effect/resource helper exposed by the owning module.
Do not store a per-run pointer in a runtime-lifetime service or return a borrowed
slice after its owner closes.

## Transport-owned child runs

HTTP, gRPC, queue, and workflow adapters keep a bounded runtime handle derived
from the managed runtime. Each dispatched program runs in a fresh child scope.
The transport owns request decoding and response encoding lifetimes; handlers
must return owned data when the transport cannot prove the borrow remains live.

## Fiber-owned resources

Forked fibers have child scopes. A parent scope owns the child lease; closing
the parent interrupts unfinished children before dependent resources are
released. Background work started by a scoped layer must be attached to that
layer's root scope, not detached globally.

The deterministic, coroutine, and thread-pool executors may schedule
differently, but they must preserve the same ownership facts and terminal fiber
states.

## Finalizer requirements

Finalizers should be:

- idempotent where the underlying protocol permits it;
- bounded by a documented timeout or finite operation count;
- safe after partial acquisition;
- incapable of exposing secrets through logs or causal facts; and
- tested after success, startup failure, operation failure, cancellation, and
  forced shutdown.

When cleanup itself fails, retain that failure alongside the original cause.
Do not overwrite the application error with a cleanup message.

## Causal ownership evidence

The managed runtime records layer, scope, resource, fiber, and finalizer events
automatically. The application snapshot exposes unresolved fibers and causal
findings so an agent can identify escaped work or an incomplete shutdown without
reconstructing ownership from logs.

Semantic facts should identify the resource class and operation, not sensitive
connection strings, request payloads, or credentials.

## Review checklist

- Does exactly one scope own acquisition and release?
- Is the resource lifetime runtime-wide, per-run, or fiber-local?
- Can a borrowed result outlive its owner?
- Is shared layer acquisition memoized intentionally?
- Does partial startup release every earlier dependency?
- Are child fibers interrupted before their dependencies close?
- Is shutdown bounded and are cleanup failures retained?
- Do tests and Testing v2 receipts report zero leaks and pending fibers?

The older `Layer.fromBuilder`, `LayerGraph`, shared `Runtime.withScope`, and
manual graph-scope patterns remain compatibility internals. New application
code should express ownership with canonical scoped layers and one managed
runtime.
