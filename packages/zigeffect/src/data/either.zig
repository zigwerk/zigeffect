pub fn Either(comptime Right: type, comptime Left: type) type {
    return union(enum) {
        left: Left,
        right: Right,
    };
}
