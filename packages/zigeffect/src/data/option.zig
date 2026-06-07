pub fn Option(comptime T: type) type {
    return union(enum) {
        none,
        some: T,
    };
}
