type UnknownRecord = Record<string, unknown>;

export type ProofStatus = "passed" | "failed" | "unsupported";
export type StudioChangeStatus = "draft" | "proved" | "reviewed" | "approved" | "applied" | "rejected" | "blocked";

export type StudioProposal = {
  schema: "zigeffect.statechart.proposal.v1";
  schema_version: 1;
  proposal_id: string;
  machine_id: string;
  author: string;
  title: string;
  summary: string;
  created_ms: number;
  base_version: number;
  next_version: number;
  base_fingerprint: string;
  next_fingerprint: string;
  definition_digest: string;
  diff_digest: string;
  digest: string;
};

export type StudioProof = {
  schema: "zigeffect.statechart.proof.v1";
  schema_version: 1;
  proof_id: string;
  proposal_digest: string;
  definition_fingerprint: string;
  validation: ProofStatus;
  analysis: ProofStatus;
  paths: ProofStatus;
  coverage: ProofStatus;
  determinism: ProofStatus;
  xstate: ProofStatus;
  temporal: ProofStatus;
  faults: ProofStatus;
  performance: ProofStatus;
  mutation_total: number;
  mutation_killed: number;
  truncated: boolean;
  digest: string;
};

export type StudioReview = {
  schema: "zigeffect.statechart.review.v1";
  schema_version: 1;
  review_id: string;
  proposal_digest: string;
  proof_digest: string;
  reviewer: string;
  decision: "accepted" | "changes_requested" | "rejected";
  summary: string;
  issued_ms: number;
  digest: string;
};

export type StudioApproval = {
  schema: "zigeffect.statechart.approval.v1";
  schema_version: 1;
  approval_id: string;
  proposal_digest: string;
  proof_digest: string;
  review_digest: string;
  reviewer: string;
  decision: "approved" | "rejected";
  issued_ms: number;
  expires_ms: number;
  digest: string;
};

export type StudioApplication = {
  schema: "zigeffect.statechart.application.v1";
  schema_version: 1;
  application_id: string;
  approval_digest: string;
  machine_id: string;
  from_fingerprint: string;
  to_fingerprint: string;
  applied_by: string;
  applied_ms: number;
  causal_event_id: string;
  digest: string;
};

export type StudioChange = {
  proposal: StudioProposal;
  proof: StudioProof | null;
  review: StudioReview | null;
  approval: StudioApproval | null;
  application: StudioApplication | null;
  proofComplete: boolean;
  bindingValid: boolean;
  status: StudioChangeStatus;
  issues: string[];
};

export type StudioFleetRecord = { machineId: string; instanceId: string; definitionFingerprint: string; version: number; status: string; health: string; owner: string; fenceEpoch: string; pending: number; mailboxDepth: number };
export type StudioModel = { changes: StudioChange[]; fleet: StudioFleetRecord[]; warnings: string[] };

const proofFields: Array<keyof Pick<StudioProof, "validation" | "analysis" | "paths" | "coverage" | "determinism" | "xstate" | "temporal" | "faults" | "performance">> = [
  "validation", "analysis", "paths", "coverage", "determinism", "xstate", "temporal", "faults", "performance",
];

export function deriveStudioModel(raw: unknown, nowMs = Date.now()): StudioModel {
  const root = record(raw, "artifact");
  const embedded = isRecord(root.statechart_studio) ? root.statechart_studio : root;
  const proposals = array(embedded.proposals).map(parseProposal);
  const proofs = array(embedded.proofs).map(parseProof);
  const reviews = array(embedded.reviews).map(parseReview);
  const approvals = array(embedded.approvals).map(parseApproval);
  const applications = array(embedded.applications).map(parseApplication);
  const fleetRoot = isRecord(root.statechart_fleet) ? root.statechart_fleet : isRecord(root.fleet) ? root.fleet : null;
  const fleet = fleetRoot?.schema === "zigeffect.statechart.fleet-snapshot.v1" && fleetRoot.schema_version === 1
    ? array(fleetRoot.instances).map(parseFleetRecord)
    : [];
  const warnings: string[] = [];

  const changes = proposals.map((proposal): StudioChange => {
    const issues: string[] = [];
    const proof = proofs.find((candidate) => candidate.proposal_digest === proposal.digest) ?? null;
    const review = reviews.find((candidate) => candidate.proposal_digest === proposal.digest) ?? null;
    const approval = approvals.find((candidate) => candidate.proposal_digest === proposal.digest) ?? null;
    const application = approval ? applications.find((candidate) => candidate.approval_digest === approval.digest) ?? null : null;
    const proofComplete = proof !== null && !proof.truncated && proofFields.every((field) => proof[field] === "passed") &&
      proof.mutation_killed <= proof.mutation_total && (proof.mutation_total === 0 || proof.mutation_killed * 100 >= proof.mutation_total * 90);

    if (!proof && (review || approval)) issues.push("governance artifact has no bound proof");
    if (proof && proof.definition_fingerprint !== proposal.next_fingerprint) issues.push("proof fingerprint is stale");
    if (proof && !proofComplete) issues.push("proof bundle is incomplete");
    if (review && proof && review.proof_digest !== proof.digest) issues.push("review proof binding is stale");
    if (approval && proof && approval.proof_digest !== proof.digest) issues.push("approval proof binding is stale");
    if (review && review.decision !== "accepted") issues.push(`review ${review.decision}`);
    if (approval && approval.review_digest !== review?.digest) issues.push("approval review binding is stale");
    if (approval && approval.decision !== "approved") issues.push("approval rejected");
    if (approval && nowMs > approval.expires_ms && !application) issues.push("approval expired before application");
    if (application && (application.machine_id !== proposal.machine_id || application.from_fingerprint !== proposal.base_fingerprint || application.to_fingerprint !== proposal.next_fingerprint)) issues.push("application binding is stale");
    const bindingValid = issues.length === 0;
    let status: StudioChangeStatus = "draft";
    if (!bindingValid) status = approval?.decision === "rejected" || review?.decision === "rejected" ? "rejected" : "blocked";
    else if (application) status = "applied";
    else if (approval) status = "approved";
    else if (review) status = "reviewed";
    else if (proofComplete) status = "proved";
    warnings.push(...issues.map((issue) => `${proposal.proposal_id}: ${issue}`));
    return { proposal, proof, review, approval, application, proofComplete, bindingValid, status, issues };
  });

  const knownProposalDigests = new Set(proposals.map((proposal) => proposal.digest));
  for (const proof of proofs) if (!knownProposalDigests.has(proof.proposal_digest)) warnings.push(`${proof.proof_id}: orphan proof`);
  return { changes, fleet, warnings };
}

export type WorkflowPlanState = { id: string; kind: "atomic" | "final" | "compound" | "parallel" | "history_shallow" | "history_deep"; parent: string | null; initial: string | null; description: string };
export type WorkflowPlanTransition = { id: string; source: string; event: string | null; target: string | null; guard: string | null; actions: string[]; description: string };
export type WorkflowPlanInvariant = { id: string; kind: string; state: string; before: string | null };
export type WorkflowPlan = { schema: "zigeffect.statechart.workflow-plan.v1"; schema_version: 1; id: string; version: number; initial: string; description: string; states: WorkflowPlanState[]; transitions: WorkflowPlanTransition[]; invariants: WorkflowPlanInvariant[] };

export function parseWorkflowPlan(raw: unknown): WorkflowPlan {
  const value = record(raw, "workflow plan");
  if (value.schema !== "zigeffect.statechart.workflow-plan.v1" || value.schema_version !== 1) throw new Error("unsupported workflow plan schema");
  const plan: WorkflowPlan = {
    schema: value.schema,
    schema_version: 1,
    id: text(value.id, "id"),
    version: integer(value.version, "version"),
    initial: text(value.initial, "initial"),
    description: optionalText(value.description),
    states: array(value.states).map((rawState) => {
      const state = record(rawState, "state");
      const kind = optionalText(state.kind) || "atomic";
      if (!["atomic", "final", "compound", "parallel", "history_shallow", "history_deep"].includes(kind)) throw new Error(`unknown state kind ${kind}`);
      return { id: text(state.id, "state.id"), kind: kind as WorkflowPlanState["kind"], parent: nullableText(state.parent), initial: nullableText(state.initial), description: optionalText(state.description) };
    }),
    transitions: array(value.transitions).map((rawTransition) => {
      const transition = record(rawTransition, "transition");
      return { id: text(transition.id, "transition.id"), source: text(transition.source, "transition.source"), event: nullableText(transition.event), target: nullableText(transition.target), guard: nullableText(transition.guard), actions: array(transition.actions).map((action) => text(action, "action")), description: optionalText(transition.description) };
    }),
    invariants: array(value.invariants).map((rawInvariant) => {
      const invariant = record(rawInvariant, "invariant");
      return { id: text(invariant.id, "invariant.id"), kind: text(invariant.kind, "invariant.kind"), state: text(invariant.state, "invariant.state"), before: nullableText(invariant.before) };
    }),
  };
  const findings = validateWorkflowPlan(plan);
  if (findings.length > 0) throw new Error(findings.join("; "));
  return plan;
}

export function validateWorkflowPlan(plan: WorkflowPlan): string[] {
  const findings: string[] = [];
  const stateIds = new Set<string>();
  for (const state of plan.states) {
    if (stateIds.has(state.id)) findings.push(`duplicate state ${state.id}`);
    stateIds.add(state.id);
  }
  if (!stateIds.has(plan.initial)) findings.push(`initial state ${plan.initial} is unknown`);
  const transitionIds = new Set<string>();
  for (const transition of plan.transitions) {
    if (transitionIds.has(transition.id)) findings.push(`duplicate transition ${transition.id}`);
    transitionIds.add(transition.id);
    if (!stateIds.has(transition.source)) findings.push(`transition ${transition.id} has unknown source ${transition.source}`);
    if (transition.target && !stateIds.has(transition.target)) findings.push(`transition ${transition.id} targets unknown state ${transition.target}`);
  }
  for (const invariant of plan.invariants) if (!stateIds.has(invariant.state)) findings.push(`invariant ${invariant.id} references unknown state ${invariant.state}`);
  return findings;
}

function parseProposal(raw: unknown): StudioProposal {
  const value = schemaRecord(raw, "zigeffect.statechart.proposal.v1");
  return { schema: "zigeffect.statechart.proposal.v1", schema_version: 1, proposal_id: text(value.proposal_id, "proposal_id"), machine_id: text(value.machine_id, "machine_id"), author: text(value.author, "author"), title: text(value.title, "title"), summary: text(value.summary, "summary"), created_ms: integer(value.created_ms, "created_ms"), base_version: integer(value.base_version, "base_version"), next_version: integer(value.next_version, "next_version"), base_fingerprint: uintText(value.base_fingerprint, "base_fingerprint"), next_fingerprint: uintText(value.next_fingerprint, "next_fingerprint"), definition_digest: digest(value.definition_digest), diff_digest: digest(value.diff_digest), digest: digest(value.digest) };
}
function parseProof(raw: unknown): StudioProof {
  const value = schemaRecord(raw, "zigeffect.statechart.proof.v1");
  const status = (field: string) => proofStatus(value[field], field);
  return { schema: "zigeffect.statechart.proof.v1", schema_version: 1, proof_id: text(value.proof_id, "proof_id"), proposal_digest: digest(value.proposal_digest), definition_fingerprint: uintText(value.definition_fingerprint, "definition_fingerprint"), validation: status("validation"), analysis: status("analysis"), paths: status("paths"), coverage: status("coverage"), determinism: status("determinism"), xstate: status("xstate"), temporal: status("temporal"), faults: status("faults"), performance: status("performance"), mutation_total: integer(value.mutation_total, "mutation_total"), mutation_killed: integer(value.mutation_killed, "mutation_killed"), truncated: value.truncated === true, digest: digest(value.digest) };
}
function parseReview(raw: unknown): StudioReview {
  const value = schemaRecord(raw, "zigeffect.statechart.review.v1");
  const decision = text(value.decision, "decision");
  if (!["accepted", "changes_requested", "rejected"].includes(decision)) throw new Error("invalid review decision");
  return { schema: "zigeffect.statechart.review.v1", schema_version: 1, review_id: text(value.review_id, "review_id"), proposal_digest: digest(value.proposal_digest), proof_digest: digest(value.proof_digest), reviewer: text(value.reviewer, "reviewer"), decision: decision as StudioReview["decision"], summary: text(value.summary, "summary"), issued_ms: integer(value.issued_ms, "issued_ms"), digest: digest(value.digest) };
}
function parseApproval(raw: unknown): StudioApproval {
  const value = schemaRecord(raw, "zigeffect.statechart.approval.v1");
  const decision = text(value.decision, "decision");
  if (decision !== "approved" && decision !== "rejected") throw new Error("invalid approval decision");
  return { schema: "zigeffect.statechart.approval.v1", schema_version: 1, approval_id: text(value.approval_id, "approval_id"), proposal_digest: digest(value.proposal_digest), proof_digest: digest(value.proof_digest), review_digest: digest(value.review_digest), reviewer: text(value.reviewer, "reviewer"), decision, issued_ms: integer(value.issued_ms, "issued_ms"), expires_ms: integer(value.expires_ms, "expires_ms"), digest: digest(value.digest) };
}
function parseApplication(raw: unknown): StudioApplication {
  const value = schemaRecord(raw, "zigeffect.statechart.application.v1");
  return { schema: "zigeffect.statechart.application.v1", schema_version: 1, application_id: text(value.application_id, "application_id"), approval_digest: digest(value.approval_digest), machine_id: text(value.machine_id, "machine_id"), from_fingerprint: uintText(value.from_fingerprint, "from_fingerprint"), to_fingerprint: uintText(value.to_fingerprint, "to_fingerprint"), applied_by: text(value.applied_by, "applied_by"), applied_ms: integer(value.applied_ms, "applied_ms"), causal_event_id: uintText(value.causal_event_id, "causal_event_id"), digest: digest(value.digest) };
}
function parseFleetRecord(raw: unknown): StudioFleetRecord {
  const value = record(raw, "fleet instance");
  return {
    machineId: text(value.machine_id, "machine_id"),
    instanceId: uintText(value.instance_id, "instance_id"),
    definitionFingerprint: uintText(value.definition_fingerprint, "definition_fingerprint"),
    version: integer(value.version, "version"),
    status: text(value.status, "status"),
    health: text(value.health, "health"),
    owner: text(value.owner, "owner"),
    fenceEpoch: uintText(value.fence_epoch, "fence_epoch"),
    pending: integer(value.pending_commands ?? 0, "pending_commands") + integer(value.pending_timers ?? 0, "pending_timers") + integer(value.pending_signals ?? 0, "pending_signals") + integer(value.pending_children ?? 0, "pending_children"),
    mailboxDepth: integer(value.mailbox_depth ?? 0, "mailbox_depth"),
  };
}
function schemaRecord(raw: unknown, schema: string): UnknownRecord { const value = record(raw, schema); if (value.schema !== schema || value.schema_version !== 1) throw new Error(`unsupported ${schema} schema`); return value; }
function proofStatus(value: unknown, field: string): ProofStatus { if (value !== "passed" && value !== "failed" && value !== "unsupported") throw new Error(`invalid ${field}`); return value; }
function digest(value: unknown): string { const result = text(value, "digest"); if (!/^sha256:[0-9a-fA-F]{64}$/.test(result)) throw new Error("invalid digest"); return result; }
function uintText(value: unknown, field: string): string { if (typeof value === "string" && /^\d+$/.test(value)) return value; if (typeof value === "number" && Number.isSafeInteger(value) && value >= 0) return String(value); throw new Error(`${field} must be an unsigned integer string or safe integer`); }
function integer(value: unknown, field: string): number { if (typeof value !== "number" || !Number.isSafeInteger(value)) throw new Error(`${field} must be a safe integer`); return value; }
function text(value: unknown, field: string): string { if (typeof value !== "string" || value.length === 0) throw new Error(`${field} must be a non-empty string`); return value; }
function optionalText(value: unknown): string { return typeof value === "string" ? value : ""; }
function nullableText(value: unknown): string | null { return value == null ? null : text(value, "value"); }
function array(value: unknown): unknown[] { return Array.isArray(value) ? value : []; }
function isRecord(value: unknown): value is UnknownRecord { return typeof value === "object" && value !== null && !Array.isArray(value); }
function record(value: unknown, field: string): UnknownRecord { if (!isRecord(value)) throw new Error(`${field} must be an object`); return value; }
