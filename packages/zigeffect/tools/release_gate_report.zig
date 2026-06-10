const std = @import("std");

pub const release_gate_schema = "zigeffect.release-gate.v1";
pub const release_gate_schema_version: u32 = 1;
pub const release_gate_artifact_dir = ".zig-cache/release-gate";
pub const release_gate_text_path = release_gate_artifact_dir ++ "/zigeffect-release-gate.txt";
pub const release_gate_json_path = release_gate_artifact_dir ++ "/zigeffect-release-gate.json";

const migration_doc_path = "docs/migration-to-durable-runtime.md";
const completion_report_path = "../../docs/superpowers/reports/2026-06-10-zigeffect-milestone-46-completion.md";
const workflow_crash_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-workflow-crash-recovery.txt";
const workflow_crash_json_path = ".zig-cache/causal-artifacts/zigeffect-causal-workflow-crash-recovery.json";
const workflow_crash_dot_path = ".zig-cache/causal-artifacts/zigeffect-causal-workflow-crash-recovery.dot";

const release_gate_text =
    \\zigeffect release gate
    \\schema: zigeffect.release-gate.v1
    \\schema_version: 1
    \\command: zig build release-gate
    \\
    \\included gates:
    \\- zig build test
    \\- zig build public-api-review
    \\- zig build storage-conformance
    \\- zig build property-crash
    \\- zig build performance-bounds
    \\- zig build examples
    \\- zig build causal-test
    \\- zig build release-gate-report
    \\
    \\acceptance proofs:
    \\- durable workflow crash recovery example: examples/workflow_crash_recovery.zig
    \\- multi-runner cluster migration example: examples/cluster_workflow_migration.zig
    \\- multi-runner cluster routing example: examples/multi_runner_cluster.zig
    \\
    \\artifact paths:
    \\- .zig-cache/release-gate/zigeffect-release-gate.txt
    \\- .zig-cache/release-gate/zigeffect-release-gate.json
    \\- .zig-cache/causal-artifacts/zigeffect-causal-workflow-crash-recovery.txt
    \\- .zig-cache/causal-artifacts/zigeffect-causal-workflow-crash-recovery.json
    \\- .zig-cache/causal-artifacts/zigeffect-causal-workflow-crash-recovery.dot
    \\
    \\docs:
    \\- docs/migration-to-durable-runtime.md
    \\- ../../docs/superpowers/reports/2026-06-10-zigeffect-milestone-46-completion.md
    \\
;

const release_gate_json =
    \\{
    \\  "schema": "zigeffect.release-gate.v1",
    \\  "schema_version": 1,
    \\  "command": "zig build release-gate",
    \\  "included_gates": [
    \\    "zig build test",
    \\    "zig build public-api-review",
    \\    "zig build storage-conformance",
    \\    "zig build property-crash",
    \\    "zig build performance-bounds",
    \\    "zig build examples",
    \\    "zig build causal-test",
    \\    "zig build release-gate-report"
    \\  ],
    \\  "acceptance_proofs": [
    \\    "durable workflow crash recovery example",
    \\    "multi-runner cluster migration example",
    \\    "multi-runner cluster routing example"
    \\  ],
    \\  "artifacts": {
    \\    "release_gate_text": ".zig-cache/release-gate/zigeffect-release-gate.txt",
    \\    "release_gate_json": ".zig-cache/release-gate/zigeffect-release-gate.json",
    \\    "workflow_crash_recovery_text": ".zig-cache/causal-artifacts/zigeffect-causal-workflow-crash-recovery.txt",
    \\    "workflow_crash_recovery_json": ".zig-cache/causal-artifacts/zigeffect-causal-workflow-crash-recovery.json",
    \\    "workflow_crash_recovery_dot": ".zig-cache/causal-artifacts/zigeffect-causal-workflow-crash-recovery.dot"
    \\  },
    \\  "docs": {
    \\    "migration": "docs/migration-to-durable-runtime.md",
    \\    "completion_report": "../../docs/superpowers/reports/2026-06-10-zigeffect-milestone-46-completion.md"
    \\  }
    \\}
    \\
;

pub fn formatReleaseGateText(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    return allocator.dupe(u8, release_gate_text);
}

pub fn formatReleaseGateJson(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    return allocator.dupe(u8, release_gate_json);
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

pub fn main(init: std.process.Init) !void {
    const text = try formatReleaseGateText(init.gpa);
    defer init.gpa.free(text);
    const json = try formatReleaseGateJson(init.gpa);
    defer init.gpa.free(json);

    try writeArtifact(init.io, release_gate_text_path, text);
    try writeArtifact(init.io, release_gate_json_path, json);

    std.debug.print(
        "zigeffect release gate reports written:\n- {s}\n- {s}\n",
        .{ release_gate_text_path, release_gate_json_path },
    );
}

test "release gate text report lists command gates proofs and artifacts" {
    const report = try formatReleaseGateText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, release_gate_schema) != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "command: zig build release-gate") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build storage-conformance") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "durable workflow crash recovery example") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "multi-runner cluster migration example") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, release_gate_text_path) != null);
    try std.testing.expect(std.mem.indexOf(u8, report, workflow_crash_report_path) != null);
    try std.testing.expect(std.mem.indexOf(u8, report, workflow_crash_json_path) != null);
    try std.testing.expect(std.mem.indexOf(u8, report, workflow_crash_dot_path) != null);
    try std.testing.expect(std.mem.indexOf(u8, report, migration_doc_path) != null);
    try std.testing.expect(std.mem.indexOf(u8, report, completion_report_path) != null);
}

test "release gate json report has stable schema and paths" {
    const report = try formatReleaseGateJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.release-gate.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema_version\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"command\": \"zig build release-gate\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"release_gate_json\": \".zig-cache/release-gate/zigeffect-release-gate.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"workflow_crash_recovery_json\": \".zig-cache/causal-artifacts/zigeffect-causal-workflow-crash-recovery.json\"") != null);
}
