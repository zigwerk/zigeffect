const std = @import("std");
const zstd = @import("zigeffect_std");

const Development = zstd.Development;

fn manifest() zstd.Project.Manifest {
    return .{
        .name = "proof-app",
        .kind = .application,
        .components = &.{.{ .id = "proof-app", .kind = .application, .path = "." }},
        .commands = &.{.{ .id = "test", .argv = &.{ "zig", "build", "test" } }},
        .requirements = &.{
            .{ .id = "req-one", .summary = "first requirement", .component = "proof-app", .status = .active },
            .{ .id = "req-two", .summary = "second requirement", .component = "proof-app", .status = .active },
        },
        .acceptance_checks = &.{
            .{ .id = "check-one", .requirement = "req-one", .command = "test", .expectation = "one passes", .status = .pending },
            .{ .id = "check-two", .requirement = "req-two", .command = "test", .expectation = "two passes", .status = .pending },
        },
        .test_scenarios = &.{
            .{ .id = "scenario-one", .label = "scenario one", .requirement = "req-one", .acceptance_check = "check-one", .component = "proof-app", .command = "test", .source_roots = &.{"src/one.zig"} },
            .{ .id = "scenario-two", .label = "scenario two", .requirement = "req-two", .acceptance_check = "check-two", .component = "proof-app", .command = "test", .source_roots = &.{"src/two.zig"} },
        },
    };
}

const passed_assertions = [_]zstd.Testing.AssertionResult{.{ .id = "acceptance-proof", .label = "acceptance proof", .status = .passed }};
const failed_assertions = [_]zstd.Testing.AssertionResult{.{ .id = "acceptance-proof", .label = "acceptance proof", .status = .failed }};

fn receipt(project_scenario: zstd.Project.TestScenario, source_revision: []const u8, manifest_digest: []const u8, status: zstd.Testing.TestStatus) zstd.Testing.TestReceipt {
    return .{
        .project = "proof-app",
        .suite = "acceptance",
        .scenario = .{
            .id = project_scenario.id,
            .label = project_scenario.label,
            .requirement = project_scenario.requirement,
            .acceptance_check = project_scenario.acceptance_check,
            .component = project_scenario.component,
            .command = project_scenario.command,
            .source_roots = project_scenario.source_roots,
            .tags = project_scenario.tags,
            .default_seed = project_scenario.default_seed,
            .fault_profile = switch (project_scenario.fault_profile) {
                .none => .none,
                .standard => .standard,
                .exhaustive => .exhaustive,
                .allocation => .allocation,
                .schedule => .schedule,
                .recovery => .recovery,
                .executor => .executor,
            },
            .required = project_scenario.required,
        },
        .source_revision = source_revision,
        .zig_version = @import("builtin").zig_version_string,
        .status = status,
        .execution = .{
            .tool_version = "test",
            .target = "native-test",
            .optimize = "Debug",
            .command_digest = "sha256:bde4102bf412d9240ccdd9b8487a3cc3d6653e3aeddfe5c48a9641d9d3dc2e63",
            .manifest_digest = manifest_digest,
            .native_receipt = true,
        },
        .assertions = if (status == .failed) &failed_assertions else &passed_assertions,
    };
}

fn writeGraphEvent(dir: std.Io.Dir, path: []const u8, label: []const u8) !void {
    var database = try zstd.CausalGraph.LocalDatabase.init(std.testing.allocator, std.testing.io, dir, .{ .path = path, .max_records = 32 });
    defer database.deinit();
    var backend = database.storageBackend(std.testing.allocator, 32);
    defer backend.deinit();
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    _ = store.replaceBackend(backend.backend());
    _ = try store.record(.{ .kind = .activity_completed, .label = label, .status = "success" });
    try backend.flush();
    _ = store.replaceBackend(null);
}

test "evidence reconciliation closes only matching fresh complete requirements" {
    const project = manifest();
    try project.validate();
    const manifest_digest = try Development.manifestDigestAlloc(std.testing.allocator, project);
    defer std.testing.allocator.free(manifest_digest);
    const receipts = [_]zstd.Testing.TestReceipt{
        receipt(project.test_scenarios[0], "revision-current", manifest_digest, .passed),
        receipt(project.test_scenarios[1], "revision-stale", manifest_digest, .passed),
    };
    const run = zstd.Testing.TestRunReceipt{
        .project = "proof-app",
        .source_revision = "revision-current",
        .discovered = 2,
        .selected = 2,
        .passed = 2,
        .failed = 0,
        .incomplete = 0,
        .unsupported = 0,
        .skipped = 0,
        .canceled = 0,
        .receipts = &receipts,
    };

    var reconciled = try Development.reconcileAlloc(std.testing.allocator, project, &run, "revision-current");
    defer reconciled.deinit();
    try std.testing.expectEqual(@as(usize, 1), reconciled.requirements_satisfied);
    try std.testing.expectEqual(@as(usize, 1), reconciled.requirements_open);
    try std.testing.expectEqual(Development.CheckState.passed, reconciled.check("check-one").?.state);
    try std.testing.expectEqual(Development.CheckState.stale, reconciled.check("check-two").?.state);
    try std.testing.expectEqualStrings(".zigeffect/tests/process-receipts/scenario-one.json", reconciled.check("check-one").?.evidence_ref);
    try std.testing.expectEqualStrings(".zigeffect/handoffs/tests/scenario-one.json", reconciled.check("check-one").?.proof_ref);
}

test "development context is deterministic budgeted and explicit about omissions" {
    const project = manifest();
    const manifest_digest = try Development.manifestDigestAlloc(std.testing.allocator, project);
    defer std.testing.allocator.free(manifest_digest);
    const receipts = [_]zstd.Testing.TestReceipt{
        receipt(project.test_scenarios[0], "revision-current", manifest_digest, .passed),
    };
    const run = zstd.Testing.TestRunReceipt{
        .project = "proof-app",
        .source_revision = "revision-current",
        .selection = .affected,
        .selection_value = "src/one.zig",
        .discovered = 2,
        .selected = 1,
        .passed = 1,
        .failed = 0,
        .incomplete = 0,
        .unsupported = 0,
        .skipped = 0,
        .canceled = 0,
        .receipts = &receipts,
    };
    var reconciled = try Development.reconcileAlloc(std.testing.allocator, project, &run, "revision-current");
    defer reconciled.deinit();

    const json = try Development.compileContextJsonAlloc(std.testing.allocator, .{
        .manifest = project,
        .reconciliation = reconciled.view(),
        .task_id = "task-req-one",
        .source_revision = "revision-current",
        .source_dirty = true,
        .changed_paths = &.{"src/one.zig"},
        .graph = .{ .records = 41, .edges = 40, .sessions = 7, .cursor = 41 },
        .byte_budget = 2048,
    });
    defer std.testing.allocator.free(json);
    try std.testing.expect(json.len <= 2048);
    try std.testing.expect(std.mem.indexOf(u8, json, "zigeffect.agent.development-context.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "check-one") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "scenario-one") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"omitted\"") != null);
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();
}

test "project context endpoint reconciles durable per-scenario receipts in one bounded query" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const project = manifest();
    const manifest_digest = try Development.manifestDigestAlloc(std.testing.allocator, project);
    defer std.testing.allocator.free(manifest_digest);
    try zstd.Testing.Protocol.publishReceipt(std.testing.allocator, std.testing.io, tmp.dir, receipt(project.test_scenarios[0], "revision-current", manifest_digest, .passed));
    try zstd.Testing.Protocol.publishReceipt(std.testing.allocator, std.testing.io, tmp.dir, receipt(project.test_scenarios[1], "revision-current", manifest_digest, .passed));

    var evidence = try Development.collectEvidenceAlloc(
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        project,
        "revision-current",
        1024 * 1024,
    );
    defer evidence.deinit();
    try std.testing.expectEqual(@as(usize, 2), evidence.run().?.receipts.len);

    const json = try Development.compileProjectContextJsonAlloc(std.testing.allocator, std.testing.io, tmp.dir, project, .{
        .task_id = "task-req-two",
        .source_revision = "revision-current",
        .source_dirty = false,
        .changed_paths = &.{"src/two.zig"},
        .byte_budget = 4096,
    });
    defer std.testing.allocator.free(json);
    try std.testing.expect(json.len <= 4096);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"requirements_open\":0") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "scenario-two") != null);
}

test "source identity addresses dirty project content rather than commit alone" {
    var identity = try Development.sourceIdentityAlloc(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{});
    defer identity.deinit();
    try std.testing.expect(identity.available);
    try std.testing.expect(std.mem.startsWith(u8, identity.revision, "git:"));
    try std.testing.expect(std.mem.indexOf(u8, identity.revision, ":sha256:") != null);
    try std.testing.expect(identity.revision.len >= 4 + 40 + 8 + 64);
}

test "automatic test proof handoff content addresses manifest run and receipts" {
    const project = manifest();
    const manifest_digest = try Development.manifestDigestAlloc(std.testing.allocator, project);
    defer std.testing.allocator.free(manifest_digest);
    const receipts = [_]zstd.Testing.TestReceipt{receipt(project.test_scenarios[0], "revision-current", manifest_digest, .passed)};
    const run = zstd.Testing.TestRunReceipt{
        .project = "proof-app",
        .source_revision = "revision-current",
        .selection = .scenario,
        .selection_value = "scenario-one",
        .discovered = 2,
        .selected = 1,
        .passed = 1,
        .failed = 0,
        .incomplete = 0,
        .unsupported = 0,
        .skipped = 0,
        .canceled = 0,
        .receipts = &receipts,
    };
    const json = try Development.testProofHandoffJsonAlloc(std.testing.allocator, project, run);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, Development.test_proof_handoff_schema) != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"manifest_digest\":\"sha256:") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"receipt_digest\":\"sha256:") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"authoritative\":true") != null);
}

test "task lifecycle leases and proof bundles reject stale swarm integration" {
    var task = Development.Task.init("task-req-one", "req-one", "check-one", "app");
    try task.apply(.scope);
    try task.apply(.claim);
    try task.apply(.start);
    try task.apply(.submit_review);
    try task.apply(.accept_review);
    try task.apply(.start_verification);
    try std.testing.expectError(error.InvalidTaskTransition, task.apply(.complete));

    var leases = Development.LeaseRegistry.init(std.testing.allocator);
    defer leases.deinit();
    const first = try leases.claim("component:app", "agent-one", 100, 200);
    try std.testing.expectError(error.LeaseConflict, leases.claim("component:app", "agent-two", 150, 300));
    const second = try leases.claim("component:app", "agent-two", 201, 300);
    try std.testing.expect(second.fencing_token > first.fencing_token);
    const renewed = try leases.renew("component:app", "agent-two", second.fencing_token, 250, 400);
    try std.testing.expectEqual(@as(u64, 400), renewed.expires_at);
    _ = try leases.require("component:app", "agent-two", second.fencing_token, 300);
    try std.testing.expectError(error.StaleLease, leases.require("component:app", "agent-one", first.fencing_token, 300));

    const packet = Development.WorkPacket{
        .id = "packet-one",
        .causal_id = 71,
        .task_id = "task-req-one",
        .requirement = "req-one",
        .acceptance_check = "check-one",
        .component = "app",
        .source_revision = "revision-current",
        .lease_key = "component:app",
        .lease_fencing_token = second.fencing_token,
        .allowed_paths = &.{"src"},
        .verification_commands = &.{"test"},
    };
    try packet.validate();
    const stale_proof = Development.ProofBundle{
        .work_packet_id = "packet-one",
        .work_packet_causal_id = 71,
        .task_id = "task-req-one",
        .requirement = "req-one",
        .acceptance_check = "check-one",
        .source_revision = "revision-stale",
        .change_set_id = 72,
        .graph_session_id = 7,
        .lease_fencing_token = first.fencing_token,
        .receipt_refs = &.{".zigeffect/tests/latest.json#scenario-one"},
        .receipt_digests = &.{"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
        .diff_digest = "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        .verification_command_digests = &.{"sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"},
        .changed_paths = &.{"src/one.zig"},
        .causal_event_ids = &.{ 81, 82 },
        .invariants = &.{.{ .id = "req-one-remains-true", .passed = true, .causal_event_ids = &.{82} }},
        .verdict = .passed,
    };
    try std.testing.expectError(error.ProofSourceMismatch, Development.verifyProof(packet, stale_proof));

    var proof = stale_proof;
    proof.source_revision = "revision-current";
    proof.lease_fencing_token = second.fencing_token;
    try Development.verifyProof(packet, proof);
    try Development.verifyProofJoin(&.{packet}, &.{proof});
    const join = try Development.integrationJoinEvent(&.{packet}, &.{proof});
    try std.testing.expectEqual(@as(usize, 1), join.activeLinks().len);
    try std.testing.expectEqual(zstd.fx.CausalLinkKind.proof, join.activeLinks()[0].kind);
    try std.testing.expectEqual(@as(?u64, 7), join.activeLinks()[0].graph_session_id);
    var escaped = proof;
    escaped.changed_paths = &.{"docs/undeclared.md"};
    try std.testing.expectError(error.ProofChangedUndeclaredPath, Development.verifyProof(packet, escaped));
    try task.apply(.verification_passed);
    try std.testing.expectEqual(Development.TaskState.completed, task.state);
    try leases.release("component:app", "agent-two", second.fencing_token);
    try std.testing.expectError(error.LeaseNotFound, leases.require("component:app", "agent-two", second.fencing_token, 300));
}

test "repair episodes and federated graph references are bounded safe contracts" {
    const reference = Development.FederatedEventRef{
        .project = "proof-app",
        .component = "app",
        .graph_session_id = 7,
        .durable_event_id = 82,
    };
    try reference.validate();
    const episode = Development.RepairEpisode{
        .fingerprint = "statechart:failed-readiness:v1",
        .requirement = "req-one",
        .before = reference,
        .after = .{ .project = "proof-app", .component = "app", .graph_session_id = 8, .durable_event_id = 91 },
        .change_set_id = 72,
        .proof_event_ids = &.{ 90, 91 },
        .summary = "bounded retry policy fixed the readiness transition",
        .invalidated_by_revision = "revision-next",
    };
    try episode.validate();
    var unsafe = episode;
    unsafe.summary = "authorization: Bearer sentinel-secret-for-tests";
    try std.testing.expectError(error.SecretDetected, unsafe.validate());

    var memory = Development.RepairMemory.init(std.testing.allocator);
    defer memory.deinit();
    try memory.remember(episode);
    const matches = try memory.queryAlloc(std.testing.allocator, "statechart:failed-readiness:v1", "revision-current", 8);
    defer std.testing.allocator.free(matches);
    try std.testing.expectEqual(@as(usize, 1), matches.len);
    try std.testing.expectEqualStrings(episode.summary, matches[0].summary);
    const invalidated = try memory.queryAlloc(std.testing.allocator, "statechart:failed-readiness:v1", "revision-next", 8);
    defer std.testing.allocator.free(invalidated);
    try std.testing.expectEqual(@as(usize, 0), invalidated.len);
}

test "federated graph joins exact records without sharing application WALs" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try writeGraphEvent(tmp.dir, "graph-a", "project-a-event");
    try writeGraphEvent(tmp.dir, "graph-b", "project-b-event");
    const mounts = [_]Development.FederatedGraphMount{
        .{ .project = "project-a", .component = "api", .root = tmp.dir, .options = .{ .path = "graph-a", .max_records = 32 } },
        .{ .project = "project-b", .component = "worker", .root = tmp.dir, .options = .{ .path = "graph-b", .max_records = 32 } },
    };
    const federation = try Development.FederatedGraph.init(std.testing.io, &mounts);
    const references = [_]Development.FederatedEventRef{
        .{ .project = "project-a", .component = "api", .graph_session_id = 1, .durable_event_id = 1 },
        .{ .project = "project-b", .component = "worker", .graph_session_id = 1, .durable_event_id = 1 },
    };
    const json = try federation.joinJsonAlloc(std.testing.allocator, &references);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "zigeffect.development.federated-join.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "project-a-event") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "project-b-event") != null);
}

test "Development exposes replaceable effect services and layers" {
    try std.testing.expect(@hasDecl(Development, "EvidenceService"));
    try std.testing.expect(@hasDecl(Development, "CoordinationService"));
    try std.testing.expect(@hasDecl(Development, "ContextService"));
    try std.testing.expect(@hasDecl(Development, "GraphService"));
    try std.testing.expect(@hasDecl(Development, "evidenceLayer"));
    try std.testing.expect(@hasDecl(Development, "coordinationLayer"));
    try std.testing.expect(@hasDecl(Development, "contextLayer"));
}

test "development root layer composes context and durable task workflows in one runtime" {
    const project = manifest();
    const manifest_digest = try Development.manifestDigestAlloc(std.testing.allocator, project);
    defer std.testing.allocator.free(manifest_digest);
    const receipts = [_]zstd.Testing.TestReceipt{receipt(project.test_scenarios[0], "revision-current", manifest_digest, .passed)};
    const run = zstd.Testing.TestRunReceipt{
        .project = "proof-app",
        .source_revision = "revision-current",
        .discovered = 2,
        .selected = 1,
        .passed = 1,
        .failed = 0,
        .incomplete = 0,
        .unsupported = 0,
        .skipped = 0,
        .canceled = 0,
        .receipts = &receipts,
    };
    var reconciliation = try Development.reconcileAlloc(std.testing.allocator, project, &run, "revision-current");
    defer reconciliation.deinit();

    var evidence_impl = Development.DefaultEvidence{};
    var context_impl = Development.DefaultContext{};
    var leases = Development.LeaseRegistry.init(std.testing.allocator);
    defer leases.deinit();
    var memory_journal = zstd.fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer memory_journal.deinit();
    var causal = zstd.fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    var causal_journal = zstd.fx.workflow.CausalJournalStore.init(std.testing.allocator, memory_journal.asJournalStore(), &causal, null);
    defer causal_journal.deinit();
    var tasks = Development.TaskJournal.init(causal_journal.asJournalStore());
    const layer = Development.rootLayer(
        Development.EvidenceApi.from(Development.DefaultEvidence, &evidence_impl),
        .{ .leases = &leases, .tasks = &tasks },
        Development.ContextApi.from(Development.DefaultContext, &context_impl),
    );
    var runtime = try zstd.fx.kernel.ManagedRuntime(@TypeOf(layer)).make(std.testing.allocator, layer, .{});
    defer runtime.deinit();

    const context_json = try runtime.run(Development.compileContext(.{
        .manifest = project,
        .reconciliation = reconciliation.view(),
        .task_id = "task-req-one",
        .source_revision = "revision-current",
        .source_dirty = true,
        .changed_paths = &.{"src/one.zig"},
        .byte_budget = 4096,
    }).named("development.context"));
    defer std.testing.allocator.free(context_json);
    try std.testing.expect(std.mem.indexOf(u8, context_json, Development.context_schema) != null);

    const declared = Development.Task.init("task-req-one", "req-one", "check-one", "proof-app");
    const scoped = try runtime.run(Development.transitionTask(.{
        .task = declared,
        .expected_revision = 0,
        .event = .scope,
        .idempotency_key = "task-req-one:scope:1",
    }).named("development.task.scope"));
    try std.testing.expectEqual(Development.TaskState.scoped, scoped.state);
    const retried = try runtime.run(Development.transitionTask(.{
        .task = declared,
        .expected_revision = 0,
        .event = .scope,
        .idempotency_key = "task-req-one:scope:1",
    }).named("development.task.scope.retry"));
    try std.testing.expectEqual(scoped.revision, retried.revision);
    try std.testing.expectError(error.StaleTaskRevision, runtime.run(Development.transitionTask(.{
        .task = declared,
        .expected_revision = 0,
        .event = .claim,
        .idempotency_key = "task-req-one:claim:stale",
    })));
    const loaded = try tasks.load(std.testing.allocator, declared);
    try std.testing.expectEqual(Development.TaskState.scoped, loaded.state);
    var causal_snapshot = try causal.snapshot(std.testing.allocator);
    defer causal_snapshot.deinit();
    var saw_durable_task = false;
    for (causal_snapshot.events) |event| if (event.kind == .workflow_event_recorded and std.mem.eql(u8, event.label, "scope")) {
        saw_durable_task = true;
    };
    try std.testing.expect(saw_durable_task);
}
