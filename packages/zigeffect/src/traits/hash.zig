pub fn hash(comptime T: type, value: T) u64 {
    _ = value;
    return @intFromPtr(@typeName(T).ptr);
}
