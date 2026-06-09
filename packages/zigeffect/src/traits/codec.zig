const std = @import("std");

pub const CodecError = error{
    InvalidEncoding,
    UnsupportedCodec,
};

pub fn Codec(comptime Value: type) type {
    return struct {
        const Self = @This();

        encode: *const fn (std.mem.Allocator, Value) anyerror![]const u8,
        decode: *const fn (std.mem.Allocator, []const u8) anyerror!Value,

        pub fn encodeValue(self: Self, allocator: std.mem.Allocator, value: Value) anyerror![]const u8 {
            return self.encode(allocator, value);
        }

        pub fn decodeValue(self: Self, allocator: std.mem.Allocator, bytes: []const u8) anyerror!Value {
            return self.decode(allocator, bytes);
        }
    };
}
