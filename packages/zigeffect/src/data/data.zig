pub fn isTaggedUnion(comptime T: type) bool {
    return @typeInfo(T) == .@"union" and @typeInfo(T).@"union".tag_type != null;
}
