const std = @import("std");
const Secrets = @import("../secrets/root.zig");
const fx = @import("zigeffect");

pub const max_text_bytes: usize = 4096;

pub const Class = fx.ExternalFailureClass;

pub const Failure = struct {
    backend: []const u8,
    operation: []const u8,
    class: Class,
    detail: []const u8 = "",
    cause: []const u8 = "",
    retry_after_ms: ?u64 = null,

    pub fn init(
        backend: []const u8,
        operation: []const u8,
        class: Class,
        detail: []const u8,
        cause: []const u8,
    ) Failure {
        return .{
            .backend = safeText(backend),
            .operation = safeText(operation),
            .class = class,
            .detail = safeText(detail),
            .cause = safeText(cause),
        };
    }

    pub fn fromError(backend: []const u8, operation: []const u8, err: anyerror) Failure {
        return init(backend, operation, classifyError(err), @errorName(err), @errorName(err));
    }

    pub fn retryable(self: Failure) bool {
        return self.class.retryable();
    }

    pub fn validate(self: Failure) !void {
        if (self.backend.len == 0 or self.operation.len == 0) return error.InvalidFailure;
        inline for (.{ self.backend, self.operation, self.detail, self.cause }) |value| {
            if (value.len > max_text_bytes) return error.FailureTooLarge;
            if (Secrets.containsSecret(value)) return error.SecretDetected;
        }
    }

    pub fn jsonAlloc(self: Failure, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        return Secrets.safeJsonAlloc(allocator, self, .{ .emit_null_optional_fields = false });
    }
};

pub fn Result(comptime Success: type) type {
    return union(enum) {
        success: Success,
        failure: Failure,
    };
}

pub fn classifyError(err: anyerror) Class {
    return fx.classifyExternalError(err);
}

fn safeText(value: []const u8) []const u8 {
    if (Secrets.containsSecret(value)) return Secrets.redacted;
    if (value.len > max_text_bytes) return "[TRUNCATED]";
    return value;
}

test "external failures classify recovery without backend string matching" {
    try std.testing.expect(Class == fx.ExternalFailureClass);
    const expected = [_]Class{
        .timeout,
        .unavailable,
        .unauthorized,
        .conflict,
        .capacity,
        .canceled,
        .corrupt_data,
        .unsupported,
        .internal,
    };
    try std.testing.expectEqual(@as(usize, 9), expected.len);
    try std.testing.expect(Class.timeout.retryable());
    try std.testing.expect(Class.unavailable.retryable());
    try std.testing.expect(!Class.unauthorized.retryable());
    try std.testing.expect(!Class.corrupt_data.retryable());

    const failure = Failure.fromError("postgres", "query", error.ConnectionRefused);
    try std.testing.expectEqual(Class.unavailable, failure.class);
    try std.testing.expect(failure.retryable());
}

test "external failure detail and cause stay bounded and redacted" {
    const failure = Failure.init(
        "billing",
        "charge",
        .unauthorized,
        "authorization: Bearer sentinel-secret-for-tests",
        "token=sentinel-secret-for-tests",
    );
    try failure.validate();
    try std.testing.expectEqualStrings("[REDACTED]", failure.detail);
    try std.testing.expectEqualStrings("[REDACTED]", failure.cause);

    const json = try failure.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "sentinel-secret") == null);
}
