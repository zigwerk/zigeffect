const std = @import("std");
const differential = @import("differential.zig");
const resource_matrix = @import("resource_matrix.zig");

pub const schema = "zgraphy.evaluation-contracts.v1";
pub const schema_version: u32 = 1;
pub const embedded_bytes = @embedFile("evaluation-contracts.v1.json");

pub const Maturity = enum { contract_candidate };
pub const EvidenceState = enum { active_baseline, schema_only };
pub const ClaimMaturity = enum { baseline_only };

pub const EvaluationKind = enum {
    extraction,
    retrieval,
    agent_task,
    performance,
    resource,
};

pub const Definition = struct {
    kind: EvaluationKind,
    receipt_schema: []const u8,
    schema_version: u32,
    evidence_state: EvidenceState,
    unit: []const u8,
    identity_fields: []const []const u8,
    outcome_fields: []const []const u8,
    metrics: []const []const u8,
    failure_fields: []const []const u8,
    promotion_requires: []const []const u8,
    controlled_arms_required: bool,
    correctness_required: bool,
    held_out_required: bool,
    unsupported_claims_forbidden: bool,
};

pub const ClaimPolicy = struct {
    maturity: ClaimMaturity,
    required_kinds: []EvaluationKind,
    schema_only_eligible: bool,
    requires_held_out: bool,
    requires_paired_resources: bool,
    requires_complete_identity: bool,
    requires_non_cherry_picked_matrix: bool,
    requires_no_unsupported_claims: bool,
};

pub const Contract = struct {
    schema: []const u8,
    schema_version: u32,
    maturity: Maturity,
    definitions: []Definition,
    claim_policy: ClaimPolicy,
};

pub const required_kinds = [_]EvaluationKind{
    .extraction,
    .retrieval,
    .agent_task,
    .performance,
    .resource,
};

const required_schemas = [_][]const u8{
    differential.schema,
    "zgraphy.retrieval-receipt.v1",
    "zgraphy.agent-task-receipt.v1",
    "zgraphy.performance-receipt.v1",
    resource_matrix.schema,
};

const required_states = [_]EvidenceState{
    .active_baseline,
    .schema_only,
    .schema_only,
    .schema_only,
    .active_baseline,
};

pub fn parseEmbedded(allocator: std.mem.Allocator) !std.json.Parsed(Contract) {
    return std.json.parseFromSlice(Contract, allocator, embedded_bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = false,
    });
}

pub fn validate(contract: *const Contract) !void {
    if (!std.mem.eql(u8, contract.schema, schema) or contract.schema_version != schema_version or contract.maturity != .contract_candidate) {
        return error.IncompatibleEvaluationContract;
    }
    if (contract.definitions.len != required_kinds.len) return error.IncompleteEvaluationKinds;
    for (contract.definitions, 0..) |definition, index| {
        for (contract.definitions[0..index]) |previous| {
            if (previous.kind == definition.kind) return error.DuplicateEvaluationKind;
            if (std.mem.eql(u8, previous.receipt_schema, definition.receipt_schema)) return error.DuplicateEvaluationSchema;
        }
        if (definition.kind != required_kinds[index] or
            !std.mem.eql(u8, definition.receipt_schema, required_schemas[index]) or
            definition.schema_version != 1 or definition.evidence_state != required_states[index] or
            !validName(definition.unit))
        {
            return error.InvalidEvaluationDefinition;
        }
        if (definition.identity_fields.len < 8) return error.MissingEvaluationIdentity;
        if (definition.outcome_fields.len < 6) return error.MissingEvaluationOutcomes;
        if (definition.metrics.len == 0) return error.MissingEvaluationMetrics;
        if (definition.failure_fields.len < 5) return error.MissingEvaluationFailures;
        if (definition.promotion_requires.len < 6) return error.IncompleteEvaluationPromotion;
        try validateNames(definition.identity_fields);
        try validateNames(definition.outcome_fields);
        try validateNames(definition.metrics);
        try validateNames(definition.failure_fields);
        try validateNames(definition.promotion_requires);
        if (!definition.correctness_required or !definition.unsupported_claims_forbidden) return error.UnsafeEvaluationPolicy;
    }
    try validateExtraction(findDefinition(contract, .extraction).?);
    try validateRetrieval(findDefinition(contract, .retrieval).?);
    try validateAgentTask(findDefinition(contract, .agent_task).?);
    try validatePerformance(findDefinition(contract, .performance).?);
    try validateResource(findDefinition(contract, .resource).?);
    try validateClaimPolicy(&contract.claim_policy);
}

pub fn findDefinition(contract: *const Contract, kind: EvaluationKind) ?*const Definition {
    for (contract.definitions, 0..) |definition, index| {
        if (definition.kind == kind) return &contract.definitions[index];
    }
    return null;
}

pub fn contractDigest() [32]u8 {
    var digest: [32]u8 = @splat(0);
    std.crypto.hash.sha2.Sha256.hash(embedded_bytes, &digest, .{});
    return digest;
}

fn validateExtraction(definition: *const Definition) !void {
    const metrics = [_][]const u8{ "entity_recall", "relation_recall", "fact_recall", "hyperedge_recall", "supernode_recall", "projection_loss" };
    try requireNames(definition.metrics, &metrics, error.IncompleteExtractionMetrics);
    if (!definition.held_out_required or definition.controlled_arms_required) return error.UnsafeExtractionEvaluation;
}

fn validateRetrieval(definition: *const Definition) !void {
    const identities = [_][]const u8{ "task_id", "graph_generation", "schema_digest", "ontology_digest", "index_digest", "query_plan_digest" };
    const outcomes = [_][]const u8{ "relevant_ids", "returned_ids", "proof_paths", "evidence_refs", "truncated", "unsupported_channels" };
    const metrics = [_][]const u8{ "recall_at_k", "mrr", "ndcg", "evidence_precision", "proof_faithfulness", "completeness", "context_bytes", "latency_ns" };
    try requireNames(definition.identity_fields, &identities, error.IncompleteRetrievalIdentity);
    try requireNames(definition.outcome_fields, &outcomes, error.IncompleteRetrievalOutcomes);
    try requireNames(definition.metrics, &metrics, error.IncompleteRetrievalMetrics);
    if (!definition.controlled_arms_required or !definition.held_out_required or definition.evidence_state != .schema_only) return error.UnsafeRetrievalEvaluation;
}

fn validateAgentTask(definition: *const Definition) !void {
    const identities = [_][]const u8{ "task_id", "agent_identity", "model_identity", "prompt_digest", "tool_policy_digest", "arm", "trial" };
    const outcomes = [_][]const u8{ "rubric", "success", "assertions", "evidence_citations", "unsupported_claims", "baseline_arm", "assisted_arm" };
    const metrics = [_][]const u8{ "task_success", "rubric_score", "unsupported_claims", "tool_calls", "file_reads", "context_bytes", "input_tokens", "output_tokens", "wall_time_ns", "spend_microunits" };
    const promotion = [_][]const u8{ "fixed_agent", "baseline_arm", "assisted_arm", "held_out_tasks", "declared_trials", "complete_cost_accounting", "task_evidence", "no_unsupported_claims" };
    try requireNames(definition.identity_fields, &identities, error.IncompleteAgentTaskIdentity);
    try requireNames(definition.outcome_fields, &outcomes, error.IncompleteAgentTaskOutcomes);
    try requireNames(definition.metrics, &metrics, error.IncompleteAgentTaskMetrics);
    try requireNames(definition.promotion_requires, &promotion, error.IncompleteAgentTaskPromotion);
    if (!definition.controlled_arms_required or !definition.held_out_required or definition.evidence_state != .schema_only) return error.UnsafeAgentTaskEvaluation;
}

fn validatePerformance(definition: *const Definition) !void {
    const identities = [_][]const u8{ "machine_digest", "operating_system", "target", "toolchain", "optimize", "configuration_digest" };
    const outcomes = [_][]const u8{ "warmups", "repetitions", "samples", "aggregates", "correctness_digest", "comparison_eligible" };
    const metrics = [_][]const u8{ "latency_p50_ns", "latency_p95_ns", "latency_p99_ns", "throughput_per_second", "allocations", "peak_rss_bytes", "persisted_bytes" };
    try requireNames(definition.identity_fields, &identities, error.IncompletePerformanceIdentity);
    try requireNames(definition.outcome_fields, &outcomes, error.IncompletePerformanceOutcomes);
    try requireNames(definition.metrics, &metrics, error.IncompletePerformanceMetrics);
    if (!definition.controlled_arms_required or !definition.correctness_required or definition.evidence_state != .schema_only) return error.UnsafePerformanceEvaluation;
}

fn validateResource(definition: *const Definition) !void {
    const metrics = [_][]const u8{ "elapsed_ns", "cpu_user_ns", "cpu_system_ns", "peak_rss_bytes", "persisted_bytes" };
    try requireNames(definition.metrics, &metrics, error.IncompleteResourceMetrics);
    if (!definition.controlled_arms_required or definition.held_out_required or definition.evidence_state != .active_baseline) return error.UnsafeResourceEvaluation;
}

fn validateClaimPolicy(policy: *const ClaimPolicy) !void {
    if (policy.maturity != .baseline_only or policy.schema_only_eligible or
        !policy.requires_held_out or !policy.requires_paired_resources or
        !policy.requires_complete_identity or !policy.requires_non_cherry_picked_matrix or
        !policy.requires_no_unsupported_claims)
    {
        return error.UnsafeEvaluationClaimPolicy;
    }
    if (policy.required_kinds.len != required_kinds.len) return error.IncompleteEvaluationClaimKinds;
    for (policy.required_kinds, required_kinds) |actual, expected| if (actual != expected) return error.IncompleteEvaluationClaimKinds;
}

fn requireNames(values: []const []const u8, required: []const []const u8, failure: anyerror) !void {
    for (required) |name| if (!containsName(values, name)) return failure;
}

fn validateNames(values: []const []const u8) !void {
    for (values, 0..) |value, index| {
        if (!validName(value)) return error.InvalidEvaluationField;
        for (values[0..index]) |previous| if (std.mem.eql(u8, previous, value)) return error.DuplicateEvaluationField;
    }
}

fn containsName(values: []const []const u8, wanted: []const u8) bool {
    for (values) |value| if (std.mem.eql(u8, value, wanted)) return true;
    return false;
}

fn validName(value: []const u8) bool {
    if (value.len == 0 or value.len > 96 or !std.ascii.isLower(value[0])) return false;
    for (value) |byte| if (!std.ascii.isLower(byte) and !std.ascii.isDigit(byte) and byte != '_') return false;
    return true;
}
