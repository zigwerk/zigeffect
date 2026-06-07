# zigeffect Data And Pattern Matching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the full `zigeffect` data, trait, tagged matching, and structural pattern matching roadmap from `docs/superpowers/specs/2026-06-07-zigeffect-data-pattern-matching-design.md`.

**Architecture:** Add four focused public domains behind the existing facade: `fx.traits`, `fx.data`, `fx.match`, and `fx.pattern`. Keep Zig's native `union(enum)` as the canonical ADT representation, layer ergonomic match helpers on top of it, and keep allocation explicit for owned data structures.

**Tech Stack:** Zig 0.16, Bun workspace scripts, `zig build test`, `bun run zigeffect:test`, `bun run zig:test`, existing `packages/zigeffect` facade and test harness.

---

## File Structure

- Create `packages/zigeffect/src/traits/root.zig`: exports trait modules.
- Create `packages/zigeffect/src/traits/equal.zig`: generic equality derivation.
- Create `packages/zigeffect/src/traits/hash.zig`: stable hash derivation.
- Create `packages/zigeffect/src/traits/order.zig`: ordering helpers.
- Create `packages/zigeffect/src/traits/show.zig`: writer and allocator formatting.
- Create `packages/zigeffect/src/traits/redaction.zig`: redaction marker and redaction-safe formatting helpers.
- Create `packages/zigeffect/src/data/root.zig`: exports data modules.
- Create `packages/zigeffect/src/data/option.zig`: `Option(T)`.
- Create `packages/zigeffect/src/data/either.zig`: `Either(Right, Left)`.
- Create `packages/zigeffect/src/data/duration.zig`: finite/infinite duration.
- Create `packages/zigeffect/src/data/redacted.zig`: redacted wrapper.
- Create `packages/zigeffect/src/data/data.zig`: tagged-data metadata helpers.
- Create `packages/zigeffect/src/data/chunk.zig`: owned sequence wrapper.
- Create `packages/zigeffect/src/data/hash_set.zig`: trait-backed set.
- Create `packages/zigeffect/src/data/datetime.zig`: UTC-first date-time.
- Create `packages/zigeffect/src/data/big_decimal.zig`: arbitrary-precision decimal boundary.
- Create `packages/zigeffect/src/match/root.zig`: exports tagged matcher APIs.
- Create `packages/zigeffect/src/match/tagged.zig`: exhaustive/partial tagged union matcher.
- Create `packages/zigeffect/src/match/handlers.zig`: handler validation and invocation helpers.
- Create `packages/zigeffect/src/match/diagnostics.zig`: compile diagnostic text builders.
- Create `packages/zigeffect/src/pattern/root.zig`: exports structural matcher APIs.
- Create `packages/zigeffect/src/pattern/matcher.zig`: public pattern constructors.
- Create `packages/zigeffect/src/pattern/captures.zig`: capture struct derivation.
- Create `packages/zigeffect/src/pattern/structural.zig`: recursive structural matching.
- Create `packages/zigeffect/src/pattern/predicates.zig`: range and predicate matchers.
- Create `packages/zigeffect/src/pattern/diagnostics.zig`: structural diagnostic text builders.
- Modify `packages/zigeffect/src/core/result.zig`: add Cause/Exit match and conversion helpers.
- Modify `packages/zigeffect/src/zigeffect.zig`: export new namespaces and top-level aliases.
- Modify `packages/zigeffect/test/all_test.zig`: import new test files.
- Modify `packages/zigeffect/test/architecture_test.zig`: assert facade exports.
- Create `packages/zigeffect/test/traits_test.zig`: trait behavior tests.
- Create `packages/zigeffect/test/data_test.zig`: data type tests.
- Create `packages/zigeffect/test/match_test.zig`: tagged matcher tests.
- Create `packages/zigeffect/test/pattern_test.zig`: structural matcher tests.
- Create compile-fail fixtures under `packages/zigeffect/test/compile_fail/` for matcher diagnostics.
- Create `packages/zigeffect/docs/data.md`: user docs for data types.
- Create `packages/zigeffect/docs/pattern-matching.md`: user docs for tagged and structural matching.
- Modify `packages/zigeffect/README.md`: link docs and summarize new APIs.
- Modify `packages/zigeffect/docs/architecture.md`: add new domains and roadmap landing zones.

## Task 1: Facade Skeleton And Architecture Tests

**Files:**
- Modify: `packages/zigeffect/test/all_test.zig`
- Modify: `packages/zigeffect/test/architecture_test.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Create: `packages/zigeffect/src/traits/root.zig`
- Create: `packages/zigeffect/src/data/root.zig`
- Create: `packages/zigeffect/src/match/root.zig`
- Create: `packages/zigeffect/src/pattern/root.zig`

- [x] **Step 1: Write failing facade tests**

Add to `packages/zigeffect/test/all_test.zig`:

```zig
    _ = @import("traits_test.zig");
    _ = @import("data_test.zig");
    _ = @import("match_test.zig");
    _ = @import("pattern_test.zig");
```

Add to `packages/zigeffect/test/architecture_test.zig`:

```zig
test "root facade exposes data match pattern and trait namespaces" {
    try std.testing.expect(fx.Option(u8) == fx.data.Option(u8));
    try std.testing.expect(fx.Either(u8, error{Bad}) == fx.data.Either(u8, error{Bad}));
    try std.testing.expect(fx.Duration == fx.data.Duration);
    try std.testing.expect(fx.BigDecimal == fx.data.BigDecimal);
    try std.testing.expect(fx.DateTime == fx.data.DateTime);
    try std.testing.expect(fx.Redacted([]const u8) == fx.data.Redacted([]const u8));
    try std.testing.expect(@hasDecl(fx, "traits"));
    try std.testing.expect(@hasDecl(fx, "match"));
    try std.testing.expect(@hasDecl(fx, "pattern"));
}
```

- [x] **Step 2: Run failing test**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: FAIL because the new test files and facade namespaces do not exist.

- [x] **Step 3: Add empty public domains**

Create the four root files with valid empty exports:

```zig
pub const ready = true;
```

Modify `src/zigeffect.zig` to export:

```zig
pub const traits = @import("traits/root.zig");
pub const data = @import("data/root.zig");
pub const match = @import("match/root.zig");
pub const pattern = @import("pattern/root.zig");
```

Add aliases once data skeletons exist:

```zig
pub const Option = data.Option;
pub const Either = data.Either;
pub const Duration = data.Duration;
pub const BigDecimal = data.BigDecimal;
pub const DateTime = data.DateTime;
pub const Redacted = data.Redacted;
pub const Chunk = data.Chunk;
pub const HashSet = data.HashSet;
```

- [x] **Step 4: Run test**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: still FAIL until data skeletons are introduced in later tasks.

## Task 2: Trait Foundation

**Files:**
- Create: `packages/zigeffect/src/traits/equal.zig`
- Create: `packages/zigeffect/src/traits/hash.zig`
- Create: `packages/zigeffect/src/traits/order.zig`
- Create: `packages/zigeffect/src/traits/show.zig`
- Create: `packages/zigeffect/src/traits/redaction.zig`
- Modify: `packages/zigeffect/src/traits/root.zig`
- Create: `packages/zigeffect/test/traits_test.zig`

- [x] **Step 1: Write failing trait tests**

Create `packages/zigeffect/test/traits_test.zig` with tests for:

```zig
const std = @import("std");
const fx = @import("zigeffect");

const Point = struct { x: u8, y: u8 };
const Shape = union(enum) { point: Point, label: []const u8 };

test "Equal compares scalars slices structs and tagged unions" {
    try std.testing.expect(fx.traits.equals(u8, 1, 1));
    try std.testing.expect(!fx.traits.equals(u8, 1, 2));
    try std.testing.expect(fx.traits.equals([]const u8, "same", "same"));
    try std.testing.expect(!fx.traits.equals([]const u8, "same", "diff"));
    try std.testing.expect(fx.traits.equals(Point, .{ .x = 1, .y = 2 }, .{ .x = 1, .y = 2 }));
    try std.testing.expect(!fx.traits.equals(Point, .{ .x = 1, .y = 2 }, .{ .x = 2, .y = 1 }));
    try std.testing.expect(fx.traits.equals(Shape, .{ .point = .{ .x = 1, .y = 2 } }, .{ .point = .{ .x = 1, .y = 2 } }));
    try std.testing.expect(!fx.traits.equals(Shape, .{ .point = .{ .x = 1, .y = 2 } }, .{ .label = "point" }));
}

test "Hash and Order produce stable basic behavior" {
    try std.testing.expectEqual(fx.traits.hash(u8, 42), fx.traits.hash(u8, 42));
    try std.testing.expectEqual(fx.traits.Ordering.less, fx.traits.compare(u8, 1, 2));
    try std.testing.expectEqual(fx.traits.Ordering.equal, fx.traits.compare(u8, 2, 2));
    try std.testing.expectEqual(fx.traits.Ordering.greater, fx.traits.compare(u8, 3, 2));
}
```

- [x] **Step 2: Run failing trait tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: FAIL because `fx.traits.equals`, `hash`, and `compare` do not exist.

- [x] **Step 3: Implement traits**

Implement `equals`, `hash`, `compare`, `format`, and redaction marker exports.

- [x] **Step 4: Run trait tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: PASS for trait tests or actionable compile errors to fix.

## Task 3: Option Either Duration Redacted

**Files:**
- Create: `packages/zigeffect/src/data/option.zig`
- Create: `packages/zigeffect/src/data/either.zig`
- Create: `packages/zigeffect/src/data/duration.zig`
- Create: `packages/zigeffect/src/data/redacted.zig`
- Modify: `packages/zigeffect/src/data/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Create: `packages/zigeffect/test/data_test.zig`

- [x] **Step 1: Write failing foundational data tests**

Create tests that assert:

```zig
test "Option maps flatMaps defaults and matches" {
    const option = fx.Option(u8).some(2);
    try std.testing.expect(option.isSome());
    try std.testing.expectEqual(@as(u8, 3), option.map(u8, addOne).getOrElse(0));
    try std.testing.expectEqual(@as(u8, 4), option.flatMap(u8, doubleSome).getOrElse(0));
    try std.testing.expectEqual(@as(u8, 9), fx.Option(u8).none().getOrElse(9));
}

test "Either is right biased and supports map mapLeft and match" {
    const right = fx.Either(u8, []const u8).right(2);
    const left = fx.Either(u8, []const u8).left("bad");
    try std.testing.expect(right.isRight());
    try std.testing.expect(left.isLeft());
    try std.testing.expectEqual(@as(u8, 3), right.map(u8, addOne).getOrElse(0));
    try std.testing.expectEqualStrings("bad!", left.mapLeft([]const u8, appendBang).left);
}

test "Duration and Redacted expose safe value behavior" {
    const d = fx.Duration.seconds(2).plus(fx.Duration.millis(500));
    try std.testing.expectEqual(@as(i128, 2_500_000_000), d.toNanos().?);
    const secret = fx.Redacted([]const u8).make("token");
    try std.testing.expectEqualStrings("token", secret.unsafeValue());
    try std.testing.expectEqualStrings("[REDACTED]", secret.redactedText());
}
```

- [x] **Step 2: Run failing data tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: FAIL because data types do not exist.

- [x] **Step 3: Implement foundational data types**

Implement `Option`, `Either`, `Duration`, and `Redacted` with tests as the API contract.

- [x] **Step 4: Run data tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: PASS for foundational data tests.

## Task 4: Generic Tagged Matcher And Ergonomic Data Match Methods

**Files:**
- Create: `packages/zigeffect/src/match/tagged.zig`
- Create: `packages/zigeffect/src/match/handlers.zig`
- Create: `packages/zigeffect/src/match/diagnostics.zig`
- Modify: `packages/zigeffect/src/match/root.zig`
- Modify: `packages/zigeffect/src/data/option.zig`
- Modify: `packages/zigeffect/src/data/either.zig`
- Modify: `packages/zigeffect/src/core/result.zig`
- Create: `packages/zigeffect/test/match_test.zig`

- [x] **Step 1: Write failing tagged matcher tests**

Create tests for:

```zig
const Event = union(enum) {
    started,
    progress: u8,
    failed: []const u8,
};

fn onStarted() []const u8 { return "started"; }
fn onProgress(value: u8) []const u8 { return if (value == 7) "seven" else "progress"; }
fn onFailed(message: []const u8) []const u8 { return message; }

test "tagged exhaustive dispatches by union tag" {
    try std.testing.expectEqualStrings("started", fx.match.exhaustive([]const u8, Event.started, .{
        .started = onStarted,
        .progress = onProgress,
        .failed = onFailed,
    }));
    try std.testing.expectEqualStrings("seven", fx.match.exhaustive([]const u8, Event{ .progress = 7 }, .{
        .started = onStarted,
        .progress = onProgress,
        .failed = onFailed,
    }));
}

test "tagged partial and orElse handle missing tags deliberately" {
    try std.testing.expect(fx.match.partial([]const u8, Event.started, .{
        .failed = onFailed,
    }) == null);
    try std.testing.expectEqualStrings("fallback", fx.match.orElse([]const u8, Event.started, .{
        .failed = onFailed,
    }, "fallback"));
}
```

- [x] **Step 2: Run failing tagged matcher tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: FAIL because `fx.match` APIs do not exist.

- [x] **Step 3: Implement tagged matcher**

Implement exhaustive and partial matching with compile-time handler checks.

- [x] **Step 4: Add `Option.match`, `Either.match`, `Cause.match`, and `Exit.match` tests**

Add tests that use type-native match methods and call into the generic matcher.

- [x] **Step 5: Run tagged matcher tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: PASS for tagged matcher tests.

## Task 5: Compile-Fail Matcher Diagnostics

**Files:**
- Create: `packages/zigeffect/test/compile_fail/match_missing_handler.zig`
- Create: `packages/zigeffect/test/compile_fail/match_unknown_handler.zig`
- Create: `packages/zigeffect/test/compile_fail/match_wrong_return.zig`
- Create: `packages/zigeffect/test/compile_fail/match_wrong_payload.zig`
- Modify: `packages/zigeffect/test/layer_test.zig`

- [x] **Step 1: Add compile-fail fixtures**

Each fixture imports `zigeffect`, defines a small `union(enum)`, and calls
`fx.match.exhaustive` with one invalid handler condition.

- [x] **Step 2: Add diagnostic assertions**

Extend `layer_test.zig` compile-fail coverage to assert diagnostic text such as
`zigeffect match exhaustive missing handler` and `zigeffect match handler payload mismatch`.

- [x] **Step 3: Run compile-fail tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: PASS with the invalid fixtures failing in the expected way.

## Task 6: Data Helpers Chunk HashSet DateTime BigDecimal

**Files:**
- Create: `packages/zigeffect/src/data/data.zig`
- Create: `packages/zigeffect/src/data/chunk.zig`
- Create: `packages/zigeffect/src/data/hash_set.zig`
- Create: `packages/zigeffect/src/data/datetime.zig`
- Create: `packages/zigeffect/src/data/big_decimal.zig`
- Modify: `packages/zigeffect/src/data/root.zig`
- Modify: `packages/zigeffect/test/data_test.zig`

- [x] **Step 1: Write failing rich data tests**

Add tests that prove:

- `Data.isTaggedUnion` recognizes `union(enum)` and rejects plain structs.
- `Chunk` copies slices, appends, concatenates, maps, filters, and folds.
- `HashSet` adds unique values, checks membership, removes values, and builds union/intersection/difference.
- `DateTime` parses/formats UTC ISO strings and computes duration distance.
- `BigDecimal` parses and formats values larger than `i128` precision.

- [x] **Step 2: Run failing rich data tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: FAIL because rich data types do not exist.

- [x] **Step 3: Implement rich data types**

Implement the minimum complete APIs described by the tests, keeping allocators explicit for owned types.

- [x] **Step 4: Run rich data tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: PASS for rich data tests.

## Task 7: Structural Pattern Matching Core

**Files:**
- Create: `packages/zigeffect/src/pattern/matcher.zig`
- Create: `packages/zigeffect/src/pattern/captures.zig`
- Create: `packages/zigeffect/src/pattern/structural.zig`
- Create: `packages/zigeffect/src/pattern/predicates.zig`
- Create: `packages/zigeffect/src/pattern/diagnostics.zig`
- Modify: `packages/zigeffect/src/pattern/root.zig`
- Create: `packages/zigeffect/test/pattern_test.zig`

- [x] **Step 1: Write failing structural matcher tests**

Create tests that assert:

```zig
const Profile = struct {
    age: u8,
    name: []const u8,
    pos: struct { x: i32, y: i32 },
};

test "structural matcher supports wildcard ranges nested structs and captures" {
    const profile = Profile{ .age = 34, .name = "Ada", .pos = .{ .x = 10, .y = 20 } };
    try std.testing.expect(fx.pattern.matches(profile, .{
        .age = fx.pattern.range(.inclusive, 18, 65),
        .name = fx.pattern.any,
        .pos = .{ .x = 10, .y = fx.pattern.any },
    }));
    const captures = fx.pattern.capture(profile, .{
        .age = fx.pattern.any,
        .name = fx.pattern.bind("name"),
        .pos = .{ .x = fx.pattern.bind("x"), .y = 20 },
    }).?;
    try std.testing.expectEqualStrings("Ada", captures.name);
    try std.testing.expectEqual(@as(i32, 10), captures.x);
}
```

- [x] **Step 2: Run failing structural matcher tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: FAIL because `fx.pattern` APIs do not exist.

- [x] **Step 3: Implement structural matcher core**

Implement recursive matching and capture derivation for scalars, structs, tagged unions, optionals, arrays, slices, single-item pointers, wildcards, binds, predicates, and ranges.

- [x] **Step 4: Run structural matcher tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: PASS for structural matcher tests.

## Task 8: Structural Arms And Compile-Fail Diagnostics

**Files:**
- Modify: `packages/zigeffect/src/pattern/structural.zig`
- Modify: `packages/zigeffect/src/pattern/diagnostics.zig`
- Modify: `packages/zigeffect/test/pattern_test.zig`
- Create: `packages/zigeffect/test/compile_fail/pattern_duplicate_capture.zig`
- Create: `packages/zigeffect/test/compile_fail/pattern_missing_union_tag.zig`
- Create: `packages/zigeffect/test/compile_fail/pattern_unknown_union_tag.zig`
- Modify: `packages/zigeffect/test/layer_test.zig`

- [ ] **Step 1: Add failing structural arms tests**

Add tests for `fx.pattern.exhaustive` and `fx.pattern.partial` over a tagged union.

- [ ] **Step 2: Add compile-fail fixtures**

Add duplicate capture and invalid union tag fixtures.

- [ ] **Step 3: Implement structural arms and diagnostics**

Validate union coverage for exhaustive structural arms and reject provable duplicate/unknown cases.

- [ ] **Step 4: Run structural diagnostics tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: PASS.

## Task 9: Documentation And Examples

**Files:**
- Create: `packages/zigeffect/docs/data.md`
- Create: `packages/zigeffect/docs/pattern-matching.md`
- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `packages/zigeffect/README.md`
- Create: `packages/zigeffect/examples/data_and_matching.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add docs and example**

Document ownership, APIs, match modes, structural patterns, redaction behavior, and examples.

- [ ] **Step 2: Wire example into build**

Add the example executable/test to `build.zig` following existing example patterns.

- [ ] **Step 3: Run docs/example verification**

Run:

```bash
cd packages/zigeffect && zig build examples
```

Expected: PASS.

## Task 10: Full Verification And Cleanup

**Files:**
- Review all files touched by Tasks 1-9.

- [ ] **Step 1: Run package gate**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

- [ ] **Step 2: Run workspace Zig gate**

Run:

```bash
bun run zig:test
```

Expected: PASS.

- [ ] **Step 3: Run TypeScript gate**

Run:

```bash
bun run typecheck
```

Expected: PASS.

- [ ] **Step 4: Review git diff**

Run:

```bash
git diff --stat
git status --short
```

Expected: only roadmap-related files are modified, plus any unrelated pre-existing user changes left unstaged.

## Self-Review

- Spec coverage: Tasks 1-10 cover facade exports, traits, all data types, existing `Cause`/`Exit` integration, generic tagged matching, structural matching, structural exhaustiveness, compile-fail diagnostics, docs, examples, and verification gates.
- Red-flag scan: this plan contains no incomplete implementation markers or undefined file destinations.
- Type consistency: public namespaces are consistently `fx.traits`, `fx.data`, `fx.match`, and `fx.pattern`; data aliases match the design spec.
