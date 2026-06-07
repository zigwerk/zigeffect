const match_mod = @import("../match/root.zig");

pub fn Option(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Tag = enum { none, some };
        pub const State = union(Tag) {
            none,
            some: T,
        };

        state: State,

        pub fn some(value: T) Self {
            return .{ .state = .{ .some = value } };
        }

        pub fn none() Self {
            return .{ .state = .none };
        }

        pub fn fromNullable(value: ?T) Self {
            if (value) |inner| return some(inner);
            return none();
        }

        pub fn isSome(self: Self) bool {
            return switch (self.state) {
                .some => true,
                .none => false,
            };
        }

        pub fn isNone(self: Self) bool {
            return !self.isSome();
        }

        pub fn map(self: Self, comptime U: type, f: anytype) Option(U) {
            return switch (self.state) {
                .some => |value| Option(U).some(f(value)),
                .none => Option(U).none(),
            };
        }

        pub fn flatMap(self: Self, comptime U: type, f: anytype) Option(U) {
            return switch (self.state) {
                .some => |value| f(value),
                .none => Option(U).none(),
            };
        }

        pub fn getOrElse(self: Self, default: T) T {
            return switch (self.state) {
                .some => |value| value,
                .none => default,
            };
        }

        pub fn valueOrNull(self: Self) ?T {
            return switch (self.state) {
                .some => |value| value,
                .none => null,
            };
        }

        pub fn match(self: Self, comptime Return: type, handlers: anytype) Return {
            return match_mod.exhaustive(Return, self.state, handlers);
        }
    };
}
