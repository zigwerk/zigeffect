# zigeffect Data

`fx.data` contains Effect-style data helpers with explicit Zig ownership.

## Foundational Types

- `fx.Option(T)` is a small optional wrapper with `some`, `none`, `map`,
  `flatMap`, `getOrElse`, `valueOrNull`, and `match`.
- `fx.Either(Right, Left)` is right-biased with `right`, `left`, `map`,
  `mapLeft`, `flatMap`, `getOrElse`, `rightOrNull`, `leftOrNull`, and `match`.
- `fx.Duration` stores finite nanoseconds or infinity. Use `nanos`, `millis`,
  `seconds`, `minutes`, `hours`, `plus`, `minus`, `toNanos`, and `toMillis`.
- `fx.Redacted(T)` stores a value behind an intentional `unsafeValue()` call and
  displays `fx.traits.redaction_marker` through `redactedText()`.

## Owned Collections

`fx.Chunk(T)` owns a copied slice. Create it with `fromSlice(allocator, values)`
and call `deinit()` when done. It supports `append`, `concat`, `map`, `filter`,
and `fold`.

`fx.HashSet(T)` wraps `std.AutoHashMap(T, void)` and owns its map. Create it
with `init(allocator)` and call `deinit()` when done. It supports `add`,
`contains`, `remove`, `count`, `unionWith`, `intersection`, and `difference`.

## DateTime And BigDecimal

`fx.DateTime` stores UTC epoch nanoseconds. Use `parseIsoUtc`,
`formatIsoUtc`, `epochNanos`, and `distance`.

`fx.BigDecimal` parses decimal strings into owned coefficient digits plus scale
and sign. It does not round-trip through `i128`, so very large precise values
stay exact. Create with `parse(allocator, text)`, call `deinit()`, and use
`format(allocator)` when a string is needed.

## Reflection

`fx.Data.isTaggedUnion(T)` recognizes `union(enum)` ADTs. It is used by the
matching layer and is useful for compile-time validation in user code.
