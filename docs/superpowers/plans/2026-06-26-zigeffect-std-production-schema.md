# zigeffect-std Production Schema Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade `zstd.Schema` into a production-ready local schema library with detailed error trees, constraints, codecs, defaults, transforms, derived struct schemas, and backward-compatible simple APIs.

**Architecture:** Keep the public module at `packages/zigeffect-std/src/schema/root.zig` so existing imports continue to work. Add richer owned result and issue-list types beside the current fast-fail API, then route detailed object/array decoding through a path-aware parse context while preserving legacy behavior.

**Tech Stack:** Zig std library, `std.json.Value`, existing `zstd.Json`, existing `zstd.Secrets`, existing `bun run zigeffect:std:test` verification.

---

### Task 1: Detailed Issues and Parse Context

**Files:**
- Modify: `packages/zigeffect-std/src/schema/root.zig`

- [ ] **Step 1: Write failing tests for owned issue lists and JSON redaction**

Add tests named:

```zig
test "Schema IssueList owns issues and renders redacted deterministic JSON" {
    var issues = IssueList.init(std.testing.allocator);
    defer issues.deinit();

    try issues.add(.{
        .path = "$.database.url",
        .kind = .invalid_value,
        .expected = "safe connection string",
        .actual = "postgres://user:pass@localhost/db",
        .message = "bad password=abc123",
    });

    const json = try issues.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);

    try std.testing.expectEqual(@as(usize, 1), issues.len());
    try std.testing.expect(std.mem.indexOf(u8, json, "\"path\":\"$.database.url\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "pass") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "abc123") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "[REDACTED]") != null);
}

test "Schema ParseContext records nested object and array paths" {
    var issues = IssueList.init(std.testing.allocator);
    defer issues.deinit();
    var ctx = ParseContext.init(std.testing.allocator, &issues);
    defer ctx.deinit();

    try ctx.pushField("agents");
    try ctx.pushIndex(2);
    try ctx.pushField("command");
    try ctx.addIssue(.invalid_type, "string", "42", "agent command must be a string");

    try std.testing.expectEqualStrings("$.agents[2].command", issues.items[0].path);
}
```

- [ ] **Step 2: Run the red tests**

Run:

```sh
bun run zigeffect:std:test
```

Expected: fail because `IssueList`, `ParseContext`, `constraint_failed`,
`transform_failed`, and `encode_failed` are not implemented.

- [ ] **Step 3: Implement issue ownership and path context**

Add:

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
```

Implement `IssueList` as an owned `std.ArrayList(Issue)` with duplicated strings
for `path`, `expected`, `actual`, and `message`. Implement `deinit`, `len`,
`add`, `jsonAlloc`, and `firstAsError`.

Implement `ParseContext` with an owned path buffer initialized to `$`, plus
`pushField`, `pushIndex`, `popTo`, `mark`, `currentPath`, and `addIssue`.

- [ ] **Step 4: Verify green**

Run:

```sh
bun run zigeffect:std:test
```

Expected: pass.

### Task 2: Detailed Primitive Decoding and Constraints

**Files:**
- Modify: `packages/zigeffect-std/src/schema/root.zig`

- [ ] **Step 1: Write failing tests for primitive detailed decode and constraints**

Add tests named:

```zig
test "Schema detailed primitive decode reports all constraint issues with paths" {
    const schema = string().nonEmpty().minLen(4).contains("@");
    var result = try decodeDetailedJsonAlloc(std.testing.allocator, schema, "\"\"");
    defer result.deinit();

    try std.testing.expect(!result.ok());
    try std.testing.expectEqual(@as(usize, 3), result.issues.len());
    try std.testing.expectEqualStrings("$", result.issues.items[0].path);
    try std.testing.expectEqual(IssueKind.constraint_failed, result.issues.items[0].kind);
}

test "Schema integer constraints support min max and simple decode compatibility" {
    const schema = integer().min(1).max(10);
    var invalid = try decodeDetailedJsonAlloc(std.testing.allocator, schema, "42");
    defer invalid.deinit();

    try std.testing.expect(!invalid.ok());
    try std.testing.expectEqual(IssueKind.constraint_failed, invalid.issues.items[0].kind);

    try std.testing.expectEqual(@as(i64, 7), try decodeJsonAlloc(std.testing.allocator, schema, "7"));
    try std.testing.expectError(SchemaError.InvalidValue, decodeJsonAlloc(std.testing.allocator, schema, "42"));
}
```

- [ ] **Step 2: Run the red tests**

Run:

```sh
bun run zigeffect:std:test
```

Expected: fail because constraints and `decodeDetailedJsonAlloc` do not exist.

- [ ] **Step 3: Implement primitive detailed decode**

Extend `StringSchema`, `IntegerSchema`, and `BooleanSchema` as value structs with
detailed decode methods. Add chainable string methods `nonEmpty`, `minLen`,
`maxLen`, `startsWith`, `endsWith`, and `contains`. Add integer methods `min`
and `max`.

Add:

```zig
pub fn DecodeResult(comptime Output: type) type {
    return struct {
        allocator: std.mem.Allocator,
        value: ?Output = null,
        issues: IssueList,

        pub fn ok(self: @This()) bool {
            return self.value != null and self.issues.len() == 0;
        }

        pub fn deinit(self: *@This()) void {
            self.issues.deinit();
            self.* = undefined;
        }
    };
}

pub fn decodeDetailedJsonAlloc(
    allocator: std.mem.Allocator,
    schema: anytype,
    json: []const u8,
) !DecodeResult(@TypeOf(schema).Output) {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{});
    defer parsed.deinit();

    var issues = IssueList.init(allocator);
    var ctx = ParseContext.init(allocator, &issues);
    defer ctx.deinit();

    const decoded = schema.decodeDetailedJsonValue(&ctx, parsed.value);
    if (issues.len() > 0) {
        return .{ .allocator = allocator, .value = null, .issues = issues };
    }
    return .{ .allocator = allocator, .value = try decoded, .issues = issues };
}
```

The simple `decodeJsonAlloc` must keep returning `SchemaError` by translating the
first issue from detailed decode.

- [ ] **Step 4: Verify green**

Run:

```sh
bun run zigeffect:std:test
```

Expected: pass.

### Task 3: Arrays, Structs, Defaults, and Multi-Error Accumulation

**Files:**
- Modify: `packages/zigeffect-std/src/schema/root.zig`

- [ ] **Step 1: Write failing tests for nested paths, defaults, and accumulation**

Add tests named:

```zig
const ProductionDatabaseConfig = struct {
    host: []const u8,
    port: i64,
    pool: i64,
};

const ProductionAppConfig = struct {
    name: []const u8,
    database: ProductionDatabaseConfig,
    agents: []const []const u8,
};

test "Schema detailed struct decode accumulates nested object and array issues" {
    const database_schema = structSchema(ProductionDatabaseConfig, .{
        field("host", string().nonEmpty()),
        field("port", integer().min(1).max(65535)),
        field("pool", default(integer().min(1), 4)),
    });
    const schema = structSchema(ProductionAppConfig, .{
        field("name", string().nonEmpty()),
        field("database", database_schema),
        field("agents", array(std.testing.allocator, string().nonEmpty())),
    });

    var result = try decodeDetailedJsonAlloc(std.testing.allocator, schema,
        \\{"name":"","database":{"port":70000,"pool":0},"agents":["codex","",42]}
    );
    defer result.deinit();

    try std.testing.expect(!result.ok());
    try expectIssuePath(result.issues, "$.name", .constraint_failed);
    try expectIssuePath(result.issues, "$.database.host", .missing_field);
    try expectIssuePath(result.issues, "$.database.port", .constraint_failed);
    try expectIssuePath(result.issues, "$.database.pool", .constraint_failed);
    try expectIssuePath(result.issues, "$.agents[1]", .constraint_failed);
    try expectIssuePath(result.issues, "$.agents[2]", .invalid_type);
}

test "Schema defaults apply to missing fields but not invalid provided values" {
    const schema = structSchema(ProductionDatabaseConfig, .{
        field("host", string().nonEmpty()),
        field("port", integer().min(1).max(65535)),
        field("pool", default(integer().min(1), 4)),
    });

    const decoded = try decodeJsonAlloc(std.testing.allocator, schema,
        \\{"host":"localhost","port":5432}
    );
    try std.testing.expectEqual(@as(i64, 4), decoded.pool);

    var invalid = try decodeDetailedJsonAlloc(std.testing.allocator, schema,
        \\{"host":"localhost","port":5432,"pool":0}
    );
    defer invalid.deinit();
    try std.testing.expect(!invalid.ok());
    try expectIssuePath(invalid.issues, "$.pool", .constraint_failed);
}
```

- [ ] **Step 2: Run the red tests**

Run:

```sh
bun run zigeffect:std:test
```

Expected: fail because detailed array/struct/default decoding is missing.

- [ ] **Step 3: Implement detailed array, struct, and default schemas**

Add `DefaultSchema`, `default(schema, value)`, `hasDefault`, and `defaultValue`.
Teach `ArraySchema` to decode every element and record all element issues before
returning failure. Teach `StructSchema` to record missing fields, nested field
paths, default values, and all invalid fields before returning a failed result.

Add the test helper:

```zig
fn expectIssuePath(issues: IssueList, path: []const u8, kind: IssueKind) !void {
    for (issues.items) |issue| {
        if (std.mem.eql(u8, issue.path, path) and issue.kind == kind) return;
    }
    std.debug.print("missing issue path={s} kind={s}\n", .{ path, issueKindName(kind) });
    return error.TestExpectedEqual;
}
```

- [ ] **Step 4: Verify green**

Run:

```sh
bun run zigeffect:std:test
```

Expected: pass.

### Task 4: Encode Codecs and Named Transforms

**Files:**
- Modify: `packages/zigeffect-std/src/schema/root.zig`

- [ ] **Step 1: Write failing tests for encode/decode symmetry and transform encode behavior**

Add tests named:

```zig
fn parsePortText(value: []const u8) SchemaError!u16 {
    const parsed = std.fmt.parseInt(u16, value, 10) catch return SchemaError.InvalidValue;
    if (parsed == 0) return SchemaError.InvalidValue;
    return parsed;
}

fn formatPortText(allocator: std.mem.Allocator, value: u16) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}", .{value});
}

test "Schema encodes primitives arrays structs and defaults deterministically" {
    const schema = structSchema(ProductionDatabaseConfig, .{
        field("host", string().nonEmpty()),
        field("port", integer().min(1).max(65535)),
        field("pool", default(integer().min(1), 4)),
    });
    const json = try encodeJsonAlloc(std.testing.allocator, schema, .{
        .host = "localhost",
        .port = 5432,
        .pool = 8,
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"host\":\"localhost\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"port\":5432") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"pool\":8") != null);
}

test "Schema named transforms decode and encode when inverse is provided" {
    const schema = transformNamed(string(), u16, "port", parsePortText, formatPortText);
    try std.testing.expectEqual(@as(u16, 5178), try decodeJsonAlloc(std.testing.allocator, schema, "\"5178\""));

    const json = try encodeJsonAlloc(std.testing.allocator, schema, @as(u16, 5178));
    defer std.testing.allocator.free(json);
    try std.testing.expectEqualStrings("\"5178\"", json);
}
```

- [ ] **Step 2: Run the red tests**

Run:

```sh
bun run zigeffect:std:test
```

Expected: fail because `encodeJsonAlloc` and `transformNamed` are missing.

- [ ] **Step 3: Implement encoding and named transforms**

Add deterministic JSON encoders for primitives, optionals, arrays, enums,
structs, defaults, and transforms with inverse encoders. Preserve existing
decode-only `transform` and make encode attempts against decode-only transforms
return an `encode_failed` detailed issue.

- [ ] **Step 4: Verify green**

Run:

```sh
bun run zigeffect:std:test
```

Expected: pass.

### Task 5: Derived Struct Schema and Config Detailed Decode

**Files:**
- Modify: `packages/zigeffect-std/src/schema/root.zig`

- [ ] **Step 1: Write failing tests for derivation and config detailed decode**

Add tests named:

```zig
const DerivedSchemaConfig = struct {
    name: []const u8,
    port: i64,
    enabled: bool,
    mode: ?[]const u8,
};

test "Schema derive decodes common Zig structs with overrides" {
    const schema = derive(DerivedSchemaConfig, .{
        .name = string().nonEmpty(),
        .port = integer().min(1).max(65535),
        .enabled = boolean(),
        .mode = optional(stringEnum(&.{ "local", "ci" })),
    });

    const decoded = try decodeJsonAlloc(std.testing.allocator, schema,
        \\{"name":"local","port":5178,"enabled":true,"mode":"ci"}
    );

    try std.testing.expectEqualStrings("local", decoded.name);
    try std.testing.expectEqual(@as(i64, 5178), decoded.port);
    try std.testing.expectEqual(true, decoded.enabled);
    try std.testing.expectEqualStrings("ci", decoded.mode.?);
}

test "Schema detailed config decode reports missing and invalid keys" {
    var config = @import("../config/root.zig").LayeredConfig.init(std.testing.allocator);
    defer config.deinit();
    try config.put("HTTP_PORT", "99999", false);

    var result = try decodeDetailedConfig(std.testing.allocator, config, "HTTP_PORT", integer().min(1).max(65535));
    defer result.deinit();
    try std.testing.expect(!result.ok());
    try expectIssuePath(result.issues, "HTTP_PORT", .constraint_failed);

    var missing = try decodeDetailedConfig(std.testing.allocator, config, "DATABASE_URL", string().nonEmpty());
    defer missing.deinit();
    try std.testing.expect(!missing.ok());
    try expectIssuePath(missing.issues, "DATABASE_URL", .missing_field);
}
```

- [ ] **Step 2: Run the red tests**

Run:

```sh
bun run zigeffect:std:test
```

Expected: fail because `derive` and `decodeDetailedConfig` are missing.

- [ ] **Step 3: Implement derivation and config detailed decode**

Add `derive(Output, overrides)` as a compile-time struct schema wrapper that uses
override schemas for fields. Implement inferred schemas only where no override is
present and the field is `[]const u8`, an integer, `bool`, optional supported
type, or slice of supported type.

Add `decodeDetailedConfig(allocator, config, key, schema)` with path equal to
the config key.

- [ ] **Step 4: Verify green**

Run:

```sh
bun run zigeffect:std:test
```

Expected: pass.

### Task 6: Docs, Roadmap, and Final Verification

**Files:**
- Modify: `packages/zigeffect-std/README.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-25-zigeffect-std-production-schema-design.md`

- [ ] **Step 1: Update docs**

README must show:

```zig
const schema = zstd.Schema.derive(AppConfig, .{
    .name = zstd.Schema.string().nonEmpty(),
    .port = zstd.Schema.integer().min(1).max(65535),
});

var result = try zstd.Schema.decodeDetailedJsonAlloc(allocator, schema, json);
defer result.deinit();
```

Roadmap row 15 must mention production Schema M11 delivered.

The M11 spec must gain:

```md
Status: delivered on 2026-06-26.
```

- [ ] **Step 2: Run final verification**

Run:

```sh
zig fmt packages/zigeffect-std/src/schema/root.zig
bun run zigeffect:std:test
bun run zigeffect:postgres:test
git diff --check
bun run zigeffect:local-agent-gate
```

Expected:

- std tests and examples pass;
- Postgres adapter tests pass;
- whitespace check passes;
- local agentic development gate passes.

- [ ] **Step 3: Commit implementation**

Run:

```sh
git add docs/superpowers/plans/2026-06-26-zigeffect-std-production-schema.md \
  docs/superpowers/specs/2026-06-25-zigeffect-std-production-schema-design.md \
  packages/zigeffect-std/README.md \
  packages/zigeffect-std/src/schema/root.zig \
  packages/zigeffect/docs/roadmap.md
git diff --cached --check
git commit -m "Add production zigeffect std schema"
```
