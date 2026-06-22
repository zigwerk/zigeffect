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
        _ = recordDecision(store, request, decision);
        return decision;
    }
};

/// Record a remediation request + its decision into the causal graph. The
/// `remediation_decided` event's `cause_event_id` points at the
/// `remediation_requested` event — the load-bearing edge for "why was this
/// remediation approved/denied?" queries. Returns the `remediation_decided`
/// event id (null if no store / record failed) so the apply step can chain its
/// `remediation_applied` cause edge to it.
pub fn recordDecision(store: *CausalStore, request: RemediationRequest, decision: Decision) ?u64 {
    const requested = store.record(.{
        .kind = .remediation_requested,
        .run_id = request.target_run_id,
        .scope_id = request.target_scope_id,
        .fiber_id = request.target_fiber_id,
        .status = "proposed",
        .label = request.reason,
        .type_name = @tagName(request.kind),
    }) catch return null;

    return store.record(.{
        .kind = .remediation_decided,
        .run_id = request.target_run_id,
        .scope_id = request.target_scope_id,
        .fiber_id = request.target_fiber_id,
        .parent_id = requested,
        .cause_event_id = requested,
        .status = @tagName(decision.decision),
        .label = decision.reason,
        .type_name = @tagName(request.kind),
    }) catch null;
}

// ─── M8.13 — the apply boundary ──────────────────────────────────────────────
//
// The convergence of the decision (PolicyEngine), the cancel capability
// (FiberExecutor.interrupt, M7.8), and structural verification
// (causalStructurallyEquivalent, M5/H5). It is the state machine that earns
// `applied=true` — and ONLY earns it when BOTH (a) the policy approved the
// action AND (b) a re-captured trace proves the fix. The concrete action and
// verifier are injected so the boundary stays testable without the full runtime
// and so callers wire kind-specific execution (interrupt → FiberExecutor.interrupt,
// retry → re-run under a schedule, etc.).

pub const ApplyOutcome = enum {
    /// Policy did not approve — nothing executed.
    declined,
    /// Approved and executed, but the action itself failed.
    action_failed,
    /// Approved and executed, but verification did NOT prove the fix → applied=false.
    applied_unverified,
    /// Approved, executed, AND verification proved the fix → applied=true.
    applied,
};

pub const ApplyResult = struct {
    outcome: ApplyOutcome,
    decision: PolicyDecision,
    kind: RemediationKind,
    reason: []const u8,

    /// The single bit the whole machinery exists to gate. True ONLY for
    /// `ApplyOutcome.applied`.
    pub fn isApplied(self: ApplyResult) bool {
        return self.outcome == .applied;
    }
};

/// Perform the remediation. Returns whether the ACTION itself succeeded (not
/// whether it fixed anything — that is the verifier's job).
pub const ActionFn = *const fn (?*anyopaque, RemediationRequest) bool;

/// Re-capture system state and return whether the fix is structurally proven
/// (e.g. `causalStructurallyEquivalent` vs a known-good shape, or a
/// causal-compare verdict of `improved`).
pub const VerifyFn = *const fn (?*anyopaque) bool;

/// The apply boundary: decide → (if approved) execute → verify → record.
pub const ApplyBoundary = struct {
    engine: PolicyEngine,
    action: ActionFn,
    verify: VerifyFn,
    action_context: ?*anyopaque = null,
    verify_context: ?*anyopaque = null,

    pub fn apply(self: ApplyBoundary, store: *CausalStore, request: RemediationRequest) ApplyResult {
        const decision = self.engine.decide(request);
        const decided_id = recordDecision(store, request, decision);

        if (decision.decision != .approve) {
            // Record-only / rejected — nothing executes, applied=false.
            recordApplied(store, request, decided_id, false, "not approved — no action taken");
            return .{ .outcome = .declined, .decision = decision.decision, .kind = request.kind, .reason = decision.reason };
        }

        // Approved — execute the action.
        if (!self.action(self.action_context, request)) {
            recordApplied(store, request, decided_id, false, "action failed");
            return .{ .outcome = .action_failed, .decision = .approve, .kind = request.kind, .reason = "action failed" };
        }

        // Verify the fix. applied=true is earned ONLY if this proves it.
        const verified = self.verify(self.verify_context);
        recordApplied(store, request, decided_id, verified, if (verified) "applied and verified" else "executed but verification failed");
        return .{
            .outcome = if (verified) .applied else .applied_unverified,
            .decision = .approve,
            .kind = request.kind,
            .reason = if (verified) "applied and verified" else "executed but verification failed",
        };
    }
};

/// Record the terminal `remediation_applied` event. `applied` is encoded in the
/// status ("applied" vs "not_applied") so a query can filter earned applies.
/// The cause edge chains to the `remediation_decided` event when available.
///
/// NOTE: the status string is intentionally LOSSY — three distinct non-applied
/// `ApplyOutcome`s (declined / action_failed / applied_unverified) all record
/// "not_applied". The `ApplyResult.outcome` enum is the load-bearing, precise
/// signal; the durable status is a coarse applied/not-applied filter for audit
/// queries.
pub fn recordApplied(store: *CausalStore, request: RemediationRequest, decided_id: ?u64, applied: bool, detail: []const u8) void {
    _ = store.record(.{
        .kind = .remediation_applied,
        .run_id = request.target_run_id,
        .scope_id = request.target_scope_id,
        .fiber_id = request.target_fiber_id,
        .parent_id = decided_id,
        .cause_event_id = decided_id,
        .status = if (applied) "applied" else "not_applied",
        .label = detail,
        .type_name = @tagName(request.kind),
    }) catch {};
}
