const traits = @import("../traits/root.zig");

pub fn Redacted(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T,

        pub fn make(value: T) Self {
            return .{ .value = value };
        }

        pub fn unsafeValue(self: Self) T {
            return self.value;
        }

        pub fn redactedText(_: Self) []const u8 {
            return traits.redaction_marker;
        }
    };
}
