pub const Ordering = enum { less, equal, greater };

pub fn compare(comptime T: type, lhs: T, rhs: T) Ordering {
    if (comptime hasDecl(T, "compare")) {
        return T.compare(lhs, rhs);
    }

    if (lhs < rhs) return .less;
    if (lhs > rhs) return .greater;
    return .equal;
}

fn hasDecl(comptime T: type, comptime name: []const u8) bool {
    return switch (@typeInfo(T)) {
        .@"struct", .@"union", .@"enum", .@"opaque" => @hasDecl(T, name),
        else => false,
    };
}
