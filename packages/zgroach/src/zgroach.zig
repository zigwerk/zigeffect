//! zgroach — the Zig RoachGraph toolchain.
//!
//! One schema and one query surface over several stores, in the shape Prisma
//! uses: a plan is written once against a neutral vocabulary, and a connector
//! answers it. What each connector can do is declared, so an unsupported query
//! is a typed error naming the feature and the store rather than an empty result
//! or a runtime failure.
//!
//! Today's connector is the embedded causal graph — local, file-backed, no
//! daemon. The CockroachDB connector is the same plan lowered to SQL, which is
//! what `packages/roachgraph` already does in TypeScript.

const std = @import("std");
const fx = @import("zigeffect");

pub const Allocator = std.mem.Allocator;

/// What a plan is written against: node kinds, typed fields, and directional
/// relations. Keeps store vocabulary out of the plan.
pub const Schema = @import("schema.zig");
/// Backend-neutral query plan. Pure data: build it anywhere, validate it on
/// arrival, lower it wherever.
pub const Plan = @import("plan.zig");
/// The connector boundary and the capability model that keeps it honest.
pub const Backend = @import("backend.zig");

pub const backends = struct {
    pub const embedded = @import("backends/embedded.zig");
    pub const cockroach = @import("backends/cockroach.zig");
};
pub const Effect = fx;

pub const CompilerEnv = fx.TestServices;
pub const CompilerError = error{ EmptySource, OutOfMemory };

pub const ValidationResult = struct {
    status: []const u8,
    bytes: usize,
};

pub const ValidateEffect = fx.Effect(ValidationResult, CompilerError, CompilerEnv);

pub fn validateCurrentSource() ValidateEffect {
    return ValidateEffect.fromFn(validateConfiguredSource);
}

fn validateConfiguredSource(ctx: *fx.Context(CompilerEnv)) CompilerError!ValidationResult {
    const config = ctx.service(fx.Config);
    const fs = ctx.service(fx.MemoryFileSystem);
    const schema_path = config.require("schema.path") catch return error.EmptySource;
    const source = fs.readFile(schema_path) orelse return error.EmptySource;
    return validateSource(ctx, source);
}

pub fn validateSource(
    ctx: *fx.Context(CompilerEnv),
    source: []const u8,
) CompilerError!ValidationResult {
    const logger = ctx.service(fx.Logger);
    const metrics = ctx.service(fx.Metrics);
    const tracing = ctx.service(fx.Tracing);

    try tracing.event("zgroach.validate.start");
    try metrics.increment("zgroach.validate.count", 1);

    const trimmed = std.mem.trim(u8, source, " \n\r\t");
    if (trimmed.len == 0) {
        try logger.info("zgroach.validate.empty");
        return error.EmptySource;
    }

    try logger.info("zgroach.validate.ok");
    return .{
        .status = "valid",
        .bytes = source.len,
    };
}

test {
    // Zig collects tests only from files the test root actually pulls in. A
    // `pub const X = @import(...)` is lazily analysed, so without this the
    // package's tests compile and silently never run — which is exactly what
    // happened before this block existed.
    _ = @import("schema.zig");
    _ = @import("plan.zig");
    _ = @import("backend.zig");
    _ = @import("backends/embedded.zig");
    _ = @import("backends/cockroach.zig");
}
