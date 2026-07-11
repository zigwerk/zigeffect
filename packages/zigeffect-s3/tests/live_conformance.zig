const std = @import("std");
const s3 = @import("zigeffect_s3");
const options = @import("live_options");

const Credentials = struct {
    access_key: []u8,
    secret_key: []u8,

    fn init() !Credentials {
        return .{
            .access_key = try std.process.Environ.getAlloc(std.testing.environ, std.testing.allocator, "ZIGEFFECT_TEST_S3_ACCESS_KEY"),
            .secret_key = try std.process.Environ.getAlloc(std.testing.environ, std.testing.allocator, "ZIGEFFECT_TEST_S3_SECRET_KEY"),
        };
    }

    fn deinit(self: *Credentials) void {
        std.crypto.secureZero(u8, self.secret_key);
        std.testing.allocator.free(self.access_key);
        std.testing.allocator.free(self.secret_key);
    }
};

test "live MinIO object storage contract" {
    var credentials = try Credentials.init();
    defer credentials.deinit();
    var client = try s3.Client.init(std.testing.allocator, std.testing.io, .{
        .port = options.port,
        .bucket = "zigeffect",
        .access_key = credentials.access_key,
        .secret_key = credentials.secret_key,
    });
    defer client.deinit();
    try s3.zstd.ObjectStorage.conform(client.asObjectStorage(), std.testing.allocator);
    try std.testing.expect(try client.delete("attachments/a.txt"));
}

test "live MinIO rejects invalid credentials" {
    var credentials = try Credentials.init();
    defer credentials.deinit();
    const invalid = try std.fmt.allocPrint(std.testing.allocator, "{s}-invalid", .{credentials.secret_key});
    defer {
        std.crypto.secureZero(u8, invalid);
        std.testing.allocator.free(invalid);
    }
    var client = try s3.Client.init(std.testing.allocator, std.testing.io, .{
        .port = options.port,
        .bucket = "zigeffect",
        .access_key = credentials.access_key,
        .secret_key = invalid,
    });
    defer client.deinit();
    try std.testing.expectError(error.S3PermissionDenied, client.getAlloc(std.testing.allocator, "missing"));
}
