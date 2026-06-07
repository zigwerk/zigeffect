pub fn Either(comptime Right: type, comptime Left: type) type {
    return struct {
        const Self = @This();

        pub const Tag = enum { left, right };
        pub const State = union(Tag) {
            left: Left,
            right: Right,
        };

        state: State,

        pub fn left(value: Left) Self {
            return .{ .state = .{ .left = value } };
        }

        pub fn right(value: Right) Self {
            return .{ .state = .{ .right = value } };
        }

        pub fn isLeft(self: Self) bool {
            return switch (self.state) {
                .left => true,
                .right => false,
            };
        }

        pub fn isRight(self: Self) bool {
            return !self.isLeft();
        }

        pub fn map(self: Self, comptime NewRight: type, f: anytype) Either(NewRight, Left) {
            return switch (self.state) {
                .right => |value| Either(NewRight, Left).right(f(value)),
                .left => |value| Either(NewRight, Left).left(value),
            };
        }

        pub fn mapLeft(self: Self, comptime NewLeft: type, f: anytype) Either(Right, NewLeft) {
            return switch (self.state) {
                .right => |value| Either(Right, NewLeft).right(value),
                .left => |value| Either(Right, NewLeft).left(f(value)),
            };
        }

        pub fn flatMap(self: Self, comptime NewRight: type, f: anytype) Either(NewRight, Left) {
            return switch (self.state) {
                .right => |value| f(value),
                .left => |value| Either(NewRight, Left).left(value),
            };
        }

        pub fn getOrElse(self: Self, default: Right) Right {
            return switch (self.state) {
                .right => |value| value,
                .left => default,
            };
        }

        pub fn rightOrNull(self: Self) ?Right {
            return switch (self.state) {
                .right => |value| value,
                .left => null,
            };
        }

        pub fn leftOrNull(self: Self) ?Left {
            return switch (self.state) {
                .right => null,
                .left => |value| value,
            };
        }
    };
}
