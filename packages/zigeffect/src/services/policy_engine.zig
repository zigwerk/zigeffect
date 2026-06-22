//! M8.3 + M14.1 — engine-side remediation policy.
//!
//! This is the binding, in-memory decision the runtime consults before it would
//! ever execute a bounded remediation an agent requested (Track 8 / Track 14 —
//! the closed agent loop). It is distinct from the JSON-artifact CI policy in
//! `tools/causal_policy_decision.zig` (which grades a remediation proposal from
//! recorded artifacts): this one is a fast, allocation-free runtime gate.
//!
//! SAFETY POSTURE (Working Default #1 of the vision-completion roadmap): the
//! master `apply_enabled` gate is OFF by default, so the runtime NEVER
//! auto-approves an action — the machinery exists but stays record-only until
//! an operator both flips the master gate AND opts a specific kind into
//! `auto_approve`. An explicit `always_reject` overrides everything.

const std = @import("std");
const causal = @import("causal.zig");

pub const CausalStore = causal.CausalStore;

/// The bounded set of remediation actions an agent may request the runtime to
/// perform. Each maps to a Phase-8 executable action:
///   - `retry`            — re-run a failed fiber under a schedule
///   - `interrupt`        — cancel a wedged fiber (via FiberExecutor.interrupt, M7.8)
///   - `replace_provider` — swap a layer's implementation
///   - `replay_scenario`  — re-run a recorded scenario to a point
pub const RemediationKind = enum {
    retry,
    interrupt,
    replace_provider,
    replay_scenario,
};

/// A bounded remediation request (M14.1). Targets are causal identifiers so the
/// decision and any later apply stay traceable in the causal graph.
pub const RemediationRequest = struct {
    kind: RemediationKind,
    target_fiber_id: ?u64 = null,
    target_scope_id: ?u64 = null,
    target_run_id: ?u64 = null,
    /// Redaction-safe label describing why the agent requested this action.
    reason: []const u8 = "",
};

/// The binding decision. `approve` means the apply-boundary MAY execute the
/// action; `reject` means it must not; `needs_human_review` means the engine
/// records the proposal but a human must approve it out-of-band.
pub const PolicyDecision = enum {
    approve,
    reject,
    needs_human_review,
};

pub const Decision = struct {
    decision: PolicyDecision,
    kind: RemediationKind,
    /// Static, redaction-safe explanation (no allocation; safe to log).
    reason: []const u8,
};

/// Per-kind operator policy. Default is `needs_human_review` (record-only).
pub const KindPolicy = enum { needs_human_review, auto_approve, always_reject };

/// Engine-side remediation policy gate.
pub const PolicyEngine = struct {
    /// Master gate (Working Default #1). When false (the default), NO action is
    /// ever auto-approved regardless of per-kind config.
    apply_enabled: bool = false,
    retry_policy: KindPolicy = .needs_human_review,
    interrupt_policy: KindPolicy = .needs_human_review,
    replace_provider_policy: KindPolicy = .needs_human_review,
    replay_scenario_policy: KindPolicy = .needs_human_review,

    fn policyFor(self: PolicyEngine, kind: RemediationKind) KindPolicy {
        return switch (kind) {
            .retry => self.retry_policy,
            .interrupt => self.interrupt_policy,
            .replace_provider => self.replace_provider_policy,
            .replay_scenario => self.replay_scenario_policy,
        };
    }

    /// The binding decision for a request. Allocation-free, pure.
    pub fn decide(self: PolicyEngine, request: RemediationRequest) Decision {
        const kind_policy = self.policyFor(request.kind);

        // An explicit deny overrides everything, including the master gate.
        if (kind_policy == .always_reject) {
            return .{ .decision = .reject, .kind = request.kind, .reason = "kind explicitly rejected by operator policy" };
        }

        // Master gate OFF (default): record-only — nothing auto-approves, even
        // a kind the operator opted into auto_approve. This is the load-bearing
        // safety property of v1.
        if (!self.apply_enabled) {
            return .{ .decision = .needs_human_review, .kind = request.kind, .reason = "apply boundary disabled (record-only posture); human approval required" };
        }

        // Master gate ON: per-kind config decides.
        return switch (kind_policy) {
            .auto_approve => .{ .decision = .approve, .kind = request.kind, .reason = "kind auto-approved by operator policy" },
            .needs_human_review => .{ .decision = .needs_human_review, .kind = request.kind, .reason = "kind not opted into auto-approval" },
            .always_reject => unreachable, // handled above
        };
    }

    // ── Builders (value semantics, like the runtime builders) ──

    pub fn withApplyEnabled(self: PolicyEngine, enabled: bool) PolicyEngine {
        var engine = self;
        engine.apply_enabled = enabled;
        return engine;
    }

    pub fn withKindPolicy(self: PolicyEngine, kind: RemediationKind, policy: KindPolicy) PolicyEngine {
        var engine = self;
        switch (kind) {
            .retry => engine.retry_policy = policy,
            .interrupt => engine.interrupt_policy = policy,
            .replace_provider => engine.replace_provider_policy = policy,
            .replay_scenario => engine.replay_scenario_policy = policy,
        }
        return engine;
    }

    /// Decide AND record the request + decision into the causal graph so an
    /// agent can later query proposed remediations and their verdicts. Emits
    /// `remediation_requested` → `remediation_decided{cause = requested}`, with
    /// the decision's verdict as the status. Returns the Decision; the
    /// `remediation_decided` event id is available by querying the store.
    pub fn decideAndRecord(self: PolicyEngine, store: *CausalStore, request: RemediationRequest) Decision {
        const decision = self.decide(request);
        recordDecision(store, request, decision);
        return decision;
    }
};

/// Record a remediation request + its decision into the causal graph. The
/// `remediation_decided` event's `cause_event_id` points at the
/// `remediation_requested` event — the load-bearing edge for "why was this
/// remediation approved/denied?" queries. Best-effort: record failures are
/// swallowed (the decision itself is already returned to the caller).
pub fn recordDecision(store: *CausalStore, request: RemediationRequest, decision: Decision) void {
    const requested = store.record(.{
        .kind = .remediation_requested,
        .run_id = request.target_run_id,
        .scope_id = request.target_scope_id,
        .fiber_id = request.target_fiber_id,
        .status = "proposed",
        .label = request.reason,
        .type_name = @tagName(request.kind),
    }) catch return;

    _ = store.record(.{
        .kind = .remediation_decided,
        .run_id = request.target_run_id,
        .scope_id = request.target_scope_id,
        .fiber_id = request.target_fiber_id,
        .parent_id = requested,
        .cause_event_id = requested,
        .status = @tagName(decision.decision),
        .label = decision.reason,
        .type_name = @tagName(request.kind),
    }) catch {};
}
