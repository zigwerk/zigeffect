const std = @import("std");
const Secrets = @import("../secrets/root.zig");
const zigeffect = @import("zigeffect");

pub const proposal_schema = "zigeffect.statechart.proposal.v1";
pub const proof_schema = "zigeffect.statechart.proof.v1";
pub const review_schema = "zigeffect.statechart.review.v1";
pub const approval_schema = "zigeffect.statechart.approval.v1";
pub const application_schema = "zigeffect.statechart.application.v1";

pub const ProposalStatus = enum { draft, proved, approved, applied, rejected };
pub const ProofStatus = enum { passed, failed, unsupported };
pub const ApprovalDecision = enum { approved, rejected };
pub const ReviewDecision = enum { accepted, changes_requested, rejected };
pub const VersionStatus = enum { proposed, accepted, active, deprecated };

const DecimalU64 = struct {
    value: u64,

    pub fn jsonStringify(self: DecimalU64, writer: anytype) !void {
        var buffer: [20]u8 = undefined;
        const encoded = std.fmt.bufPrint(&buffer, "{d}", .{self.value}) catch unreachable;
        try writer.write(encoded);
    }

    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !DecimalU64 {
        const token = try source.nextAlloc(allocator, options.allocate.?);
        const text = switch (token) {
            .string, .number => |value| value,
            .allocated_string, .allocated_number => |value| value,
            else => return error.UnexpectedToken,
        };
        return .{ .value = try std.fmt.parseInt(u64, text, 10) };
    }
};

pub const ProposalInput = struct {
    proposal_id: []const u8,
    machine_id: []const u8,
    author: []const u8,
    title: []const u8,
    summary: []const u8,
    created_ms: i64,
    base_version: u64,
    next_version: u64,
    base_fingerprint: u64,
    next_fingerprint: u64,
    definition_digest: []const u8,
    diff_digest: []const u8,
};

pub const Proposal = struct {
    schema: []const u8 = proposal_schema,
    schema_version: u32 = 1,
    proposal_id: []const u8,
    machine_id: []const u8,
    author: []const u8,
    title: []const u8,
    summary: []const u8,
    created_ms: i64,
    base_version: u64,
    next_version: u64,
    base_fingerprint: u64,
    next_fingerprint: u64,
    definition_digest: []const u8,
    diff_digest: []const u8,
    digest: []const u8,

    const Wire = struct {
        schema: []const u8,
        schema_version: u32,
        proposal_id: []const u8,
        machine_id: []const u8,
        author: []const u8,
        title: []const u8,
        summary: []const u8,
        created_ms: i64,
        base_version: DecimalU64,
        next_version: DecimalU64,
        base_fingerprint: DecimalU64,
        next_fingerprint: DecimalU64,
        definition_digest: []const u8,
        diff_digest: []const u8,
        digest: []const u8,
    };

    pub fn jsonStringify(self: Proposal, writer: anytype) !void {
        try writer.write(Wire{
            .schema = self.schema,
            .schema_version = self.schema_version,
            .proposal_id = self.proposal_id,
            .machine_id = self.machine_id,
            .author = self.author,
            .title = self.title,
            .summary = self.summary,
            .created_ms = self.created_ms,
            .base_version = .{ .value = self.base_version },
            .next_version = .{ .value = self.next_version },
            .base_fingerprint = .{ .value = self.base_fingerprint },
            .next_fingerprint = .{ .value = self.next_fingerprint },
            .definition_digest = self.definition_digest,
            .diff_digest = self.diff_digest,
            .digest = self.digest,
        });
    }

    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Proposal {
        const wire = try std.json.innerParse(Wire, allocator, source, options);
        return .{
            .schema = wire.schema,
            .schema_version = wire.schema_version,
            .proposal_id = wire.proposal_id,
            .machine_id = wire.machine_id,
            .author = wire.author,
            .title = wire.title,
            .summary = wire.summary,
            .created_ms = wire.created_ms,
            .base_version = wire.base_version.value,
            .next_version = wire.next_version.value,
            .base_fingerprint = wire.base_fingerprint.value,
            .next_fingerprint = wire.next_fingerprint.value,
            .definition_digest = wire.definition_digest,
            .diff_digest = wire.diff_digest,
            .digest = wire.digest,
        };
    }

    pub fn validate(self: Proposal) !void {
        if (!std.mem.eql(u8, self.schema, proposal_schema) or self.schema_version != 1) return error.UnsupportedSchema;
        if (self.proposal_id.len == 0 or self.machine_id.len == 0 or self.author.len == 0 or self.title.len == 0 or self.summary.len == 0) return error.InvalidProposal;
        if (self.next_version != self.base_version + 1 or self.next_fingerprint == self.base_fingerprint) return error.InvalidProposal;
        if (!validDigest(self.definition_digest) or !validDigest(self.diff_digest) or !validDigest(self.digest)) return error.InvalidDigest;
        inline for (.{ self.proposal_id, self.machine_id, self.author, self.title, self.summary, self.definition_digest, self.diff_digest }) |value| {
            if (Secrets.containsSecret(value)) return error.SecretDetected;
        }
    }

    pub fn validateIntegrity(self: Proposal, allocator: std.mem.Allocator) !void {
        try self.validate();
        try verifyProposalDigest(allocator, self);
    }
};

pub const OwnedProposal = struct {
    allocator: std.mem.Allocator,
    value: Proposal,

    pub fn deinit(self: *OwnedProposal) void {
        self.allocator.free(self.value.digest);
        self.* = undefined;
    }
};

pub fn createProposal(allocator: std.mem.Allocator, input: ProposalInput) !OwnedProposal {
    const canonical = try std.json.Stringify.valueAlloc(allocator, input, .{});
    defer allocator.free(canonical);
    const digest = try digestAlloc(allocator, canonical);
    errdefer allocator.free(digest);
    const value = Proposal{
        .proposal_id = input.proposal_id,
        .machine_id = input.machine_id,
        .author = input.author,
        .title = input.title,
        .summary = input.summary,
        .created_ms = input.created_ms,
        .base_version = input.base_version,
        .next_version = input.next_version,
        .base_fingerprint = input.base_fingerprint,
        .next_fingerprint = input.next_fingerprint,
        .definition_digest = input.definition_digest,
        .diff_digest = input.diff_digest,
        .digest = digest,
    };
    try value.validate();
    return .{ .allocator = allocator, .value = value };
}

pub fn formatProposalJson(allocator: std.mem.Allocator, proposal: Proposal) ![]u8 {
    try proposal.validate();
    try verifyProposalDigest(allocator, proposal);
    return std.json.Stringify.valueAlloc(allocator, proposal, .{});
}

pub const ParsedProposal = std.json.Parsed(Proposal);

pub fn parseProposal(allocator: std.mem.Allocator, input: []const u8) !ParsedProposal {
    var parsed = try std.json.parseFromSlice(Proposal, allocator, input, .{ .allocate = .alloc_always });
    errdefer parsed.deinit();
    try parsed.value.validate();
    try verifyProposalDigest(allocator, parsed.value);
    return parsed;
}

pub const ProofInput = struct {
    proof_id: []const u8,
    proposal_digest: []const u8,
    definition_fingerprint: u64,
    validation: ProofStatus,
    analysis: ProofStatus,
    paths: ProofStatus,
    coverage: ProofStatus,
    determinism: ProofStatus,
    xstate: ProofStatus,
    temporal: ProofStatus,
    faults: ProofStatus,
    performance: ProofStatus,
    mutation_total: u32 = 0,
    mutation_killed: u32 = 0,
    truncated: bool = false,
};

pub const Proof = struct {
    schema: []const u8 = proof_schema,
    schema_version: u32 = 1,
    proof_id: []const u8,
    proposal_digest: []const u8,
    definition_fingerprint: u64,
    validation: ProofStatus,
    analysis: ProofStatus,
    paths: ProofStatus,
    coverage: ProofStatus,
    determinism: ProofStatus,
    xstate: ProofStatus,
    temporal: ProofStatus,
    faults: ProofStatus,
    performance: ProofStatus,
    mutation_total: u32,
    mutation_killed: u32,
    truncated: bool,
    digest: []const u8,

    const Wire = struct {
        schema: []const u8,
        schema_version: u32,
        proof_id: []const u8,
        proposal_digest: []const u8,
        definition_fingerprint: DecimalU64,
        validation: ProofStatus,
        analysis: ProofStatus,
        paths: ProofStatus,
        coverage: ProofStatus,
        determinism: ProofStatus,
        xstate: ProofStatus,
        temporal: ProofStatus,
        faults: ProofStatus,
        performance: ProofStatus,
        mutation_total: u32,
        mutation_killed: u32,
        truncated: bool,
        digest: []const u8,
    };

    pub fn jsonStringify(self: Proof, writer: anytype) !void {
        try writer.write(Wire{
            .schema = self.schema,
            .schema_version = self.schema_version,
            .proof_id = self.proof_id,
            .proposal_digest = self.proposal_digest,
            .definition_fingerprint = .{ .value = self.definition_fingerprint },
            .validation = self.validation,
            .analysis = self.analysis,
            .paths = self.paths,
            .coverage = self.coverage,
            .determinism = self.determinism,
            .xstate = self.xstate,
            .temporal = self.temporal,
            .faults = self.faults,
            .performance = self.performance,
            .mutation_total = self.mutation_total,
            .mutation_killed = self.mutation_killed,
            .truncated = self.truncated,
            .digest = self.digest,
        });
    }

    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Proof {
        const wire = try std.json.innerParse(Wire, allocator, source, options);
        return .{
            .schema = wire.schema,
            .schema_version = wire.schema_version,
            .proof_id = wire.proof_id,
            .proposal_digest = wire.proposal_digest,
            .definition_fingerprint = wire.definition_fingerprint.value,
            .validation = wire.validation,
            .analysis = wire.analysis,
            .paths = wire.paths,
            .coverage = wire.coverage,
            .determinism = wire.determinism,
            .xstate = wire.xstate,
            .temporal = wire.temporal,
            .faults = wire.faults,
            .performance = wire.performance,
            .mutation_total = wire.mutation_total,
            .mutation_killed = wire.mutation_killed,
            .truncated = wire.truncated,
            .digest = wire.digest,
        };
    }

    pub fn complete(self: Proof) bool {
        return !self.truncated and self.validation == .passed and self.analysis == .passed and self.paths == .passed and self.coverage == .passed and
            self.determinism == .passed and self.xstate == .passed and self.temporal == .passed and
            self.faults == .passed and self.performance == .passed and
            self.mutation_killed <= self.mutation_total and
            (self.mutation_total == 0 or @as(u64, self.mutation_killed) * 100 >= @as(u64, self.mutation_total) * 90);
    }

    pub fn validate(self: Proof) !void {
        if (!std.mem.eql(u8, self.schema, proof_schema) or self.schema_version != 1) return error.UnsupportedSchema;
        if (self.proof_id.len == 0 or !validDigest(self.proposal_digest) or !validDigest(self.digest)) return error.InvalidProof;
        if (self.mutation_killed > self.mutation_total) return error.InvalidProof;
        if (Secrets.containsSecret(self.proof_id) or Secrets.containsSecret(self.proposal_digest)) return error.SecretDetected;
    }

    pub fn validateIntegrity(self: Proof, allocator: std.mem.Allocator) !void {
        try self.validate();
        try verifyProofDigest(allocator, self);
    }
};

pub const OwnedProof = struct {
    allocator: std.mem.Allocator,
    value: Proof,

    pub fn deinit(self: *OwnedProof) void {
        self.allocator.free(self.value.digest);
        self.* = undefined;
    }
};

pub fn createProof(allocator: std.mem.Allocator, input: ProofInput) !OwnedProof {
    if (input.proof_id.len == 0 or !validDigest(input.proposal_digest) or input.mutation_killed > input.mutation_total) return error.InvalidProof;
    if (Secrets.containsSecret(input.proof_id) or Secrets.containsSecret(input.proposal_digest)) return error.SecretDetected;
    const canonical = try std.json.Stringify.valueAlloc(allocator, input, .{});
    defer allocator.free(canonical);
    const digest = try digestAlloc(allocator, canonical);
    errdefer allocator.free(digest);
    const value = Proof{
        .proof_id = input.proof_id,
        .proposal_digest = input.proposal_digest,
        .definition_fingerprint = input.definition_fingerprint,
        .validation = input.validation,
        .analysis = input.analysis,
        .paths = input.paths,
        .coverage = input.coverage,
        .determinism = input.determinism,
        .xstate = input.xstate,
        .temporal = input.temporal,
        .faults = input.faults,
        .performance = input.performance,
        .mutation_total = input.mutation_total,
        .mutation_killed = input.mutation_killed,
        .truncated = input.truncated,
        .digest = digest,
    };
    try value.validate();
    return .{ .allocator = allocator, .value = value };
}

pub fn formatProofJson(allocator: std.mem.Allocator, proof: Proof) ![]u8 {
    try proof.validate();
    try verifyProofDigest(allocator, proof);
    return std.json.Stringify.valueAlloc(allocator, proof, .{});
}

pub const ParsedProof = std.json.Parsed(Proof);

pub fn parseProof(allocator: std.mem.Allocator, input: []const u8) !ParsedProof {
    var parsed = try std.json.parseFromSlice(Proof, allocator, input, .{ .allocate = .alloc_always });
    errdefer parsed.deinit();
    try parsed.value.validate();
    try verifyProofDigest(allocator, parsed.value);
    return parsed;
}

pub const ReviewInput = struct {
    review_id: []const u8,
    proposal_digest: []const u8,
    proof_digest: []const u8,
    reviewer: []const u8,
    decision: ReviewDecision,
    summary: []const u8,
    issued_ms: i64,
};

pub const Review = struct {
    schema: []const u8 = review_schema,
    schema_version: u32 = 1,
    review_id: []const u8,
    proposal_digest: []const u8,
    proof_digest: []const u8,
    reviewer: []const u8,
    decision: ReviewDecision,
    summary: []const u8,
    issued_ms: i64,
    digest: []const u8,

    pub fn validate(self: Review) !void {
        if (!std.mem.eql(u8, self.schema, review_schema) or self.schema_version != 1) return error.UnsupportedSchema;
        if (self.review_id.len == 0 or self.reviewer.len == 0 or self.summary.len == 0 or !validDigest(self.proposal_digest) or !validDigest(self.proof_digest) or !validDigest(self.digest)) return error.InvalidReview;
        inline for (.{ self.review_id, self.reviewer, self.summary }) |value| if (Secrets.containsSecret(value)) return error.SecretDetected;
    }

    pub fn validateIntegrity(self: Review, allocator: std.mem.Allocator) !void {
        try self.validate();
        try verifyReviewDigest(allocator, self);
    }

    pub fn validateBinding(self: Review, proposal: Proposal, proof: Proof) !void {
        try self.validate();
        try proof.validate();
        if (!std.mem.eql(u8, self.proposal_digest, proposal.digest) or
            !std.mem.eql(u8, self.proof_digest, proof.digest) or
            !std.mem.eql(u8, proof.proposal_digest, proposal.digest)) return error.StaleReview;
        if (self.issued_ms < proposal.created_ms) return error.InvalidReviewTime;
        if (self.decision != .accepted or !proof.complete()) return error.UnacceptedReview;
    }
};

pub const OwnedReview = struct {
    allocator: std.mem.Allocator,
    value: Review,
    pub fn deinit(self: *OwnedReview) void {
        self.allocator.free(self.value.digest);
        self.* = undefined;
    }
};

pub fn createReview(allocator: std.mem.Allocator, input: ReviewInput) !OwnedReview {
    const canonical = try std.json.Stringify.valueAlloc(allocator, input, .{});
    defer allocator.free(canonical);
    const digest = try digestAlloc(allocator, canonical);
    errdefer allocator.free(digest);
    const value = Review{
        .review_id = input.review_id,
        .proposal_digest = input.proposal_digest,
        .proof_digest = input.proof_digest,
        .reviewer = input.reviewer,
        .decision = input.decision,
        .summary = input.summary,
        .issued_ms = input.issued_ms,
        .digest = digest,
    };
    try value.validate();
    return .{ .allocator = allocator, .value = value };
}

pub fn formatReviewJson(allocator: std.mem.Allocator, review: Review) ![]u8 {
    try review.validate();
    try verifyReviewDigest(allocator, review);
    return std.json.Stringify.valueAlloc(allocator, review, .{});
}

pub const ParsedReview = std.json.Parsed(Review);

pub fn parseReview(allocator: std.mem.Allocator, input: []const u8) !ParsedReview {
    var parsed = try std.json.parseFromSlice(Review, allocator, input, .{ .allocate = .alloc_always });
    errdefer parsed.deinit();
    try parsed.value.validate();
    try verifyReviewDigest(allocator, parsed.value);
    return parsed;
}

pub const ApprovalInput = struct {
    approval_id: []const u8,
    proposal_digest: []const u8,
    proof_digest: []const u8,
    review_digest: []const u8,
    reviewer: []const u8,
    decision: ApprovalDecision,
    issued_ms: i64,
    expires_ms: i64,
};

pub const Approval = struct {
    schema: []const u8 = approval_schema,
    schema_version: u32 = 1,
    approval_id: []const u8,
    proposal_digest: []const u8,
    proof_digest: []const u8,
    review_digest: []const u8,
    reviewer: []const u8,
    decision: ApprovalDecision,
    issued_ms: i64,
    expires_ms: i64,
    digest: []const u8,

    pub fn validate(self: Approval) !void {
        if (!std.mem.eql(u8, self.schema, approval_schema) or self.schema_version != 1) return error.UnsupportedSchema;
        if (self.approval_id.len == 0 or self.reviewer.len == 0 or self.expires_ms <= self.issued_ms or !validDigest(self.proposal_digest) or !validDigest(self.proof_digest) or !validDigest(self.digest)) return error.InvalidApproval;
        if (!validDigest(self.review_digest)) return error.InvalidApproval;
        if (Secrets.containsSecret(self.approval_id) or Secrets.containsSecret(self.reviewer)) return error.SecretDetected;
    }

    pub fn validateIntegrity(self: Approval, allocator: std.mem.Allocator) !void {
        try self.validate();
        try verifyApprovalDigest(allocator, self);
    }

    pub fn validateBinding(self: Approval, proposal: Proposal, proof: Proof, now_ms: i64) !void {
        try self.validate();
        if (now_ms < self.issued_ms) return error.InvalidApprovalTime;
        if (now_ms > self.expires_ms) return error.ExpiredApproval;
        if (self.decision != .approved or !proof.complete()) return error.UnapprovedChange;
        if (!std.mem.eql(u8, self.proposal_digest, proposal.digest) or
            !std.mem.eql(u8, self.proof_digest, proof.digest) or
            !std.mem.eql(u8, proof.proposal_digest, proposal.digest) or
            proof.definition_fingerprint != proposal.next_fingerprint)
        {
            return error.StaleApproval;
        }
    }

    pub fn validateBindingWithReview(self: Approval, proposal: Proposal, proof: Proof, review: Review, now_ms: i64) !void {
        try self.validateBinding(proposal, proof, now_ms);
        try review.validateBinding(proposal, proof);
        if (self.issued_ms < review.issued_ms) return error.InvalidApprovalTime;
        if (!std.mem.eql(u8, self.review_digest, review.digest)) return error.StaleApproval;
    }
};

pub const OwnedApproval = struct {
    allocator: std.mem.Allocator,
    value: Approval,

    pub fn deinit(self: *OwnedApproval) void {
        self.allocator.free(self.value.digest);
        self.* = undefined;
    }
};

pub fn createApproval(allocator: std.mem.Allocator, input: ApprovalInput) !OwnedApproval {
    if (input.approval_id.len == 0 or input.reviewer.len == 0 or input.expires_ms <= input.issued_ms or !validDigest(input.proposal_digest) or !validDigest(input.proof_digest) or !validDigest(input.review_digest)) return error.InvalidApproval;
    if (Secrets.containsSecret(input.approval_id) or Secrets.containsSecret(input.reviewer)) return error.SecretDetected;
    const canonical = try std.json.Stringify.valueAlloc(allocator, input, .{});
    defer allocator.free(canonical);
    const digest = try digestAlloc(allocator, canonical);
    errdefer allocator.free(digest);
    const value = Approval{
        .approval_id = input.approval_id,
        .proposal_digest = input.proposal_digest,
        .proof_digest = input.proof_digest,
        .review_digest = input.review_digest,
        .reviewer = input.reviewer,
        .decision = input.decision,
        .issued_ms = input.issued_ms,
        .expires_ms = input.expires_ms,
        .digest = digest,
    };
    try value.validate();
    return .{ .allocator = allocator, .value = value };
}

pub fn formatApprovalJson(allocator: std.mem.Allocator, approval: Approval) ![]u8 {
    try approval.validate();
    try verifyApprovalDigest(allocator, approval);
    return std.json.Stringify.valueAlloc(allocator, approval, .{});
}

pub const ParsedApproval = std.json.Parsed(Approval);

pub fn parseApproval(allocator: std.mem.Allocator, input: []const u8) !ParsedApproval {
    var parsed = try std.json.parseFromSlice(Approval, allocator, input, .{ .allocate = .alloc_always });
    errdefer parsed.deinit();
    try parsed.value.validate();
    try verifyApprovalDigest(allocator, parsed.value);
    return parsed;
}

pub const ApplicationInput = struct {
    application_id: []const u8,
    approval_digest: []const u8,
    machine_id: []const u8,
    from_fingerprint: u64,
    to_fingerprint: u64,
    applied_by: []const u8,
    applied_ms: i64,
    causal_event_id: u64,
};

pub const ApplicationReceipt = struct {
    schema: []const u8 = application_schema,
    schema_version: u32 = 1,
    application_id: []const u8,
    approval_digest: []const u8,
    machine_id: []const u8,
    from_fingerprint: u64,
    to_fingerprint: u64,
    applied_by: []const u8,
    applied_ms: i64,
    causal_event_id: u64,
    digest: []const u8,

    const Wire = struct {
        schema: []const u8,
        schema_version: u32,
        application_id: []const u8,
        approval_digest: []const u8,
        machine_id: []const u8,
        from_fingerprint: DecimalU64,
        to_fingerprint: DecimalU64,
        applied_by: []const u8,
        applied_ms: i64,
        causal_event_id: DecimalU64,
        digest: []const u8,
    };

    pub fn jsonStringify(self: ApplicationReceipt, writer: anytype) !void {
        try writer.write(Wire{
            .schema = self.schema,
            .schema_version = self.schema_version,
            .application_id = self.application_id,
            .approval_digest = self.approval_digest,
            .machine_id = self.machine_id,
            .from_fingerprint = .{ .value = self.from_fingerprint },
            .to_fingerprint = .{ .value = self.to_fingerprint },
            .applied_by = self.applied_by,
            .applied_ms = self.applied_ms,
            .causal_event_id = .{ .value = self.causal_event_id },
            .digest = self.digest,
        });
    }

    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !ApplicationReceipt {
        const wire = try std.json.innerParse(Wire, allocator, source, options);
        return .{
            .schema = wire.schema,
            .schema_version = wire.schema_version,
            .application_id = wire.application_id,
            .approval_digest = wire.approval_digest,
            .machine_id = wire.machine_id,
            .from_fingerprint = wire.from_fingerprint.value,
            .to_fingerprint = wire.to_fingerprint.value,
            .applied_by = wire.applied_by,
            .applied_ms = wire.applied_ms,
            .causal_event_id = wire.causal_event_id.value,
            .digest = wire.digest,
        };
    }

    pub fn validate(self: ApplicationReceipt) !void {
        if (!std.mem.eql(u8, self.schema, application_schema) or self.schema_version != 1) return error.UnsupportedSchema;
        if (self.application_id.len == 0 or self.machine_id.len == 0 or self.applied_by.len == 0 or self.causal_event_id == 0 or self.from_fingerprint == self.to_fingerprint or !validDigest(self.approval_digest) or !validDigest(self.digest)) return error.InvalidApplication;
        inline for (.{ self.application_id, self.machine_id, self.applied_by }) |value| if (Secrets.containsSecret(value)) return error.SecretDetected;
    }

    pub fn validateIntegrity(self: ApplicationReceipt, allocator: std.mem.Allocator) !void {
        try self.validate();
        try verifyApplicationDigest(allocator, self);
    }

    pub fn validateBinding(self: ApplicationReceipt, proposal: Proposal, approval: Approval) !void {
        try self.validate();
        try approval.validate();
        if (approval.decision != .approved) return error.UnapprovedChange;
        if (self.applied_ms < approval.issued_ms or self.applied_ms > approval.expires_ms) return error.ExpiredApproval;
        if (!std.mem.eql(u8, self.approval_digest, approval.digest) or
            !std.mem.eql(u8, self.machine_id, proposal.machine_id) or
            self.from_fingerprint != proposal.base_fingerprint or
            self.to_fingerprint != proposal.next_fingerprint) return error.StaleApplication;
    }
};

pub const OwnedApplicationReceipt = struct {
    allocator: std.mem.Allocator,
    value: ApplicationReceipt,
    pub fn deinit(self: *OwnedApplicationReceipt) void {
        self.allocator.free(self.value.digest);
        self.* = undefined;
    }
};

pub fn createApplicationReceipt(allocator: std.mem.Allocator, input: ApplicationInput) !OwnedApplicationReceipt {
    const canonical = try std.json.Stringify.valueAlloc(allocator, input, .{});
    defer allocator.free(canonical);
    const digest = try digestAlloc(allocator, canonical);
    errdefer allocator.free(digest);
    const value = ApplicationReceipt{
        .application_id = input.application_id,
        .approval_digest = input.approval_digest,
        .machine_id = input.machine_id,
        .from_fingerprint = input.from_fingerprint,
        .to_fingerprint = input.to_fingerprint,
        .applied_by = input.applied_by,
        .applied_ms = input.applied_ms,
        .causal_event_id = input.causal_event_id,
        .digest = digest,
    };
    try value.validate();
    return .{ .allocator = allocator, .value = value };
}

pub fn formatApplicationJson(allocator: std.mem.Allocator, receipt: ApplicationReceipt) ![]u8 {
    try receipt.validate();
    try verifyApplicationDigest(allocator, receipt);
    return std.json.Stringify.valueAlloc(allocator, receipt, .{});
}

pub const ParsedApplicationReceipt = std.json.Parsed(ApplicationReceipt);

pub fn parseApplication(allocator: std.mem.Allocator, input: []const u8) !ParsedApplicationReceipt {
    var parsed = try std.json.parseFromSlice(ApplicationReceipt, allocator, input, .{ .allocate = .alloc_always });
    errdefer parsed.deinit();
    try parsed.value.validate();
    try verifyApplicationDigest(allocator, parsed.value);
    return parsed;
}

pub fn deriveStatus(_: Proposal, proof: ?Proof, approval: ?Approval, applied_ms: ?i64) ProposalStatus {
    if (approval) |value| if (value.decision == .rejected) return .rejected;
    if (applied_ms != null and approval != null and approval.?.decision == .approved) return .applied;
    if (approval != null) return .approved;
    if (proof) |value| if (value.complete()) return .proved;
    return .draft;
}

pub const VersionEntry = struct {
    version: u64,
    fingerprint: u64,
    parent_fingerprint: ?u64 = null,
    definition_digest: []const u8,
    status: VersionStatus,
};

pub const VersionRegistry = struct {
    machine_id: []const u8,
    entries: []const VersionEntry,

    pub fn validate(self: VersionRegistry) !void {
        if (self.machine_id.len == 0 or self.entries.len == 0) return error.InvalidRegistry;
        var active_count: usize = 0;
        for (self.entries, 0..) |entry, index| {
            if (entry.version == 0 or entry.fingerprint == 0 or !validDigest(entry.definition_digest)) return error.InvalidVersion;
            if (entry.status == .active) active_count += 1;
            for (self.entries[0..index]) |prior| {
                if (prior.version == entry.version or prior.fingerprint == entry.fingerprint) return error.DuplicateVersion;
            }
            if (entry.parent_fingerprint) |parent| {
                var found = false;
                for (self.entries[0..index]) |prior| if (prior.fingerprint == parent) {
                    found = true;
                    break;
                };
                if (!found) return error.InvalidLineage;
            }
        }
        if (active_count > 1) return error.InvalidRegistry;
    }

    pub fn activeFingerprint(self: VersionRegistry) ?u64 {
        for (self.entries) |entry| if (entry.status == .active) return entry.fingerprint;
        return null;
    }
};

/// Bridges an exact immutable governance chain into the core control plane.
/// Human approval alone is deliberately insufficient: the host must separately
/// grant mutation authority and enumerate the permitted operations.
pub fn GovernedControlPolicy(comptime Event: type) type {
    return struct {
        const Self = @This();
        const Plane = zigeffect.statechart.ControlPlane(Event);

        proposal: Proposal,
        proof: Proof,
        review: Review,
        approval: Approval,
        now_ms: i64,
        mutation_authority: bool = false,
        allowed_operations: []const zigeffect.statechart.ControlOperation = &.{},

        pub fn policy(self: *Self) Plane.Policy {
            return .{ .context = self, .decide_fn = decideOpaque };
        }

        fn decideOpaque(context: *anyopaque, request: Plane.Request) zigeffect.statechart.ControlDecision {
            const self: *Self = @ptrCast(@alignCast(context));
            self.approval.validateBindingWithReview(self.proposal, self.proof, self.review, self.now_ms) catch return .deny;
            if (!std.mem.eql(u8, request.machine_id, self.proposal.machine_id) or
                request.expected_definition_fingerprint != self.proposal.next_fingerprint) return .deny;
            var operation_allowed = false;
            for (self.allowed_operations) |operation| if (operation == request.operation) {
                operation_allowed = true;
                break;
            };
            if (!operation_allowed) return .deny;
            return if (self.mutation_authority) .allow else .human_review;
        }
    };
}

fn validDigest(value: []const u8) bool {
    if (!std.mem.startsWith(u8, value, "sha256:") or value.len != "sha256:".len + 64) return false;
    for (value["sha256:".len..]) |byte| if (!std.ascii.isHex(byte)) return false;
    return true;
}

fn verifyProposalDigest(allocator: std.mem.Allocator, value: Proposal) !void {
    try verifyDigest(allocator, ProposalInput{
        .proposal_id = value.proposal_id,
        .machine_id = value.machine_id,
        .author = value.author,
        .title = value.title,
        .summary = value.summary,
        .created_ms = value.created_ms,
        .base_version = value.base_version,
        .next_version = value.next_version,
        .base_fingerprint = value.base_fingerprint,
        .next_fingerprint = value.next_fingerprint,
        .definition_digest = value.definition_digest,
        .diff_digest = value.diff_digest,
    }, value.digest);
}

fn verifyProofDigest(allocator: std.mem.Allocator, value: Proof) !void {
    try verifyDigest(allocator, ProofInput{
        .proof_id = value.proof_id,
        .proposal_digest = value.proposal_digest,
        .definition_fingerprint = value.definition_fingerprint,
        .validation = value.validation,
        .analysis = value.analysis,
        .paths = value.paths,
        .coverage = value.coverage,
        .determinism = value.determinism,
        .xstate = value.xstate,
        .temporal = value.temporal,
        .faults = value.faults,
        .performance = value.performance,
        .mutation_total = value.mutation_total,
        .mutation_killed = value.mutation_killed,
        .truncated = value.truncated,
    }, value.digest);
}

fn verifyReviewDigest(allocator: std.mem.Allocator, value: Review) !void {
    try verifyDigest(allocator, ReviewInput{
        .review_id = value.review_id,
        .proposal_digest = value.proposal_digest,
        .proof_digest = value.proof_digest,
        .reviewer = value.reviewer,
        .decision = value.decision,
        .summary = value.summary,
        .issued_ms = value.issued_ms,
    }, value.digest);
}

fn verifyApprovalDigest(allocator: std.mem.Allocator, value: Approval) !void {
    try verifyDigest(allocator, ApprovalInput{
        .approval_id = value.approval_id,
        .proposal_digest = value.proposal_digest,
        .proof_digest = value.proof_digest,
        .review_digest = value.review_digest,
        .reviewer = value.reviewer,
        .decision = value.decision,
        .issued_ms = value.issued_ms,
        .expires_ms = value.expires_ms,
    }, value.digest);
}

fn verifyApplicationDigest(allocator: std.mem.Allocator, value: ApplicationReceipt) !void {
    try verifyDigest(allocator, ApplicationInput{
        .application_id = value.application_id,
        .approval_digest = value.approval_digest,
        .machine_id = value.machine_id,
        .from_fingerprint = value.from_fingerprint,
        .to_fingerprint = value.to_fingerprint,
        .applied_by = value.applied_by,
        .applied_ms = value.applied_ms,
        .causal_event_id = value.causal_event_id,
    }, value.digest);
}

fn verifyDigest(allocator: std.mem.Allocator, input: anytype, actual: []const u8) !void {
    const canonical = try std.json.Stringify.valueAlloc(allocator, input, .{});
    defer allocator.free(canonical);
    const expected = try digestAlloc(allocator, canonical);
    defer allocator.free(expected);
    if (!std.mem.eql(u8, expected, actual)) return error.DigestMismatch;
}

fn digestAlloc(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.allocPrint(allocator, "sha256:{x}", .{digest});
}
