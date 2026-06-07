# zigeffect Pattern Matching

`zigeffect` has two matching layers.

## Tagged Union Matching

Use `fx.match.exhaustive(Return, value, handlers)` for plain `union(enum)`
ADTs. Every tag must have a handler. Use `fx.match.partial` when missing tags
are allowed, or `fx.match.orElse` for a fallback value.

```zig
const Event = union(enum) {
    started,
    progress: u8,
};

const label = fx.match.exhaustive([]const u8, Event{ .progress = 7 }, .{
    .started = onStarted,
    .progress = onProgress,
});
```

`Option`, `Either`, `Cause`, and `Exit` expose `.match(Return, handlers)` for
type-native ergonomics.

## Structural Patterns

Use `fx.pattern.matches(value, pattern)` for recursive structural checks:

- `fx.pattern.any`
- `fx.pattern.bind("name")`
- `fx.pattern.range(.inclusive, min, max)`
- `fx.pattern.predicate(fn)`
- `fx.pattern.some(pattern)` and `fx.pattern.none`
- nested struct patterns
- exact arrays, slices, and single-item pointers

Use `fx.pattern.capture(value, comptime pattern)` to derive a typed capture
struct:

```zig
const captures = fx.pattern.capture(profile, .{
    .name = fx.pattern.bind("name"),
    .pos = .{ .x = fx.pattern.bind("x"), .y = fx.pattern.any },
}).?;

try std.testing.expectEqualStrings("Ada", captures.name);
try std.testing.expectEqual(@as(i32, 10), captures.x);
```

Duplicate capture names are rejected at compile time.

## Structural Arms

Use `fx.pattern.arm(pattern, handler)` inside `fx.pattern.exhaustive` or
`fx.pattern.partial` to combine tagged-union dispatch with payload filtering:

```zig
const result = fx.pattern.exhaustive([]const u8, event, .{
    .heartbeat = fx.pattern.arm(fx.pattern.any, onHeartbeat),
    .signed_in = fx.pattern.arm(.{
        .age = fx.pattern.range(.inclusive, 18, 120),
        .name = fx.pattern.any,
    }, onSignedIn),
    .failed = fx.pattern.arm(fx.pattern.any, onFailed),
});
```

Exhaustive structural arms validate tag coverage at compile time. Partial arms
return `null` when the active tag is missing or its payload pattern does not
match.
