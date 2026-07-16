const std = @import("std");
const fx = @import("zigeffect");
const Project = @import("../project/root.zig");
const Testing = @import("../testing/root.zig");
const Secrets = @import("../secrets/root.zig");
const CausalGraph = @import("../causal_graph/root.zig");

pub const context_schema = "zigeffect.agent.development-context.v1";
pub const context_schema_version: u32 = 1;
pub const test_proof_handoff_schema = "zigeffect.development.test-proof-handoff.v1";
pub const test_proof_handoff_schema_version: u32 = 1;
pub const max_context_bytes: usize = 4 * 1024 * 1024;
pub const max_changed_paths: usize = 256;
pub const max_proof_items: usize = 4096;

pub const SourceIdentityOptions = struct {
    max_diff_bytes: usize = 32 * 1024 * 1024,
    max_untracked_list_bytes: usize = 4 * 1024 * 1024,
    max_untracked_file_bytes: usize = 8 * 1024 * 1024,
    max_untracked_files: usize = 4096,
};

/// Content-addressed identity for the project subtree. The commit alone is not
/// a freshness proof while a worktree is dirty, so tracked diffs plus bounded
/// untracked source contents are hashed without ever entering receipts.
pub const SourceIdentity = struct {
    allocator: std.mem.Allocator,
    revision: []u8,
    dirty: bool = false,
    available: bool = false,

    pub fn deinit(self: *SourceIdentity) void {
        self.allocator.free(self.revision);
        self.* = undefined;
    }
};

pub fn sourceIdentityAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    project_dir: std.Io.Dir,
    options: SourceIdentityOptions,
) !SourceIdentity {
    if (options.max_diff_bytes == 0 or options.max_untracked_list_bytes == 0 or options.max_untracked_file_bytes == 0 or options.max_untracked_files == 0) return error.InvalidSourceIdentityBounds;
    const head = std.process.run(allocator, io, .{
        .argv = &.{ "git", "rev-parse", "HEAD" },
        .cwd = .{ .dir = project_dir },
        .stdout_limit = .limited(4096),
        .stderr_limit = .limited(4096),
    }) catch return .{ .allocator = allocator, .revision = try allocator.dupe(u8, "working-tree"), .available = false };
    defer allocator.free(head.stdout);
    defer allocator.free(head.stderr);
    if (!processSucceeded(head.term)) return .{ .allocator = allocator, .revision = try allocator.dupe(u8, "working-tree"), .available = false };
    const head_text = std.mem.trim(u8, head.stdout, " \t\r\n");
    if (head_text.len == 0) return .{ .allocator = allocator, .revision = try allocator.dupe(u8, "working-tree"), .available = false };

    const diff = try std.process.run(allocator, io, .{
        .argv = &.{ "git", "diff", "--binary", "HEAD", "--", "." },
        .cwd = .{ .dir = project_dir },
        .stdout_limit = .limited(options.max_diff_bytes),
        .stderr_limit = .limited(4096),
    });
    defer allocator.free(diff.stdout);
    defer allocator.free(diff.stderr);
    if (!processSucceeded(diff.term)) return error.SourceIdentityUnavailable;

    const untracked = try std.process.run(allocator, io, .{
        .argv = &.{ "git", "ls-files", "--others", "--exclude-standard", "-z", "--", "." },
        .cwd = .{ .dir = project_dir },
        .stdout_limit = .limited(options.max_untracked_list_bytes),
        .stderr_limit = .limited(4096),
    });
    defer allocator.free(untracked.stdout);
    defer allocator.free(untracked.stderr);
    if (!processSucceeded(untracked.term)) return error.SourceIdentityUnavailable;

    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(head_text);
    hasher.update(&.{0});
    hasher.update(diff.stdout);
    hasher.update(&.{0});
    var paths = std.mem.splitScalar(u8, untracked.stdout, 0);
    var path_count: usize = 0;
    while (paths.next()) |path| {
        if (path.len == 0) continue;
        path_count += 1;
        if (path_count > options.max_untracked_files) return error.SourceIdentityBoundsExceeded;
        try Project.validateRelativePath(path, false);
        const content = try project_dir.readFileAlloc(io, path, allocator, .limited(options.max_untracked_file_bytes));
        defer allocator.free(content);
        hasher.update(path);
        hasher.update(&.{0});
        hasher.update(content);
        hasher.update(&.{0});
    }
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    hasher.final(&digest);
    const revision = try std.fmt.allocPrint(allocator, "git:{s}:sha256:{x}", .{ head_text, digest });
    return .{
        .allocator = allocator,
        .revision = revision,
        .dirty = diff.stdout.len != 0 or path_count != 0,
        .available = true,
    };
}

fn processSucceeded(term: std.process.Child.Term) bool {
    return switch (term) {
        .exited => |code| code == 0,
        else => false,
    };
}

pub const CheckState = enum {
    pending,
    passed,
    failed,
    stale,
    incomplete,
    blocked,
};

pub const RequirementState = enum {
    pending,
    satisfied,
    failed,
    stale,
    incomplete,
    blocked,
};

pub const CheckObservation = struct {
    id: []const u8,
    requirement: []const u8,
    component: []const u8,
    state: CheckState,
    reason: []const u8,
    evidence_ref: []const u8 = "",
    proof_ref: []const u8 = "",
    scenarios_required: usize = 0,
    scenarios_passed: usize = 0,
};

pub const RequirementObservation = struct {
    id: []const u8,
    component: []const u8,
    state: RequirementState,
    checks_total: usize,
    checks_passed: usize,
};

pub const ReconciliationView = struct {
    requirements: []const RequirementObservation,
    checks: []const CheckObservation,
    requirements_satisfied: usize,
    requirements_open: usize,
    checks_passed: usize,
    checks_pending: usize,
    checks_failed: usize,
};

pub const Reconciliation = struct {
    allocator: std.mem.Allocator,
    requirements: []RequirementObservation,
    checks: []CheckObservation,
    owned_strings: std.ArrayList([]u8) = .empty,
    requirements_satisfied: usize = 0,
    requirements_open: usize = 0,
    checks_passed: usize = 0,
    checks_pending: usize = 0,
    checks_failed: usize = 0,

    pub fn deinit(self: *Reconciliation) void {
        for (self.owned_strings.items) |value| self.allocator.free(value);
        self.owned_strings.deinit(self.allocator);
        self.allocator.free(self.requirements);
        self.allocator.free(self.checks);
        self.* = undefined;
    }

    pub fn view(self: *const Reconciliation) ReconciliationView {
        return .{
            .requirements = self.requirements,
            .checks = self.checks,
            .requirements_satisfied = self.requirements_satisfied,
            .requirements_open = self.requirements_open,
            .checks_passed = self.checks_passed,
            .checks_pending = self.checks_pending,
            .checks_failed = self.checks_failed,
        };
    }

    pub fn check(self: *const Reconciliation, id: []const u8) ?CheckObservation {
        for (self.checks) |candidate| if (std.mem.eql(u8, candidate.id, id)) return candidate;
        return null;
    }
};

/// Derive observed project truth from validated Testing v2 evidence. Manifest
/// status remains declared intent and is never rewritten by this function.
pub fn reconcileAlloc(
    allocator: std.mem.Allocator,
    manifest: Project.Manifest,
    run: ?*const Testing.TestRunReceipt,
    current_source_revision: []const u8,
) !Reconciliation {
    return reconcileImplAlloc(allocator, manifest, run, current_source_revision);
}

fn reconcileImplAlloc(
    allocator: std.mem.Allocator,
    manifest: Project.Manifest,
    run: ?*const Testing.TestRunReceipt,
    current_source_revision: []const u8,
) !Reconciliation {
    try manifest.validate();
    if (current_source_revision.len == 0 or Secrets.containsSecret(current_source_revision)) return error.InvalidSourceRevision;
    if (run) |receipt_run| try receipt_run.validate();
    const expected_manifest_digest = try manifestDigestAlloc(allocator, manifest);
    defer allocator.free(expected_manifest_digest);

    var result = Reconciliation{
        .allocator = allocator,
        .requirements = try allocator.alloc(RequirementObservation, manifest.requirements.len),
        .checks = undefined,
    };
    errdefer {
        for (result.owned_strings.items) |value| allocator.free(value);
        result.owned_strings.deinit(allocator);
        allocator.free(result.requirements);
    }
    result.checks = try allocator.alloc(CheckObservation, manifest.acceptance_checks.len);
    errdefer allocator.free(result.checks);

    for (manifest.acceptance_checks, 0..) |check, check_index| {
        const requirement = manifest.requirement(check.requirement) orelse return error.InvalidAcceptanceCheck;
        var observation = CheckObservation{
            .id = check.id,
            .requirement = check.requirement,
            .component = requirement.component,
            .state = if (check.status == .blocked) .blocked else .pending,
            .reason = if (check.status == .blocked) "declared blocked" else "required scenario evidence missing",
        };

        var saw_failed = false;
        var saw_stale = false;
        var saw_incomplete = false;
        var saw_missing = false;
        for (manifest.test_scenarios) |scenario| {
            if (!scenario.required or !std.mem.eql(u8, scenario.acceptance_check, check.id)) continue;
            observation.scenarios_required += 1;
            const receipt = findScenarioReceipt(run, scenario.id) orelse {
                saw_missing = true;
                continue;
            };
            if (!receiptMatchesManifest(receipt, manifest, scenario, expected_manifest_digest)) {
                saw_incomplete = true;
                continue;
            }
            if (!std.mem.eql(u8, receipt.source_revision, current_source_revision) or
                (run != null and !std.mem.eql(u8, run.?.source_revision, current_source_revision)))
            {
                saw_stale = true;
                continue;
            }
            switch (receipt.verdict()) {
                .passed => if (receipt.execution.native_receipt) {
                    observation.scenarios_passed += 1;
                    const reference = try Testing.Protocol.publishedReceiptPathAlloc(allocator, scenario.id);
                    try result.owned_strings.append(allocator, reference);
                    observation.evidence_ref = reference;
                    const proof_reference = try std.fmt.allocPrint(allocator, ".zigeffect/handoffs/tests/{s}.json", .{scenario.id});
                    try result.owned_strings.append(allocator, proof_reference);
                    observation.proof_ref = proof_reference;
                } else {
                    saw_incomplete = true;
                },
                .failed => saw_failed = true,
                .incomplete, .unsupported, .skipped, .canceled => saw_incomplete = true,
            }
        }

        if (check.status != .blocked) {
            if (observation.scenarios_required > 0 and observation.scenarios_passed == observation.scenarios_required) {
                observation.state = .passed;
                observation.reason = "all required scenarios have fresh complete native receipts";
            } else if (saw_failed) {
                observation.state = .failed;
                observation.reason = "matching required scenario failed";
            } else if (saw_stale) {
                observation.state = .stale;
                observation.reason = "matching evidence belongs to a different source revision";
            } else if (saw_incomplete) {
                observation.state = .incomplete;
                observation.reason = "matching evidence is incomplete, unsupported, or non-native";
            } else if (saw_missing or observation.scenarios_required == 0) {
                observation.state = .pending;
                observation.reason = "required scenario evidence missing";
            }
        }
        result.checks[check_index] = observation;
        switch (observation.state) {
            .passed => result.checks_passed += 1,
            .failed => result.checks_failed += 1,
            .pending, .stale, .incomplete, .blocked => result.checks_pending += 1,
        }
    }

    for (manifest.requirements, 0..) |requirement, requirement_index| {
        var checks_total: usize = 0;
        var checks_passed: usize = 0;
        var saw_failed = false;
        var saw_stale = false;
        var saw_incomplete = false;
        var saw_blocked = requirement.status == .blocked;
        for (result.checks) |check| {
            if (!std.mem.eql(u8, check.requirement, requirement.id)) continue;
            checks_total += 1;
            switch (check.state) {
                .passed => checks_passed += 1,
                .failed => saw_failed = true,
                .stale => saw_stale = true,
                .incomplete => saw_incomplete = true,
                .blocked => saw_blocked = true,
                .pending => {},
            }
        }
        const state: RequirementState = if (saw_blocked)
            .blocked
        else if (checks_total > 0 and checks_passed == checks_total)
            .satisfied
        else if (saw_failed)
            .failed
        else if (saw_stale)
            .stale
        else if (saw_incomplete)
            .incomplete
        else
            .pending;
        result.requirements[requirement_index] = .{
            .id = requirement.id,
            .component = requirement.component,
            .state = state,
            .checks_total = checks_total,
            .checks_passed = checks_passed,
        };
        if (state == .satisfied) result.requirements_satisfied += 1 else result.requirements_open += 1;
    }
    return result;
}

fn findScenarioReceipt(run: ?*const Testing.TestRunReceipt, scenario_id: []const u8) ?*const Testing.TestReceipt {
    const receipt_run = run orelse return null;
    for (receipt_run.receipts) |*receipt| if (std.mem.eql(u8, receipt.scenario.id, scenario_id)) return receipt;
    return null;
}

fn receiptMatchesManifest(receipt: *const Testing.TestReceipt, manifest: Project.Manifest, scenario: Project.TestScenario, expected_manifest_digest: []const u8) bool {
    return std.mem.eql(u8, receipt.project, manifest.name) and
        std.mem.eql(u8, receipt.scenario.id, scenario.id) and
        std.mem.eql(u8, receipt.scenario.requirement, scenario.requirement) and
        std.mem.eql(u8, receipt.scenario.acceptance_check, scenario.acceptance_check) and
        std.mem.eql(u8, receipt.scenario.component, scenario.component) and
        std.mem.eql(u8, receipt.scenario.command, scenario.command) and
        receipt.execution.native_receipt and
        receipt.execution.tool_version.len != 0 and
        receipt.execution.target.len != 0 and
        receipt.execution.optimize.len != 0 and
        std.mem.eql(u8, receipt.execution.manifest_digest, expected_manifest_digest) and
        (manifest.capability_requirements.len == 0 or receipt.execution.adapter_profile.len != 0) and
        receiptCommandDigestMatches(receipt.execution.command_digest, manifest.command(scenario.command).?, scenario.native_test_filter);
}

fn receiptCommandDigestMatches(actual: []const u8, command: Project.Command, native_test_filter: ?[]const u8) bool {
    if (actual.len != 71 or !std.mem.startsWith(u8, actual, "sha256:")) return false;
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    for (command.argv) |arg| {
        hasher.update(arg);
        hasher.update(&.{0});
    }
    if (native_test_filter) |filter| {
        hasher.update("-Dtest-filter=");
        hasher.update(filter);
        hasher.update(&.{0});
    }
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    hasher.final(&digest);
    const expected = std.fmt.bytesToHex(digest, .lower);
    return std.mem.eql(u8, actual[7..], &expected);
}

/// Owns the validated per-scenario receipts used to derive project truth.
/// Published Testing v2 process receipts take precedence over the aggregate
/// latest run because a focused run intentionally replaces latest.json.
pub const EvidenceCollection = struct {
    allocator: std.mem.Allocator,
    parsed_receipts: std.ArrayList(Testing.ParsedReceipt) = .empty,
    receipts: std.ArrayList(Testing.TestReceipt) = .empty,
    collected_run: Testing.TestRunReceipt = .{
        .project = "uninitialized",
        .source_revision = "uninitialized",
        .discovered = 0,
        .selected = 0,
        .passed = 0,
        .failed = 0,
        .incomplete = 0,
        .unsupported = 0,
        .skipped = 0,
        .canceled = 0,
        .receipts = &.{},
    },
    has_run: bool = false,

    pub fn deinit(self: *EvidenceCollection) void {
        for (self.parsed_receipts.items) |*receipt| receipt.deinit();
        self.parsed_receipts.deinit(self.allocator);
        self.receipts.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn run(self: *const EvidenceCollection) ?*const Testing.TestRunReceipt {
        return if (self.has_run) &self.collected_run else null;
    }
};

pub fn collectEvidenceAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    project_dir: std.Io.Dir,
    manifest: Project.Manifest,
    current_source_revision: []const u8,
    max_artifact_bytes: usize,
) !EvidenceCollection {
    try manifest.validate();
    if (current_source_revision.len == 0 or Secrets.containsSecret(current_source_revision)) return error.InvalidSourceRevision;
    if (max_artifact_bytes == 0) return error.InvalidArtifactLimit;

    var result = EvidenceCollection{ .allocator = allocator };
    errdefer result.deinit();
    for (manifest.test_scenarios) |scenario| {
        const published_path = try Testing.Protocol.publishedReceiptPathAlloc(allocator, scenario.id);
        defer allocator.free(published_path);
        const published_text = project_dir.readFileAlloc(io, published_path, allocator, .limited(max_artifact_bytes)) catch |failure| switch (failure) {
            error.FileNotFound => null,
            else => return failure,
        };
        if (published_text) |text| {
            defer allocator.free(text);
            var parsed = try Testing.parseReceipt(allocator, text);
            errdefer parsed.deinit();
            try result.parsed_receipts.append(allocator, parsed);
            try result.receipts.append(allocator, result.parsed_receipts.items[result.parsed_receipts.items.len - 1].value);
            continue;
        }
    }

    var passed: usize = 0;
    var failed: usize = 0;
    var incomplete: usize = 0;
    var unsupported: usize = 0;
    var skipped: usize = 0;
    var canceled: usize = 0;
    for (result.receipts.items) |receipt| switch (receipt.status) {
        .passed => passed += 1,
        .failed => failed += 1,
        .incomplete => incomplete += 1,
        .unsupported => unsupported += 1,
        .skipped => skipped += 1,
        .canceled => canceled += 1,
    };
    result.collected_run = .{
        .project = manifest.name,
        .source_revision = current_source_revision,
        .discovered = manifest.test_scenarios.len,
        .selected = result.receipts.items.len,
        .passed = passed,
        .failed = failed,
        .incomplete = incomplete,
        .unsupported = unsupported,
        .skipped = skipped,
        .canceled = canceled,
        .receipts = result.receipts.items,
    };
    result.has_run = result.receipts.items.len != 0;
    if (result.has_run) try result.collected_run.validate();
    return result;
}

pub const ContextGraphSummary = struct {
    records: usize,
    edges: usize,
    sessions: u64,
    cursor: u64,
};

pub const ContextInput = struct {
    manifest: Project.Manifest,
    reconciliation: ReconciliationView,
    task_id: []const u8,
    source_revision: []const u8,
    source_dirty: bool,
    changed_paths: []const []const u8 = &.{},
    graph: ?ContextGraphSummary = null,
    byte_budget: usize = 32 * 1024,
};

pub fn compileContextJsonAlloc(allocator: std.mem.Allocator, input: ContextInput) ![]u8 {
    try input.manifest.validate();
    if (input.byte_budget < 512) return error.ContextBudgetTooSmall;
    if (input.byte_budget > max_context_bytes or input.changed_paths.len > max_changed_paths) return error.ContextBudgetExceeded;
    if (Secrets.containsSecret(input.task_id) or Secrets.containsSecret(input.source_revision)) return error.SecretDetected;
    for (input.changed_paths) |path| if (Secrets.containsSecret(path)) return error.SecretDetected;

    const attempts = [_]ContextSections{
        .{},
        .{ .graph = false },
        .{ .graph = false, .affected = false },
        .{ .graph = false, .affected = false, .observations = false },
    };
    for (attempts) |sections| {
        const json = try renderContextAlloc(allocator, input, sections);
        if (json.len <= input.byte_budget) return json;
        allocator.free(json);
    }
    return error.ContextBudgetTooSmall;
}

pub const ProjectContextRequest = struct {
    task_id: []const u8,
    source_revision: []const u8,
    source_dirty: bool,
    changed_paths: []const []const u8 = &.{},
    byte_budget: usize = 32 * 1024,
};

/// One canonical read endpoint for an agent: collect validated Testing v2
/// evidence, reconcile observed truth, summarize the embedded NenDB graph, and
/// compile only the task-relevant context that fits the declared byte budget.
pub fn compileProjectContextJsonAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    project_dir: std.Io.Dir,
    manifest: Project.Manifest,
    request: ProjectContextRequest,
) ![]u8 {
    var evidence = try collectEvidenceAlloc(
        allocator,
        io,
        project_dir,
        manifest,
        request.source_revision,
        manifest.safety.limits.max_artifact_bytes,
    );
    defer evidence.deinit();
    var reconciliation = try reconcileAlloc(allocator, manifest, evidence.run(), request.source_revision);
    defer reconciliation.deinit();

    var graph_summary: ?ContextGraphSummary = null;
    var snapshot = CausalGraph.Snapshot.open(allocator, io, project_dir, .{
        .path = manifest.artifacts.graph,
        .max_wal_bytes = manifest.safety.limits.max_artifact_bytes,
        .max_records = manifest.safety.limits.max_runtime_events,
    }) catch |failure| switch (failure) {
        error.FileNotFound => null,
        else => return failure,
    };
    defer if (snapshot) |*value| value.deinit();
    if (snapshot) |*value| {
        const summary = value.summary();
        graph_summary = .{
            .records = summary.records,
            .edges = summary.edges,
            .sessions = summary.sessions,
            .cursor = summary.newest_durable_event_id orelse 0,
        };
    }
    return compileContextJsonAlloc(allocator, .{
        .manifest = manifest,
        .reconciliation = reconciliation.view(),
        .task_id = request.task_id,
        .source_revision = request.source_revision,
        .source_dirty = request.source_dirty,
        .changed_paths = request.changed_paths,
        .graph = graph_summary,
        .byte_budget = request.byte_budget,
    });
}

const ContextSections = struct {
    graph: bool = true,
    affected: bool = true,
    observations: bool = true,
};

fn renderContextAlloc(allocator: std.mem.Allocator, input: ContextInput, sections: ContextSections) ![]u8 {
    const requirement = resolveRequirement(input.manifest, input.reconciliation, input.task_id) orelse return error.TaskNotFound;
    const declared_requirement = input.manifest.requirement(requirement.id) orelse return error.TaskNotFound;
    const component = input.manifest.component(requirement.component) orelse return error.TaskNotFound;
    const manifest_digest = try manifestDigestAlloc(allocator, input.manifest);
    defer allocator.free(manifest_digest);
    var selected_checks = std.ArrayList(CheckObservation).empty;
    defer selected_checks.deinit(allocator);
    if (sections.observations) {
        for (input.reconciliation.checks) |check| {
            if (std.mem.eql(u8, check.requirement, requirement.id)) try selected_checks.append(allocator, check);
        }
    }
    var affected = std.ArrayList([]const u8).empty;
    defer affected.deinit(allocator);
    var requirement_scenarios = std.ArrayList(Project.TestScenario).empty;
    defer requirement_scenarios.deinit(allocator);
    for (input.manifest.test_scenarios) |scenario| {
        if (std.mem.eql(u8, scenario.requirement, requirement.id)) try requirement_scenarios.append(allocator, scenario);
    }
    if (sections.affected) {
        for (input.manifest.test_scenarios) |scenario| {
            if (!scenarioAffected(scenario, input.changed_paths)) continue;
            try affected.append(allocator, scenario.id);
        }
    }
    var omitted_storage: [3][]const u8 = undefined;
    var omitted_count: usize = 0;
    if (!sections.graph) {
        omitted_storage[omitted_count] = "graph";
        omitted_count += 1;
    }
    if (!sections.affected) {
        omitted_storage[omitted_count] = "affected_scenarios";
        omitted_count += 1;
    }
    if (!sections.observations) {
        omitted_storage[omitted_count] = "check_observations";
        omitted_count += 1;
    }
    const graph: ?ContextGraphSummary = if (sections.graph) input.graph else null;
    const json = try std.json.Stringify.valueAlloc(allocator, .{
        .schema = context_schema,
        .schema_version = context_schema_version,
        .project = .{ .name = input.manifest.name, .kind = input.manifest.kind },
        .task = .{
            .id = input.task_id,
            .requirement = requirement.id,
            .component = requirement.component,
            .state = requirement.state,
        },
        .contract = .{
            .summary = declared_requirement.summary,
            .declared_status = declared_requirement.status,
            .component = .{
                .id = component.id,
                .kind = component.kind,
                .path = component.path,
                .depends_on = component.depends_on,
                .capabilities = component.capabilities,
            },
            .checks = selected_checks.items,
            .scenarios = requirement_scenarios.items,
        },
        .authority = .{
            .execution_posture = input.manifest.execution_posture,
            .allow_network = input.manifest.policy.allow_network,
            .process_approval_required = input.manifest.policy.require_approval_for_processes,
            .mutation_authorized = false,
        },
        .source = .{ .revision = input.source_revision, .manifest_digest = manifest_digest, .dirty = input.source_dirty },
        .observed = .{
            .requirements_satisfied = input.reconciliation.requirements_satisfied,
            .requirements_open = input.reconciliation.requirements_open,
            .checks_passed = input.reconciliation.checks_passed,
            .checks_pending = input.reconciliation.checks_pending,
            .checks_failed = input.reconciliation.checks_failed,
            .checks = selected_checks.items,
        },
        .changed_paths = input.changed_paths,
        .affected_scenarios = affected.items,
        .graph = graph,
        .counterfactual = .{
            .expect = if (requirement_scenarios.items.len == 0) "satisfy the selected acceptance contract" else requirement_scenarios.items[0].label,
            .action = if (requirement_scenarios.items.len == 0) "run the manifest-owned verification command" else requirement_scenarios.items[0].native_test_filter orelse requirement_scenarios.items[0].command,
            .preserve = &.{ "no new causal findings", "no pending fibers", "no undeclared service dependencies" },
        },
        .coordination = .{
            .active_claims = @as(usize, 0),
            .likely_conflicts = @as(usize, 0),
            .source = "workspace DevelopmentRuntime",
            .available = false,
        },
        .active_workflows = .{
            .count = @as(usize, 0),
            .available = false,
        },
        .budget = .{ .requested_bytes = input.byte_budget },
        .omitted = omitted_storage[0..omitted_count],
        .completeness = .{
            .contract = true,
            .evidence_reconciled = true,
            .graph_available = graph != null,
            .coordination_available = false,
            .workflow_registry_available = false,
        },
        .queries = .{
            .graph_since = "zigeffect graph since <cursor> --limit 256 --json",
            .graph_path = "zigeffect graph path <from> <to> --json",
            .run_affected = "zigeffect test affected --changed <path> --json",
            .handoff = "zigeffect agent handoff --provider <provider> --session <session> --json",
            .progress = ".zigeffect/tests/progress.jsonl",
        },
    }, .{});
    errdefer allocator.free(json);
    if (Secrets.containsSecret(json)) return error.SecretDetected;
    return json;
}

fn resolveRequirement(manifest: Project.Manifest, reconciliation: ReconciliationView, task: []const u8) ?RequirementObservation {
    const prefix = "task-";
    const candidate = if (std.mem.startsWith(u8, task, prefix)) task[prefix.len..] else task;
    for (reconciliation.requirements) |requirement| {
        if (std.mem.eql(u8, requirement.id, candidate)) return requirement;
    }
    for (manifest.requirements) |declared| {
        if (std.mem.indexOf(u8, declared.id, candidate) == null and std.mem.indexOf(u8, declared.summary, task) == null) continue;
        for (reconciliation.requirements) |requirement| if (std.mem.eql(u8, requirement.id, declared.id)) return requirement;
    }
    return null;
}

fn scenarioAffected(scenario: Project.TestScenario, changed_paths: []const []const u8) bool {
    if (changed_paths.len == 0) return false;
    for (changed_paths) |changed| for (scenario.source_roots) |root| {
        if (std.mem.eql(u8, changed, root) or pathWithin(changed, root) or pathWithin(root, changed)) return true;
    };
    return false;
}

fn pathWithin(path: []const u8, root: []const u8) bool {
    return path.len > root.len and std.mem.startsWith(u8, path, root) and path[root.len] == '/';
}

pub const TaskState = enum {
    proposed,
    scoped,
    claimed,
    running,
    input_required,
    authority_required,
    reviewing,
    integrating,
    verifying,
    completed,
    blocked,
    failed,
    canceled,
};

pub const TaskEvent = enum {
    scope,
    claim,
    start,
    require_input,
    provide_input,
    require_authority,
    grant_authority,
    submit_review,
    request_changes,
    accept_review,
    start_verification,
    verification_passed,
    verification_failed,
    complete,
    block,
    fail,
    cancel,
};

pub const Task = struct {
    id: []const u8,
    requirement: []const u8,
    acceptance_check: []const u8,
    component: []const u8,
    state: TaskState = .proposed,
    revision: u64 = 0,

    pub fn init(id: []const u8, requirement: []const u8, acceptance_check: []const u8, component: []const u8) Task {
        return .{ .id = id, .requirement = requirement, .acceptance_check = acceptance_check, .component = component };
    }

    pub fn apply(self: *Task, event: TaskEvent) !void {
        const next: TaskState = switch (self.state) {
            .proposed => switch (event) {
                .scope => .scoped,
                .cancel => .canceled,
                else => return error.InvalidTaskTransition,
            },
            .scoped => switch (event) {
                .claim => .claimed,
                .block => .blocked,
                .cancel => .canceled,
                else => return error.InvalidTaskTransition,
            },
            .claimed => switch (event) {
                .start => .running,
                .block => .blocked,
                .cancel => .canceled,
                else => return error.InvalidTaskTransition,
            },
            .running => switch (event) {
                .require_input => .input_required,
                .require_authority => .authority_required,
                .submit_review => .reviewing,
                .block => .blocked,
                .fail => .failed,
                .cancel => .canceled,
                else => return error.InvalidTaskTransition,
            },
            .input_required => switch (event) {
                .provide_input => .running,
                .block => .blocked,
                .cancel => .canceled,
                else => return error.InvalidTaskTransition,
            },
            .authority_required => switch (event) {
                .grant_authority => .running,
                .block => .blocked,
                .cancel => .canceled,
                else => return error.InvalidTaskTransition,
            },
            .reviewing => switch (event) {
                .request_changes => .running,
                .accept_review => .integrating,
                .block => .blocked,
                .fail => .failed,
                .cancel => .canceled,
                else => return error.InvalidTaskTransition,
            },
            .integrating => switch (event) {
                .start_verification => .verifying,
                .block => .blocked,
                .fail => .failed,
                .cancel => .canceled,
                else => return error.InvalidTaskTransition,
            },
            .verifying => switch (event) {
                .verification_passed => .completed,
                .verification_failed => .failed,
                .block => .blocked,
                .cancel => .canceled,
                else => return error.InvalidTaskTransition,
            },
            .completed, .blocked, .failed, .canceled => return error.InvalidTaskTransition,
        };
        self.state = next;
        self.revision = std.math.add(u64, self.revision, 1) catch return error.TaskRevisionOverflow;
    }
};

/// Durable task statechart backed by the existing ZigEffect workflow journal.
/// A caller may provide an in-memory journal for deterministic tests or a
/// FileJournalStore wrapped by CausalJournalStore for process durability and
/// automatic NenDB correlation. Optimistic sequence checks fence concurrent
/// agents and idempotency keys make retries safe.
pub const TaskJournal = struct {
    store: fx.workflow.JournalStore,

    pub fn init(store: fx.workflow.JournalStore) TaskJournal {
        return .{ .store = store };
    }

    pub fn load(self: TaskJournal, allocator: std.mem.Allocator, declared: Task) !Task {
        var batch = try self.store.readAll(allocator);
        defer batch.deinit();
        return replayTask(declared, batch.events);
    }

    pub fn transition(
        self: TaskJournal,
        allocator: std.mem.Allocator,
        declared: Task,
        expected_revision: u64,
        event: TaskEvent,
        idempotency_key: []const u8,
    ) !Task {
        if (idempotency_key.len == 0 or Secrets.containsSecret(idempotency_key)) return error.InvalidTaskIdempotencyKey;
        var batch = try self.store.readAll(allocator);
        defer batch.deinit();
        var current = try replayTask(declared, batch.events);
        const workflow_id = taskWorkflowId(declared.id);
        for (batch.events) |recorded| {
            if (recorded.workflow_id == workflow_id and std.mem.eql(u8, recorded.idempotency_key, idempotency_key)) return current;
        }
        if (current.revision != expected_revision) return error.StaleTaskRevision;
        try current.apply(event);

        var next_sequence: u64 = 1;
        for (batch.events) |recorded| next_sequence = @max(next_sequence, recorded.sequence +| 1);
        const kind: fx.workflow.WorkflowEventKind = switch (event) {
            .scope => .workflow_started,
            .verification_passed => .workflow_completed,
            .verification_failed, .fail => .workflow_failed,
            .cancel => .workflow_cancelled,
            else => .step_completed,
        };
        _ = try self.store.append(.{
            .expected_next_sequence = next_sequence,
            .event = .{
                .sequence = next_sequence,
                .kind = kind,
                .workflow_id = workflow_id,
                .execution_id = 1,
                .parent_sequence = if (next_sequence > 1) next_sequence - 1 else null,
                .name = @tagName(event),
                .status = @tagName(current.state),
                .redacted_detail = declared.requirement,
                .idempotency_key = idempotency_key,
            },
        });
        return current;
    }
};

fn replayTask(declared: Task, events: []const fx.workflow.WorkflowEvent) !Task {
    var current = Task.init(declared.id, declared.requirement, declared.acceptance_check, declared.component);
    const workflow_id = taskWorkflowId(declared.id);
    for (events) |recorded| {
        if (recorded.workflow_id != workflow_id) continue;
        const event = std.meta.stringToEnum(TaskEvent, recorded.name) orelse return error.InvalidTaskJournalEvent;
        try current.apply(event);
        if (!std.mem.eql(u8, recorded.status, @tagName(current.state))) return error.TaskJournalStateMismatch;
    }
    return current;
}

fn taskWorkflowId(task_id: []const u8) u64 {
    return fx.stableCausalContextId(task_id);
}

pub const Lease = struct {
    key: []const u8,
    owner: []const u8,
    expires_at: u64,
    fencing_token: u64,
};

pub const LeaseRegistry = struct {
    allocator: std.mem.Allocator,
    leases: std.ArrayList(Lease) = .empty,

    pub fn init(allocator: std.mem.Allocator) LeaseRegistry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *LeaseRegistry) void {
        for (self.leases.items) |lease| {
            self.allocator.free(lease.key);
            self.allocator.free(lease.owner);
        }
        self.leases.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn claim(self: *LeaseRegistry, key: []const u8, owner: []const u8, now: u64, expires_at: u64) !Lease {
        if (key.len == 0 or owner.len == 0 or expires_at <= now) return error.InvalidLease;
        if (Secrets.containsSecret(key) or Secrets.containsSecret(owner)) return error.SecretDetected;
        for (self.leases.items) |*lease| {
            if (!std.mem.eql(u8, lease.key, key)) continue;
            if (now <= lease.expires_at) return error.LeaseConflict;
            const next_token = std.math.add(u64, lease.fencing_token, 1) catch return error.LeaseTokenOverflow;
            const next_owner = try self.allocator.dupe(u8, owner);
            self.allocator.free(lease.owner);
            lease.owner = next_owner;
            lease.expires_at = expires_at;
            lease.fencing_token = next_token;
            return lease.*;
        }
        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);
        const owned_owner = try self.allocator.dupe(u8, owner);
        errdefer self.allocator.free(owned_owner);
        const lease = Lease{ .key = owned_key, .owner = owned_owner, .expires_at = expires_at, .fencing_token = 1 };
        try self.leases.append(self.allocator, lease);
        return lease;
    }

    pub fn renew(self: *LeaseRegistry, key: []const u8, owner: []const u8, fencing_token: u64, now: u64, expires_at: u64) !Lease {
        if (expires_at <= now) return error.InvalidLease;
        for (self.leases.items) |*lease| {
            if (!std.mem.eql(u8, lease.key, key)) continue;
            if (!std.mem.eql(u8, lease.owner, owner) or lease.fencing_token != fencing_token or now > lease.expires_at) return error.StaleLease;
            lease.expires_at = expires_at;
            return lease.*;
        }
        return error.LeaseNotFound;
    }

    pub fn release(self: *LeaseRegistry, key: []const u8, owner: []const u8, fencing_token: u64) !void {
        for (self.leases.items, 0..) |lease, index| {
            if (!std.mem.eql(u8, lease.key, key)) continue;
            if (!std.mem.eql(u8, lease.owner, owner) or lease.fencing_token != fencing_token) return error.StaleLease;
            const removed = self.leases.orderedRemove(index);
            self.allocator.free(removed.key);
            self.allocator.free(removed.owner);
            return;
        }
        return error.LeaseNotFound;
    }

    pub fn require(self: *const LeaseRegistry, key: []const u8, owner: []const u8, fencing_token: u64, now: u64) !Lease {
        for (self.leases.items) |lease| {
            if (!std.mem.eql(u8, lease.key, key)) continue;
            if (!std.mem.eql(u8, lease.owner, owner) or lease.fencing_token != fencing_token or now > lease.expires_at) return error.StaleLease;
            return lease;
        }
        return error.LeaseNotFound;
    }
};

pub const WorkPacket = struct {
    id: []const u8,
    causal_id: u64,
    task_id: []const u8,
    requirement: []const u8,
    acceptance_check: []const u8,
    component: []const u8,
    source_revision: []const u8,
    lease_key: []const u8,
    lease_fencing_token: u64,
    allowed_paths: []const []const u8,
    excluded_paths: []const []const u8 = &.{},
    dependency_task_ids: []const []const u8 = &.{},
    verification_commands: []const []const u8,

    pub fn validate(self: WorkPacket) !void {
        if (self.causal_id == 0 or self.lease_fencing_token == 0 or self.verification_commands.len == 0 or
            self.allowed_paths.len == 0 or self.allowed_paths.len > max_proof_items or self.excluded_paths.len > max_proof_items or self.dependency_task_ids.len > max_proof_items or
            self.verification_commands.len > max_proof_items) return error.InvalidWorkPacket;
        inline for (.{ self.id, self.task_id, self.requirement, self.acceptance_check, self.component, self.source_revision, self.lease_key }) |value| {
            if (value.len == 0) return error.InvalidWorkPacket;
            if (Secrets.containsSecret(value)) return error.SecretDetected;
        }
        for (self.allowed_paths) |path| try validateProofPath(path);
        for (self.excluded_paths) |path| try validateProofPath(path);
    }
};

pub const ProofVerdict = enum { passed, failed, incomplete };

pub const ProofBundle = struct {
    work_packet_id: []const u8,
    work_packet_causal_id: u64,
    task_id: []const u8,
    requirement: []const u8,
    acceptance_check: []const u8,
    source_revision: []const u8,
    change_set_id: u64,
    graph_session_id: u64,
    lease_fencing_token: u64,
    receipt_refs: []const []const u8,
    receipt_digests: []const []const u8,
    diff_digest: []const u8,
    verification_command_digests: []const []const u8,
    changed_paths: []const []const u8,
    causal_event_ids: []const u64,
    invariants: []const InvariantOutcome,
    limitations: []const []const u8 = &.{},
    verdict: ProofVerdict,
};

pub const InvariantOutcome = struct {
    id: []const u8,
    passed: bool,
    causal_event_ids: []const u64,
};

pub fn verifyProof(packet: WorkPacket, proof: ProofBundle) !void {
    try packet.validate();
    if (!std.mem.eql(u8, proof.work_packet_id, packet.id) or proof.work_packet_causal_id != packet.causal_id) return error.ProofPacketMismatch;
    if (!std.mem.eql(u8, proof.task_id, packet.task_id) or
        !std.mem.eql(u8, proof.requirement, packet.requirement) or
        !std.mem.eql(u8, proof.acceptance_check, packet.acceptance_check)) return error.ProofScopeMismatch;
    if (!std.mem.eql(u8, proof.source_revision, packet.source_revision)) return error.ProofSourceMismatch;
    if (proof.lease_fencing_token != packet.lease_fencing_token) return error.ProofLeaseMismatch;
    if (proof.change_set_id == 0 or proof.graph_session_id == 0 or proof.receipt_refs.len == 0 or
        proof.receipt_refs.len != proof.receipt_digests.len or !validSha256Digest(proof.diff_digest) or
        proof.verification_command_digests.len == 0 or proof.invariants.len == 0 or
        proof.changed_paths.len == 0 or proof.changed_paths.len > max_proof_items or
        proof.causal_event_ids.len == 0 or proof.receipt_refs.len > max_proof_items or
        proof.causal_event_ids.len > max_proof_items or proof.limitations.len > max_proof_items or
        proof.verdict != .passed) return error.ProofIncomplete;
    for (proof.receipt_refs, proof.receipt_digests) |reference, digest| {
        if (reference.len == 0 or Secrets.containsSecret(reference)) return error.SecretDetected;
        if (!validSha256Digest(digest)) return error.ProofIncomplete;
    }
    for (proof.verification_command_digests) |digest| if (!validSha256Digest(digest)) return error.ProofIncomplete;
    for (proof.changed_paths) |changed| {
        try validateProofPath(changed);
        var allowed = false;
        for (packet.allowed_paths) |root| if (std.mem.eql(u8, changed, root) or pathWithin(changed, root)) {
            allowed = true;
        };
        for (packet.excluded_paths) |root| if (std.mem.eql(u8, changed, root) or pathWithin(changed, root)) return error.ProofChangedExcludedPath;
        if (!allowed) return error.ProofChangedUndeclaredPath;
    }
    for (proof.invariants) |invariant| {
        if (invariant.id.len == 0 or Secrets.containsSecret(invariant.id)) return error.SecretDetected;
        if (!invariant.passed or invariant.causal_event_ids.len == 0 or invariant.causal_event_ids.len > max_proof_items) return error.ProofIncomplete;
    }
    for (proof.limitations) |limitation| if (Secrets.containsSecret(limitation)) return error.SecretDetected;
}

pub fn verifyProofJoin(packets: []const WorkPacket, proofs: []const ProofBundle) !void {
    if (packets.len == 0 or packets.len != proofs.len or packets.len > 256) return error.InvalidProofJoin;
    for (packets, proofs) |packet, proof| try verifyProof(packet, proof);
    for (proofs, 0..) |proof, proof_index| {
        for (proof.changed_paths) |path| for (proofs[0..proof_index]) |previous| for (previous.changed_paths) |previous_path| {
            if (std.mem.eql(u8, path, previous_path) or pathWithin(path, previous_path) or pathWithin(previous_path, path)) return error.ProofChangeConflict;
        };
        for (packets[proof_index].dependency_task_ids) |dependency| {
            var found = false;
            for (proofs) |candidate| {
                if (std.mem.eql(u8, candidate.task_id, dependency)) found = true;
            }
            if (!found) return error.ProofDependencyMissing;
        }
    }
}

/// Construct the semantic fan-in fact after proof verification. Each proof is
/// a typed multi-parent link to its application graph, so a swarm integration
/// is queryable without pretending the coordinator owns those foreign WALs.
pub fn integrationJoinEvent(packets: []const WorkPacket, proofs: []const ProofBundle) !fx.CausalEvent {
    try verifyProofJoin(packets, proofs);
    if (proofs.len > fx.max_causal_links) return error.IntegrationJoinLinkLimit;
    var event = fx.CausalEvent{
        .kind = .activity_completed,
        .label = "Development.integrationJoin",
        .status = "success",
        .redacted_detail = "verified-proof-fan-in",
        .context = .{ .change_set_id = proofs[proofs.len - 1].change_set_id },
    };
    for (proofs) |proof| try event.addLink(.{
        .kind = .proof,
        .event_id = proof.causal_event_ids[proof.causal_event_ids.len - 1],
        .graph_session_id = proof.graph_session_id,
    });
    return event;
}

fn validateProofPath(path: []const u8) !void {
    if (path.len == 0 or path.len > 4096 or Secrets.containsSecret(path)) return error.InvalidProofPath;
    try Project.validateRelativePath(path, false);
}

fn validSha256Digest(value: []const u8) bool {
    if (value.len != 71 or !std.mem.startsWith(u8, value, "sha256:")) return false;
    for (value[7..]) |byte| if (!std.ascii.isHex(byte)) return false;
    return true;
}

const TestReceiptProof = struct {
    scenario: []const u8,
    requirement: []const u8,
    acceptance_check: []const u8,
    status: Testing.TestStatus,
    source_revision: []const u8,
    command_digest: []const u8,
    receipt_digest: []const u8,
    replay_command: []const u8,
    causal_graph_session_id: ?u64,
    assertions: []const Testing.AssertionResult,
    limitations: []const []const u8,
};

/// Automatic proof handoff emitted after every manifest-owned test run. Every
/// receipt and the complete run are content addressed so another agent can
/// reject stale or substituted evidence without replaying terminal prose.
pub fn testProofHandoffJsonAlloc(
    allocator: std.mem.Allocator,
    manifest: Project.Manifest,
    run: Testing.TestRunReceipt,
) ![]u8 {
    try manifest.validate();
    try run.validate();
    if (!std.mem.eql(u8, manifest.name, run.project)) return error.ProofProjectMismatch;
    const manifest_json = try manifest.jsonAlloc(allocator);
    defer allocator.free(manifest_json);
    const run_json = try run.jsonAlloc(allocator);
    defer allocator.free(run_json);
    const manifest_digest = try sha256DigestAlloc(allocator, manifest_json);
    defer allocator.free(manifest_digest);
    const run_digest = try sha256DigestAlloc(allocator, run_json);
    defer allocator.free(run_digest);

    const proofs = try allocator.alloc(TestReceiptProof, run.receipts.len);
    defer allocator.free(proofs);
    var owned_digests = std.ArrayList([]u8).empty;
    defer {
        for (owned_digests.items) |digest| allocator.free(digest);
        owned_digests.deinit(allocator);
    }
    for (run.receipts, 0..) |receipt, index| {
        const receipt_json = try receipt.jsonAlloc(allocator);
        defer allocator.free(receipt_json);
        const receipt_digest = try sha256DigestAlloc(allocator, receipt_json);
        errdefer allocator.free(receipt_digest);
        try owned_digests.append(allocator, receipt_digest);
        proofs[index] = .{
            .scenario = receipt.scenario.id,
            .requirement = receipt.scenario.requirement,
            .acceptance_check = receipt.scenario.acceptance_check,
            .status = receipt.status,
            .source_revision = receipt.source_revision,
            .command_digest = receipt.execution.command_digest,
            .receipt_digest = receipt_digest,
            .replay_command = receipt.replay_command,
            .causal_graph_session_id = receipt.causal_graph_session_id,
            .assertions = receipt.assertions,
            .limitations = receipt.limitations,
        };
    }
    const json = try std.json.Stringify.valueAlloc(allocator, .{
        .schema = test_proof_handoff_schema,
        .schema_version = test_proof_handoff_schema_version,
        .project = manifest.name,
        .source_revision = run.source_revision,
        .selection = run.selection,
        .selection_value = run.selection_value,
        .status = run.status(),
        .authoritative = run.status() == .passed and run.completeness.complete(),
        .manifest_digest = manifest_digest,
        .run_digest = run_digest,
        .proofs = proofs,
        .limitations = run.limitations,
        .next = .{
            .context = "zigeffect agent context --task <task> --json",
            .graph_path = "zigeffect graph path <from> <to> --json",
        },
    }, .{});
    errdefer allocator.free(json);
    if (Secrets.containsSecret(json)) return error.SecretDetected;
    return json;
}

fn sha256DigestAlloc(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.allocPrint(allocator, "sha256:{x}", .{digest});
}

pub fn manifestDigestAlloc(allocator: std.mem.Allocator, manifest: Project.Manifest) ![]u8 {
    try manifest.validate();
    const json = try manifest.jsonAlloc(allocator);
    defer allocator.free(json);
    return sha256DigestAlloc(allocator, json);
}

pub const FederatedEventRef = struct {
    project: []const u8,
    component: []const u8,
    graph_session_id: u64,
    durable_event_id: u64,

    pub fn validate(self: FederatedEventRef) !void {
        if (self.project.len == 0 or self.component.len == 0 or self.graph_session_id == 0 or self.durable_event_id == 0) return error.InvalidGraphReference;
        if (Secrets.containsSecret(self.project) or Secrets.containsSecret(self.component)) return error.SecretDetected;
    }
};

pub const FederatedGraphMount = struct {
    project: []const u8,
    component: []const u8,
    root: std.Io.Dir,
    options: CausalGraph.Options = .{},

    pub fn validate(self: FederatedGraphMount) !void {
        if (self.project.len == 0 or self.component.len == 0 or Secrets.containsSecret(self.project) or Secrets.containsSecret(self.component)) return error.InvalidGraphMount;
        try self.options.validate();
    }
};

/// Read-only logical view over independently owned application graphs. Each
/// graph retains its own WAL, limits, and writer; the workspace runtime joins
/// exact graph references without creating a multi-process shared database.
pub const FederatedGraph = struct {
    io: std.Io,
    mounts: []const FederatedGraphMount,

    pub fn init(io: std.Io, mounts: []const FederatedGraphMount) !FederatedGraph {
        for (mounts, 0..) |candidate, index| {
            try candidate.validate();
            for (mounts[0..index]) |previous| if (std.mem.eql(u8, candidate.project, previous.project) and std.mem.eql(u8, candidate.component, previous.component)) return error.DuplicateGraphMount;
        }
        return .{ .io = io, .mounts = mounts };
    }

    pub fn resolveJsonAlloc(self: FederatedGraph, allocator: std.mem.Allocator, reference: FederatedEventRef) ![]u8 {
        try reference.validate();
        const selected_mount = self.findMount(reference.project, reference.component) orelse return error.GraphMountNotFound;
        var snapshot = try CausalGraph.Snapshot.open(allocator, self.io, selected_mount.root, selected_mount.options);
        defer snapshot.deinit();
        const record = try snapshot.recordJsonAlloc(allocator, reference.durable_event_id);
        defer allocator.free(record);
        const Header = struct { session_id: u64 };
        var header = try std.json.parseFromSlice(Header, allocator, record, .{ .ignore_unknown_fields = true });
        defer header.deinit();
        if (header.value.session_id != reference.graph_session_id) return error.GraphSessionMismatch;
        const encoded_project = try std.json.Stringify.valueAlloc(allocator, reference.project, .{});
        defer allocator.free(encoded_project);
        const encoded_component = try std.json.Stringify.valueAlloc(allocator, reference.component, .{});
        defer allocator.free(encoded_component);
        return std.fmt.allocPrint(
            allocator,
            "{{\"schema\":\"zigeffect.development.federated-record.v1\",\"project\":{s},\"component\":{s},\"graph_session_id\":{d},\"durable_event_id\":{d},\"record\":{s}}}",
            .{ encoded_project, encoded_component, reference.graph_session_id, reference.durable_event_id, record },
        );
    }

    pub fn joinJsonAlloc(self: FederatedGraph, allocator: std.mem.Allocator, references: []const FederatedEventRef) ![]u8 {
        if (references.len == 0 or references.len > max_proof_items) return error.InvalidGraphReference;
        var output = std.ArrayList(u8).empty;
        errdefer output.deinit(allocator);
        try output.appendSlice(allocator, "{\"schema\":\"zigeffect.development.federated-join.v1\",\"records\":[");
        for (references, 0..) |reference, index| {
            const record = try self.resolveJsonAlloc(allocator, reference);
            defer allocator.free(record);
            if (index != 0) try output.append(allocator, ',');
            try output.appendSlice(allocator, record);
        }
        try output.print(allocator, "],\"count\":{d}}}", .{references.len});
        return output.toOwnedSlice(allocator);
    }

    fn findMount(self: FederatedGraph, project: []const u8, component: []const u8) ?FederatedGraphMount {
        for (self.mounts) |candidate| if (std.mem.eql(u8, candidate.project, project) and std.mem.eql(u8, candidate.component, component)) return candidate;
        return null;
    }
};

pub const RepairEpisode = struct {
    fingerprint: []const u8,
    requirement: []const u8,
    before: FederatedEventRef,
    after: FederatedEventRef,
    change_set_id: u64,
    proof_event_ids: []const u64,
    summary: []const u8,
    invalidated_by_revision: []const u8 = "",

    pub fn validate(self: RepairEpisode) !void {
        try self.before.validate();
        try self.after.validate();
        if (self.fingerprint.len == 0 or self.requirement.len == 0 or self.change_set_id == 0 or
            self.proof_event_ids.len == 0 or self.proof_event_ids.len > max_proof_items or self.summary.len == 0) return error.InvalidRepairEpisode;
        inline for (.{ self.fingerprint, self.requirement, self.summary, self.invalidated_by_revision }) |value| {
            if (Secrets.containsSecret(value)) return error.SecretDetected;
        }
    }
};

pub const RepairMemory = struct {
    allocator: std.mem.Allocator,
    episodes: std.ArrayList(RepairEpisode) = .empty,

    pub fn init(allocator: std.mem.Allocator) RepairMemory {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *RepairMemory) void {
        for (self.episodes.items) |episode| self.freeEpisode(episode);
        self.episodes.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn remember(self: *RepairMemory, episode: RepairEpisode) !void {
        try episode.validate();
        for (self.episodes.items) |existing| if (std.mem.eql(u8, existing.fingerprint, episode.fingerprint) and existing.change_set_id == episode.change_set_id) return error.DuplicateRepairEpisode;
        const owned = try self.cloneEpisode(episode);
        errdefer self.freeEpisode(owned);
        try self.episodes.append(self.allocator, owned);
    }

    pub fn queryAlloc(
        self: *const RepairMemory,
        allocator: std.mem.Allocator,
        fingerprint: []const u8,
        source_revision: []const u8,
        limit: usize,
    ) ![]RepairEpisode {
        if (fingerprint.len == 0 or source_revision.len == 0 or limit == 0 or limit > 256) return error.InvalidRepairQuery;
        if (Secrets.containsSecret(fingerprint) or Secrets.containsSecret(source_revision)) return error.SecretDetected;
        var matches = std.ArrayList(RepairEpisode).empty;
        defer matches.deinit(allocator);
        var index = self.episodes.items.len;
        while (index > 0 and matches.items.len < limit) {
            index -= 1;
            const episode = self.episodes.items[index];
            if (!std.mem.eql(u8, episode.fingerprint, fingerprint)) continue;
            if (episode.invalidated_by_revision.len != 0 and std.mem.eql(u8, episode.invalidated_by_revision, source_revision)) continue;
            try matches.append(allocator, episode);
        }
        return matches.toOwnedSlice(allocator);
    }

    fn cloneEpisode(self: *RepairMemory, source: RepairEpisode) !RepairEpisode {
        const fingerprint = try self.allocator.dupe(u8, source.fingerprint);
        errdefer self.allocator.free(fingerprint);
        const requirement = try self.allocator.dupe(u8, source.requirement);
        errdefer self.allocator.free(requirement);
        const before_project = try self.allocator.dupe(u8, source.before.project);
        errdefer self.allocator.free(before_project);
        const before_component = try self.allocator.dupe(u8, source.before.component);
        errdefer self.allocator.free(before_component);
        const after_project = try self.allocator.dupe(u8, source.after.project);
        errdefer self.allocator.free(after_project);
        const after_component = try self.allocator.dupe(u8, source.after.component);
        errdefer self.allocator.free(after_component);
        const proof_ids = try self.allocator.dupe(u64, source.proof_event_ids);
        errdefer self.allocator.free(proof_ids);
        const summary = try self.allocator.dupe(u8, source.summary);
        errdefer self.allocator.free(summary);
        const invalidated = try self.allocator.dupe(u8, source.invalidated_by_revision);
        errdefer self.allocator.free(invalidated);
        return .{
            .fingerprint = fingerprint,
            .requirement = requirement,
            .before = .{ .project = before_project, .component = before_component, .graph_session_id = source.before.graph_session_id, .durable_event_id = source.before.durable_event_id },
            .after = .{ .project = after_project, .component = after_component, .graph_session_id = source.after.graph_session_id, .durable_event_id = source.after.durable_event_id },
            .change_set_id = source.change_set_id,
            .proof_event_ids = proof_ids,
            .summary = summary,
            .invalidated_by_revision = invalidated,
        };
    }

    fn freeEpisode(self: *RepairMemory, episode: RepairEpisode) void {
        self.allocator.free(episode.fingerprint);
        self.allocator.free(episode.requirement);
        self.allocator.free(episode.before.project);
        self.allocator.free(episode.before.component);
        self.allocator.free(episode.after.project);
        self.allocator.free(episode.after.component);
        self.allocator.free(episode.proof_event_ids);
        self.allocator.free(episode.summary);
        self.allocator.free(episode.invalidated_by_revision);
    }
};

pub const EvidenceApi = struct {
    state: *anyopaque,
    reconcile_alloc_fn: *const fn (*anyopaque, std.mem.Allocator, Project.Manifest, ?*const Testing.TestRunReceipt, []const u8) anyerror!Reconciliation,

    pub fn from(comptime Implementation: type, implementation: *Implementation) EvidenceApi {
        return .{
            .state = implementation,
            .reconcile_alloc_fn = struct {
                fn call(raw: *anyopaque, allocator: std.mem.Allocator, manifest: Project.Manifest, run: ?*const Testing.TestRunReceipt, revision: []const u8) anyerror!Reconciliation {
                    return (@as(*Implementation, @ptrCast(@alignCast(raw)))).reconcileAlloc(allocator, manifest, run, revision);
                }
            }.call,
        };
    }

    pub fn reconcileAlloc(self: EvidenceApi, allocator: std.mem.Allocator, manifest: Project.Manifest, run: ?*const Testing.TestRunReceipt, revision: []const u8) !Reconciliation {
        return self.reconcile_alloc_fn(self.state, allocator, manifest, run, revision);
    }
};

pub const CoordinationApi = struct {
    leases: *LeaseRegistry,
    tasks: ?*TaskJournal = null,
};

pub const ContextApi = struct {
    state: *anyopaque,
    compile_alloc_fn: *const fn (*anyopaque, std.mem.Allocator, ContextInput) anyerror![]u8,

    pub fn from(comptime Implementation: type, implementation: *Implementation) ContextApi {
        return .{
            .state = implementation,
            .compile_alloc_fn = struct {
                fn call(raw: *anyopaque, allocator: std.mem.Allocator, input: ContextInput) anyerror![]u8 {
                    return (@as(*Implementation, @ptrCast(@alignCast(raw)))).compileAlloc(allocator, input);
                }
            }.call,
        };
    }

    pub fn compileAlloc(self: ContextApi, allocator: std.mem.Allocator, input: ContextInput) ![]u8 {
        return self.compile_alloc_fn(self.state, allocator, input);
    }
};

pub const GraphApi = struct {
    federation: *const FederatedGraph,

    pub fn resolveJsonAlloc(self: GraphApi, allocator: std.mem.Allocator, reference: FederatedEventRef) ![]u8 {
        return self.federation.resolveJsonAlloc(allocator, reference);
    }

    pub fn joinJsonAlloc(self: GraphApi, allocator: std.mem.Allocator, references: []const FederatedEventRef) ![]u8 {
        return self.federation.joinJsonAlloc(allocator, references);
    }
};

pub const EvidenceService = fx.kernel.Service("zigeffect/Development/Evidence", EvidenceApi);
pub const CoordinationService = fx.kernel.Service("zigeffect/Development/Coordination", CoordinationApi);
pub const ContextService = fx.kernel.Service("zigeffect/Development/Context", ContextApi);
pub const GraphService = fx.kernel.Service("zigeffect/Development/FederatedGraph", GraphApi);

pub fn evidenceLayer(api: EvidenceApi) @TypeOf(fx.kernel.Layer.succeed(EvidenceService, api)) {
    return fx.kernel.Layer.succeed(EvidenceService, api);
}

pub fn coordinationLayer(api: CoordinationApi) @TypeOf(fx.kernel.Layer.succeed(CoordinationService, api)) {
    return fx.kernel.Layer.succeed(CoordinationService, api);
}

pub fn contextLayer(api: ContextApi) @TypeOf(fx.kernel.Layer.succeed(ContextService, api)) {
    return fx.kernel.Layer.succeed(ContextService, api);
}

pub fn graphLayer(api: GraphApi) @TypeOf(fx.kernel.Layer.succeed(GraphService, api)) {
    return fx.kernel.Layer.succeed(GraphService, api);
}

pub fn rootLayer(
    evidence: EvidenceApi,
    coordination: CoordinationApi,
    context: ContextApi,
) @TypeOf(fx.kernel.Layer.mergeAll(.{
    fx.kernel.Layer.succeed(EvidenceService, evidence),
    fx.kernel.Layer.succeed(CoordinationService, coordination),
    fx.kernel.Layer.succeed(ContextService, context),
})) {
    return fx.kernel.Layer.mergeAll(.{
        fx.kernel.Layer.succeed(EvidenceService, evidence),
        fx.kernel.Layer.succeed(CoordinationService, coordination),
        fx.kernel.Layer.succeed(ContextService, context),
    });
}

pub fn workspaceRootLayer(
    evidence: EvidenceApi,
    coordination: CoordinationApi,
    context: ContextApi,
    graph: GraphApi,
) @TypeOf(fx.kernel.Layer.mergeAll(.{
    fx.kernel.Layer.succeed(EvidenceService, evidence),
    fx.kernel.Layer.succeed(CoordinationService, coordination),
    fx.kernel.Layer.succeed(ContextService, context),
    fx.kernel.Layer.succeed(GraphService, graph),
})) {
    return fx.kernel.Layer.mergeAll(.{
        fx.kernel.Layer.succeed(EvidenceService, evidence),
        fx.kernel.Layer.succeed(CoordinationService, coordination),
        fx.kernel.Layer.succeed(ContextService, context),
        fx.kernel.Layer.succeed(GraphService, graph),
    });
}

pub const DefaultEvidence = struct {
    pub fn reconcileAlloc(_: *DefaultEvidence, allocator: std.mem.Allocator, manifest: Project.Manifest, run: ?*const Testing.TestRunReceipt, revision: []const u8) !Reconciliation {
        return reconcileImplAlloc(allocator, manifest, run, revision);
    }
};

pub const DefaultContext = struct {
    pub fn compileAlloc(_: *DefaultContext, allocator: std.mem.Allocator, input: ContextInput) ![]u8 {
        return compileContextJsonAlloc(allocator, input);
    }
};

const CompileContextBase = fx.kernel.Effect([]u8, anyerror, .{ContextService});
pub const CompileContextEffect = CompileContextBase.Stateful(ContextInput);

pub fn compileContext(input: ContextInput) CompileContextEffect {
    return CompileContextEffect.init(input, struct {
        fn run(value: ContextInput, context: *CompileContextEffect.Context) anyerror![]u8 {
            const json = try context.service(ContextService).compileAlloc(context.allocator(), value);
            _ = context.recordCausal(.{
                .kind = .activity_completed,
                .service_key = ContextService.service_key,
                .label = "Development.compileContext",
                .status = "success",
                .redacted_detail = value.task_id,
                .context = .{ .development_task_id = fx.stableCausalContextId(value.task_id) },
            });
            return json;
        }
    }.run);
}

pub const TaskTransitionInput = struct {
    task: Task,
    expected_revision: u64,
    event: TaskEvent,
    idempotency_key: []const u8,
};
const TransitionTaskBase = fx.kernel.Effect(Task, anyerror, .{CoordinationService});
pub const TransitionTaskEffect = TransitionTaskBase.Stateful(TaskTransitionInput);

pub fn transitionTask(input: TaskTransitionInput) TransitionTaskEffect {
    return TransitionTaskEffect.init(input, struct {
        fn run(value: TaskTransitionInput, context: *TransitionTaskEffect.Context) anyerror!Task {
            const journal = context.service(CoordinationService).tasks orelse return error.TaskJournalUnavailable;
            const task = try journal.transition(context.allocator(), value.task, value.expected_revision, value.event, value.idempotency_key);
            _ = context.recordCausal(.{
                .kind = .workflow_event_recorded,
                .service_key = CoordinationService.service_key,
                .label = @tagName(value.event),
                .status = @tagName(task.state),
                .redacted_detail = task.requirement,
                .context = .{
                    .development_task_id = fx.stableCausalContextId(task.id),
                    .requirement_id = fx.stableCausalContextId(task.requirement),
                    .acceptance_check_id = fx.stableCausalContextId(task.acceptance_check),
                    .component_id = fx.stableCausalContextId(task.component),
                },
            });
            return task;
        }
    }.run);
}

const FederatedJoinBase = fx.kernel.Effect([]u8, anyerror, .{GraphService});
pub const FederatedJoinEffect = FederatedJoinBase.Stateful([]const FederatedEventRef);

pub fn federatedJoin(references: []const FederatedEventRef) FederatedJoinEffect {
    return FederatedJoinEffect.init(references, struct {
        fn run(value: []const FederatedEventRef, context: *FederatedJoinEffect.Context) anyerror![]u8 {
            const json = try context.service(GraphService).joinJsonAlloc(context.allocator(), value);
            _ = context.recordCausal(.{
                .kind = .activity_completed,
                .service_key = GraphService.service_key,
                .label = "Development.federatedJoin",
                .status = "success",
                .redacted_detail = "bounded-read-only-graph-join",
            });
            return json;
        }
    }.run);
}
