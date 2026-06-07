pub const Pattern = union(enum) {
    wildcard,
    bind: []const u8,
    range: Range,
};

pub const RangeMode = enum {
    inclusive,
    exclusive,
    inclusive_min,
    inclusive_max,
};

pub const Range = struct {
    mode: RangeMode,
    min: i128,
    max: i128,
};

pub const any = Pattern.wildcard;

pub fn bind(comptime name: []const u8) Pattern {
    return .{ .bind = name };
}

pub fn range(comptime mode: RangeMode, min: anytype, max: anytype) Pattern {
    return .{ .range = .{ .mode = mode, .min = min, .max = max } };
}

pub fn matches(value: anytype, pattern: anytype) bool {
    _ = value;
    _ = pattern;
    return false;
}

pub fn capture(value: anytype, pattern: anytype) ?void {
    _ = value;
    _ = pattern;
    return null;
}
