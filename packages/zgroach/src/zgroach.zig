const std = @import("std");
const fx = @import("zigeffect");

pub const Allocator = std.mem.Allocator;
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
