# zigeffect Shard Identity Routing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add deterministic shard ids, configurable shard counts, reloadable local routing tables, and public cluster routing exports for Milestone 27.

**Architecture:** Add a focused `cluster/routing.zig` module that depends only on cluster identity and `std`. It computes stable shard ids from entity ids, owns an allocator-backed routing table with one local entry per shard, and exposes snapshot/reload helpers that prove restart stability before runner identity exists.

**Tech Stack:** Zig, `std.hash.Fnv1a_64`, `std.ArrayList`, `bun run zigeffect:test`, `zig build test`, `zig build examples`.

---

## File Structure

- Create `packages/zigeffect/src/cluster/routing.zig`: shard id types, hash helpers, local routing table, snapshot/reload.
- Create `packages/zigeffect/test/routing_test.zig`: public exports, shard stability, invalid counts, local routing, reload behavior.
- Modify `packages/zigeffect/src/cluster/root.zig`: import and re-export routing module APIs.
- Modify `packages/zigeffect/src/zigeffect.zig`: add top-level ergonomic routing aliases.
- Modify `packages/zigeffect/test/all_test.zig`: import `routing_test.zig`.
- Modify `packages/zigeffect/docs/architecture.md`: document the routing module.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`: mark Milestone 27 complete after verification.

## Task 1: Public Shard Identity Tests

**Files:**
- Create: `packages/zigeffect/test/routing_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [x] **Step 1: Write the failing public export and shard-id tests**

Add this file:

```zig
const std = @import("std");
const fx = @import("zigeffect");

test "shard routing public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "routing"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardId"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardCount"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardRoutingTable"));
    try std.testing.expect(@hasDecl(fx.cluster, "shardIdForEntityId"));
    try std.testing.expect(@hasDecl(fx.cluster, "shardIdForAddress"));
    try std.testing.expect(@hasDecl(fx, "ShardId"));
    try std.testing.expect(@hasDecl(fx, "ShardRoutingTable"));
}

test "shard ids are stable bounded and entity-sensitive" {
    const shard_count: fx.ShardCount = 16;
    const first_id = fx.entityId("counter", "tenant-1");
    const second_id = fx.entityId("counter", "tenant-1");
    const other_type_id = fx.entityId("ledger", "tenant-1");
    const other_key_id = fx.entityId("counter", "tenant-2");

    const first = try fx.shardIdForEntityId(first_id, shard_count);
    const second = try fx.shardIdForEntityId(second_id, shard_count);
    const other_type = try fx.shardIdForEntityId(other_type_id, shard_count);
    const other_key = try fx.shardIdForEntityId(other_key_id, shard_count);
    const by_address = try fx.shardIdForAddress(fx.entityAddress("counter", "tenant-1"), shard_count);

    try std.testing.expectEqual(first, second);
    try std.testing.expectEqual(first, by_address);
    try std.testing.expect(first < @as(fx.ShardId, shard_count));
    try std.testing.expect(other_type < @as(fx.ShardId, shard_count));
    try std.testing.expect(other_key < @as(fx.ShardId, shard_count));

    var occupied = [_]bool{false} ** 16;
    const keys = [_][]const u8{ "tenant-1", "tenant-2", "tenant-3", "tenant-4", "tenant-5", "tenant-6", "tenant-7", "tenant-8" };
    for (keys) |key| {
        const shard = try fx.shardIdForAddress(fx.entityAddress("counter", key), shard_count);
        const index: usize = @intCast(shard);
        occupied[index] = true;
    }
    var occupied_count: usize = 0;
    for (occupied) |is_occupied| {
        if (is_occupied) occupied_count += 1;
    }
    try std.testing.expect(occupied_count > 1);
}

test "zero shard counts fail clearly" {
    const address = fx.entityAddress("counter", "one");
    try std.testing.expectError(error.InvalidShardCount, fx.shardIdForAddress(address, 0));
    try std.testing.expectError(error.InvalidShardCount, fx.shardIdForEntityId(address.id, 0));
    try std.testing.expectError(error.InvalidShardCount, fx.ShardRoutingTable.initLocal(std.testing.allocator, .{ .shard_count = 0 }));
}
```

Add this import to `packages/zigeffect/test/all_test.zig`:

```zig
    _ = @import("routing_test.zig");
```

- [x] **Step 2: Run the focused test and verify it fails for missing declarations**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL with errors naming missing declarations such as `routing`,
`ShardId`, or `ShardRoutingTable`.

- [x] **Step 3: Keep the red tests in the worktree for the green implementation**

Do not commit the failing state. Task 2 commits the tests and implementation
together after the focused test command exits 0.

## Task 2: Shard Identity Implementation

**Files:**
- Create: `packages/zigeffect/src/cluster/routing.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [x] **Step 1: Implement shard identity helpers and local table skeleton**

Add `packages/zigeffect/src/cluster/routing.zig`:

```zig
const std = @import("std");
const identity = @import("identity.zig");

pub const Allocator = std.mem.Allocator;
pub const EntityId = identity.EntityId;
pub const EntityAddress = identity.EntityAddress;
pub const ShardId = u64;
pub const ShardCount = u32;
pub const ShardRoutingVersion = u64;

pub const ShardRoutingError = error{
    InvalidShardCount,
    ShardNotFound,
};

pub const ShardRouteTarget = enum { local };

pub const ShardRouteEntry = struct {
    shard_id: ShardId,
    target: ShardRouteTarget = .local,
};

pub const ShardRoute = struct {
    shard_id: ShardId,
    target: ShardRouteTarget,
};

pub const ShardRoutingOptions = struct {
    shard_count: ShardCount,
    version: ShardRoutingVersion = 1,
};

pub const ShardRoutingSnapshot = struct {
    shard_count: ShardCount,
    version: ShardRoutingVersion,
};

pub const ShardRoutingTable = struct {
    allocator: Allocator,
    entries: std.ArrayList(ShardRouteEntry) = .empty,
    version_value: ShardRoutingVersion = 1,

    pub fn initLocal(allocator: Allocator, options: ShardRoutingOptions) (Allocator.Error || ShardRoutingError)!ShardRoutingTable {
        if (options.shard_count == 0) return error.InvalidShardCount;
        var table = ShardRoutingTable{
            .allocator = allocator,
            .version_value = options.version,
        };
        errdefer table.deinit();

        try table.entries.ensureTotalCapacity(allocator, @intCast(options.shard_count));
        var shard_id: ShardId = 0;
        while (shard_id < @as(ShardId, options.shard_count)) : (shard_id += 1) {
            table.entries.appendAssumeCapacity(.{ .shard_id = shard_id });
        }
        return table;
    }

    pub fn deinit(self: *ShardRoutingTable) void {
        self.entries.deinit(self.allocator);
    }
};

pub fn entityShardHash(entity_id: EntityId) u64 {
    var hasher = std.hash.Fnv1a_64.init();
    var id_buf: [8]u8 = undefined;
    std.mem.writeInt(u64, &id_buf, entity_id, .little);
    hasher.update("zigeffect.cluster.shard.v1:");
    hasher.update(&id_buf);
    return hasher.final();
}

pub fn shardIdForEntityId(entity_id: EntityId, shard_count: ShardCount) ShardRoutingError!ShardId {
    if (shard_count == 0) return error.InvalidShardCount;
    return entityShardHash(entity_id) % @as(ShardId, shard_count);
}

pub fn shardIdForAddress(address: EntityAddress, shard_count: ShardCount) ShardRoutingError!ShardId {
    return shardIdForEntityId(address.id, shard_count);
}
```

In `packages/zigeffect/src/cluster/root.zig`, add the module import and exports:

```zig
pub const routing = @import("routing.zig");
pub const ShardId = routing.ShardId;
pub const ShardCount = routing.ShardCount;
pub const ShardRoutingVersion = routing.ShardRoutingVersion;
pub const ShardRoutingError = routing.ShardRoutingError;
pub const ShardRouteTarget = routing.ShardRouteTarget;
pub const ShardRouteEntry = routing.ShardRouteEntry;
pub const ShardRoute = routing.ShardRoute;
pub const ShardRoutingOptions = routing.ShardRoutingOptions;
pub const ShardRoutingSnapshot = routing.ShardRoutingSnapshot;
pub const ShardRoutingTable = routing.ShardRoutingTable;
pub const entityShardHash = routing.entityShardHash;
pub const shardIdForEntityId = routing.shardIdForEntityId;
pub const shardIdForAddress = routing.shardIdForAddress;
```

In `packages/zigeffect/src/zigeffect.zig`, add matching top-level aliases near
the entity and message aliases.

- [x] **Step 2: Run tests and verify Task 1 passes**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS for the new public export, stability, and invalid-count tests.

- [x] **Step 3: Commit shard identity implementation and tests**

```bash
git add packages/zigeffect/test/routing_test.zig packages/zigeffect/test/all_test.zig packages/zigeffect/src/cluster/routing.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig
git commit -m "feat(zigeffect): add shard identity routing"
```

## Task 3: Local Routing Table And Reload Tests

**Files:**
- Modify: `packages/zigeffect/test/routing_test.zig`

- [x] **Step 1: Add failing local routing and reload tests**

Append these tests:

```zig
test "local routing table owns every configured shard" {
    var table = try fx.ShardRoutingTable.initLocal(std.testing.allocator, .{ .shard_count = 8 });
    defer table.deinit();

    try std.testing.expectEqual(@as(fx.ShardCount, 8), table.shardCount());
    try std.testing.expectEqual(@as(fx.ShardRoutingVersion, 1), table.version());

    for (0..8) |index| {
        const shard_id: fx.ShardId = @intCast(index);
        try std.testing.expectEqual(fx.ShardRouteTarget.local, try table.routeShard(shard_id));
    }
    try std.testing.expectError(error.ShardNotFound, table.routeShard(8));

    const address = fx.entityAddress("counter", "one");
    const route = try table.route(address);
    try std.testing.expectEqual(try fx.shardIdForAddress(address, 8), route.shard_id);
    try std.testing.expectEqual(fx.ShardRouteTarget.local, route.target);
}

test "routing table snapshot reload preserves entity routes" {
    var table = try fx.ShardRoutingTable.initLocal(std.testing.allocator, .{
        .shard_count = 12,
        .version = 7,
    });
    defer table.deinit();

    const address = fx.entityAddress("counter", "reload");
    const before = try table.route(address);
    const snapshot = table.snapshot();

    var reloaded = try fx.ShardRoutingTable.reloadLocal(std.testing.allocator, snapshot);
    defer reloaded.deinit();
    const after = try reloaded.route(address);

    try std.testing.expectEqual(@as(fx.ShardCount, 12), snapshot.shard_count);
    try std.testing.expectEqual(@as(fx.ShardRoutingVersion, 7), snapshot.version);
    try std.testing.expectEqual(before.shard_id, after.shard_id);
    try std.testing.expectEqual(before.target, after.target);
    try std.testing.expectEqual(table.shardCount(), reloaded.shardCount());
    try std.testing.expectEqual(table.version(), reloaded.version());
}
```

- [x] **Step 2: Run tests and verify the new tests fail for missing methods**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL with missing declarations such as `shardCount`, `version`,
`routeShard`, `route`, `snapshot`, or `reloadLocal`.

- [x] **Step 3: Keep the red routing-table tests in the worktree for the green implementation**

Do not commit the failing state. Task 4 commits the routing-table tests and
implementation together after the focused test command exits 0.

## Task 4: Local Routing Table Implementation

**Files:**
- Modify: `packages/zigeffect/src/cluster/routing.zig`

- [x] **Step 1: Implement table methods**

Add these methods inside `ShardRoutingTable`:

```zig
    pub fn reloadLocal(allocator: Allocator, routing_snapshot: ShardRoutingSnapshot) (Allocator.Error || ShardRoutingError)!ShardRoutingTable {
        return initLocal(allocator, .{
            .shard_count = routing_snapshot.shard_count,
            .version = routing_snapshot.version,
        });
    }

    pub fn shardCount(self: *const ShardRoutingTable) ShardCount {
        return @intCast(self.entries.items.len);
    }

    pub fn version(self: *const ShardRoutingTable) ShardRoutingVersion {
        return self.version_value;
    }

    pub fn route(self: *const ShardRoutingTable, address: EntityAddress) ShardRoutingError!ShardRoute {
        const shard_id = try shardIdForAddress(address, self.shardCount());
        return .{
            .shard_id = shard_id,
            .target = try self.routeShard(shard_id),
        };
    }

    pub fn routeShard(self: *const ShardRoutingTable, shard_id: ShardId) ShardRoutingError!ShardRouteTarget {
        for (self.entries.items) |entry| {
            if (entry.shard_id == shard_id) return entry.target;
        }
        return error.ShardNotFound;
    }

    pub fn snapshot(self: *const ShardRoutingTable) ShardRoutingSnapshot {
        return .{
            .shard_count = self.shardCount(),
            .version = self.version_value,
        };
    }
```

- [x] **Step 2: Run tests and verify routing table behavior passes**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

- [ ] **Step 3: Commit routing table implementation and tests**

```bash
git add packages/zigeffect/test/routing_test.zig packages/zigeffect/src/cluster/routing.zig
git commit -m "feat(zigeffect): add local shard routing table"
```

## Task 5: Documentation, Roadmap, And Verification

**Files:**
- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

- [ ] **Step 1: Update architecture docs**

Add this bullet in the `src/cluster/` section:

```markdown
- `routing.zig`: deterministic shard ids, entity-id shard hashing,
  configurable local shard routing tables, local route targets, and
  snapshot/reload helpers for restart-stable routing.
```

- [ ] **Step 2: Mark Milestone 27 complete in the roadmap**

Change every Milestone 27 deliverable and acceptance checkbox from `[ ]` to
`[x]`.

- [ ] **Step 3: Run the full Milestone 27 verification gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
zig fmt --check packages/zigeffect/src/cluster/routing.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/routing_test.zig packages/zigeffect/test/all_test.zig
git diff --check
rg -n 'TO''DO|TB''D|implement'' later|fill'' in' packages/zigeffect/src/cluster packages/zigeffect/test/routing_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/specs/2026-06-09-zigeffect-shard-identity-routing-design.md docs/superpowers/plans/2026-06-09-zigeffect-shard-identity-routing.md
```

Expected: the build/test/format/diff commands exit 0. The `rg` placeholder scan
exits 1 with no matches.

- [ ] **Step 4: Commit docs and roadmap**

```bash
git add packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "docs(zigeffect): mark shard routing complete"
```
