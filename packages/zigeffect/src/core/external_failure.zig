const std = @import("std");

pub const ExternalFailureClass = enum {
    timeout,
    unavailable,
    unauthorized,
    conflict,
    capacity,
    canceled,
    corrupt_data,
    unsupported,
    internal,

    pub fn retryable(self: ExternalFailureClass) bool {
        return switch (self) {
            .timeout, .unavailable, .conflict, .capacity => true,
            .unauthorized, .canceled, .corrupt_data, .unsupported, .internal => false,
        };
    }
};

pub fn classifyExternalError(err: anyerror) ExternalFailureClass {
    const name = @errorName(err);
    if (containsAny(name, &.{ "Timeout", "TimedOut", "Deadline" })) return .timeout;
    if (containsAny(name, &.{ "Connection", "Unavailable", "Refused", "Unreachable", "Closed", "Reset" })) return .unavailable;
    if (containsAny(name, &.{ "Unauthorized", "Forbidden", "Authentication", "PermissionDenied" })) return .unauthorized;
    if (containsAny(name, &.{ "Conflict", "Serialization", "AlreadyExists", "Stale" })) return .conflict;
    if (containsAny(name, &.{ "Capacity", "Full", "Exhausted", "LimitExceeded", "Backpressured", "TooMany", "OutOfMemory", "PayloadTooLarge" })) return .capacity;
    if (containsAny(name, &.{ "Canceled", "Cancelled", "Interrupted" })) return .canceled;
    if (containsAny(name, &.{ "Corrupt", "InvalidData", "Malformed", "Checksum", "Incompatible" })) return .corrupt_data;
    if (containsAny(name, &.{ "Unsupported", "NotImplemented" })) return .unsupported;
    return .internal;
}

fn containsAny(value: []const u8, needles: []const []const u8) bool {
    for (needles) |needle| if (std.mem.indexOf(u8, value, needle) != null) return true;
    return false;
}

test "external failure classifications have stable retry posture" {
    try std.testing.expectEqual(ExternalFailureClass.timeout, classifyExternalError(error.TransportTimeout));
    try std.testing.expectEqual(ExternalFailureClass.unauthorized, classifyExternalError(error.TransportUnauthorized));
    try std.testing.expectEqual(ExternalFailureClass.capacity, classifyExternalError(error.TransportBackpressured));
    try std.testing.expect(!ExternalFailureClass.unauthorized.retryable());
}
