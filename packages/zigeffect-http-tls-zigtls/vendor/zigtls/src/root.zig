//! zigtls library root.
const std = @import("std");

pub const tls13 = @import("tls13.zig");
pub const quic = @import("quic.zig");
pub const termination = @import("termination.zig");
pub const adapter = @import("adapter.zig");
pub const cert_reload = @import("cert_reload.zig");
pub const rate_limit = @import("rate_limit.zig");
pub const metrics = @import("metrics.zig");

pub fn version() []const u8 {
    return "0.1.0-dev";
}

test "library root is wired" {
    try std.testing.expect(version().len > 0);
    std.testing.refAllDecls(quic);
    std.testing.refAllDecls(termination);
    std.testing.refAllDecls(adapter);
    std.testing.refAllDecls(cert_reload);
    std.testing.refAllDecls(rate_limit);
    std.testing.refAllDecls(metrics);
    std.testing.refAllDecls(tls13.alerts);
    std.testing.refAllDecls(tls13.certificate_validation);
    std.testing.refAllDecls(tls13.early_data);
    std.testing.refAllDecls(tls13.fuzz);
    std.testing.refAllDecls(tls13.handshake);
    std.testing.refAllDecls(tls13.keyschedule);
    std.testing.refAllDecls(tls13.messages);
    std.testing.refAllDecls(tls13.ocsp);
    std.testing.refAllDecls(tls13.record);
    std.testing.refAllDecls(tls13.session);
    std.testing.refAllDecls(tls13.state);
    std.testing.refAllDecls(tls13.ticket_keys);
    std.testing.refAllDecls(tls13.trust_store);
}
