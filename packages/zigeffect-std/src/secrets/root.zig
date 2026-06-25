const std = @import("std");

pub const redacted = "[REDACTED]";

pub const SecretString = struct {
    value: []const u8,

    pub fn expose(self: SecretString) []const u8 {
        return self.value;
    }

    pub fn display(_: SecretString) []const u8 {
        return redacted;
    }
};

pub fn containsSecret(input: []const u8) bool {
    return containsInsensitive(input, "sentinel-secret") or
        containsInsensitive(input, "password=") or
        containsInsensitive(input, "token=") or
        containsInsensitive(input, "authorization:") or
        containsInsensitive(input, "bearer ") or
        containsInsensitive(input, "sk-") or
        containsUrlUserInfo(input);
}

pub fn redactAlloc(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    if (containsSecret(input)) return allocator.dupe(u8, redacted);
    return allocator.dupe(u8, input);
}

fn containsInsensitive(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (needle.len > haystack.len) return false;

    var index: usize = 0;
    while (index + needle.len <= haystack.len) : (index += 1) {
        if (eqlInsensitive(haystack[index .. index + needle.len], needle)) return true;
    }
    return false;
}

fn eqlInsensitive(left: []const u8, right: []const u8) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_byte, right_byte| {
        if (std.ascii.toLower(left_byte) != std.ascii.toLower(right_byte)) return false;
    }
    return true;
}

fn containsUrlUserInfo(input: []const u8) bool {
    const scheme = std.mem.indexOf(u8, input, "://") orelse return false;
    const authority_start = scheme + 3;
    const authority_end = if (std.mem.indexOfScalarPos(u8, input, authority_start, '/')) |slash|
        slash
    else
        input.len;
    const authority = input[authority_start..authority_end];
    const at_index = std.mem.indexOfScalar(u8, authority, '@') orelse return false;
    return std.mem.indexOfScalar(u8, authority[0..at_index], ':') != null;
}

test "Secrets redacts sentinel token password and auth URL" {
    const samples = [_][]const u8{
        "sentinel-secret-for-tests",
        "token=abc123",
        "password=hunter2",
        "authorization: Bearer abc123",
        "postgres://user:pass@localhost/db",
        "sk-project-key",
    };

    for (samples) |sample| {
        const redacted_text = try redactAlloc(std.testing.allocator, sample);
        defer std.testing.allocator.free(redacted_text);

        try std.testing.expectEqualStrings(redacted, redacted_text);
    }
}

test "SecretString never exposes raw display text" {
    const secret = SecretString{ .value = "sentinel-secret-for-tests" };

    try std.testing.expectEqualStrings("sentinel-secret-for-tests", secret.expose());
    try std.testing.expectEqualStrings(redacted, secret.display());
}
