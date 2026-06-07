pub fn isTaggedUnion(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"union" => |union_info| union_info.tag_type != null,
        else => false,
    };
}
