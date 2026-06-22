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
pub const CausalFinding = causal.CausalFinding;
pub const CausalFindingKind = causal.CausalFindingKind;

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

/// Derive a bounded remediation request from a causal finding, if the runtime
/// knows a remediation for that finding kind. This is the autonomous
/// detection→proposal step of the closed loop (M8.1): the agent reads a finding
/// out of the causal graph and proposes the action the runtime associates with
/// that diagnosed problem — without a human naming the target fiber. Returns
/// null when no safe auto-remediation is mapped (the agent must decide), e.g.
/// `retry_budget_exhausted` is deliberately NOT mapped to `retry` (that would
/// loop), and resource/finalizer/provider/assertion findings need human design.
pub fn remediationFromFinding(finding: CausalFinding) ?RemediationRequest {
    return switch (finding.kind) {
        // A hung fiber (parked with no resume) or one leaked past its scope's
        // close → interrupt it to recover.
        .fiber_suspended_without_resume, .fiber_pending_after_scope_close => .{
            .kind = .interrupt,
            .target_fiber_id = finding.fiber_id,
            .target_scope_id = finding.scope_id,
            .target_run_id = finding.run_id,
            .reason = "hung/leaked fiber diagnosed by the causal graph — interrupt to recover",
        },
        .resource_acquired_without_finalization,
        .finalizer_failure,
        .retry_budget_exhausted,
        .service_requirement_without_provider,
        .assertion_failure,
        => null,
    };
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
/// causal-compare verdict of `improved`). Receives the request so a verifier
/// shared across multiple remediations knows which one it is proving.
pub const VerifyFn = *const fn (?*anyopaque, RemediationRequest) bool;

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
        const verified = self.verify(self.verify_context, request);
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

// ─── M8.1 — the remediation loop runner ──────────────────────────────────────
//
// The standing capability: one driver that, per pass, queries the causal graph
// for findings, derives a remediation request for each (via
// remediationFromFinding), and runs each through the apply boundary. This turns
// the demonstrated closed loop into a callable engine primitive — a host calls
// `runOnce` on each tick (or in response to a finding), with the gate governing
// whether anything actually executes.

pub const Allocator = std.mem.Allocator;

pub const LoopSummary = struct {
    findings_seen: usize = 0,
    /// Findings that mapped to a remediation request.
    requests_derived: usize = 0,
    /// Outcome tallies (sum == requests_derived).
    applied: usize = 0,
    declined: usize = 0,
    action_failed: usize = 0,
    applied_unverified: usize = 0,

    fn tally(self: *LoopSummary, outcome: ApplyOutcome) void {
        switch (outcome) {
            .applied => self.applied += 1,
            .declined => self.declined += 1,
            .action_failed => self.action_failed += 1,
            .applied_unverified => self.applied_unverified += 1,
        }
    }
};

pub const RemediationLoop = struct {
    engine: PolicyEngine,
    action: ActionFn,
    verify: VerifyFn,
    action_context: ?*anyopaque = null,
    verify_context: ?*anyopaque = null,

    /// One pass over the store's current findings. Derives a request per
    /// finding (skipping findings with no mapped remediation) and runs each
    /// through the apply boundary, recording the requested→decided→applied
    /// chain into the same store. Returns a summary of what happened.
    pub fn runOnce(self: RemediationLoop, allocator: Allocator, store: *CausalStore) Allocator.Error!LoopSummary {
        var findings = try store.findings(allocator);
        defer findings.deinit();

        var summary = LoopSummary{};
        summary.findings_seen = findings.items.len;

        const boundary = ApplyBoundary{
            .engine = self.engine,
            .action = self.action,
            .verify = self.verify,
            .action_context = self.action_context,
            .verify_context = self.verify_context,
        };

        for (findings.items) |finding| {
            const request = remediationFromFinding(finding) orelse continue;
            summary.requests_derived += 1;
            const result = boundary.apply(store, request);
            summary.tally(result.outcome);
        }
        return summary;
    }
};

// ─── M8.4–M8.7 — the Phase-8 remediation executor ────────────────────────────
//
// The apply boundary's ActionFn is generic. A RemediationExecutor structures it:
// a per-kind handler dispatch so the four Phase-8 actions (retry / interrupt /
// replace_provider / replay_scenario) each route to a registered handler. The
// engine supplies the dispatch + framework; the concrete handlers are wired by
// the host, because only the host knows the effect to retry, the provider to
// swap, the scenario to replay, or the fiber handle to interrupt. A kind with
// no registered handler fails the action (so the apply boundary records
// not_applied) — the runtime never pretends to have executed something it
// can't.

pub const RemediationHandler = struct {
    context: ?*anyopaque = null,
    /// Perform the action for `request`. Returns whether the action itself
    /// succeeded (not whether it fixed anything — that's the verifier's job).
    run: *const fn (?*anyopaque, RemediationRequest) bool,
};

pub const RemediationExecutor = struct {
    retry_handler: ?RemediationHandler = null,
    interrupt_handler: ?RemediationHandler = null,
    replace_provider_handler: ?RemediationHandler = null,
    replay_scenario_handler: ?RemediationHandler = null,

    fn handlerFor(self: *const RemediationExecutor, kind: RemediationKind) ?RemediationHandler {
        return switch (kind) {
            .retry => self.retry_handler,
            .interrupt => self.interrupt_handler,
            .replace_provider => self.replace_provider_handler,
            .replay_scenario => self.replay_scenario_handler,
        };
    }

    /// Dispatch `request` to its kind's handler. Returns false (action failed)
    /// when no handler is registered for the kind.
    pub fn execute(self: *const RemediationExecutor, request: RemediationRequest) bool {
        const handler = self.handlerFor(request.kind) orelse return false;
        return handler.run(handler.context, request);
    }

    pub fn withHandler(self: RemediationExecutor, kind: RemediationKind, handler: RemediationHandler) RemediationExecutor {
        var e = self;
        switch (kind) {
            .retry => e.retry_handler = handler,
            .interrupt => e.interrupt_handler = handler,
            .replace_provider => e.replace_provider_handler = handler,
            .replay_scenario => e.replay_scenario_handler = handler,
        }
        return e;
    }

    /// True if `kind` has a registered handler.
    pub fn canExecute(self: *const RemediationExecutor, kind: RemediationKind) bool {
        return self.handlerFor(kind) != null;
    }

    /// Adapt to the ApplyBoundary's ActionFn. Pass `&executor` as the
    /// action_context.
    pub fn action(ctx: ?*anyopaque, request: RemediationRequest) bool {
        const self: *const RemediationExecutor = @ptrCast(@alignCast(ctx.?));
        return self.execute(request);
    }
};
