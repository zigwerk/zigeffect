# zigeffect Data And Pattern Matching Design

Date: 2026-06-07

## Goal

Build a comprehensive Zig-native data and pattern-matching foundation for
`zigeffect`, inspired by EffectTS but shaped around Zig's strengths:
`union(enum)`, exhaustive `switch`, comptime reflection, explicit allocators,
typed errors, and direct-style APIs.

The system has four layers:

1. `fx.traits`: typeclass-ish traits for equality, hashing, ordering, display,
   and redaction-safe formatting.
2. `fx.data`: Effect-style data types: `Option`, `Either`, `Data`, `Duration`,
   `DateTime`, `BigDecimal`, `Chunk`, `HashSet`, and `Redacted`, plus
   integration with existing `Cause` and `Exit`.
3. `fx.match`: a generic tagged-union matcher for `union(enum)` ADTs with
   exhaustive and partial modes, return-type validation, tag validation, and
   clear compile-time errors.
4. `fx.pattern`: structural pattern matching with wildcards, captures, nested
   structs, nested union tags, optionals, arrays, slices, ranges, predicates,
   custom matchers, and comptime-supported reachability checks.

## Non-Goals

- Do not replace Zig's native `switch`. `fx.match` and `fx.pattern` are
  ergonomic and compositional helpers for data-heavy code, tests, diagnostics,
  and generic libraries.
- Do not clone EffectTS API-for-API. Preserve Effect-style semantics where they
  fit, but prefer Zig naming, allocators, explicit ownership, and compile-time
  diagnostics.
- Do not add a third-party pattern matching dependency. `zkinder` is prior art
  and inspiration, not a dependency.
- Do not rewrite existing `Cause`, `Exit`, or runtime internals just to use the
  matcher. Existing direct `switch` code remains valid when it is clearer.

## Current Context

`zigeffect` already exposes a public facade through
`packages/zigeffect/src/zigeffect.zig` and organizes implementation domains
under `src/core`, `src/effect`, `src/runtime`, `src/layer`, `src/services`, and
`src/testing`.

Existing result types already have the right ADT shape:

- `Cause(Failure)` is a `union(enum)` with failure, defect, interruption,
  finalizer failure, sequential, parallel, and annotated variants.
- `Exit(Success, Failure)` is a `union(enum)` with success, typed failure,
  defect, interruption, and cause variants.
- `FinalizerExit` is a compact `union(enum)` used by scoped cleanup.

The package currently relies on native exhaustive `switch`. The new design
keeps that foundation and adds reusable helpers around it.

## Architecture

### Public Facade

Add these namespaces to `src/zigeffect.zig`:

```zig
pub const traits = @import("traits/root.zig");
pub const data = @import("data/root.zig");
pub const match = @import("match/root.zig");
pub const pattern = @import("pattern/root.zig");
```

Top-level aliases should expose the common types:

```zig
pub const Option = data.Option;
pub const Either = data.Either;
pub const Duration = data.Duration;
pub const DateTime = data.DateTime;
pub const BigDecimal = data.BigDecimal;
pub const Chunk = data.Chunk;
pub const HashSet = data.HashSet;
pub const Redacted = data.Redacted;
```

### Source Domains

Create focused files:

```text
packages/zigeffect/src/traits/
  root.zig
  equal.zig
  hash.zig
  order.zig
  show.zig
  redaction.zig

packages/zigeffect/src/data/
  root.zig
  option.zig
  either.zig
  data.zig
  duration.zig
  datetime.zig
  big_decimal.zig
  chunk.zig
  hash_set.zig
  redacted.zig

packages/zigeffect/src/match/
  root.zig
  tagged.zig
  handlers.zig
  diagnostics.zig

packages/zigeffect/src/pattern/
  root.zig
  matcher.zig
  captures.zig
  structural.zig
  predicates.zig
  diagnostics.zig
```

Tests live in:

```text
packages/zigeffect/test/traits_test.zig
packages/zigeffect/test/data_test.zig
packages/zigeffect/test/match_test.zig
packages/zigeffect/test/pattern_test.zig
packages/zigeffect/test/compile_fail/
```

## Layer 1: Traits

Traits are small comptime contracts, not runtime interfaces.

### Equal

`Equal(T)` provides equality for values that cannot rely on `==`, or where
semantic equality differs from byte equality.

Planned API:

```zig
pub fn equals(comptime T: type, lhs: T, rhs: T) bool;
pub fn Equal(comptime T: type) type;
```

Default behavior:

- Scalars and enums use `==`.
- Slices compare by element equality.
- Structs compare fields when every field has equality.
- Unions compare active tag and payload equality.
- Types may provide `pub fn equals(lhs: Self, rhs: Self) bool`.

### Hash

`Hash(T)` supports `HashSet` and hashed structural data.

Planned API:

```zig
pub fn hash(comptime T: type, value: T) u64;
pub fn Hash(comptime T: type) type;
```

Default behavior:

- Scalars use stable numeric hashing.
- Slices hash length and elements.
- Structs hash field names and values in declaration order.
- Tagged unions hash active tag and payload.
- Types may provide `pub fn hash(self: Self) u64`.

### Order

`Order(T)` supports `BigDecimal`, `Duration`, `DateTime`, sorted diagnostics,
and pattern ranges.

Planned API:

```zig
pub const Ordering = enum { less, equal, greater };
pub fn compare(comptime T: type, lhs: T, rhs: T) Ordering;
```

### Show And Redaction

`Show(T)` formats values into allocator-owned strings or writers. Redaction
rules ensure secret-bearing data cannot accidentally leak into diagnostics.

`Redacted(T)` must format as a redaction marker unless the caller explicitly
uses an unsafe extraction function.

## Layer 2: Data Types

### Option

`Option(T)` is a `union(enum)`:

```zig
pub fn Option(comptime T: type) type {
    return union(enum) {
        none,
        some: T,
    };
}
```

Planned methods:

- `some(value)`
- `none()`
- `isSome`
- `isNone`
- `map`
- `flatMap`
- `getOrElse`
- `toEither`
- `match`

`Option.match` calls `fx.match.exhaustive` when possible.

### Either

`Either(Right, Left)` is a right-biased `union(enum)`:

```zig
pub fn Either(comptime Right: type, comptime Left: type) type {
    return union(enum) {
        left: Left,
        right: Right,
    };
}
```

Planned methods:

- `right(value)`
- `left(error_value)`
- `isRight`
- `isLeft`
- `map`
- `mapLeft`
- `flatMap`
- `getOrElse`
- `match`

### Duration

`Duration` represents finite nanoseconds or infinity:

```zig
pub const Duration = union(enum) {
    finite: i128,
    infinity,
};
```

Planned constructors:

- `nanos`
- `micros`
- `millis`
- `seconds`
- `minutes`
- `hours`
- `days`
- `weeks`
- `infinity`

Planned operations:

- `plus`
- `minus`
- `times`
- `compare`
- `isFinite`
- `isInfinity`
- checked conversion to integer units

Schedule code can migrate to this type after the data module is stable.

### Redacted

`Redacted(T)` stores sensitive values and participates in equality/hash without
printing the underlying value.

Planned API:

- `make(value)`
- `unsafeValue`
- `deinit` when `T` owns memory
- redaction-safe `format`
- equality and hash through underlying value

### Data

`Data` provides helpers for defining tagged structs and tagged enum-like unions
that integrate with `Equal`, `Hash`, `Show`, and `fx.match`.

Zig already has `union(enum)`, so `Data` should not invent a parallel ADT
encoding. Its value is in helper contracts:

- assert a type is tagged data
- derive tag name
- derive field metadata
- validate data-friendly equality/hash support
- build diagnostics for tagged-data mismatch

### Chunk

`Chunk(T)` is an owned, immutable-by-convention sequence wrapper.

Planned shape:

```zig
pub fn Chunk(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        items: []T,
    };
}
```

Planned API:

- `empty`
- `fromSlice`
- `deinit`
- `len`
- `at`
- `append`
- `concat`
- `map`
- `filter`
- `fold`
- `toSlice`

Operations that allocate return allocator errors explicitly.

### HashSet

`HashSet(T)` uses `Equal` and `Hash`.

Planned API:

- `init`
- `deinit`
- `contains`
- `add`
- `remove`
- `len`
- `union`
- `intersection`
- `difference`
- `toChunk`

The first implementation can wrap `std.AutoHashMap`-style storage when the
default hash/equality contract is enough, and use package-owned adapters where
custom equality is needed.

### DateTime

`DateTime` starts with UTC-first semantics:

```zig
pub const DateTime = union(enum) {
    utc: Utc,
    zoned: Zoned,
};
```

`Utc` stores epoch nanoseconds or milliseconds with explicit precision.
`Zoned` stores UTC instant plus a zone identifier/offset. Named-zone rules are
allowed to be limited at first; the type boundary should not require changing
callers when richer zone databases arrive.

Planned API:

- `now` through `Clock`
- `fromEpochMillis`
- `fromEpochNanos`
- `parseIso`
- `formatIso`
- `addDuration`
- `distance`
- `compare`

### BigDecimal

`BigDecimal` represents decimal values with value plus scale, following
Effect's conceptual model.

Public model:

```zig
pub const BigDecimal = struct {
    allocator: std.mem.Allocator,
    coefficient: BigInt,
    scale: i32,
};
```

The coefficient is arbitrary precision. The implementation may add a small
`i128` fast path internally, but callers see arbitrary-precision decimal
semantics from the first complete version.

Planned API:

- `make(value, scale)`
- `parse`
- `format`
- `normalize`
- `plus`
- `minus`
- `times`
- `compare`
- `equals`

## Layer 3: Tagged Union Matching

`fx.match` is for tagged ADTs.

### API

```zig
pub fn exhaustive(comptime Return: type, value: anytype, handlers: anytype) Return;
pub fn partial(comptime Return: type, value: anytype, handlers: anytype) ?Return;
pub fn orElse(comptime Return: type, value: anytype, handlers: anytype, fallback: anytype) Return;
pub fn option(comptime Return: type, value: anytype, handlers: anytype) Option(Return);
pub fn either(comptime Return: type, comptime Error: type, value: anytype, handlers: anytype) Either(Return, Error);
```

Handler fields map directly to union tags:

```zig
const text = fx.match.exhaustive([]const u8, exit, .{
    .success = onSuccess,
    .failure = onFailure,
    .defect = onDefect,
    .interrupted = onInterrupted,
    .cause = onCause,
});
```

Handlers may be:

- functions that accept the payload;
- zero-argument functions for void tags;
- comptime-known literal values when no payload is needed;
- small structs with a `call` method if a matcher needs state.

### Compile-Time Validation

`exhaustive` must fail at compile time when:

- `value` is not a tagged union;
- a union tag has no handler;
- handlers contain an unknown field;
- a handler has the wrong payload parameter type;
- a handler returns something other than `Return`.

`partial` permits missing handlers, but still rejects unknown tags and invalid
handler signatures.

Diagnostics should name:

- the matcher mode;
- the value type;
- missing tags;
- unknown handler fields;
- expected payload type;
- actual handler type.

### Cause And Exit Integration

Add methods or module functions:

```zig
pub fn matchCause(comptime Return: type, cause: anytype, handlers: anytype) Return;
pub fn matchExit(comptime Return: type, exit: anytype, handlers: anytype) Return;
```

Existing helpers such as `formatExit`, `formatCause`, `causeHasDefect`, and
`exitToResult` may keep native `switch` internally. Ergonomic public match
helpers should be available for users.

## Layer 4: Structural Pattern Matching

`fx.pattern` handles shape matching over structs, unions, optionals, arrays,
slices, pointers, scalars, and custom predicates.

### API

```zig
pub fn matches(value: anytype, pattern: anytype) bool;
pub fn capture(value: anytype, pattern: anytype) ?Captures(@TypeOf(value), pattern);
pub fn match(value: anytype, pattern: anytype) MatchResult(@TypeOf(value), pattern);
```

Pattern helpers:

```zig
pub const any: Pattern = .{ .wildcard = {} };
pub fn bind(comptime name: []const u8) Pattern;
pub fn when(predicate: anytype) Pattern;
pub fn range(comptime mode: RangeMode, min: anytype, max: anytype) Pattern;
pub fn tag(comptime tag_name: []const u8, payload_pattern: anytype) Pattern;
pub fn oneOf(patterns: anytype) Pattern;
pub fn optional(pattern: anytype) Pattern;
pub fn custom(comptime matcher: type, args: anytype) Pattern;
```

Range modes:

```zig
pub const RangeMode = enum {
    inclusive,
    exclusive,
    inclusive_min,
    inclusive_max,
};
```

### Matching Rules

- Scalar patterns compare with `Equal`.
- Struct patterns match declared fields by name.
- Union patterns match active tag and payload.
- Optional patterns match null/non-null explicitly.
- Array patterns match exact length unless a rest matcher is present.
- Slice patterns can match exact length, prefix, suffix, or rest captures.
- Pointer patterns dereference single-item pointers only.
- Wildcards match anything and capture nothing.
- Captures return a generated struct.
- Predicates receive a pointer or value according to matcher definition.

### Captures

Captures are generated at comptime.

Rules:

- Duplicate capture names are compile errors unless the captured types are the
  same and the repeated value is proven equal at runtime.
- Captured field names must be valid Zig identifiers or explicitly escaped by
  the API.
- Capturing `Redacted(T)` preserves the redacted wrapper.
- No default stringification of captured redacted values is allowed.

### Custom Matcher Protocol

Custom matchers are comptime-known values or types that expose:

```zig
pub const Captures = struct {};
pub fn matches(value: anytype, captures: *Captures) bool;
```

The exact protocol should stay small enough that package users can implement
custom predicates without learning a mini framework.

### Exhaustiveness And Reachability

Structural exhaustiveness is required for tagged unions where the pattern set
claims exhaustive mode.

Planned APIs:

```zig
pub fn exhaustive(comptime Return: type, value: anytype, arms: anytype) Return;
pub fn partial(comptime Return: type, value: anytype, arms: anytype) ?Return;
```

For tagged unions:

- every tag must be covered in exhaustive mode;
- unknown tags are compile errors;
- duplicate exact tag arms are compile errors;
- unreachable arms are compile errors when they are statically provable;
- predicate overlap may remain a runtime ordering concern unless provable.

## Milestones

### Milestone 1: Traits Foundation

- Add `fx.traits`.
- Implement `Equal`, `Hash`, `Order`, `Show`, and redaction formatting.
- Add focused tests for scalar, slice, struct, and tagged union derivation.

### Milestone 2: Option, Either, Duration, Redacted

- Add foundational data modules.
- Add module-level and method-style APIs.
- Add equality/hash/order/show support.

### Milestone 3: Cause And Exit Adapters

- Add public match helpers for `Cause`, `Exit`, and `FinalizerExit`.
- Add conversion helpers to `Option` and `Either` where semantically valid.
- Preserve existing APIs.

### Milestone 4: Generic Tagged Matcher

- Add `fx.match.exhaustive`, `partial`, `orElse`, `option`, and `either`.
- Add compile-fail coverage for missing handlers, unknown tags, invalid
  handler payload types, and invalid return types.

### Milestone 5: Data Helpers

- Add `fx.data.Data` helpers for tagged data validation and derived trait
  support.
- Document how `union(enum)` remains the canonical ADT representation.

### Milestone 6: Structural Matcher Core

- Add `fx.pattern.matches` and `fx.pattern.capture`.
- Support wildcard, bind, predicates, ranges, structs, unions, optionals,
  arrays, and slices.
- Add duplicate capture validation.

### Milestone 7: Structural Arms

- Add `fx.pattern.exhaustive` and `fx.pattern.partial`.
- Validate tagged-union coverage in exhaustive mode.
- Add static unreachable checks where straightforward.

### Milestone 8: Chunk And HashSet

- Add `Chunk(T)` and `HashSet(T)`.
- Integrate with traits.
- Add map/filter/fold/set operations.

### Milestone 9: DateTime And BigDecimal

- Add UTC-first `DateTime`.
- Add arbitrary-precision `BigDecimal` with parse, format, normalize, compare,
  and arithmetic.
- Add tests that prove values exceed fixed-width integer precision.

### Milestone 10: Docs And Examples

- Add `packages/zigeffect/docs/data.md`.
- Add `packages/zigeffect/docs/pattern-matching.md`.
- Add examples for `Option`, `Either`, `Exit`, tagged matching, and structural
  matching.
- Update README and architecture docs.

### Milestone 11: Stabilization

- Expand compile-fail diagnostics.
- Dogfood matchers in selected tests and diagnostics.
- Run package, workspace Zig, and TypeScript verification.

## Error Handling

Runtime matching functions should not allocate unless their return type or
handler does. Compile-time validation uses `@compileError` with precise,
actionable messages.

Data types that allocate return `Allocator.Error` explicitly. Parsing APIs use
small typed error sets, for example `ParseDurationError`,
`ParseDateTimeError`, and `ParseBigDecimalError`.

Structural matching itself returns `bool` or optional capture structs. It should
not panic on ordinary non-matches.

## Testing

Use `bun run zigeffect:test` for package verification.

Add normal tests for:

- trait derivation;
- `Option` and `Either` constructors and combinators;
- `Duration` arithmetic;
- `Redacted` formatting;
- tagged matcher success paths;
- structural matcher success and failure paths;
- capture generation;
- array and slice matching;
- `Cause` and `Exit` match ergonomics.

Add compile-fail fixtures for:

- missing exhaustive handler;
- unknown handler tag;
- wrong handler payload;
- wrong handler return type;
- duplicate capture names;
- invalid range bounds;
- structural exhaustive union missing a tag;
- redacted unsafe formatting misuse where comptime-detectable.

Final verification for implementation milestones:

```bash
bun run zigeffect:test
bun run zig:test
bun run typecheck
```

## Acceptance Criteria

- `fx.data`, `fx.match`, `fx.pattern`, and `fx.traits` are exported through the
  public facade.
- `Option`, `Either`, `Data`, `Duration`, `Redacted`, `Chunk`, `HashSet`,
  `DateTime`, and `BigDecimal` have focused tests and documented ownership
  rules.
- Existing `Cause` and `Exit` APIs continue to work and gain match adapters.
- `fx.match.exhaustive` rejects missing or unknown tagged-union handlers at
  compile time.
- `fx.pattern` supports structural matching with captures and custom
  predicates.
- Structural exhaustive mode checks tagged-union coverage.
- Redacted data remains redacted in formatting and captured output unless the
  caller explicitly opts into unsafe extraction.
- The full package verification gate passes.
