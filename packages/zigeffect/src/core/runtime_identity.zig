const std = @import("std");

/// Compiler-generated generic type names are useful while they remain small,
/// but deeply composed effects can exceed the causal recorder's explicit
/// string bound. Preserve a readable outer constructor plus a stable digest
/// instead of allowing framework-owned structural events to be truncated.
pub const max_runtime_type_bytes: usize = 160;

pub fn boundedTypeName(comptime T: type) []const u8 {
    const full = comptime @typeName(T);
    if (full.len <= max_runtime_type_bytes) return full;

    const constructor_end = comptime std.mem.indexOfScalar(u8, full, '(') orelse @min(full.len, 96);
    const readable_end = comptime @min(constructor_end, 96);
    const digest = comptime digest: {
        @setEvalBranchQuota(1_000_000);
        break :digest std.hash.Wyhash.hash(0, full);
    };
    return comptime std.fmt.comptimePrint("{s}#{x}", .{ full[0..readable_end], digest });
}

pub fn effectLabel(effect: anytype) []const u8 {
    const EffectType = @TypeOf(effect);
    if (comptime @hasDecl(EffectType, "runtimeLabel")) return effect.runtimeLabel();
    return boundedTypeName(EffectType);
}
