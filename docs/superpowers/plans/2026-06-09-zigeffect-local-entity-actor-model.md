# zigeffect Local Entity Actor Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a deterministic local entity actor model with entity identity, in-memory mailbox ordering, local ask/tell/reply/interrupt envelopes, entity scopes, idle shutdown, and supervisor-backed handler failure recovery.

**Architecture:** The local actor model lives in `packages/zigeffect/src/cluster/` because entity identity, references, and envelopes are cluster concepts even when they run in one process. Identity, mailbox storage, and runtime lifecycle are split into separate files so later shard routing and durable message storage can replace the local pieces without rewriting handlers. `LocalEntityRuntime` owns a `Supervisor` configured for `.entity` children and uses `Scope` for entity finalizers.

**Tech Stack:** Zig, `std.hash.Fnv1a_64`, unmanaged `std.ArrayList`, existing `Scope`, existing `Supervisor`, `bun` and Zig test commands.

---

## File Structure

- Create `packages/zigeffect/src/cluster/identity.zig`
  - Owns `EntityType`, `EntityId`, `EntityAddress`, stable id derivation, and address equality.
- Create `packages/zigeffect/src/cluster/mailbox.zig`
  - Owns envelope ids, envelope kinds, local mailbox store, owned envelope cloning/freeing, per-entity FIFO queues, and reply storage.
- Create `packages/zigeffect/src/cluster/entity.zig`
  - Owns `EntityStatus`, entity runtime errors, entity scopes, runtime-bound `EntityRef`, `LocalEntityRuntime`, handler outcomes, lifecycle transitions, idle shutdown, and supervisor integration.
- Modify `packages/zigeffect/src/cluster/root.zig`
  - Exports identity, mailbox, and entity namespaces plus ergonomic cluster aliases.
- Modify `packages/zigeffect/src/zigeffect.zig`
  - Adds selected top-level aliases for common local entity actor types.
- Create `packages/zigeffect/test/entity_test.zig`
  - Covers all Milestone 25 behavior.
- Modify `packages/zigeffect/test/all_test.zig`
  - Imports `entity_test.zig`.
- Modify `packages/zigeffect/docs/architecture.md`
  - Documents local entity actor boundaries in `src/cluster/`.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Marks Milestone 25 complete after the full gate passes.

## Task 1: Identity And Public Exports

**Files:**
- Create: `packages/zigeffect/src/cluster/identity.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Create: `packages/zigeffect/test/entity_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [ ] **Step 1: Write failing public export and identity tests**

Create `packages/zigeffect/test/entity_test.zig`:

```zig
const std = @import("std");
const fx = @import("zigeffect");

test "cluster entity public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "identity"));
    try std.testing.expect(@hasDecl(fx.cluster, "mailbox"));
    try std.testing.expect(@hasDecl(fx.cluster, "entity"));
    try std.testing.expect(@hasDecl(fx.cluster, "EntityType"));
    try std.testing.expect(@hasDecl(fx.cluster, "EntityId"));
    try std.testing.expect(@hasDecl(fx.cluster, "EntityAddress"));
    try std.testing.expect(@hasDecl(fx.cluster, "entityId"));
    try std.testing.expect(@hasDecl(fx.cluster, "entityAddress"));
    try std.testing.expect(@hasDecl(fx, "EntityAddress"));
}

test "entity ids are stable and entity-type sensitive" {
    const first = fx.entityId("counter", "tenant-1");
    const second = fx.entityId("counter", "tenant-1");
    const other_type = fx.entityId("ledger", "tenant-1");
    const other_key = fx.entityId("counter", "tenant-2");

    try std.testing.expectEqual(first, second);
    try std.testing.expect(first != other_type);
    try std.testing.expect(first != other_key);

    const address = fx.entityAddress("counter", "tenant-1");
    try std.testing.expectEqual(first, address.id);
    try std.testing.expectEqualStrings("counter", address.entity_type.name);
    try std.testing.expect(address.eql(fx.EntityAddress{
        .entity_type = fx.EntityType.init("counter"),
        .id = first,
    }));
}
```

Add to `packages/zigeffect/test/all_test.zig`:

```zig
    _ = @import("entity_test.zig");
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: failure because entity exports do not exist.

- [ ] **Step 3: Implement identity module and exports**

Create `packages/zigeffect/src/cluster/identity.zig`:

```zig
const std = @import("std");

pub const EntityId = u64;

pub const EntityType = struct {
    name: []const u8,

    pub fn init(name: []const u8) EntityType {
        return .{ .name = name };
    }
};

pub const EntityAddress = struct {
    entity_type: EntityType,
    id: EntityId,

    pub fn eql(self: EntityAddress, other: EntityAddress) bool {
        return self.id == other.id and std.mem.eql(u8, self.entity_type.name, other.entity_type.name);
    }
};

pub fn entityId(entity_type: []const u8, key: []const u8) EntityId {
    var hasher = std.hash.Fnv1a_64.init();
    hasher.update(entity_type);
    hasher.update(":");
    hasher.update(key);
    return hasher.final();
}

pub fn entityAddress(entity_type: []const u8, key: []const u8) EntityAddress {
    return .{
        .entity_type = EntityType.init(entity_type),
        .id = entityId(entity_type, key),
    };
}
```

Replace `packages/zigeffect/src/cluster/root.zig` with:

```zig
pub const domain = "cluster";

pub const identity = @import("identity.zig");
pub const mailbox = struct {};
pub const entity = struct {};

pub const EntityType = identity.EntityType;
pub const EntityId = identity.EntityId;
pub const EntityAddress = identity.EntityAddress;
pub const entityId = identity.entityId;
pub const entityAddress = identity.entityAddress;
```

In `packages/zigeffect/src/zigeffect.zig`, add top-level aliases near other public aliases:

```zig
pub const EntityType = cluster.EntityType;
pub const EntityId = cluster.EntityId;
pub const EntityAddress = cluster.EntityAddress;
pub const entityId = cluster.entityId;
pub const entityAddress = cluster.entityAddress;
```

- [ ] **Step 4: Run green tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: all tests pass.

- [ ] **Step 5: Format and commit**

Run:

```bash
zig fmt --check packages/zigeffect/src/cluster/identity.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/entity_test.zig packages/zigeffect/test/all_test.zig
git add packages/zigeffect/src/cluster/identity.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/entity_test.zig packages/zigeffect/test/all_test.zig
git commit -m "feat(zigeffect): add local entity identity"
```

## Task 2: Local Mailbox Storage

**Files:**
- Create: `packages/zigeffect/src/cluster/mailbox.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/entity_test.zig`

- [ ] **Step 1: Write failing mailbox tests**

Append to `packages/zigeffect/test/entity_test.zig`:

```zig
test "local mailbox store returns entity messages in fifo order" {
    var store = fx.LocalMailboxStore.init(std.testing.allocator);
    defer store.deinit();

    const counter = fx.entityAddress("counter", "one");
    const ledger = fx.entityAddress("ledger", "one");

    var first = try store.offer(.{ .kind = .tell, .address = counter, .payload_type_name = "text", .payload = "first" });
    defer fx.deinitEntityEnvelope(std.testing.allocator, first);
    var second = try store.offer(.{ .kind = .tell, .address = counter, .payload_type_name = "text", .payload = "second" });
    defer fx.deinitEntityEnvelope(std.testing.allocator, second);
    var other = try store.offer(.{ .kind = .tell, .address = ledger, .payload_type_name = "text", .payload = "ledger" });
    defer fx.deinitEntityEnvelope(std.testing.allocator, other);

    try std.testing.expectEqual(@as(usize, 2), store.pendingCount(counter));
    try std.testing.expectEqual(@as(usize, 1), store.pendingCount(ledger));

    var taken_first = try store.take(counter);
    defer fx.deinitEntityEnvelope(std.testing.allocator, taken_first);
    var taken_second = try store.take(counter);
    defer fx.deinitEntityEnvelope(std.testing.allocator, taken_second);
    var taken_other = try store.take(ledger);
    defer fx.deinitEntityEnvelope(std.testing.allocator, taken_other);

    try std.testing.expectEqualStrings("first", taken_first.payload);
    try std.testing.expectEqualStrings("second", taken_second.payload);
    try std.testing.expectEqualStrings("ledger", taken_other.payload);
    try std.testing.expect(taken_first.sequence < taken_second.sequence);
    try std.testing.expectError(error.MailboxEmpty, store.take(counter));
}

test "local mailbox store keeps ask correlations and replies" {
    var store = fx.LocalMailboxStore.init(std.testing.allocator);
    defer store.deinit();

    const address = fx.entityAddress("counter", "one");
    var ask = try store.offer(.{ .kind = .ask, .address = address, .payload_type_name = "text", .payload = "question" });
    defer fx.deinitEntityEnvelope(std.testing.allocator, ask);

    try std.testing.expect(ask.correlation_id != null);
    var reply = try store.storeReply(.{
        .kind = .reply,
        .address = address,
        .correlation_id = ask.correlation_id,
        .payload_type_name = "text",
        .payload = "answer",
    });
    defer fx.deinitEntityEnvelope(std.testing.allocator, reply);

    var taken_reply = try store.takeReply(ask.correlation_id.?);
    defer fx.deinitEntityEnvelope(std.testing.allocator, taken_reply);
    try std.testing.expectEqualStrings("answer", taken_reply.payload);
    try std.testing.expectError(error.ReplyNotFound, store.takeReply(ask.correlation_id.?));
}
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: failure because mailbox exports and implementation do not exist.

- [ ] **Step 3: Implement mailbox storage**

Create `packages/zigeffect/src/cluster/mailbox.zig` with:

```zig
const std = @import("std");
const identity = @import("identity.zig");

pub const Allocator = std.mem.Allocator;
pub const EntityAddress = identity.EntityAddress;
pub const EntityMessageId = u64;
pub const EntityCorrelationId = u64;
pub const EntityMessageSequence = u64;

pub const EntityEnvelopeKind = enum { tell, ask, reply, interrupt };

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

    pub fn deinit(self: *EntityAsk, allocator: Allocator) void {
        deinitEntityEnvelope(allocator, self.envelope);
    }
};

pub const EntityMailboxError = error{
    MailboxEmpty,
    ReplyNotFound,
};

const Mailbox = struct {
    address: EntityAddress,
    items: std.ArrayList(EntityEnvelope) = .empty,
};
```

Add ownership helpers in the same file:

```zig
pub fn cloneEntityAddress(allocator: Allocator, address: EntityAddress) Allocator.Error!EntityAddress {
    return .{
        .entity_type = .{ .name = try allocator.dupe(u8, address.entity_type.name) },
        .id = address.id,
    };
}

pub fn deinitEntityAddress(allocator: Allocator, address: EntityAddress) void {
    if (address.entity_type.name.len > 0) allocator.free(address.entity_type.name);
}

pub fn cloneEntityEnvelope(allocator: Allocator, envelope: EntityEnvelope) Allocator.Error!EntityEnvelope {
    var owned = envelope;
    owned.address = try cloneEntityAddress(allocator, envelope.address);
    errdefer deinitEntityAddress(allocator, owned.address);
    owned.payload_type_name = if (envelope.payload_type_name.len == 0) "" else try allocator.dupe(u8, envelope.payload_type_name);
    errdefer if (owned.payload_type_name.len > 0) allocator.free(owned.payload_type_name);
    owned.payload = if (envelope.payload.len == 0) "" else try allocator.dupe(u8, envelope.payload);
    errdefer if (owned.payload.len > 0) allocator.free(owned.payload);
    owned.redacted_detail = if (envelope.redacted_detail.len == 0) "" else try allocator.dupe(u8, envelope.redacted_detail);
    return owned;
}

pub fn deinitEntityEnvelope(allocator: Allocator, envelope: EntityEnvelope) void {
    deinitEntityAddress(allocator, envelope.address);
    if (envelope.payload_type_name.len > 0) allocator.free(envelope.payload_type_name);
    if (envelope.payload.len > 0) allocator.free(envelope.payload);
    if (envelope.redacted_detail.len > 0) allocator.free(envelope.redacted_detail);
}
```

Implement `LocalMailboxStore`:

```zig
pub const LocalMailboxStore = struct {
    allocator: Allocator,
    mailboxes: std.ArrayList(Mailbox) = .empty,
    replies: std.ArrayList(EntityEnvelope) = .empty,
    next_message_id: EntityMessageId = 1,
    next_sequence: EntityMessageSequence = 1,
    next_correlation_id: EntityCorrelationId = 1,

    pub fn init(allocator: Allocator) LocalMailboxStore {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *LocalMailboxStore) void {
        for (self.mailboxes.items) |*mailbox| {
            for (mailbox.items.items) |item| deinitEntityEnvelope(self.allocator, item);
            mailbox.items.deinit(self.allocator);
            deinitEntityAddress(self.allocator, mailbox.address);
        }
        self.mailboxes.deinit(self.allocator);
        for (self.replies.items) |reply| deinitEntityEnvelope(self.allocator, reply);
        self.replies.deinit(self.allocator);
    }
```

Complete methods:

```zig
    pub fn offer(self: *LocalMailboxStore, envelope: EntityEnvelope) Allocator.Error!EntityEnvelope {
        var owned = try self.prepareEnvelope(envelope);
        errdefer deinitEntityEnvelope(self.allocator, owned);
        const mailbox = try self.mailboxFor(owned.address);
        try mailbox.items.append(self.allocator, owned);
        return cloneEntityEnvelope(self.allocator, owned);
    }

    pub fn take(self: *LocalMailboxStore, address: EntityAddress) (Allocator.Error || EntityMailboxError)!EntityEnvelope {
        const mailbox = self.findMailbox(address) orelse return error.MailboxEmpty;
        if (mailbox.items.items.len == 0) return error.MailboxEmpty;
        return mailbox.items.orderedRemove(0);
    }

    pub fn pendingCount(self: *const LocalMailboxStore, address: EntityAddress) usize {
        const mailbox = self.findMailboxConst(address) orelse return 0;
        return mailbox.items.items.len;
    }

    pub fn storeReply(self: *LocalMailboxStore, envelope: EntityEnvelope) Allocator.Error!EntityEnvelope {
        var owned = try self.prepareEnvelope(envelope);
        errdefer deinitEntityEnvelope(self.allocator, owned);
        try self.replies.append(self.allocator, owned);
        return cloneEntityEnvelope(self.allocator, owned);
    }

    pub fn takeReply(self: *LocalMailboxStore, correlation_id: EntityCorrelationId) (Allocator.Error || EntityMailboxError)!EntityEnvelope {
        for (self.replies.items, 0..) |reply, index| {
            if (reply.correlation_id == correlation_id) return self.replies.orderedRemove(index);
        }
        return error.ReplyNotFound;
    }
```

Add private helpers:

```zig
    fn prepareEnvelope(self: *LocalMailboxStore, envelope: EntityEnvelope) Allocator.Error!EntityEnvelope {
        var owned = try cloneEntityEnvelope(self.allocator, envelope);
        owned.id = if (owned.id == 0) self.nextMessageId() else owned.id;
        owned.sequence = if (owned.sequence == 0) self.nextSequence() else owned.sequence;
        if (owned.kind == .ask and owned.correlation_id == null) owned.correlation_id = self.nextCorrelationId();
        return owned;
    }

    fn nextMessageId(self: *LocalMailboxStore) EntityMessageId {
        const id = self.next_message_id;
        self.next_message_id += 1;
        return id;
    }

    fn nextSequence(self: *LocalMailboxStore) EntityMessageSequence {
        const sequence = self.next_sequence;
        self.next_sequence += 1;
        return sequence;
    }

    fn nextCorrelationId(self: *LocalMailboxStore) EntityCorrelationId {
        const id = self.next_correlation_id;
        self.next_correlation_id += 1;
        return id;
    }

    fn mailboxFor(self: *LocalMailboxStore, address: EntityAddress) Allocator.Error!*Mailbox {
        if (self.findMailbox(address)) |mailbox| return mailbox;
        try self.mailboxes.append(self.allocator, .{ .address = try cloneEntityAddress(self.allocator, address) });
        return &self.mailboxes.items[self.mailboxes.items.len - 1];
    }

    fn findMailbox(self: *LocalMailboxStore, address: EntityAddress) ?*Mailbox {
        for (self.mailboxes.items) |*mailbox| {
            if (mailbox.address.eql(address)) return mailbox;
        }
        return null;
    }

    fn findMailboxConst(self: *const LocalMailboxStore, address: EntityAddress) ?*const Mailbox {
        for (self.mailboxes.items) |*mailbox| {
            if (mailbox.address.eql(address)) return mailbox;
        }
        return null;
    }
};
```

Update `cluster/root.zig` to import `mailbox.zig` and export aliases:

```zig
pub const mailbox = @import("mailbox.zig");
pub const EntityMessageId = mailbox.EntityMessageId;
pub const EntityCorrelationId = mailbox.EntityCorrelationId;
pub const EntityMessageSequence = mailbox.EntityMessageSequence;
pub const EntityEnvelopeKind = mailbox.EntityEnvelopeKind;
pub const EntityEnvelope = mailbox.EntityEnvelope;
pub const EntityAsk = mailbox.EntityAsk;
pub const EntityMailboxError = mailbox.EntityMailboxError;
pub const LocalMailboxStore = mailbox.LocalMailboxStore;
pub const cloneEntityAddress = mailbox.cloneEntityAddress;
pub const deinitEntityAddress = mailbox.deinitEntityAddress;
pub const cloneEntityEnvelope = mailbox.cloneEntityEnvelope;
pub const deinitEntityEnvelope = mailbox.deinitEntityEnvelope;
```

Update `zigeffect.zig` with matching top-level aliases for mailbox types and helpers.

- [ ] **Step 4: Run green tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: all tests pass.

- [ ] **Step 5: Format and commit**

Run:

```bash
zig fmt --check packages/zigeffect/src/cluster/mailbox.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/entity_test.zig
git add packages/zigeffect/src/cluster/mailbox.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/entity_test.zig
git commit -m "feat(zigeffect): add local entity mailbox storage"
```

## Task 3: Runtime Registration, Scopes, Services, And Refs

**Files:**
- Create: `packages/zigeffect/src/cluster/entity.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/entity_test.zig`

- [ ] **Step 1: Write failing runtime registration and scope tests**

Append to `packages/zigeffect/test/entity_test.zig`:

```zig
test "local entity runtime registers entities refs services and finalizers" {
    var runtime = fx.LocalEntityRuntime.init(std.testing.allocator, .{});
    defer runtime.deinit();

    const address = fx.entityAddress("counter", "one");
    const ref = try runtime.registerEntity(.{
        .address = address,
        .name = "counter-one",
        .idle_timeout_ms = 500,
    }, 1_000);

    try std.testing.expect(ref.address.eql(address));
    try std.testing.expectEqual(fx.EntityStatus.running, try runtime.status(address));
    try std.testing.expectError(error.DuplicateEntity, runtime.registerEntity(.{
        .address = address,
        .name = "dupe",
    }, 1_100));

    var value: u32 = 42;
    const scope = try runtime.entityScope(address);
    try scope.provideService("counter-state", &value);
    try std.testing.expectError(error.DuplicateEntityService, scope.provideService("counter-state", &value));
    const raw = (try scope.service("counter-state")).?;
    const typed: *u32 = @ptrCast(@alignCast(raw));
    try std.testing.expectEqual(@as(u32, 42), typed.*);
}

test "entity scope finalizers run in reverse order on shutdown" {
    var runtime = fx.LocalEntityRuntime.init(std.testing.allocator, .{});
    defer runtime.deinit();

    const address = fx.entityAddress("counter", "one");
    _ = try runtime.registerEntity(.{
        .address = address,
        .name = "counter-one",
        .idle_timeout_ms = 0,
    }, 1_000);

    var releases = std.ArrayList(u8).empty;
    defer releases.deinit(std.testing.allocator);

    const Resource = struct {
        releases: *std.ArrayList(u8),
        marker: u8,
    };
    const release = struct {
        fn run(resource: *Resource) void {
            resource.releases.append(std.testing.allocator, resource.marker) catch unreachable;
        }
    }.run;

    var first = Resource{ .releases = &releases, .marker = 'a' };
    var second = Resource{ .releases = &releases, .marker = 'b' };
    const scope = try runtime.entityScope(address);
    try scope.addFinalizerFor(Resource, &first, release);
    try scope.addFinalizerFor(Resource, &second, release);

    runtime.shutdownIdle(1_001);
    try std.testing.expectEqual(fx.EntityStatus.stopped, try runtime.status(address));
    try std.testing.expectEqualStrings("ba", releases.items);
}
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: failure because local entity runtime and scope APIs do not exist.

- [ ] **Step 3: Implement entity runtime skeleton, scopes, services, and refs**

Create `packages/zigeffect/src/cluster/entity.zig` with imports:

```zig
const std = @import("std");
const identity = @import("identity.zig");
const mailbox_mod = @import("mailbox.zig");
const scope_mod = @import("../core/scope.zig");
const result_mod = @import("../core/result.zig");
const supervisor_mod = @import("../runtime/supervisor.zig");

pub const Allocator = std.mem.Allocator;
pub const EntityAddress = identity.EntityAddress;
pub const EntityEnvelope = mailbox_mod.EntityEnvelope;
pub const EntityAsk = mailbox_mod.EntityAsk;
pub const EntityCorrelationId = mailbox_mod.EntityCorrelationId;
pub const EntityMailboxError = mailbox_mod.EntityMailboxError;
pub const LocalMailboxStore = mailbox_mod.LocalMailboxStore;
pub const FinalizerExit = result_mod.FinalizerExit;
pub const Scope = scope_mod.Scope;
pub const Supervisor = supervisor_mod.Supervisor;
pub const SupervisorDecision = supervisor_mod.SupervisorDecision;
pub const SupervisorError = supervisor_mod.SupervisorError;
pub const SupervisorId = supervisor_mod.SupervisorId;
pub const SupervisorRestartMode = supervisor_mod.SupervisorRestartMode;
pub const SupervisorStrategy = supervisor_mod.SupervisorStrategy;
pub const RestartIntensity = supervisor_mod.RestartIntensity;
```

Add public types:

```zig
pub const EntityStatus = enum { idle, running, stopping, stopped, interrupted, failed, escalated };

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
```

Implement `EntityScope`:

```zig
const ServiceEntry = struct {
    name: []const u8,
    value: ?*anyopaque,
};

pub const EntityScope = struct {
    allocator: Allocator,
    scope: Scope,
    services: std.ArrayList(ServiceEntry) = .empty,

    pub fn init(allocator: Allocator) EntityScope {
        return .{ .allocator = allocator, .scope = Scope.init(allocator) };
    }

    pub fn deinit(self: *EntityScope) void {
        self.scope.deinit();
        for (self.services.items) |entry| self.allocator.free(entry.name);
        self.services.deinit(self.allocator);
    }

    pub fn close(self: *EntityScope, exit: FinalizerExit) void {
        self.scope.closeWithExit(exit);
    }

    pub fn addFinalizerFor(self: *EntityScope, comptime Resource: type, resource: *Resource, comptime release: *const fn (*Resource) void) Allocator.Error!void {
        try self.scope.addFinalizerFor(Resource, resource, release);
    }

    pub fn provideService(self: *EntityScope, name: []const u8, value: ?*anyopaque) (Allocator.Error || EntityRuntimeError)!void {
        if (self.findService(name) != null) return error.DuplicateEntityService;
        try self.services.append(self.allocator, .{ .name = try self.allocator.dupe(u8, name), .value = value });
    }

    pub fn service(self: *const EntityScope, name: []const u8) EntityRuntimeError!?*anyopaque {
        const index = self.findService(name) orelse return error.EntityServiceNotFound;
        return self.services.items[index].value;
    }

    fn findService(self: *const EntityScope, name: []const u8) ?usize {
        for (self.services.items, 0..) |entry, index| {
            if (std.mem.eql(u8, entry.name, name)) return index;
        }
        return null;
    }
};
```

If `Scope.closeWithExit` does not exist yet, add this method to `packages/zigeffect/src/core/scope.zig`:

```zig
    pub fn closeWithExit(self: *Scope, exit: FinalizerExit) void {
        if (self.closed) return;
        var index = self.finalizers.items.len;
        while (index > 0) {
            index -= 1;
            const finalizer = self.finalizers.items[index];
            if (finalizer.run(finalizer.state, exit)) |failure| {
                self.finalizer_failures.append(self.allocator, failure) catch {};
                self.recordResourceFinalized(finalizer, failure);
            } else {
                self.recordResourceFinalized(finalizer, null);
            }
        }
        self.recordScopeClosed(exit);
        self.closed = true;
    }
```

Then update existing `Scope.close` to call `closeWithExit(.success)`.

Implement runtime state:

```zig
const EntityInstance = struct {
    address: EntityAddress,
    name: []const u8,
    status: EntityStatus = .running,
    scope: EntityScope,
    idle_timeout_ms: ?u64 = null,
    last_active_ms: u64 = 0,
    supervisor_child_id: supervisor_mod.SupervisorChildId,
};

pub const LocalEntityRuntimeOptions = struct {
    supervisor_id: SupervisorId = 1,
    supervisor_name: []const u8 = "local-entities",
    supervisor_strategy: SupervisorStrategy = .one_for_one,
    restart_intensity: RestartIntensity = .{},
};
```

Implement `LocalEntityRuntime.init`, `deinit`, `registerEntity`, `ref`, `status`, `restartCount`, `pendingCount`, `entityScope`, and `shutdownIdle`. `registerEntity` should clone the address and name, add a `.entity` supervisor child, call `supervisor.startAll(now_ms)`, and return `EntityRef`.

Implement `EntityRef` with only the struct fields in this task:

```zig
pub const EntityRef = struct {
    address: EntityAddress,
    runtime: *LocalEntityRuntime,
};
```

Update `cluster/root.zig` and `zigeffect.zig` to export:

```zig
pub const entity = @import("entity.zig");
pub const EntityStatus = entity.EntityStatus;
pub const EntityRuntimeError = entity.EntityRuntimeError;
pub const EntityRegistration = entity.EntityRegistration;
pub const EntityHandlerResult = entity.EntityHandlerResult;
pub const EntityScope = entity.EntityScope;
pub const LocalEntityRuntimeOptions = entity.LocalEntityRuntimeOptions;
pub const LocalEntityRuntime = entity.LocalEntityRuntime;
pub const EntityRef = entity.EntityRef;
```

- [ ] **Step 4: Run green tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: all tests pass.

- [ ] **Step 5: Format and commit**

Run:

```bash
zig fmt --check packages/zigeffect/src/core/scope.zig packages/zigeffect/src/cluster/entity.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/entity_test.zig
git add packages/zigeffect/src/core/scope.zig packages/zigeffect/src/cluster/entity.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/entity_test.zig
git commit -m "feat(zigeffect): add local entity runtime scopes"
```

## Task 4: Tell Ask Reply Interrupt Processing

**Files:**
- Modify: `packages/zigeffect/src/cluster/entity.zig`
- Modify: `packages/zigeffect/test/entity_test.zig`

- [ ] **Step 1: Write failing processing tests**

Append to `packages/zigeffect/test/entity_test.zig`:

```zig
test "entity refs tell ask reply and process ordered messages" {
    var runtime = fx.LocalEntityRuntime.init(std.testing.allocator, .{});
    defer runtime.deinit();

    const address = fx.entityAddress("counter", "one");
    const ref = try runtime.registerEntity(.{ .address = address, .name = "counter-one" }, 1_000);

    var tell = try ref.tell("text", "inc", "first command");
    defer fx.deinitEntityEnvelope(std.testing.allocator, tell);
    var ask = try ref.ask("text", "get", "read current value");
    defer ask.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), runtime.pendingCount(address));

    const Handler = struct {
        var seen = std.ArrayList([]const u8).empty;

        fn handle(_: *fx.EntityScope, envelope: fx.EntityEnvelope) !fx.EntityHandlerResult {
            try seen.append(std.testing.allocator, envelope.payload);
            if (envelope.kind == .ask) return .{ .reply = "value=1" };
            return .noreply;
        }
    };
    defer Handler.seen.deinit(std.testing.allocator);

    var first = try runtime.processNext(address, Handler, 1_100);
    defer first.deinit(std.testing.allocator);
    var second = try runtime.processNext(address, Handler, 1_200);
    defer second.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("inc", Handler.seen.items[0]);
    try std.testing.expectEqualStrings("get", Handler.seen.items[1]);
    try std.testing.expect(!first.replied);
    try std.testing.expect(second.replied);

    var reply = try runtime.takeReply(ask.correlation_id);
    defer fx.deinitEntityEnvelope(std.testing.allocator, reply);
    try std.testing.expectEqual(fx.EntityEnvelopeKind.reply, reply.kind);
    try std.testing.expectEqualStrings("value=1", reply.payload);
}

test "interrupt envelope marks entity interrupted and closes scope" {
    var runtime = fx.LocalEntityRuntime.init(std.testing.allocator, .{});
    defer runtime.deinit();

    const address = fx.entityAddress("counter", "one");
    const ref = try runtime.registerEntity(.{ .address = address, .name = "counter-one" }, 1_000);

    var interrupt = try ref.interrupt("shutdown");
    defer fx.deinitEntityEnvelope(std.testing.allocator, interrupt);

    const Handler = struct {
        fn handle(_: *fx.EntityScope, _: fx.EntityEnvelope) !fx.EntityHandlerResult {
            return .noreply;
        }
    };

    var result = try runtime.processNext(address, Handler, 1_100);
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(fx.EntityEnvelopeKind.interrupt, result.envelope.kind);
    try std.testing.expectEqual(fx.EntityStatus.interrupted, try runtime.status(address));
}
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: failure because ref methods, process results, and processing behavior are incomplete.

- [ ] **Step 3: Implement ref methods and `processNext`**

Add `EntityProcessResult`:

```zig
pub const EntityProcessResult = struct {
    address: EntityAddress,
    envelope: EntityEnvelope,
    status: EntityStatus,
    replied: bool = false,
    supervisor_decision: ?SupervisorDecision = null,

    pub fn deinit(self: *EntityProcessResult, allocator: Allocator) void {
        mailbox_mod.deinitEntityEnvelope(allocator, self.envelope);
    }
};
```

Add methods to `EntityRef`:

```zig
    pub fn tell(self: EntityRef, payload_type_name: []const u8, payload: []const u8, redacted_detail: []const u8) Allocator.Error!EntityEnvelope {
        return self.runtime.mailbox.offer(.{
            .kind = .tell,
            .address = self.address,
            .payload_type_name = payload_type_name,
            .payload = payload,
            .redacted_detail = redacted_detail,
        });
    }

    pub fn ask(self: EntityRef, payload_type_name: []const u8, payload: []const u8, redacted_detail: []const u8) Allocator.Error!EntityAsk {
        const envelope = try self.runtime.mailbox.offer(.{
            .kind = .ask,
            .address = self.address,
            .payload_type_name = payload_type_name,
            .payload = payload,
            .redacted_detail = redacted_detail,
        });
        return .{ .envelope = envelope, .correlation_id = envelope.correlation_id.? };
    }

    pub fn interrupt(self: EntityRef, reason: []const u8) Allocator.Error!EntityEnvelope {
        return self.runtime.mailbox.offer(.{
            .kind = .interrupt,
            .address = self.address,
            .payload_type_name = "interrupt",
            .payload = reason,
            .redacted_detail = reason,
        });
    }
```

Implement `LocalEntityRuntime.takeReply` as a pass-through to `mailbox.takeReply`.

Implement `processNext`:

```zig
    pub fn processNext(self: *LocalEntityRuntime, address: EntityAddress, handler: anytype, now_ms: u64) anyerror!EntityProcessResult {
        const index = self.findEntityIndex(address) orelse return error.EntityNotFound;
        var instance = &self.entities.items[index];
        if (instance.status != .running and instance.status != .idle) return error.EntityNotRunning;

        var envelope = try self.mailbox.take(address);
        errdefer mailbox_mod.deinitEntityEnvelope(self.allocator, envelope);
        instance.last_active_ms = now_ms;

        if (envelope.kind == .interrupt) {
            instance.status = .interrupted;
            instance.scope.close(.{ .interrupted = 0 });
            return .{ .address = address, .envelope = envelope, .status = instance.status };
        }

        if (envelope.kind == .reply) {
            return .{ .address = address, .envelope = envelope, .status = instance.status };
        }

        const outcome = handler.handle(&instance.scope, envelope) catch |err| {
            try self.handleEntityFailure(index, err, now_ms);
            return err;
        };

        var replied = false;
        switch (outcome) {
            .noreply => {},
            .reply => |payload| if (envelope.kind == .ask) {
                var reply = try self.mailbox.storeReply(.{
                    .kind = .reply,
                    .address = address,
                    .correlation_id = envelope.correlation_id,
                    .payload_type_name = envelope.payload_type_name,
                    .payload = payload,
                });
                mailbox_mod.deinitEntityEnvelope(self.allocator, reply);
                replied = true;
            },
            .stop => {
                instance.status = .stopped;
                instance.scope.close(.success);
            },
        }

        return .{ .address = address, .envelope = envelope, .status = instance.status, .replied = replied };
    }
```

Add a temporary `handleEntityFailure` that returns the handler error through `anyerror` without supervisor recovery. Task 6 replaces it with full supervisor behavior:

```zig
    fn handleEntityFailure(self: *LocalEntityRuntime, index: usize, err: anyerror, now_ms: u64) !void {
        _ = now_ms;
        self.entities.items[index].status = .failed;
        return err;
    }
```

- [ ] **Step 4: Run green tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: all tests pass.

- [ ] **Step 5: Format and commit**

Run:

```bash
zig fmt --check packages/zigeffect/src/cluster/entity.zig packages/zigeffect/test/entity_test.zig
git add packages/zigeffect/src/cluster/entity.zig packages/zigeffect/test/entity_test.zig
git commit -m "feat(zigeffect): process local entity messages"
```

## Task 5: Idle Shutdown

**Files:**
- Modify: `packages/zigeffect/src/cluster/entity.zig`
- Modify: `packages/zigeffect/test/entity_test.zig`

- [ ] **Step 1: Write failing idle shutdown test**

Append to `packages/zigeffect/test/entity_test.zig`:

```zig
test "idle shutdown only stops entities with empty expired mailboxes" {
    var runtime = fx.LocalEntityRuntime.init(std.testing.allocator, .{});
    defer runtime.deinit();

    const idle = fx.entityAddress("counter", "idle");
    const busy = fx.entityAddress("counter", "busy");
    const ref_idle = try runtime.registerEntity(.{ .address = idle, .name = "idle", .idle_timeout_ms = 100 }, 1_000);
    const ref_busy = try runtime.registerEntity(.{ .address = busy, .name = "busy", .idle_timeout_ms = 100 }, 1_000);

    var queued = try ref_busy.tell("text", "work", "queued");
    defer fx.deinitEntityEnvelope(std.testing.allocator, queued);
    _ = ref_idle;

    runtime.shutdownIdle(1_101);
    try std.testing.expectEqual(fx.EntityStatus.stopped, try runtime.status(idle));
    try std.testing.expectEqual(fx.EntityStatus.running, try runtime.status(busy));
}
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: failure if `shutdownIdle` does not check mailbox emptiness and timeout.

- [ ] **Step 3: Implement idle shutdown**

Implement:

```zig
    pub fn shutdownIdle(self: *LocalEntityRuntime, now_ms: u64) void {
        for (self.entities.items) |*instance| {
            if (instance.status != .running and instance.status != .idle) continue;
            const timeout = instance.idle_timeout_ms orelse continue;
            if (self.mailbox.pendingCount(instance.address) > 0) continue;
            if (now_ms < instance.last_active_ms + timeout) continue;
            instance.status = .stopped;
            instance.scope.close(.success);
        }
    }
```

- [ ] **Step 4: Run green tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: all tests pass.

- [ ] **Step 5: Format and commit**

Run:

```bash
zig fmt --check packages/zigeffect/src/cluster/entity.zig packages/zigeffect/test/entity_test.zig
git add packages/zigeffect/src/cluster/entity.zig packages/zigeffect/test/entity_test.zig
git commit -m "feat(zigeffect): add local entity idle shutdown"
```

## Task 6: Supervisor Recovery And Escalation

**Files:**
- Modify: `packages/zigeffect/src/cluster/entity.zig`
- Modify: `packages/zigeffect/test/entity_test.zig`

- [ ] **Step 1: Write failing supervisor recovery tests**

Append to `packages/zigeffect/test/entity_test.zig`:

```zig
test "handler failure restarts entity through supervisor" {
    var runtime = fx.LocalEntityRuntime.init(std.testing.allocator, .{
        .restart_intensity = .{ .max_restarts = 2, .within_ms = 1_000 },
    });
    defer runtime.deinit();

    const address = fx.entityAddress("counter", "one");
    const ref = try runtime.registerEntity(.{ .address = address, .name = "counter-one" }, 1_000);
    var queued = try ref.tell("text", "boom", "failure");
    defer fx.deinitEntityEnvelope(std.testing.allocator, queued);

    const Handler = struct {
        fn handle(_: *fx.EntityScope, _: fx.EntityEnvelope) !fx.EntityHandlerResult {
            return error.Boom;
        }
    };

    try std.testing.expectError(error.Boom, runtime.processNext(address, Handler, 1_100));
    try std.testing.expectEqual(fx.EntityStatus.running, try runtime.status(address));
    try std.testing.expectEqual(@as(usize, 1), try runtime.restartCount(address));
}

test "repeated handler failure escalates entity through supervisor intensity" {
    var runtime = fx.LocalEntityRuntime.init(std.testing.allocator, .{
        .restart_intensity = .{ .max_restarts = 1, .within_ms = 1_000 },
    });
    defer runtime.deinit();

    const address = fx.entityAddress("counter", "one");
    const ref = try runtime.registerEntity(.{ .address = address, .name = "counter-one" }, 1_000);
    var first = try ref.tell("text", "boom-1", "failure");
    defer fx.deinitEntityEnvelope(std.testing.allocator, first);
    var second = try ref.tell("text", "boom-2", "failure");
    defer fx.deinitEntityEnvelope(std.testing.allocator, second);

    const Handler = struct {
        fn handle(_: *fx.EntityScope, _: fx.EntityEnvelope) !fx.EntityHandlerResult {
            return error.Boom;
        }
    };

    try std.testing.expectError(error.Boom, runtime.processNext(address, Handler, 1_100));
    try std.testing.expectError(error.Boom, runtime.processNext(address, Handler, 1_200));
    try std.testing.expectEqual(fx.EntityStatus.escalated, try runtime.status(address));
    try std.testing.expectEqual(@as(usize, 1), try runtime.restartCount(address));
}
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: failure because handler failures currently mark the entity failed without supervisor restart/escalation.

- [ ] **Step 3: Implement supervisor-backed failure handling**

Replace `handleEntityFailure`:

```zig
    fn handleEntityFailure(self: *LocalEntityRuntime, index: usize, err: anyerror, now_ms: u64) !void {
        var instance = &self.entities.items[index];
        const decision = try self.supervisor.reportChildExit(
            instance.supervisor_child_id,
            .{ .failure = @errorName(err) },
            now_ms,
        );

        instance.scope.close(.{ .failure = @errorName(err) });
        instance.scope.deinit();
        instance.scope = EntityScope.init(self.allocator);

        if (decision.escalated) {
            instance.status = .escalated;
        } else if (decision.restarted_children > 0) {
            instance.status = .running;
        } else {
            instance.status = .failed;
        }
    }
```

Ensure `restartCount` delegates to `self.supervisor.childRestartCount(instance.supervisor_child_id)`.

- [ ] **Step 4: Run green tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: all tests pass.

- [ ] **Step 5: Format and commit**

Run:

```bash
zig fmt --check packages/zigeffect/src/cluster/entity.zig packages/zigeffect/test/entity_test.zig
git add packages/zigeffect/src/cluster/entity.zig packages/zigeffect/test/entity_test.zig
git commit -m "feat(zigeffect): recover local entities with supervisor"
```

## Task 7: Architecture Docs, Roadmap Checklist, And Full Verification

**Files:**
- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

- [ ] **Step 1: Update architecture docs**

In `packages/zigeffect/docs/architecture.md`, replace the cluster marker bullet with:

```markdown
- `root.zig`: cluster namespace facade and ergonomic public aliases.
- `identity.zig`: local entity type, id, address, and stable id derivation.
- `mailbox.zig`: local in-memory entity envelopes, per-entity FIFO mailbox
  storage, ask correlations, reply storage, and envelope ownership helpers.
- `entity.zig`: local entity runtime, runtime-bound refs, entity scopes,
  services, finalizers, idle shutdown, and supervisor-backed handler failure
  recovery.
```

Add below the cluster section:

```markdown
The local entity runtime is single-process and in-memory. It gives cluster
concepts a deterministic local execution model, but durable delivery,
idempotent envelopes, shard routing, runner ownership, and transport are
separate milestones.
```

- [ ] **Step 2: Mark Milestone 25 complete**

In `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`, mark all Milestone 25 deliverables and acceptance as `[x]`.

- [ ] **Step 3: Run the full gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
zig fmt --check packages/zigeffect/src/core/scope.zig packages/zigeffect/src/cluster/identity.zig packages/zigeffect/src/cluster/mailbox.zig packages/zigeffect/src/cluster/entity.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/entity_test.zig packages/zigeffect/test/all_test.zig
git diff --check
rg -n 'TO''DO|TB''D|implement'' later|fill'' in' packages/zigeffect/src/cluster packages/zigeffect/test/entity_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
```

Expected:

- `bun run zigeffect:test` exits 0.
- `zig build examples` exits 0.
- `bun run zig:test` exits 0.
- `zig fmt --check` exits 0.
- `git diff --check` exits 0.
- `rg` exits 1 with no output, meaning no placeholder text was found.

- [ ] **Step 4: Commit docs**

Run:

```bash
git add packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "docs(zigeffect): mark local entity actors complete"
```
