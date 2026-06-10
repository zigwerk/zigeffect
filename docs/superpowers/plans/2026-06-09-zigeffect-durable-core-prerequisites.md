# zigeffect Durable Core Prerequisites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the minimal core contracts durable workflows and clustering need before workflow behavior lands.

**Architecture:** Keep workflow and cluster behavior out of deep core. Add a generic codec trait, deterministic id service, runtime suspension/cancellation vocabulary, expanded backend capability labels, and causal extension domain names. Export all new contracts through `src/zigeffect.zig` and cover them with focused tests.

**Tech Stack:** Zig 0.16, `zig build test`, Bun workspace scripts, existing `zigeffect` facade/domain/test structure.

---

## File Structure

- Create `packages/zigeffect/src/traits/codec.zig`
  - Owns `Codec(Value)` and `CodecError`.
- Modify `packages/zigeffect/src/traits/root.zig`
  - Exposes `Codec` and `CodecError`.
- Create `packages/zigeffect/src/services/id_generator.zig`
  - Owns deterministic monotonic `IdGenerator`.
- Modify `packages/zigeffect/src/testing/test_env.zig`
  - Adds `IdGenerator` to `TestServices`.
- Create `packages/zigeffect/src/runtime/control.zig`
  - Owns `SuspensionKind`, `Suspension`, `RuntimeDecision`, and `Cancellation`.
- Modify `packages/zigeffect/src/runtime/backend.zig`
  - Expands backend kind/capability constructors.
- Modify `packages/zigeffect/src/services/causal.zig`
  - Adds causal extension domain names.
- Modify `packages/zigeffect/src/zigeffect.zig`
  - Exposes new domain and root aliases.
- Modify `packages/zigeffect/test/traits_test.zig`
  - Adds codec behavior tests.
- Modify `packages/zigeffect/test/services_test.zig`
  - Adds id generator and causal extension tests.
- Modify `packages/zigeffect/test/runtime_test.zig`
  - Adds suspension/cancellation tests.
- Modify `packages/zigeffect/test/architecture_test.zig`
  - Adds facade/backend capability export tests.
- Modify `packages/zigeffect/docs/architecture.md`
  - Documents the new files and ownership boundaries.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Marks Milestone 0.5 complete after verification.

## Task 1: Codec Contract

**Files:**
- Create: `packages/zigeffect/src/traits/codec.zig`
- Modify: `packages/zigeffect/src/traits/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/traits_test.zig`
- Modify: `packages/zigeffect/test/architecture_test.zig`

- [ ] **Step 1: Write failing codec tests**

Add tests that define a local `u64` codec and prove facade exposure:

```zig
test "codec encodes and decodes values through allocator explicit callbacks" {
    const U64Codec = fx.Codec(u64);
    const codec = U64Codec{
        .encode = struct {
            fn run(allocator: std.mem.Allocator, value: u64) anyerror![]const u8 {
                return std.fmt.allocPrint(allocator, "{d}", .{value});
            }
        }.run,
        .decode = struct {
            fn run(_: std.mem.Allocator, bytes: []const u8) anyerror!u64 {
                return std.fmt.parseInt(u64, bytes, 10);
            }
        }.run,
    };

    const encoded = try codec.encodeValue(std.testing.allocator, 42);
    defer std.testing.allocator.free(encoded);

    try std.testing.expectEqualStrings("42", encoded);
    try std.testing.expectEqual(@as(u64, 42), try codec.decodeValue(std.testing.allocator, encoded));
}

test "codec preserves decode errors" {
    const codec = fx.Codec(u64){
        .encode = struct {
            fn run(allocator: std.mem.Allocator, value: u64) anyerror![]const u8 {
                return std.fmt.allocPrint(allocator, "{d}", .{value});
            }
        }.run,
        .decode = struct {
            fn run(_: std.mem.Allocator, bytes: []const u8) anyerror!u64 {
                return std.fmt.parseInt(u64, bytes, 10);
            }
        }.run,
    };

    try std.testing.expectError(error.InvalidCharacter, codec.decodeValue(std.testing.allocator, "not-a-number"));
}
```

Add an architecture assertion:

```zig
try std.testing.expect(fx.Codec(u8) == fx.traits.Codec(u8));
```

- [ ] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL because `fx.Codec` and `fx.traits.Codec` do not exist.

- [ ] **Step 3: Implement codec contract**

Create `src/traits/codec.zig`:

```zig
const std = @import("std");

pub const CodecError = error{
    InvalidEncoding,
    UnsupportedCodec,
};

pub fn Codec(comptime Value: type) type {
    return struct {
        const Self = @This();

        encode: *const fn (std.mem.Allocator, Value) anyerror![]const u8,
        decode: *const fn (std.mem.Allocator, []const u8) anyerror!Value,

        pub fn encodeValue(self: Self, allocator: std.mem.Allocator, value: Value) anyerror![]const u8 {
            return self.encode(allocator, value);
        }

        pub fn decodeValue(self: Self, allocator: std.mem.Allocator, bytes: []const u8) anyerror!Value {
            return self.decode(allocator, bytes);
        }
    };
}
```

Expose it in `traits/root.zig` and `zigeffect.zig`.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/traits/codec.zig packages/zigeffect/src/traits/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/traits_test.zig packages/zigeffect/test/architecture_test.zig
git commit -m "feat(zigeffect): add codec trait"
```

## Task 2: IdGenerator Service

**Files:**
- Create: `packages/zigeffect/src/services/id_generator.zig`
- Modify: `packages/zigeffect/src/testing/test_env.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/services_test.zig`
- Modify: `packages/zigeffect/test/architecture_test.zig`

- [ ] **Step 1: Write failing id generator tests**

Add service tests:

```zig
test "id generator produces deterministic monotonic ids" {
    var ids = fx.IdGenerator.init(10);

    try std.testing.expectEqual(@as(u64, 10), ids.peek());
    try std.testing.expectEqual(@as(u64, 10), ids.next());
    try std.testing.expectEqual(@as(u64, 11), ids.next());
    ids.reset(99);
    try std.testing.expectEqual(@as(u64, 99), ids.next());
}

test "test environment exposes id generator service through context" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    const ids = ctx.service(fx.IdGenerator);

    try std.testing.expectEqual(@as(u64, 1), ids.next());
    try std.testing.expectEqual(@as(u64, 2), ids.next());
}
```

Add architecture assertions for `fx.IdGenerator == fx.services.IdGenerator`.

- [ ] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL because `IdGenerator` is not defined or exposed.

- [ ] **Step 3: Implement id generator**

Create `src/services/id_generator.zig`:

```zig
pub const IdGenerator = struct {
    next_value: u64 = 1,

    pub fn init(start: u64) IdGenerator {
        return .{ .next_value = start };
    }

    pub fn peek(self: *const IdGenerator) u64 {
        return self.next_value;
    }

    pub fn next(self: *IdGenerator) u64 {
        const value = self.next_value;
        self.next_value += 1;
        return value;
    }

    pub fn reset(self: *IdGenerator, start: u64) void {
        self.next_value = start;
    }
};
```

Import it in `test_env.zig`, add `id_generator: IdGenerator` to
`TestServices`, initialize it with `IdGenerator.init(1)`, and return it from
`service()`. Expose it in `zigeffect.zig`.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/services/id_generator.zig packages/zigeffect/src/testing/test_env.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/services_test.zig packages/zigeffect/test/architecture_test.zig
git commit -m "feat(zigeffect): add deterministic id generator service"
```

## Task 3: Runtime Control And Backend Capabilities

**Files:**
- Create: `packages/zigeffect/src/runtime/control.zig`
- Modify: `packages/zigeffect/src/runtime/backend.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/runtime_test.zig`
- Modify: `packages/zigeffect/test/architecture_test.zig`

- [ ] **Step 1: Write failing runtime control tests**

Add runtime tests:

```zig
test "runtime suspension names durable wait boundary" {
    const suspension = fx.Suspension{
        .kind = .timer,
        .id = 42,
        .label = "wake-up",
    };
    const decision = fx.RuntimeDecision{ .suspended = suspension };

    switch (decision) {
        .suspended => |value| {
            try std.testing.expectEqual(fx.SuspensionKind.timer, value.kind);
            try std.testing.expectEqual(@as(u64, 42), value.id);
            try std.testing.expectEqualStrings("wake-up", value.label);
        },
        else => return error.Empty,
    }
}

test "cancellation is cooperative and reason preserving" {
    var cancellation = fx.Cancellation.init();
    try std.testing.expect(!cancellation.isRequested());
    try std.testing.expect(cancellation.reason() == null);

    cancellation.request("workflow interrupted");

    try std.testing.expect(cancellation.isRequested());
    try std.testing.expectEqualStrings("workflow interrupted", cancellation.reason().?);
}
```

Extend backend architecture tests:

```zig
const durable = fx.durableLocalBackend();
try std.testing.expectEqual(fx.BackendKind.durable_local, durable.kind);
try std.testing.expect(durable.can_suspend);
try std.testing.expect(durable.can_persist);
try std.testing.expect(!durable.can_distribute);

const async_backend = fx.asyncLocalBackend();
try std.testing.expectEqual(fx.BackendKind.async_local, async_backend.kind);
try std.testing.expect(async_backend.can_suspend);
try std.testing.expect(async_backend.can_interrupt_blocking_io);
try std.testing.expect(async_backend.can_parallel);

const clustered = fx.clusteredBackend();
try std.testing.expectEqual(fx.BackendKind.clustered, clustered.kind);
try std.testing.expect(clustered.can_suspend);
try std.testing.expect(clustered.can_persist);
try std.testing.expect(clustered.can_distribute);
```

- [ ] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL because runtime control types and backend constructors do not
exist.

- [ ] **Step 3: Implement runtime control and capabilities**

Create `src/runtime/control.zig`:

```zig
pub const SuspensionKind = enum {
    timer,
    deferred,
    queue,
    signal,
    activity,
    external,
};

pub const Suspension = struct {
    kind: SuspensionKind,
    id: u64,
    label: []const u8 = "",
};

pub const RuntimeDecision = union(enum) {
    completed,
    suspended: Suspension,
    cancelled: []const u8,
};

pub const Cancellation = struct {
    requested: bool = false,
    reason_value: ?[]const u8 = null,

    pub fn init() Cancellation {
        return .{};
    }

    pub fn request(self: *Cancellation, reason_text: []const u8) void {
        self.requested = true;
        self.reason_value = reason_text;
    }

    pub fn isRequested(self: *const Cancellation) bool {
        return self.requested;
    }

    pub fn reason(self: *const Cancellation) ?[]const u8 {
        return self.reason_value;
    }
};
```

Expand `BackendKind`, add `can_persist` and `can_distribute`, and add
constructors for durable-local, async-local, and clustered backends.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/runtime/control.zig packages/zigeffect/src/runtime/backend.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/runtime_test.zig packages/zigeffect/test/architecture_test.zig
git commit -m "feat(zigeffect): add durable runtime control vocabulary"
```

## Task 4: Causal Extension Domains And Docs

**Files:**
- Modify: `packages/zigeffect/src/services/causal.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/services_test.zig`
- Modify: `packages/zigeffect/test/architecture_test.zig`
- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

- [ ] **Step 1: Write failing causal extension tests**

Add service tests:

```zig
test "causal extension domains reserve workflow and cluster names" {
    try std.testing.expectEqualStrings("workflow", fx.causalExtensionDomainName(.workflow));
    try std.testing.expectEqualStrings("cluster", fx.causalExtensionDomainName(.cluster));
}
```

Add architecture assertion:

```zig
try std.testing.expect(fx.CausalExtensionDomain == fx.services.CausalExtensionDomain);
```

- [ ] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL because extension domain names are not exposed.

- [ ] **Step 3: Implement causal extension domains**

Add to `services/causal.zig`:

```zig
pub const CausalExtensionDomain = enum {
    workflow,
    cluster,
};

pub fn causalExtensionDomainName(domain: CausalExtensionDomain) []const u8 {
    return switch (domain) {
        .workflow => "workflow",
        .cluster => "cluster",
    };
}
```

Expose through `services` and root facade. Update architecture docs so
`src/traits/codec.zig`, `src/services/id_generator.zig`, and
`src/runtime/control.zig` have clear ownership notes. Mark Milestone 0.5
deliverables and acceptance as complete in the roadmap after verification.

- [ ] **Step 4: Verify green and full baseline**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
```

Expected: all commands PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/services/causal.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/services_test.zig packages/zigeffect/test/architecture_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/specs/2026-06-09-zigeffect-durable-core-prerequisites-design.md docs/superpowers/plans/2026-06-09-zigeffect-durable-core-prerequisites.md
git commit -m "docs(zigeffect): plan durable core prerequisites"
```

## Self-Review Checklist

- [ ] Every requirement in `2026-06-09-zigeffect-durable-core-prerequisites-design.md` maps to a task.
- [ ] No workflow engine, journal store, actor runtime, async backend, or cluster behavior is implemented in this milestone.
- [ ] Existing deterministic backend behavior remains unchanged.
- [ ] Public aliases exist at both root and domain namespace where the design requires them.
- [ ] `bun run zigeffect:test`, `zig build examples`, and `bun run zig:test` pass before marking Milestone 0.5 complete.
