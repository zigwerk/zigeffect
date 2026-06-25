# zigeffect-std Schema Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `zstd.Schema`, the typed validation/decode/encode boundary layer for JSON and config inputs.

**Architecture:** Add `packages/zigeffect-std/src/schema/root.zig` using schema values that expose `Output`, `decodeJsonValue`, and optional `encodeJsonAlloc`. Schema helpers operate on `std.json.Value` for JSON boundaries and `zstd.Config.LayeredConfig` for config boundaries. Error reporting uses structured issues with redacted rendering.

**Tech Stack:** Zig 0.16, `std.json.Value`, `std.json.parseFromSlice`, existing `zstd.Json`, `zstd.Config`, `zstd.Secrets`, and `bun run zigeffect:std:test`.

---

## File Structure

- Create `packages/zigeffect-std/src/schema/root.zig`: schema primitives, arrays, optionals, enum matching, struct field decoder, transforms, JSON/config codecs, error diagnostics.
- Modify `packages/zigeffect-std/src/root.zig`: export `Schema`.
- Modify `packages/zigeffect-std/README.md`: document `Schema`.

## Task 1: Primitive JSON Schemas and Errors

**Files:**
- Create: `packages/zigeffect-std/src/schema/root.zig`
- Modify: `packages/zigeffect-std/src/root.zig`

- [ ] **Step 1: Write failing primitive tests**

Add tests:

```zig
test "Schema decodes primitive JSON values" {}
test "Schema returns structured redacted issue for invalid primitive" {}
```

The tests must prove:

- string, integer, and boolean schemas decode `std.json.Value`;
- invalid type returns `SchemaError.InvalidType`;
- `issueJsonAlloc` redacts secret-shaped actual values.

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because `Schema` is not exported and APIs are missing.

- [ ] **Step 2: Implement primitives and issues**

Implement:

```zig
pub const SchemaError = error{ InvalidType, MissingField, InvalidValue, UnknownEnum, TransformFailed };
pub const IssueKind = enum { invalid_type, missing_field, invalid_value, unknown_enum };
pub const Issue = struct { path: []const u8, kind: IssueKind, expected: []const u8, actual: []const u8, message: []const u8 = "" };
pub fn issueJsonAlloc(allocator: std.mem.Allocator, issue: Issue) ![]const u8;
pub fn string() StringSchema;
pub fn integer() IntegerSchema;
pub fn boolean() BooleanSchema;
pub fn decodeJsonValue(schema: anytype, value: std.json.Value) (SchemaError || std.mem.Allocator.Error)!@TypeOf(schema).Output;
```

- [ ] **Step 3: Verify**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: primitive tests pass.

## Task 2: Optional, Array, Enum, and Transform

**Files:**
- Modify: `packages/zigeffect-std/src/schema/root.zig`

- [ ] **Step 1: Write failing composite tests**

Add tests:

```zig
test "Schema decodes optional and array JSON values" {}
test "Schema decodes enum choices and transform schemas" {}
```

The tests must prove:

- optional string returns `null` for JSON null and string for JSON string;
- array of integers decodes every element and owns the result slice;
- enum choice accepts only configured strings;
- transform maps a decoded string into another value.

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because composite APIs are missing.

- [ ] **Step 2: Implement composite schemas**

Implement:

```zig
pub fn optional(schema: anytype) OptionalSchema(@TypeOf(schema));
pub fn array(schema: anytype) ArraySchema(@TypeOf(schema));
pub fn stringEnum(comptime choices: []const []const u8) EnumSchema(choices);
pub fn transform(schema: anytype, comptime Output: type, mapper: *const fn (@TypeOf(schema).Output) SchemaError!Output) TransformSchema(@TypeOf(schema), Output, mapper);
pub fn freeDecoded(allocator: std.mem.Allocator, value: anytype) void;
```

- [ ] **Step 3: Verify**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: composite tests pass.

## Task 3: Struct Fields, JSON Codec, and Config Codec

**Files:**
- Modify: `packages/zigeffect-std/src/schema/root.zig`

- [ ] **Step 1: Write failing boundary tests**

Add tests:

```zig
test "Schema decodes struct fields from JSON object" {}
test "Schema decodes JSON text and config entries" {}
```

The tests must prove:

- a struct field schema decodes a typed Zig struct from a JSON object;
- missing field returns `MissingField`;
- `decodeJsonAlloc` parses JSON text and decodes it;
- `decodeConfig` reads `Config.LayeredConfig` values through schema codecs.

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because struct/config APIs are missing.

- [ ] **Step 2: Implement boundary codecs**

Implement:

```zig
pub fn field(comptime name: []const u8, schema: anytype) FieldSpec(@TypeOf(schema), name);
pub fn structSchema(comptime Output: type, fields: anytype) StructSchema(Output, @TypeOf(fields));
pub fn decodeJsonAlloc(allocator: std.mem.Allocator, schema: anytype, json: []const u8) !@TypeOf(schema).Output;
pub fn decodeConfig(config: anytype, comptime key: []const u8, schema: anytype) !@TypeOf(schema).Output;
```

`structSchema` should support string, integer, boolean, optional, enum, and
transform field schemas for the first milestone.

- [ ] **Step 3: Verify**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: boundary tests pass.

## Task 4: Docs and Gate

**Files:**
- Modify: `packages/zigeffect-std/README.md`
- Modify: `docs/superpowers/plans/2026-06-25-zigeffect-std-schema.md`

- [ ] **Step 1: Update README**

Add `Schema` to the module list and public surface.

- [ ] **Step 2: Mark plan checkboxes complete**

Replace completed `- [ ]` with `- [x]`.

- [ ] **Step 3: Final verification**

Run:

```sh
bun run zigeffect:std:test
bun run zigeffect:local-agent-gate
git diff --check
```

Expected: all commands exit 0.

