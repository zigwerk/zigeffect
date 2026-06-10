const std = @import("std");

pub const wall_clock_benchmark_baselines_schema = "zigeffect.causal.wall-clock-benchmark-baselines.v1";
pub const wall_clock_benchmark_baselines_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-wall-clock-benchmark-baselines";
pub const next_branch = "codex/zigeffect-causal-production-capacity-planning";

const OutputFormat = enum { text, json };

const generated_by = "causal-wall-clock-benchmark-baselines";
const mode = "local-record";
const mutation_authority = "none";

const ScenarioFamily = struct {
    id: []const u8,
    category: []const u8,
    description: []const u8,
    command: []const u8,
    measurement_kind: []const u8,
    baseline_scope: []const u8,
    primary_metric: []const u8,
    secondary_metrics: []const []const u8,
    agent_guidance: []const u8,
};

const BaselineRecordField = struct {
    name: []const u8,
    required: bool,
    description: []const u8,
    guidance: []const u8,
};

const EnvironmentField = struct {
    name: []const u8,
    required: bool,
    safe_to_share: bool,
    description: []const u8,
};

const CalibrationPolicy = struct {
    id: []const u8,
    rule: []const u8,
    rationale: []const u8,
};

const ReviewGate = struct {
    id: []const u8,
    decision: []const u8,
    trigger: []const u8,
    action: []const u8,
};

const AgentGuidance = struct {
    id: []const u8,
    guidance: []const u8,
};

fn usage() []const u8 {
    return
    \\usage:
    \\  zig build causal-wall-clock-benchmark-baselines
    \\  zig build causal-wall-clock-benchmark-baselines -- --format text
    \\  zig build causal-wall-clock-benchmark-baselines -- --format json
    \\
    \\formats:
    \\  --format text|json
    \\
    ;
}

fn parseOptions(args: []const []const u8) !OutputFormat {
    if (args.len == 1) return .text;
    if (args.len == 3 and std.mem.eql(u8, args[1], "--format")) {
        if (std.mem.eql(u8, args[2], "text")) return .text;
        if (std.mem.eql(u8, args[2], "json")) return .json;
        return error.UnknownFormat;
    }
    if (args.len == 2 and std.mem.eql(u8, args[1], "--format")) return error.MissingFormat;
    return error.UnknownFlag;
}

const source_contracts: []const []const u8 = &.{
    "zigeffect.causal.performance-budget.v1",
    "zigeffect.causal.production-artifact-aggregation.v1",
    "zigeffect.causal.production-hardening-backlog.v1",
};

const scenario_families: []const ScenarioFamily = &.{
    .{
        .id = "app-request-trace",
        .category = "runtime-request",
        .description = "Observed cost of recording a bounded app request causal trace with semantic refs and redaction metadata.",
        .command = "future causal-benchmark --scenario app-request-trace",
        .measurement_kind = "wall-clock elapsed milliseconds",
        .baseline_scope = "local and CI records stay separate",
        .primary_metric = "median_ms",
        .secondary_metrics = &.{ "p95_ms", "min_ms", "max_ms", "sample_count" },
        .agent_guidance = "Compare only against compatible request-trace baselines and cite retained-event limits.",
    },
    .{
        .id = "background-job-trace",
        .category = "runtime-job",
        .description = "Observed cost of recording a larger bounded background-job causal trace with dropped-event metadata.",
        .command = "future causal-benchmark --scenario background-job-trace",
        .measurement_kind = "wall-clock elapsed milliseconds",
        .baseline_scope = "local and CI records stay separate",
        .primary_metric = "median_ms",
        .secondary_metrics = &.{ "p95_ms", "dropped_events", "sample_count" },
        .agent_guidance = "Call out retention and dropped-event state before comparing job traces.",
    },
    .{
        .id = "causal-artifact-formatting",
        .category = "artifact",
        .description = "Observed cost of formatting representative causal traces as text JSON and DOT artifacts.",
        .command = "future causal-benchmark --scenario causal-artifact-formatting",
        .measurement_kind = "wall-clock elapsed milliseconds",
        .baseline_scope = "artifact shape and schema compatible records only",
        .primary_metric = "median_ms",
        .secondary_metrics = &.{ "p95_ms", "artifact_bytes", "sample_count" },
        .agent_guidance = "Do not compare artifacts with incompatible schema versions or very different retained event counts.",
    },
    .{
        .id = "causal-query-agent-slices",
        .category = "agent-query",
        .description = "Observed cost of bounded agent query slices such as summarize run find failures explain event trace cause and trace data.",
        .command = "future causal-benchmark --scenario causal-query-agent-slices",
        .measurement_kind = "wall-clock elapsed milliseconds",
        .baseline_scope = "same query family and artifact class",
        .primary_metric = "median_ms",
        .secondary_metrics = &.{ "p95_ms", "response_bytes", "sample_count" },
        .agent_guidance = "Prefer query-family comparisons and cite response bounds when explaining deltas.",
    },
    .{
        .id = "causal-compare-before-after",
        .category = "comparison",
        .description = "Observed cost of comparing baseline and after causal artifacts for regression review.",
        .command = "future causal-benchmark --scenario causal-compare-before-after",
        .measurement_kind = "wall-clock elapsed milliseconds",
        .baseline_scope = "paired baseline and after artifact fixtures",
        .primary_metric = "median_ms",
        .secondary_metrics = &.{ "p95_ms", "finding_count", "sample_count" },
        .agent_guidance = "Separate comparison cost from the severity of findings produced by the compare command.",
    },
    .{
        .id = "causal-dev-loop-package-tests",
        .category = "developer-loop",
        .description = "Observed cost of producing before after development-loop artifacts around package tests.",
        .command = "future causal-benchmark --scenario causal-dev-loop-package-tests",
        .measurement_kind = "wall-clock elapsed milliseconds",
        .baseline_scope = "same package-test scenario and optimize mode",
        .primary_metric = "median_ms",
        .secondary_metrics = &.{ "p95_ms", "test_count", "sample_count" },
        .agent_guidance = "Do not call a package-test timing delta a runtime regression without causal evidence.",
    },
    .{
        .id = "workbench-solid-build",
        .category = "workbench",
        .description = "Observed cost of SolidJS workbench build and test boundaries hosted by webui-dev/zig-webui.",
        .command = "future causal-benchmark --scenario workbench-solid-build",
        .measurement_kind = "wall-clock elapsed milliseconds",
        .baseline_scope = "same Bun lockfile package scripts and renderer direction",
        .primary_metric = "median_ms",
        .secondary_metrics = &.{ "p95_ms", "bundle_bytes", "sample_count" },
        .agent_guidance = "Keep workbench timing separate from Zig runtime tracing and note package-manager drift.",
    },
    .{
        .id = "ci-baseline-capture",
        .category = "ci",
        .description = "Observed overhead of capturing PR base causal artifacts before current-branch verification.",
        .command = "future CI benchmark observation step",
        .measurement_kind = "wall-clock elapsed milliseconds",
        .baseline_scope = "same CI provider runner image and checkout depth",
        .primary_metric = "median_ms",
        .secondary_metrics = &.{ "p95_ms", "artifact_bytes", "sample_count" },
        .agent_guidance = "Treat CI runner image or provider drift as environment drift before regression.",
    },
};

const baseline_record_fields: []const BaselineRecordField = &.{
    .{ .name = "scenario_id", .required = true, .description = "Scenario family being measured.", .guidance = "Compare only identical scenario ids." },
    .{ .name = "baseline_id", .required = true, .description = "Stable id for the baseline observation.", .guidance = "Use reviewed baseline ids in findings." },
    .{ .name = "environment_class", .required = true, .description = "Local developer machine CI runner or other approved class.", .guidance = "Prefer local-to-local and CI-to-CI comparisons." },
    .{ .name = "runner_class", .required = true, .description = "Human-readable runner or machine class.", .guidance = "Treat runner changes as environment drift." },
    .{ .name = "optimize_mode", .required = true, .description = "Zig optimize mode or package build mode.", .guidance = "Do not compare incompatible optimize modes." },
    .{ .name = "warmup_iterations", .required = true, .description = "Warmup iterations run before measurement.", .guidance = "Missing warmups should trigger needs-more-samples." },
    .{ .name = "measured_iterations", .required = true, .description = "Measured iteration count.", .guidance = "Use this as sample_count for review gates." },
    .{ .name = "sample_count", .required = true, .description = "Alias for measured iterations in agent summaries.", .guidance = "Do not hide small samples." },
    .{ .name = "median_ms", .required = true, .description = "Median elapsed milliseconds.", .guidance = "Primary comparison metric." },
    .{ .name = "p95_ms", .required = true, .description = "95th percentile elapsed milliseconds.", .guidance = "Use for tail-latency review." },
    .{ .name = "min_ms", .required = true, .description = "Minimum observed elapsed milliseconds.", .guidance = "Useful for noise inspection only." },
    .{ .name = "max_ms", .required = true, .description = "Maximum observed elapsed milliseconds.", .guidance = "Investigate large spread before claiming regression." },
    .{ .name = "stddev_ms", .required = false, .description = "Optional standard deviation.", .guidance = "Use when the harness can compute it." },
    .{ .name = "artifact_refs", .required = true, .description = "Causal artifact or benchmark observation refs.", .guidance = "Cite refs in every benchmark finding." },
    .{ .name = "source_commit", .required = true, .description = "Commit or tree ref used for the observation.", .guidance = "Never compare unknown source states." },
    .{ .name = "observed_at", .required = true, .description = "Observation timestamp or externally supplied observation id.", .guidance = "Use for ordering only not deterministic proof." },
    .{ .name = "measurement_notes", .required = false, .description = "Short notes about load thermal state or harness caveats.", .guidance = "Keep notes redacted and bounded." },
    .{ .name = "redaction_review", .required = true, .description = "Whether artifact refs and environment fields were redaction reviewed.", .guidance = "Block sharing when review is absent." },
    .{ .name = "schema_ref", .required = true, .description = "Schema of the observation artifact.", .guidance = "Fail closed on unsupported observation schemas." },
};

const environment_fields: []const EnvironmentField = &.{
    .{ .name = "machine_class", .required = true, .safe_to_share = true, .description = "Coarse local machine class or benchmark host class." },
    .{ .name = "runner_class", .required = true, .safe_to_share = true, .description = "CI or local runner family." },
    .{ .name = "os_name", .required = true, .safe_to_share = true, .description = "Operating system name." },
    .{ .name = "os_version", .required = true, .safe_to_share = true, .description = "Operating system version or runner image version." },
    .{ .name = "cpu_arch", .required = true, .safe_to_share = true, .description = "CPU architecture." },
    .{ .name = "cpu_model", .required = false, .safe_to_share = true, .description = "Coarse CPU model when safely available." },
    .{ .name = "cpu_count", .required = true, .safe_to_share = true, .description = "Logical CPU count or class." },
    .{ .name = "memory_class", .required = false, .safe_to_share = true, .description = "Coarse memory class when safely available." },
    .{ .name = "zig_version", .required = true, .safe_to_share = true, .description = "Zig compiler version." },
    .{ .name = "bun_version", .required = false, .safe_to_share = true, .description = "Bun version for workbench and package commands." },
    .{ .name = "shell", .required = false, .safe_to_share = true, .description = "Shell family used by the harness." },
    .{ .name = "optimize_mode", .required = true, .safe_to_share = true, .description = "Build optimize mode." },
    .{ .name = "thermal_or_load_notes", .required = false, .safe_to_share = true, .description = "Bounded local load notes without process details." },
    .{ .name = "ci_provider", .required = false, .safe_to_share = true, .description = "CI provider for CI records." },
    .{ .name = "ci_runner_image", .required = false, .safe_to_share = true, .description = "CI runner image or version." },
    .{ .name = "ci_run_id", .required = false, .safe_to_share = true, .description = "CI run id for artifact lookup." },
};

const calibration_policy: []const CalibrationPolicy = &.{
    .{ .id = "warmups-required", .rule = "Run warmups before measured iterations.", .rationale = "First-run compiler filesystem and cache effects distort wall-clock records." },
    .{ .id = "local-minimum-samples", .rule = "Local exploratory records need at least five measured iterations.", .rationale = "Small local samples can guide investigation but not release decisions." },
    .{ .id = "ci-minimum-samples", .rule = "CI reviewable records need at least ten measured iterations.", .rationale = "CI runners are noisy and need more samples before review." },
    .{ .id = "median-and-p95", .rule = "Report median and p95 rather than a single elapsed time.", .rationale = "Agents need central and tail signals." },
    .{ .id = "compatible-environment-only", .rule = "Compare only the same scenario family and compatible environment class.", .rationale = "Runner or compiler drift can dominate benchmark deltas." },
    .{ .id = "failed-command-is-finding", .rule = "Record failed benchmark commands as causal findings.", .rationale = "Missing timing data should not be silently ignored." },
    .{ .id = "human-review-before-blocking", .rule = "Require human review before any wall-clock delta becomes release blocking.", .rationale = "This contract is advisory and record-only." },
    .{ .id = "threshold-policy", .rule = "Use 15 percent median 25 percent p95 and a 5ms absolute floor as advisory review thresholds.", .rationale = "Percentage-only findings are noisy for tiny measurements." },
};

const review_gates: []const ReviewGate = &.{
    .{ .id = "record-only", .decision = "record", .trigger = "default for every wall-clock observation", .action = "store or upload advisory evidence only" },
    .{ .id = "needs-more-samples", .decision = "collect-more-evidence", .trigger = "missing sample count environment metadata artifact refs or warmups", .action = "request another observation before comparing" },
    .{ .id = "review-regression", .decision = "human-review", .trigger = "compatible records exceed advisory median or p95 threshold", .action = "open review with artifact refs and environment metadata" },
    .{ .id = "review-environment-drift", .decision = "human-review", .trigger = "runner OS compiler package manager or optimize mode changed", .action = "review environment drift before runtime claims" },
    .{ .id = "ready-for-capacity-planning", .decision = "handoff", .trigger = "reviewed baselines cover request job artifact query compare dev-loop workbench and CI capture scenarios", .action = "handoff to production capacity planning without claiming capacity" },
};

const agent_guidance: []const AgentGuidance = &.{
    .{ .id = "separate-budget-from-baseline", .guidance = "Use causal-performance-budget for deterministic constants and this report for noisy wall-clock observation contracts." },
    .{ .id = "compare-like-with-like", .guidance = "Compare only matching scenario ids with compatible environment class optimize mode compiler and package-manager versions." },
    .{ .id = "cite-evidence", .guidance = "Every benchmark finding should cite source commit artifact refs sample count median p95 and environment metadata." },
    .{ .id = "prefer-review-over-failure", .guidance = "Recommend human review rather than automatic CI failure for wall-clock deltas." },
    .{ .id = "watch-environment-drift", .guidance = "Explain runner image compiler package manager or workload drift before claiming runtime regression." },
    .{ .id = "handoff-to-capacity", .guidance = "Use ready-for-capacity-planning only after reviewed baselines exist across the core scenario surface." },
};

const non_goals: []const []const u8 = &.{
    "live production benchmarking",
    "automatic CI failure gates from timing",
    "network calls or external service probes",
    "load testing",
    "production capacity sizing",
    "durable writes",
    "non-NenDB durable adapter work",
    "deployment rollout source config app registry or production mutation",
    "alternate frontend renderer support",
};

const verification_commands: []const []const u8 = &.{
    "cd packages/zigeffect",
    "zig test tools/causal_wall_clock_benchmark_baselines.zig",
    "zig build causal-wall-clock-benchmark-baselines",
    "zig build causal-wall-clock-benchmark-baselines -- --format json",
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

fn scenarioFamilies() []const ScenarioFamily {
    return scenario_families;
}

fn baselineRecordFields() []const BaselineRecordField {
    return baseline_record_fields;
}

fn environmentFields() []const EnvironmentField {
    return environment_fields;
}

fn calibrationPolicy() []const CalibrationPolicy {
    return calibration_policy;
}

fn reviewGates() []const ReviewGate {
    return review_gates;
}

fn agentGuidance() []const AgentGuidance {
    return agent_guidance;
}

fn nonGoals() []const []const u8 {
    return non_goals;
}

fn verificationCommands() []const []const u8 {
    return verification_commands;
}

fn formatWallClockBenchmarkBaselinesText(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal wall-clock benchmark baselines\n");
    try output.print(allocator, "schema: {s}\n", .{wall_clock_benchmark_baselines_schema});
    try output.print(allocator, "schema_version: {d}\n", .{wall_clock_benchmark_baselines_schema_version});
    try output.appendSlice(allocator, "status: current\n");
    try output.print(allocator, "generated by: {s}\n", .{generated_by});
    try output.print(allocator, "mode: {s}\n", .{mode});
    try output.appendSlice(allocator, "applied: false\n");
    try output.print(allocator, "mutation authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "next branch: {s}\n\n", .{next_branch});

    try output.appendSlice(allocator, "budget separation:\n");
    try output.appendSlice(allocator, "- causal-performance-budget is the deterministic performance budget for stable runtime constants\n");
    try output.appendSlice(allocator, "- this report defines wall-clock benchmark baselines as noisy review evidence only\n");
    try output.appendSlice(allocator, "- wall-clock deltas are advisory until a human review records a release decision\n\n");

    try output.appendSlice(allocator, "source contracts:\n");
    for (source_contracts) |contract| try output.print(allocator, "- {s}\n", .{contract});

    try output.appendSlice(allocator, "\nscenario families:\n");
    for (scenarioFamilies()) |scenario| {
        try output.print(allocator, "- {s}\n", .{scenario.id});
        try output.print(allocator, "  category: {s}\n", .{scenario.category});
        try output.print(allocator, "  description: {s}\n", .{scenario.description});
        try output.print(allocator, "  command: {s}\n", .{scenario.command});
        try output.print(allocator, "  measurement kind: {s}\n", .{scenario.measurement_kind});
        try output.print(allocator, "  baseline scope: {s}\n", .{scenario.baseline_scope});
        try output.print(allocator, "  primary metric: {s}\n", .{scenario.primary_metric});
        try output.appendSlice(allocator, "  secondary metrics:");
        for (scenario.secondary_metrics) |metric| try output.print(allocator, " {s}", .{metric});
        try output.append(allocator, '\n');
        try output.print(allocator, "  agent guidance: {s}\n", .{scenario.agent_guidance});
    }

    try output.appendSlice(allocator, "\nbaseline record fields:\n");
    for (baselineRecordFields()) |field| {
        try output.print(allocator, "- {s} required={any}\n", .{ field.name, field.required });
        try output.print(allocator, "  description: {s}\n", .{field.description});
        try output.print(allocator, "  guidance: {s}\n", .{field.guidance});
    }

    try output.appendSlice(allocator, "\nenvironment fields:\n");
    for (environmentFields()) |field| {
        try output.print(allocator, "- {s} required={any} safe_to_share={any}\n", .{ field.name, field.required, field.safe_to_share });
        try output.print(allocator, "  description: {s}\n", .{field.description});
    }

    try output.appendSlice(allocator, "\ncalibration policy:\n");
    for (calibrationPolicy()) |policy| {
        try output.print(allocator, "- {s}: {s}\n", .{ policy.id, policy.rule });
        try output.print(allocator, "  rationale: {s}\n", .{policy.rationale});
    }

    try output.appendSlice(allocator, "\nreview gates:\n");
    for (reviewGates()) |gate| {
        try output.print(allocator, "- {s}: {s}\n", .{ gate.id, gate.decision });
        try output.print(allocator, "  trigger: {s}\n", .{gate.trigger});
        try output.print(allocator, "  action: {s}\n", .{gate.action});
    }

    try output.appendSlice(allocator, "\nagent guidance:\n");
    for (agentGuidance()) |guidance| {
        try output.print(allocator, "- {s}: {s}\n", .{ guidance.id, guidance.guidance });
    }

    try output.appendSlice(allocator, "\nnon-goals:\n");
    for (nonGoals()) |item| try output.print(allocator, "- {s}\n", .{item});

    try output.appendSlice(allocator, "\nverification commands:\n");
    for (verificationCommands()) |command| try output.print(allocator, "- {s}\n", .{command});

    return output.toOwnedSlice(allocator);
}

fn formatWallClockBenchmarkBaselinesJson(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonStringProperty(allocator, &output, "schema", wall_clock_benchmark_baselines_schema, true, 2);
    try output.print(allocator, "  \"schema_version\": {d},\n", .{wall_clock_benchmark_baselines_schema_version});
    try appendJsonStringProperty(allocator, &output, "producer", generated_by, true, 2);
    try appendJsonStringProperty(allocator, &output, "mode", mode, true, 2);
    try output.appendSlice(allocator, "  \"applied\": false,\n");
    try appendJsonStringProperty(allocator, &output, "mutation_authority", mutation_authority, true, 2);
    try appendJsonStringProperty(allocator, &output, "source_branch", source_branch, true, 2);
    try output.appendSlice(allocator, "  \"source_contracts\": ");
    try appendStringArray(allocator, &output, source_contracts);
    try output.appendSlice(allocator, ",\n");

    try output.appendSlice(allocator, "  \"scenario_families\": [\n");
    for (scenarioFamilies(), 0..) |scenario, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", scenario.id, true, 6);
        try appendJsonStringProperty(allocator, &output, "category", scenario.category, true, 6);
        try appendJsonStringProperty(allocator, &output, "description", scenario.description, true, 6);
        try appendJsonStringProperty(allocator, &output, "command", scenario.command, true, 6);
        try appendJsonStringProperty(allocator, &output, "measurement_kind", scenario.measurement_kind, true, 6);
        try appendJsonStringProperty(allocator, &output, "baseline_scope", scenario.baseline_scope, true, 6);
        try appendJsonStringProperty(allocator, &output, "primary_metric", scenario.primary_metric, true, 6);
        try appendIndent(allocator, &output, 6);
        try output.appendSlice(allocator, "\"secondary_metrics\": ");
        try appendStringArray(allocator, &output, scenario.secondary_metrics);
        try output.appendSlice(allocator, ",\n");
        try appendJsonStringProperty(allocator, &output, "agent_guidance", scenario.agent_guidance, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < scenarioFamilies().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"baseline_record_contract\": [\n");
    for (baselineRecordFields(), 0..) |field, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "name", field.name, true, 6);
        try appendJsonBoolProperty(allocator, &output, "required", field.required, true, 6);
        try appendJsonStringProperty(allocator, &output, "description", field.description, true, 6);
        try appendJsonStringProperty(allocator, &output, "guidance", field.guidance, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < baselineRecordFields().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"environment_fields\": [\n");
    for (environmentFields(), 0..) |field, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "name", field.name, true, 6);
        try appendJsonBoolProperty(allocator, &output, "required", field.required, true, 6);
        try appendJsonBoolProperty(allocator, &output, "safe_to_share", field.safe_to_share, true, 6);
        try appendJsonStringProperty(allocator, &output, "description", field.description, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < environmentFields().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"calibration_policy\": [\n");
    for (calibrationPolicy(), 0..) |policy, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", policy.id, true, 6);
        try appendJsonStringProperty(allocator, &output, "rule", policy.rule, true, 6);
        try appendJsonStringProperty(allocator, &output, "rationale", policy.rationale, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < calibrationPolicy().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"review_gates\": [\n");
    for (reviewGates(), 0..) |gate, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", gate.id, true, 6);
        try appendJsonStringProperty(allocator, &output, "decision", gate.decision, true, 6);
        try appendJsonStringProperty(allocator, &output, "trigger", gate.trigger, true, 6);
        try appendJsonStringProperty(allocator, &output, "action", gate.action, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < reviewGates().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"agent_guidance\": [\n");
    for (agentGuidance(), 0..) |guidance, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", guidance.id, true, 6);
        try appendJsonStringProperty(allocator, &output, "guidance", guidance.guidance, false, 6);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < agentGuidance().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"non_goals\": ");
    try appendStringArray(allocator, &output, nonGoals());
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"verification_commands\": ");
    try appendStringArray(allocator, &output, verificationCommands());
    try output.appendSlice(allocator, ",\n");
    try appendJsonStringProperty(allocator, &output, "next_branch", next_branch, false, 2);
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const format = parseOptions(args) catch |err| failUsage(err);
    const report = switch (format) {
        .text => try formatWallClockBenchmarkBaselinesText(init.gpa),
        .json => try formatWallClockBenchmarkBaselinesJson(init.gpa),
    };
    defer init.gpa.free(report);

    std.debug.print("{s}", .{report});
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-wall-clock-benchmark-baselines error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
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

fn appendJsonBoolProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: bool,
    comma: bool,
    indent: usize,
) !void {
    try appendIndent(allocator, output, indent);
    try appendJsonString(allocator, output, name);
    try output.appendSlice(allocator, ": ");
    try output.appendSlice(allocator, if (value) "true" else "false");
    if (comma) try output.append(allocator, ',');
    try output.append(allocator, '\n');
}

fn appendStringArray(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    values: []const []const u8,
) !void {
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

fn hasScenario(id: []const u8) bool {
    for (scenarioFamilies()) |scenario| {
        if (std.mem.eql(u8, scenario.id, id)) return true;
    }
    return false;
}

fn hasBaselineField(name: []const u8) bool {
    for (baselineRecordFields()) |field| {
        if (std.mem.eql(u8, field.name, name)) return true;
    }
    return false;
}

fn hasEnvironmentField(name: []const u8) bool {
    for (environmentFields()) |field| {
        if (std.mem.eql(u8, field.name, name)) return true;
    }
    return false;
}

fn hasReviewGate(id: []const u8) bool {
    for (reviewGates()) |gate| {
        if (std.mem.eql(u8, gate.id, id)) return true;
    }
    return false;
}

test "wall clock benchmark baseline usage names command and formats" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "causal-wall-clock-benchmark-baselines") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--format text|json") != null);
    try std.testing.expectEqualStrings("zigeffect.causal.wall-clock-benchmark-baselines.v1", wall_clock_benchmark_baselines_schema);
}

test "wall clock benchmark baseline parses format options" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-wall-clock-benchmark-baselines"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-wall-clock-benchmark-baselines", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-wall-clock-benchmark-baselines", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-wall-clock-benchmark-baselines", "--format", "yaml" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-wall-clock-benchmark-baselines", "--json" }));
}

test "wall clock benchmark baseline scenario inventory covers core timing surface" {
    try std.testing.expectEqual(@as(usize, 8), scenarioFamilies().len);
    try std.testing.expect(hasScenario("app-request-trace"));
    try std.testing.expect(hasScenario("background-job-trace"));
    try std.testing.expect(hasScenario("causal-artifact-formatting"));
    try std.testing.expect(hasScenario("causal-query-agent-slices"));
    try std.testing.expect(hasScenario("causal-compare-before-after"));
    try std.testing.expect(hasScenario("causal-dev-loop-package-tests"));
    try std.testing.expect(hasScenario("workbench-solid-build"));
    try std.testing.expect(hasScenario("ci-baseline-capture"));
}

test "wall clock benchmark baseline record contract includes comparison fields" {
    try std.testing.expect(hasBaselineField("scenario_id"));
    try std.testing.expect(hasBaselineField("sample_count"));
    try std.testing.expect(hasBaselineField("median_ms"));
    try std.testing.expect(hasBaselineField("p95_ms"));
    try std.testing.expect(hasBaselineField("environment_class"));
    try std.testing.expect(hasBaselineField("artifact_refs"));
    try std.testing.expect(hasBaselineField("source_commit"));
}

test "wall clock benchmark baseline environment fields are curated" {
    try std.testing.expect(hasEnvironmentField("zig_version"));
    try std.testing.expect(hasEnvironmentField("bun_version"));
    try std.testing.expect(hasEnvironmentField("runner_class"));
    try std.testing.expect(!hasEnvironmentField("raw_environment_dump"));
    try std.testing.expect(!hasEnvironmentField("hostname"));
}

test "wall clock benchmark baseline review gates stay advisory" {
    try std.testing.expect(hasReviewGate("record-only"));
    try std.testing.expect(hasReviewGate("needs-more-samples"));
    try std.testing.expect(hasReviewGate("review-regression"));
    try std.testing.expect(hasReviewGate("review-environment-drift"));
    try std.testing.expect(hasReviewGate("ready-for-capacity-planning"));
}

test "wall clock benchmark baseline text report explains budget separation" {
    const report = try formatWallClockBenchmarkBaselinesText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "wall-clock benchmark baselines") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "deterministic performance budget") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "mutation authority: none") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, next_branch) != null);
}

test "wall clock benchmark baseline json report is machine readable" {
    const report = try formatWallClockBenchmarkBaselinesJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.wall-clock-benchmark-baselines.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"scenario_families\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"next_branch\": \"codex/zigeffect-causal-production-capacity-planning\"") != null);
}
