const std = @import("std");

/// Conservative boundary scanner for serialized evidence. It detects
/// credential-shaped material rather than harmless schema field names.
pub fn containsSensitiveMaterial(input: []const u8) bool {
    return containsInsensitive(input, "sentinel-secret") or
        containsInsensitive(input, "authorization:") or
        containsAssignment(input, "authorization") or
        containsInsensitive(input, "proxy-authorization:") or
        containsInsensitive(input, "bearer ") or
        containsInsensitive(input, "-----begin private key-----") or
        containsInsensitive(input, "-----begin rsa private key-----") or
        containsInsensitive(input, "-----begin ec private key-----") or
        containsInsensitive(input, "x-amz-security-token:") or
        containsAssignment(input, "password") or
        containsAssignment(input, "passwd") or
        containsAssignment(input, "token") or
        containsAssignment(input, "access_token") or
        containsAssignment(input, "refresh_token") or
        containsAssignment(input, "client_secret") or
        containsAssignment(input, "secret_key") or
        containsAssignment(input, "api_key") or
        containsSecretKeyPrefix(input) or
        containsAwsAccessKey(input) or
        containsUrlUserInfo(input);
}

fn containsAssignment(input: []const u8, name: []const u8) bool {
    var offset: usize = 0;
    while (offset + name.len <= input.len) : (offset += 1) {
        if (!eqlInsensitive(input[offset .. offset + name.len], name)) continue;
        if (offset > 0 and (std.ascii.isAlphanumeric(input[offset - 1]) or input[offset - 1] == '_')) continue;
        var cursor = offset + name.len;
        if (cursor < input.len and (std.ascii.isAlphanumeric(input[cursor]) or input[cursor] == '_')) continue;
        while (cursor < input.len and (input[cursor] == '"' or input[cursor] == '\'' or input[cursor] == ' ' or input[cursor] == '\t')) : (cursor += 1) {}
        if (cursor >= input.len or (input[cursor] != '=' and input[cursor] != ':')) continue;
        cursor += 1;
        while (cursor < input.len and (input[cursor] == '"' or input[cursor] == '\'' or input[cursor] == ' ' or input[cursor] == '\t')) : (cursor += 1) {}
        if (cursor >= input.len) continue;
        if (input[cursor] == 'n' and cursor + 4 <= input.len and eqlInsensitive(input[cursor .. cursor + 4], "null")) continue;
        return true;
    }
    return false;
}

fn containsSecretKeyPrefix(input: []const u8) bool {
    var offset: usize = 0;
    while (offset + 3 <= input.len) : (offset += 1) {
        if (!eqlInsensitive(input[offset .. offset + 3], "sk-")) continue;
        if (offset == 0 or !std.ascii.isAlphanumeric(input[offset - 1])) return true;
    }
    return false;
}

fn containsAwsAccessKey(input: []const u8) bool {
    var offset: usize = 0;
    while (offset + 20 <= input.len) : (offset += 1) {
        if (!(std.mem.startsWith(u8, input[offset..], "AKIA") or std.mem.startsWith(u8, input[offset..], "ASIA"))) continue;
        var valid = true;
        for (input[offset + 4 .. offset + 20]) |byte| {
            if (!((byte >= 'A' and byte <= 'Z') or std.ascii.isDigit(byte))) {
                valid = false;
                break;
            }
        }
        if (valid) return true;
    }
    return false;
}

fn containsUrlUserInfo(input: []const u8) bool {
    var search: usize = 0;
    while (std.mem.indexOfPos(u8, input, search, "://")) |scheme| {
        const authority_start = scheme + 3;
        const authority_end = std.mem.indexOfAnyPos(u8, input, authority_start, "/?# \t\r\n") orelse input.len;
        const authority = input[authority_start..authority_end];
        if (std.mem.indexOfScalar(u8, authority, '@')) |at| if (std.mem.indexOfScalar(u8, authority[0..at], ':') != null) return true;
        if (authority_end == input.len) break;
        search = authority_end + 1;
    }
    return false;
}

fn containsInsensitive(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0 or needle.len > haystack.len) return false;
    var index: usize = 0;
    while (index + needle.len <= haystack.len) : (index += 1) if (eqlInsensitive(haystack[index .. index + needle.len], needle)) return true;
    return false;
}

fn eqlInsensitive(left: []const u8, right: []const u8) bool {
    if (left.len != right.len) return false;
    for (left, right) |a, b| if (std.ascii.toLower(a) != std.ascii.toLower(b)) return false;
    return true;
}

test "secret scanner detects structured credentials without rejecting safe schema names" {
    const unsafe = [_][]const u8{ "postgresql://user:pass@db/orders", "{\"password\":\"hunter2\"}", "Authorization: Bearer abc", "client_secret=abc", "-----BEGIN PRIVATE KEY-----", "AKIAIOSFODNN7EXAMPLE" };
    for (unsafe) |value| try std.testing.expect(containsSensitiveMaterial(value));
    try std.testing.expect(!containsSensitiveMaterial("{\"password\":null,\"idempotency_key\":\"safe\",\"secret_reference\":\"secret://vault/db\"}"));
    try std.testing.expect(!containsSensitiveMaterial("{\"assetType\":\"certificatemanager.googleapis.com/DnsAuthorization\"}"));
}
