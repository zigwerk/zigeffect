const std = @import("std");
const Contract = @import("contract.zig");

pub const SideEffect = enum { filesystem, network, process, environment, database, clock, randomness };
pub const Adapter = enum { fake, real };

pub const Request = struct {
    effect: SideEffect,
    adapter: Adapter,
    source: Contract.SourceReference = .{},
    causal_event_id: u64 = 0,
    reason: []const u8 = "",
};

pub const Decision = struct {
    effect: SideEffect,
    adapter: Adapter,
    allowed: bool,
    source: Contract.SourceReference,
    causal_event_id: u64,
};

/// Test policy is deny-by-default for real side effects. Fake adapters are
/// allowed; each real capability must be explicitly enabled.
pub const Firewall = struct {
    allocator: std.mem.Allocator,
    real_allowed: std.EnumSet(SideEffect) = .initEmpty(),
    decisions: std.ArrayList(Decision) = .empty,
    denied: usize = 0,

    pub fn init(allocator: std.mem.Allocator) Firewall {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Firewall) void {
        self.decisions.deinit(self.allocator);
    }

    pub fn allowReal(self: *Firewall, effect: SideEffect) void {
        self.real_allowed.insert(effect);
    }

    pub fn authorize(self: *Firewall, request: Request) !void {
        try request.source.validate();
        for (self.decisions.items) |decision| {
            if (decision.effect == request.effect and decision.adapter == request.adapter and
                decision.causal_event_id == request.causal_event_id and
                std.mem.eql(u8, decision.source.path, request.source.path) and decision.source.line == request.source.line)
                return error.DuplicateDecision;
        }
        const allowed = request.adapter == .fake or self.real_allowed.contains(request.effect);
        try self.decisions.append(self.allocator, .{
            .effect = request.effect,
            .adapter = request.adapter,
            .allowed = allowed,
            .source = request.source,
            .causal_event_id = request.causal_event_id,
        });
        if (!allowed) {
            self.denied += 1;
            return error.SideEffectDenied;
        }
    }

    pub fn evidenceSummary(self: Firewall) Contract.EvidenceSummary {
        const count = self.decisions.items.len;
        return .{
            .attempted = true,
            .status = if (self.denied == 0) .passed else .failed,
            .planned = count,
            .executed = count,
            .passed = count - self.denied,
            .failed = self.denied,
        };
    }

    pub fn jsonAlloc(self: Firewall, allocator: std.mem.Allocator) ![]u8 {
        return std.json.Stringify.valueAlloc(allocator, .{
            .schema = "zigeffect.test-sandbox.v1",
            .status = @tagName(self.evidenceSummary().status),
            .denied = self.denied,
            .decisions = self.decisions.items,
            .limitation = "Direct OS calls outside guarded adapters cannot be intercepted by the ZigEffect library.",
        }, .{});
    }
};

test "sandbox allows fakes and explicitly granted real adapters but denies real by default" {
    var firewall = Firewall.init(std.testing.allocator);
    defer firewall.deinit();
    try firewall.authorize(.{ .effect = .network, .adapter = .fake, .causal_event_id = 1 });
    try std.testing.expectError(error.SideEffectDenied, firewall.authorize(.{ .effect = .network, .adapter = .real, .causal_event_id = 2 }));
    firewall.allowReal(.database);
    try firewall.authorize(.{ .effect = .database, .adapter = .real, .causal_event_id = 3 });
    try std.testing.expectEqual(Contract.TestStatus.failed, firewall.evidenceSummary().status);
}

test "sandbox rejects duplicate causal decisions" {
    var firewall = Firewall.init(std.testing.allocator);
    defer firewall.deinit();
    const request = Request{ .effect = .clock, .adapter = .fake, .causal_event_id = 9 };
    try firewall.authorize(request);
    try std.testing.expectError(error.DuplicateDecision, firewall.authorize(request));
}
