const std = @import("std");

pub const load_test_observation_harness_schema = "zigeffect.causal.load-test-observation-harness.v1";
pub const load_test_observation_harness_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-load-test-observation-harness";
pub const recommendation = "start-production-telemetry-capture-design";
pub const next_branch = "codex/zigeffect-causal-production-telemetry-capture-design";

const OutputFormat = enum { text, json };
const Action = enum { catalog, observe };

const generated_by = "causal-load-test-observation-harness";
const mode = "local-record";
const mutation_authority = "none";
const max_iterations: u32 = 10;
const warmup_iterations: u32 = 1;
const snippet_limit: usize = 240;

const Options = struct {
    action: Action,
    format: OutputFormat,
    scenario_id: ?[]const u8 = null,
    iterations: u32 = 0,
};

const ScenarioStatus = enum {
    local_safe,
    local_safe_needs_artifacts,
    local_safe_workspace_root,
    future_ci_only,
};

const CommandStatus = enum { ok, failed };

const SourceContract = struct {
    id: []const u8,
    schema: []const u8,
    producer: []const u8,
    evidence_role: []const u8,
    authority_boundary: []const u8,
};

const Scenario = struct {
    id: []const u8,
    category: []const u8,
    status: ScenarioStatus,
    upstream_source: []const u8,
    argv: []const []const u8,
    measurement_kind: []const u8,
    required_evidence: []const []const u8,
    local_safety_boundary: []const u8,
    blocked_claim: []const u8,
    agent_guidance: []const u8,
};

const ObservationField = struct {
    name: []const u8,
    required: bool,
    description: []const u8,
};

const NegativeFixture = struct {
    id: []const u8,
    attempted_claim: []const u8,
    decision: []const u8,
    reason: []const u8,
};

const AgentGuidance = struct {
    id: []const u8,
    guidance: []const u8,
};

const RunOutput = struct {
    status: CommandStatus,
    exit_code: ?i32,
    stdout: []const u8,
    stderr: []const u8,
    elapsed_ms: u64,
};

const ObservationRecord = struct {
    scenario_id: []const u8,
    scenario_category: []const u8,
    command_status: CommandStatus,
    exit_code: ?i32,
    warmup_iterations: u32,
    measured_iterations: u32,
    sample_count: u32,
    median_ms: u64,
    p95_ms: u64,
    min_ms: u64,
    max_ms: u64,
    stdout_snippet: []const u8,
    stderr_snippet: []const u8,
    review_gate: []const u8,
};

const Runner = struct {
    ptr: *anyopaque,
    runFn: *const fn (*anyopaque, std.mem.Allocator, []const []const u8) anyerror!RunOutput,

    fn run(self: Runner, allocator: std.mem.Allocator, argv: []const []const u8) !RunOutput {
        return self.runFn(self.ptr, allocator, argv);
    }
};

const ProcessRunner = struct {
    io: std.Io,

    fn runner(self: *ProcessRunner) Runner {
        return .{ .ptr = self, .runFn = run };
    }

    fn run(ptr: *anyopaque, allocator: std.mem.Allocator, argv: []const []const u8) !RunOutput {
        const self: *ProcessRunner = @ptrCast(@alignCast(ptr));
        const started_ns = std.Io.Clock.awake.now(self.io).nanoseconds;
        const result = std.process.run(allocator, self.io, .{
            .argv = argv,
            .stdout_limit = .limited(64 * 1024),
            .stderr_limit = .limited(64 * 1024),
        }) catch |err| {
            return .{
                .status = .failed,
                .exit_code = null,
                .stdout = try allocator.dupe(u8, ""),
                .stderr = try allocator.dupe(u8, @errorName(err)),
                .elapsed_ms = 0,
            };
        };
        const ended_ns = std.Io.Clock.awake.now(self.io).nanoseconds;
        const elapsed_ns = if (ended_ns > started_ns) ended_ns - started_ns else 0;

        return .{
            .status = statusForTerm(result.term),
            .exit_code = exitCodeForTerm(result.term),
            .stdout = result.stdout,
            .stderr = result.stderr,
            .elapsed_ms = @intCast(@divTrunc(elapsed_ns, std.time.ns_per_ms)),
        };
    }
};

const FakeRunner = struct {
    outputs: []const RunOutput,
    index: usize = 0,
    calls: std.ArrayList([]const []const u8) = .empty,

    fn init(outputs: []const RunOutput) FakeRunner {
        return .{ .outputs = outputs };
    }

    fn runner(self: *FakeRunner) Runner {
        return .{ .ptr = self, .runFn = run };
    }

    fn run(ptr: *anyopaque, allocator: std.mem.Allocator, argv: []const []const u8) !RunOutput {
        const self: *FakeRunner = @ptrCast(@alignCast(ptr));
        const owned_argv = try allocator.alloc([]const u8, argv.len);
        @memcpy(owned_argv, argv);
        try self.calls.append(allocator, owned_argv);

        if (self.index >= self.outputs.len) return error.MissingFakeOutput;
        const output = self.outputs[self.index];
        self.index += 1;
        return .{
            .status = output.status,
            .exit_code = output.exit_code,
            .stdout = try allocator.dupe(u8, output.stdout),
            .stderr = try allocator.dupe(u8, output.stderr),
            .elapsed_ms = output.elapsed_ms,
        };
    }

    fn deinit(self: *FakeRunner, allocator: std.mem.Allocator) void {
        for (self.calls.items) |argv| allocator.free(argv);
        self.calls.deinit(allocator);
    }
};

fn usage() []const u8 {
    return
    \\usage:
    \\  zig build causal-load-test-observation-harness
    \\  zig build causal-load-test-observation-harness -- --format text
    \\  zig build causal-load-test-observation-harness -- --format json
    \\  zig build causal-load-test-observation-harness -- observe <scenario-id> --iterations <n> --format text|json
    \\
    \\formats:
    \\  --format text|json
    \\
    ;
}

fn parseOptions(args: []const []const u8) !Options {
    if (args.len == 1) return .{ .action = .catalog, .format = .text };

    if (args.len == 3 and std.mem.eql(u8, args[1], "--format")) {
        return .{ .action = .catalog, .format = try parseFormat(args[2]) };
    }

    if (!std.mem.eql(u8, args[1], "observe")) return error.UnknownFlag;
    if (args.len < 5) return error.MissingScenario;

    const scenario_id = args[2];
    if (scenarioById(scenario_id) == null) return error.UnknownScenario;

    var format: OutputFormat = .text;
    var iterations: ?u32 = null;
    var index: usize = 3;
    while (index < args.len) {
        if (std.mem.eql(u8, args[index], "--iterations")) {
            if (index + 1 >= args.len) return error.MissingIterations;
            const parsed = std.fmt.parseUnsigned(u32, args[index + 1], 10) catch return error.InvalidIterations;
            if (parsed == 0) return error.InvalidIterations;
            if (parsed > max_iterations) return error.IterationLimitExceeded;
            iterations = parsed;
            index += 2;
        } else if (std.mem.eql(u8, args[index], "--format")) {
            if (index + 1 >= args.len) return error.MissingFormat;
            format = try parseFormat(args[index + 1]);
            index += 2;
        } else {
            return error.UnknownFlag;
        }
    }

    return .{
        .action = .observe,
        .format = format,
        .scenario_id = scenario_id,
        .iterations = iterations orelse return error.MissingIterations,
    };
}

fn parseFormat(value: []const u8) !OutputFormat {
    if (std.mem.eql(u8, value, "text")) return .text;
    if (std.mem.eql(u8, value, "json")) return .json;
    return error.UnknownFormat;
}

const source_contracts: []const SourceContract = &.{
    .{
        .id = "wall-clock-benchmark-baselines",
        .schema = "zigeffect.causal.wall-clock-benchmark-baselines.v1",
        .producer = "causal-wall-clock-benchmark-baselines",
        .evidence_role = "scenario families environment metadata calibration policy and advisory review gates",
        .authority_boundary = "advisory timing contract only",
    },
    .{
        .id = "production-capacity-planning",
        .schema = "zigeffect.causal.production-capacity-planning.v1",
        .producer = "causal-production-capacity-planning",
        .evidence_role = "capacity domains load-test fixture plan storage assumptions and readiness gates",
        .authority_boundary = "planning-only and not production capacity evidence",
    },
    .{
        .id = "production-hardening-completion-audit",
        .schema = "zigeffect.causal.production-hardening-completion-audit.v1",
        .producer = "causal-production-hardening-completion-audit",
        .evidence_role = "hardening completion boundaries and remaining evidence gaps",
        .authority_boundary = "record-only completion evidence",
    },
};

const scenario_catalog: []const Scenario = &.{
    .{
        .id = "app-request-trace",
        .category = "runtime-request",
        .status = .local_safe,
        .upstream_source = "wall-clock-benchmark-baselines and production-capacity-planning",
        .argv = &.{ "zig", "build", "causal-app-request-example" },
        .measurement_kind = "wall-clock elapsed milliseconds",
        .required_evidence = &.{ "causal app request example", "redaction-safe app semantic refs", "bounded event limits" },
        .local_safety_boundary = "runs a local example build/test only",
        .blocked_claim = "production request throughput or capacity",
        .agent_guidance = "Use as local app request trace observation only.",
    },
    .{
        .id = "background-job-trace",
        .category = "runtime-job",
        .status = .local_safe,
        .upstream_source = "wall-clock-benchmark-baselines and production-capacity-planning",
        .argv = &.{ "zig", "build", "causal-run", "--", "causal-scoped-fiber" },
        .measurement_kind = "wall-clock elapsed milliseconds",
        .required_evidence = &.{ "causal scoped fiber scenario", "runtime fiber scope events", "bounded output snippets" },
        .local_safety_boundary = "runs a registered local causal-run scenario only",
        .blocked_claim = "background job production volume",
        .agent_guidance = "Keep dropped-event and runtime-boundary caveats visible.",
    },
    .{
        .id = "causal-artifact-formatting",
        .category = "artifact",
        .status = .local_safe,
        .upstream_source = "wall-clock-benchmark-baselines",
        .argv = &.{ "zig", "build", "causal-report" },
        .measurement_kind = "wall-clock elapsed milliseconds",
        .required_evidence = &.{ "sample causal report", "text JSON and causal report formatting path" },
        .local_safety_boundary = "prints a local sample causal report only",
        .blocked_claim = "retained artifact production formatting capacity",
        .agent_guidance = "Compare only compatible artifact shapes.",
    },
    .{
        .id = "causal-query-agent-slices",
        .category = "agent-query",
        .status = .local_safe,
        .upstream_source = "wall-clock-benchmark-baselines and agent-query-interface",
        .argv = &.{ "zig", "build", "causal-query", "--", "--agent", "summarize_run", "1" },
        .measurement_kind = "wall-clock elapsed milliseconds",
        .required_evidence = &.{ "bounded agent query schema", "default sample artifact", "query family id" },
        .local_safety_boundary = "runs a bounded local query over a sample artifact",
        .blocked_claim = "agent query throughput for production artifacts",
        .agent_guidance = "Cite query family and response bounds.",
    },
    .{
        .id = "causal-compare-before-after",
        .category = "comparison",
        .status = .local_safe_needs_artifacts,
        .upstream_source = "wall-clock-benchmark-baselines and human-agent-feedback-loop",
        .argv = &.{ "zig", "build", "causal-compare", "--", ".zig-cache/causal-artifacts/before.json", ".zig-cache/causal-artifacts/after.json" },
        .measurement_kind = "wall-clock elapsed milliseconds",
        .required_evidence = &.{ "reviewed before artifact", "reviewed after artifact", "compatible schema versions" },
        .local_safety_boundary = "cataloged but blocked until reviewed artifact refs are supplied",
        .blocked_claim = "comparison cost or regression severity without paired artifacts",
        .agent_guidance = "Do not run comparison observations without explicit before/after artifact refs.",
    },
    .{
        .id = "causal-dev-loop-package-tests",
        .category = "developer-loop",
        .status = .local_safe,
        .upstream_source = "wall-clock-benchmark-baselines and causal-dev-loop",
        .argv = &.{ "zig", "build", "test-raw" },
        .measurement_kind = "wall-clock elapsed milliseconds",
        .required_evidence = &.{ "package test command", "local Zig cache boundary", "bounded command output" },
        .local_safety_boundary = "runs package tests without causal wrapping",
        .blocked_claim = "production runtime regression",
        .agent_guidance = "Treat package-test timing separately from runtime trace overhead.",
    },
    .{
        .id = "workbench-solid-build",
        .category = "workbench",
        .status = .local_safe_workspace_root,
        .upstream_source = "wall-clock-benchmark-baselines and SolidJS zig-webui workbench",
        .argv = &.{ "bun", "run", "zigeffect:workbench:build" },
        .measurement_kind = "wall-clock elapsed milliseconds",
        .required_evidence = &.{ "Bun lockfile", "SolidJS workbench scripts", "zig-webui workbench direction" },
        .local_safety_boundary = "cataloged but blocked in v1 because it must run from repository root",
        .blocked_claim = "production dashboard hosting or alternate renderer approval",
        .agent_guidance = "Keep SolidJS and zig-webui direction explicit.",
    },
    .{
        .id = "ci-baseline-capture",
        .category = "ci",
        .status = .future_ci_only,
        .upstream_source = "wall-clock-benchmark-baselines future CI observation flow",
        .argv = &.{ "future", "ci", "baseline-capture" },
        .measurement_kind = "wall-clock elapsed milliseconds",
        .required_evidence = &.{ "CI provider", "runner image", "PR base checkout", "PR head checkout" },
        .local_safety_boundary = "not executable locally",
        .blocked_claim = "CI timing gate or production capacity",
        .agent_guidance = "Design CI capture separately with runner metadata and advisory gates.",
    },
};

const observation_record_fields: []const ObservationField = &.{
    .{ .name = "scenario_id", .required = true, .description = "Approved scenario id." },
    .{ .name = "command_status", .required = true, .description = "Whether the curated command completed successfully." },
    .{ .name = "warmup_iterations", .required = true, .description = "Warmups run before measurement." },
    .{ .name = "measured_iterations", .required = true, .description = "Measured local command iterations." },
    .{ .name = "median_ms", .required = true, .description = "Median elapsed milliseconds for measured iterations." },
    .{ .name = "p95_ms", .required = true, .description = "P95 elapsed milliseconds for measured iterations." },
    .{ .name = "stdout_snippet", .required = true, .description = "Bounded stdout excerpt." },
    .{ .name = "stderr_snippet", .required = true, .description = "Bounded stderr excerpt." },
    .{ .name = "review_gate", .required = true, .description = "Advisory review gate classification." },
};

const execution_constraints: []const []const u8 = &.{
    "curated argv arrays only",
    "no shell invocation",
    "approved scenario ids only",
    "measured iterations capped at 10",
    "stdout and stderr snippets capped at 240 bytes",
    "redaction-safe environment metadata only",
    "no production telemetry",
    "no production load",
    "no capacity claim",
};

const review_gates: []const []const u8 = &.{
    "record-only",
    "needs-more-samples",
    "needs-review",
    "failed-command-finding",
    "environment-drift-review",
    "ready-for-telemetry-design",
};

const negative_fixtures: []const NegativeFixture = &.{
    .{ .id = "production-load-claim", .attempted_claim = "local observation proves production load behavior", .decision = "reject", .reason = "the harness runs curated local commands only" },
    .{ .id = "capacity-sizing-claim", .attempted_claim = "local timing records prove production capacity", .decision = "reject", .reason = "capacity sizing remains blocked until production telemetry and human review exist" },
    .{ .id = "live-telemetry-claim", .attempted_claim = "the harness captures live production telemetry", .decision = "reject", .reason = "the harness reads no production telemetry" },
    .{ .id = "arbitrary-command-execution", .attempted_claim = "agents can pass shell command text into the harness", .decision = "reject", .reason = "only curated argv arrays from the catalog are executable" },
    .{ .id = "ci-gate-claim", .attempted_claim = "advisory timings can fail CI", .decision = "reject", .reason = "timing gates require a future reviewed CI policy" },
    .{ .id = "unredacted-environment", .attempted_claim = "raw environment hostnames or usernames can be captured", .decision = "reject", .reason = "environment metadata is curated and snippets are bounded" },
    .{ .id = "non-nendb-adapter", .attempted_claim = "local observations authorize a non-NenDB durable adapter", .decision = "reject", .reason = "durable direction remains NenDB adapter only" },
    .{ .id = "alternate-renderer", .attempted_claim = "workbench observations authorize React or another renderer", .decision = "reject", .reason = "workbench direction remains SolidJS inside webui-dev/zig-webui" },
    .{ .id = "mutation-authority", .attempted_claim = "the harness grants mutation authority", .decision = "reject", .reason = "mutation authority remains none" },
};

const agent_guidance: []const AgentGuidance = &.{
    .{ .id = "cite-scenario", .guidance = "Cite scenario id command status sample count median p95 and review gate." },
    .{ .id = "compare-like-with-like", .guidance = "Compare only compatible scenario ids environment classes optimize modes and artifact shapes." },
    .{ .id = "block-capacity-claims", .guidance = "Do not turn local observations into production capacity sizing." },
    .{ .id = "preserve-boundaries", .guidance = "Keep record-only mutation-authority-none NenDB-only and SolidJS webui constraints visible." },
    .{ .id = "handoff-to-telemetry-design", .guidance = "Use local observations to shape privacy-safe production telemetry capture design." },
};

const non_goals: []const []const u8 = &.{
    "production load tests",
    "live production telemetry ingestion",
    "reviewed production capacity sizing",
    "production cost or autoscaling estimates",
    "automatic CI timing gates",
    "arbitrary command execution",
    "shell invocation",
    "raw environment dumps",
    "source config registry app deployment rollout alert ticket page RBAC encryption durable-store CI-policy or production mutation",
    "non-NenDB durable adapter work",
    "Cockroach adapter work",
    "alternate frontend renderer work",
};

const verification_commands: []const []const u8 = &.{
    "cd packages/zigeffect",
    "zig test tools/causal_load_test_observation_harness.zig",
    "zig build causal-load-test-observation-harness",
    "zig build causal-load-test-observation-harness -- --format json",
    "zig build causal-load-test-observation-harness -- observe app-request-trace --iterations 1 --format json",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
    "cd ../..",
    "bun run zigeffect:workbench:test",
    "bun run zigeffect:workbench:typecheck",
    "bun run zigeffect:workbench:build",
    "bun run check",
    "bun run zig:test",
    "git diff --check",
};

fn scenarios() []const Scenario {
    return scenario_catalog;
}

fn sourceContracts() []const SourceContract {
    return source_contracts;
}

fn scenarioById(id: []const u8) ?Scenario {
    for (scenarios()) |scenario| {
        if (std.mem.eql(u8, scenario.id, id)) return scenario;
    }
    return null;
}

fn runObservation(
    allocator: std.mem.Allocator,
    runner: Runner,
    scenario: Scenario,
    iterations: u32,
) !ObservationRecord {
    if (iterations == 0) return error.InvalidIterations;
    if (iterations > max_iterations) return error.IterationLimitExceeded;
    switch (scenario.status) {
        .local_safe => {},
        .future_ci_only => return error.FutureCiOnlyScenario,
        .local_safe_needs_artifacts => return error.MissingArtifactRefs,
        .local_safe_workspace_root => return error.WorkspaceRootRequired,
    }

    const warmup = try runner.run(allocator, scenario.argv);
    defer deinitRunOutput(allocator, warmup);
    if (warmup.status == .failed) {
        return failedObservationRecord(allocator, scenario, warmup, 0);
    }

    const sample_count: usize = @intCast(iterations);
    var samples = try allocator.alloc(u64, sample_count);
    defer allocator.free(samples);

    var last_stdout_snippet: []const u8 = try allocator.dupe(u8, "");
    errdefer allocator.free(last_stdout_snippet);
    var last_stderr_snippet: []const u8 = try allocator.dupe(u8, "");
    errdefer allocator.free(last_stderr_snippet);

    var index: usize = 0;
    while (index < sample_count) : (index += 1) {
        const result = try runner.run(allocator, scenario.argv);
        defer deinitRunOutput(allocator, result);
        if (result.status == .failed) {
            allocator.free(last_stdout_snippet);
            allocator.free(last_stderr_snippet);
            return failedObservationRecord(allocator, scenario, result, @intCast(index));
        }

        samples[index] = result.elapsed_ms;
        allocator.free(last_stdout_snippet);
        allocator.free(last_stderr_snippet);
        last_stdout_snippet = try snippet(allocator, result.stdout);
        last_stderr_snippet = try snippet(allocator, result.stderr);
    }

    sortAscending(samples);

    return .{
        .scenario_id = scenario.id,
        .scenario_category = scenario.category,
        .command_status = .ok,
        .exit_code = 0,
        .warmup_iterations = warmup_iterations,
        .measured_iterations = iterations,
        .sample_count = iterations,
        .median_ms = median(samples),
        .p95_ms = p95(samples),
        .min_ms = samples[0],
        .max_ms = samples[samples.len - 1],
        .stdout_snippet = last_stdout_snippet,
        .stderr_snippet = last_stderr_snippet,
        .review_gate = if (iterations < 5) "needs-more-samples" else "needs-review",
    };
}

fn failedObservationRecord(
    allocator: std.mem.Allocator,
    scenario: Scenario,
    result: RunOutput,
    measured_count: u32,
) !ObservationRecord {
    return .{
        .scenario_id = scenario.id,
        .scenario_category = scenario.category,
        .command_status = .failed,
        .exit_code = result.exit_code,
        .warmup_iterations = warmup_iterations,
        .measured_iterations = measured_count,
        .sample_count = measured_count,
        .median_ms = 0,
        .p95_ms = 0,
        .min_ms = 0,
        .max_ms = 0,
        .stdout_snippet = try snippet(allocator, result.stdout),
        .stderr_snippet = try snippet(allocator, result.stderr),
        .review_gate = "failed-command-finding",
    };
}

fn freeObservationRecord(allocator: std.mem.Allocator, record: ObservationRecord) void {
    allocator.free(record.stdout_snippet);
    allocator.free(record.stderr_snippet);
}

fn deinitRunOutput(allocator: std.mem.Allocator, output: RunOutput) void {
    allocator.free(output.stdout);
    allocator.free(output.stderr);
}

fn statusForTerm(term: std.process.Child.Term) CommandStatus {
    return switch (term) {
        .exited => |code| if (code == 0) .ok else .failed,
        else => .failed,
    };
}

fn exitCodeForTerm(term: std.process.Child.Term) ?i32 {
    return switch (term) {
        .exited => |code| @intCast(code),
        else => null,
    };
}

fn sortAscending(values: []u64) void {
    if (values.len < 2) return;
    var index: usize = 1;
    while (index < values.len) : (index += 1) {
        const current = values[index];
        var cursor = index;
        while (cursor > 0 and values[cursor - 1] > current) : (cursor -= 1) {
            values[cursor] = values[cursor - 1];
        }
        values[cursor] = current;
    }
}

fn median(sorted: []const u64) u64 {
    return sorted[sorted.len / 2];
}

fn p95(sorted: []const u64) u64 {
    const index = @min(sorted.len - 1, (sorted.len * 95 + 99) / 100 - 1);
    return sorted[index];
}

fn snippet(allocator: std.mem.Allocator, value: []const u8) ![]const u8 {
    return allocator.dupe(u8, value[0..@min(value.len, snippet_limit)]);
}

fn formatCatalogText(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal load-test observation harness\n");
    try output.print(allocator, "schema: {s}\n", .{load_test_observation_harness_schema});
    try output.print(allocator, "schema_version: {d}\n", .{load_test_observation_harness_schema_version});
    try output.appendSlice(allocator, "status: current\n");
    try output.print(allocator, "generated by: {s}\n", .{generated_by});
    try output.print(allocator, "mode: {s}\n", .{mode});
    try output.appendSlice(allocator, "applied: false\n");
    try output.print(allocator, "mutation authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch: {s}\n\n", .{next_branch});

    try output.appendSlice(allocator, "authority boundary:\n");
    try output.appendSlice(allocator, "- local observations only\n");
    try output.appendSlice(allocator, "- production_load=false\n");
    try output.appendSlice(allocator, "- capacity_claim=false\n");
    try output.appendSlice(allocator, "- production_telemetry=false\n\n");

    try output.appendSlice(allocator, "source contracts:\n");
    for (sourceContracts()) |contract| {
        try output.print(allocator, "- {s}: {s}\n", .{ contract.id, contract.schema });
        try output.print(allocator, "  producer: {s}\n", .{contract.producer});
        try output.print(allocator, "  role: {s}\n", .{contract.evidence_role});
        try output.print(allocator, "  boundary: {s}\n", .{contract.authority_boundary});
    }

    try output.appendSlice(allocator, "\nscenario catalog:\n");
    for (scenarios()) |scenario| {
        try output.print(allocator, "- {s}: {s}\n", .{ scenario.id, scenarioStatusName(scenario.status) });
        try output.print(allocator, "  category: {s}\n", .{scenario.category});
        const argv_display = try scenarioArgvDisplay(allocator, scenario.argv);
        defer allocator.free(argv_display);
        try output.print(allocator, "  argv: {s}\n", .{argv_display});
        try output.print(allocator, "  boundary: {s}\n", .{scenario.local_safety_boundary});
        try output.print(allocator, "  blocked claim: {s}\n", .{scenario.blocked_claim});
    }

    try appendTextList(allocator, &output, "\nexecution constraints", execution_constraints);
    try appendTextList(allocator, &output, "\nreview gates", review_gates);

    try output.appendSlice(allocator, "\nnegative observation fixtures:\n");
    for (negative_fixtures) |fixture| {
        try output.print(allocator, "- {s}: {s}\n", .{ fixture.id, fixture.decision });
        try output.print(allocator, "  attempted claim: {s}\n", .{fixture.attempted_claim});
        try output.print(allocator, "  reason: {s}\n", .{fixture.reason});
    }

    try output.appendSlice(allocator, "\nagent guidance:\n");
    for (agent_guidance) |guidance| {
        try output.print(allocator, "- {s}: {s}\n", .{ guidance.id, guidance.guidance });
    }

    try appendTextList(allocator, &output, "\nnon-goals", non_goals);
    try appendTextList(allocator, &output, "\nverification commands", verification_commands);

    return output.toOwnedSlice(allocator);
}

fn formatCatalogJson(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonStringProperty(allocator, &output, "schema", load_test_observation_harness_schema, true, 2);
    try output.print(allocator, "  \"schema_version\": {d},\n", .{load_test_observation_harness_schema_version});
    try appendJsonStringProperty(allocator, &output, "producer", generated_by, true, 2);
    try appendJsonStringProperty(allocator, &output, "mode", mode, true, 2);
    try output.appendSlice(allocator, "  \"applied\": false,\n");
    try appendJsonStringProperty(allocator, &output, "mutation_authority", mutation_authority, true, 2);
    try appendJsonStringProperty(allocator, &output, "source_branch", source_branch, true, 2);
    try appendJsonStringProperty(allocator, &output, "status", "current", true, 2);
    try appendJsonStringProperty(allocator, &output, "recommendation", recommendation, true, 2);
    try appendJsonStringProperty(allocator, &output, "next_branch", next_branch, true, 2);
    try output.appendSlice(allocator, "  \"production_load\": false,\n");
    try output.appendSlice(allocator, "  \"capacity_claim\": false,\n");
    try output.appendSlice(allocator, "  \"production_telemetry\": false,\n");

    try output.appendSlice(allocator, "  \"source_contracts\": [\n");
    for (sourceContracts(), 0..) |contract, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", contract.id, true, 6);
        try appendJsonStringProperty(allocator, &output, "schema", contract.schema, true, 6);
        try appendJsonStringProperty(allocator, &output, "producer", contract.producer, true, 6);
        try appendJsonStringProperty(allocator, &output, "evidence_role", contract.evidence_role, true, 6);
        try appendJsonStringProperty(allocator, &output, "authority_boundary", contract.authority_boundary, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < sourceContracts().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"scenario_catalog\": [\n");
    for (scenarios(), 0..) |scenario, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", scenario.id, true, 6);
        try appendJsonStringProperty(allocator, &output, "category", scenario.category, true, 6);
        try appendJsonStringProperty(allocator, &output, "status", scenarioStatusName(scenario.status), true, 6);
        try appendJsonStringProperty(allocator, &output, "upstream_source", scenario.upstream_source, true, 6);
        try output.appendSlice(allocator, "      \"argv\": ");
        try appendStringArray(allocator, &output, scenario.argv);
        try output.appendSlice(allocator, ",\n");
        try appendJsonStringProperty(allocator, &output, "measurement_kind", scenario.measurement_kind, true, 6);
        try output.appendSlice(allocator, "      \"required_evidence\": ");
        try appendStringArray(allocator, &output, scenario.required_evidence);
        try output.appendSlice(allocator, ",\n");
        try appendJsonStringProperty(allocator, &output, "local_safety_boundary", scenario.local_safety_boundary, true, 6);
        try appendJsonStringProperty(allocator, &output, "blocked_claim", scenario.blocked_claim, true, 6);
        try appendJsonStringProperty(allocator, &output, "agent_guidance", scenario.agent_guidance, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < scenarios().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"observation_record_fields\": [\n");
    for (observation_record_fields, 0..) |field, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "name", field.name, true, 6);
        try output.print(allocator, "      \"required\": {},\n", .{field.required});
        try appendJsonStringProperty(allocator, &output, "description", field.description, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < observation_record_fields.len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"execution_constraints\": ");
    try appendStringArray(allocator, &output, execution_constraints);
    try output.appendSlice(allocator, ",\n  \"review_gates\": ");
    try appendStringArray(allocator, &output, review_gates);
    try output.appendSlice(allocator, ",\n");

    try output.appendSlice(allocator, "  \"negative_observation_fixtures\": [\n");
    for (negative_fixtures, 0..) |fixture, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", fixture.id, true, 6);
        try appendJsonStringProperty(allocator, &output, "attempted_claim", fixture.attempted_claim, true, 6);
        try appendJsonStringProperty(allocator, &output, "decision", fixture.decision, true, 6);
        try appendJsonStringProperty(allocator, &output, "reason", fixture.reason, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < negative_fixtures.len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"agent_guidance\": [\n");
    for (agent_guidance, 0..) |guidance, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", guidance.id, true, 6);
        try appendJsonStringProperty(allocator, &output, "guidance", guidance.guidance, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < agent_guidance.len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"non_goals\": ");
    try appendStringArray(allocator, &output, non_goals);
    try output.appendSlice(allocator, ",\n  \"verification_commands\": ");
    try appendStringArray(allocator, &output, verification_commands);
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn formatObservationText(allocator: std.mem.Allocator, record: ObservationRecord) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal load-test observation\n");
    try output.print(allocator, "schema: {s}\n", .{load_test_observation_harness_schema});
    try output.print(allocator, "schema_version: {d}\n", .{load_test_observation_harness_schema_version});
    try output.appendSlice(allocator, "mode: local-observation\n");
    try output.appendSlice(allocator, "applied: false\n");
    try output.print(allocator, "mutation authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "scenario: {s}\n", .{record.scenario_id});
    try output.print(allocator, "category: {s}\n", .{record.scenario_category});
    try output.print(allocator, "command status: {s}\n", .{commandStatusName(record.command_status)});
    if (record.exit_code) |code| try output.print(allocator, "exit code: {d}\n", .{code});
    try output.print(allocator, "warmups: {d}\n", .{record.warmup_iterations});
    try output.print(allocator, "sample count: {d}\n", .{record.sample_count});
    try output.print(allocator, "median_ms: {d}\n", .{record.median_ms});
    try output.print(allocator, "p95_ms: {d}\n", .{record.p95_ms});
    try output.print(allocator, "min_ms: {d}\n", .{record.min_ms});
    try output.print(allocator, "max_ms: {d}\n", .{record.max_ms});
    try output.print(allocator, "review gate: {s}\n", .{record.review_gate});
    try output.appendSlice(allocator, "production_load: false\n");
    try output.appendSlice(allocator, "capacity_claim: false\n");
    try output.appendSlice(allocator, "production_telemetry: false\n");
    return output.toOwnedSlice(allocator);
}

fn formatObservationJson(allocator: std.mem.Allocator, record: ObservationRecord) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonStringProperty(allocator, &output, "schema", load_test_observation_harness_schema, true, 2);
    try output.print(allocator, "  \"schema_version\": {d},\n", .{load_test_observation_harness_schema_version});
    try appendJsonStringProperty(allocator, &output, "producer", generated_by, true, 2);
    try appendJsonStringProperty(allocator, &output, "mode", "local-observation", true, 2);
    try output.appendSlice(allocator, "  \"applied\": false,\n");
    try appendJsonStringProperty(allocator, &output, "mutation_authority", mutation_authority, true, 2);
    try appendJsonStringProperty(allocator, &output, "scenario_id", record.scenario_id, true, 2);
    try appendJsonStringProperty(allocator, &output, "scenario_category", record.scenario_category, true, 2);
    try appendJsonStringProperty(allocator, &output, "command_status", commandStatusName(record.command_status), true, 2);
    if (record.exit_code) |code| {
        try output.print(allocator, "  \"exit_code\": {d},\n", .{code});
    } else {
        try output.appendSlice(allocator, "  \"exit_code\": null,\n");
    }
    try output.print(allocator, "  \"warmup_iterations\": {d},\n", .{record.warmup_iterations});
    try output.print(allocator, "  \"measured_iterations\": {d},\n", .{record.measured_iterations});
    try output.print(allocator, "  \"sample_count\": {d},\n", .{record.sample_count});
    try output.print(allocator, "  \"median_ms\": {d},\n", .{record.median_ms});
    try output.print(allocator, "  \"p95_ms\": {d},\n", .{record.p95_ms});
    try output.print(allocator, "  \"min_ms\": {d},\n", .{record.min_ms});
    try output.print(allocator, "  \"max_ms\": {d},\n", .{record.max_ms});
    try appendJsonStringProperty(allocator, &output, "stdout_snippet", record.stdout_snippet, true, 2);
    try appendJsonStringProperty(allocator, &output, "stderr_snippet", record.stderr_snippet, true, 2);
    try output.appendSlice(allocator, "  \"artifact_refs\": [],\n");
    try output.appendSlice(allocator, "  \"environment\": {\n");
    try appendJsonStringProperty(allocator, &output, "environment_class", "local", true, 4);
    try appendJsonStringProperty(allocator, &output, "runner_class", "developer-machine", true, 4);
    try appendJsonStringProperty(allocator, &output, "redaction_review", "bounded-snippets-only", false, 4);
    try output.appendSlice(allocator, "  },\n");
    try appendJsonStringProperty(allocator, &output, "review_gate", record.review_gate, true, 2);
    try output.appendSlice(allocator, "  \"capacity_claim\": false,\n");
    try output.appendSlice(allocator, "  \"production_telemetry\": false,\n");
    try output.appendSlice(allocator, "  \"production_load\": false,\n");
    try appendJsonStringProperty(allocator, &output, "agent_guidance", "Advisory local observation only; do not claim production capacity.", false, 2);
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}

fn appendTextList(allocator: std.mem.Allocator, output: *std.ArrayList(u8), title: []const u8, values: []const []const u8) !void {
    try output.print(allocator, "{s}:\n", .{title});
    for (values) |value| {
        try output.print(allocator, "- {s}\n", .{value});
    }
}

fn appendIndent(allocator: std.mem.Allocator, output: *std.ArrayList(u8), spaces: usize) !void {
    for (0..spaces) |_| try output.append(allocator, ' ');
}

fn appendJsonStringProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: []const u8,
    comma: bool,
    indent: usize,
) !void {
    try appendIndent(allocator, output, indent);
    try appendJsonString(allocator, output, name);
    try output.appendSlice(allocator, ": ");
    try appendJsonString(allocator, output, value);
    if (comma) try output.append(allocator, ',');
    try output.append(allocator, '\n');
}

fn appendStringArray(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const []const u8) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index != 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, value);
    }
    try output.append(allocator, ']');
}

fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void {
    try output.append(allocator, '"');
    for (value) |byte| switch (byte) {
        '"' => try output.appendSlice(allocator, "\\\""),
        '\\' => try output.appendSlice(allocator, "\\\\"),
        '\n' => try output.appendSlice(allocator, "\\n"),
        '\r' => try output.appendSlice(allocator, "\\r"),
        '\t' => try output.appendSlice(allocator, "\\t"),
        else => try output.append(allocator, byte),
    };
    try output.append(allocator, '"');
}

fn scenarioArgvDisplay(allocator: std.mem.Allocator, argv: []const []const u8) ![]const u8 {
    return std.mem.join(allocator, " ", argv);
}

fn scenarioStatusName(status: ScenarioStatus) []const u8 {
    return switch (status) {
        .local_safe => "local-safe",
        .local_safe_needs_artifacts => "local-safe-needs-artifacts",
        .local_safe_workspace_root => "local-safe-workspace-root",
        .future_ci_only => "future-ci-only",
    };
}

fn commandStatusName(status: CommandStatus) []const u8 {
    return switch (status) {
        .ok => "ok",
        .failed => "failed",
    };
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-load-test-observation-harness error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseOptions(args) catch |err| failUsage(err);
    switch (options.action) {
        .catalog => {
            const report = switch (options.format) {
                .text => try formatCatalogText(init.gpa),
                .json => try formatCatalogJson(init.gpa),
            };
            defer init.gpa.free(report);
            std.debug.print("{s}", .{report});
        },
        .observe => {
            const scenario = scenarioById(options.scenario_id.?) orelse failUsage(error.UnknownScenario);
            var process_runner = ProcessRunner{ .io = init.io };
            const record = runObservation(init.gpa, process_runner.runner(), scenario, options.iterations) catch |err| failUsage(err);
            defer freeObservationRecord(init.gpa, record);
            const report = switch (options.format) {
                .text => try formatObservationText(init.gpa, record),
                .json => try formatObservationJson(init.gpa, record),
            };
            defer init.gpa.free(report);
            std.debug.print("{s}", .{report});
        },
    }
}

fn hasScenario(id: []const u8) bool {
    for (scenarios()) |scenario| {
        if (std.mem.eql(u8, scenario.id, id)) return true;
    }
    return false;
}

fn hasScenarioStatus(id: []const u8, status: ScenarioStatus) bool {
    for (scenarios()) |scenario| {
        if (std.mem.eql(u8, scenario.id, id) and scenario.status == status) return true;
    }
    return false;
}

test "load-test observation harness usage names command and schema" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "causal-load-test-observation-harness") != null);
    try std.testing.expectEqualStrings("zigeffect.causal.load-test-observation-harness.v1", load_test_observation_harness_schema);
    try std.testing.expectEqualStrings("start-production-telemetry-capture-design", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-capture-design", next_branch);
}

test "load-test observation harness parses catalog and observe options" {
    try std.testing.expectEqual(Action.catalog, (try parseOptions(&.{"zigeffect-causal-load-test-observation-harness"})).action);
    try std.testing.expectEqual(OutputFormat.json, (try parseOptions(&.{ "zigeffect-causal-load-test-observation-harness", "--format", "json" })).format);
    const observe = try parseOptions(&.{ "zigeffect-causal-load-test-observation-harness", "observe", "app-request-trace", "--iterations", "3", "--format", "json" });
    try std.testing.expectEqual(Action.observe, observe.action);
    try std.testing.expectEqualStrings("app-request-trace", observe.scenario_id.?);
    try std.testing.expectEqual(@as(u32, 3), observe.iterations);
    try std.testing.expectError(error.IterationLimitExceeded, parseOptions(&.{ "zigeffect-causal-load-test-observation-harness", "observe", "app-request-trace", "--iterations", "11" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-load-test-observation-harness", "--format", "yaml" }));
    try std.testing.expectError(error.UnknownScenario, parseOptions(&.{ "zigeffect-causal-load-test-observation-harness", "observe", "unknown", "--iterations", "1" }));
}

test "load-test observation harness scenario catalog covers upstream families" {
    try std.testing.expectEqual(@as(usize, 8), scenarios().len);
    try std.testing.expect(hasScenario("app-request-trace"));
    try std.testing.expect(hasScenario("background-job-trace"));
    try std.testing.expect(hasScenario("causal-artifact-formatting"));
    try std.testing.expect(hasScenario("causal-query-agent-slices"));
    try std.testing.expect(hasScenario("causal-compare-before-after"));
    try std.testing.expect(hasScenario("causal-dev-loop-package-tests"));
    try std.testing.expect(hasScenario("workbench-solid-build"));
    try std.testing.expect(hasScenarioStatus("ci-baseline-capture", .future_ci_only));
}

test "load-test observation harness catalog json preserves authority boundaries" {
    const report = try formatCatalogJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.load-test-observation-harness.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"production_load\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"capacity_claim\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"ci-baseline-capture\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"status\": \"future-ci-only\"") != null);
}

test "load-test observation harness fake runner records median p95 and bounds" {
    var fake = FakeRunner.init(&.{
        .{ .status = .ok, .exit_code = 0, .stdout = "warmup", .stderr = "", .elapsed_ms = 100 },
        .{ .status = .ok, .exit_code = 0, .stdout = "one", .stderr = "", .elapsed_ms = 10 },
        .{ .status = .ok, .exit_code = 0, .stdout = "two", .stderr = "", .elapsed_ms = 20 },
        .{ .status = .ok, .exit_code = 0, .stdout = "three", .stderr = "", .elapsed_ms = 30 },
        .{ .status = .ok, .exit_code = 0, .stdout = "four", .stderr = "", .elapsed_ms = 40 },
        .{ .status = .ok, .exit_code = 0, .stdout = "five", .stderr = "", .elapsed_ms = 50 },
    });
    defer fake.deinit(std.testing.allocator);

    const record = try runObservation(std.testing.allocator, fake.runner(), scenarioById("app-request-trace").?, 5);
    defer freeObservationRecord(std.testing.allocator, record);

    try std.testing.expectEqual(@as(u32, 1), record.warmup_iterations);
    try std.testing.expectEqual(@as(u32, 5), record.sample_count);
    try std.testing.expectEqual(@as(u64, 30), record.median_ms);
    try std.testing.expectEqual(@as(u64, 50), record.p95_ms);
    try std.testing.expectEqualStrings("needs-review", record.review_gate);
    try std.testing.expectEqual(@as(usize, 6), fake.calls.items.len);
}

test "load-test observation harness failed command becomes finding gate" {
    var fake = FakeRunner.init(&.{
        .{ .status = .ok, .exit_code = 0, .stdout = "warmup", .stderr = "", .elapsed_ms = 5 },
        .{ .status = .failed, .exit_code = 1, .stdout = "", .stderr = "failure", .elapsed_ms = 7 },
    });
    defer fake.deinit(std.testing.allocator);

    const record = try runObservation(std.testing.allocator, fake.runner(), scenarioById("app-request-trace").?, 1);
    defer freeObservationRecord(std.testing.allocator, record);

    try std.testing.expectEqual(CommandStatus.failed, record.command_status);
    try std.testing.expect(record.exit_code.? == 1);
    try std.testing.expectEqualStrings("failed-command-finding", record.review_gate);
}

test "load-test observation harness blocks non-local observation scenarios" {
    var fake = FakeRunner.init(&.{});
    defer fake.deinit(std.testing.allocator);

    try std.testing.expectError(error.FutureCiOnlyScenario, runObservation(std.testing.allocator, fake.runner(), scenarioById("ci-baseline-capture").?, 1));
    try std.testing.expectError(error.MissingArtifactRefs, runObservation(std.testing.allocator, fake.runner(), scenarioById("causal-compare-before-after").?, 1));
    try std.testing.expectError(error.WorkspaceRootRequired, runObservation(std.testing.allocator, fake.runner(), scenarioById("workbench-solid-build").?, 1));
}

test "load-test observation harness observation json is advisory and local-only" {
    var fake = FakeRunner.init(&.{
        .{ .status = .ok, .exit_code = 0, .stdout = "warmup", .stderr = "", .elapsed_ms = 5 },
        .{ .status = .ok, .exit_code = 0, .stdout = "done", .stderr = "", .elapsed_ms = 7 },
    });
    defer fake.deinit(std.testing.allocator);

    const record = try runObservation(std.testing.allocator, fake.runner(), scenarioById("app-request-trace").?, 1);
    defer freeObservationRecord(std.testing.allocator, record);
    const report = try formatObservationJson(std.testing.allocator, record);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"mode\": \"local-observation\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"capacity_claim\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"production_telemetry\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"production_load\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"review_gate\": \"needs-more-samples\"") != null);
}
