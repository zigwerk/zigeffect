const std = @import("std");
const zstd = @import("zigeffect_std");

pub const Grpc = zstd.Grpc;

fn container(encoding: Grpc.Compression) !std.compress.flate.Container {
    return switch (encoding) {
        .identity => error.IdentityHasNoContainer,
        .gzip => .gzip,
        .deflate => .zlib,
    };
}

pub fn compressAlloc(allocator: std.mem.Allocator, encoding: Grpc.Compression, input: []const u8, max_output_bytes: usize) ![]u8 {
    if (input.len > max_output_bytes) return error.MessageTooLarge;
    if (encoding == .identity) return allocator.dupe(u8, input);
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    try output.ensureUnusedCapacity(64);
    const work = try allocator.alloc(u8, std.compress.flate.max_window_len);
    defer allocator.free(work);
    const compressor = try allocator.create(std.compress.flate.Compress);
    defer allocator.destroy(compressor);
    compressor.* = try std.compress.flate.Compress.init(&output.writer, work, try container(encoding), .default);
    try compressor.writer.writeAll(input);
    try compressor.finish();
    if (output.written().len > max_output_bytes) return error.MessageTooLarge;
    return output.toOwnedSlice();
}

pub fn decompressAlloc(allocator: std.mem.Allocator, encoding: Grpc.Compression, input: []const u8, max_output_bytes: usize) ![]u8 {
    if (encoding == .identity) {
        if (input.len > max_output_bytes) return error.MessageTooLarge;
        return allocator.dupe(u8, input);
    }
    const output = try allocator.alloc(u8, max_output_bytes);
    errdefer allocator.free(output);
    var writer: std.Io.Writer = .fixed(output);
    var reader: std.Io.Reader = .fixed(input);
    var decompressor: std.compress.flate.Decompress = .init(&reader, try container(encoding), &.{});
    _ = decompressor.reader.streamRemaining(&writer) catch |err| switch (err) {
        error.WriteFailed => return error.MessageTooLarge,
        error.ReadFailed => return error.InvalidCompressedMessage,
    };
    return allocator.realloc(output, writer.end);
}

test "bounded decompression rejects expansion beyond its contract" {
    const compressed = try compressAlloc(std.testing.allocator, .gzip, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", 128);
    defer std.testing.allocator.free(compressed);
    try std.testing.expectError(error.MessageTooLarge, decompressAlloc(std.testing.allocator, .gzip, compressed, 8));
}

test "malformed compressed input remains a typed failure" {
    try std.testing.expectError(error.InvalidCompressedMessage, decompressAlloc(std.testing.allocator, .gzip, "not-gzip", 128));
}
