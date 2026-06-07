pub fn Redacted(comptime T: type) type {
    return struct {
        value: T,
    };
}
