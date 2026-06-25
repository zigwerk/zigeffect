# zigeffect-std Production Schema Design

Date: 2026-06-25

## Decision

Upgrade `zstd.Schema` from a useful boundary helper into the production data
contract layer for local zigeffect applications.

The module will stay source-compatible with the current simple APIs:

```zig
try zstd.Schema.decodeJsonValue(zstd.Schema.string(), value);
try zstd.Schema.decodeJsonAlloc(allocator, schema, json_text);
try zstd.Schema.decodeConfig(config, "HTTP_PORT", zstd.Schema.integer());
```

The production path will add richer APIs beside them:

```zig
var result = try zstd.Schema.decodeDetailedJsonAlloc(allocator, schema, json_text);
defer result.deinit();

const json = try zstd.Schema.encodeJsonAlloc(allocator, schema, value);
defer allocator.free(json);
```

This keeps existing std modules stable while giving CLI, config, HTTP, SQL,
agent receipts, and future user packages one shared schema engine for
validation, redaction, transforms, and JSON/config codecs.

## Goals

- Add decode and encode symmetry for supported schemas.
- Preserve exact error paths through nested objects, arrays, optionals, enums,
  constraints, defaults, and transforms.
- Report multiple issues in one pass for object fields and array elements.
- Redact secret-shaped actual values in every issue and serialized error tree.
- Make ownership explicit for detailed parse results.
- Add ergonomic struct derivation for common Zig structs while retaining manual
  `structSchema` for advanced schemas.
- Keep the implementation deterministic and std-lib-only.

## Non-Goals

- No runtime reflection beyond Zig compile-time type inspection.
- No regex engine dependency.
- No schema-to-TypeScript or OpenAPI generation in this milestone.
- No automatic network URL validation beyond deterministic string constraints.
- No breaking change to existing simple decode APIs.

## Public API Shape

### Detailed Result

`decodeDetailedJsonAlloc` returns an owned result object:

```zig
pub fn DecodeResult(comptime Output: type) type {
    return struct {
        allocator: std.mem.Allocator,
        value: ?Output,
        issues: IssueList,

        pub fn ok(self: @This()) bool;
        pub fn deinit(self: *@This()) void;
    };
}
```

Successful results contain `value` and an empty issue list. Failed results
contain `null` value plus one or more issues. The function itself only returns
allocator and JSON syntax errors; validation problems live in `issues`.

### Issue Tree

The current flat `Issue` stays, but grows enough information to be useful in
local agent workflows:

```zig
pub const IssueKind = enum {
    invalid_type,
    missing_field,
    invalid_value,
    unknown_enum,
    constraint_failed,
    transform_failed,
    encode_failed,
};

pub const Issue = struct {
    path: []const u8,
    kind: IssueKind,
    expected: []const u8,
    actual: []const u8,
    message: []const u8 = "",
};
```

`IssueList` owns duplicated issue strings, renders deterministic JSON, and
redacts all secret-shaped `actual` and `message` data.

Paths use a predictable grammar:

- root: `$`
- object field: `$.database.host`
- array index: `$.agents[2].command`

### Parse Context

Schema internals use a `ParseContext`:

```zig
pub const ParseContext = struct {
    allocator: std.mem.Allocator,
    path: PathStack,
    issues: *IssueList,
};
```

The context owns path formatting and issue recording. Nested schemas never
hand-build paths.

### Codecs

Supported schemas gain `encodeJsonValueAlloc` or `encodeJsonAlloc` helpers:

- string
- integer
- boolean
- optional
- array
- enum
- struct/manual fields
- derived struct fields
- default
- constraints
- transforms that provide an explicit inverse encoder

Transforms without an inverse remain decode-only and report `encode_failed`
when a caller asks them to encode.

### Constraints

Primitive schemas become chainable value structs:

```zig
const port = zstd.Schema.integer().min(1).max(65535);
const name = zstd.Schema.string().nonEmpty().maxLen(64);
const mode = zstd.Schema.stringEnum(&.{ "local", "ci" });
```

String constraints:

- `nonEmpty`
- `minLen`
- `maxLen`
- `startsWith`
- `endsWith`
- `contains`

Integer constraints:

- `min`
- `max`

Constraint failures record `constraint_failed` with the active path.

### Defaults

`default(schema, value)` applies only when a field is missing or a config value
is absent. It does not mask invalid provided values.

```zig
field("pool", zstd.Schema.default(zstd.Schema.integer().min(1), 4))
```

Defaults must be copy-safe for scalar and borrowed literal values. Owned
deep-copy defaults are explicitly out of scope for this milestone.

### Transforms

The existing `transform` stays. A production transform adds a name and optional
encoder:

```zig
const port_schema = zstd.Schema.transformNamed(
    zstd.Schema.string(),
    u16,
    "port",
    parsePort,
    formatPort,
);
```

Transform decode failures become `transform_failed` issues at the same path as
the source value. If the source value contains a secret, the issue actual is
redacted.

### Struct Derivation

Manual struct schemas remain supported:

```zig
const schema = zstd.Schema.structSchema(AppConfig, .{
    zstd.Schema.field("name", zstd.Schema.string().nonEmpty()),
    zstd.Schema.field("port", zstd.Schema.integer().min(1).max(65535)),
});
```

Derived schemas reduce boilerplate for ordinary Zig structs:

```zig
const schema = zstd.Schema.derive(AppConfig, .{
    .name = zstd.Schema.string().nonEmpty(),
    .port = zstd.Schema.integer().min(1).max(65535),
    .mode = zstd.Schema.default(zstd.Schema.stringEnum(&.{ "local", "ci" }), "local"),
});
```

Derivation behavior:

- every public struct field must have either an override schema or a supported
  default inferred schema;
- inferred schemas cover `[]const u8`, integer types, `bool`, optionals, and
  slices of supported inferred types;
- unknown fields in JSON are ignored for this milestone;
- missing required fields produce `missing_field`;
- invalid multiple fields are accumulated.

## Data Flow

JSON decode:

```text
json text
  -> std.json.Value
  -> ParseContext("$")
  -> schema.decodeDetailedValue
  -> DecodeResult(value or IssueList)
```

Config decode:

```text
LayeredConfig
  -> key lookup
  -> schema.decodeDetailedConfigText
  -> DecodeResult(value or IssueList)
```

Encode:

```text
typed value
  -> schema.encodeJsonValueAlloc / encodeJsonAlloc
  -> deterministic redacted JSON text when values are diagnostic payloads
```

## Error Handling

Simple APIs continue returning `SchemaError` for callers that want fast failure.
They may internally use detailed decode and return the first issue as the legacy
error variant.

Detailed APIs never throw validation errors. They return issues so local agents
and CLIs can show all boundary failures at once.

All issue JSON rendering uses `zstd.Secrets`.

## Testing

The implementation must be test-first. Required regression coverage:

- primitive encode/decode symmetry;
- nested object paths;
- array index paths;
- multi-error accumulation;
- missing field with default succeeds;
- invalid provided field with default still fails;
- string and integer constraints;
- transform success and transform failure;
- transform encode with and without inverse;
- derived struct schema for primitives, optionals, arrays, and overrides;
- config detailed decode;
- secret redaction in issue actual/message and issue-list JSON;
- old simple APIs still pass current tests.

## Documentation

Update:

- `packages/zigeffect-std/README.md`
- `packages/zigeffect/docs/roadmap.md`
- this feature's implementation plan under `docs/superpowers/plans/`

The README should show both quick simple decode and production detailed decode.

## Completion Criteria

- `bun run zigeffect:std:test` passes.
- `bun run zigeffect:local-agent-gate` passes unless this milestone only touches
  std docs and schema tests; if skipped, the final report must say why.
- `git diff --check` passes.
- Schema public APIs are documented in README.
- No existing std module imports break.
