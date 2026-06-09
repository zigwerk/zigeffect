# zigeffect Local Entity Actor Model Design

Date: 2026-06-09

## Context

Milestone 25 adds local actor/entity identity and mailbox semantics before the
cluster runtime grows shard routing, durable message storage, runner leases, or
multi-runner transport. The current cluster namespace is only a marker, while
the workflow and runtime layers already provide useful local patterns:

- stable `u64` identity derivation through `std.hash.Fnv1a_64`;
- unmanaged `std.ArrayList` queues for deterministic ordering;
- `Scope` for reverse-order finalizers and causal resource cleanup;
- `Supervisor` with `.entity` child kind, restart policies, intensity limits,
  shutdown ordering, and causal supervisor events.

This milestone creates a local actor model in `src/cluster/` that later shard
and message-storage milestones can reuse.

## Design Choice

Three approaches were considered:

1. Put a local entity runtime in `src/cluster/` with in-memory mailbox storage,
   runtime-bound `EntityRef` values, and local supervisor integration.
2. Add actors to `src/runtime/` next to fibers and queues.
3. Skip local actors and wait for durable cluster message storage.

The selected approach is option 1. Entity identity, references, envelopes, and
mailboxes are cluster concepts even when they run in one process. Keeping them
in `src/cluster/` prevents the core runtime from learning about actor-specific
message semantics and gives later shard, lease, transport, and durable message
storage milestones a natural home.

## Goals

- Add `EntityType`, `EntityId`, `EntityAddress`, and runtime-bound `EntityRef`.
- Add stable entity id derivation from entity type plus key.
- Add local mailbox storage that preserves FIFO order per entity.
- Add local ask, tell, reply, and interrupt envelopes.
- Add entity lifecycle states: idle, running, stopping, stopped, interrupted,
  failed, and escalated.
- Add idle shutdown for entities with no pending mailbox messages.
- Add entity-scoped service registration and reverse-order finalizers through
  `Scope`.
- Integrate local entities with `SupervisorChildKind.entity` so handler
  failures can be restarted or escalated by the supervisor policy.
- Export the cluster actor model through `fx.cluster` and selected top-level
  aliases.

## Milestone Boundary

Milestone 25 is local and deterministic. It does not implement durable message
storage, envelope idempotency across process restart, shard routing, runner
leases, distributed ask/reply, transport encoding, backpressure across runners,
or exactly-once delivery. Those are Milestones 26 through 32.

Payloads are owned byte slices with explicit `payload_type_name` strings. This
keeps local actor tests concrete without introducing a serialization framework
before the message protocol milestone.

## Public API

Create `packages/zigeffect/src/cluster/identity.zig`.

```zig
pub const EntityId = u64;

pub const EntityType = struct {
    name: []const u8,

    pub fn init(name: []const u8) EntityType;
};

pub const EntityAddress = struct {
    entity_type: EntityType,
    id: EntityId,

    pub fn eql(self: EntityAddress, other: EntityAddress) bool;
};

pub fn entityId(entity_type: []const u8, key: []const u8) EntityId;
pub fn entityAddress(entity_type: []const u8, key: []const u8) EntityAddress;
```

Create `packages/zigeffect/src/cluster/mailbox.zig`.

```zig
pub const EntityMessageId = u64;
pub const EntityCorrelationId = u64;
pub const EntityMessageSequence = u64;

pub const EntityEnvelopeKind = enum {
    tell,
    ask,
    reply,
    interrupt,
};

pub const EntityEnvelope = struct {
    id: EntityMessageId = 0,
    sequence: EntityMessageSequence = 0,
    kind: EntityEnvelopeKind,
    address: EntityAddress,
    correlation_id: ?EntityCorrelationId = null,
    payload_type_name: []const u8 = "",
    payload: []const u8 = "",
    redacted_detail: []const u8 = "",
};

pub const EntityAsk = struct {
    envelope: EntityEnvelope,
    correlation_id: EntityCorrelationId,
};

pub const EntityMailboxError = error{
    MailboxEmpty,
    ReplyNotFound,
};

pub const LocalMailboxStore = struct {
    pub fn init(allocator: Allocator) LocalMailboxStore;
    pub fn deinit(self: *LocalMailboxStore) void;

    pub fn offer(self: *LocalMailboxStore, envelope: EntityEnvelope) Allocator.Error!EntityEnvelope;
    pub fn take(self: *LocalMailboxStore, address: EntityAddress) (Allocator.Error || EntityMailboxError)!EntityEnvelope;
    pub fn pendingCount(self: *const LocalMailboxStore, address: EntityAddress) usize;
    pub fn storeReply(self: *LocalMailboxStore, envelope: EntityEnvelope) Allocator.Error!EntityEnvelope;
    pub fn takeReply(
        self: *LocalMailboxStore,
        correlation_id: EntityCorrelationId,
    ) (Allocator.Error || EntityMailboxError)!EntityEnvelope;
};
```

`LocalMailboxStore` owns cloned strings for all retained envelopes. Returned
envelopes are also owned by the caller and must be released with
`deinitEnvelope(allocator, envelope)`.

Create `packages/zigeffect/src/cluster/entity.zig`.

```zig
pub const EntityStatus = enum {
    idle,
    running,
    stopping,
    stopped,
    interrupted,
    failed,
    escalated,
};

pub const EntityRuntimeError = error{
    EntityNotFound,
    DuplicateEntity,
    EntityNotRunning,
    EntityServiceNotFound,
    DuplicateEntityService,
};

pub const EntityRegistration = struct {
    address: EntityAddress,
    name: []const u8,
    restart_mode: SupervisorRestartMode = .permanent,
    shutdown_order: u32 = 0,
    idle_timeout_ms: ?u64 = null,
};

pub const EntityHandlerResult = union(enum) {
    noreply,
    reply: []const u8,
    stop,
};

pub const EntityProcessResult = struct {
    address: EntityAddress,
    envelope: EntityEnvelope,
    status: EntityStatus,
    replied: bool = false,
    supervisor_decision: ?SupervisorDecision = null,

    pub fn deinit(self: *EntityProcessResult, allocator: Allocator) void;
};
```

Entity scope:

```zig
pub const EntityScope = struct {
    pub fn init(allocator: Allocator) EntityScope;
    pub fn deinit(self: *EntityScope) void;

    pub fn addFinalizerFor(
        self: *EntityScope,
        comptime Resource: type,
        resource: *Resource,
        comptime release: *const fn (*Resource) void,
    ) Allocator.Error!void;

    pub fn provideService(
        self: *EntityScope,
        name: []const u8,
        value: ?*anyopaque,
    ) (Allocator.Error || EntityRuntimeError)!void;

    pub fn service(self: *const EntityScope, name: []const u8) EntityRuntimeError!?*anyopaque;
};
```

Local runtime and references:

```zig
pub const LocalEntityRuntimeOptions = struct {
    supervisor_id: SupervisorId = 1,
    supervisor_name: []const u8 = "local-entities",
    supervisor_strategy: SupervisorStrategy = .one_for_one,
    restart_intensity: RestartIntensity = .{},
};

pub const LocalEntityRuntime = struct {
    pub fn init(allocator: Allocator, options: LocalEntityRuntimeOptions) LocalEntityRuntime;
    pub fn deinit(self: *LocalEntityRuntime) void;

    pub fn registerEntity(
        self: *LocalEntityRuntime,
        registration: EntityRegistration,
        now_ms: u64,
    ) (Allocator.Error || EntityRuntimeError || SupervisorError)!EntityRef;

    pub fn ref(self: *LocalEntityRuntime, address: EntityAddress) EntityRuntimeError!EntityRef;
    pub fn status(self: *const LocalEntityRuntime, address: EntityAddress) EntityRuntimeError!EntityStatus;
    pub fn restartCount(self: *const LocalEntityRuntime, address: EntityAddress) EntityRuntimeError!usize;
    pub fn pendingCount(self: *const LocalEntityRuntime, address: EntityAddress) usize;
    pub fn entityScope(self: *LocalEntityRuntime, address: EntityAddress) EntityRuntimeError!*EntityScope;

    pub fn processNext(
        self: *LocalEntityRuntime,
        address: EntityAddress,
        handler: anytype,
        now_ms: u64,
    ) anyerror!EntityProcessResult;

    pub fn takeReply(
        self: *LocalEntityRuntime,
        correlation_id: EntityCorrelationId,
    ) (Allocator.Error || EntityMailboxError)!EntityEnvelope;

    pub fn shutdownIdle(self: *LocalEntityRuntime, now_ms: u64) void;
};

pub const EntityRef = struct {
    address: EntityAddress,
    runtime: *LocalEntityRuntime,

    pub fn tell(
        self: EntityRef,
        payload_type_name: []const u8,
        payload: []const u8,
        redacted_detail: []const u8,
    ) Allocator.Error!EntityEnvelope;

    pub fn ask(
        self: EntityRef,
        payload_type_name: []const u8,
        payload: []const u8,
        redacted_detail: []const u8,
    ) Allocator.Error!EntityAsk;

    pub fn interrupt(
        self: EntityRef,
        reason: []const u8,
    ) Allocator.Error!EntityEnvelope;
};
```

## Runtime Behavior

`entityId` hashes `entity_type`, a separator, and `key` with `std.hash.Fnv1a_64`.
`EntityAddress.eql` compares both type name and id. `registerEntity` rejects
duplicates, creates an `EntityScope`, registers a supervisor child with kind
`.entity`, marks the entity running, and returns an `EntityRef`.

`EntityRef.tell` appends a tell envelope to the entity mailbox. `EntityRef.ask`
appends an ask envelope and returns an `EntityAsk` containing a stable local
correlation id. `EntityRef.interrupt` appends an interrupt envelope.

`LocalMailboxStore.take` returns envelopes in ascending sequence order for the
target address. Mailboxes are per entity; messages for different entities do
not reorder each other within an entity mailbox.

`LocalEntityRuntime.processNext` takes one envelope and applies it:

- `tell`: call `handler.handle(envelope)` and update last-active time.
- `ask`: call `handler.handle(envelope)`. If the handler returns
  `.{ .reply = bytes }`, store a reply envelope under the ask correlation id.
- `reply`: local runtimes normally store replies directly through ask
  processing; manually enqueued reply envelopes are treated as no-op messages.
- `interrupt`: mark the entity interrupted and close its scope with an
  interrupted finalizer exit. Milestone 25 uses supervision for handler
  failures; distributed interrupt and restart semantics are left to the later
  message protocol and cluster runtime milestones.

If `handler.handle(envelope)` fails, `processNext` reports the entity child exit
to the supervisor. A restart decision closes the old entity scope with failure,
opens a fresh scope, and returns the handler error while leaving the entity
running for the next message. An escalation decision closes the scope with
failure and marks the entity escalated.

`shutdownIdle(now_ms)` stops entities whose mailbox is empty and whose
`idle_timeout_ms` elapsed since their last activity. Shutdown closes the entity
scope with success and marks the entity stopped.

## Entity-Scoped Services And Finalizers

`EntityScope` wraps `Scope` and a small named service registry. The registry is
local only and intentionally stores `?*anyopaque` pointers keyed by cloned
service names. This avoids adding a second dependency-injection system while
still giving entity handlers a place to keep local resources.

Finalizers run through `Scope`, so they preserve existing reverse-order cleanup
behavior and causal resource events when scopes later attach causal stores.

## Testing Strategy

Add `packages/zigeffect/test/entity_test.zig` and import it from
`packages/zigeffect/test/all_test.zig`.

Test coverage:

- public cluster exports include identity, envelope, mailbox, runtime, and ref
  types;
- `entityId` is stable and type-sensitive;
- mailbox storage returns messages FIFO per entity and keeps entity mailboxes
  independent;
- `tell` and `ask` enqueue envelopes; ask replies are stored and retrievable by
  correlation id;
- interrupt envelopes mark entities interrupted and close scopes;
- idle shutdown stops only idle entities with empty mailboxes;
- entity-scoped services reject duplicates and can be looked up by name;
- entity finalizers run on stop/failure in reverse order through `Scope`;
- handler failures flow through `Supervisor`, restart the entity when policy
  permits, and escalate when restart intensity is exceeded.

## Documentation

Update `packages/zigeffect/docs/architecture.md` to list the new cluster files
and clarify that local entity actors are single-process and in-memory until the
message storage and shard runtime milestones.

Update the main roadmap after the full verification gate by marking Milestone
25 deliverables and acceptance complete.
