import { expect, test } from "bun:test";
import {
  deriveStudioModel,
  parseWorkflowPlan,
  validateWorkflowPlan,
} from "./studioModel";

const digest = (fill: string) => `sha256:${fill.repeat(64)}`;

test("studio derives an exact immutable governance chain", () => {
  const proposal = {
    schema: "zigeffect.statechart.proposal.v1", schema_version: 1,
    proposal_id: "proposal-2", machine_id: "agent.review", author: "agent:planner",
    title: "Add review", summary: "Require review", created_ms: 100,
    base_version: 1, next_version: 2, base_fingerprint: 41, next_fingerprint: 42,
    definition_digest: digest("1"), diff_digest: digest("2"), digest: digest("3"),
  };
  const proof = {
    schema: "zigeffect.statechart.proof.v1", schema_version: 1, proof_id: "proof-2",
    proposal_digest: proposal.digest, definition_fingerprint: 42,
    validation: "passed", analysis: "passed", paths: "passed", coverage: "passed", determinism: "passed", xstate: "passed",
    temporal: "passed", faults: "passed", performance: "passed",
    mutation_total: 10, mutation_killed: 9, truncated: false, digest: digest("4"),
  };
  const review = {
    schema: "zigeffect.statechart.review.v1", schema_version: 1, review_id: "review-2",
    proposal_digest: proposal.digest, proof_digest: proof.digest, reviewer: "human:operator",
    decision: "accepted", summary: "Evidence accepted", issued_ms: 110, digest: digest("5"),
  };
  const approval = {
    schema: "zigeffect.statechart.approval.v1", schema_version: 1, approval_id: "approval-2",
    proposal_digest: proposal.digest, proof_digest: proof.digest, review_digest: review.digest,
    reviewer: "human:operator", decision: "approved", issued_ms: 120, expires_ms: 200,
    digest: digest("6"),
  };
  const application = {
    schema: "zigeffect.statechart.application.v1", schema_version: 1, application_id: "application-2",
    approval_digest: approval.digest, machine_id: proposal.machine_id,
    from_fingerprint: 41, to_fingerprint: 42, applied_by: "service:control",
    applied_ms: 130, causal_event_id: 9, digest: digest("7"),
  };
  const model = deriveStudioModel({
    statechart_studio: { proposals: [proposal], proofs: [proof], reviews: [review], approvals: [approval], applications: [application] },
    statechart_fleet: { schema: "zigeffect.statechart.fleet-snapshot.v1", schema_version: 1, instances: [{ machine_id: "agent.review", instance_id: "7", definition_fingerprint: "42", version: 2, status: "running", health: "healthy", owner: "runner-a", fence_epoch: "9", pending_commands: 1, pending_timers: 1, pending_signals: 0, pending_children: 0, mailbox_depth: 2 }] },
  }, 150);

  expect(model.changes).toHaveLength(1);
  expect(model.changes[0]?.status).toBe("applied");
  expect(model.changes[0]?.proofComplete).toBe(true);
  expect(model.changes[0]?.bindingValid).toBe(true);
  expect(model.fleet[0]).toMatchObject({ instanceId: "7", pending: 2, mailboxDepth: 2 });
  expect(model.warnings).toEqual([]);
});

test("studio fails closed on stale or expired evidence", () => {
  const model = deriveStudioModel({
    statechart_studio: {
      proposals: [{
        schema: "zigeffect.statechart.proposal.v1", schema_version: 1, proposal_id: "p", machine_id: "m",
        author: "a", title: "t", summary: "s", created_ms: 1, base_version: 1, next_version: 2,
        base_fingerprint: 1, next_fingerprint: 2, definition_digest: digest("1"), diff_digest: digest("2"), digest: digest("3"),
      }],
      proofs: [], reviews: [],
      approvals: [{ schema: "zigeffect.statechart.approval.v1", schema_version: 1, approval_id: "a", proposal_digest: digest("3"), proof_digest: digest("4"), review_digest: digest("6"), reviewer: "h", decision: "approved", issued_ms: 1, expires_ms: 2, digest: digest("5") }],
      applications: [],
    },
  }, 10);
  expect(model.changes[0]?.status).toBe("blocked");
  expect(model.warnings.some((warning) => warning.includes("expired"))).toBe(true);
});

test("workflow plan validation catches unsafe and dangling logic", () => {
  const plan = parseWorkflowPlan({
    schema: "zigeffect.statechart.workflow-plan.v1", schema_version: 1,
    id: "agent.review", version: 1, initial: "idle",
    states: [{ id: "idle", kind: "atomic" }, { id: "done", kind: "final" }],
    transitions: [{ id: "finish", source: "idle", event: "finish", target: "done", actions: [] }],
    invariants: [{ id: "terminal", kind: "eventually_active", state: "done" }],
  });
  expect(validateWorkflowPlan(plan)).toEqual([]);
  expect(validateWorkflowPlan({ ...plan, transitions: [{ ...plan.transitions[0]!, target: "missing" }] })).toContain("transition finish targets unknown state missing");
});
