const std = @import("std");
const zstd = @import("zigeffect_std");

pub const Output = struct {
    allocator: std.mem.Allocator,
    generated_source: []u8,
    application_receipt: []u8,
    pub fn deinit(self: *Output) void {
        self.allocator.free(self.generated_source);
        self.allocator.free(self.application_receipt);
        self.* = undefined;
    }
};

pub fn runAgentWorkflowStudioExample(allocator: std.mem.Allocator) !Output {
    var expansion = try zstd.Statechart.Plan.expandPattern(allocator, .human_approval, "release.approval");
    defer expansion.deinit();
    const plan = zstd.Statechart.Plan.WorkflowPlan{
        .schema = zstd.Statechart.Plan.workflow_plan_schema,
        .schema_version = zstd.Statechart.Plan.workflow_plan_schema_version,
        .id = "agent.release",
        .version = 2,
        .initial = expansion.states[0].id,
        .description = "Human-governed agent release workflow",
        .states = expansion.states,
        .transitions = expansion.transitions,
        .invariants = expansion.invariants,
    };
    const source = try zstd.Statechart.Plan.generateZig(allocator, plan);
    errdefer allocator.free(source);

    var proposal = try zstd.Statechart.Studio.createProposal(allocator, .{
        .proposal_id = "agent-release-v2",
        .machine_id = "agent.release",
        .author = "agent:workflow-author",
        .title = "Govern agent release",
        .summary = "Require complete proof and explicit human review before application.",
        .created_ms = 100,
        .base_version = 1,
        .next_version = 2,
        .base_fingerprint = 41,
        .next_fingerprint = 42,
        .definition_digest = "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        .diff_digest = "sha256:1123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    });
    defer proposal.deinit();
    var proof = try zstd.Statechart.Studio.createProof(allocator, .{
        .proof_id = "agent-release-v2-proof",
        .proposal_digest = proposal.value.digest,
        .definition_fingerprint = proposal.value.next_fingerprint,
        .validation = .passed,
        .analysis = .passed,
        .paths = .passed,
        .coverage = .passed,
        .determinism = .passed,
        .xstate = .passed,
        .temporal = .passed,
        .faults = .passed,
        .performance = .passed,
        .mutation_total = 20,
        .mutation_killed = 20,
    });
    defer proof.deinit();
    var review = try zstd.Statechart.Studio.createReview(allocator, .{
        .review_id = "agent-release-v2-review",
        .proposal_digest = proposal.value.digest,
        .proof_digest = proof.value.digest,
        .reviewer = "human:operator",
        .decision = .accepted,
        .summary = "Logic, negative paths, and production evidence reviewed.",
        .issued_ms = 110,
    });
    defer review.deinit();
    var approval = try zstd.Statechart.Studio.createApproval(allocator, .{
        .approval_id = "agent-release-v2-approval",
        .proposal_digest = proposal.value.digest,
        .proof_digest = proof.value.digest,
        .review_digest = review.value.digest,
        .reviewer = "human:operator",
        .decision = .approved,
        .issued_ms = 120,
        .expires_ms = 200,
    });
    defer approval.deinit();
    try approval.value.validateBindingWithReview(proposal.value, proof.value, review.value, 130);
    var application = try zstd.Statechart.Studio.createApplicationReceipt(allocator, .{
        .application_id = "agent-release-v2-application",
        .approval_digest = approval.value.digest,
        .machine_id = proposal.value.machine_id,
        .from_fingerprint = proposal.value.base_fingerprint,
        .to_fingerprint = proposal.value.next_fingerprint,
        .applied_by = "service:statechart-control",
        .applied_ms = 140,
        .causal_event_id = 9001,
    });
    defer application.deinit();
    try application.value.validateBinding(proposal.value, approval.value);
    const receipt = try zstd.Statechart.Studio.formatApplicationJson(allocator, application.value);
    return .{ .allocator = allocator, .generated_source = source, .application_receipt = receipt };
}

pub fn main() !void {
    var output = try runAgentWorkflowStudioExample(std.heap.page_allocator);
    defer output.deinit();
    std.debug.print("{s}\n", .{output.application_receipt});
}

test "agent workflow studio example compiles a pattern through governed application" {
    var output = try runAgentWorkflowStudioExample(std.testing.allocator);
    defer output.deinit();
    try std.testing.expect(std.mem.indexOf(u8, output.generated_source, "statechart.Definition") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.generated_source, "release.approval.rejected") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.application_receipt, "zigeffect.statechart.application.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.application_receipt, "\"causal_event_id\":\"9001\"") != null);
}
