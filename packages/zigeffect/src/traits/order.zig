pub const Ordering = enum { less, equal, greater };

pub fn compare(comptime T: type, lhs: T, rhs: T) Ordering {
    if (lhs < rhs) return .less;
    if (lhs > rhs) return .greater;
    return .equal;
}
