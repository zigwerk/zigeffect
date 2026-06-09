# zigeffect Runner Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the RunnerStorage contract, in-memory storage, file-backed storage, and lease acquire/refresh/release/release-all semantics for Milestone 29.

**Architecture:** Add `cluster/runner_storage.zig` as the storage boundary over `RunnerAddress` and `ShardId`. The in-memory store owns an ArrayList lease table. The file-backed store writes one JSON lease file per shard and uses exclusive file creation for atomic local acquisition.

**Tech Stack:** Zig, `std.ArrayList`, `std.json.parseFromSlice`, `std.Io.Dir`, `std.Io.File`, `std.testing.tmpDir`, `bun run zigeffect:test`, `zig build examples`, `bun run zig:test`.

---

## File Structure

- Create `packages/zigeffect/src/cluster/runner_storage.zig`: storage contract, lease types, in-memory store, file-backed store, JSON helpers.
- Create `packages/zigeffect/test/runner_storage_test.zig`: contract exports, in-memory lease semantics, file-backed atomic acquisition, file refresh/release behavior.
- Modify `packages/zigeffect/src/cluster/root.zig`: import and re-export runner storage APIs.
- Modify `packages/zigeffect/src/zigeffect.zig`: add top-level runner storage aliases.
- Modify `packages/zigeffect/test/all_test.zig`: import `runner_storage_test.zig`.
- Modify `packages/zigeffect/docs/architecture.md`: document `runner_storage.zig`.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`: mark Milestone 29 complete after verification.

## Task 1: Storage Contract And In-Memory Acquire

**Files:**
- Create: `packages/zigeffect/test/runner_storage_test.zig`
- Create: `packages/zigeffect/src/cluster/runner_storage.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [ ] **Step 1: Write failing public export and basic acquire tests**

Create `packages/zigeffect/test/runner_storage_test.zig`:

```zig
const std = @import("std");
const fx = @import("zigeffect");

test "runner storage public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "runner_storage"));
    try std.testing.expect(@hasDecl(fx.cluster, "RunnerStorage"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardLease"));
    try std.testing.expect(@hasDecl(fx.cluster, "RunnerLeaseAcquire"));
    try std.testing.expect(@hasDecl(fx.cluster, "InMemoryRunnerStorage"));
    try std.testing.expect(@hasDecl(fx.cluster, "FileRunnerStorage"));
    try std.testing.expect(@hasDecl(fx, "RunnerStorage"));
}

test "in-memory runner storage acquires and lists leases" {
    var storage = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage.deinit();
    var contract = storage.asRunnerStorage();

    const owner = fx.runnerAddress("machine-a", "runner-a");
    const lease = try contract.acquire(.{
        .shard_id = 3,
        .owner = owner,
        .now_ms = 1_000,
        .ttl_ms = 500,
    });

    try std.testing.expectEqual(@as(fx.ShardId, 3), lease.shard_id);
    try std.testing.expect(lease.owner.eql(owner));
    try std.testing.expectEqual(@as(u64, 1_000), lease.acquired_at_ms);
    try std.testing.expectEqual(@as(u64, 1_500), lease.expires_at_ms);
    try std.testing.expectEqual(@as(u64, 1), lease.version);

    const found = (try contract.lease(3)).?;
    try std.testing.expect(found.owner.eql(owner));

    var leases = try contract.leases(std.testing.allocator);
    defer leases.deinit();
    try std.testing.expectEqual(@as(usize, 1), leases.leases.len);
}
```

Add this import to `packages/zigeffect/test/all_test.zig`:

```zig
    _ = @import("runner_storage_test.zig");
```

- [ ] **Step 2: Run the red test**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL with missing declarations for `RunnerStorage`,
`InMemoryRunnerStorage`, or lease types.

- [ ] **Step 3: Implement contract, lease types, and minimal in-memory acquire**

Add `runner_storage.zig` with:

- imports for `runner.zig` and `routing.zig`
- `ShardLease`, request structs, `RunnerLeaseBatch`, `RunnerStorageError`
- `RunnerStorage` vtable wrapper methods
- `InMemoryRunnerStorage` with `leases_list: std.ArrayList(ShardLease)`
- `acquire`, `lease`, `leases`, `reset`, and `asRunnerStorage`

The first implementation may return `LeaseConflict` for any existing
non-expired lease and may leave refresh/release methods as declarations that
return `LeaseNotFound` until Task 2 drives them.

- [ ] **Step 4: Run green tests and hygiene checks**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/runner_storage.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/runner_storage_test.zig packages/zigeffect/test/all_test.zig
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 5: Commit storage contract and in-memory acquire**

```bash
git add packages/zigeffect/src/cluster/runner_storage.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/runner_storage_test.zig packages/zigeffect/test/all_test.zig
git commit -m "feat(zigeffect): add runner storage contract"
```

## Task 2: In-Memory Lease Semantics

**Files:**
- Modify: `packages/zigeffect/test/runner_storage_test.zig`
- Modify: `packages/zigeffect/src/cluster/runner_storage.zig`

- [ ] **Step 1: Add failing in-memory conflict, refresh, release, and release-all tests**

Append these tests to `packages/zigeffect/test/runner_storage_test.zig`:

```zig
test "in-memory runner storage rejects active lease conflicts and invalid ttl" {
    var storage = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage.deinit();
    var contract = storage.asRunnerStorage();

    const owner = fx.runnerAddress("machine-a", "runner-a");
    const contender = fx.runnerAddress("machine-b", "runner-b");
    _ = try contract.acquire(.{ .shard_id = 8, .owner = owner, .now_ms = 10, .ttl_ms = 100 });

    try std.testing.expectError(error.LeaseConflict, contract.acquire(.{
        .shard_id = 8,
        .owner = contender,
        .now_ms = 20,
        .ttl_ms = 100,
    }));
    try std.testing.expectError(error.InvalidLeaseTtl, contract.acquire(.{
        .shard_id = 9,
        .owner = owner,
        .now_ms = 20,
        .ttl_ms = 0,
    }));
}

test "in-memory runner storage replaces expired leases" {
    var storage = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage.deinit();
    var contract = storage.asRunnerStorage();

    const owner = fx.runnerAddress("machine-a", "runner-a");
    const contender = fx.runnerAddress("machine-b", "runner-b");
    _ = try contract.acquire(.{ .shard_id = 4, .owner = owner, .now_ms = 100, .ttl_ms = 25 });

    const replacement = try contract.acquire(.{ .shard_id = 4, .owner = contender, .now_ms = 125, .ttl_ms = 50 });
    try std.testing.expect(replacement.owner.eql(contender));
    try std.testing.expectEqual(@as(u64, 2), replacement.version);
    try std.testing.expectEqual(@as(u64, 175), replacement.expires_at_ms);
}

test "in-memory runner storage refreshes and releases owned leases" {
    var storage = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage.deinit();
    var contract = storage.asRunnerStorage();

    const owner = fx.runnerAddress("machine-a", "runner-a");
    const intruder = fx.runnerAddress("machine-b", "runner-b");
    _ = try contract.acquire(.{ .shard_id = 12, .owner = owner, .now_ms = 1_000, .ttl_ms = 200 });

    try std.testing.expectError(error.LeaseNotOwned, contract.refresh(.{
        .shard_id = 12,
        .owner = intruder,
        .now_ms = 1_100,
        .ttl_ms = 200,
    }));

    const refreshed = try contract.refresh(.{ .shard_id = 12, .owner = owner, .now_ms = 1_100, .ttl_ms = 400 });
    try std.testing.expectEqual(@as(u64, 2), refreshed.version);
    try std.testing.expectEqual(@as(u64, 1_500), refreshed.expires_at_ms);

    try std.testing.expectError(error.LeaseNotOwned, contract.release(.{ .shard_id = 12, .owner = intruder }));
    try contract.release(.{ .shard_id = 12, .owner = owner });
    try std.testing.expectEqual(@as(?fx.ShardLease, null), try contract.lease(12));
}

test "in-memory runner storage rejects expired refreshes and releases all owned leases" {
    var storage = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage.deinit();
    var contract = storage.asRunnerStorage();

    const owner = fx.runnerAddress("machine-a", "runner-a");
    const other = fx.runnerAddress("machine-b", "runner-b");
    _ = try contract.acquire(.{ .shard_id = 1, .owner = owner, .now_ms = 0, .ttl_ms = 10 });
    _ = try contract.acquire(.{ .shard_id = 2, .owner = owner, .now_ms = 0, .ttl_ms = 100 });
    _ = try contract.acquire(.{ .shard_id = 3, .owner = other, .now_ms = 0, .ttl_ms = 100 });

    try std.testing.expectError(error.LeaseExpired, contract.refresh(.{
        .shard_id = 1,
        .owner = owner,
        .now_ms = 10,
        .ttl_ms = 100,
    }));

    const released = try contract.releaseAll(owner);
    try std.testing.expectEqual(@as(usize, 2), released);
    var leases = try contract.leases(std.testing.allocator);
    defer leases.deinit();
    try std.testing.expectEqual(@as(usize, 1), leases.leases.len);
    try std.testing.expect(leases.leases[0].owner.eql(other));
}
```

- [ ] **Step 2: Run the red in-memory semantics tests**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL on missing or incomplete refresh/release/release-all behavior.

- [ ] **Step 3: Implement complete in-memory lease semantics**

Implement:

- TTL validation with overflow-safe expiration calculation
- `refresh`
- `release`
- `releaseAll`
- owner equality checks
- expired lease replacement with version increment
- vtable adapters for all operations

The implementation should add these concrete helpers and methods:

```zig
fn leaseExpiresAt(now_ms: u64, ttl_ms: RunnerLeaseTtlMs) RunnerStorageError!u64 {
    if (ttl_ms == 0) return error.InvalidLeaseTtl;
    return std.math.add(u64, now_ms, ttl_ms) catch error.InvalidLeaseTtl;
}

fn leaseExpired(lease: ShardLease, now_ms: u64) bool {
    return lease.expires_at_ms <= now_ms;
}

pub fn refresh(self: *InMemoryRunnerStorage, request: RunnerLeaseRefresh) (Allocator.Error || RunnerStorageError)!ShardLease
pub fn release(self: *InMemoryRunnerStorage, request: RunnerLeaseRelease) RunnerStorageError!void
pub fn releaseAll(self: *InMemoryRunnerStorage, owner: RunnerAddress) usize
```

- [ ] **Step 4: Run green tests and hygiene checks**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/runner_storage.zig packages/zigeffect/test/runner_storage_test.zig
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 5: Commit in-memory lease semantics**

```bash
git add packages/zigeffect/src/cluster/runner_storage.zig packages/zigeffect/test/runner_storage_test.zig
git commit -m "feat(zigeffect): implement in-memory runner leases"
```

## Task 3: File-Backed Atomic Acquire

**Files:**
- Modify: `packages/zigeffect/test/runner_storage_test.zig`
- Modify: `packages/zigeffect/src/cluster/runner_storage.zig`

- [ ] **Step 1: Add failing file-backed acquire tests**

Append these tests to `packages/zigeffect/test/runner_storage_test.zig`:

```zig
test "runner lease json round-trips" {
    const owner = fx.runnerAddress("machine-a", "runner-a");
    const lease: fx.ShardLease = .{
        .shard_id = 42,
        .owner = owner,
        .acquired_at_ms = 1_000,
        .refreshed_at_ms = 1_000,
        .expires_at_ms = 2_000,
        .version = 7,
    };

    const json = try fx.formatShardLeaseJson(std.testing.allocator, lease);
    defer std.testing.allocator.free(json);

    const parsed = try fx.parseShardLeaseJson(std.testing.allocator, json);
    try std.testing.expectEqual(lease.shard_id, parsed.shard_id);
    try std.testing.expect(parsed.owner.eql(owner));
    try std.testing.expectEqual(lease.version, parsed.version);
}

test "file runner storage acquires leases atomically across store instances" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var first = try fx.FileRunnerStorage.open(std.testing.allocator, tmp.dir, .{});
    defer first.deinit();
    var second = try fx.FileRunnerStorage.open(std.testing.allocator, tmp.dir, .{});
    defer second.deinit();

    var first_contract = first.asRunnerStorage();
    var second_contract = second.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");
    const contender = fx.runnerAddress("machine-b", "runner-b");

    _ = try first_contract.acquire(.{ .shard_id = 17, .owner = owner, .now_ms = 500, .ttl_ms = 250 });
    try std.testing.expectError(error.LeaseConflict, second_contract.acquire(.{
        .shard_id = 17,
        .owner = contender,
        .now_ms = 600,
        .ttl_ms = 250,
    }));

    const found = (try second_contract.lease(17)).?;
    try std.testing.expect(found.owner.eql(owner));

    var file = try tmp.dir.openFile("runner-shard-17.json", .{});
    file.close();
}

test "file runner storage replaces expired persisted leases" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var first = try fx.FileRunnerStorage.open(std.testing.allocator, tmp.dir, .{});
    defer first.deinit();
    var second = try fx.FileRunnerStorage.open(std.testing.allocator, tmp.dir, .{});
    defer second.deinit();

    var first_contract = first.asRunnerStorage();
    var second_contract = second.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");
    const contender = fx.runnerAddress("machine-b", "runner-b");
    _ = try first_contract.acquire(.{ .shard_id = 18, .owner = owner, .now_ms = 100, .ttl_ms = 25 });

    const replacement = try second_contract.acquire(.{ .shard_id = 18, .owner = contender, .now_ms = 125, .ttl_ms = 100 });
    try std.testing.expect(replacement.owner.eql(contender));
    try std.testing.expectEqual(@as(u64, 2), replacement.version);
}
```

- [ ] **Step 2: Run the red file acquire tests**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL on missing `FileRunnerStorage`, JSON helpers, or file acquire
behavior.

- [ ] **Step 3: Implement file-backed JSON and atomic acquire**

Implement:

- `FileRunnerStorageOptions`
- `FileRunnerStorage.open`
- `FileRunnerStorage.deinit`
- `FileRunnerStorage.asRunnerStorage`
- `leaseFileName`
- JSON format/parse helpers
- acquire using exclusive file creation
- conflict and expired-lease replacement behavior

Use this concrete public shape:

```zig
pub const runner_lease_schema = "zigeffect.cluster.runner-lease.v1";
pub const runner_lease_schema_version: u32 = 1;

pub const FileRunnerStorageOptions = struct {
    lease_prefix: []const u8 = "runner-shard-",
    lease_suffix: []const u8 = ".json",
    max_lease_file_bytes: usize = 64 * 1024,
};

pub const FileRunnerStorage = struct {
    allocator: Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    options: FileRunnerStorageOptions,

    pub fn open(allocator: Allocator, dir: std.fs.Dir, options: FileRunnerStorageOptions) !FileRunnerStorage
    pub fn deinit(self: *FileRunnerStorage) void
    pub fn asRunnerStorage(self: *FileRunnerStorage) RunnerStorage
};
```

`acquire` must first try `dir.createFile(..., .{ .exclusive = true })`; when
the file already exists, it must parse the current lease, return
`LeaseConflict` if it is still active, or delete and retry exclusive creation
if it is expired.

- [ ] **Step 4: Run green tests and hygiene checks**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/runner_storage.zig packages/zigeffect/test/runner_storage_test.zig
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 5: Commit file-backed atomic acquire**

```bash
git add packages/zigeffect/src/cluster/runner_storage.zig packages/zigeffect/test/runner_storage_test.zig
git commit -m "feat(zigeffect): add file runner lease acquire"
```

## Task 4: File-Backed Refresh Release And Release-All

**Files:**
- Modify: `packages/zigeffect/test/runner_storage_test.zig`
- Modify: `packages/zigeffect/src/cluster/runner_storage.zig`

- [ ] **Step 1: Add failing file-backed refresh and release tests**

Append these tests to `packages/zigeffect/test/runner_storage_test.zig`:

```zig
test "file runner storage refresh persists across reopen" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const owner = fx.runnerAddress("machine-a", "runner-a");
    {
        var storage = try fx.FileRunnerStorage.open(std.testing.allocator, tmp.dir, .{});
        defer storage.deinit();
        var contract = storage.asRunnerStorage();
        _ = try contract.acquire(.{ .shard_id = 21, .owner = owner, .now_ms = 1_000, .ttl_ms = 100 });
        const refreshed = try contract.refresh(.{ .shard_id = 21, .owner = owner, .now_ms = 1_050, .ttl_ms = 500 });
        try std.testing.expectEqual(@as(u64, 1_550), refreshed.expires_at_ms);
        try std.testing.expectEqual(@as(u64, 2), refreshed.version);
    }

    var reopened = try fx.FileRunnerStorage.open(std.testing.allocator, tmp.dir, .{});
    defer reopened.deinit();
    var reopened_contract = reopened.asRunnerStorage();
    const found = (try reopened_contract.lease(21)).?;
    try std.testing.expectEqual(@as(u64, 1_550), found.expires_at_ms);
    try std.testing.expectEqual(@as(u64, 2), found.version);
}

test "file runner storage validates refresh and release ownership" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var storage = try fx.FileRunnerStorage.open(std.testing.allocator, tmp.dir, .{});
    defer storage.deinit();
    var contract = storage.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");
    const intruder = fx.runnerAddress("machine-b", "runner-b");
    _ = try contract.acquire(.{ .shard_id = 22, .owner = owner, .now_ms = 100, .ttl_ms = 50 });

    try std.testing.expectError(error.LeaseNotOwned, contract.refresh(.{
        .shard_id = 22,
        .owner = intruder,
        .now_ms = 125,
        .ttl_ms = 50,
    }));
    try std.testing.expectError(error.LeaseExpired, contract.refresh(.{
        .shard_id = 22,
        .owner = owner,
        .now_ms = 150,
        .ttl_ms = 50,
    }));
    try std.testing.expectError(error.LeaseNotOwned, contract.release(.{ .shard_id = 22, .owner = intruder }));
    try contract.release(.{ .shard_id = 22, .owner = owner });
    try std.testing.expectEqual(@as(?fx.ShardLease, null), try contract.lease(22));
}

test "file runner storage release-all removes only owner leases and lists current leases" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var storage = try fx.FileRunnerStorage.open(std.testing.allocator, tmp.dir, .{});
    defer storage.deinit();
    var contract = storage.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");
    const other = fx.runnerAddress("machine-b", "runner-b");
    _ = try contract.acquire(.{ .shard_id = 31, .owner = owner, .now_ms = 0, .ttl_ms = 100 });
    _ = try contract.acquire(.{ .shard_id = 32, .owner = owner, .now_ms = 0, .ttl_ms = 100 });
    _ = try contract.acquire(.{ .shard_id = 33, .owner = other, .now_ms = 0, .ttl_ms = 100 });

    var before = try contract.leases(std.testing.allocator);
    defer before.deinit();
    try std.testing.expectEqual(@as(usize, 3), before.leases.len);

    const released = try contract.releaseAll(owner);
    try std.testing.expectEqual(@as(usize, 2), released);

    var after = try contract.leases(std.testing.allocator);
    defer after.deinit();
    try std.testing.expectEqual(@as(usize, 1), after.leases.len);
    try std.testing.expect(after.leases[0].owner.eql(other));
}
```

- [ ] **Step 2: Run the red file refresh/release tests**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL on missing or incomplete file refresh/release/list behavior.

- [ ] **Step 3: Implement file-backed refresh, release, release-all, and list**

Implement:

- atomic JSON replacement for refresh
- owner and expiration validation
- delete-file release
- directory iteration for `releaseAll` and `leases`
- `lease` lookup returning `null` when absent
- `reset` deleting all lease files with the configured prefix and suffix

Use `dir.createFileAtomic(..., .{ .replace = true })` for refresh writes, and
use `dir.iterate()` plus prefix/suffix checks for `releaseAll`, `leases`, and
`reset`. File-backed operations must read the authoritative JSON file each time
so two `FileRunnerStorage` instances in the same process observe one another.

- [ ] **Step 4: Run green tests and hygiene checks**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/runner_storage.zig packages/zigeffect/test/runner_storage_test.zig
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 5: Commit file-backed refresh and release**

```bash
git add packages/zigeffect/src/cluster/runner_storage.zig packages/zigeffect/test/runner_storage_test.zig
git commit -m "feat(zigeffect): refresh and release file runner leases"
```

## Task 5: Documentation, Roadmap, And Verification

**Files:**
- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Modify: `docs/superpowers/plans/2026-06-09-zigeffect-runner-storage.md`

- [ ] **Step 1: Update architecture docs**

Add this bullet in the `src/cluster/` section:

```markdown
- `runner_storage.zig`: runner storage contract, shard lease metadata,
  in-memory lease table, file-backed per-shard lease files, and local atomic
  acquire/refresh/release operations.
```

- [ ] **Step 2: Mark Milestone 29 complete in the roadmap**

Change every Milestone 29 deliverable and acceptance checkbox from `[ ]` to
`[x]`.

- [ ] **Step 3: Run the full Milestone 29 verification gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
zig fmt --check packages/zigeffect/src/cluster/runner_storage.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/runner_storage_test.zig packages/zigeffect/test/all_test.zig
git diff --check
rg -n 'TO''DO|TB''D|implement'' later|fill'' in' packages/zigeffect/src/cluster packages/zigeffect/test/runner_storage_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/specs/2026-06-09-zigeffect-runner-storage-design.md docs/superpowers/plans/2026-06-09-zigeffect-runner-storage.md
```

Expected: the build/test/format/diff commands exit 0. The `rg` placeholder scan
exits 1 with no matches.

- [ ] **Step 4: Commit docs and roadmap**

```bash
git add packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/plans/2026-06-09-zigeffect-runner-storage.md
git commit -m "docs(zigeffect): mark runner storage complete"
```
