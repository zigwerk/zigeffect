const std = @import("std");
const fx = @import("zigeffect");

pub const artifact_dir = ".zig-cache/causal-artifacts";
pub const report_path = artifact_dir ++ "/zigeffect-causal-dogfood.txt";
pub const json_path = artifact_dir ++ "/zigeffect-causal-dogfood.json";
pub const dot_path = artifact_dir ++ "/zigeffect-causal-dogfood.dot";
pub const workflow_crash_recovery_report_path = artifact_dir ++ "/zigeffect-causal-workflow-crash-recovery.txt";
pub const workflow_crash_recovery_json_path = artifact_dir ++ "/zigeffect-causal-workflow-crash-recovery.json";
pub const workflow_crash_recovery_dot_path = artifact_dir ++ "/zigeffect-causal-workflow-crash-recovery.dot";

pub const ArtifactSet = struct {
    report_path: []const u8,
    json_path: []const u8,
    dot_path: []const u8,
    report: []const u8,
    json: []const u8,
    dot: []const u8,
    finding_count: usize,

    pub fn deinit(self: ArtifactSet, allocator: std.mem.Allocator) void {
        allocator.free(self.report);
        allocator.free(self.json);
        allocator.free(self.dot);
    }
};

fn recordDogfoodScenario(store: *fx.CausalStore) std.mem.Allocator.Error!void {
    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();
    const run_started = try store.record(.{
        .kind = .run_started,
        .run_id = run_id,
        .label = "zigeffect dogfood",
        .type_name = "DogfoodHarness",
    });
    const scope_opened = try store.record(.{
        .kind = .scope_opened,
        .run_id = run_id,
        .parent_id = run_started,
        .scope_id = scope_id,
        .label = "dogfood scope",
        .status = "opened",
    });
    _ = try store.record(.{
        .kind = .service_required,
        .run_id = run_id,
        .parent_id = scope_opened,
        .label = "Config",
        .type_name = @typeName(fx.Config),
        .status = "missing",
        .redacted_detail = "missing provider for config descriptor",
    });
    _ = try store.record(.{
        .kind = .resource_acquired,
        .run_id = run_id,
        .parent_id = scope_opened,
        .scope_id = scope_id,
        .label = "dogfood database",
        .type_name = "DogfoodDatabaseConnection",
        .status = "success",
        .redacted_detail = "resource intentionally left open by fixture",
    });
    _ = try store.record(.{
        .kind = .fiber_forked,
        .run_id = run_id,
        .parent_id = scope_opened,
        .scope_id = scope_id,
        .fiber_id = 42,
        .label = "dogfood child fiber",
        .status = "pending",
    });
    _ = try store.record(.{
        .kind = .schedule_decision,
        .run_id = run_id,
        .parent_id = run_started,
        .label = "dogfood retry policy",
        .type_name = "Schedule.exponential",
        .status = "exhausted",
        .redacted_detail = "retry budget exhausted after deterministic fixture",
    });
    _ = try store.record(.{
        .kind = .scope_closed,
        .run_id = run_id,
        .parent_id = scope_opened,
        .scope_id = scope_id,
        .label = "dogfood scope",
        .status = "closed",
    });
    _ = try store.record(.{
        .kind = .exit_recorded,
        .run_id = run_id,
        .parent_id = run_started,
        .label = "dogfood exit",
        .type_name = "DogfoodFailure",
        .status = "failure",
        .redacted_detail = "fixture records failure for artifact analysis",
    });
}

fn workflowCrashRecoveryEvents() [6]fx.workflow.WorkflowEvent {
    return .{
        .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .name = "workflow crash recovery",
            .status = "running",
            .idempotency_key = "workflow-crash-start",
        },
        .{
            .sequence = 2,
            .kind = .activity_scheduled,
            .workflow_id = 7,
            .execution_id = 8,
            .parent_sequence = 1,
            .activity_id = 50,
            .attempt = 1,
            .name = "charge-card",
            .status = "scheduled",
            .idempotency_key = "workflow-crash-activity",
        },
        .{
            .sequence = 3,
            .kind = .workflow_suspended,
            .workflow_id = 7,
            .execution_id = 8,
            .parent_sequence = 2,
            .timer_id = 20,
            .name = "wake-after-crash",
            .status = "waiting",
            .redacted_detail = "durable timer persisted before crash",
            .idempotency_key = "workflow-crash-suspend",
        },
        .{
            .sequence = 4,
            .kind = .workflow_resumed,
            .workflow_id = 7,
            .execution_id = 8,
            .parent_sequence = 3,
            .timer_id = 20,
            .name = "wake-after-crash",
            .status = "running",
            .redacted_detail = "journal replay resumed timer wait",
            .idempotency_key = "workflow-crash-resume",
        },
        .{
            .sequence = 5,
            .kind = .activity_retry_scheduled,
            .workflow_id = 7,
            .execution_id = 8,
            .parent_sequence = 4,
            .activity_id = 50,
            .attempt = 2,
            .name = "charge-card",
            .status = "retry",
            .redacted_detail = "attempt=1;delay_ms=250;reason=worker_crash_replay",
            .idempotency_key = "workflow-crash-retry",
        },
        .{
            .sequence = 6,
            .kind = .workflow_failed,
            .workflow_id = 7,
            .execution_id = 8,
            .parent_sequence = 5,
            .name = "workflow crash recovery",
            .status = "failed",
            .redacted_detail = "exit.cause.failure:CrashRecoveryFixture",
            .idempotency_key = "workflow-crash-failed",
        },
    };
}

pub fn buildDogfoodArtifacts(allocator: std.mem.Allocator) std.mem.Allocator.Error!ArtifactSet {
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();

    try recordDogfoodScenario(&store);

    var findings = try store.findings(allocator);
    defer findings.deinit();
    const finding_count = findings.items.len;

    const report = try fx.formatCausalCiReport(allocator, "zigeffect dogfood", &store);
    errdefer allocator.free(report);
    const json = try fx.formatCausalJson(allocator, &store);
    errdefer allocator.free(json);
    const dot = try fx.formatCausalDot(allocator, &store);
    errdefer allocator.free(dot);

    return .{
        .report_path = report_path,
        .json_path = json_path,
        .dot_path = dot_path,
        .report = report,
        .json = json,
        .dot = dot,
        .finding_count = finding_count,
    };
}

pub fn buildWorkflowCrashRecoveryArtifacts(allocator: std.mem.Allocator) std.mem.Allocator.Error!ArtifactSet {
    const events = workflowCrashRecoveryEvents();

    var store = try fx.workflow.buildWorkflowCausalStore(allocator, &events);
    defer store.deinit();

    var findings = try fx.workflow.collectWorkflowCausalFindings(allocator, &store);
    defer findings.deinit();
    const finding_count = findings.items.len;

    const causal_report = try fx.workflow.formatWorkflowCausalReport(allocator, &events);
    defer allocator.free(causal_report);
    const report = try std.fmt.allocPrint(allocator, "workflow crash recovery\n{s}", .{causal_report});
    errdefer allocator.free(report);
    const json = try fx.workflow.formatWorkflowCausalJson(allocator, &events);
    errdefer allocator.free(json);
    const dot = try fx.workflow.formatWorkflowCausalDot(allocator, &events);
    errdefer allocator.free(dot);

    return .{
        .report_path = workflow_crash_recovery_report_path,
        .json_path = workflow_crash_recovery_json_path,
        .dot_path = workflow_crash_recovery_dot_path,
        .report = report,
        .json = json,
        .dot = dot,
        .finding_count = finding_count,
    };
}

pub fn exitCodeForFindings(finding_count: usize, fail_on_findings: bool) u8 {
    if (fail_on_findings and finding_count > 0) return 1;
    return 0;
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

fn writeArtifacts(io: std.Io, artifacts: ArtifactSet) !void {
    try writeArtifact(io, artifacts.report_path, artifacts.report);
    try writeArtifact(io, artifacts.json_path, artifacts.json);
    try writeArtifact(io, artifacts.dot_path, artifacts.dot);
}

fn usage() []const u8 {
    return "usage: zig build causal-test -- [--fail-on-findings]\n       zig build causal-check\n";
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    var fail_on_findings = false;
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--fail-on-findings")) {
            fail_on_findings = true;
        } else {
            std.debug.print("causal-test error: unknown argument '{s}'\n{s}", .{ arg, usage() });
            std.process.exit(2);
        }
    }

    const artifacts = try buildDogfoodArtifacts(allocator);
    defer artifacts.deinit(allocator);
    const workflow_artifacts = try buildWorkflowCrashRecoveryArtifacts(allocator);
    defer workflow_artifacts.deinit(allocator);

    try writeArtifacts(init.io, artifacts);
    try writeArtifacts(init.io, workflow_artifacts);

    const total_finding_count = artifacts.finding_count + workflow_artifacts.finding_count;
    std.debug.print(
        "zigeffect causal dogfood artifacts written:\n- {s}\n- {s}\n- {s}\n- {s}\n- {s}\n- {s}\nfindings: {d}\n",
        .{
            artifacts.report_path,
            artifacts.json_path,
            artifacts.dot_path,
            workflow_artifacts.report_path,
            workflow_artifacts.json_path,
            workflow_artifacts.dot_path,
            total_finding_count,
        },
    );

    const exit_code = exitCodeForFindings(total_finding_count, fail_on_findings);
    if (exit_code != 0) {
        std.debug.print("causal dogfood check failed: {d} findings detected\n", .{total_finding_count});
        std.process.exit(exit_code);
    }
}

test "dogfood artifacts include report json dot and stable paths" {
    const artifacts = try buildDogfoodArtifacts(std.testing.allocator);
    defer artifacts.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), artifacts.finding_count);
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.txt",
        artifacts.report_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
        artifacts.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.dot",
        artifacts.dot_path,
    );
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "zigeffect causal ci report") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "program: zigeffect dogfood") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "findings: 4") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "causal.requirements") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "causal.resources") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "causal.fibers pending") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "causal.retries") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.json, "\"kind\": \"service_required\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.json, "\"kind\": \"resource_acquired\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.dot, "digraph zigeffect_causal") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.dot, "event_1 -> event_2") != null);
}

test "workflow crash recovery artifacts include causal report json dot and findings" {
    const artifacts = try buildWorkflowCrashRecoveryArtifacts(std.testing.allocator);
    defer artifacts.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), artifacts.finding_count);
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-workflow-crash-recovery.txt",
        artifacts.report_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-workflow-crash-recovery.json",
        artifacts.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-workflow-crash-recovery.dot",
        artifacts.dot_path,
    );
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "workflow crash recovery") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "workflow_failure") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "workflow_retry_scheduled") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.json, "\"kind\": \"workflow_event_recorded\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.dot, "workflow.workflow_suspended") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.dot, "workflow.workflow_resumed") != null);
}

test "fail-on-findings mode exits nonzero only when findings exist" {
    try std.testing.expectEqual(@as(u8, 0), exitCodeForFindings(0, false));
    try std.testing.expectEqual(@as(u8, 0), exitCodeForFindings(4, false));
    try std.testing.expectEqual(@as(u8, 0), exitCodeForFindings(0, true));
    try std.testing.expectEqual(@as(u8, 1), exitCodeForFindings(4, true));
}
