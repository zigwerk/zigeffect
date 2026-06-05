# zigeffect Config Schema Loading Design

## Goal

Load a complete typed config struct from existing config descriptors in one
call, while preserving descriptor defaults, parse errors, and secret-safe
diagnostics.

## Design

Add a schema helper to `Config`:

```zig
const AppConfig = struct {
    name: []const u8,
    port: i64,
    enabled: bool,
};

const schema = fx.Config.schema(AppConfig, .{
    .name = fx.Config.string("app.name"),
    .port = fx.Config.int("http.port"),
    .enabled = fx.Config.boolean("feature.enabled").withDefault(false),
});

const app = try config.readSchema(schema);
```

The schema is a compile-time contract between a named output struct and a named
descriptor struct. Every output field must have a descriptor with the same field
name, and each descriptor `ValueType` must match the output field type.

`readSchema` iterates output fields, calls existing `read(descriptor)`, and
returns the populated output struct. It does not introduce a second parser or
provider path.

## Contract

- Defaults continue to live on descriptors.
- Missing keys still return `error.MissingConfig`.
- Invalid conversion still returns `error.InvalidConfigValue`.
- Schema validation emits compile-time errors for missing descriptors or value
  type mismatches.

## Tests

Add a service test that loads entries, defines an `AppConfig` schema, reads the
full struct, and verifies strings, ints, booleans, and defaults.
