# ZigEffect guide for coding agents

ZigEffect gives agents two things ordinary source-and-log workflows lack:

1. a typed application architecture whose services, failures, dependencies,
   resources, and entry points are statically visible; and
2. bounded machine-readable evidence that connects requirements, tests,
   runtime events, failures, and repair hints.

This is an operating guide, not a second API tutorial. Start with
[Compositional applications](compositional-applications.md) and use
[Agent-first testing](agent-first-testing.md) for the complete Testing v2
contract.

## Choose the operating mode

### Application repository

When `zigeffect.project.json` exists at the current root, it is executable
intent. It owns requirements, acceptance checks, components, commands,
scenarios, safety policy, and side-effect authority.

Begin with:

```sh
zigeffect compatibility --json
zigeffect project validate --json
zigeffect agent status --json
zigeffect agent next --json
zigeffect test list --json
```

Map the request to a requirement, acceptance check, component, fixed command,
and deterministic scenario before changing behavior.

### Framework repository

When changing ZigEffect itself and no application manifest exists at the root,
do not invent one. Read the affected package facade and `build.zig`, use its
native Zig gates, and keep generated templates and public contract snapshots in
sync.

## Canonical application rules

- Import application capabilities through `zigeffect_std` and framework
  primitives through its `fx.kernel` facade.
- Define capabilities with `kernel.Service`.
- Return lazy `kernel.Effect` values from operations.
- Select live, local, or fake implementations with `kernel.Layer`.
- Compose one root layer and create one process-level `zstd.ManagedRuntime`.
- Give each endpoint, job, workflow, or command a stable semantic name.
- Interpret effects only at the managed runtime or a runtime-backed transport.
- Use scoped layers for sockets, pools, exporters, processes, files, channels,
  and other acquired resources.

New application code must not use `EffectEnv`, `ServiceEnv`, provider tuples,
`LayerGraphEnv`, `layerGraph`, or `ctx.runEffect`. `runIn` is an internal
interpreter protocol, not an application API.

## Application shape

```zig
const zstd = @import("zigeffect_std");
const kernel = zstd.fx.kernel;

const Repository = kernel.Service("orders/Repository", RepositoryApi);
const Load = kernel.Effect(Order, error{NotFound}, .{Repository});

const program = load(order_id)
    .flatMap(enrich)
    .tap(audit)
    .named("orders.load");

const MainLayer = RepositoryLive.merge(AuditLive);
var runtime = try zstd.ManagedRuntime(@TypeOf(MainLayer)).make(
    allocator,
    io,
    root,
    MainLayer,
    .{ .observability = observability },
);
defer runtime.deinit();

const order = try runtime.run(program);
try runtime.shutdown();
```

The program is unchanged when a test supplies fake layers. Its type reveals the
combined services and typed failures before execution.

## Work from a failing scenario

Use focused `std.testing` assertions for local invariants. Use
`zstd.Testing.TestContext` when the acceptance contract needs semantic evidence,
fault injection, causal assertions, replay, or a native receipt.

```zig
const scenario = zstd.Testing.Scenario{
    .id = "create-order",
    .label = "an accepted order is durable",
    .requirement = "req-orders",
    .acceptance_check = "check-order-durable",
    .component = "orders",
    .command = "test",
};

var context = try zstd.Testing.TestContext.initFromProject(
    std.testing.allocator,
    std.testing.io,
    std.Io.Dir.cwd(),
    .{
        .project = "orders",
        .suite = "acceptance",
        .scenario = scenario,
        .seed = 42,
    },
);
defer context.deinit();

const assertions = zstd.Testing.AssertionRecorder.init(&context);
try assertions.boolean(.{
    .id = "order-durable",
    .label = "the order is durable",
    .repair_hint = "make the write and idempotency key atomic",
}, true);
try assertions.noPendingFibers(.{
    .id = "fibers-clean",
    .label = "no work escaped its scope",
});
try assertions.noFindings(.{
    .id = "causal-clean",
    .label = "runtime invariants remain clean",
});

try context.publish(std.testing.io, std.Io.Dir.cwd(), 1);
```

Add the failing scenario first, implement the smallest responsible boundary,
and iterate with:

```sh
zigeffect graph status --json
zigeffect test affected --changed <path> --json
zigeffect graph since <baseline-event-id> --limit 256 --json
```

Retain `newest_durable_event_id` before editing, state the expected service and
boundary delta, and compare it with the ordered graph delta after the focused
test.

## Read evidence before terminal scrollback

After a test command, read `.zigeffect/tests/latest.json` or the package suite
receipt first. Require:

- `complete: true` and `status: "passed"`;
- equal discovered and executed counts;
- zero failed and pending tests;
- zero leaks and logged errors; and
- no unsupported or truncated required evidence.

On failure:

1. inspect the first failed assertion, source reference, repair hint, causal
   event IDs, and `causal_event_id_space`;
2. query the event and its children when the IDs are `graph_durable`; never
   treat `runtime_local` IDs as persistent graph cursors;
3. replay with the exact recorded seed and bounds; and
4. repair the narrowest responsible service, layer, resource, or operation.

```sh
zigeffect graph event <event-id> --json
zigeffect graph children <event-id> --json
zigeffect test replay <scenario-id> --json
```

Do not update a snapshot merely to turn a failure green. Compare it, explain the
semantic change, and apply only an intentional result.

## Map the application from one runtime

Every canonical managed runtime can produce a bounded application snapshot:

```zig
const json = try runtime.agentMapJsonAlloc(allocator, .{
    .max_recent_events = 128,
});
defer allocator.free(json);
```

It includes services, operations, layers, dependency edges, memoized reuse,
causal health, findings, fibers, recent events, embedded NenDB provenance, and
durable follow-up queries. Prefer an authenticated
`zigeffect-http.ApplicationMapHandler` for live agent access. An inspection
endpoint is read-only evidence; it grants no source, deployment, or remediation
authority.

## Semantic causal facts

The runtime records structural facts automatically. Standard-library,
transport and domain-framework adapters record the following boundary facts
automatically:

- config loads and schema decoding;
- CLI and API requests;
- HTTP, gRPC, SQL, process, and storage operations;
- external calls and retry decisions;
- artifacts and component dependencies;
- workflow and statechart transitions; and
- acceptance evaluation.

Do not mirror these events with `ctx.recordCausal` or thread a recorder through
business APIs. When domain meaning would otherwise be lost, expose a narrow
typed domain-event service whose live platform adapter uses stable labels,
causal parents and redacted domain references. See
[Runtime-owned causal applications](runtime-owned-causal-applications.md).

## Side-effect authority

Evidence is not authority. Causal tools may inspect, compare, diagnose, and
propose. They do not implicitly authorize source mutation, network access,
provider calls, deployment, or remediation.

Use deterministic fakes by default. Real effects require an explicit manifest
command, capability, safety policy, and user or project authority.

## Handoff gates

For an application project, finish with:

```sh
zigeffect project validate --json
zigeffect test run --requirement <requirement-id> --json
zigeffect test coverage --requirement <requirement-id> --json
zigeffect test gaps --requirement <requirement-id> --json
zigeffect project test --json
zigeffect project check --agent --json
```

For framework work, run the affected package-native tests and inspect every
Testing v2 receipt. State failed, skipped, unsupported, or unrun gates plainly.

## Specialized guides

- [Agent-first application development](agent-first-application-development.md)
- [Agent-first testing](agent-first-testing.md)
- [Agent-observable runtime](agent-observable-runtime.md)
- [Causal scenarios](causal-scenarios.md)
- [Causal development harness](causal-dev-harness.md)
- [Operations and governed remediation](operations.md)
- [Agent safety plane](agent-safety-plane.md)
- [Local agentic development](local-agentic-development.md)
