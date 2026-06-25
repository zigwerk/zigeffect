# zigeffect-std Streams Queues PubSub Sinks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add M5 std-level streaming primitives for local IO and agent feeds:
`zstd.Stream`, `zstd.Sink`, `zstd.Queue`, and `zstd.PubSub`.

**Architecture:** Wrap the real engine primitives instead of creating a parallel
runtime. `zstd.Stream` re-exports engine pull streams and adds line/JSONL
helpers. `zstd.Queue` wraps `fx.Queue(T)` in a service with effect-native
offer/take/shutdown/stats operations. `zstd.PubSub` wraps `fx.Hub(T)` with
effect-native subscribe/publish/take operations. `zstd.Sink` provides a
deterministic memory line sink for local tools and process output. All effect
operations declare service requirements and record causal facts through
`zstd.Service.recordOperation`, including success, empty/closed, backpressure,
drop/failure, and shutdown/close states.

**Tech Stack:** Zig 0.16, engine `Stream`, `Queue`, `Hub`, `zstd.Service`,
existing `Jsonl` line parsing, `bun run zigeffect:std:test`.

---

## File Structure

- Create `packages/zigeffect-std/src/stream/root.zig`: engine stream facade,
  line splitting, JSONL line stream helpers, and collection effects.
- Create `packages/zigeffect-std/src/sink/root.zig`: deterministic memory line
  sink and effect-native write/close/snapshot operations.
- Create `packages/zigeffect-std/src/queue/root.zig`: service-backed queue
  wrapper and offer/take/shutdown/stats effects.
- Create `packages/zigeffect-std/src/pubsub/root.zig`: service-backed hub wrapper
  and subscribe/publish/take/unsubscribe effects.
- Modify `packages/zigeffect-std/src/root.zig`: export the four namespaces.
- Modify `packages/zigeffect-std/README.md`: document the M5 namespaces.
- Modify `packages/zigeffect/docs/roadmap.md`: update std-library status.

## Task 1: Stream And Sink Helpers

- [ ] **Step 1: Write failing tests**

Add tests:

```zig
test "Stream re-exports engine stream composition and collects values" {}
test "Stream splits complete lines and retains trailing partial line" {}
test "Sink memory line sink writes snapshots and redacts JSONL receipts" {}
test "Sink writeLineEffect records causal facts" {}
```

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because the new namespaces are missing.

- [ ] **Step 2: Implement Stream/Sink APIs**

Implement:

```zig
pub const EngineStream = fx.Stream;
pub const fromSlice = fx.streamFromSlice;
pub fn splitLinesAlloc(...) !Jsonl.ParsedLines;
pub fn collectAlloc(stream: anytype, allocator: std.mem.Allocator) ![]@TypeOf(stream).ItemType;

pub const LineSink = struct { ... };
pub fn writeLineEffect(comptime EffectEnv: type, line: []const u8) WriteLineEffect(EffectEnv);
```

`LineSink` snapshots and JSONL receipts must redact secret-shaped text.

- [ ] **Step 3: Verify**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: tests pass.

## Task 2: Queue Service Effects

- [ ] **Step 1: Write failing tests**

Add tests:

```zig
test "Queue service offer take stats and shutdown are effect-native" {}
test "Queue offerEffect records backpressure when bounded queue is full" {}
```

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because `Queue.Service` and effects are missing.

- [ ] **Step 2: Implement Queue APIs**

Implement:

```zig
pub fn Service(comptime Item: type) type;
pub fn offerEffect(comptime EffectEnv: type, comptime Item: type, item: Item) OfferEffect(EffectEnv, Item);
pub fn takeEffect(comptime EffectEnv: type, comptime Item: type) TakeEffect(EffectEnv, Item);
pub fn statsEffect(comptime EffectEnv: type, comptime Item: type) StatsEffect(EffectEnv, Item);
pub fn shutdownEffect(comptime EffectEnv: type, comptime Item: type) ShutdownEffect(EffectEnv, Item);
```

Effects must declare `RequiredServices = .{Service(Item)}` and record causal
facts for item, empty, backpressure, shutdown, and success states.

- [ ] **Step 3: Verify**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: tests pass.

## Task 3: PubSub Service Effects

- [ ] **Step 1: Write failing tests**

Add tests:

```zig
test "PubSub service broadcasts to multiple subscribers through effects" {}
test "PubSub publishEffect records backpressure for bounded subscribers" {}
```

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because `PubSub.Service` and effects are missing.

- [ ] **Step 2: Implement PubSub APIs**

Implement:

```zig
pub fn Service(comptime Item: type) type;
pub fn subscribeEffect(comptime EffectEnv: type, comptime Item: type) SubscribeEffect(EffectEnv, Item);
pub fn publishEffect(comptime EffectEnv: type, comptime Item: type, item: Item) PublishEffect(EffectEnv, Item);
pub fn takeEffect(comptime EffectEnv: type, comptime Item: type, id: fx.SubscriptionId) TakeEffect(EffectEnv, Item);
pub fn unsubscribeEffect(comptime EffectEnv: type, comptime Item: type, id: fx.SubscriptionId) UnsubscribeEffect(EffectEnv, Item);
```

Effects must wrap `fx.Hub(Item)` and record publish/receive/drop/backpressure
facts.

- [ ] **Step 3: Verify**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: tests pass.

## Task 4: Docs And Gate

- [ ] **Step 1: Update exports and docs**

Export `Stream`, `Sink`, `Queue`, and `PubSub` from `zstd`, update README, and
update roadmap status.

- [ ] **Step 2: Mark checkboxes complete**

Replace completed `- [ ]` with `- [x]`.

- [ ] **Step 3: Final verification**

Run:

```sh
bun run zigeffect:std:test
bun run zigeffect:local-agent-gate
git diff --check
```

Expected: all commands exit 0.
