const std = @import("std");
const causal_artifact = @import("causal_artifact");
const causal_run = @import("causal_run");

pub const snapshot_manifest_schema = "zigeffect.causal.snapshot-manifest.v1";
pub const snapshot_manifest_schema_version: u32 = 1;

const sample_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"baseline","type_name":"Command","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"service_required","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"Config","status":"missing","redacted_detail":"missing provider"},
    \\    {"id":3,"kind":"schedule_decision","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"retry","type_name":"Schedule.exponential","status":"exhausted","redacted_detail":"budget exhausted"}
    \\  ]
    \\}
;

const future_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 2,
    \\  "event_taxonomy_version": 3,
    \\  "events": [
    \\    {"id":4,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"future","type_name":"Command","status":"started","redacted_detail":""},
    \\    {"id":5,"kind":"effect_suspended","run_id":1,"parent_id":4,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"future event","type_name":"Command","status":"pending","redacted_detail":""}
    \\  ]
    \\}
;

test "snapshot manifest json names artifact and derived event metadata" {
    const manifest = try formatSnapshotManifestJson(std.testing.allocator, sample_json, .{
        .name = "baseline",
        .target = "dogfood",
        .phase = "baseline",
        .artifact_path = ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
    });
    defer std.testing.allocator.free(manifest);

    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"schema\":\"zigeffect.causal.snapshot-manifest.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"name\":\"baseline\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"target\":\"dogfood\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"phase\":\"baseline\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"events\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"first_event_id\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"last_event_id\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"findings\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"feasible\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json snapshot") != null);
}

test "snapshot manifest text includes replay posture and next query" {
    const report = try formatSnapshotManifestText(std.testing.allocator, sample_json, .{
        .name = "after",
        .target = "package-tests",
        .phase = "after",
        .artifact_path = ".zig-cache/causal-artifacts/zigeffect-causal-package-tests.json",
        .baseline_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-before.json",
        .compare_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-compare.txt",
    });
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal snapshot manifest") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "name: after") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "target: package-tests") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "baseline: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-before.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "compare report: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-compare.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "replay feasible: false") != null);
}

test "snapshot manifest warns for future artifact shape and unknown event kind" {
    const manifest = try formatSnapshotManifestJson(std.testing.allocator, future_json, .{
        .name = "future",
        .artifact_path = ".zig-cache/causal-artifacts/future.json",
    });
    defer std.testing.allocator.free(manifest);

    try std.testing.expect(std.mem.indexOf(u8, manifest, "schema_version=2 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "event_taxonomy_version=3 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "event kind effect_suspended unknown") != null);
}

test "snapshot names validate before path formatting" {
    try validateSnapshotName("baseline");
    try validateSnapshotName("after_1");
    try std.testing.expectError(error.InvalidSnapshotName, validateSnapshotName(""));
    try std.testing.expectError(error.InvalidSnapshotName, validateSnapshotName("../oops"));
    try std.testing.expectError(error.InvalidSnapshotName, validateSnapshotName("bad name"));
}

test "snapshot manifest paths are deterministic" {
    const paths = try snapshotManifestPaths(std.testing.allocator, "baseline");
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json", paths.json_path);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.txt", paths.text_path);
}
