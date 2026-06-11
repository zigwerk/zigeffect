const std = @import("std");

pub const schema = "zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1";
pub const schema_version: u32 = 1;
pub const source_schema = "zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1";
pub const tool_name = "causal-app-facing-production-integration-solid-webui-readonly-preview";
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview";
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report";
pub const output_suffix = "-solid-webui-readonly-preview";

const generated_by = tool_name;
const applied = false;
const mutation_authority = "none";
const read_only_preview = true;
const solid_webui_enabled = true;
const solid_webui_renderer = "solidjs";
const webui_bridge = "webui-dev/zig-webui";
const hosted_live_dashboard_enabled = false;
const app_mutation_controls_enabled = false;
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const network_send_enabled = false;
const collector_endpoint_configured = false;
const otlp_serialization_enabled = false;
const durable_write_enabled = false;
const app_mutation_enabled = false;
const ci_gate_enabled = false;
const raw_payload_capture_enabled = false;
const app_config_write_enabled = false;
const app_data_write_enabled = false;
const deployment_mutation_enabled = false;
const nendb_write_enabled = false;
const nendb_adapter_execution_enabled = false;
const app_runtime_integration_enabled = false;
const agent_query_live_projection_enabled = false;
const mutation_proof_claim_enabled = false;
const auto_apply_enabled = false;
const production_health_claim_enabled = false;
const react_renderer_enabled = false;
const alternate_renderer_enabled = false;

const Decision = enum { approve, reject };
const PreviewStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    from_bridge: []const u8,
    decision: Decision,
    reason: []const u8,
    out_prefix: ?[]const u8 = null,
    format: []const u8 = "text",
    verified_commands: []const []const u8 = &.{},

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        if (self.verified_commands.len > 0) allocator.free(self.verified_commands);
    }
};

const OutputPaths = struct {
    json_path: []const u8,
    text_path: []const u8,

    fn deinit(self: OutputPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json_path);
        allocator.free(self.text_path);
    }
};

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingFromBridge;
    if (!std.mem.eql(u8, args[1], "--from-bridge")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingFromBridge;
    const from_bridge = args[2];
    if (!std.mem.endsWith(u8, from_bridge, ".json")) return error.InvalidBridgePath;
    if (args.len < 4) return error.MissingDecision;
    const decision = try parseDecision(args[3]);

    var reason: ?[]const u8 = null;
    var out_prefix: ?[]const u8 = null;
    var format: []const u8 = "text";
    var verified_commands = std.ArrayList([]const u8).empty;
    errdefer verified_commands.deinit(allocator);

    var index: usize = 4;
    while (index < args.len) {
        const arg = args[index];
        if (!std.mem.startsWith(u8, arg, "--")) return error.UnknownArgument;
        if (index + 1 >= args.len) return error.MissingFlagValue;
        const value = args[index + 1];

        if (std.mem.eql(u8, arg, "--reason")) {
            reason = value;
        } else if (std.mem.eql(u8, arg, "--verified-command")) {
            if (value.len == 0) return error.MissingVerifiedCommand;
            try verified_commands.append(allocator, value);
        } else if (std.mem.eql(u8, arg, "--out-prefix")) {
            out_prefix = value;
        } else if (std.mem.eql(u8, arg, "--format")) {
            if (!std.mem.eql(u8, value, "json") and !std.mem.eql(u8, value, "text")) return error.UnsupportedFormat;
            format = value;
        } else {
            return error.UnknownFlag;
        }
        index += 2;
    }

    const final_reason = reason orelse return error.MissingReason;
    if (final_reason.len == 0) return error.MissingReason;

    return .{
        .from_bridge = from_bridge,
        .decision = decision,
        .reason = final_reason,
        .out_prefix = out_prefix,
        .format = format,
        .verified_commands = try verified_commands.toOwnedSlice(allocator),
    };
}

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    const prefix = if (options.out_prefix) |out_prefix|
        try allocator.dupe(u8, out_prefix)
    else blk: {
        if (!std.mem.endsWith(u8, options.from_bridge, ".json")) return error.InvalidBridgePath;
        const base = options.from_bridge[0 .. options.from_bridge.len - ".json".len];
        const stripped = if (std.mem.endsWith(u8, base, "-audit-remediation-bridge"))
            base[0 .. base.len - "-audit-remediation-bridge".len]
        else
            base;
        break :blk try std.fmt.allocPrint(allocator, "{s}{s}", .{ stripped, output_suffix });
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn parseDecision(value: []const u8) !Decision {
    if (std.mem.eql(u8, value, "approve")) return .approve;
    if (std.mem.eql(u8, value, "reject")) return .reject;
    return error.InvalidDecision;
}

fn decisionText(decision: Decision) []const u8 {
    return switch (decision) {
        .approve => "approve",
        .reject => "reject",
    };
}

fn statusText(status: PreviewStatus) []const u8 {
    return switch (status) {
        .ready => "ready",
        .blocked => "blocked",
    };
}

fn checkStatusText(status: CheckStatus) []const u8 {
    return switch (status) {
        .pass => "pass",
        .fail => "fail",
    };
}

const PreviewInput = struct {
    options: Options,
    source_bridge_json: []const u8,
};

const PreviewReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: PreviewReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const SourceCheck = struct {
    name: []const u8 = "",
    status: []const u8 = "",
    detail: []const u8 = "",
};

const SourceBridgeRecord = struct {
    id: []const u8 = "",
    status: []const u8 = "",
    source_ref: []const u8 = "",
    target_ref: []const u8 = "",
    source_handoff_fixture: []const u8 = "",
    audit_ref: []const u8 = "",
    remediation_ref: []const u8 = "",
    bridge_kind: []const u8 = "",
    review_state: []const u8 = "",
    retained_refs: []const []const u8 = &.{},
    blocked_claims: []const []const u8 = &.{},
};

const SourceBridgeArtifact = struct {
    schema: []const u8 = "",
    status: []const u8 = "",
    audit_remediation_bridge_status: []const u8 = "",
    decision: []const u8 = "",
    applied: bool = true,
    mutation_authority: []const u8 = "",
    audit_remediation_bridge_mode: bool = false,
    mutation_proof_claim_enabled: bool = true,
    auto_apply_enabled: bool = true,
    production_health_claim_enabled: bool = true,
    production_telemetry_ingestion: bool = true,
    live_exporter_enabled: bool = true,
    network_send_enabled: bool = true,
    collector_endpoint_configured: bool = true,
    otlp_serialization_enabled: bool = true,
    durable_write_enabled: bool = true,
    app_mutation_enabled: bool = true,
    ci_gate_enabled: bool = true,
    raw_payload_capture_enabled: bool = true,
    app_config_write_enabled: bool = true,
    app_data_write_enabled: bool = true,
    deployment_mutation_enabled: bool = true,
    nendb_write_enabled: bool = true,
    nendb_adapter_execution_enabled: bool = true,
    app_runtime_integration_enabled: bool = true,
    agent_query_live_projection_enabled: bool = true,
    solid_webui_preview_enabled: bool = true,
    checks: []const SourceCheck = &.{},
    validation_checks: []const []const u8 = &.{},
    bridge_validation_checks: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    bridge_records: []const SourceBridgeRecord = &.{},
    audit_remediation_bridge_records: []const SourceBridgeRecord = &.{},
    source_handoff: []const u8 = "",
    source_boundary: []const u8 = "",
    source_proposal: []const u8 = "",
    source_readiness: []const u8 = "",
    source_fixtures: []const u8 = "",
};

const PreviewCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const PreviewSection = struct {
    id: []const u8,
    title: []const u8,
    evidence_refs: []const []const u8,
    blocked_authority: []const []const u8,
};

const PreviewResult = struct {
    status: PreviewStatus,
    ready_for_next_branch: bool,
    checks: []const PreviewCheck,
    source_status: []const u8,
    bridge_records: []const SourceBridgeRecord,

    fn deinit(self: PreviewResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

fn formatReports(allocator: std.mem.Allocator, input: PreviewInput) !PreviewReports {
    var parsed = try std.json.parseFromSlice(SourceBridgeArtifact, allocator, input.source_bridge_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const result = try evaluatePreview(allocator, input.options, parsed.value);
    defer result.deinit(allocator);

    const json = try formatPreviewJson(allocator, input.options, parsed.value, result);
    errdefer allocator.free(json);
    const text = try formatPreviewText(allocator, input.options, result);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

fn evaluatePreview(
    allocator: std.mem.Allocator,
    options: Options,
    bridge: SourceBridgeArtifact,
) !PreviewResult {
    var checks = std.ArrayList(PreviewCheck).empty;
    errdefer checks.deinit(allocator);

    const bridge_records = sourceBridgeRecords(bridge);
    const bridge_status = sourceBridgeStatus(bridge);

    try appendCheck(allocator, &checks, "bridge-schema", if (std.mem.eql(u8, bridge.schema, source_schema)) .pass else .fail, "source audit/remediation bridge schema is supported");
    try appendCheck(allocator, &checks, "bridge-status", if (std.mem.eql(u8, bridge_status, "ready")) .pass else .fail, "source audit/remediation bridge is ready");
    try appendCheck(allocator, &checks, "bridge-decision-approved", if (std.mem.eql(u8, bridge.decision, "approve")) .pass else .fail, "source audit/remediation bridge was approved");
    try appendCheck(allocator, &checks, "preview-decision", if (options.reason.len > 0) .pass else .fail, "preview decision records a review reason");
    try appendCheck(allocator, &checks, "decision-approved", if (options.decision == .approve) .pass else .fail, "review decision approves this read-only preview artifact");
    try appendCheck(allocator, &checks, "authority-boundary", if (sourceAuthorityDisabled(bridge)) .pass else .fail, "source bridge and preview keep mutation authority disabled");
    try appendCheck(allocator, &checks, "source-chain-linked", if (sourceChainLinked(bridge)) .pass else .fail, "source bridge keeps upstream handoff links or bridge records");
    try appendCheck(allocator, &checks, "bridge-checks-passed", if (sourceChecksPassed(bridge.checks)) .pass else .fail, "all source bridge checks passed");
    try appendCheck(allocator, &checks, "bridge-verification-recorded", if (sourceVerificationRecorded(bridge)) .pass else .fail, "source bridge recorded verification command evidence");
    try appendCheck(allocator, &checks, "bridge-catalog-present", if (bridgeCatalogPresent(bridge_records)) .pass else .fail, "source bridge catalog contains the six app-facing review records");
    try appendCheck(allocator, &checks, "preview-panels-present", if (preview_panels.len == 12) .pass else .fail, "preview panel catalog is complete");
    try appendCheck(allocator, &checks, "preview-sections-present", if (app_preview_sections.len == 6) .pass else .fail, "app preview section catalog is complete");
    try appendCheck(allocator, &checks, "solid-webui-readonly", if (read_only_preview and solid_webui_enabled and !applied and std.mem.eql(u8, mutation_authority, "none")) .pass else .fail, "preview is read-only SolidJS inside webui-dev/zig-webui");
    try appendCheck(allocator, &checks, "solid-renderer", if (std.mem.eql(u8, solid_webui_renderer, "solidjs")) .pass else .fail, "renderer is SolidJS only");
    try appendCheck(allocator, &checks, "webui-bridge-scope", if (std.mem.eql(u8, webui_bridge, "webui-dev/zig-webui")) .pass else .fail, "preview remains scoped to webui-dev/zig-webui");
    try appendCheck(allocator, &checks, "app-mutation-controls-disabled", if (!app_mutation_controls_enabled and !app_mutation_enabled) .pass else .fail, "app mutation controls remain disabled");
    try appendCheck(allocator, &checks, "hosted-live-dashboard-disabled", if (!hosted_live_dashboard_enabled) .pass else .fail, "hosted live dashboard remains disabled");
    try appendCheck(allocator, &checks, "react-renderer-disabled", if (!react_renderer_enabled) .pass else .fail, "React renderer is not enabled");
    try appendCheck(allocator, &checks, "alternate-renderer-disabled", if (!alternate_renderer_enabled) .pass else .fail, "alternate renderer is not enabled");
    try appendCheck(allocator, &checks, "preview-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "preview review recorded every required verification command");
    try appendCheck(allocator, &checks, "nendb-write-disabled", if (!nendb_write_enabled and !bridge.nendb_write_enabled) .pass else .fail, "NenDB writes remain disabled");
    try appendCheck(allocator, &checks, "nendb-adapter-execution-disabled", if (!nendb_adapter_execution_enabled and !bridge.nendb_adapter_execution_enabled) .pass else .fail, "NenDB adapter execution remains disabled");
    try appendCheck(allocator, &checks, "durable-write-disabled", if (!durable_write_enabled and !bridge.durable_write_enabled) .pass else .fail, "durable writes remain disabled");
    try appendCheck(allocator, &checks, "deployment-mutation-disabled", if (!deployment_mutation_enabled and !bridge.deployment_mutation_enabled) .pass else .fail, "deployment mutation remains disabled");
    try appendCheck(allocator, &checks, "auto-apply-disabled", if (!auto_apply_enabled and !bridge.auto_apply_enabled) .pass else .fail, "auto-apply remains disabled");
    try appendCheck(allocator, &checks, "mutation-proof-disabled", if (!mutation_proof_claim_enabled and !bridge.mutation_proof_claim_enabled) .pass else .fail, "mutation proof claims remain disabled");
    try appendCheck(allocator, &checks, "production-health-claim-disabled", if (!production_health_claim_enabled and !bridge.production_health_claim_enabled) .pass else .fail, "production health claims remain disabled");
    try appendCheck(allocator, &checks, "nendb-only-scope", if (nendbOnlyScope()) .pass else .fail, "durable scope remains NenDB-only and explicitly excludes Cockroach adapter work");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);
    const ready = allChecksPassed(check_slice);

    return .{
        .status = if (ready) .ready else .blocked,
        .ready_for_next_branch = ready,
        .checks = check_slice,
        .source_status = bridge_status,
        .bridge_records = bridge_records,
    };
}

fn appendCheck(
    allocator: std.mem.Allocator,
    checks: *std.ArrayList(PreviewCheck),
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
) !void {
    try checks.append(allocator, .{ .name = name, .status = status, .detail = detail });
}

fn sourceBridgeStatus(bridge: SourceBridgeArtifact) []const u8 {
    if (bridge.status.len > 0) return bridge.status;
    return bridge.audit_remediation_bridge_status;
}

fn sourceBridgeRecords(bridge: SourceBridgeArtifact) []const SourceBridgeRecord {
    if (bridge.bridge_records.len > 0) return bridge.bridge_records;
    return bridge.audit_remediation_bridge_records;
}

fn sourceAuthorityDisabled(bridge: SourceBridgeArtifact) bool {
    return !bridge.applied and
        std.mem.eql(u8, bridge.mutation_authority, "none") and
        bridge.audit_remediation_bridge_mode and
        !bridge.mutation_proof_claim_enabled and
        !bridge.auto_apply_enabled and
        !bridge.production_health_claim_enabled and
        !bridge.production_telemetry_ingestion and
        !bridge.live_exporter_enabled and
        !bridge.network_send_enabled and
        !bridge.collector_endpoint_configured and
        !bridge.otlp_serialization_enabled and
        !bridge.durable_write_enabled and
        !bridge.app_mutation_enabled and
        !bridge.ci_gate_enabled and
        !bridge.raw_payload_capture_enabled and
        !bridge.app_config_write_enabled and
        !bridge.app_data_write_enabled and
        !bridge.deployment_mutation_enabled and
        !bridge.nendb_write_enabled and
        !bridge.nendb_adapter_execution_enabled and
        !bridge.app_runtime_integration_enabled and
        !bridge.agent_query_live_projection_enabled and
        !bridge.solid_webui_preview_enabled;
}

fn sourceChainLinked(bridge: SourceBridgeArtifact) bool {
    return bridge.source_handoff.len > 0 or
        bridge.source_boundary.len > 0 or
        bridge.source_proposal.len > 0 or
        bridge.source_readiness.len > 0 or
        bridge.source_fixtures.len > 0 or
        sourceBridgeRecords(bridge).len > 0;
}

fn sourceChecksPassed(checks: []const SourceCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (!std.mem.eql(u8, check.status, "pass")) return false;
    }
    return true;
}

fn sourceVerificationRecorded(bridge: SourceBridgeArtifact) bool {
    if (bridge.verified_commands.len == 0) return false;
    if (bridge.required_verification_commands.len == 0) return true;
    return verifiedCommandsContainAll(bridge.verified_commands, bridge.required_verification_commands);
}

fn bridgeCatalogPresent(records: []const SourceBridgeRecord) bool {
    const required = [_][]const u8{
        "audit-chain-comparison-review-bridge",
        "remediation-review-policy-gate-bridge",
        "runtime-to-remediation-evidence-bridge",
        "agent-query-to-remediation-next-query-bridge",
        "solid-webui-review-preview-bridge",
        "ci-advisory-remediation-report-bridge",
    };

    for (required) |id| {
        if (!hasBridgeRecord(records, id)) return false;
    }
    return records.len >= required.len;
}

fn hasBridgeRecord(records: []const SourceBridgeRecord, id: []const u8) bool {
    for (records) |record| {
        if (std.mem.eql(u8, record.id, id)) return true;
    }
    return false;
}

fn verifiedCommandsContainAll(verified_commands: []const []const u8, required_commands: []const []const u8) bool {
    for (required_commands) |required| {
        var found = false;
        for (verified_commands) |verified| {
            if (std.mem.eql(u8, verified, required)) {
                found = true;
                break;
            }
        }
        if (!found) return false;
    }
    return true;
}

fn nendbOnlyScope() bool {
    return containsString(non_goals, "non-NenDB durable adapters") and
        containsString(non_goals, "Cockroach adapter work") and
        containsString(blocked_claims, "cockroach-adapter-work");
}

fn containsString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.indexOf(u8, value, needle) != null) return true;
    }
    return false;
}

fn allChecksPassed(checks: []const PreviewCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn hasCheck(checks: []const PreviewCheck, name: []const u8, status: CheckStatus) bool {
    for (checks) |check| {
        if (std.mem.eql(u8, check.name, name) and check.status == status) return true;
    }
    return false;
}

fn formatPreviewJson(
    allocator: std.mem.Allocator,
    options: Options,
    bridge: SourceBridgeArtifact,
    result: PreviewResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, schema);
    try output.appendSlice(allocator, ",\n  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"source_schema\": ");
    try appendJsonString(allocator, &output, source_schema);
    try output.appendSlice(allocator, ",\n  \"tool\": ");
    try appendJsonString(allocator, &output, tool_name);
    try output.appendSlice(allocator, ",\n  \"generated_by\": ");
    try appendJsonString(allocator, &output, generated_by);
    try output.appendSlice(allocator, ",\n  \"source_branch\": ");
    try appendJsonString(allocator, &output, source_branch);
    try output.appendSlice(allocator, ",\n  \"source_bridge\": ");
    try appendJsonString(allocator, &output, options.from_bridge);
    try output.appendSlice(allocator, ",\n  \"source_bridge_status\": ");
    try appendJsonString(allocator, &output, result.source_status);
    try output.appendSlice(allocator, ",\n  \"status\": ");
    try appendJsonString(allocator, &output, statusText(result.status));
    try output.appendSlice(allocator, ",\n  \"solid_webui_readonly_preview_status\": ");
    try appendJsonString(allocator, &output, statusText(result.status));
    try output.appendSlice(allocator, ",\n  \"decision\": ");
    try appendJsonString(allocator, &output, decisionText(options.decision));
    try output.appendSlice(allocator, ",\n  \"reason\": ");
    try appendJsonString(allocator, &output, options.reason);
    try output.print(allocator, ",\n  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try output.print(allocator, "  \"applied\": {},\n", .{applied});
    try output.appendSlice(allocator, "  \"mutation_authority\": ");
    try appendJsonString(allocator, &output, mutation_authority);
    try output.print(allocator, ",\n  \"read_only_preview\": {},\n", .{read_only_preview});
    try output.print(allocator, "  \"solid_webui_enabled\": {},\n", .{solid_webui_enabled});
    try output.appendSlice(allocator, "  \"solid_webui_renderer\": ");
    try appendJsonString(allocator, &output, solid_webui_renderer);
    try output.appendSlice(allocator, ",\n  \"webui_bridge\": ");
    try appendJsonString(allocator, &output, webui_bridge);
    try output.print(allocator, ",\n  \"hosted_live_dashboard_enabled\": {},\n", .{hosted_live_dashboard_enabled});
    try output.print(allocator, "  \"app_mutation_controls_enabled\": {},\n", .{app_mutation_controls_enabled});
    try output.print(allocator, "  \"production_telemetry_ingestion\": {},\n", .{production_telemetry_ingestion});
    try output.print(allocator, "  \"live_exporter_enabled\": {},\n", .{live_exporter_enabled});
    try output.print(allocator, "  \"network_send_enabled\": {},\n", .{network_send_enabled});
    try output.print(allocator, "  \"collector_endpoint_configured\": {},\n", .{collector_endpoint_configured});
    try output.print(allocator, "  \"otlp_serialization_enabled\": {},\n", .{otlp_serialization_enabled});
    try output.print(allocator, "  \"durable_write_enabled\": {},\n", .{durable_write_enabled});
    try output.print(allocator, "  \"app_mutation_enabled\": {},\n", .{app_mutation_enabled});
    try output.print(allocator, "  \"ci_gate_enabled\": {},\n", .{ci_gate_enabled});
    try output.print(allocator, "  \"raw_payload_capture_enabled\": {},\n", .{raw_payload_capture_enabled});
    try output.print(allocator, "  \"app_config_write_enabled\": {},\n", .{app_config_write_enabled});
    try output.print(allocator, "  \"app_data_write_enabled\": {},\n", .{app_data_write_enabled});
    try output.print(allocator, "  \"deployment_mutation_enabled\": {},\n", .{deployment_mutation_enabled});
    try output.print(allocator, "  \"nendb_write_enabled\": {},\n", .{nendb_write_enabled});
    try output.print(allocator, "  \"nendb_adapter_execution_enabled\": {},\n", .{nendb_adapter_execution_enabled});
    try output.print(allocator, "  \"app_runtime_integration_enabled\": {},\n", .{app_runtime_integration_enabled});
    try output.print(allocator, "  \"agent_query_live_projection_enabled\": {},\n", .{agent_query_live_projection_enabled});
    try output.print(allocator, "  \"mutation_proof_claim_enabled\": {},\n", .{mutation_proof_claim_enabled});
    try output.print(allocator, "  \"auto_apply_enabled\": {},\n", .{auto_apply_enabled});
    try output.print(allocator, "  \"production_health_claim_enabled\": {},\n", .{production_health_claim_enabled});
    try output.print(allocator, "  \"react_renderer_enabled\": {},\n", .{react_renderer_enabled});
    try output.print(allocator, "  \"alternate_renderer_enabled\": {},\n", .{alternate_renderer_enabled});
    try output.appendSlice(allocator, "  \"preview_panels\": ");
    try appendStringArray(allocator, &output, preview_panels);
    try output.appendSlice(allocator, ",\n  \"app_preview_sections\": ");
    try appendPreviewSectionsJson(allocator, &output, app_preview_sections);
    try output.appendSlice(allocator, ",\n  \"bridge_records\": ");
    try appendBridgeRecordsJson(allocator, &output, result.bridge_records);
    try output.appendSlice(allocator, ",\n  \"source_verified_commands\": ");
    try appendStringArray(allocator, &output, bridge.verified_commands);
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"validation_checks\": ");
    try appendStringArray(allocator, &output, validation_checks);
    try output.appendSlice(allocator, ",\n  \"implementation_gates\": ");
    try appendStringArray(allocator, &output, implementation_gates);
    try output.appendSlice(allocator, ",\n  \"non_goals\": ");
    try appendStringArray(allocator, &output, non_goals);
    try output.appendSlice(allocator, ",\n  \"blocked_claims\": ");
    try appendStringArray(allocator, &output, blocked_claims);
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, required_verification_commands);
    try output.appendSlice(allocator, ",\n  \"verified_commands\": ");
    try appendStringArray(allocator, &output, options.verified_commands);
    try output.appendSlice(allocator, ",\n  \"agent_guidance\": ");
    try appendStringArray(allocator, &output, agentGuidance(result.status));
    try output.appendSlice(allocator, ",\n  \"recommendation\": ");
    try appendJsonString(allocator, &output, recommendation);
    try output.appendSlice(allocator, ",\n  \"next_branch_if_ready\": ");
    try appendJsonString(allocator, &output, next_branch_if_ready);
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn formatPreviewText(
    allocator: std.mem.Allocator,
    options: Options,
    result: PreviewResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect app-facing production integration SolidJS read-only preview\n");
    try output.print(allocator, "schema: {s}\n", .{schema});
    try output.print(allocator, "source schema: {s}\n", .{source_schema});
    try output.print(allocator, "source bridge: {s}\n", .{options.from_bridge});
    try output.print(allocator, "source bridge status: {s}\n", .{result.source_status});
    try output.print(allocator, "status: {s}\n", .{statusText(result.status)});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "ready for next branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "applied: {}\n", .{applied});
    try output.print(allocator, "mutation authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "read only preview: {}\n", .{read_only_preview});
    try output.print(allocator, "solid webui enabled: {}\n", .{solid_webui_enabled});
    try output.print(allocator, "solid webui renderer: {s}\n", .{solid_webui_renderer});
    try output.print(allocator, "webui bridge: {s}\n", .{webui_bridge});
    try output.print(allocator, "app mutation controls enabled: {}\n", .{app_mutation_controls_enabled});
    try output.print(allocator, "hosted live dashboard enabled: {}\n", .{hosted_live_dashboard_enabled});
    try output.print(allocator, "react renderer enabled: {}\n", .{react_renderer_enabled});
    try output.print(allocator, "alternate renderer enabled: {}\n", .{alternate_renderer_enabled});
    try output.print(allocator, "nendb write enabled: {}\n", .{nendb_write_enabled});
    try output.print(allocator, "nendb adapter execution enabled: {}\n", .{nendb_adapter_execution_enabled});
    try output.print(allocator, "durable write enabled: {}\n", .{durable_write_enabled});
    try output.print(allocator, "deployment mutation enabled: {}\n", .{deployment_mutation_enabled});
    try output.print(allocator, "auto apply enabled: {}\n", .{auto_apply_enabled});
    try output.print(allocator, "mutation proof claim enabled: {}\n", .{mutation_proof_claim_enabled});
    try output.print(allocator, "production health claim enabled: {}\n", .{production_health_claim_enabled});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch: {s}\n\n", .{next_branch_if_ready});

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendBridgeRecordsText(allocator, &output, result.bridge_records);
    try appendTextList(allocator, &output, "preview panels", preview_panels);
    try appendPreviewSectionsText(allocator, &output, app_preview_sections);
    try appendTextList(allocator, &output, "validation checks", validation_checks);
    try appendTextList(allocator, &output, "implementation gates", implementation_gates);
    try appendTextList(allocator, &output, "non-goals", non_goals);
    try appendTextList(allocator, &output, "blocked claims", blocked_claims);
    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", options.verified_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return output.toOwnedSlice(allocator);
}

fn appendChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const PreviewCheck) !void {
    try output.append(allocator, '[');
    for (checks, 0..) |check, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"name\": ");
        try appendJsonString(allocator, output, check.name);
        try output.appendSlice(allocator, ", \"status\": ");
        try appendJsonString(allocator, output, checkStatusText(check.status));
        try output.appendSlice(allocator, ", \"detail\": ");
        try appendJsonString(allocator, output, check.detail);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendPreviewSectionsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), sections: []const PreviewSection) !void {
    try output.append(allocator, '[');
    for (sections, 0..) |section, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, section.id);
        try output.appendSlice(allocator, ", \"title\": ");
        try appendJsonString(allocator, output, section.title);
        try output.appendSlice(allocator, ", \"evidence_refs\": ");
        try appendStringArray(allocator, output, section.evidence_refs);
        try output.appendSlice(allocator, ", \"blocked_authority\": ");
        try appendStringArray(allocator, output, section.blocked_authority);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendBridgeRecordsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), records: []const SourceBridgeRecord) !void {
    try output.append(allocator, '[');
    for (records, 0..) |record, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, record.id);
        try output.appendSlice(allocator, ", \"status\": ");
        try appendJsonString(allocator, output, bridgeRecordStatus(record));
        try output.appendSlice(allocator, ", \"source_ref\": ");
        try appendJsonString(allocator, output, bridgeRecordSourceRef(record));
        try output.appendSlice(allocator, ", \"target_ref\": ");
        try appendJsonString(allocator, output, bridgeRecordTargetRef(record));
        try output.appendSlice(allocator, ", \"bridge_kind\": ");
        try appendJsonString(allocator, output, record.bridge_kind);
        try output.appendSlice(allocator, ", \"retained_refs\": ");
        try appendStringArray(allocator, output, record.retained_refs);
        try output.appendSlice(allocator, ", \"blocked_claims\": ");
        try appendStringArray(allocator, output, record.blocked_claims);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendBridgeRecordsText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), records: []const SourceBridgeRecord) !void {
    try output.appendSlice(allocator, "bridge records:\n");
    if (records.len == 0) {
        try output.appendSlice(allocator, "- none\n\n");
        return;
    }
    for (records) |record| {
        try output.print(allocator, "- {s}: {s} ({s})\n", .{ record.id, bridgeRecordStatus(record), record.bridge_kind });
        try output.print(allocator, "  source ref: {s}\n", .{bridgeRecordSourceRef(record)});
        try output.print(allocator, "  target ref: {s}\n", .{bridgeRecordTargetRef(record)});
    }
    try output.append(allocator, '\n');
}

fn appendPreviewSectionsText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), sections: []const PreviewSection) !void {
    try output.appendSlice(allocator, "app preview sections:\n");
    for (sections) |section| {
        try output.print(allocator, "- {s}: {s}\n", .{ section.id, section.title });
        try output.appendSlice(allocator, "  evidence refs:");
        for (section.evidence_refs) |ref| try output.print(allocator, " {s}", .{ref});
        try output.appendSlice(allocator, "\n  blocked authority:");
        for (section.blocked_authority) |authority| try output.print(allocator, " {s}", .{authority});
        try output.append(allocator, '\n');
    }
    try output.append(allocator, '\n');
}

fn bridgeRecordStatus(record: SourceBridgeRecord) []const u8 {
    if (record.status.len > 0) return record.status;
    if (record.review_state.len > 0) return record.review_state;
    return "ready";
}

fn bridgeRecordSourceRef(record: SourceBridgeRecord) []const u8 {
    if (record.source_ref.len > 0) return record.source_ref;
    if (record.source_handoff_fixture.len > 0) return record.source_handoff_fixture;
    return record.audit_ref;
}

fn bridgeRecordTargetRef(record: SourceBridgeRecord) []const u8 {
    if (record.target_ref.len > 0) return record.target_ref;
    if (record.remediation_ref.len > 0) return record.remediation_ref;
    return record.review_state;
}

fn appendStringArray(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const []const u8) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
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
        0...7,
        11,
        12,
        14...31,
        => {
            const hex = "0123456789abcdef";
            try output.appendSlice(allocator, "\\u00");
            try output.append(allocator, hex[@intCast(byte >> 4)]);
            try output.append(allocator, hex[@intCast(byte & 0x0f)]);
        },
        else => try output.append(allocator, byte),
    };
    try output.append(allocator, '"');
}

fn appendTextList(allocator: std.mem.Allocator, output: *std.ArrayList(u8), title: []const u8, values: []const []const u8) !void {
    try output.print(allocator, "{s}:\n", .{title});
    if (values.len == 0) {
        try output.appendSlice(allocator, "- none\n\n");
        return;
    }
    for (values) |value| {
        try output.print(allocator, "- {s}\n", .{value});
    }
    try output.append(allocator, '\n');
}

fn agentGuidance(status: PreviewStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Ready audit/remediation bridge evidence may be inspected in the local SolidJS workbench preview only.",
            "Agents should cite source bridge records preview sections checks and verification commands when reasoning about app-facing remediation state.",
            "Do not infer live app runtime integration live agent projection raw payload capture app mutation NenDB writes NenDB adapter execution Cockroach scope CI enforcement deployment mutation production health mutation proof auto-apply or applied=true.",
        },
        .blocked => &.{
            "Blocked preview artifacts must not be treated as app runtime integration or live dashboard evidence.",
            "Repair source bridge readiness authority drift bridge record coverage or preview verification command evidence first.",
            "Keep app writes deployment mutation CI enforcement NenDB adapter execution and production health claims disabled.",
        },
    };
}

fn usage() []const u8 {
    return "usage: zig build causal-app-facing-production-integration-solid-webui-readonly-preview -- --from-bridge <bridge.json> approve|reject --reason <reason> [--verified-command <command>]... [--out-prefix <path-prefix>] [--format json|text]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-app-facing-production-integration-solid-webui-readonly-preview error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn readRequiredArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingBridgeInput,
        else => return err,
    };
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

fn run(init: std.process.Init, options: Options) !void {
    const allocator = init.gpa;
    const source_bridge_json = try readRequiredArtifact(init.io, allocator, options.from_bridge);
    defer allocator.free(source_bridge_json);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_bridge_json = source_bridge_json,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);

    if (std.mem.eql(u8, options.format, "json")) {
        std.debug.print("{s}", .{reports.json});
    } else {
        std.debug.print("{s}", .{reports.text});
    }
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseOptions(init.gpa, args) catch |err| failUsage(err);
    defer options.deinit(init.gpa);
    run(init, options) catch |err| switch (err) {
        error.MissingBridgeInput => failUsage(err),
        else => return err,
    };
}

const preview_panels: []const []const u8 = &.{
    "status",
    "source-artifacts",
    "authority-boundary",
    "audit-remediation-bridge-records",
    "runtime-remediation-evidence",
    "agent-query-next-queries",
    "solid-webui-preview-state",
    "ci-advisory-state",
    "verification",
    "blocked-claims",
    "non-goals",
    "next-branch",
};

const app_preview_sections: []const PreviewSection = &.{
    .{ .id = "audit-chain-comparison", .title = "Audit chain comparison", .evidence_refs = &.{ "audit-chain-comparison-review-bridge", "audit_chain_ref", "comparison_ref" }, .blocked_authority = &.{ "mutation-proof", "fixed-claim", "deployed-claim" } },
    .{ .id = "remediation-review", .title = "Remediation review", .evidence_refs = &.{ "remediation-review-policy-gate-bridge", "remediation_review_ref", "policy_gate_ref" }, .blocked_authority = &.{ "auto-apply", "app-config-write", "app-data-write" } },
    .{ .id = "runtime-evidence", .title = "Runtime remediation evidence", .evidence_refs = &.{ "runtime-to-remediation-evidence-bridge", "trace_id_ref", "causal_event_ref" }, .blocked_authority = &.{ "raw-payload-join", "source-database-read" } },
    .{ .id = "agent-query-evidence", .title = "Agent query next queries", .evidence_refs = &.{ "agent-query-to-remediation-next-query-bridge", "finding_refs", "next_query_refs" }, .blocked_authority = &.{ "raw-prompt", "raw-response", "unbounded-query" } },
    .{ .id = "solid-webui-preview", .title = "SolidJS WebUI read-only preview", .evidence_refs = &.{ "solid-webui-review-preview-bridge", "webui_sample_ref", "solid_view_ref" }, .blocked_authority = &.{ "live-dashboard-host", "app-mutation-button", "react-renderer", "alternate-renderer" } },
    .{ .id = "ci-advisory", .title = "CI advisory state", .evidence_refs = &.{ "ci-advisory-remediation-report-bridge", "ci_artifact_ref", "advisory_status_ref" }, .blocked_authority = &.{ "required-status-check", "ci-enforcement", "workflow-mutation", "github-api-mutation" } },
};

const validation_checks: []const []const u8 = &.{
    "source-bridge-ready",
    "source-authority-disabled",
    "source-bridge-catalog-covered",
    "source-bridge-verification-recorded",
    "preview-panels-covered",
    "preview-sections-covered",
    "audit-chain-comparison-section-present",
    "remediation-review-section-present",
    "runtime-evidence-section-present",
    "agent-query-evidence-section-present",
    "solid-webui-preview-section-present",
    "ci-advisory-section-present",
    "solid-webui-readonly",
    "solidjs-renderer-only",
    "webui-bridge-local-only",
    "hosted-live-dashboard-disabled",
    "app-mutation-controls-disabled",
    "react-renderer-disabled",
    "alternate-renderer-disabled",
    "raw-sensitive-fields-blocked",
    "production-mutation-fields-blocked",
    "auto-apply-disabled",
    "mutation-proof-disabled",
    "production-health-claim-disabled",
    "nendb-write-disabled",
    "nendb-adapter-execution-disabled",
    "durable-write-disabled",
    "deployment-mutation-disabled",
    "ci-enforcement-disabled",
    "cockroach-scope-rejected",
};

const implementation_gates: []const []const u8 = &.{
    "source audit/remediation bridge artifact is ready",
    "source bridge checks and verification commands remain pass",
    "preview emits SolidJS read-only workbench state only",
    "webui bridge remains webui-dev/zig-webui",
    "app mutation controls remain disabled",
    "hosted live dashboard remains disabled",
    "React and alternate renderers remain disabled",
    "NenDB writes and NenDB adapter execution remain disabled",
    "durable writes and deployment mutation remain disabled",
    "CI remains advisory and does not enforce required status checks",
};

const non_goals: []const []const u8 = &.{
    "live app runtime integration",
    "live agent query projection",
    "raw app payload capture",
    "raw prompt or raw response capture",
    "app config writes",
    "app data writes",
    "remediation auto-apply",
    "mutation proof",
    "fixed deployed or healthy app claims",
    "deployment mutation",
    "CI enforcement or required status checks",
    "GitHub API or workflow mutation",
    "NenDB production writes",
    "NenDB adapter execution",
    "durable production writes",
    "non-NenDB durable adapters",
    "Cockroach adapter work",
    "hosted live dashboard",
    "React or alternate renderer work",
    "app mutation buttons",
    "applied=true",
};

const blocked_claims: []const []const u8 = &.{
    "app-runtime-integration-enabled",
    "agent-query-live-projection-enabled",
    "app-mutation-enabled",
    "raw-payload-capture-enabled",
    "raw-prompt-capture-enabled",
    "raw-response-capture-enabled",
    "app-config-write",
    "app-data-write",
    "remediation-auto-apply",
    "mutation-proof-claim",
    "fixed-deployed-healthy-claim",
    "deployment-mutation",
    "durable-production-write-enabled",
    "nendb-write-enabled",
    "nendb-adapter-execution-enabled",
    "non-nendb-durable-storage",
    "cockroach-adapter-work",
    "ci-required-status-check",
    "ci-enforcement",
    "github-api-mutation",
    "hosted-live-dashboard",
    "react-or-alternate-renderer",
    "app-mutation-button",
    "mutation-authority-granted",
    "applied-true",
};

const required_verification_commands: []const []const u8 = &.{
    "bun run zigeffect:workbench:typecheck",
    "bun run zigeffect:workbench:test",
    "zig build causal-app-facing-production-integration-audit-remediation-bridge",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const preview_verified_commands_for_tests: []const []const u8 = required_verification_commands;

const sample_bridge_json =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1",
    \\  "audit_remediation_bridge_status": "ready",
    \\  "decision": "approve",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "audit_remediation_bridge_mode": true,
    \\  "mutation_proof_claim_enabled": false,
    \\  "auto_apply_enabled": false,
    \\  "production_health_claim_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "app_mutation_enabled": false,
    \\  "ci_gate_enabled": false,
    \\  "raw_payload_capture_enabled": false,
    \\  "app_config_write_enabled": false,
    \\  "app_data_write_enabled": false,
    \\  "deployment_mutation_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "nendb_adapter_execution_enabled": false,
    \\  "app_runtime_integration_enabled": false,
    \\  "agent_query_live_projection_enabled": false,
    \\  "solid_webui_preview_enabled": false,
    \\  "source_handoff": "handoff.json",
    \\  "source_boundary": "boundary.json",
    \\  "source_proposal": "proposal.json",
    \\  "source_readiness": "readiness.json",
    \\  "source_fixtures": "fixtures.json",
    \\  "checks": [
    \\    { "name": "bridge-schema", "status": "pass", "detail": "source bridge schema" },
    \\    { "name": "authority-boundary", "status": "pass", "detail": "no mutation authority" }
    \\  ],
    \\  "required_verification_commands": [
    \\    "zig build causal-app-facing-production-integration-nendb-handoff-fixtures"
    \\  ],
    \\  "verified_commands": [
    \\    "zig build causal-app-facing-production-integration-nendb-handoff-fixtures",
    \\    "zig build test"
    \\  ],
    \\  "audit_remediation_bridge_records": [
    \\    { "id": "audit-chain-comparison-review-bridge", "source_handoff_fixture": "nendb-audit-remediation-node-handoff-fixture", "audit_ref": "audit_chain_ref", "remediation_ref": "comparison_ref", "bridge_kind": "audit-chain-comparison", "review_state": "review-only", "retained_refs": ["audit_chain_ref", "comparison_ref"], "blocked_claims": ["mutation-proof"] },
    \\    { "id": "remediation-review-policy-gate-bridge", "source_handoff_fixture": "nendb-audit-remediation-node-handoff-fixture", "audit_ref": "policy_gate_ref", "remediation_ref": "remediation_review_ref", "bridge_kind": "remediation-policy-gate", "review_state": "review-only", "retained_refs": ["remediation_review_ref"], "blocked_claims": ["auto-apply"] },
    \\    { "id": "runtime-to-remediation-evidence-bridge", "source_handoff_fixture": "nendb-runtime-to-audit-remediation-edge-handoff-fixture", "audit_ref": "runtime_trace_ref", "remediation_ref": "remediation_review_ref", "bridge_kind": "runtime-remediation-evidence", "review_state": "review-only", "retained_refs": ["trace_id_ref"], "blocked_claims": ["raw-payload-join"] },
    \\    { "id": "agent-query-to-remediation-next-query-bridge", "source_handoff_fixture": "nendb-runtime-to-agent-query-edge-handoff-fixture", "audit_ref": "agent_query_ref", "remediation_ref": "next_query_refs", "bridge_kind": "agent-query-remediation", "review_state": "review-only", "retained_refs": ["finding_refs", "next_query_refs"], "blocked_claims": ["raw-prompt", "raw-response"] },
    \\    { "id": "solid-webui-review-preview-bridge", "source_handoff_fixture": "nendb-solid-webui-preview-node-handoff-fixture", "audit_ref": "solid_view_ref", "remediation_ref": "review_state_ref", "bridge_kind": "solid-webui-preview", "review_state": "read-only-preview-next", "retained_refs": ["webui_sample_ref", "solid_view_ref"], "blocked_claims": ["react-renderer", "alternate-renderer"] },
    \\    { "id": "ci-advisory-remediation-report-bridge", "source_handoff_fixture": "nendb-ci-advisory-node-handoff-fixture", "audit_ref": "ci_artifact_ref", "remediation_ref": "advisory_status_ref", "bridge_kind": "ci-advisory-report", "review_state": "advisory-only", "retained_refs": ["ci_artifact_ref", "advisory_status_ref"], "blocked_claims": ["required-status-check", "ci-enforcement"] }
    \\  ]
    \\}
;

test "solid webui preview constants define the milestone boundary" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1", schema);
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1", source_schema);
    try std.testing.expectEqualStrings("causal-app-facing-production-integration-solid-webui-readonly-preview", tool_name);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-production-integration-ci-advisory-remediation-report", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report", next_branch_if_ready);
    try std.testing.expectEqualStrings("-solid-webui-readonly-preview", output_suffix);
}

test "solid webui preview options require bridge json decision and reason" {
    try std.testing.expectError(error.MissingFromBridge, parseOptions(std.testing.allocator, &.{"tool"}));
    try std.testing.expectError(error.UnknownFlag, parseOptions(std.testing.allocator, &.{ "tool", "--from-handoff", "bridge.json", "approve", "--reason", "reviewed" }));
    try std.testing.expectError(error.InvalidBridgePath, parseOptions(std.testing.allocator, &.{ "tool", "--from-bridge", "bridge.txt", "approve", "--reason", "reviewed" }));
    try std.testing.expectError(error.MissingDecision, parseOptions(std.testing.allocator, &.{ "tool", "--from-bridge", "bridge.json" }));
    try std.testing.expectError(error.InvalidDecision, parseOptions(std.testing.allocator, &.{ "tool", "--from-bridge", "bridge.json", "maybe", "--reason", "reviewed" }));
    try std.testing.expectError(error.MissingReason, parseOptions(std.testing.allocator, &.{ "tool", "--from-bridge", "bridge.json", "approve" }));
}

test "solid webui preview options parse approval review with verification commands" {
    const parsed = try parseOptions(std.testing.allocator, &.{ "tool", "--from-bridge", "bridge.json", "approve", "--reason", "reviewed", "--verified-command", "bun run zigeffect:workbench:test", "--format", "json" });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("bridge.json", parsed.from_bridge);
    try std.testing.expectEqual(Decision.approve, parsed.decision);
    try std.testing.expectEqualStrings("reviewed", parsed.reason);
    try std.testing.expectEqualStrings("json", parsed.format);
    try std.testing.expectEqual(@as(usize, 1), parsed.verified_commands.len);
    try std.testing.expectEqualStrings("bun run zigeffect:workbench:test", parsed.verified_commands[0]);
}

test "solid webui preview output paths replace source bridge suffix" {
    const paths = try outputPathsForOptions(std.testing.allocator, .{
        .from_bridge = "../../.zig-cache/causal-artifacts/source-audit-remediation-bridge.json",
        .decision = .approve,
        .reason = "reviewed",
    });
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/source-solid-webui-readonly-preview.json", paths.json_path);
    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/source-solid-webui-readonly-preview.txt", paths.text_path);
}

test "solid webui preview ready report preserves read-only SolidJS authority" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .from_bridge = "source-audit-remediation-bridge.json",
            .decision = .approve,
            .reason = "ready app-facing audit remediation bridge reviewed for SolidJS read-only preview",
            .verified_commands = preview_verified_commands_for_tests,
        },
        .source_bridge_json = sample_bridge_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_schema\": \"zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"read_only_preview\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"solid_webui_enabled\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"solid_webui_renderer\": \"solidjs\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"webui_bridge\": \"webui-dev/zig-webui\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"app_mutation_controls_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"hosted_live_dashboard_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"react_renderer_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"alternate_renderer_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "solid-webui-review-preview-bridge") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "solid-webui-preview") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "status: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "solid webui renderer: solidjs") != null);
}

test "solid webui preview reject report remains blocked and authority-disabled" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .from_bridge = "source-audit-remediation-bridge.json",
            .decision = .reject,
            .reason = "negative fixture keeps preview blocked after reviewer rejection",
        },
        .source_bridge_json = sample_bridge_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"app_data_write_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"nendb_adapter_execution_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"auto_apply_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"production_health_claim_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "status: blocked") != null);
}

test "solid webui preview blocks source authority drift" {
    const app_data_write_json = try std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        sample_bridge_json,
        "\"app_data_write_enabled\": false",
        "\"app_data_write_enabled\": true",
    );
    defer std.testing.allocator.free(app_data_write_json);
    try expectPreviewBlockedBy(app_data_write_json, "authority-boundary");

    const preview_enabled_json = try std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        sample_bridge_json,
        "\"solid_webui_preview_enabled\": false",
        "\"solid_webui_preview_enabled\": true",
    );
    defer std.testing.allocator.free(preview_enabled_json);
    try expectPreviewBlockedBy(preview_enabled_json, "authority-boundary");
}

test "solid webui preview evaluator exposes failed source verification command evidence" {
    const missing_command_json = try std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        sample_bridge_json,
        "\"zig build causal-app-facing-production-integration-nendb-handoff-fixtures\",",
        "",
    );
    defer std.testing.allocator.free(missing_command_json);

    try expectPreviewBlockedBy(missing_command_json, "bridge-verification-recorded");
}

test "solid webui preview result helper sees source bridge record catalog" {
    var parsed = try std.json.parseFromSlice(SourceBridgeArtifact, std.testing.allocator, sample_bridge_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const result = try evaluatePreview(std.testing.allocator, .{
        .from_bridge = "source-audit-remediation-bridge.json",
        .decision = .approve,
        .reason = "reviewed",
        .verified_commands = preview_verified_commands_for_tests,
    }, parsed.value);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.ready_for_next_branch);
    try std.testing.expectEqual(PreviewStatus.ready, result.status);
    try std.testing.expect(hasCheck(result.checks, "solid-webui-readonly", .pass));
    try std.testing.expect(hasCheck(result.checks, "webui-bridge-scope", .pass));
    try std.testing.expectEqual(@as(usize, 6), result.bridge_records.len);
}

fn expectPreviewBlockedBy(source_bridge_json: []const u8, check_name: []const u8) !void {
    var parsed = try std.json.parseFromSlice(SourceBridgeArtifact, std.testing.allocator, source_bridge_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const result = try evaluatePreview(std.testing.allocator, .{
        .from_bridge = "source-audit-remediation-bridge.json",
        .decision = .approve,
        .reason = "reviewed",
        .verified_commands = preview_verified_commands_for_tests,
    }, parsed.value);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(PreviewStatus.blocked, result.status);
    try std.testing.expect(hasCheck(result.checks, check_name, .fail));
}
