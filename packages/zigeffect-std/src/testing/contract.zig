const std = @import("std");
const Project = @import("../project/root.zig");
const Secrets = @import("../secrets/root.zig");
const Capability = @import("../capability/root.zig");

pub const scenario_schema = "zigeffect.test-scenario.v1";
pub const receipt_schema = "zigeffect.test-receipt.v1";
pub const run_receipt_schema = "zigeffect.test-run.v1";
pub const schema_version: u32 = 1;

pub const ContractError = error{
    UnsupportedSchema,
    InvalidScenario,
    InvalidIdentifier,
    InvalidPath,
    InvalidBounds,
    InvalidTimeline,
    InvalidStatus,
    InvalidCounts,
    SecretDetected,
};

pub const FaultProfile = enum {
    none,
    standard,
    exhaustive,
    allocation,
    schedule,
    recovery,
    executor,
};

pub const FaultKind = enum {
    none,
    allocation_failure,
    schedule_choice,
    timeout,
    cancellation,
    interruption,
    spawn_failure,
    retry_exhaustion,
    process_failure,
    http_failure,
    sql_failure,
    storage_failure,
    transport_failure,
    broker_failure,
    cache_failure,
    object_storage_failure,
    telemetry_failure,
    lease_loss,
    database_restart,
    network_partition,
    migration_failure,
    redelivery,
    journal_crash,
    corrupt_artifact,
    executor,
};

pub const TestStatus = enum {
    passed,
    failed,
    incomplete,
    unsupported,
    skipped,
    canceled,
};

pub const AssertionStatus = enum {
    passed,
    failed,
    skipped,
};

pub const SelectionReason = enum {
    all,
    scenario,
    requirement,
    component,
    tag,
    affected,
    replay,
};

pub const Scenario = struct {
    schema: []const u8 = scenario_schema,
    schema_version: u32 = schema_version,
    id: []const u8,
    label: []const u8,
    requirement: []const u8,
    acceptance_check: []const u8,
    component: []const u8,
    command: []const u8,
    source_roots: []const []const u8 = &.{},
    tags: []const []const u8 = &.{},
    default_seed: u64 = 1,
    fault_profile: FaultProfile = .standard,
    required: bool = true,

    pub fn validate(self: Scenario) ContractError!void {
        if (!std.mem.eql(u8, self.schema, scenario_schema) or self.schema_version != schema_version) return error.UnsupportedSchema;
        try validateIdentifier(self.id);
        try validateIdentifier(self.requirement);
        try validateIdentifier(self.acceptance_check);
        try validateIdentifier(self.component);
        try validateIdentifier(self.command);
        try validateFreeLabel(self.label);
        if (self.default_seed == 0) return error.InvalidBounds;
        for (self.source_roots, 0..) |root, index| {
            validatePath(root) catch return error.InvalidPath;
            for (self.source_roots[0..index]) |previous| {
                if (std.mem.eql(u8, previous, root)) return error.InvalidScenario;
            }
        }
        for (self.tags, 0..) |tag, index| {
            try validateIdentifier(tag);
            for (self.tags[0..index]) |previous| {
                if (std.mem.eql(u8, previous, tag)) return error.InvalidScenario;
            }
        }
    }
};

pub const SourceReference = struct {
    id: []const u8 = "",
    path: []const u8 = "",
    line: u32 = 0,
    column: u32 = 0,

    pub fn validate(self: SourceReference) ContractError!void {
        if (self.id.len == 0 and self.path.len == 0) return;
        try validateIdentifier(self.id);
        validatePath(self.path) catch return error.InvalidPath;
        if (self.line == 0 or self.column == 0) return error.InvalidBounds;
    }
};

pub const AssertionResult = struct {
    id: []const u8,
    label: []const u8,
    status: AssertionStatus,
    source: SourceReference = .{},
    causal_event_ids: []const u64 = &.{},
    expected: []const u8 = "",
    actual: []const u8 = "",
    detail: []const u8 = "",
    repair_hint: []const u8 = "",

    pub fn validate(self: AssertionResult) ContractError!void {
        try validateIdentifier(self.id);
        try validateFreeLabel(self.label);
        try self.source.validate();
    }
};

/// Identity domain used by assertion `causal_event_ids`. Durable IDs can be
/// passed directly to `zigeffect graph event`; runtime-local IDs cannot.
pub const CausalEventIdSpace = enum {
    runtime_local,
    graph_durable,
};

pub const Completeness = struct {
    dropped_assertions: usize = 0,
    dropped_diagnostics: usize = 0,
    dropped_runtime_events: usize = 0,
    stale_source_refs: usize = 0,
    truncated_artifacts: usize = 0,
    sampled_events: usize = 0,

    pub fn complete(self: Completeness) bool {
        return self.dropped_assertions == 0 and
            self.dropped_diagnostics == 0 and
            self.dropped_runtime_events == 0 and
            self.stale_source_refs == 0 and
            self.truncated_artifacts == 0 and
            self.sampled_events == 0;
    }
};

pub const MinimalCase = struct {
    kind: []const u8,
    input: []const u8 = "",
    seed: u64,
    case_index: usize,
    shrink_steps: usize = 0,
    shrink_path: []const u8 = "",
    schedule_choices: []const u32 = &.{},
    artifact: []const u8 = "",

    pub fn validate(self: MinimalCase) ContractError!void {
        try validateIdentifier(self.kind);
        if (self.seed == 0) return error.InvalidBounds;
        if (self.artifact.len != 0) validatePath(self.artifact) catch return error.InvalidPath;
        if (self.shrink_path.len != 0) try validateFreeLabel(self.shrink_path);
    }
};

pub const MemorySummary = struct {
    allocations: usize = 0,
    frees: usize = 0,
    live_allocations: usize = 0,
    live_bytes: usize = 0,
    peak_bytes: usize = 0,
    invalid_frees: usize = 0,
    out_of_memory: usize = 0,

    pub fn safe(self: MemorySummary) bool {
        return self.live_allocations == 0 and self.live_bytes == 0 and self.invalid_frees == 0;
    }
};

pub const CausalSummary = struct {
    events: usize = 0,
    findings: usize = 0,
    pending_fibers: usize = 0,
    leaked_resources: usize = 0,
    assertion_failures: usize = 0,

    pub fn clean(self: CausalSummary) bool {
        return self.findings == 0 and self.pending_fibers == 0 and self.leaked_resources == 0 and self.assertion_failures == 0;
    }
};

pub const ExecutionIdentity = struct {
    tool_version: []const u8 = "",
    target: []const u8 = "",
    optimize: []const u8 = "",
    command_digest: []const u8 = "",
    manifest_digest: []const u8 = "",
    worktree_dirty: bool = false,
    native_receipt: bool = false,
    adapter_profile: []const u8 = "",
    adapters: []const Capability.AdapterEvidence = &.{},

    pub fn validate(self: ExecutionIdentity) ContractError!void {
        inline for (.{ self.tool_version, self.target, self.optimize, self.command_digest, self.manifest_digest }) |value| {
            if (value.len > 4096) return error.InvalidBounds;
            if (value.len != 0) try validateFreeLabel(value);
        }
        if (self.adapter_profile.len == 0 and self.adapters.len != 0) return error.InvalidScenario;
        if (self.adapter_profile.len != 0) try validateIdentifier(self.adapter_profile);
        for (self.adapters, 0..) |adapter, index| {
            adapter.validate() catch |err| return if (err == error.SecretDetected) error.SecretDetected else error.InvalidScenario;
            if (!std.mem.eql(u8, adapter.profile_id, self.adapter_profile)) return error.InvalidScenario;
            for (self.adapters[0..index]) |previous| {
                if (std.mem.eql(u8, previous.requirement_id, adapter.requirement_id)) return error.InvalidScenario;
            }
        }
    }
};

pub const CoverageDimension = enum {
    requirement,
    acceptance,
    assertion,
    fault,
    causal,
    statechart,
    schema,
    mutation,
    executor,
    performance,
    sandbox,
};

pub const CoverageTarget = struct {
    id: []const u8,
    label: []const u8,
    dimension: CoverageDimension,
    required: bool = true,
    repair_hint: []const u8 = "",
    next_command: []const u8 = "",

    pub fn validate(self: CoverageTarget) ContractError!void {
        try validateIdentifier(self.id);
        try validateFreeLabel(self.label);
        if (self.repair_hint.len != 0) try validateFreeLabel(self.repair_hint);
        if (self.next_command.len != 0) try validateFreeLabel(self.next_command);
    }
};

pub const CoverageHit = struct {
    target_id: []const u8,
    evidence_id: []const u8,

    pub fn validate(self: CoverageHit) ContractError!void {
        try validateIdentifier(self.target_id);
        try validateIdentifier(self.evidence_id);
    }
};

pub const CoverageSummary = struct {
    targets: usize = 0,
    hits: usize = 0,
    required_gaps: usize = 0,
    advisory_gaps: usize = 0,
    truncated: bool = false,

    pub fn complete(self: CoverageSummary) bool {
        return self.required_gaps == 0 and !self.truncated;
    }
};

pub const EvidenceKind = enum {
    model,
    schedule,
    differential,
    virtual_world,
    mutation,
    performance,
    sandbox,
};

pub const EvidenceSummary = struct {
    attempted: bool = false,
    status: TestStatus = .skipped,
    planned: usize = 0,
    executed: usize = 0,
    passed: usize = 0,
    failed: usize = 0,
    unsupported: usize = 0,
    truncated: bool = false,
    artifact: []const u8 = "",
    replay_token: []const u8 = "",

    pub fn validate(self: EvidenceSummary) ContractError!void {
        if (!self.attempted) {
            if (self.status != .skipped or self.planned != 0 or self.executed != 0 or self.passed != 0 or self.failed != 0 or self.unsupported != 0 or self.truncated) return error.InvalidStatus;
        } else {
            if (self.executed > self.planned or self.passed + self.failed + self.unsupported != self.executed) return error.InvalidCounts;
            const expected: TestStatus = if (self.failed != 0)
                .failed
            else if (self.truncated or self.executed != self.planned)
                .incomplete
            else if (self.passed == 0 and self.unsupported != 0)
                .unsupported
            else
                .passed;
            if (self.status != expected) return error.InvalidStatus;
        }
        if (self.artifact.len != 0) validatePath(self.artifact) catch return error.InvalidPath;
        if (self.replay_token.len != 0) try validateFreeLabel(self.replay_token);
    }

    pub fn complete(self: EvidenceSummary) bool {
        return !self.attempted or self.status == .passed;
    }
};

pub const NamedEvidence = struct {
    kind: EvidenceKind,
    summary: EvidenceSummary,
};

pub const TestReceipt = struct {
    schema: []const u8 = receipt_schema,
    schema_version: u32 = schema_version,
    project: []const u8,
    suite: []const u8,
    scenario: Scenario,
    source_revision: []const u8,
    zig_version: []const u8,
    status: TestStatus,
    required: bool = true,
    started_ms: i64 = 0,
    ended_ms: i64 = 0,
    seed: u64 = 1,
    executor: []const u8 = "deterministic",
    execution: ExecutionIdentity = .{},
    coverage_targets: []const CoverageTarget = &.{},
    coverage_hits: []const CoverageHit = &.{},
    coverage: CoverageSummary = .{},
    evidence: []const NamedEvidence = &.{},
    fault_kind: FaultKind = .none,
    fault_index: ?usize = null,
    schedule_choices: []const u32 = &.{},
    assertions: []const AssertionResult = &.{},
    causal_event_id_space: CausalEventIdSpace = .runtime_local,
    causal_graph_session_id: ?u64 = null,
    minimal_case: ?MinimalCase = null,
    memory: MemorySummary = .{},
    causal: CausalSummary = .{},
    completeness: Completeness = .{},
    stdout_artifact: []const u8 = "",
    stderr_artifact: []const u8 = "",
    replay_command: []const u8 = "",
    limitations: []const []const u8 = &.{},
    detail: []const u8 = "",

    pub fn verdict(self: TestReceipt) TestStatus {
        if (self.status == .failed) return .failed;
        for (self.assertions) |assertion| {
            if (assertion.status == .failed) return .failed;
        }
        for (self.evidence) |item| if (item.summary.attempted and item.summary.status == .failed) return .failed;
        if (!self.memory.safe() or !self.causal.clean()) return .failed;
        switch (self.status) {
            .unsupported, .skipped, .canceled => return self.status,
            .incomplete => return .incomplete,
            .passed => {},
            .failed => unreachable,
        }
        if (!self.completeness.complete()) return .incomplete;
        if (!self.coverage.complete()) return .incomplete;
        for (self.evidence) |item| if (!item.summary.complete()) return .incomplete;
        for (self.execution.adapters) |adapter| if (adapter.result != .matched) return .incomplete;
        if (self.required and self.assertions.len == 0) return .incomplete;
        return .passed;
    }

    pub fn durationMs(self: TestReceipt) u64 {
        if (self.ended_ms <= self.started_ms) return 0;
        return @intCast(self.ended_ms - self.started_ms);
    }

    pub fn validate(self: TestReceipt) ContractError!void {
        if (!std.mem.eql(u8, self.schema, receipt_schema) or self.schema_version != schema_version) return error.UnsupportedSchema;
        try validateIdentifier(self.project);
        try validateIdentifier(self.suite);
        try self.scenario.validate();
        try validateFreeLabel(self.source_revision);
        try validateFreeLabel(self.zig_version);
        try validateIdentifier(self.executor);
        try self.execution.validate();
        try validateCoverage(self.coverage_targets, self.coverage_hits, self.coverage);
        for (self.evidence, 0..) |item, index| {
            try item.summary.validate();
            for (self.evidence[0..index]) |previous| if (previous.kind == item.kind) return error.InvalidScenario;
        }
        if (self.seed == 0) return error.InvalidBounds;
        if (self.ended_ms < self.started_ms) return error.InvalidTimeline;
        for (self.assertions, 0..) |assertion, index| {
            try assertion.validate();
            for (self.assertions[0..index]) |previous| {
                if (std.mem.eql(u8, previous.id, assertion.id)) return error.InvalidScenario;
            }
        }
        if ((self.causal_event_id_space == .graph_durable) != (self.causal_graph_session_id != null)) return error.InvalidScenario;
        if (self.causal_graph_session_id) |session_id| if (session_id == 0) return error.InvalidBounds;
        if (self.minimal_case) |minimal| try minimal.validate();
        if (self.stdout_artifact.len != 0) validatePath(self.stdout_artifact) catch return error.InvalidPath;
        if (self.stderr_artifact.len != 0) validatePath(self.stderr_artifact) catch return error.InvalidPath;
        if (self.verdict() != self.status) return error.InvalidStatus;
    }

    pub fn jsonAlloc(self: TestReceipt, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        var output = std.ArrayList(u8).empty;
        errdefer output.deinit(allocator);
        try appendReceiptJson(&output, allocator, self);
        return output.toOwnedSlice(allocator);
    }
};

pub const TestRunReceipt = struct {
    schema: []const u8 = run_receipt_schema,
    schema_version: u32 = schema_version,
    project: []const u8,
    source_revision: []const u8,
    selection: SelectionReason = .all,
    selection_value: []const u8 = "",
    discovered: usize,
    selected: usize,
    passed: usize,
    failed: usize,
    incomplete: usize,
    unsupported: usize,
    skipped: usize,
    canceled: usize,
    introduced_failures: usize = 0,
    resolved_failures: usize = 0,
    started_ms: i64 = 0,
    ended_ms: i64 = 0,
    completeness: Completeness = .{},
    receipts: []const TestReceipt = &.{},
    limitations: []const []const u8 = &.{},

    pub fn status(self: TestRunReceipt) TestStatus {
        if (self.failed > 0) return .failed;
        if (self.incomplete > 0 or !self.completeness.complete()) return .incomplete;
        if (self.canceled > 0) return .canceled;
        if (self.passed == 0 and self.unsupported > 0) return .unsupported;
        if (self.passed == 0 and self.skipped > 0) return .skipped;
        return .passed;
    }

    pub fn validate(self: TestRunReceipt) ContractError!void {
        if (!std.mem.eql(u8, self.schema, run_receipt_schema) or self.schema_version != schema_version) return error.UnsupportedSchema;
        try validateIdentifier(self.project);
        try validateFreeLabel(self.source_revision);
        if (self.ended_ms < self.started_ms or self.selected > self.discovered) return error.InvalidTimeline;
        const total = self.passed + self.failed + self.incomplete + self.unsupported + self.skipped + self.canceled;
        if (total != self.selected or self.receipts.len != self.selected) return error.InvalidCounts;
        var counts = StatusCounts{};
        for (self.receipts, 0..) |receipt, index| {
            try receipt.validate();
            counts.add(receipt.status);
            for (self.receipts[0..index]) |previous| {
                if (std.mem.eql(u8, previous.scenario.id, receipt.scenario.id)) return error.InvalidScenario;
            }
        }
        if (!counts.eql(self)) return error.InvalidCounts;
    }

    pub fn jsonAlloc(self: TestRunReceipt, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        var output = std.ArrayList(u8).empty;
        errdefer output.deinit(allocator);
        try output.appendSlice(allocator, "{\"schema\":");
        try appendJsonString(&output, allocator, self.schema);
        try output.print(allocator, ",\"schema_version\":{d},\"status\":", .{self.schema_version});
        try appendJsonString(&output, allocator, @tagName(self.status()));
        try output.appendSlice(allocator, ",\"project\":");
        try appendSafeJsonString(&output, allocator, self.project);
        try output.appendSlice(allocator, ",\"source_revision\":");
        try appendSafeJsonString(&output, allocator, self.source_revision);
        try output.appendSlice(allocator, ",\"selection\":");
        try appendJsonString(&output, allocator, @tagName(self.selection));
        try output.appendSlice(allocator, ",\"selection_value\":");
        try appendSafeJsonString(&output, allocator, self.selection_value);
        try output.print(
            allocator,
            ",\"discovered\":{d},\"selected\":{d},\"passed\":{d},\"failed\":{d},\"incomplete\":{d},\"unsupported\":{d},\"skipped\":{d},\"canceled\":{d},\"introduced_failures\":{d},\"resolved_failures\":{d},\"started_ms\":{d},\"ended_ms\":{d},\"completeness\":",
            .{ self.discovered, self.selected, self.passed, self.failed, self.incomplete, self.unsupported, self.skipped, self.canceled, self.introduced_failures, self.resolved_failures, self.started_ms, self.ended_ms },
        );
        try appendCompleteness(&output, allocator, self.completeness);
        try output.appendSlice(allocator, ",\"receipts\":[");
        for (self.receipts, 0..) |receipt, index| {
            if (index != 0) try output.append(allocator, ',');
            try appendReceiptJson(&output, allocator, receipt);
        }
        try output.appendSlice(allocator, "],\"limitations\":");
        try appendStringArray(&output, allocator, self.limitations, true);
        try output.append(allocator, '}');
        return output.toOwnedSlice(allocator);
    }
};

pub const ParsedReceipt = std.json.Parsed(TestReceipt);
pub const ParsedRunReceipt = std.json.Parsed(TestRunReceipt);

pub fn parseReceipt(allocator: std.mem.Allocator, input: []const u8) !ParsedReceipt {
    var parsed = try std.json.parseFromSlice(TestReceipt, allocator, input, .{ .allocate = .alloc_always, .ignore_unknown_fields = true });
    errdefer parsed.deinit();
    try parsed.value.validate();
    return parsed;
}

pub fn parseRunReceipt(allocator: std.mem.Allocator, input: []const u8) !ParsedRunReceipt {
    var parsed = try std.json.parseFromSlice(TestRunReceipt, allocator, input, .{ .allocate = .alloc_always, .ignore_unknown_fields = true });
    errdefer parsed.deinit();
    try parsed.value.validate();
    return parsed;
}

const StatusCounts = struct {
    passed: usize = 0,
    failed: usize = 0,
    incomplete: usize = 0,
    unsupported: usize = 0,
    skipped: usize = 0,
    canceled: usize = 0,

    fn add(self: *StatusCounts, status: TestStatus) void {
        switch (status) {
            .passed => self.passed += 1,
            .failed => self.failed += 1,
            .incomplete => self.incomplete += 1,
            .unsupported => self.unsupported += 1,
            .skipped => self.skipped += 1,
            .canceled => self.canceled += 1,
        }
    }

    fn eql(self: StatusCounts, run: TestRunReceipt) bool {
        return self.passed == run.passed and self.failed == run.failed and self.incomplete == run.incomplete and
            self.unsupported == run.unsupported and self.skipped == run.skipped and self.canceled == run.canceled;
    }
};

fn validateIdentifier(value: []const u8) ContractError!void {
    if (value.len == 0 or value.len > 128 or Secrets.containsSecret(value)) return if (Secrets.containsSecret(value)) error.SecretDetected else error.InvalidIdentifier;
    for (value) |byte| {
        if (!(std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.')) return error.InvalidIdentifier;
    }
}

fn validateFreeLabel(value: []const u8) ContractError!void {
    if (value.len == 0 or value.len > 4096) return error.InvalidScenario;
    if (Secrets.containsSecret(value)) return error.SecretDetected;
}

fn validatePath(value: []const u8) !void {
    if (Secrets.containsSecret(value)) return error.SecretDetected;
    try Project.validateRelativePath(value, false);
}

fn appendReceiptJson(output: *std.ArrayList(u8), allocator: std.mem.Allocator, receipt: TestReceipt) !void {
    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(output, allocator, receipt.schema);
    try output.print(allocator, ",\"schema_version\":{d},\"status\":", .{receipt.schema_version});
    try appendJsonString(output, allocator, @tagName(receipt.status));
    try output.appendSlice(allocator, ",\"project\":");
    try appendSafeJsonString(output, allocator, receipt.project);
    try output.appendSlice(allocator, ",\"suite\":");
    try appendSafeJsonString(output, allocator, receipt.suite);
    try output.appendSlice(allocator, ",\"scenario\":");
    try appendScenario(output, allocator, receipt.scenario);
    try output.appendSlice(allocator, ",\"source_revision\":");
    try appendSafeJsonString(output, allocator, receipt.source_revision);
    try output.appendSlice(allocator, ",\"zig_version\":");
    try appendSafeJsonString(output, allocator, receipt.zig_version);
    try output.print(allocator, ",\"required\":{s},\"started_ms\":{d},\"ended_ms\":{d},\"duration_ms\":{d},\"seed\":{d},\"executor\":", .{
        if (receipt.required) "true" else "false", receipt.started_ms, receipt.ended_ms, receipt.durationMs(), receipt.seed,
    });
    try appendSafeJsonString(output, allocator, receipt.executor);
    try output.appendSlice(allocator, ",\"execution\":");
    try appendExecution(output, allocator, receipt.execution);
    try output.appendSlice(allocator, ",\"coverage_targets\":[");
    for (receipt.coverage_targets, 0..) |target, index| {
        if (index != 0) try output.append(allocator, ',');
        try appendCoverageTarget(output, allocator, target);
    }
    try output.appendSlice(allocator, "],\"coverage_hits\":[");
    for (receipt.coverage_hits, 0..) |hit, index| {
        if (index != 0) try output.append(allocator, ',');
        try appendCoverageHit(output, allocator, hit);
    }
    try output.appendSlice(allocator, "],\"coverage\":");
    try appendCoverageSummary(output, allocator, receipt.coverage);
    try output.appendSlice(allocator, ",\"evidence\":[");
    for (receipt.evidence, 0..) |item, index| {
        if (index != 0) try output.append(allocator, ',');
        try appendNamedEvidence(output, allocator, item);
    }
    try output.append(allocator, ']');
    try output.appendSlice(allocator, ",\"fault_kind\":");
    try appendJsonString(output, allocator, @tagName(receipt.fault_kind));
    try output.appendSlice(allocator, ",\"fault_index\":");
    if (receipt.fault_index) |index| try output.print(allocator, "{d}", .{index}) else try output.appendSlice(allocator, "null");
    try output.appendSlice(allocator, ",\"schedule_choices\":");
    try appendU32Array(output, allocator, receipt.schedule_choices);
    try output.appendSlice(allocator, ",\"causal_event_id_space\":");
    try appendJsonString(output, allocator, @tagName(receipt.causal_event_id_space));
    try output.appendSlice(allocator, ",\"causal_graph_session_id\":");
    if (receipt.causal_graph_session_id) |session_id| try output.print(allocator, "{d}", .{session_id}) else try output.appendSlice(allocator, "null");
    try output.appendSlice(allocator, ",\"assertions\":[");
    for (receipt.assertions, 0..) |assertion, index| {
        if (index != 0) try output.append(allocator, ',');
        try appendAssertion(output, allocator, assertion);
    }
    try output.appendSlice(allocator, "],\"minimal_case\":");
    if (receipt.minimal_case) |minimal| try appendMinimalCase(output, allocator, minimal) else try output.appendSlice(allocator, "null");
    try output.appendSlice(allocator, ",\"memory\":");
    try appendMemory(output, allocator, receipt.memory);
    try output.appendSlice(allocator, ",\"causal\":");
    try appendCausal(output, allocator, receipt.causal);
    try output.appendSlice(allocator, ",\"completeness\":");
    try appendCompleteness(output, allocator, receipt.completeness);
    try output.appendSlice(allocator, ",\"stdout_artifact\":");
    try appendSafeJsonString(output, allocator, receipt.stdout_artifact);
    try output.appendSlice(allocator, ",\"stderr_artifact\":");
    try appendSafeJsonString(output, allocator, receipt.stderr_artifact);
    try output.appendSlice(allocator, ",\"replay_command\":");
    try appendSafeJsonString(output, allocator, receipt.replay_command);
    try output.appendSlice(allocator, ",\"limitations\":");
    try appendStringArray(output, allocator, receipt.limitations, true);
    try output.appendSlice(allocator, ",\"detail\":");
    try appendSafeJsonString(output, allocator, receipt.detail);
    try output.append(allocator, '}');
}

fn appendExecution(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: ExecutionIdentity) !void {
    try output.appendSlice(allocator, "{\"tool_version\":");
    try appendSafeJsonString(output, allocator, value.tool_version);
    try output.appendSlice(allocator, ",\"target\":");
    try appendSafeJsonString(output, allocator, value.target);
    try output.appendSlice(allocator, ",\"optimize\":");
    try appendSafeJsonString(output, allocator, value.optimize);
    try output.appendSlice(allocator, ",\"command_digest\":");
    try appendSafeJsonString(output, allocator, value.command_digest);
    try output.appendSlice(allocator, ",\"manifest_digest\":");
    try appendSafeJsonString(output, allocator, value.manifest_digest);
    try output.appendSlice(allocator, ",\"adapter_profile\":");
    try appendSafeJsonString(output, allocator, value.adapter_profile);
    try output.appendSlice(allocator, ",\"adapters\":[");
    for (value.adapters, 0..) |adapter, index| {
        if (index != 0) try output.append(allocator, ',');
        const encoded = try std.json.Stringify.valueAlloc(allocator, adapter, .{ .emit_null_optional_fields = false });
        defer allocator.free(encoded);
        try output.appendSlice(allocator, encoded);
    }
    try output.print(allocator, "],\"worktree_dirty\":{s},\"native_receipt\":{s}}}", .{
        if (value.worktree_dirty) "true" else "false",
        if (value.native_receipt) "true" else "false",
    });
}

fn appendCoverageTarget(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: CoverageTarget) !void {
    try output.appendSlice(allocator, "{\"id\":");
    try appendSafeJsonString(output, allocator, value.id);
    try output.appendSlice(allocator, ",\"label\":");
    try appendSafeJsonString(output, allocator, value.label);
    try output.appendSlice(allocator, ",\"dimension\":");
    try appendJsonString(output, allocator, @tagName(value.dimension));
    try output.print(allocator, ",\"required\":{s},\"repair_hint\":", .{if (value.required) "true" else "false"});
    try appendSafeJsonString(output, allocator, value.repair_hint);
    try output.appendSlice(allocator, ",\"next_command\":");
    try appendSafeJsonString(output, allocator, value.next_command);
    try output.append(allocator, '}');
}

fn appendCoverageHit(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: CoverageHit) !void {
    try output.appendSlice(allocator, "{\"target_id\":");
    try appendSafeJsonString(output, allocator, value.target_id);
    try output.appendSlice(allocator, ",\"evidence_id\":");
    try appendSafeJsonString(output, allocator, value.evidence_id);
    try output.append(allocator, '}');
}

fn appendCoverageSummary(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: CoverageSummary) !void {
    try output.print(allocator, "{{\"targets\":{d},\"hits\":{d},\"required_gaps\":{d},\"advisory_gaps\":{d},\"truncated\":{s}}}", .{
        value.targets,
        value.hits,
        value.required_gaps,
        value.advisory_gaps,
        if (value.truncated) "true" else "false",
    });
}

fn appendNamedEvidence(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: NamedEvidence) !void {
    try output.appendSlice(allocator, "{\"kind\":");
    try appendJsonString(output, allocator, @tagName(value.kind));
    try output.appendSlice(allocator, ",\"summary\":");
    try appendEvidenceSummary(output, allocator, value.summary);
    try output.append(allocator, '}');
}

fn appendEvidenceSummary(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: EvidenceSummary) !void {
    try output.print(allocator, "{{\"attempted\":{s},\"status\":", .{if (value.attempted) "true" else "false"});
    try appendJsonString(output, allocator, @tagName(value.status));
    try output.print(allocator, ",\"planned\":{d},\"executed\":{d},\"passed\":{d},\"failed\":{d},\"unsupported\":{d},\"truncated\":{s},\"artifact\":", .{
        value.planned, value.executed, value.passed, value.failed, value.unsupported, if (value.truncated) "true" else "false",
    });
    try appendSafeJsonString(output, allocator, value.artifact);
    try output.appendSlice(allocator, ",\"replay_token\":");
    try appendSafeJsonString(output, allocator, value.replay_token);
    try output.append(allocator, '}');
}

fn validateCoverage(targets: []const CoverageTarget, hits: []const CoverageHit, summary: CoverageSummary) ContractError!void {
    var required_gaps: usize = 0;
    var advisory_gaps: usize = 0;
    for (targets, 0..) |target, index| {
        try target.validate();
        for (targets[0..index]) |previous| if (std.mem.eql(u8, previous.id, target.id)) return error.InvalidScenario;
        var covered = false;
        for (hits) |hit| if (std.mem.eql(u8, hit.target_id, target.id)) {
            covered = true;
            break;
        };
        if (!covered) {
            if (target.required) required_gaps += 1 else advisory_gaps += 1;
        }
    }
    for (hits, 0..) |hit, index| {
        try hit.validate();
        var found = false;
        for (targets) |target| if (std.mem.eql(u8, target.id, hit.target_id)) {
            found = true;
            break;
        };
        if (!found) return error.InvalidScenario;
        for (hits[0..index]) |previous| if (std.mem.eql(u8, previous.target_id, hit.target_id) and std.mem.eql(u8, previous.evidence_id, hit.evidence_id)) return error.InvalidScenario;
    }
    if (summary.targets != targets.len or summary.hits != hits.len or summary.required_gaps != required_gaps or summary.advisory_gaps != advisory_gaps) return error.InvalidCounts;
}

fn appendScenario(output: *std.ArrayList(u8), allocator: std.mem.Allocator, scenario: Scenario) !void {
    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(output, allocator, scenario.schema);
    try output.print(allocator, ",\"schema_version\":{d},\"id\":", .{scenario.schema_version});
    try appendSafeJsonString(output, allocator, scenario.id);
    try output.appendSlice(allocator, ",\"label\":");
    try appendSafeJsonString(output, allocator, scenario.label);
    try output.appendSlice(allocator, ",\"requirement\":");
    try appendSafeJsonString(output, allocator, scenario.requirement);
    try output.appendSlice(allocator, ",\"acceptance_check\":");
    try appendSafeJsonString(output, allocator, scenario.acceptance_check);
    try output.appendSlice(allocator, ",\"component\":");
    try appendSafeJsonString(output, allocator, scenario.component);
    try output.appendSlice(allocator, ",\"command\":");
    try appendSafeJsonString(output, allocator, scenario.command);
    try output.appendSlice(allocator, ",\"source_roots\":");
    try appendStringArray(output, allocator, scenario.source_roots, false);
    try output.appendSlice(allocator, ",\"tags\":");
    try appendStringArray(output, allocator, scenario.tags, false);
    try output.print(allocator, ",\"default_seed\":{d},\"fault_profile\":", .{scenario.default_seed});
    try appendJsonString(output, allocator, @tagName(scenario.fault_profile));
    try output.print(allocator, ",\"required\":{s}}}", .{if (scenario.required) "true" else "false"});
}

fn appendAssertion(output: *std.ArrayList(u8), allocator: std.mem.Allocator, assertion: AssertionResult) !void {
    try output.appendSlice(allocator, "{\"id\":");
    try appendSafeJsonString(output, allocator, assertion.id);
    try output.appendSlice(allocator, ",\"label\":");
    try appendSafeJsonString(output, allocator, assertion.label);
    try output.appendSlice(allocator, ",\"status\":");
    try appendJsonString(output, allocator, @tagName(assertion.status));
    try output.appendSlice(allocator, ",\"source\":{");
    try output.appendSlice(allocator, "\"id\":");
    try appendSafeJsonString(output, allocator, assertion.source.id);
    try output.appendSlice(allocator, ",\"path\":");
    try appendSafeJsonString(output, allocator, assertion.source.path);
    try output.print(allocator, ",\"line\":{d},\"column\":{d}}},\"causal_event_ids\":", .{ assertion.source.line, assertion.source.column });
    try appendU64Array(output, allocator, assertion.causal_event_ids);
    try output.appendSlice(allocator, ",\"expected\":");
    try appendSafeJsonString(output, allocator, assertion.expected);
    try output.appendSlice(allocator, ",\"actual\":");
    try appendSafeJsonString(output, allocator, assertion.actual);
    try output.appendSlice(allocator, ",\"detail\":");
    try appendSafeJsonString(output, allocator, assertion.detail);
    try output.appendSlice(allocator, ",\"repair_hint\":");
    try appendSafeJsonString(output, allocator, assertion.repair_hint);
    try output.append(allocator, '}');
}

fn appendMinimalCase(output: *std.ArrayList(u8), allocator: std.mem.Allocator, minimal: MinimalCase) !void {
    try output.appendSlice(allocator, "{\"kind\":");
    try appendSafeJsonString(output, allocator, minimal.kind);
    try output.appendSlice(allocator, ",\"input\":");
    try appendSafeJsonString(output, allocator, minimal.input);
    try output.print(allocator, ",\"seed\":{d},\"case_index\":{d},\"shrink_steps\":{d},\"schedule_choices\":", .{ minimal.seed, minimal.case_index, minimal.shrink_steps });
    try appendU32Array(output, allocator, minimal.schedule_choices);
    try output.appendSlice(allocator, ",\"artifact\":");
    try appendSafeJsonString(output, allocator, minimal.artifact);
    try output.appendSlice(allocator, ",\"shrink_path\":");
    try appendSafeJsonString(output, allocator, minimal.shrink_path);
    try output.append(allocator, '}');
}

fn appendMemory(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: MemorySummary) !void {
    try output.print(allocator, "{{\"allocations\":{d},\"frees\":{d},\"live_allocations\":{d},\"live_bytes\":{d},\"peak_bytes\":{d},\"invalid_frees\":{d},\"out_of_memory\":{d}}}", .{
        value.allocations, value.frees, value.live_allocations, value.live_bytes, value.peak_bytes, value.invalid_frees, value.out_of_memory,
    });
}

fn appendCausal(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: CausalSummary) !void {
    try output.print(allocator, "{{\"events\":{d},\"findings\":{d},\"pending_fibers\":{d},\"leaked_resources\":{d},\"assertion_failures\":{d}}}", .{
        value.events, value.findings, value.pending_fibers, value.leaked_resources, value.assertion_failures,
    });
}

fn appendCompleteness(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: Completeness) !void {
    try output.print(allocator, "{{\"dropped_assertions\":{d},\"dropped_diagnostics\":{d},\"dropped_runtime_events\":{d},\"stale_source_refs\":{d},\"truncated_artifacts\":{d},\"sampled_events\":{d}}}", .{
        value.dropped_assertions, value.dropped_diagnostics, value.dropped_runtime_events, value.stale_source_refs, value.truncated_artifacts, value.sampled_events,
    });
}

fn appendStringArray(output: *std.ArrayList(u8), allocator: std.mem.Allocator, values: []const []const u8, safe: bool) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index != 0) try output.append(allocator, ',');
        if (safe) try appendSafeJsonString(output, allocator, value) else try appendJsonString(output, allocator, value);
    }
    try output.append(allocator, ']');
}

fn appendU64Array(output: *std.ArrayList(u8), allocator: std.mem.Allocator, values: []const u64) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index != 0) try output.append(allocator, ',');
        try output.print(allocator, "{d}", .{value});
    }
    try output.append(allocator, ']');
}

fn appendU32Array(output: *std.ArrayList(u8), allocator: std.mem.Allocator, values: []const u32) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index != 0) try output.append(allocator, ',');
        try output.print(allocator, "{d}", .{value});
    }
    try output.append(allocator, ']');
}

fn appendSafeJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    try appendJsonString(output, allocator, if (Secrets.containsSecret(value)) Secrets.redacted else value);
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    try output.append(allocator, '"');
    for (value) |byte| switch (byte) {
        '"' => try output.appendSlice(allocator, "\\\""),
        '\\' => try output.appendSlice(allocator, "\\\\"),
        '\n' => try output.appendSlice(allocator, "\\n"),
        '\r' => try output.appendSlice(allocator, "\\r"),
        '\t' => try output.appendSlice(allocator, "\\t"),
        0x00...0x08, 0x0b, 0x0c, 0x0e...0x1f => try output.print(allocator, "\\u{x:0>4}", .{byte}),
        else => try output.append(allocator, byte),
    };
    try output.append(allocator, '"');
}

fn sampleScenario() Scenario {
    return .{
        .id = "create-order",
        .label = "duplicate keys create one order",
        .requirement = "req-create-order",
        .acceptance_check = "check-create-order",
        .component = "api-service",
        .command = "test",
        .source_roots = &.{"src/orders"},
        .tags = &.{ "acceptance", "sql" },
        .default_seed = 42,
    };
}

fn sampleReceipt(assertions: []const AssertionResult) TestReceipt {
    return .{
        .project = "order-platform",
        .suite = "orders",
        .scenario = sampleScenario(),
        .source_revision = "sha256:revision",
        .zig_version = "0.16.0",
        .status = .passed,
        .started_ms = 100,
        .ended_ms = 125,
        .seed = 42,
        .assertions = assertions,
        .replay_command = "zigeffect test replay create-order",
    };
}

test "Scenario validates identity paths tags and fails closed" {
    try sampleScenario().validate();

    var zero_seed = sampleScenario();
    zero_seed.default_seed = 0;
    try std.testing.expectError(error.InvalidBounds, zero_seed.validate());

    var secret = sampleScenario();
    secret.id = "token=sentinel-secret-for-tests";
    try std.testing.expectError(error.SecretDetected, secret.validate());

    var traversal = sampleScenario();
    traversal.source_roots = &.{"../outside"};
    try std.testing.expectError(error.InvalidPath, traversal.validate());

    var duplicate = sampleScenario();
    duplicate.tags = &.{ "acceptance", "acceptance" };
    try std.testing.expectError(error.InvalidScenario, duplicate.validate());
}

test "TestReceipt derives truthful failure incomplete and pass status" {
    const passed_assertions = [_]AssertionResult{.{ .id = "assert-order", .label = "order exists", .status = .passed }};
    var receipt = sampleReceipt(&passed_assertions);
    try receipt.validate();
    try std.testing.expectEqual(TestStatus.passed, receipt.verdict());
    try std.testing.expectEqual(@as(u64, 25), receipt.durationMs());

    var failed_assertions = passed_assertions;
    failed_assertions[0].status = .failed;
    receipt.assertions = &failed_assertions;
    try std.testing.expectEqual(TestStatus.failed, receipt.verdict());
    try std.testing.expectError(error.InvalidStatus, receipt.validate());

    receipt.assertions = &passed_assertions;
    receipt.completeness.truncated_artifacts = 1;
    try std.testing.expectEqual(TestStatus.incomplete, receipt.verdict());
    try std.testing.expectError(error.InvalidStatus, receipt.validate());

    receipt.completeness = .{};
    receipt.memory.live_allocations = 1;
    try std.testing.expectEqual(TestStatus.failed, receipt.verdict());
}

test "TestReceipt JSON redacts free text round trips and preserves replay evidence" {
    const assertions = [_]AssertionResult{.{
        .id = "assert-order",
        .label = "order exists",
        .status = .passed,
        .source = .{ .id = "src-order", .path = "src/orders/service.zig", .line = 42, .column = 9 },
        .causal_event_ids = &.{ 7, 9 },
        .detail = "authorization: Bearer sentinel-secret-for-tests",
    }};
    const receipt = sampleReceipt(&assertions);
    const json = try receipt.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "sentinel-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "[REDACTED]") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "zigeffect test replay create-order") != null);

    var parsed = try parseReceipt(std.testing.allocator, json);
    defer parsed.deinit();
    try std.testing.expectEqualStrings("create-order", parsed.value.scenario.id);
    try std.testing.expectEqual(@as(u64, 7), parsed.value.assertions[0].causal_event_ids[0]);
    try std.testing.expectEqual(TestStatus.passed, parsed.value.status);
}

test "TestReceipt preserves additive execution identity" {
    const assertions = [_]AssertionResult{.{ .id = "identity", .label = "identity recorded", .status = .passed }};
    var receipt = sampleReceipt(&assertions);
    receipt.execution = .{
        .tool_version = "0.4.0",
        .target = "aarch64-macos",
        .optimize = "Debug",
        .command_digest = "sha256:command",
        .worktree_dirty = true,
        .native_receipt = true,
        .adapter_profile = "local",
        .adapters = &.{Capability.AdapterEvidence.fromDescriptor(
            "local",
            "public-http",
            "aarch64-macos",
            Capability.Builtin.memory_http_server,
            .matched,
        )},
    };
    const json = try receipt.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    var parsed = try parseReceipt(std.testing.allocator, json);
    defer parsed.deinit();
    try std.testing.expect(parsed.value.execution.native_receipt);
    try std.testing.expect(parsed.value.execution.worktree_dirty);
    try std.testing.expectEqualStrings("sha256:command", parsed.value.execution.command_digest);
    try std.testing.expectEqualStrings("local", parsed.value.execution.adapter_profile);
    try std.testing.expectEqualStrings("zigeffect-std.memory-http", parsed.value.execution.adapters[0].adapter_id);
}

test "TestReceipt cannot pass with an unresolved adapter profile" {
    const assertions = [_]AssertionResult{.{ .id = "identity", .label = "identity recorded", .status = .passed }};
    var receipt = sampleReceipt(&assertions);
    receipt.execution = .{
        .adapter_profile = "production",
        .adapters = &.{Capability.AdapterEvidence.fromDescriptor(
            "production",
            "public-http",
            "aarch64-macos",
            Capability.Builtin.memory_http_server,
            .insufficient_maturity,
        )},
    };
    try std.testing.expectEqual(TestStatus.incomplete, receipt.verdict());
    try std.testing.expectError(error.InvalidStatus, receipt.validate());
    receipt.status = .incomplete;
    try receipt.validate();
}

test "TestRunReceipt validates exact counts scenario uniqueness and JSON" {
    const assertions = [_]AssertionResult{.{ .id = "assert-order", .label = "order exists", .status = .passed }};
    const receipts = [_]TestReceipt{sampleReceipt(&assertions)};
    var run = TestRunReceipt{
        .project = "order-platform",
        .source_revision = "sha256:revision",
        .discovered = 1,
        .selected = 1,
        .passed = 1,
        .failed = 0,
        .incomplete = 0,
        .unsupported = 0,
        .skipped = 0,
        .canceled = 0,
        .started_ms = 100,
        .ended_ms = 125,
        .receipts = &receipts,
    };
    try run.validate();
    try std.testing.expectEqual(TestStatus.passed, run.status());
    const json = try run.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    var parsed = try parseRunReceipt(std.testing.allocator, json);
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.value.receipts.len);

    run.failed = 1;
    run.passed = 0;
    try std.testing.expectError(error.InvalidCounts, run.validate());
}

test "Testing contract builders and parsers release every partial allocation" {
    const Harness = struct {
        fn json(allocator: std.mem.Allocator) !void {
            const assertions = [_]AssertionResult{.{ .id = "assert-order", .label = "order exists", .status = .passed }};
            var receipt = sampleReceipt(&assertions);
            receipt.execution = .{
                .adapter_profile = "local",
                .adapters = &.{Capability.AdapterEvidence.fromDescriptor(
                    "local",
                    "public-http",
                    "aarch64-macos",
                    Capability.Builtin.memory_http_server,
                    .matched,
                )},
            };
            const output = try receipt.jsonAlloc(allocator);
            defer allocator.free(output);
        }

        fn parse(allocator: std.mem.Allocator) !void {
            const assertions = [_]AssertionResult{.{ .id = "assert-order", .label = "order exists", .status = .passed }};
            var receipt = sampleReceipt(&assertions);
            receipt.execution = .{
                .adapter_profile = "local",
                .adapters = &.{Capability.AdapterEvidence.fromDescriptor(
                    "local",
                    "public-http",
                    "aarch64-macos",
                    Capability.Builtin.memory_http_server,
                    .matched,
                )},
            };
            const encoded = try receipt.jsonAlloc(std.testing.allocator);
            defer std.testing.allocator.free(encoded);
            var parsed = try parseReceipt(allocator, encoded);
            defer parsed.deinit();
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.json, .{});
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.parse, .{});
}
