const std = @import("std");
const causal_run = @import("causal_run");

pub fn formatArtifactManifest(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal artifact manifest\n");
    try output.print(allocator, "artifact dir: {s}\n", .{causal_run.artifact_dir});
    try output.appendSlice(allocator, "retention: upload causal artifacts on failed causal checks and after-phase dev loops\n");

    try output.appendSlice(allocator, "\nci upload globs:\n");
    try output.print(allocator, "- {s}/*.txt\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- {s}/*.json\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- {s}/*.dot\n", .{causal_run.artifact_dir});

    try output.appendSlice(allocator, "\ndefault artifacts:\n");
    try appendDogfoodArtifacts(&output, allocator);
    try appendDefaultLoopArtifacts(&output, allocator);

    try output.appendSlice(allocator, "\nscenario artifacts:\n");
    for (causal_run.scenarioRegistry()) |scenario| {
        const paths = try causal_run.artifactPaths(allocator, scenario.slug);
        defer paths.deinit(allocator);

        try output.print(allocator, "- scenario {s}\n", .{scenario.slug});
        try output.print(allocator, "  label: {s}\n", .{scenario.label});
        try output.print(allocator, "  expectation: {s}\n", .{@tagName(scenario.expectation)});
        try output.print(allocator, "  report: {s}\n", .{paths.report_path});
        try output.print(allocator, "  json: {s}\n", .{paths.json_path});
        try output.print(allocator, "  dot: {s}\n", .{paths.dot_path});
        try appendScenarioLoopArtifacts(&output, allocator, scenario.slug);
    }

    try output.appendSlice(allocator, "\nsafety notes:\n");
    try output.appendSlice(allocator, "- artifacts are redacted and bounded, but review before public upload\n");
    try output.appendSlice(allocator, "- upload only causal artifact globs; do not upload the rest of .zig-cache\n");
    try output.appendSlice(allocator, "- prefer txt for human triage, json for agent queries, and dot for graph visualization\n");

    return output.toOwnedSlice(allocator);
}

pub fn main(init: std.process.Init) !void {
    const manifest = try formatArtifactManifest(init.gpa);
    defer init.gpa.free(manifest);
    std.debug.print("{s}", .{manifest});
}

fn appendDogfoodArtifacts(output: *std.ArrayList(u8), allocator: std.mem.Allocator) std.mem.Allocator.Error!void {
    try output.print(allocator, "- dogfood report {s}/zigeffect-causal-dogfood.txt\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dogfood json {s}/zigeffect-causal-dogfood.json\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dogfood dot {s}/zigeffect-causal-dogfood.dot\n", .{causal_run.artifact_dir});
}

fn appendDefaultLoopArtifacts(output: *std.ArrayList(u8), allocator: std.mem.Allocator) std.mem.Allocator.Error!void {
    try output.print(allocator, "- ci baseline dogfood {s}/zigeffect-causal-ci-baseline-dogfood.json\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- ci baseline package-tests {s}/zigeffect-causal-ci-baseline-package-tests.json\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop before {s}/zigeffect-causal-dev-loop-before.json\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop after {s}/zigeffect-causal-dev-loop-after.json\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop compare {s}/zigeffect-causal-dev-loop-compare.txt\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop queries {s}/zigeffect-causal-dev-loop-queries.txt\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop advice {s}/zigeffect-causal-dev-loop-advice.txt\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop verdict {s}/zigeffect-causal-dev-loop-verdict.json\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop diagnosis {s}/zigeffect-causal-dev-loop-diagnosis.txt\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop remediation plan {s}/zigeffect-causal-dev-loop-remediation-plan.md\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop remediation audit json {s}/zigeffect-causal-dev-loop-remediation-audit.json\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop remediation audit text {s}/zigeffect-causal-dev-loop-remediation-audit.txt\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop remediation decision json {s}/zigeffect-causal-dev-loop-remediation-decision.json\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop remediation decision text {s}/zigeffect-causal-dev-loop-remediation-decision.txt\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop patch proposal json {s}/zigeffect-causal-dev-loop-patch-proposal.json\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop patch proposal text {s}/zigeffect-causal-dev-loop-patch-proposal.txt\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop audit chain json {s}/zigeffect-causal-dev-loop-audit-chain.json\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop audit chain text {s}/zigeffect-causal-dev-loop-audit-chain.txt\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop scenario proposal json {s}/zigeffect-causal-dev-loop-scenario-proposal.json\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop scenario proposal text {s}/zigeffect-causal-dev-loop-scenario-proposal.txt\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop registry patch json {s}/zigeffect-causal-dev-loop-registry-patch.json\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop registry patch text {s}/zigeffect-causal-dev-loop-registry-patch.txt\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop registry patch zig {s}/zigeffect-causal-dev-loop-registry-patch.zig\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop registry application readiness json {s}/zigeffect-causal-dev-loop-registry-application-readiness.json\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop registry application readiness text {s}/zigeffect-causal-dev-loop-registry-application-readiness.txt\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev session json {s}/zigeffect-causal-dev-session.json\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev session text {s}/zigeffect-causal-dev-session.txt\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- ci handoff {s}/zigeffect-causal-ci-handoff.txt\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- ci verdict {s}/zigeffect-causal-ci-verdict.json\n", .{causal_run.artifact_dir});
}

fn appendScenarioLoopArtifacts(output: *std.ArrayList(u8), allocator: std.mem.Allocator, slug: []const u8) std.mem.Allocator.Error!void {
    try output.print(allocator, "  loop before: {s}/zigeffect-causal-dev-loop-{s}-before.json\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop after: {s}/zigeffect-causal-dev-loop-{s}-after.json\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop compare: {s}/zigeffect-causal-dev-loop-{s}-compare.txt\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop queries: {s}/zigeffect-causal-dev-loop-{s}-queries.txt\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop advice: {s}/zigeffect-causal-dev-loop-{s}-advice.txt\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop verdict: {s}/zigeffect-causal-dev-loop-{s}-verdict.json\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop diagnosis: {s}/zigeffect-causal-dev-loop-{s}-diagnosis.txt\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop remediation plan: {s}/zigeffect-causal-dev-loop-{s}-remediation-plan.md\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop remediation audit json: {s}/zigeffect-causal-dev-loop-{s}-remediation-audit.json\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop remediation audit text: {s}/zigeffect-causal-dev-loop-{s}-remediation-audit.txt\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop remediation decision json: {s}/zigeffect-causal-dev-loop-{s}-remediation-decision.json\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop remediation decision text: {s}/zigeffect-causal-dev-loop-{s}-remediation-decision.txt\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop patch proposal json: {s}/zigeffect-causal-dev-loop-{s}-patch-proposal.json\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop patch proposal text: {s}/zigeffect-causal-dev-loop-{s}-patch-proposal.txt\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop audit chain json: {s}/zigeffect-causal-dev-loop-{s}-audit-chain.json\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop audit chain text: {s}/zigeffect-causal-dev-loop-{s}-audit-chain.txt\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop scenario proposal json: {s}/zigeffect-causal-dev-loop-{s}-scenario-proposal.json\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop scenario proposal text: {s}/zigeffect-causal-dev-loop-{s}-scenario-proposal.txt\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop registry patch json: {s}/zigeffect-causal-dev-loop-{s}-registry-patch.json\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop registry patch text: {s}/zigeffect-causal-dev-loop-{s}-registry-patch.txt\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop registry patch zig: {s}/zigeffect-causal-dev-loop-{s}-registry-patch.zig\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop registry application readiness json: {s}/zigeffect-causal-dev-loop-{s}-registry-application-readiness.json\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop registry application readiness text: {s}/zigeffect-causal-dev-loop-{s}-registry-application-readiness.txt\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  dev session json: {s}/zigeffect-causal-dev-session-{s}.json\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  dev session text: {s}/zigeffect-causal-dev-session-{s}.txt\n", .{ causal_run.artifact_dir, slug });
}

test "artifact manifest lists CI upload globs and default artifacts" {
    const manifest = try formatArtifactManifest(std.testing.allocator);
    defer std.testing.allocator.free(manifest);

    try std.testing.expect(std.mem.indexOf(u8, manifest, "zigeffect causal artifact manifest") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "artifact dir: .zig-cache/causal-artifacts") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/*.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/*.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/*.dot") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-dogfood.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-package-tests.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-audit-chain.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-audit-chain.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.zig") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-session.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-session.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-ci-handoff.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-ci-verdict.json") != null);
}

test "artifact manifest lists scenario and scenario loop artifacts" {
    const manifest = try formatArtifactManifest(std.testing.allocator);
    defer std.testing.allocator.free(manifest);

    try std.testing.expect(std.mem.indexOf(u8, manifest, "scenario package-tests") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-package-tests.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-advice.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-verdict.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-diagnosis.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-remediation-plan.md") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-remediation-audit.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-remediation-audit.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-remediation-decision.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-remediation-decision.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-patch-proposal.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-patch-proposal.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-audit-chain.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-audit-chain.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-scenario-proposal.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-scenario-proposal.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-registry-patch.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-registry-patch.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-registry-patch.zig") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-registry-application-readiness.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-registry-application-readiness.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-session-causal-scoped-fiber.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-session-causal-scoped-fiber.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "review before public upload") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "do not upload the rest of .zig-cache") != null);
}
