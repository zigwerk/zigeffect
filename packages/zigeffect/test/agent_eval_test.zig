const std = @import("std");
const fx = @import("zigeffect");

const baseline = [_]fx.CausalEvent{
    .{ .id = 1, .kind = .run_started, .run_id = 1, .status = "started" },
    .{ .id = 2, .kind = .fiber_suspended, .run_id = 1, .fiber_id = 9, .status = "suspended", .label = "await io" },
};

test "agent eval passes when intervention improves findings and satisfies invariants" {
    const policy = (fx.AgentInterventionPolicy{})
        .withApplyEnabled(true)
        .withKindPolicy(.interrupt_fiber, .auto_approve);
    const invariants = fx.CausalInvariantBuilder.init().requireSuspendedFibersResolve();

    const result = try fx.runAgentEval(std.testing.allocator, .{
        .name = "interrupt hung fiber",
        .baseline = &baseline,
        .policy = policy,
        .request = .{
            .kind = .interrupt_fiber,
            .run_id = 1,
            .fiber_id = 9,
            .reason = "eval interrupt",
        },
        .invariants = invariants,
        .expect_improvement = true,
    });

    try std.testing.expect(result.passed);
    try std.testing.expect(result.counterfactual.improved);
    try std.testing.expectEqual(@as(usize, 1), result.diff_summary.resolved_findings);
    try std.testing.expectEqual(@as(usize, 0), result.invariant_violations);
}

test "agent eval fails when policy leaves the intervention record-only" {
    const invariants = fx.CausalInvariantBuilder.init().requireSuspendedFibersResolve();

    const result = try fx.runAgentEval(std.testing.allocator, .{
        .name = "denied interrupt",
        .baseline = &baseline,
        .policy = .{},
        .request = .{
            .kind = .interrupt_fiber,
            .run_id = 1,
            .fiber_id = 9,
            .reason = "eval interrupt",
        },
        .invariants = invariants,
        .expect_improvement = true,
    });

    try std.testing.expect(!result.passed);
    try std.testing.expect(!result.counterfactual.intervention.applied);
}

test "agent eval emits semantic diff artifact linked to remediation events" {
    const policy = (fx.AgentInterventionPolicy{})
        .withApplyEnabled(true)
        .withKindPolicy(.interrupt_fiber, .auto_approve);
    const invariants = fx.CausalInvariantBuilder.init().requireSuspendedFibersResolve();

    var artifact = try fx.runAgentEvalWithDiffArtifact(std.testing.allocator, .{
        .name = "interrupt hung fiber",
        .baseline = &baseline,
        .policy = policy,
        .request = .{
            .kind = .interrupt_fiber,
            .run_id = 1,
            .fiber_id = 9,
            .reason = "eval interrupt",
        },
        .invariants = invariants,
        .expect_improvement = true,
    }, "baseline", "after-interrupt");
    defer artifact.deinit();

    try std.testing.expect(artifact.result.passed);
    try std.testing.expect(std.mem.indexOf(u8, artifact.json, "\"schema\":\"zigeffect.causal.agent-eval-diff.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifact.json, "\"semantic_diff\":{\"schema\":\"zigeffect.causal.semantic-diff.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifact.json, "\"resolved_findings\":1") != null);

    var requested_buf: [64]u8 = undefined;
    const requested = try std.fmt.bufPrint(&requested_buf, "\"requested\":{d}", .{artifact.result.counterfactual.intervention.requested_event_id.?});
    try std.testing.expect(std.mem.indexOf(u8, artifact.json, requested) != null);
}

const EvalArtifactCapture = struct {
    writes: usize = 0,
    saw_schema: bool = false,
    saw_semantic_diff: bool = false,

    fn sink(self: *EvalArtifactCapture) fx.AgentEvalDiffArtifactSink {
        return .{
            .state = self,
            .write = write,
        };
    }

    fn write(raw: ?*anyopaque, json: []const u8) anyerror!void {
        const self: *EvalArtifactCapture = @ptrCast(@alignCast(raw.?));
        self.writes += 1;
        self.saw_schema = std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.causal.agent-eval-diff.v1\"") != null;
        self.saw_semantic_diff = std.mem.indexOf(u8, json, "\"semantic_diff\":{\"schema\":\"zigeffect.causal.semantic-diff.v1\"") != null;
    }
};

test "agent eval writes semantic diff artifact to caller sink" {
    const policy = (fx.AgentInterventionPolicy{})
        .withApplyEnabled(true)
        .withKindPolicy(.interrupt_fiber, .auto_approve);
    const invariants = fx.CausalInvariantBuilder.init().requireSuspendedFibersResolve();
    var capture = EvalArtifactCapture{};

    const result = try fx.runAgentEvalAndWriteDiffArtifact(std.testing.allocator, .{
        .name = "interrupt hung fiber",
        .baseline = &baseline,
        .policy = policy,
        .request = .{
            .kind = .interrupt_fiber,
            .run_id = 1,
            .fiber_id = 9,
            .reason = "eval interrupt",
        },
        .invariants = invariants,
        .expect_improvement = true,
    }, "baseline", "after-interrupt", capture.sink());

    try std.testing.expect(result.passed);
    try std.testing.expectEqual(@as(usize, 1), capture.writes);
    try std.testing.expect(capture.saw_schema);
    try std.testing.expect(capture.saw_semantic_diff);
}

test "agent eval formats diff artifact link for remediation chains" {
    const policy = (fx.AgentInterventionPolicy{})
        .withApplyEnabled(true)
        .withKindPolicy(.interrupt_fiber, .auto_approve);
    const invariants = fx.CausalInvariantBuilder.init().requireSuspendedFibersResolve();

    var artifact = try fx.runAgentEvalWithDiffArtifact(std.testing.allocator, .{
        .name = "interrupt hung fiber",
        .baseline = &baseline,
        .policy = policy,
        .request = .{
            .kind = .interrupt_fiber,
            .run_id = 1,
            .fiber_id = 9,
            .reason = "eval interrupt",
        },
        .invariants = invariants,
        .expect_improvement = true,
    }, "baseline", "after-interrupt");
    defer artifact.deinit();

    const link = try fx.formatAgentEvalDiffArtifactLinkJson(std.testing.allocator, .{
        .eval_name = "interrupt hung fiber",
        .artifact_path = ".zig-cache/causal-artifacts/eval-diff.json",
        .result = artifact.result,
    });
    defer std.testing.allocator.free(link);

    try std.testing.expect(std.mem.indexOf(u8, link, "\"schema\":\"zigeffect.causal.agent-eval-diff-link.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, link, "\"artifact_path\":\".zig-cache/causal-artifacts/eval-diff.json\"") != null);
    var requested_buf: [64]u8 = undefined;
    const requested = try std.fmt.bufPrint(&requested_buf, "\"requested\":{d}", .{artifact.result.counterfactual.intervention.requested_event_id.?});
    try std.testing.expect(std.mem.indexOf(u8, link, requested) != null);
}

const LinkedEvalArtifactCapture = struct {
    artifact_writes: usize = 0,
    link_writes: usize = 0,
    saw_artifact_schema: bool = false,
    saw_link_schema: bool = false,
    saw_requested_event_id: bool = false,

    fn artifactSink(self: *LinkedEvalArtifactCapture) fx.AgentEvalDiffArtifactSink {
        return .{
            .state = self,
            .write = writeArtifact,
        };
    }

    fn linkSink(self: *LinkedEvalArtifactCapture) fx.AgentEvalDiffArtifactSink {
        return .{
            .state = self,
            .write = writeLink,
        };
    }

    fn writeArtifact(raw: ?*anyopaque, json: []const u8) anyerror!void {
        const self: *LinkedEvalArtifactCapture = @ptrCast(@alignCast(raw.?));
        self.artifact_writes += 1;
        self.saw_artifact_schema = std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.causal.agent-eval-diff.v1\"") != null;
    }

    fn writeLink(raw: ?*anyopaque, json: []const u8) anyerror!void {
        const self: *LinkedEvalArtifactCapture = @ptrCast(@alignCast(raw.?));
        self.link_writes += 1;
        self.saw_link_schema = std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.causal.agent-eval-diff-link.v1\"") != null;
        self.saw_requested_event_id = std.mem.indexOf(u8, json, "\"requested\":") != null and
            std.mem.indexOf(u8, json, "\"artifact_path\":\".zig-cache/causal-artifacts/eval-diff.json\"") != null;
    }
};

test "agent eval writes diff artifact and remediation link to caller sinks" {
    const policy = (fx.AgentInterventionPolicy{})
        .withApplyEnabled(true)
        .withKindPolicy(.interrupt_fiber, .auto_approve);
    const invariants = fx.CausalInvariantBuilder.init().requireSuspendedFibersResolve();
    var capture = LinkedEvalArtifactCapture{};

    const result = try fx.runAgentEvalAndWriteLinkedDiffArtifact(std.testing.allocator, .{
        .name = "interrupt hung fiber",
        .baseline = &baseline,
        .policy = policy,
        .request = .{
            .kind = .interrupt_fiber,
            .run_id = 1,
            .fiber_id = 9,
            .reason = "eval interrupt",
        },
        .invariants = invariants,
        .expect_improvement = true,
    }, "baseline", "after-interrupt", .{
        .artifact_path = ".zig-cache/causal-artifacts/eval-diff.json",
    }, capture.artifactSink(), capture.linkSink());

    try std.testing.expect(result.passed);
    try std.testing.expectEqual(@as(usize, 1), capture.artifact_writes);
    try std.testing.expectEqual(@as(usize, 1), capture.link_writes);
    try std.testing.expect(capture.saw_artifact_schema);
    try std.testing.expect(capture.saw_link_schema);
    try std.testing.expect(capture.saw_requested_event_id);
}

test "agent eval formats linked diff artifact manifest" {
    const policy = (fx.AgentInterventionPolicy{})
        .withApplyEnabled(true)
        .withKindPolicy(.interrupt_fiber, .auto_approve);
    const invariants = fx.CausalInvariantBuilder.init().requireSuspendedFibersResolve();

    const result = try fx.runAgentEval(std.testing.allocator, .{
        .name = "interrupt hung fiber",
        .baseline = &baseline,
        .policy = policy,
        .request = .{
            .kind = .interrupt_fiber,
            .run_id = 1,
            .fiber_id = 9,
            .reason = "eval interrupt",
        },
        .invariants = invariants,
        .expect_improvement = true,
    });

    const manifest = try fx.formatAgentEvalLinkedDiffManifestJson(std.testing.allocator, .{
        .eval_name = "interrupt hung fiber",
        .diff_artifact_path = ".zig-cache/causal-artifacts/eval-diff.json",
        .link_artifact_path = ".zig-cache/causal-artifacts/eval-link.json",
        .result = result,
    });
    defer std.testing.allocator.free(manifest);

    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"schema\":\"zigeffect.causal.agent-eval-linked-manifest.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"diff_artifact_path\":\".zig-cache/causal-artifacts/eval-diff.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"link_artifact_path\":\".zig-cache/causal-artifacts/eval-link.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"requested\":") != null);
}
