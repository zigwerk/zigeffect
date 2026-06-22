//! M8.3 + M14.1 — engine-side remediation policy tests.

const std = @import("std");
const fx = @import("zigeffect");

fn req(kind: fx.RemediationKind) fx.RemediationRequest {
    return .{ .kind = kind, .target_fiber_id = 7, .reason = "test" };
}

test "default policy: every kind is record-only (needs_human_review)" {
    const engine = fx.PolicyEngine{}; // master gate OFF, all kinds default
    inline for (.{ .retry, .interrupt, .replace_provider, .replay_scenario }) |kind| {
        const d = engine.decide(req(kind));
        try std.testing.expectEqual(fx.PolicyDecision.needs_human_review, d.decision);
        try std.testing.expectEqual(kind, d.kind);
    }
}

test "always_reject overrides the master gate (explicit deny even when apply disabled)" {
    const engine = (fx.PolicyEngine{})
        .withKindPolicy(.interrupt, .always_reject);
    const d = engine.decide(req(.interrupt));
    try std.testing.expectEqual(fx.PolicyDecision.reject, d.decision);
}

test "gate ON + auto_approve → approve" {
    const engine = (fx.PolicyEngine{})
        .withApplyEnabled(true)
        .withKindPolicy(.retry, .auto_approve);
    const d = engine.decide(req(.retry));
    try std.testing.expectEqual(fx.PolicyDecision.approve, d.decision);
}

test "gate ON + needs_human_review (unconfigured kind) → needs_human_review" {
    const engine = (fx.PolicyEngine{})
        .withApplyEnabled(true)
        .withKindPolicy(.retry, .auto_approve); // only retry opted in
    // interrupt was never opted in → still needs review even with gate on.
    const d = engine.decide(req(.interrupt));
    try std.testing.expectEqual(fx.PolicyDecision.needs_human_review, d.decision);
}

test "SAFETY: master gate OFF dominates an auto_approve kind (record-only is enforced)" {
    // An operator opted `retry` into auto_approve, but forgot to flip the
    // master gate. The engine MUST still refuse to auto-approve — this is the
    // load-bearing Working-Default-#1 safety property.
    const engine = (fx.PolicyEngine{})
        .withKindPolicy(.retry, .auto_approve); // apply_enabled stays false
    const d = engine.decide(req(.retry));
    try std.testing.expectEqual(fx.PolicyDecision.needs_human_review, d.decision);
}

test "always_reject still rejects even with the master gate ON" {
    const engine = (fx.PolicyEngine{})
        .withApplyEnabled(true)
        .withKindPolicy(.replace_provider, .always_reject);
    const d = engine.decide(req(.replace_provider));
    try std.testing.expectEqual(fx.PolicyDecision.reject, d.decision);
}

test "per-kind policies are independent (one auto_approve doesn't leak to siblings)" {
    const engine = (fx.PolicyEngine{})
        .withApplyEnabled(true)
        .withKindPolicy(.replay_scenario, .auto_approve);
    try std.testing.expectEqual(fx.PolicyDecision.approve, engine.decide(req(.replay_scenario)).decision);
    // The other three remain at the default needs_human_review.
    try std.testing.expectEqual(fx.PolicyDecision.needs_human_review, engine.decide(req(.retry)).decision);
    try std.testing.expectEqual(fx.PolicyDecision.needs_human_review, engine.decide(req(.interrupt)).decision);
    try std.testing.expectEqual(fx.PolicyDecision.needs_human_review, engine.decide(req(.replace_provider)).decision);
}
