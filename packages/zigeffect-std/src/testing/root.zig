const std = @import("std");
const Secrets = @import("../secrets/root.zig");

pub const TestingError = error{SecretLeak};

pub fn assertEqualJson(expected: []const u8, actual: []const u8) !void {
    try std.testing.expectEqualStrings(expected, actual);
}

pub fn assertNoSentinelSecrets(text: []const u8) TestingError!void {
    if (Secrets.containsSecret(text)) return TestingError.SecretLeak;
}

test "Testing assertNoSentinelSecrets catches leaks" {
    try assertNoSentinelSecrets("plain text");
    try std.testing.expectError(TestingError.SecretLeak, assertNoSentinelSecrets("sentinel-secret-for-tests"));
}
