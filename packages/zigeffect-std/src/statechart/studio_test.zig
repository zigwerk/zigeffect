const std = @import("std");
const Studio = @import("studio.zig");
const zigeffect = @import("zigeffect");

fn proposalInput() Studio.ProposalInput {
    return .{
        .proposal_id = "proposal-review-v2",
        .machine_id = "agent.review",
        .author = "agent:planner",
        .title = "Add evidence review",
        .summary = "Require reviewed evidence before publication",
        .created_ms = 100,
        .base_version = 1,
        .next_version = 2,
        .base_fingerprint = 41,
        .next_fingerprint = 42,
        .definition_digest = "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        .diff_digest = "sha256:1123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    };
}

test "studio proposal is deterministic versioned and JSON round trips" {
    var left = try Studio.createProposal(std.testing.allocator, proposalInput());
    defer left.deinit();
    var right = try Studio.createProposal(std.testing.allocator, proposalInput());
    defer right.deinit();
    try std.testing.expectEqualStrings(left.value.digest, right.value.digest);
    try std.testing.expectEqualStrings(Studio.proposal_schema, left.value.schema);

    const json = try Studio.formatProposalJson(std.testing.allocator, left.value);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"next_fingerprint\":\"42\"") != null);
    var parsed = try Studio.parseProposal(std.testing.allocator, json);
    defer parsed.deinit();
    try std.testing.expectEqualStrings(left.value.digest, parsed.value.digest);
    try std.testing.expectEqual(@as(u64, 42), parsed.value.next_fingerprint);
    left.value.title = "Tampered title";
    try std.testing.expectError(error.DigestMismatch, Studio.formatProposalJson(std.testing.allocator, left.value));
}

test "studio artifacts preserve full-range u64 identities as decimal strings" {
    var input = proposalInput();
    input.base_version = 9_007_199_254_740_993;
    input.next_version = 9_007_199_254_740_994;
    input.base_fingerprint = std.math.maxInt(u64) - 1;
    input.next_fingerprint = std.math.maxInt(u64);
    var proposal = try Studio.createProposal(std.testing.allocator, input);
    defer proposal.deinit();
    const json = try Studio.formatProposalJson(std.testing.allocator, proposal.value);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"18446744073709551615\"") != null);
    var parsed = try Studio.parseProposal(std.testing.allocator, json);
    defer parsed.deinit();
    try std.testing.expectEqual(std.math.maxInt(u64), parsed.value.next_fingerprint);
}

test "studio proof bundle is complete only when every required proof passes" {
    var proposal = try Studio.createProposal(std.testing.allocator, proposalInput());
    defer proposal.deinit();
    var proof = try Studio.createProof(std.testing.allocator, .{
        .proof_id = "proof-review-v2",
        .proposal_digest = proposal.value.digest,
        .definition_fingerprint = 42,
        .validation = .passed,
        .analysis = .passed,
        .paths = .passed,
        .coverage = .passed,
        .determinism = .passed,
        .xstate = .passed,
        .temporal = .passed,
        .faults = .passed,
        .performance = .passed,
        .mutation_total = 10,
        .mutation_killed = 9,
    });
    defer proof.deinit();
    try std.testing.expect(proof.value.complete());

    proof.value.truncated = true;
    try std.testing.expect(!proof.value.complete());
    try std.testing.expectError(error.DigestMismatch, Studio.formatProofJson(std.testing.allocator, proof.value));
}

test "studio approval is bound to exact proposal and proof and expires closed" {
    var proposal = try Studio.createProposal(std.testing.allocator, proposalInput());
    defer proposal.deinit();
    var proof = try Studio.createProof(std.testing.allocator, .{
        .proof_id = "proof-review-v2",
        .proposal_digest = proposal.value.digest,
        .definition_fingerprint = 42,
        .validation = .passed,
        .analysis = .passed,
        .paths = .passed,
        .coverage = .passed,
        .determinism = .passed,
        .xstate = .passed,
        .temporal = .passed,
        .faults = .passed,
        .performance = .passed,
    });
    defer proof.deinit();
    var review = try Studio.createReview(std.testing.allocator, .{
        .review_id = "review-review-v2",
        .proposal_digest = proposal.value.digest,
        .proof_digest = proof.value.digest,
        .reviewer = "human:operator",
        .decision = .accepted,
        .summary = "Evidence and intended behavior were reviewed.",
        .issued_ms = 190,
    });
    defer review.deinit();
    var approval = try Studio.createApproval(std.testing.allocator, .{
        .approval_id = "approval-review-v2",
        .proposal_digest = proposal.value.digest,
        .proof_digest = proof.value.digest,
        .review_digest = review.value.digest,
        .reviewer = "human:operator",
        .decision = .approved,
        .issued_ms = 200,
        .expires_ms = 300,
    });
    defer approval.deinit();

    try approval.value.validateBindingWithReview(proposal.value, proof.value, review.value, 250);
    try std.testing.expectError(error.ExpiredApproval, approval.value.validateBindingWithReview(proposal.value, proof.value, review.value, 301));

    var changed_proof = proof.value;
    changed_proof.digest = "sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
    try std.testing.expectError(error.StaleApproval, approval.value.validateBindingWithReview(proposal.value, changed_proof, review.value, 250));
}

test "studio derives immutable proposal lifecycle and rejects secret-bearing metadata" {
    var proposal = try Studio.createProposal(std.testing.allocator, proposalInput());
    defer proposal.deinit();
    try std.testing.expectEqual(Studio.ProposalStatus.draft, Studio.deriveStatus(proposal.value, null, null, null));

    var secret = proposalInput();
    secret.summary = "authorization: Bearer sentinel-secret-for-tests";
    try std.testing.expectError(error.SecretDetected, Studio.createProposal(std.testing.allocator, secret));
}

test "studio version registry validates lineage and finds accepted versions" {
    const registry = Studio.VersionRegistry{
        .machine_id = "agent.review",
        .entries = &.{
            .{ .version = 1, .fingerprint = 41, .definition_digest = "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef", .status = .accepted },
            .{ .version = 2, .fingerprint = 42, .parent_fingerprint = 41, .definition_digest = "sha256:1123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef", .status = .active },
        },
    };
    try registry.validate();
    try std.testing.expectEqual(@as(?u64, 42), registry.activeFingerprint());

    var duplicate = registry;
    duplicate.entries = &.{ registry.entries[0], registry.entries[0] };
    try std.testing.expectError(error.DuplicateVersion, duplicate.validate());
}

test "studio governance artifacts round trip and preserve exact bindings" {
    var proposal = try Studio.createProposal(std.testing.allocator, proposalInput());
    defer proposal.deinit();
    var proof = try Studio.createProof(std.testing.allocator, .{
        .proof_id = "proof-review-v2",
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
        .mutation_total = 10,
        .mutation_killed = 10,
    });
    defer proof.deinit();
    const proof_json = try Studio.formatProofJson(std.testing.allocator, proof.value);
    defer std.testing.allocator.free(proof_json);
    var parsed_proof = try Studio.parseProof(std.testing.allocator, proof_json);
    defer parsed_proof.deinit();
    try std.testing.expect(parsed_proof.value.complete());
    try std.testing.expect(std.mem.indexOf(u8, proof_json, "\"definition_fingerprint\":\"42\"") != null);

    var review = try Studio.createReview(std.testing.allocator, .{
        .review_id = "review-review-v2",
        .proposal_digest = proposal.value.digest,
        .proof_digest = proof.value.digest,
        .reviewer = "human:operator",
        .decision = .accepted,
        .summary = "Evidence is complete and the behavioral change is intentional.",
        .issued_ms = 210,
    });
    defer review.deinit();
    const review_json = try Studio.formatReviewJson(std.testing.allocator, review.value);
    defer std.testing.allocator.free(review_json);
    var parsed_review = try Studio.parseReview(std.testing.allocator, review_json);
    defer parsed_review.deinit();
    try parsed_review.value.validateBinding(proposal.value, proof.value);

    var approval = try Studio.createApproval(std.testing.allocator, .{
        .approval_id = "approval-review-v2",
        .proposal_digest = proposal.value.digest,
        .proof_digest = proof.value.digest,
        .review_digest = review.value.digest,
        .reviewer = "human:operator",
        .decision = .approved,
        .issued_ms = 220,
        .expires_ms = 300,
    });
    defer approval.deinit();
    try approval.value.validateBindingWithReview(proposal.value, proof.value, review.value, 250);
    const approval_json = try Studio.formatApprovalJson(std.testing.allocator, approval.value);
    defer std.testing.allocator.free(approval_json);
    var parsed_approval = try Studio.parseApproval(std.testing.allocator, approval_json);
    defer parsed_approval.deinit();

    const ControlEvent = enum { publish };
    const Governed = Studio.GovernedControlPolicy(ControlEvent);
    var governed = Governed{
        .proposal = proposal.value,
        .proof = proof.value,
        .review = review.value,
        .approval = approval.value,
        .now_ms = 250,
        .allowed_operations = &.{.migrate},
    };
    const control_request = zigeffect.statechart.ControlPlane(ControlEvent).Request{
        .request_id = "migrate-review-v2",
        .machine_id = proposal.value.machine_id,
        .instance_id = 7,
        .operation = .migrate,
        .expected_definition_fingerprint = proposal.value.next_fingerprint,
        .expected_fence_epoch = 9,
        .reason = "apply reviewed definition",
    };
    try std.testing.expectEqual(zigeffect.statechart.ControlDecision.human_review, governed.policy().decide(control_request));
    governed.mutation_authority = true;
    try std.testing.expectEqual(zigeffect.statechart.ControlDecision.allow, governed.policy().decide(control_request));

    var application = try Studio.createApplicationReceipt(std.testing.allocator, .{
        .application_id = "application-review-v2",
        .approval_digest = approval.value.digest,
        .machine_id = proposal.value.machine_id,
        .from_fingerprint = proposal.value.base_fingerprint,
        .to_fingerprint = proposal.value.next_fingerprint,
        .applied_by = "service:statechart-control",
        .applied_ms = 260,
        .causal_event_id = 9001,
    });
    defer application.deinit();
    try application.value.validateBinding(proposal.value, approval.value);
    const application_json = try Studio.formatApplicationJson(std.testing.allocator, application.value);
    defer std.testing.allocator.free(application_json);
    var parsed_application = try Studio.parseApplication(std.testing.allocator, application_json);
    defer parsed_application.deinit();
    try std.testing.expectEqual(@as(u64, 9001), parsed_application.value.causal_event_id);
    try std.testing.expect(std.mem.indexOf(u8, application_json, "\"causal_event_id\":\"9001\"") != null);
}

test "studio artifact creation is allocation-failure safe" {
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var proposal = try Studio.createProposal(allocator, proposalInput());
            defer proposal.deinit();
            const json = try Studio.formatProposalJson(allocator, proposal.value);
            defer allocator.free(json);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}
