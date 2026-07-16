const std = @import("std");
const zgraphy = @import("zgraphy");
const zstd = @import("zigeffect_std");

const repository_scenario = zstd.Testing.Scenario{
    .id = "repository-graph-roundtrip",
    .label = "Zig repository graph extracts and survives a NenStore round trip",
    .requirement = "req-local-repository-graph",
    .acceptance_check = "check-local-repository-graph",
    .component = "zgraphy",
    .command = "test",
    .default_seed = 1601,
    .source_roots = &.{ "src/model.zig", "src/nendb.zig", "src/store.zig", "src/indexer.zig", "test/all_test.zig" },
    .tags = &.{ "acceptance", "nendb", "graph", "deterministic" },
};

const retrieval_scenario = zstd.Testing.Scenario{
    .id = "hybrid-retrieval",
    .label = "keyword vector and graph scores produce bounded inspectable retrieval",
    .requirement = "req-hybrid-retrieval",
    .acceptance_check = "check-hybrid-retrieval",
    .component = "zgraphy",
    .command = "test",
    .default_seed = 1602,
    .source_roots = &.{ "src/search.zig", "src/model.zig", "test/all_test.zig" },
    .tags = &.{ "acceptance", "keyword", "vector", "graph" },
};

const bridge_scenario = zstd.Testing.Scenario{
    .id = "zigeffect-source-bridge",
    .label = "ZigEffect intent and causal facts link to stable source references",
    .requirement = "req-zigeffect-source-bridge",
    .acceptance_check = "check-zigeffect-source-bridge",
    .component = "zgraphy",
    .command = "test",
    .default_seed = 1603,
    .source_roots = &.{ "src/zigeffect_bridge.zig", "src/indexer.zig", "src/application.zig", "test/all_test.zig" },
    .tags = &.{ "acceptance", "zigeffect", "causal", "source" },
};

test "zgraphy command application exposes a non-empty canonical root layer" {
    try std.testing.expectEqualStrings(".zigeffect/graph", zgraphy.Application.causal_graph_path);
    const layer = zgraphy.Application.rootLayer(.{ .io = std.testing.io, .root = std.Io.Dir.cwd(), .args = &.{ "zgraphy", "status" } });
    var causal = zstd.fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    var runtime = try zstd.fx.kernel.ManagedRuntime(@TypeOf(layer)).make(std.testing.allocator, layer, .{ .causal_store = &causal });
    defer runtime.deinit();
    var snapshot = try runtime.inspect(std.testing.allocator, .{});
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), snapshot.services.len);
    try std.testing.expectEqualStrings(zgraphy.Application.ApplicationInputs.service_key, snapshot.services[0].key);
}

const parity_scenario = zstd.Testing.Scenario{
    .id = "m0-graphify-parity-ledger",
    .label = "Pinned Graphify capability families have a complete versioned parity ledger",
    .requirement = "req-m0-graphify-parity-ledger",
    .acceptance_check = "check-m0-graphify-parity-ledger",
    .component = "zgraphy",
    .command = "test",
    .default_seed = 1700,
    .source_roots = &.{ "src/parity.zig", "src/graphify-parity.v1.json", "src/root.zig", "src/main.zig", "test/all_test.zig" },
    .tags = &.{ "acceptance", "m0", "graphify", "parity", "deterministic" },
};

const benchmark_corpus_scenario = zstd.Testing.Scenario{
    .id = "m0-canonical-benchmark-corpus",
    .label = "Canonical benchmark IR and source-grounded cross-stack gold corpus validate deterministically",
    .requirement = "req-m0-canonical-benchmark-corpus",
    .acceptance_check = "check-m0-canonical-benchmark-corpus",
    .component = "zgraphy",
    .command = "test",
    .default_seed = 1701,
    .source_roots = &.{ "src/benchmark.zig", "benchmarks/embedded.zig", "benchmarks/corpus.v1.json", "benchmarks/gold", "benchmarks/fixtures", "src/root.zig", "src/main.zig", "test/all_test.zig" },
    .tags = &.{ "acceptance", "m0", "benchmark", "gold", "cross-stack", "freshness", "deterministic" },
};

const graphify_adapter_scenario = zstd.Testing.Scenario{
    .id = "m0-graphify-differential-adapter",
    .label = "Pinned Graphify raw graph projects into bounded canonical differential evidence",
    .requirement = "req-m0-graphify-differential-adapter",
    .acceptance_check = "check-m0-graphify-differential-adapter",
    .component = "zgraphy",
    .command = "test",
    .default_seed = 1702,
    .source_roots = &.{ "src/differential.zig", "src/benchmark.zig", "benchmarks/embedded.zig", "benchmarks/adapter-fixtures/graphify-0.9.17", "benchmarks/run_graphify_reference.sh", "benchmarks/gold", "src/root.zig", "src/main.zig", "test/all_test.zig" },
    .tags = &.{ "acceptance", "m0", "graphify", "adapter", "differential", "projection-loss", "deterministic" },
};

const zgraphy_adapter_scenario = zstd.Testing.Scenario{
    .id = "m0-zgraphy-differential-adapter",
    .label = "Native zgraphy graph projects into bounded canonical differential evidence",
    .requirement = "req-m0-zgraphy-differential-adapter",
    .acceptance_check = "check-m0-zgraphy-differential-adapter",
    .component = "zgraphy",
    .command = "test",
    .default_seed = 1703,
    .source_roots = &.{ "src/differential.zig", "src/indexer.zig", "src/model.zig", "src/benchmark.zig", "benchmarks/fixtures/zig-ambiguity", "benchmarks/fixtures/mutation-pruning/baseline", "benchmarks/gold/zig-ambiguity.canonical.v1.json", "benchmarks/gold/mutation-pruning.canonical.v1.json", "src/root.zig", "src/main.zig", "test/all_test.zig" },
    .tags = &.{ "acceptance", "m0", "zgraphy", "adapter", "differential", "projection-loss", "deterministic" },
};

test "zgraphy repository graph extracts Zig relationships with stable source evidence" {
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = repository_scenario,
        .seed = 1601,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);
    var graph = try zgraphy.RepositoryGraph.init(std.testing.allocator, .{});
    defer graph.deinit();

    try zgraphy.Indexer.indexZigSource(&graph, "src/service.zig",
        \\const store = @import("store.zig");
        \\pub const Service = struct {};
        \\pub fn load() void {}
        \\pub fn handle() void { load(); }
    );

    const file = graph.findNodeByLabel("service.zig") orelse return error.MissingFileNode;
    const handler = graph.findNodeByLabel("handle") orelse return error.MissingHandlerNode;
    const loader = graph.findNodeByLabel("load") orelse return error.MissingLoaderNode;
    try std.testing.expectEqual(zgraphy.stableId(.symbol, "src/service.zig", "handle"), handler.id);
    try std.testing.expect(graph.hasEdge(file.id, handler.id, .declares));
    try std.testing.expect(graph.hasEdge(handler.id, loader.id, .calls));
    try std.testing.expect(graph.hasOutgoingRelation(file.id, .imports));
    try std.testing.expectEqual(@as(u32, 4), handler.line);
    try assertions.boolean(.{
        .id = "zgraphy.repository.relationships",
        .label = "Zig declarations imports and calls retain stable source evidence",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 45, .column = 1 },
        .repair_hint = "repair the Zig extraction and deterministic relationship resolver",
    }, graph.hasEdge(file.id, handler.id, .declares) and graph.hasEdge(handler.id, loader.id, .calls));
    try assertions.noFindings(.{ .id = "zgraphy.repository.no-findings", .label = "repository extraction has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.repository.no-pending", .label = "repository extraction leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy repository graph persists a complete NenStore snapshot and rejects truncation" {
    var graph = try zgraphy.RepositoryGraph.init(std.testing.allocator, .{});
    defer graph.deinit();
    try zgraphy.Indexer.indexZigSource(&graph, "src/main.zig", "pub fn main() void {}\n");

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try zgraphy.Store.save(std.testing.io, tmp.dir, "nendb.jsonl", &graph);
    var loaded = try zgraphy.Store.load(std.testing.allocator, std.testing.io, tmp.dir, "nendb.jsonl", .{});
    defer loaded.deinit();
    try std.testing.expectEqual(graph.nodeCount(), loaded.nodeCount());
    try std.testing.expectEqual(graph.edgeCount(), loaded.edgeCount());
    try std.testing.expectEqual(graph.vectorCount(), loaded.vectorCount());

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "broken.jsonl",
        .data = "{\"record\":\"header\",\"schema\":\"zgraphy.nendb.snapshot.v1\"}\n",
    });
    try std.testing.expectError(
        error.IncompleteSnapshot,
        zgraphy.Store.load(std.testing.allocator, std.testing.io, tmp.dir, "broken.jsonl", .{}),
    );
}

test "zgraphy repository graph builds an initialized local fixture deterministically" {
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/store.zig",
        .data = "pub fn load() void {}\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/main.zig",
        .data = "const store = @import(\"store.zig\");\npub fn main() void { store.load(); }\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/ignored.zig",
        .data = "pub fn ignored() void {}\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "zigeffect.project.json",
        .data =
        \\{"schema":"zigeffect.project.v1","components":[{"id":"app","path":"src"}],"commands":[],"requirements":[],"acceptance_checks":[],"test_scenarios":[]}
        ,
    });
    try std.testing.expectEqual(zgraphy.Project.InitStatus.initialized, try zgraphy.Project.init(std.testing.allocator, std.testing.io, tmp.dir));
    try std.testing.expectEqual(zgraphy.Project.InitStatus.already_initialized, try zgraphy.Project.init(std.testing.allocator, std.testing.io, tmp.dir));
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = ".zgraphyignore", .data = "src/ignored.zig\n" });

    var built = try zgraphy.Indexer.buildRepository(std.testing.allocator, std.testing.io, tmp.dir, .{});
    defer built.deinit();
    try std.testing.expectEqual(@as(usize, 3), built.summary.files_indexed);
    const main_file = built.graph.findNodeByLabel("main.zig") orelse return error.MissingMainFile;
    const store_file = built.graph.findNodeByLabel("store.zig") orelse return error.MissingStoreFile;
    try std.testing.expect(built.graph.hasEdge(main_file.id, store_file.id, .imports));
    try std.testing.expect(built.graph.hasEdge(
        zgraphy.stableId(.symbol, "src/main.zig", "main"),
        zgraphy.stableId(.symbol, "src/store.zig", "load"),
        .calls,
    ));
    try std.testing.expect(built.summary.nodes == built.graph.nodeCount());
    try std.testing.expectEqual(built.summary.nodes, built.summary.vectors);
    try std.testing.expect(built.graph.findNodeByLabel("ignored.zig") == null);
}

test "zgraphy hybrid retrieval exposes keyword vector and graph contributions" {
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = retrieval_scenario,
        .seed = 1602,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);
    var graph = try zgraphy.RepositoryGraph.init(std.testing.allocator, .{});
    defer graph.deinit();
    const handler = try graph.addSearchableNode(.symbol, "PaymentHandler", "src/payment.zig", 10, "process card payment authorization");
    const repository = try graph.addSearchableNode(.symbol, "PaymentRepository", "src/repository.zig", 8, "persist transaction records");
    const pool = try graph.addSearchableNode(.symbol, "DatabasePool", "src/database.zig", 5, "sql database connection pool");
    try graph.addEdge(.{ .from = handler, .to = repository, .relation = .calls, .provenance = .extracted });
    try graph.addEdge(.{ .from = repository, .to = pool, .relation = .calls, .provenance = .extracted });

    var results = try zgraphy.Search.queryAlloc(std.testing.allocator, &graph, "card payment database", .{ .limit = 3 });
    defer results.deinit();
    try std.testing.expect(results.items.len >= 2);
    try std.testing.expectEqual(handler, results.items[0].node_id);
    try std.testing.expect(results.items[0].keyword_score > 0);
    try std.testing.expect(results.items[0].vector_score > 0);
    var saw_graph_score = false;
    for (results.items) |item| saw_graph_score = saw_graph_score or item.graph_score > 0;
    try std.testing.expect(saw_graph_score);

    var path = try graph.shortestPathAlloc(std.testing.allocator, handler, pool, 4);
    defer path.deinit();
    try std.testing.expect(path.complete);
    try std.testing.expectEqualSlices(u64, &.{ handler, repository, pool }, path.node_ids);
    try assertions.boolean(.{
        .id = "zgraphy.retrieval.hybrid-components",
        .label = "keyword vector and graph scores all contribute to bounded retrieval",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 137, .column = 1 },
        .repair_hint = "preserve inspectable hybrid scoring and graph expansion",
    }, results.items[0].keyword_score > 0 and results.items[0].vector_score > 0 and saw_graph_score);
    try assertions.boolean(.{
        .id = "zgraphy.retrieval.shortest-path",
        .label = "bounded graph retrieval finds the expected shortest path",
        .repair_hint = "repair bounded breadth-first traversal without hiding exhausted bounds",
    }, path.complete and path.node_ids.len == 3);
    try assertions.noFindings(.{ .id = "zgraphy.retrieval.no-findings", .label = "hybrid retrieval has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.retrieval.no-pending", .label = "hybrid retrieval leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy ZigEffect source bridge links manifest intent to stable code references" {
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = bridge_scenario,
        .seed = 1603,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);
    var graph = try zgraphy.RepositoryGraph.init(std.testing.allocator, .{});
    defer graph.deinit();
    try zgraphy.Indexer.indexZigSource(&graph, "src/main.zig", "pub fn main() void {}\n");
    try zgraphy.Indexer.indexZigEffectManifest(&graph,
        \\{"schema":"zigeffect.project.v1","name":"fixture","version":"0.1.0","kind":"application","components":[{"id":"api","kind":"service","path":"src","depends_on":[],"capabilities":[]}],"commands":[{"id":"test","argv":["zig","build","test"],"component":null}],"requirements":[{"id":"req-api","summary":"serve the API","component":"api","status":"active"}],"acceptance_checks":[{"id":"check-api","requirement":"req-api","command":"test","expectation":"API passes","status":"pending"}],"test_scenarios":[{"id":"api-test","label":"API test","requirement":"req-api","acceptance_check":"check-api","component":"api","command":"test","source_roots":["src/main.zig"],"tags":[],"default_seed":1,"fault_profile":"standard","required":true}],"execution_posture":"local","capability_requirements":[],"capability_descriptors":[],"adapter_profiles":[],"policy":{"allow_network":false,"require_approval_for_processes":true,"persist_raw_terminal":false},"safety":{"profile":"unmanaged","safe_roots":[],"audited_roots":[],"allowances":[],"gates":[],"limits":{"max_source_bytes":1,"max_findings":1,"max_diagnostics":1,"max_schedules":1,"max_fuzz_cases":1,"max_artifact_bytes":1,"max_runtime_events":1},"production_posture":{"retain_generation_checks":true,"retain_critical_invariants":true,"retain_causal_findings":true}},"artifacts":{"sessions":".zigeffect/sessions","causal":".zigeffect/causal","receipts":".zigeffect/receipts","graph":".zigeffect/graph","statecharts":".zigeffect/statecharts"},"dependencies":{}}
    );
    const scenario = graph.findNodeByLabel("api-test") orelse return error.MissingScenario;
    const source = graph.findNodeByLabel("main.zig") orelse return error.MissingSource;
    try std.testing.expect(graph.hasEdge(scenario.id, source.id, .source_root));

    const source_ref = try zgraphy.ZigEffectBridge.sourceRefAlloc(std.testing.allocator, "src/main.zig", "main");
    defer std.testing.allocator.free(source_ref);
    try std.testing.expectEqualStrings("zgraphy://source/src/main.zig#main", source_ref);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const empty = zstd.fx.kernel.Layer.empty();
    var runtime = try zstd.ManagedRuntime(@TypeOf(empty)).make(
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        empty,
        .{ .graph = .{ .path = ".zigeffect/graph", .max_records = 128 }, .causal_store = evidence.causalStore() },
    );
    defer runtime.deinit();
    try runtime.run(zgraphy.ZigEffectBridge.linkEffect(.{
        .source_ref = source_ref,
        .label = "fixture.main",
    }));
    try std.testing.expect(runtime.graphSummary().records > 0);
    try std.testing.expectEqual(zstd.CausalRuntime.HealthStatus.healthy, runtime.causalHealth().status);
    _ = try assertions.event(.{
        .id = "zgraphy.bridge.causal-source-ref",
        .label = "the managed runtime records the stable zgraphy source reference",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 199, .column = 1 },
        .repair_hint = "run ZigEffectBridge.linkEffect through the canonical managed runtime",
    }, .{ .kind = .activity_completed, .label = "fixture.main", .status = "observed" });
    try assertions.noFindings(.{ .id = "zgraphy.bridge.no-findings", .label = "source linking has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.bridge.no-pending", .label = "source linking leaves no pending fibers" });
    try evidence.mapCausalEventIds(&runtime);
    try runtime.shutdown();

    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/main.zig", .data = "pub fn main() void {}\n" });
    var linked = try zgraphy.Indexer.buildRepository(std.testing.allocator, std.testing.io, tmp.dir, .{});
    defer linked.deinit();
    const linked_source = linked.graph.findNodeByLabel("main") orelse return error.MissingLinkedSource;
    var observed = false;
    for (linked.graph.edges.items) |edge| {
        observed = observed or (edge.to == linked_source.id and edge.relation == .observed_at);
    }
    try std.testing.expect(observed);
    try std.testing.expect(linked.summary.causal_records > 0);
    try assertions.boolean(.{
        .id = "zgraphy.bridge.observed-at",
        .label = "durable causal projection resolves to the indexed source symbol",
        .repair_hint = "preserve bounded causal WAL import and zgraphy source reference resolution",
    }, observed);
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy M0 parity ledger covers every pinned Graphify capability family" {
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = parity_scenario,
        .seed = 1700,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    var parsed = try zgraphy.Parity.parseEmbedded(std.testing.allocator);
    defer parsed.deinit();
    try zgraphy.Parity.validate(&parsed.value);
    const summary = zgraphy.Parity.summarize(&parsed.value);

    try std.testing.expectEqualStrings("zgraphy.graphify-parity.v1", parsed.value.schema);
    try std.testing.expectEqual(@as(u32, 1), parsed.value.schema_version);
    try std.testing.expectEqualStrings("0.9.17", parsed.value.baseline.version);
    try std.testing.expectEqualStrings("cb96bdaa0c367bec8d5c5aee5d7c9ebb727e9780", parsed.value.baseline.commit);
    try std.testing.expectEqual(zgraphy.Parity.required_capability_ids.len, summary.total);
    try std.testing.expect(summary.core_parity > 0);
    try std.testing.expect(summary.improved_equivalent > 0);
    try std.testing.expect(summary.optional_parity > 0);
    try std.testing.expect(summary.deferred_visual > 0);
    for (zgraphy.Parity.required_capability_ids) |id| {
        try std.testing.expect(zgraphy.Parity.findCapability(&parsed.value, id) != null);
    }

    try assertions.boolean(.{
        .id = "zgraphy.m0.parity-ledger-complete",
        .label = "the parity ledger covers every pinned Graphify capability family",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 310, .column = 1 },
        .repair_hint = "add the missing capability family with its requirement milestone reference modules tests and planned improvement",
    }, summary.total == zgraphy.Parity.required_capability_ids.len);
    try assertions.boolean(.{
        .id = "zgraphy.m0.parity-ledger-pinned",
        .label = "the parity ledger is bound to the reviewed Graphify commit",
        .repair_hint = "review the new Graphify reference then update the ledger and differential baseline together",
    }, std.mem.eql(u8, parsed.value.baseline.commit, "cb96bdaa0c367bec8d5c5aee5d7c9ebb727e9780"));
    try assertions.noFindings(.{ .id = "zgraphy.m0.no-findings", .label = "parity validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m0.no-pending", .label = "parity validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy M0 canonical benchmark corpus is source grounded and engine neutral" {
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = benchmark_corpus_scenario,
        .seed = 1701,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    var corpus = try zgraphy.Benchmark.parseEmbeddedCorpus(std.testing.allocator);
    defer corpus.deinit();
    try zgraphy.Benchmark.validateCorpus(&corpus.value);

    var summary = zgraphy.Benchmark.CorpusSummary{};
    for (corpus.value.fixtures) |fixture| {
        var gold = try zgraphy.Benchmark.parseEmbeddedGold(std.testing.allocator, fixture.gold);
        defer gold.deinit();
        try zgraphy.Benchmark.validateGold(&gold.value, fixture.id);
        try zgraphy.Benchmark.validateSources(
            std.testing.allocator,
            std.testing.io,
            std.Io.Dir.cwd(),
            &fixture,
            &gold.value,
        );
        summary.include(&fixture, &gold.value);
    }

    try std.testing.expectEqual(@as(usize, 3), summary.fixtures);
    try std.testing.expect(summary.entities >= 20);
    try std.testing.expect(summary.relations >= 16);
    try std.testing.expect(summary.facts >= 3);
    try std.testing.expect(summary.hyperedges >= 1);
    try std.testing.expect(summary.supernodes >= 1);
    try std.testing.expect(summary.retrieval_tasks >= 4);
    try std.testing.expect(summary.mutations >= 3);
    try std.testing.expect(summary.languages >= 3);

    const fullstack = zgraphy.Benchmark.findFixture(&corpus.value, "fullstack-orders") orelse return error.MissingFullstackFixture;
    try std.testing.expect(zgraphy.Benchmark.hasCapability(fullstack, "cross-stack-contract"));
    try std.testing.expect(zgraphy.Benchmark.hasCapability(fullstack, "supernode-proof"));
    const mutation = zgraphy.Benchmark.findFixture(&corpus.value, "mutation-pruning") orelse return error.MissingMutationFixture;
    try std.testing.expect(zgraphy.Benchmark.hasMutationOperation(mutation, .delete));
    try std.testing.expect(zgraphy.Benchmark.hasMutationOperation(mutation, .rename));
    try std.testing.expect(zgraphy.Benchmark.hasMutationOperation(mutation, .modify));

    try assertions.boolean(.{
        .id = "zgraphy.m0.benchmark-corpus-source-grounded",
        .label = "every canonical fact and relation resolves to immutable fixture evidence",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 354, .column = 1 },
        .repair_hint = "repair the gold evidence span or update the immutable content hash after reviewing the source fixture",
    }, summary.fixtures == 3 and summary.relations >= 16);
    try assertions.boolean(.{
        .id = "zgraphy.m0.benchmark-corpus-agent-contract",
        .label = "the corpus exercises ambiguity cross-stack supernode retrieval and stale-node pruning semantics",
        .repair_hint = "add the missing canonical IR capability and its source-grounded gold expectation",
    }, summary.facts >= 3 and summary.hyperedges >= 1 and summary.supernodes >= 1 and summary.retrieval_tasks >= 4 and summary.mutations >= 3);
    try assertions.noFindings(.{ .id = "zgraphy.m0.benchmark-corpus-no-findings", .label = "canonical corpus validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m0.benchmark-corpus-no-pending", .label = "canonical corpus validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy M0 Graphify differential adapter reports canonical matches and projection loss" {
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = graphify_adapter_scenario,
        .seed = 1702,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    var gold = try zgraphy.Benchmark.parseEmbeddedGold(std.testing.allocator, "benchmarks/gold/zig-ambiguity.canonical.v1.json");
    defer gold.deinit();
    var graphify = try zgraphy.Differential.parseEmbeddedGraphifyFixture(std.testing.allocator);
    defer graphify.deinit();
    var receipt = try zgraphy.Differential.projectGraphify(std.testing.allocator, &graphify.value, &gold.value);
    defer receipt.deinit(std.testing.allocator);
    try zgraphy.Differential.validateReceipt(&receipt);

    try std.testing.expectEqualStrings("zgraphy.differential-receipt.v1", receipt.schema);
    try std.testing.expectEqualStrings("Graphify", receipt.adapter.engine);
    try std.testing.expectEqualStrings("0.9.17", receipt.adapter.version);
    try std.testing.expectEqualStrings("cb96bdaa0c367bec8d5c5aee5d7c9ebb727e9780", receipt.adapter.commit);
    try std.testing.expectEqual(@as(usize, 6), receipt.input.nodes);
    try std.testing.expectEqual(@as(usize, 5), receipt.input.relations);
    try std.testing.expectEqual(@as(usize, 7), receipt.entities.matched);
    try std.testing.expectEqual(@as(usize, 1), receipt.entities.missing);
    try std.testing.expectEqual(@as(usize, 0), receipt.entities.unexpected);
    try std.testing.expectEqual(@as(usize, 8), receipt.relations.matched);
    try std.testing.expectEqual(@as(usize, 4), receipt.relations.missing);
    try std.testing.expectEqual(@as(usize, 0), receipt.relations.unexpected);
    try std.testing.expect(zgraphy.Differential.containsId(receipt.synthesized_entity_ids, "repo:zig-ambiguity"));
    try std.testing.expect(zgraphy.Differential.containsId(receipt.missing_entity_ids, "symbol:zig-ambiguity:loader"));
    try std.testing.expect(zgraphy.Differential.containsId(receipt.missing_fact_ids, "fact:zig-ambiguity:loader-resolution"));

    try assertions.boolean(.{
        .id = "zgraphy.m0.graphify-adapter-honest-projection",
        .label = "the adapter reports mapped synthesized missing and unexpected Graphify semantics separately",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 417, .column = 1 },
        .repair_hint = "repair the source-qualified projection rule without hiding unmappable Graphify output or missing gold semantics",
    }, receipt.entities.matched == 7 and receipt.entities.missing == 1 and receipt.relations.matched == 8 and receipt.relations.missing == 4);
    try assertions.boolean(.{
        .id = "zgraphy.m0.graphify-adapter-pinned",
        .label = "the differential receipt is bound to the reviewed Graphify version and commit",
        .repair_hint = "review and re-baseline the Graphify adapter before changing its pinned version or commit",
    }, std.mem.eql(u8, receipt.adapter.commit, "cb96bdaa0c367bec8d5c5aee5d7c9ebb727e9780"));
    try assertions.noFindings(.{ .id = "zgraphy.m0.graphify-adapter-no-findings", .label = "Graphify projection validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m0.graphify-adapter-no-pending", .label = "Graphify projection validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy M0 native differential adapter reports canonical matches and internal projection loss" {
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = zgraphy_adapter_scenario,
        .seed = 1703,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    var fixture = try std.Io.Dir.cwd().openDir(std.testing.io, "benchmarks/fixtures/zig-ambiguity", .{ .iterate = true, .follow_symlinks = false });
    defer fixture.close(std.testing.io);
    var built = try zgraphy.Indexer.buildRepository(std.testing.allocator, std.testing.io, fixture, .{});
    defer built.deinit();
    var gold = try zgraphy.Benchmark.parseEmbeddedGold(std.testing.allocator, "benchmarks/gold/zig-ambiguity.canonical.v1.json");
    defer gold.deinit();
    var receipt = try zgraphy.Differential.projectZgraphy(std.testing.allocator, &built.graph, &gold.value);
    defer receipt.deinit(std.testing.allocator);
    try zgraphy.Differential.validateReceipt(&receipt);

    try std.testing.expectEqualStrings("zgraphy", receipt.adapter.engine);
    try std.testing.expectEqualStrings("0.1.0", receipt.adapter.version);
    try std.testing.expectEqualStrings("zgraphy-native-v2", receipt.adapter.adapter_version);
    try std.testing.expectEqual(@as(usize, 12), receipt.input.nodes);
    try std.testing.expectEqual(@as(usize, 20), receipt.input.relations);
    try std.testing.expectEqual(@as(usize, 8), receipt.entities.matched);
    try std.testing.expectEqual(@as(usize, 0), receipt.entities.missing);
    try std.testing.expectEqual(@as(usize, 4), receipt.entities.unexpected);
    try std.testing.expectEqual(@as(usize, 12), receipt.relations.matched);
    try std.testing.expectEqual(@as(usize, 0), receipt.relations.missing);
    try std.testing.expectEqual(@as(usize, 11), receipt.relations.unexpected);
    try std.testing.expect(!zgraphy.Differential.containsId(receipt.missing_entity_ids, "symbol:zig-ambiguity:loader"));
    try std.testing.expect(!zgraphy.Differential.containsId(receipt.missing_relation_ids, "rel:zig-ambiguity:loader-candidate-alpha"));
    try std.testing.expect(!zgraphy.Differential.containsId(receipt.missing_fact_ids, "fact:zig-ambiguity:loader-resolution"));

    var mutation_fixture = try std.Io.Dir.cwd().openDir(std.testing.io, "benchmarks/fixtures/mutation-pruning/baseline", .{ .iterate = true, .follow_symlinks = false });
    defer mutation_fixture.close(std.testing.io);
    var mutation_built = try zgraphy.Indexer.buildRepository(std.testing.allocator, std.testing.io, mutation_fixture, .{});
    defer mutation_built.deinit();
    var mutation_gold = try zgraphy.Benchmark.parseEmbeddedGold(std.testing.allocator, "benchmarks/gold/mutation-pruning.canonical.v1.json");
    defer mutation_gold.deinit();
    var mutation_receipt = try zgraphy.Differential.projectZgraphy(std.testing.allocator, &mutation_built.graph, &mutation_gold.value);
    defer mutation_receipt.deinit(std.testing.allocator);
    try zgraphy.Differential.validateReceipt(&mutation_receipt);
    try std.testing.expectEqual(@as(usize, 6), mutation_receipt.entities.matched);
    try std.testing.expectEqual(@as(usize, 0), mutation_receipt.entities.missing);
    try std.testing.expectEqual(@as(usize, 7), mutation_receipt.relations.matched);
    try std.testing.expectEqual(@as(usize, 0), mutation_receipt.relations.missing);
    try std.testing.expectEqual(@as(usize, 3), mutation_receipt.entities.unexpected);
    try std.testing.expectEqual(@as(usize, 7), mutation_receipt.relations.unexpected);

    try assertions.boolean(.{
        .id = "zgraphy.m0.native-adapter-honest-projection",
        .label = "the native adapter maps every canonical ambiguity entity relation and fact while exposing internal extras",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 467, .column = 1 },
        .repair_hint = "repair source-qualified candidate projection without filtering internal extras or inventing ambiguity evidence",
    }, receipt.entities.matched == 8 and receipt.entities.missing == 0 and receipt.entities.unexpected == 4 and receipt.relations.missing == 0 and receipt.facts.missing == 0);
    try assertions.noFindings(.{ .id = "zgraphy.m0.native-adapter-no-findings", .label = "native projection validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m0.native-adapter-no-pending", .label = "native projection validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy M0 lexical differential adapter is a cross-language orientation floor without semantic claims" {
    const scenario = zstd.Testing.Scenario{
        .id = "m0-lexical-differential-adapter",
        .label = "Bounded lexical graph provides an honest cross-language orientation floor",
        .requirement = "req-m0-lexical-differential-adapter",
        .acceptance_check = "check-m0-lexical-differential-adapter",
        .component = "zgraphy",
        .command = "test",
        .default_seed = 1704,
        .source_roots = &.{ "src/lexical.zig", "src/differential.zig", "src/benchmark.zig", "benchmarks/fixtures", "benchmarks/gold", "src/root.zig", "src/main.zig", "test/all_test.zig" },
        .tags = &.{ "acceptance", "m0", "lexical", "baseline", "typescript", "proto", "zig", "deterministic" },
    };
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = scenario,
        .seed = 1704,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    var fullstack_dir = try std.Io.Dir.cwd().openDir(std.testing.io, "benchmarks/fixtures/fullstack-orders", .{ .iterate = true, .follow_symlinks = false });
    defer fullstack_dir.close(std.testing.io);
    var fullstack_graph = try zgraphy.Lexical.build(std.testing.allocator, std.testing.io, fullstack_dir, .{});
    defer fullstack_graph.deinit();
    var fullstack_gold = try zgraphy.Benchmark.parseEmbeddedGold(std.testing.allocator, "benchmarks/gold/fullstack-orders.canonical.v1.json");
    defer fullstack_gold.deinit();
    var fullstack = try zgraphy.Differential.projectLexical(std.testing.allocator, &fullstack_graph, &fullstack_gold.value);
    defer fullstack.deinit(std.testing.allocator);
    try zgraphy.Differential.validateReceipt(&fullstack);
    try std.testing.expectEqualStrings("lexical", fullstack.adapter.engine);
    try std.testing.expectEqual(@as(usize, 15), fullstack.entities.matched);
    try std.testing.expectEqual(@as(usize, 1), fullstack.entities.missing);
    try std.testing.expectEqual(@as(usize, 4), fullstack.relations.matched);
    try std.testing.expectEqual(@as(usize, 18), fullstack.relations.missing);
    try std.testing.expectEqual(@as(usize, 0), fullstack.relations.unexpected);

    var ambiguity_dir = try std.Io.Dir.cwd().openDir(std.testing.io, "benchmarks/fixtures/zig-ambiguity", .{ .iterate = true, .follow_symlinks = false });
    defer ambiguity_dir.close(std.testing.io);
    var ambiguity_graph = try zgraphy.Lexical.build(std.testing.allocator, std.testing.io, ambiguity_dir, .{});
    defer ambiguity_graph.deinit();
    var ambiguity_gold = try zgraphy.Benchmark.parseEmbeddedGold(std.testing.allocator, "benchmarks/gold/zig-ambiguity.canonical.v1.json");
    defer ambiguity_gold.deinit();
    var ambiguity = try zgraphy.Differential.projectLexical(std.testing.allocator, &ambiguity_graph, &ambiguity_gold.value);
    defer ambiguity.deinit(std.testing.allocator);
    try zgraphy.Differential.validateReceipt(&ambiguity);
    try std.testing.expectEqual(@as(usize, 8), ambiguity.entities.matched);
    try std.testing.expectEqual(@as(usize, 3), ambiguity.relations.matched);
    try std.testing.expectEqual(@as(usize, 9), ambiguity.relations.missing);
    try std.testing.expect(ambiguity.entities.unexpected > 0);

    var mutation_dir = try std.Io.Dir.cwd().openDir(std.testing.io, "benchmarks/fixtures/mutation-pruning/baseline", .{ .iterate = true, .follow_symlinks = false });
    defer mutation_dir.close(std.testing.io);
    var mutation_graph = try zgraphy.Lexical.build(std.testing.allocator, std.testing.io, mutation_dir, .{});
    defer mutation_graph.deinit();
    var mutation_gold = try zgraphy.Benchmark.parseEmbeddedGold(std.testing.allocator, "benchmarks/gold/mutation-pruning.canonical.v1.json");
    defer mutation_gold.deinit();
    var mutation = try zgraphy.Differential.projectLexical(std.testing.allocator, &mutation_graph, &mutation_gold.value);
    defer mutation.deinit(std.testing.allocator);
    try zgraphy.Differential.validateReceipt(&mutation);
    try std.testing.expectEqual(@as(usize, 6), mutation.entities.matched);
    try std.testing.expectEqual(@as(usize, 2), mutation.relations.matched);
    try std.testing.expectEqual(@as(usize, 5), mutation.relations.missing);

    try assertions.boolean(.{
        .id = "zgraphy.m0.lexical-cross-language-floor",
        .label = "the lexical baseline orients to Zig TypeScript TSX and Proto entities without claiming semantic edges",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 529, .column = 1 },
        .repair_hint = "repair bounded deterministic file and identifier tokenization without inferring calls contracts or implementations",
    }, fullstack.entities.matched == 15 and fullstack.relations.matched == 4 and fullstack.relations.unexpected == 0);
    try assertions.noFindings(.{ .id = "zgraphy.m0.lexical-no-findings", .label = "lexical baseline validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m0.lexical-no-pending", .label = "lexical baseline validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy M0 quality matrix recomputes weighted identified claim-free totals" {
    const scenario = zstd.Testing.Scenario{
        .id = "m0-quality-matrix",
        .label = "Canonical quality matrix is weighted reproducible identified and claim-free",
        .requirement = "req-m0-quality-matrix",
        .acceptance_check = "check-m0-quality-matrix",
        .component = "zgraphy",
        .command = "test",
        .default_seed = 1705,
        .source_roots = &.{ "src/quality_matrix.zig", "src/differential.zig", "src/benchmark.zig", "benchmarks/corpus.v1.json", "benchmarks/gold", "benchmarks/run_graphify_reference.sh", "benchmarks/baselines", "src/root.zig", "src/main.zig", "test/all_test.zig" },
        .tags = &.{ "acceptance", "m0", "quality", "matrix", "reproducible", "identity", "deterministic" },
    };
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = scenario,
        .seed = 1705,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    const score = zgraphy.Differential.scoreCounts;
    const runs = [_]zgraphy.QualityMatrix.Run{
        .{ .fixture_id = "zig-ambiguity", .engine = .graphify, .entities = score(8, 7, 0), .relations = score(12, 8, 0), .facts = score(1, 0, 0), .hyperedges = score(0, 0, 0), .supernodes = score(0, 0, 0) },
        .{ .fixture_id = "zig-ambiguity", .engine = .zgraphy, .entities = score(8, 8, 3), .relations = score(12, 9, 6), .facts = score(1, 0, 0), .hyperedges = score(0, 0, 0), .supernodes = score(0, 0, 0) },
        .{ .fixture_id = "zig-ambiguity", .engine = .lexical, .entities = score(8, 8, 26), .relations = score(12, 3, 0), .facts = score(1, 0, 0), .hyperedges = score(0, 0, 0), .supernodes = score(0, 0, 0) },
        .{ .fixture_id = "fullstack-orders", .engine = .graphify, .entities = score(16, 10, 2), .relations = score(22, 11, 11), .facts = score(2, 0, 0), .hyperedges = score(1, 0, 0), .supernodes = score(1, 0, 0) },
        .{ .fixture_id = "fullstack-orders", .engine = .zgraphy, .entities = score(16, 5, 4), .relations = score(22, 4, 6), .facts = score(2, 0, 0), .hyperedges = score(1, 0, 0), .supernodes = score(1, 0, 0) },
        .{ .fixture_id = "fullstack-orders", .engine = .lexical, .entities = score(16, 15, 76), .relations = score(22, 4, 0), .facts = score(2, 0, 0), .hyperedges = score(1, 0, 0), .supernodes = score(1, 0, 0) },
        .{ .fixture_id = "mutation-pruning", .engine = .graphify, .entities = score(6, 6, 0), .relations = score(7, 6, 0), .facts = score(1, 0, 0), .hyperedges = score(0, 0, 0), .supernodes = score(0, 0, 0) },
        .{ .fixture_id = "mutation-pruning", .engine = .zgraphy, .entities = score(6, 6, 3), .relations = score(7, 7, 5), .facts = score(1, 0, 0), .hyperedges = score(0, 0, 0), .supernodes = score(0, 0, 0) },
        .{ .fixture_id = "mutation-pruning", .engine = .lexical, .entities = score(6, 6, 17), .relations = score(7, 2, 0), .facts = score(1, 0, 0), .hyperedges = score(0, 0, 0), .supernodes = score(0, 0, 0) },
    };
    const identity = zgraphy.QualityMatrix.Identity{
        .corpus_digest = "sha256:1111111111111111111111111111111111111111111111111111111111111111",
        .zgraphy_source_revision = "sha256:2222222222222222222222222222222222222222222222222222222222222222",
        .graphify_python = "3.11.14",
        .graphify_environment_digest = "sha256:3333333333333333333333333333333333333333333333333333333333333333",
    };
    var matrix = try zgraphy.QualityMatrix.build(std.testing.allocator, identity, &runs);
    defer matrix.deinit(std.testing.allocator);
    try zgraphy.QualityMatrix.validate(&matrix);
    try std.testing.expectError(error.IncompleteQualityMatrix, zgraphy.QualityMatrix.build(std.testing.allocator, identity, runs[0 .. runs.len - 1]));
    var invalid_identity = identity;
    invalid_identity.corpus_digest = "sha256:invalid";
    try std.testing.expectError(error.InvalidQualityIdentity, zgraphy.QualityMatrix.build(std.testing.allocator, invalid_identity, &runs));

    const corpus_digest = zgraphy.Benchmark.canonicalCorpusDigest();
    const corpus_digest_hex = std.fmt.bytesToHex(corpus_digest, .lower);
    try std.testing.expectEqualStrings("a25dcb727149294aaf82020aa1d5325007eec512c9f225549fce73debf68caed", &corpus_digest_hex);

    var checked_baseline = try zgraphy.QualityMatrix.parseEmbeddedBaseline(std.testing.allocator);
    defer checked_baseline.deinit();
    try zgraphy.QualityMatrix.validate(&checked_baseline.value);
    try std.testing.expectEqualStrings("sha256:a25dcb727149294aaf82020aa1d5325007eec512c9f225549fce73debf68caed", checked_baseline.value.corpus_digest);
    const checked_native = zgraphy.QualityMatrix.findAggregate(&checked_baseline.value, .zgraphy) orelse return error.MissingCheckedZgraphyAggregate;
    try std.testing.expectEqual(@as(usize, 19), checked_native.entities.matched);
    try std.testing.expectEqual(@as(usize, 20), checked_native.relations.matched);

    const graphify = zgraphy.QualityMatrix.findAggregate(&matrix, .graphify) orelse return error.MissingGraphifyAggregate;
    const native = zgraphy.QualityMatrix.findAggregate(&matrix, .zgraphy) orelse return error.MissingZgraphyAggregate;
    const lexical = zgraphy.QualityMatrix.findAggregate(&matrix, .lexical) orelse return error.MissingLexicalAggregate;
    try std.testing.expectEqual(@as(usize, 30), graphify.entities.expected);
    try std.testing.expectEqual(@as(usize, 41), graphify.relations.expected);
    try std.testing.expectEqual(@as(usize, 23), graphify.entities.matched);
    try std.testing.expectEqual(@as(usize, 25), graphify.relations.matched);
    try std.testing.expectEqual(@as(usize, 19), native.entities.matched);
    try std.testing.expectEqual(@as(usize, 20), native.relations.matched);
    try std.testing.expectEqual(@as(usize, 29), lexical.entities.matched);
    try std.testing.expectEqual(@as(usize, 9), lexical.relations.matched);
    try std.testing.expectEqual(@as(usize, 119), lexical.entities.unexpected);
    try std.testing.expectEqual(@as(usize, 0), matrix.claims.len);
    try std.testing.expectEqualStrings("baseline_only", matrix.promotion_status);

    const original_graphify_entities = matrix.aggregates[0].entities;
    matrix.aggregates[0].entities.matched -= 1;
    try std.testing.expectError(error.InconsistentQualityAggregate, zgraphy.QualityMatrix.validate(&matrix));
    matrix.aggregates[0].entities = original_graphify_entities;
    try zgraphy.QualityMatrix.validate(&matrix);

    try assertions.boolean(.{
        .id = "zgraphy.m0.quality-matrix-weighted",
        .label = "the matrix recomputes weighted quality totals across every engine and fixture",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 626, .column = 1 },
        .repair_hint = "include every canonical engine fixture run and recompute totals from integer counts rather than averaging percentages",
    }, graphify.entities.expected == 30 and graphify.relations.expected == 41 and native.relations.matched == 20 and lexical.relations.matched == 9);
    try assertions.boolean(.{
        .id = "zgraphy.m0.quality-matrix-identified",
        .label = "the matrix is bound to corpus source toolchain and Graphify environment identities without superiority claims",
        .repair_hint = "supply complete sha256 identities and keep candidate comparison claims outside the baseline receipt",
    }, matrix.claims.len == 0 and std.mem.eql(u8, matrix.promotion_status, "baseline_only"));
    try assertions.noFindings(.{ .id = "zgraphy.m0.quality-matrix-no-findings", .label = "quality aggregation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m0.quality-matrix-no-pending", .label = "quality aggregation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy M0 resource and freshness receipts are bounded reproducible and claim honest" {
    const scenario = zstd.Testing.Scenario{
        .id = "m0-resource-freshness",
        .label = "Resource statistics and full rebuild freshness evidence are reproducible bounded and claim honest",
        .requirement = "req-m0-resource-freshness",
        .acceptance_check = "check-m0-resource-freshness",
        .component = "zgraphy",
        .command = "test",
        .default_seed = 1706,
        .source_roots = &.{ "src/resource_matrix.zig", "src/freshness.zig", "src/model.zig", "src/indexer.zig", "src/store.zig", "benchmarks/fixtures/mutation-pruning", "benchmarks/run_resource_baseline.py", "benchmarks/run_freshness_baseline.py", "benchmarks/baselines/resource-matrix.v1.json", "benchmarks/baselines/freshness-receipt.v1.json", "src/root.zig", "src/main.zig", "test/all_test.zig" },
        .tags = &.{ "acceptance", "m0", "resource", "latency", "memory", "freshness", "pruning", "deterministic" },
    };
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = scenario,
        .seed = 1706,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    const identity = zgraphy.ResourceMatrix.Identity{
        .corpus_digest = "sha256:1111111111111111111111111111111111111111111111111111111111111111",
        .zgraphy_source_revision = "sha256:2222222222222222222222222222222222222222222222222222222222222222",
        .graphify_python = "3.11.15",
        .graphify_environment_digest = "sha256:3333333333333333333333333333333333333333333333333333333333333333",
        .machine_digest = "sha256:4444444444444444444444444444444444444444444444444444444444444444",
        .configuration_digest = "sha256:5555555555555555555555555555555555555555555555555555555555555555",
    };
    const samples = [_]zgraphy.ResourceMatrix.Sample{
        .{ .fixture_id = "mutation-pruning", .engine = .graphify, .workload = .cold_build, .repetition = 1, .elapsed_ns = 100, .peak_rss_bytes = 1000, .persisted_bytes = 4000, .nodes = 6, .relations = 6 },
        .{ .fixture_id = "mutation-pruning", .engine = .graphify, .workload = .cold_build, .repetition = 2, .elapsed_ns = 110, .peak_rss_bytes = 1100, .persisted_bytes = 4000, .nodes = 6, .relations = 6 },
        .{ .fixture_id = "mutation-pruning", .engine = .graphify, .workload = .cold_build, .repetition = 3, .elapsed_ns = 120, .peak_rss_bytes = 1200, .persisted_bytes = 4000, .nodes = 6, .relations = 6 },
        .{ .fixture_id = "mutation-pruning", .engine = .graphify, .workload = .cold_build, .repetition = 4, .elapsed_ns = 130, .peak_rss_bytes = 1300, .persisted_bytes = 4000, .nodes = 6, .relations = 6 },
        .{ .fixture_id = "mutation-pruning", .engine = .graphify, .workload = .cold_build, .repetition = 5, .elapsed_ns = 140, .peak_rss_bytes = 1400, .persisted_bytes = 4000, .nodes = 6, .relations = 6 },
        .{ .fixture_id = "mutation-pruning", .engine = .graphify, .workload = .cold_build, .repetition = 6, .elapsed_ns = 150, .peak_rss_bytes = 1500, .persisted_bytes = 4000, .nodes = 6, .relations = 6 },
        .{ .fixture_id = "mutation-pruning", .engine = .graphify, .workload = .cold_build, .repetition = 7, .elapsed_ns = 160, .peak_rss_bytes = 1600, .persisted_bytes = 4000, .nodes = 6, .relations = 6 },
        .{ .fixture_id = "mutation-pruning", .engine = .zgraphy, .workload = .cold_build, .repetition = 1, .elapsed_ns = 40, .peak_rss_bytes = 400, .persisted_bytes = 2000, .nodes = 9, .relations = 12 },
        .{ .fixture_id = "mutation-pruning", .engine = .zgraphy, .workload = .cold_build, .repetition = 2, .elapsed_ns = 50, .peak_rss_bytes = 500, .persisted_bytes = 2000, .nodes = 9, .relations = 12 },
        .{ .fixture_id = "mutation-pruning", .engine = .zgraphy, .workload = .cold_build, .repetition = 3, .elapsed_ns = 60, .peak_rss_bytes = 600, .persisted_bytes = 2000, .nodes = 9, .relations = 12 },
        .{ .fixture_id = "mutation-pruning", .engine = .zgraphy, .workload = .cold_build, .repetition = 4, .elapsed_ns = 70, .peak_rss_bytes = 700, .persisted_bytes = 2000, .nodes = 9, .relations = 12 },
        .{ .fixture_id = "mutation-pruning", .engine = .zgraphy, .workload = .cold_build, .repetition = 5, .elapsed_ns = 80, .peak_rss_bytes = 800, .persisted_bytes = 2000, .nodes = 9, .relations = 12 },
        .{ .fixture_id = "mutation-pruning", .engine = .zgraphy, .workload = .cold_build, .repetition = 6, .elapsed_ns = 90, .peak_rss_bytes = 900, .persisted_bytes = 2000, .nodes = 9, .relations = 12 },
        .{ .fixture_id = "mutation-pruning", .engine = .zgraphy, .workload = .cold_build, .repetition = 7, .elapsed_ns = 100, .peak_rss_bytes = 1000, .persisted_bytes = 2000, .nodes = 9, .relations = 12 },
    };
    var resources = try zgraphy.ResourceMatrix.build(std.testing.allocator, identity, .{ .warmups = 2, .repetitions = 7 }, &samples);
    defer resources.deinit(std.testing.allocator);
    try zgraphy.ResourceMatrix.validate(&resources);
    const graphify_resources = zgraphy.ResourceMatrix.findAggregate(&resources, .graphify, "mutation-pruning", .cold_build) orelse return error.MissingGraphifyResourceAggregate;
    const native_resources = zgraphy.ResourceMatrix.findAggregate(&resources, .zgraphy, "mutation-pruning", .cold_build) orelse return error.MissingZgraphyResourceAggregate;
    try std.testing.expectEqual(@as(u64, 130), graphify_resources.elapsed_ns.p50);
    try std.testing.expectEqual(@as(u64, 160), graphify_resources.elapsed_ns.p95);
    try std.testing.expectEqual(@as(u64, 70), native_resources.elapsed_ns.p50);
    try std.testing.expectEqual(@as(usize, 0), resources.claims.len);
    try std.testing.expectError(error.IncompleteResourceSamples, zgraphy.ResourceMatrix.build(std.testing.allocator, identity, .{ .warmups = 2, .repetitions = 7 }, samples[0 .. samples.len - 1]));
    const original_elapsed = resources.aggregates[0].elapsed_ns;
    resources.aggregates[0].elapsed_ns.p50 += 1;
    try std.testing.expectError(error.InconsistentResourceAggregate, zgraphy.ResourceMatrix.validate(&resources));
    resources.aggregates[0].elapsed_ns = original_elapsed;
    try zgraphy.ResourceMatrix.validate(&resources);
    var checked_resources = try zgraphy.ResourceMatrix.parseEmbeddedBaseline(std.testing.allocator);
    defer checked_resources.deinit();
    try zgraphy.ResourceMatrix.validate(&checked_resources.value);
    try std.testing.expectEqual(@as(usize, 14), checked_resources.value.samples.len);
    try std.testing.expectEqual(@as(usize, 0), checked_resources.value.claims.len);

    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/catalog.zig", .data = "pub fn feature() []const u8 { return \"catalog-v1\"; }\npub fn orphaned() void {}\n" });
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/main.zig", .data = "const catalog = @import(\"catalog.zig\");\npub fn main() void { _ = catalog.feature(); }\n" });
    var baseline_graph = try zgraphy.Indexer.buildRepository(std.testing.allocator, std.testing.io, tmp.dir, .{});
    defer baseline_graph.deinit();
    try zgraphy.Store.save(std.testing.io, tmp.dir, ".zgraphy/nendb.jsonl", &baseline_graph.graph);
    try tmp.dir.deleteFile(std.testing.io, "src/catalog.zig");
    var deleted_graph = try zgraphy.Indexer.buildRepository(std.testing.allocator, std.testing.io, tmp.dir, .{});
    defer deleted_graph.deinit();
    try zgraphy.Store.save(std.testing.io, tmp.dir, ".zgraphy/nendb.jsonl", &deleted_graph.graph);
    var loaded_deleted = try zgraphy.Store.load(std.testing.allocator, std.testing.io, tmp.dir, ".zgraphy/nendb.jsonl", .{});
    defer loaded_deleted.deinit();
    const deleted_health = zgraphy.Freshness.inspect(&loaded_deleted);
    const deleted_fingerprint = try zgraphy.Freshness.fingerprint(std.testing.allocator, &deleted_graph.graph);
    const loaded_fingerprint = try zgraphy.Freshness.fingerprint(std.testing.allocator, &loaded_deleted);
    try std.testing.expectEqualSlices(u8, &deleted_fingerprint, &loaded_fingerprint);
    try std.testing.expect(loaded_deleted.findNode(zgraphy.stableId(.file, "src/catalog.zig", "catalog.zig")) == null);
    try std.testing.expect(loaded_deleted.findNode(zgraphy.stableId(.symbol, "src/catalog.zig", "feature")) == null);
    try std.testing.expect(deleted_health.clean());

    const transitions = [_]zgraphy.Freshness.Transition{
        .{ .mutation_id = "modify-catalog", .operation = .modify, .before_digest = "sha256:1111111111111111111111111111111111111111111111111111111111111111", .after_digest = "sha256:2222222222222222222222222222222222222222222222222222222222222222", .observed_graph_fingerprint = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", .clean_graph_fingerprint = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", .preserved_expected = 2, .preserved_observed = 2, .invalidated_expected = 1, .invalidated_observed = 0, .persisted_bytes = 2000 },
        .{ .mutation_id = "rename-catalog-to-inventory", .operation = .rename, .before_digest = "sha256:2222222222222222222222222222222222222222222222222222222222222222", .after_digest = "sha256:3333333333333333333333333333333333333333333333333333333333333333", .observed_graph_fingerprint = "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", .clean_graph_fingerprint = "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", .preserved_expected = 2, .preserved_observed = 0, .removed_expected = 1, .removed_observed = 1, .persisted_bytes = 1900 },
        .{ .mutation_id = "delete-inventory", .operation = .delete, .before_digest = "sha256:3333333333333333333333333333333333333333333333333333333333333333", .after_digest = "sha256:4444444444444444444444444444444444444444444444444444444444444444", .observed_graph_fingerprint = "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", .clean_graph_fingerprint = "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", .preserved_expected = 2, .preserved_observed = 2, .removed_expected = 3, .removed_observed = 3, .invalidated_expected = 1, .invalidated_observed = 0, .persisted_bytes = 900 },
    };
    var freshness = try zgraphy.Freshness.build(std.testing.allocator, identity.corpus_digest, &transitions, zgraphy.Freshness.Capabilities.currentM0());
    defer freshness.deinit(std.testing.allocator);
    try zgraphy.Freshness.validate(&freshness);
    try std.testing.expectEqual(zgraphy.Freshness.CapabilityStatus.unsupported, freshness.capabilities.incremental_update);
    try std.testing.expectEqual(zgraphy.Freshness.CapabilityStatus.unsupported, freshness.capabilities.pre_query_refresh);
    try std.testing.expectEqual(@as(usize, 0), freshness.claims.len);
    try std.testing.expect(!freshness.freshness_gate_passed);
    try std.testing.expectError(error.IncompleteFreshnessSequence, zgraphy.Freshness.build(std.testing.allocator, identity.corpus_digest, transitions[0 .. transitions.len - 1], zgraphy.Freshness.Capabilities.currentM0()));
    var false_capabilities = zgraphy.Freshness.Capabilities.currentM0();
    false_capabilities.incremental_update = .supported;
    try std.testing.expectError(error.InvalidFreshnessCapabilities, zgraphy.Freshness.build(std.testing.allocator, identity.corpus_digest, &transitions, false_capabilities));
    var checked_freshness = try zgraphy.Freshness.parseEmbeddedBaseline(std.testing.allocator);
    defer checked_freshness.deinit();
    try zgraphy.Freshness.validate(&checked_freshness.value);
    try std.testing.expect(!checked_freshness.value.freshness_gate_passed);
    try std.testing.expectEqual(@as(usize, 0), checked_freshness.value.transitions[1].preserved_observed);
    try std.testing.expectEqual(@as(usize, 0), checked_freshness.value.transitions[2].invalidated_observed);

    try assertions.boolean(.{
        .id = "zgraphy.m0.resource-quantiles",
        .label = "resource receipts recompute bounded integer quantiles from complete measured samples",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 700, .column = 1 },
        .repair_hint = "reject incomplete or mixed resource samples and derive quantiles from the retained observations",
    }, graphify_resources.elapsed_ns.p50 == 130 and native_resources.elapsed_ns.p50 == 70 and resources.claims.len == 0);
    try assertions.boolean(.{
        .id = "zgraphy.m0.full-rebuild-prunes",
        .label = "a full rebuild removes deleted identities and republishes a complete clean equivalent snapshot",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 700, .column = 1 },
        .repair_hint = "replace the complete snapshot transactionally and reject stale nodes dangling endpoints or unowned vectors",
    }, deleted_health.clean() and loaded_deleted.findNode(zgraphy.stableId(.symbol, "src/catalog.zig", "feature")) == null);
    try assertions.boolean(.{
        .id = "zgraphy.m0.freshness-honesty",
        .label = "the M0 freshness receipt does not claim incremental or automatic pre-query refresh support",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 700, .column = 1 },
        .repair_hint = "keep unsupported capabilities explicit until an exercised updater path matches a clean build",
    }, freshness.capabilities.incremental_update == .unsupported and freshness.capabilities.pre_query_refresh == .unsupported and !freshness.freshness_gate_passed and freshness.claims.len == 0);
    try assertions.noFindings(.{ .id = "zgraphy.m0.resource-freshness-no-findings", .label = "resource and freshness validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m0.resource-freshness-no-pending", .label = "resource and freshness validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy M0 semantic schema ontology is complete versioned and migration safe" {
    const scenario = zstd.Testing.Scenario{
        .id = "m0-semantic-schema-ontology",
        .label = "Schema v2 semantic records provenance ontology compatibility and migration policy validate completely",
        .requirement = "req-m0-semantic-schema-ontology",
        .acceptance_check = "check-m0-semantic-schema-ontology",
        .component = "zgraphy",
        .command = "test",
        .default_seed = 1707,
        .source_roots = &.{ "src/semantic_schema.zig", "src/semantic-schema.v2.json", "docs/schema-v2-rfc.md", "src/model.zig", "src/benchmark.zig", "src/differential.zig", "src/store.zig", "src/project.zig", "src/root.zig", "src/main.zig", "test/all_test.zig" },
        .tags = &.{ "acceptance", "m0", "schema-v2", "ontology", "provenance", "compatibility", "migration", "deterministic" },
    };
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = scenario,
        .seed = 1707,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    var parsed = try zgraphy.SemanticSchema.parseEmbedded(std.testing.allocator);
    defer parsed.deinit();
    try zgraphy.SemanticSchema.validate(&parsed.value);
    try std.testing.expectEqualStrings("zgraphy.semantic-contract.v2", parsed.value.schema);
    try std.testing.expectEqual(@as(u32, 2), parsed.value.schema_version);
    try std.testing.expectEqual(@as(usize, 8), parsed.value.records.len);
    try std.testing.expectEqual(@as(usize, 10), parsed.value.origins.len);
    try std.testing.expectEqual(@as(usize, 7), parsed.value.epistemic_statuses.len);
    try std.testing.expectEqual(zgraphy.SemanticSchema.required_relation_names.len, parsed.value.relations.len);
    for (zgraphy.SemanticSchema.required_relation_names) |name| {
        try std.testing.expect(zgraphy.SemanticSchema.findRelation(&parsed.value, name) != null);
    }

    const call = try zgraphy.SemanticSchema.resolveRelation(&parsed.value, "calls_direct");
    try std.testing.expectEqualStrings("caller", call.source_role);
    try std.testing.expectEqualStrings("callee", call.target_role);
    try std.testing.expectEqual(zgraphy.SemanticSchema.Direction.directed, call.direction);
    try std.testing.expect(call.reverse_traversal);
    try std.testing.expect(call.parallel_instances);
    try std.testing.expectEqual(zgraphy.SemanticSchema.EvidencePolicy.required, call.evidence);
    try std.testing.expect(call.affected.reverse);
    try std.testing.expect(call.affected.default_cost > 0);

    inline for (std.meta.fields(zgraphy.Model.Relation)) |field| {
        try std.testing.expect(zgraphy.SemanticSchema.findCompatibility(&parsed.value, .mvp_v1, field.name) != null);
    }
    inline for (std.meta.fields(zgraphy.Benchmark.RelationKind)) |field| {
        try std.testing.expect(zgraphy.SemanticSchema.findCompatibility(&parsed.value, .benchmark_v1, field.name) != null);
    }
    const mvp_calls = zgraphy.SemanticSchema.findCompatibility(&parsed.value, .mvp_v1, "calls") orelse return error.MissingMvpCallsMapping;
    try std.testing.expectEqualStrings("calls_direct", mvp_calls.target_relation);
    const contract_call = zgraphy.SemanticSchema.findCompatibility(&parsed.value, .benchmark_v1, "invokes_contract") orelse return error.MissingContractCallMapping;
    try std.testing.expectEqualStrings("invokes_operation", contract_call.target_relation);
    try std.testing.expectEqualStrings("zgraphy.nendb.snapshot.v1", parsed.value.migration.source_schema);
    try std.testing.expectEqual(zgraphy.SemanticSchema.MigrationStrategy.rebuild_generation, parsed.value.migration.strategy);
    try std.testing.expect(parsed.value.migration.retain_source_for_rollback);
    try std.testing.expectEqualStrings("zgraphy.nendb.snapshot.v1", zgraphy.Store.schema);
    try std.testing.expectEqual(@as(u32, 1), zgraphy.Store.schema_version);

    const digest = zgraphy.SemanticSchema.contractDigest();
    const digest_hex = std.fmt.bytesToHex(digest, .lower);
    try std.testing.expectEqualStrings("171de155c28b29bbed87b4309e7656411516937aaf4406b3760a0c0737a78881", &digest_hex);
    const original_name = parsed.value.relations[1].name;
    parsed.value.relations[1].name = parsed.value.relations[0].name;
    try std.testing.expectError(error.DuplicateSemanticRelation, zgraphy.SemanticSchema.validate(&parsed.value));
    parsed.value.relations[1].name = original_name;
    const original_family = parsed.value.relations[0].family;
    parsed.value.relations[0].family = "missing-family";
    try std.testing.expectError(error.UnknownRelationFamily, zgraphy.SemanticSchema.validate(&parsed.value));
    parsed.value.relations[0].family = original_family;
    try zgraphy.SemanticSchema.validate(&parsed.value);

    try assertions.boolean(.{
        .id = "zgraphy.m0.schema-v2-complete",
        .label = "schema v2 declares every semantic record provenance axis and initial ontology relation",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 834, .column = 1 },
        .repair_hint = "restore the embedded schema record provenance and required relation registries",
    }, parsed.value.records.len == 8 and parsed.value.origins.len == 10 and parsed.value.epistemic_statuses.len == 7 and parsed.value.relations.len == zgraphy.SemanticSchema.required_relation_names.len);
    try assertions.boolean(.{
        .id = "zgraphy.m0.schema-v2-compatible",
        .label = "every MVP and canonical benchmark relation has an explicit schema-v2 migration mapping while v1 stays readable",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 834, .column = 1 },
        .repair_hint = "add explicit compatibility mappings without changing the current snapshot schema identifier",
    }, std.mem.eql(u8, zgraphy.Store.schema, "zgraphy.nendb.snapshot.v1") and parsed.value.compatibility.len == std.meta.fields(zgraphy.Model.Relation).len + std.meta.fields(zgraphy.Benchmark.RelationKind).len);
    try assertions.noFindings(.{ .id = "zgraphy.m0.schema-v2-no-findings", .label = "semantic schema validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m0.schema-v2-no-pending", .label = "semantic schema validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy M0 operational contracts are capability safe complete and rollback preserving" {
    const scenario = zstd.Testing.Scenario{
        .id = "m0-operational-contracts",
        .label = "Provider conformance configuration health diagnostics and migration contracts are bounded capability safe and rollback preserving",
        .requirement = "req-m0-operational-contracts",
        .acceptance_check = "check-m0-operational-contracts",
        .component = "zgraphy",
        .command = "test",
        .default_seed = 1708,
        .source_roots = &.{ "src/operational_contracts.zig", "src/operational-contracts.v1.json", "docs/operational-contracts-rfc.md", "src/semantic_schema.zig", "src/project.zig", "src/freshness.zig", "src/store.zig", "src/root.zig", "src/main.zig", "test/all_test.zig" },
        .tags = &.{ "acceptance", "m0", "provider", "conformance", "config", "health", "diagnostic", "migration", "authority", "deterministic" },
    };
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = scenario,
        .seed = 1708,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    var parsed = try zgraphy.OperationalContracts.parseEmbedded(std.testing.allocator);
    defer parsed.deinit();
    try zgraphy.OperationalContracts.validate(&parsed.value);
    try std.testing.expectEqualStrings("zgraphy.operational-contracts.v1", parsed.value.schema);
    try std.testing.expectEqual(@as(u32, 1), parsed.value.schema_version);
    try std.testing.expectEqual(zgraphy.OperationalContracts.required_provider_kinds.len, parsed.value.provider.kinds.len);
    try std.testing.expectEqual(zgraphy.OperationalContracts.required_conformance_dimensions.len, parsed.value.conformance.dimensions.len);
    try std.testing.expectEqual(zgraphy.OperationalContracts.required_health_dimensions.len, parsed.value.health.dimensions.len);
    try std.testing.expectEqual(@as(usize, 6), parsed.value.provider.terminal_unit_states.len);
    try std.testing.expect(zgraphy.OperationalContracts.allowsTransition(&parsed.value.provider, .running, .complete));
    try std.testing.expect(zgraphy.OperationalContracts.allowsTransition(&parsed.value.provider, .complete, .stale));
    try std.testing.expect(!zgraphy.OperationalContracts.allowsTransition(&parsed.value.provider, .complete, .running));
    const database_authority = zgraphy.OperationalContracts.findAuthority(&parsed.value.provider, .database_read) orelse return error.MissingDatabaseAuthority;
    try std.testing.expect(database_authority.externally_granted);
    try std.testing.expect(!database_authority.repository_config_allowed);
    const semantic_profile = zgraphy.OperationalContracts.findConformanceProfile(&parsed.value.conformance, .semantic_model) orelse return error.MissingSemanticProfile;
    try std.testing.expect(semantic_profile.no_canonical_mutation);
    try std.testing.expectEqual(parsed.value.conformance.dimensions.len, semantic_profile.required_dimensions.len);
    try std.testing.expectEqual(zgraphy.OperationalContracts.Authority.repository_read, parsed.value.provider.repository_config_max_authority);
    try std.testing.expectEqual(zgraphy.OperationalContracts.FreshnessMode.on_query, parsed.value.config.default_freshness);
    try std.testing.expectEqual(@as(usize, 5), parsed.value.config.precedence.len);
    try std.testing.expectEqual(@as(usize, 6), parsed.value.config.modes.len);
    try std.testing.expectEqual(@as(usize, 6), parsed.value.health.statuses.len);
    try std.testing.expect(parsed.value.health.independent_dimensions);
    try std.testing.expect(parsed.value.health.query_declares_dependencies);
    try std.testing.expect(parsed.value.diagnostic.stdout_result_only);
    try std.testing.expectEqual(zgraphy.OperationalContracts.DiagnosticStream.stderr, parsed.value.diagnostic.stream);
    try std.testing.expect(parsed.value.migration.atomic_publish);
    try std.testing.expect(parsed.value.migration.retain_previous_good);
    try std.testing.expect(parsed.value.migration.publish_requires_validation);
    try std.testing.expect(!parsed.value.migration.in_place);
    const current_config = zgraphy.Project.Config{};
    try std.testing.expectEqualStrings("zgraphy.config.v2", current_config.schema);
    try std.testing.expectEqualStrings("zgraphy.nendb.snapshot.v1", zgraphy.Store.schema);

    const digest = zgraphy.OperationalContracts.contractDigest();
    const digest_hex = std.fmt.bytesToHex(digest, .lower);
    try std.testing.expectEqualStrings("b131864697af63604ff9130768f0156980333ad3a02adb2f8df3bcf11d9100a0", &digest_hex);

    const original_kind = parsed.value.provider.kinds[1].kind;
    parsed.value.provider.kinds[1].kind = parsed.value.provider.kinds[0].kind;
    try std.testing.expectError(error.DuplicateProviderKind, zgraphy.OperationalContracts.validate(&parsed.value));
    parsed.value.provider.kinds[1].kind = original_kind;
    const original_authority = parsed.value.provider.repository_config_max_authority;
    parsed.value.provider.repository_config_max_authority = .network_egress;
    try std.testing.expectError(error.UnsafeRepositoryAuthority, zgraphy.OperationalContracts.validate(&parsed.value));
    parsed.value.provider.repository_config_max_authority = original_authority;
    const original_publish_requirements = parsed.value.migration.publish_requires;
    parsed.value.migration.publish_requires = &.{"schema"};
    try std.testing.expectError(error.IncompleteMigrationValidation, zgraphy.OperationalContracts.validate(&parsed.value));
    parsed.value.migration.publish_requires = original_publish_requirements;
    try zgraphy.OperationalContracts.validate(&parsed.value);

    try assertions.boolean(.{
        .id = "zgraphy.m0.operational-authority",
        .label = "repository configuration cannot grant process network database or model authority",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 924, .column = 1 },
        .repair_hint = "restore externally granted authority policy and the repository-read ceiling",
    }, parsed.value.provider.repository_config_max_authority == .repository_read and database_authority.externally_granted and !database_authority.repository_config_allowed);
    try assertions.boolean(.{
        .id = "zgraphy.m0.operational-fallback",
        .label = "provider and migration failure retain the last complete generation and expose typed partial health",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 924, .column = 1 },
        .repair_hint = "require validated atomic publication rollback retention and explicit partial or degraded provider states",
    }, parsed.value.provider.failure_policy.retain_last_complete_generation and !parsed.value.provider.failure_policy.canonical_overwrite and parsed.value.migration.retain_previous_good and parsed.value.migration.atomic_publish);
    try assertions.noFindings(.{ .id = "zgraphy.m0.operational-no-findings", .label = "operational contract validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m0.operational-no-pending", .label = "operational contract validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy M0 security baseline is pinned complete and evidence honest" {
    const scenario = zstd.Testing.Scenario{
        .id = "m0-security-baseline",
        .label = "Pinned threat catalog and adversarial index cover every trust boundary without overstating unimplemented controls",
        .requirement = "req-m0-security-baseline",
        .acceptance_check = "check-m0-security-baseline",
        .component = "zgraphy",
        .command = "test",
        .default_seed = 1709,
        .source_roots = &.{ "src/security_baseline.zig", "src/security-baseline.v1.json", "docs/threat-model.md", "src/operational_contracts.zig", "src/indexer.zig", "src/store.zig", "src/freshness.zig", "src/root.zig", "src/main.zig", "test/all_test.zig" },
        .tags = &.{ "acceptance", "m0", "security", "threat-model", "adversarial", "graphify", "integrity", "deterministic" },
    };
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = scenario,
        .seed = 1709,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    var parsed = try zgraphy.SecurityBaseline.parseEmbedded(std.testing.allocator);
    defer parsed.deinit();
    try zgraphy.SecurityBaseline.validate(&parsed.value);
    try zgraphy.SecurityBaseline.validateEvidencePaths(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), &parsed.value);
    try std.testing.expectEqualStrings("zgraphy.security-baseline.v1", parsed.value.schema);
    try std.testing.expectEqual(@as(usize, 5), parsed.value.graphify.references.len);
    try std.testing.expectEqual(zgraphy.SecurityBaseline.required_threat_ids.len, parsed.value.threats.len);
    try std.testing.expectEqual(parsed.value.threats.len, parsed.value.fixtures.len);
    const authority = zgraphy.SecurityBaseline.findThreat(&parsed.value, "ZG-THR-015") orelse return error.MissingAuthorityThreat;
    try std.testing.expectEqual(zgraphy.SecurityBaseline.Severity.critical, authority.severity);
    try std.testing.expectEqual(zgraphy.SecurityBaseline.Disposition.contract_only, authority.disposition);
    const summary = zgraphy.SecurityBaseline.summarize(&parsed.value);
    try std.testing.expectEqual(parsed.value.threats.len, summary.total);
    try std.testing.expect(summary.exercised > 0);
    try std.testing.expect(summary.contract_exercised > 0);
    try std.testing.expect(summary.planned > 0);
    try std.testing.expect(summary.deferred > 0);
    try std.testing.expectEqual(@as(usize, 0), summary.unowned_high_or_critical);
    const digest = zgraphy.SecurityBaseline.catalogDigest();
    const digest_hex = std.fmt.bytesToHex(digest, .lower);
    try std.testing.expectEqualStrings("5cf030049fb9f9ce93e20b3efe78820de690f41edf91bd97e526b14dd7dc6412", &digest_hex);

    const original_id = parsed.value.threats[1].id;
    parsed.value.threats[1].id = parsed.value.threats[0].id;
    try std.testing.expectError(error.DuplicateThreat, zgraphy.SecurityBaseline.validate(&parsed.value));
    parsed.value.threats[1].id = original_id;
    const original_refs = parsed.value.fixtures[0].threat_ids;
    parsed.value.fixtures[0].threat_ids = &.{"ZG-THR-999"};
    try std.testing.expectError(error.UnknownThreatReference, zgraphy.SecurityBaseline.validate(&parsed.value));
    parsed.value.fixtures[0].threat_ids = original_refs;
    const original_disposition = parsed.value.threats[0].disposition;
    parsed.value.threats[0].disposition = .mitigated;
    try std.testing.expectError(error.FalseSecurityPromotion, zgraphy.SecurityBaseline.validate(&parsed.value));
    parsed.value.threats[0].disposition = original_disposition;
    try zgraphy.SecurityBaseline.validate(&parsed.value);

    try assertions.boolean(.{
        .id = "zgraphy.m0.security-complete",
        .label = "every threat has controls fixtures residual risk and a milestone owner across every trust boundary",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1015, .column = 1 },
        .repair_hint = "restore the exact threat catalog cross-references and high-risk milestone ownership",
    }, summary.total == 20 and summary.unowned_high_or_critical == 0);
    try assertions.boolean(.{
        .id = "zgraphy.m0.security-honest",
        .label = "planned and deferred fixtures remain distinct from exercised runtime or contract evidence",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1015, .column = 1 },
        .repair_hint = "do not promote a threat until an existing required scenario exercises its runtime boundary",
    }, summary.planned > 0 and summary.deferred > 0 and summary.exercised + summary.contract_exercised < summary.total);
    try assertions.noFindings(.{ .id = "zgraphy.m0.security-no-findings", .label = "security baseline validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m0.security-no-pending", .label = "security baseline validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy M0 evaluation contracts and exit evidence are complete and claim honest" {
    const scenario = zstd.Testing.Scenario{
        .id = "m0-evaluation-contracts-exit",
        .label = "Five evaluation receipt contracts and every M0 exit criterion validate without unsupported claims",
        .requirement = "req-m0-evaluation-contracts-exit",
        .acceptance_check = "check-m0-evaluation-contracts-exit",
        .component = "zgraphy",
        .command = "test",
        .default_seed = 1710,
        .source_roots = &.{ "src/evaluation_contracts.zig", "src/evaluation-contracts.v1.json", "src/differential.zig", "src/quality_matrix.zig", "src/resource_matrix.zig", "src/freshness.zig", "src/benchmark.zig", "src/parity.zig", "src/semantic_schema.zig", "src/operational_contracts.zig", "src/security_baseline.zig", "benchmarks/run_graphify_reference.sh", "benchmarks/baselines", "docs/schema-v2-rfc.md", "src/root.zig", "src/main.zig", "test/all_test.zig" },
        .tags = &.{ "acceptance", "m0", "evaluation", "retrieval", "agent-task", "performance", "resource", "exit-audit", "deterministic" },
    };
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = scenario,
        .seed = 1710,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    var contracts = try zgraphy.EvaluationContracts.parseEmbedded(std.testing.allocator);
    defer contracts.deinit();
    try zgraphy.EvaluationContracts.validate(&contracts.value);
    try std.testing.expectEqualStrings("zgraphy.evaluation-contracts.v1", contracts.value.schema);
    try std.testing.expectEqual(zgraphy.EvaluationContracts.required_kinds.len, contracts.value.definitions.len);
    const extraction = zgraphy.EvaluationContracts.findDefinition(&contracts.value, .extraction) orelse return error.MissingExtractionEvaluation;
    const retrieval = zgraphy.EvaluationContracts.findDefinition(&contracts.value, .retrieval) orelse return error.MissingRetrievalEvaluation;
    const agent_task = zgraphy.EvaluationContracts.findDefinition(&contracts.value, .agent_task) orelse return error.MissingAgentTaskEvaluation;
    const performance = zgraphy.EvaluationContracts.findDefinition(&contracts.value, .performance) orelse return error.MissingPerformanceEvaluation;
    const resource = zgraphy.EvaluationContracts.findDefinition(&contracts.value, .resource) orelse return error.MissingResourceEvaluation;
    try std.testing.expectEqualStrings(zgraphy.Differential.schema, extraction.receipt_schema);
    try std.testing.expectEqualStrings(zgraphy.ResourceMatrix.schema, resource.receipt_schema);
    try std.testing.expectEqual(zgraphy.EvaluationContracts.EvidenceState.schema_only, retrieval.evidence_state);
    try std.testing.expectEqual(zgraphy.EvaluationContracts.EvidenceState.schema_only, agent_task.evidence_state);
    try std.testing.expect(agent_task.controlled_arms_required);
    try std.testing.expect(agent_task.held_out_required);
    try std.testing.expect(agent_task.unsupported_claims_forbidden);
    try std.testing.expect(performance.correctness_required);
    try std.testing.expect(containsString(agent_task.metrics, "task_success"));
    try std.testing.expect(containsString(agent_task.metrics, "context_bytes"));
    try std.testing.expect(containsString(retrieval.metrics, "proof_faithfulness"));
    try std.testing.expect(containsString(performance.metrics, "peak_rss_bytes"));
    try std.testing.expectEqual(zgraphy.EvaluationContracts.ClaimMaturity.baseline_only, contracts.value.claim_policy.maturity);
    try std.testing.expect(!contracts.value.claim_policy.schema_only_eligible);

    var corpus = try zgraphy.Benchmark.parseEmbeddedCorpus(std.testing.allocator);
    defer corpus.deinit();
    try zgraphy.Benchmark.validateCorpus(&corpus.value);
    const first_corpus_digest = zgraphy.Benchmark.canonicalCorpusDigest();
    const second_corpus_digest = zgraphy.Benchmark.canonicalCorpusDigest();
    try std.testing.expectEqualSlices(u8, &first_corpus_digest, &second_corpus_digest);
    var parity = try zgraphy.Parity.parseEmbedded(std.testing.allocator);
    defer parity.deinit();
    try zgraphy.Parity.validate(&parity.value);
    var quality = try zgraphy.QualityMatrix.parseEmbeddedBaseline(std.testing.allocator);
    defer quality.deinit();
    try zgraphy.QualityMatrix.validate(&quality.value);
    var resources = try zgraphy.ResourceMatrix.parseEmbeddedBaseline(std.testing.allocator);
    defer resources.deinit();
    try zgraphy.ResourceMatrix.validate(&resources.value);
    var freshness = try zgraphy.Freshness.parseEmbeddedBaseline(std.testing.allocator);
    defer freshness.deinit();
    try zgraphy.Freshness.validate(&freshness.value);
    var semantic = try zgraphy.SemanticSchema.parseEmbedded(std.testing.allocator);
    defer semantic.deinit();
    try zgraphy.SemanticSchema.validate(&semantic.value);
    var operational = try zgraphy.OperationalContracts.parseEmbedded(std.testing.allocator);
    defer operational.deinit();
    try zgraphy.OperationalContracts.validate(&operational.value);
    var security = try zgraphy.SecurityBaseline.parseEmbedded(std.testing.allocator);
    defer security.deinit();
    try zgraphy.SecurityBaseline.validate(&security.value);
    try zgraphy.SecurityBaseline.validateEvidencePaths(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), &security.value);
    try std.Io.Dir.cwd().access(std.testing.io, "benchmarks/run_graphify_reference.sh", .{});
    try std.testing.expectEqual(@as(usize, 3), quality.value.fixtures.len);
    try std.testing.expectEqual(@as(usize, 0), quality.value.claims.len);
    try std.testing.expectEqual(@as(usize, 0), resources.value.claims.len);
    try std.testing.expectEqual(@as(usize, 0), freshness.value.claims.len);
    for (freshness.value.transitions) |transition| {
        try std.testing.expect(transition.canonical_equivalent);
        try std.testing.expect(transition.snapshot_complete);
    }
    try std.testing.expect(!freshness.value.freshness_gate_passed);

    const digest = zgraphy.EvaluationContracts.contractDigest();
    const digest_hex = std.fmt.bytesToHex(digest, .lower);
    try std.testing.expectEqualStrings("e2c04bdc4cb2d8c4d46783f9a48b80576d37dcf767704ecaf0f0571617b1e971", &digest_hex);
    const original_kind = contracts.value.definitions[1].kind;
    contracts.value.definitions[1].kind = contracts.value.definitions[0].kind;
    try std.testing.expectError(error.DuplicateEvaluationKind, zgraphy.EvaluationContracts.validate(&contracts.value));
    contracts.value.definitions[1].kind = original_kind;
    const original_metrics = contracts.value.definitions[2].metrics;
    contracts.value.definitions[2].metrics = &.{};
    try std.testing.expectError(error.MissingEvaluationMetrics, zgraphy.EvaluationContracts.validate(&contracts.value));
    contracts.value.definitions[2].metrics = original_metrics;
    try zgraphy.EvaluationContracts.validate(&contracts.value);

    try assertions.boolean(.{
        .id = "zgraphy.m0.evaluation-five-contracts",
        .label = "extraction retrieval agent-task performance and resource receipts have explicit complete claim-gated schemas",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1089, .column = 1 },
        .repair_hint = "restore all five definitions and the controlled agent/retrieval/performance evidence fields",
    }, contracts.value.definitions.len == 5 and agent_task.controlled_arms_required and performance.correctness_required);
    try assertions.boolean(.{
        .id = "zgraphy.m0.exit-evidence",
        .label = "all M0 baselines ontology compatibility parity and deterministic facts validate without superiority claims",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1089, .column = 1 },
        .repair_hint = "repair the failing embedded baseline or keep M0 active with the exact missing exit evidence",
    }, quality.value.claims.len == 0 and resources.value.claims.len == 0 and freshness.value.claims.len == 0 and std.mem.eql(u8, parity.value.baseline.commit, zgraphy.Parity.pinned_graphify_commit));
    try assertions.noFindings(.{ .id = "zgraphy.m0.evaluation-no-findings", .label = "M0 evaluation and exit validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m0.evaluation-no-pending", .label = "M0 evaluation and exit validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

fn containsString(values: []const []const u8, wanted: []const u8) bool {
    for (values) |value| if (std.mem.eql(u8, value, wanted)) return true;
    return false;
}

test "zgraphy M1 universal discovery is deterministic complete and placement preserving" {
    const scenario = zstd.Testing.Scenario{
        .id = "m1-universal-discovery",
        .label = "Mixed-language discovery is deterministic complete placement-preserving and terminally accountable",
        .requirement = "req-m1-universal-discovery",
        .acceptance_check = "check-m1-universal-discovery",
        .component = "zgraphy",
        .command = "test",
        .default_seed = 1801,
        .source_roots = &.{ "src/discovery.zig", "src/indexer.zig", "src/model.zig", "src/project.zig", "src/store.zig", "test/fixtures/universal-discovery", "src/root.zig", "src/main.zig", "test/all_test.zig" },
        .tags = &.{ "acceptance", "m1", "discovery", "classification", "placement", "manifest", "security", "deterministic" },
    };
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = scenario,
        .seed = 1801,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    var fixture = try std.Io.Dir.cwd().openDir(std.testing.io, "test/fixtures/universal-discovery", .{ .iterate = true, .follow_symlinks = false });
    defer fixture.close(std.testing.io);
    const options = zgraphy.Discovery.Options{
        .repository_id = "repo-0123456789abcdef0123456789abcdef",
        .max_entries = 128,
        .max_files = 64,
        .max_file_bytes = 64 * 1024,
        .max_total_bytes = 1024 * 1024,
        .max_depth = 16,
    };
    var first = try zgraphy.Discovery.scan(std.testing.allocator, std.testing.io, fixture, options);
    defer first.deinit();
    var second = try zgraphy.Discovery.scan(std.testing.allocator, std.testing.io, fixture, options);
    defer second.deinit();
    try zgraphy.Discovery.validate(&first);
    try zgraphy.Discovery.validate(&second);
    try std.testing.expectEqualSlices(u8, &first.manifest_digest, &second.manifest_digest);
    try std.testing.expectEqual(first.records.len, first.summary.total);
    try std.testing.expect(first.reconciles());
    try std.testing.expectEqual(@as(usize, 4), first.summary.deeply_indexed);
    try std.testing.expect(first.summary.placed_unsupported >= 6);
    try std.testing.expectEqual(@as(usize, 1), first.summary.excluded_sensitive);
    try std.testing.expectEqual(@as(usize, 2), first.summary.ignored_rule);
    const typescript = first.findByPath("frontend/app.ts") orelse return error.MissingTypeScriptDiscovery;
    try std.testing.expectEqual(zgraphy.Discovery.Language.typescript, typescript.classification.language);
    try std.testing.expectEqual(zgraphy.Discovery.Disposition.deeply_indexed, typescript.disposition);
    const proto = first.findByPath("proto/order.proto") orelse return error.MissingProtoDiscovery;
    try std.testing.expectEqual(zgraphy.Discovery.Artifact.protocol, proto.classification.artifact);
    const unknown = first.findByPath("unknown/data.weird") orelse return error.MissingUnknownDiscovery;
    try std.testing.expectEqual(zgraphy.Discovery.Language.unknown, unknown.classification.language);
    for (first.records) |record| if (record.disposition == .excluded_sensitive) {
        try std.testing.expectEqual(@as(usize, 0), record.relative_path.len);
        try std.testing.expect(record.content_digest == null);
    };

    var graph = try zgraphy.RepositoryGraph.init(std.testing.allocator, .{});
    defer graph.deinit();
    try zgraphy.Discovery.materialize(&graph, &first);
    try zgraphy.Indexer.indexZigSource(&graph, "src/main.zig", "pub fn main() void {}\n");
    const app_id = zgraphy.stableId(.file, "frontend/app.ts", "app.ts");
    try std.testing.expect(graph.findNode(app_id) != null);
    const zig_file_id = zgraphy.stableId(.file, "src/main.zig", "main.zig");
    try std.testing.expect(graph.findNode(zig_file_id) != null);
    var zig_file_count: usize = 0;
    for (graph.nodes.items) |node| {
        if (node.id == zig_file_id) zig_file_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), zig_file_count);

    var built = try zgraphy.Indexer.buildRepository(std.testing.allocator, std.testing.io, fixture, .{});
    defer built.deinit();
    try std.testing.expect(built.graph.findNode(app_id) != null);
    try std.testing.expectEqual(first.manifest_digest, built.summary.discovery_manifest_digest);
    try std.testing.expectEqual(first.summary.total, built.summary.discovery.total);
    try std.testing.expectEqual(@as(usize, 4), built.summary.discovery.deeply_indexed);

    var initialized = std.testing.tmpDir(.{ .iterate = true });
    defer initialized.cleanup();
    try std.testing.expectEqual(zgraphy.Project.InitStatus.initialized, try zgraphy.Project.init(std.testing.allocator, std.testing.io, initialized.dir));
    var initialized_config = try zgraphy.Project.loadConfig(std.testing.allocator, std.testing.io, initialized.dir);
    defer initialized_config.deinit();
    try std.testing.expectEqualStrings("zgraphy.config.v2", initialized_config.value.schema);
    try std.testing.expect(zgraphy.Discovery.isValidRepositoryId(initialized_config.value.repository_id));
    try std.testing.expectEqual(zgraphy.Project.InitStatus.already_initialized, try zgraphy.Project.init(std.testing.allocator, std.testing.io, initialized.dir));
    var repeated_config = try zgraphy.Project.loadConfig(std.testing.allocator, std.testing.io, initialized.dir);
    defer repeated_config.deinit();
    try std.testing.expectEqualStrings(initialized_config.value.repository_id, repeated_config.value.repository_id);

    var legacy = std.testing.tmpDir(.{ .iterate = true });
    defer legacy.cleanup();
    try legacy.dir.createDirPath(std.testing.io, ".zgraphy");
    try legacy.dir.writeFile(std.testing.io, .{
        .sub_path = zgraphy.Project.config_path,
        .data = "{\"schema\":\"zgraphy.config.v1\",\"schema_version\":1,\"database\":\".zgraphy/custom.jsonl\",\"max_files\":321,\"max_file_bytes\":65536,\"max_source_bytes\":1048576,\"max_nodes\":654,\"max_edges\":987}",
    });
    var migrated_config = try zgraphy.Project.loadConfig(std.testing.allocator, std.testing.io, legacy.dir);
    defer migrated_config.deinit();
    try std.testing.expectEqualStrings("zgraphy.config.v2", migrated_config.value.schema);
    try std.testing.expect(zgraphy.Discovery.isValidRepositoryId(migrated_config.value.repository_id));
    try std.testing.expectEqual(@as(usize, 321), migrated_config.value.max_files);
    try std.testing.expectEqualStrings(".zgraphy/custom.jsonl", migrated_config.value.database);

    try assertions.boolean(.{
        .id = "zgraphy.m1.discovery-accounted",
        .label = "every observed mixed-language input reaches one responsible terminal disposition",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1209, .column = 1 },
        .repair_hint = "reconcile every walk record and keep ignored sensitive unsupported and failed inputs distinct",
    }, first.reconciles() and first.summary.total == first.records.len and first.summary.excluded_sensitive == 1 and first.summary.ignored_rule == 2);
    try assertions.boolean(.{
        .id = "zgraphy.m1.discovery-placement",
        .label = "unsupported safe files remain queryable placement nodes and Zig extraction reuses the same file identity",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1209, .column = 1 },
        .repair_hint = "materialize complete placement hierarchy before adding language-specific facts",
    }, graph.findNode(app_id) != null and built.graph.findNode(app_id) != null and zig_file_count == 1);
    try assertions.boolean(.{
        .id = "zgraphy.m1.repository-identity",
        .label = "init preserves one opaque repository identity and legacy migration preserves user limits",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1209, .column = 1 },
        .repair_hint = "generate repository identity once and migrate configuration additively and atomically",
    }, zgraphy.Discovery.isValidRepositoryId(initialized_config.value.repository_id) and std.mem.eql(u8, initialized_config.value.repository_id, repeated_config.value.repository_id) and migrated_config.value.max_files == 321);
    try assertions.noFindings(.{ .id = "zgraphy.m1.discovery-no-findings", .label = "universal discovery validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m1.discovery-no-pending", .label = "universal discovery validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy M1 workspace ownership assigns every safe file to the deepest explicit unit" {
    const scenario = zstd.Testing.Scenario{
        .id = "m1-workspace-ownership",
        .label = "Manifest adapters assign every safe file one deepest workspace-aware owner",
        .requirement = "req-m1-workspace-ownership",
        .acceptance_check = "check-m1-workspace-ownership",
        .component = "zgraphy",
        .command = "test",
        .default_seed = 1802,
        .source_roots = &.{ "src/ownership.zig", "src/discovery.zig", "src/indexer.zig", "src/model.zig", "test/fixtures/universal-discovery", "src/root.zig", "src/main.zig", "test/all_test.zig" },
        .tags = &.{ "acceptance", "m1", "workspace", "ownership", "manifest", "zig", "typescript", "python", "rust", "go", "proto", "deterministic" },
    };
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = scenario,
        .seed = 1802,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    var fixture = try std.Io.Dir.cwd().openDir(std.testing.io, "test/fixtures/universal-discovery", .{ .iterate = true, .follow_symlinks = false });
    defer fixture.close(std.testing.io);
    var discovered = try zgraphy.Discovery.scan(std.testing.allocator, std.testing.io, fixture, .{
        .repository_id = "repo-0123456789abcdef0123456789abcdef",
        .max_entries = 256,
        .max_files = 128,
        .max_file_bytes = 64 * 1024,
        .max_total_bytes = 2 * 1024 * 1024,
        .max_depth = 24,
    });
    defer discovered.deinit();
    var ownership = try zgraphy.Ownership.analyze(std.testing.allocator, std.testing.io, fixture, &discovered, .{});
    defer ownership.deinit();
    try zgraphy.Ownership.validate(&discovered, &ownership);
    const placed_files = discovered.summary.deeply_indexed + discovered.summary.placed_unsupported + discovered.summary.placed_asset;
    try std.testing.expectEqual(placed_files, ownership.summary.assignments);
    try std.testing.expect(ownership.summary.adapters_succeeded >= 6);
    try std.testing.expectEqual(@as(usize, 1), ownership.summary.nested_repositories);

    const frontend = ownership.findAssignment("frontend/app.ts") orelse return error.MissingFrontendOwnership;
    try std.testing.expectEqual(zgraphy.Ownership.UnitKind.application, frontend.owner_kind);
    try std.testing.expectEqualStrings("web-console", frontend.owner_label);
    const rust = ownership.findAssignment("crates/core/src/lib.rs") orelse return error.MissingRustOwnership;
    try std.testing.expectEqual(zgraphy.Ownership.UnitKind.library, rust.owner_kind);
    try std.testing.expectEqualStrings("core-engine", rust.owner_label);
    const linked = ownership.findAssignment("vendor/linked/README.txt") orelse return error.MissingNestedRepositoryOwnership;
    try std.testing.expectEqual(zgraphy.Ownership.UnitKind.nested_repository, linked.owner_kind);
    const proto = ownership.findAssignment("proto/order.proto") orelse return error.MissingProtoOwnership;
    try std.testing.expectEqual(zgraphy.Ownership.Provider.buf, proto.provider);

    var graph = try zgraphy.RepositoryGraph.init(std.testing.allocator, .{});
    defer graph.deinit();
    try zgraphy.Discovery.materialize(&graph, &discovered);
    try zgraphy.Ownership.materialize(&graph, &discovered, &ownership);
    const app = graph.findNodeByLabel("web-console") orelse return error.MissingApplicationNode;
    const app_file_id = zgraphy.stableId(.file, "frontend/app.ts", "app.ts");
    try std.testing.expect(graph.hasEdge(app_file_id, app.id, .owned_by));

    var built = try zgraphy.Indexer.buildRepository(std.testing.allocator, std.testing.io, fixture, .{});
    defer built.deinit();
    try std.testing.expectEqual(placed_files, built.summary.ownership.assignments);
    const built_app = built.graph.findNodeByLabel("web-console") orelse return error.MissingBuiltApplicationNode;
    try std.testing.expect(built.graph.hasEdge(app_file_id, built_app.id, .owned_by));

    try assertions.boolean(.{
        .id = "zgraphy.m1.ownership-complete",
        .label = "every safe placed file has exactly one deepest explicit owner",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1335, .column = 1 },
        .repair_hint = "reconcile placement records against deterministic deepest-root assignments",
    }, ownership.summary.assignments == placed_files and ownership.reconciles(&discovered));
    try assertions.boolean(.{
        .id = "zgraphy.m1.ownership-adapters",
        .label = "Zig JavaScript Python Rust Go Proto and nested repository adapters preserve useful ownership",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1335, .column = 1 },
        .repair_hint = "repair manifest provider detection without replacing canonical source identities",
    }, ownership.summary.adapters_succeeded >= 6 and ownership.summary.nested_repositories == 1 and built.graph.hasEdge(app_file_id, built_app.id, .owned_by));
    try assertions.noFindings(.{ .id = "zgraphy.m1.ownership-no-findings", .label = "workspace ownership validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m1.ownership-no-pending", .label = "workspace ownership validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy M1 discovery hardening keeps nested ignore negations and adversarial inputs typed" {
    const scenario = zstd.Testing.Scenario{
        .id = "m1-discovery-hardening",
        .label = "Nested ignore and adversarial filesystem inputs remain bounded typed and attributable",
        .requirement = "req-m1-discovery-hardening",
        .acceptance_check = "check-m1-discovery-hardening",
        .component = "zgraphy",
        .command = "test",
        .default_seed = 1803,
        .source_roots = &.{ "src/discovery.zig", "test/fixtures/universal-discovery/frontend/.gitignore", "test/fixtures/universal-discovery/frontend/generated", "src/root.zig", "src/main.zig", "test/all_test.zig" },
        .tags = &.{ "acceptance", "m1", "discovery", "ignore", "sensitive", "binary", "oversized", "symlink", "limits", "security", "deterministic" },
    };
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = scenario,
        .seed = 1803,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    var fixture = try std.Io.Dir.cwd().openDir(std.testing.io, "test/fixtures/universal-discovery", .{ .iterate = true, .follow_symlinks = false });
    defer fixture.close(std.testing.io);
    var nested = try zgraphy.Discovery.scan(std.testing.allocator, std.testing.io, fixture, .{
        .repository_id = "repo-0123456789abcdef0123456789abcdef",
        .max_entries = 256,
        .max_files = 128,
        .max_file_bytes = 64 * 1024,
        .max_total_bytes = 2 * 1024 * 1024,
        .max_depth = 24,
    });
    defer nested.deinit();
    const dropped = nested.findByPath("frontend/generated/drop.ts") orelse return error.MissingNestedIgnoredRecord;
    try std.testing.expectEqual(zgraphy.Discovery.Disposition.ignored_rule, dropped.disposition);
    try std.testing.expect(std.mem.startsWith(u8, dropped.responsible, "ignore:frontend/.gitignore:1"));
    const retained = nested.findByPath("frontend/generated/keep.ts") orelse return error.MissingNestedNegationRecord;
    try std.testing.expectEqual(zgraphy.Discovery.Disposition.deeply_indexed, retained.disposition);

    var hostile = std.testing.tmpDir(.{ .iterate = true });
    defer hostile.cleanup();
    try hostile.dir.writeFile(std.testing.io, .{ .sub_path = "safe.txt", .data = "safe text\n" });
    try hostile.dir.writeFile(std.testing.io, .{ .sub_path = "binary.dat", .data = "prefix\x00payload" });
    var oversized_bytes: [64]u8 = @splat('x');
    try hostile.dir.writeFile(std.testing.io, .{ .sub_path = "oversized.txt", .data = &oversized_bytes });
    try hostile.dir.writeFile(std.testing.io, .{ .sub_path = ".env.local", .data = "SECRET=must-not-hash\n" });
    try hostile.dir.symLink(std.testing.io, "safe.txt", "internal-link.txt", .{});
    try hostile.dir.symLink(std.testing.io, "/etc/passwd", "external-link.txt", .{});
    var adversarial = try zgraphy.Discovery.scan(std.testing.allocator, std.testing.io, hostile.dir, .{
        .repository_id = "repo-fedcba9876543210fedcba9876543210",
        .max_entries = 32,
        .max_files = 16,
        .max_file_bytes = 32,
        .max_total_bytes = 1024,
        .max_depth = 8,
    });
    defer adversarial.deinit();
    try zgraphy.Discovery.validate(&adversarial);
    try std.testing.expectEqual(@as(usize, 1), adversarial.summary.excluded_sensitive);
    try std.testing.expectEqual(@as(usize, 1), adversarial.summary.excluded_binary);
    try std.testing.expectEqual(@as(usize, 1), adversarial.summary.excluded_oversized);
    try std.testing.expectEqual(@as(usize, 2), adversarial.summary.symlink_not_followed);
    for (adversarial.records) |record| {
        try std.testing.expect(record.responsible.len > 0);
        if (record.relative_path.len > 0) try std.testing.expect(!std.fs.path.isAbsolute(record.relative_path));
        if (record.disposition == .excluded_sensitive) {
            try std.testing.expectEqual(@as(usize, 0), record.relative_path.len);
            try std.testing.expect(record.content_digest == null);
        }
    }
    try std.testing.expectError(error.DiscoveryEntryLimitExceeded, zgraphy.Discovery.scan(std.testing.allocator, std.testing.io, hostile.dir, .{
        .repository_id = "repo-fedcba9876543210fedcba9876543210",
        .max_entries = 1,
        .max_files = 16,
        .max_file_bytes = 32,
        .max_total_bytes = 1024,
        .max_depth = 8,
    }));

    try assertions.boolean(.{
        .id = "zgraphy.m1.ignore-nested-negation",
        .label = "nested last-match ignore rules exclude and re-include only their anchored subtree",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1417, .column = 1 },
        .repair_hint = "load each directory ignore file before visiting children and retain the responsible source line",
    }, dropped.disposition == .ignored_rule and retained.disposition == .deeply_indexed and std.mem.startsWith(u8, dropped.responsible, "ignore:frontend/.gitignore:1"));
    try assertions.boolean(.{
        .id = "zgraphy.m1.adversarial-terminal-outcomes",
        .label = "sensitive binary oversized and symlink inputs have distinct bounded terminal outcomes",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1417, .column = 1 },
        .repair_hint = "apply name and file-kind policy before content reads and preserve typed failure accounting",
    }, adversarial.reconciles() and adversarial.summary.excluded_sensitive == 1 and adversarial.summary.excluded_binary == 1 and adversarial.summary.excluded_oversized == 1 and adversarial.summary.symlink_not_followed == 2);
    try assertions.noFindings(.{ .id = "zgraphy.m1.hardening-no-findings", .label = "adversarial discovery validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m1.hardening-no-pending", .label = "adversarial discovery validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy M1 operational baseline publishes deterministic evidence and diagnoses staleness" {
    const scenario = zstd.Testing.Scenario{
        .id = "m1-operational-baseline",
        .label = "Deterministic build evidence effective config and doctor freshness are machine clean",
        .requirement = "req-m1-operational-baseline",
        .acceptance_check = "check-m1-operational-baseline",
        .component = "zgraphy",
        .command = "test",
        .default_seed = 1804,
        .source_roots = &.{ "src/operations.zig", "src/project.zig", "src/discovery.zig", "src/ownership.zig", "src/indexer.zig", "src/store.zig", "src/freshness.zig", "src/root.zig", "src/main.zig", "test/all_test.zig" },
        .tags = &.{ "acceptance", "m1", "manifest", "config", "health", "doctor", "freshness", "diagnostic", "atomic", "deterministic" },
    };
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = scenario,
        .seed = 1804,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/main.zig", .data = "pub fn main() void {}\n" });
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "notes.txt", .data = "agent orientation\n" });
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = ".env.local", .data = "SECRET=must-never-persist\n" });
    try std.testing.expectEqual(zgraphy.Project.InitStatus.initialized, try zgraphy.Project.init(std.testing.allocator, std.testing.io, tmp.dir));
    var config = try zgraphy.Project.loadConfig(std.testing.allocator, std.testing.io, tmp.dir);
    defer config.deinit();

    var first = try zgraphy.Indexer.buildRepository(std.testing.allocator, std.testing.io, tmp.dir, zgraphy.Operations.buildOptions(config.value));
    defer first.deinit();
    try zgraphy.Store.save(std.testing.io, tmp.dir, config.value.database, &first.graph);
    try zgraphy.Operations.publish(std.testing.allocator, std.testing.io, tmp.dir, config.value, &first);
    const first_manifest = try tmp.dir.readFileAlloc(std.testing.io, config.value.content_manifest, std.testing.allocator, .limited(4 * 1024 * 1024));
    defer std.testing.allocator.free(first_manifest);
    const first_health = try tmp.dir.readFileAlloc(std.testing.io, config.value.health_report, std.testing.allocator, .limited(1024 * 1024));
    defer std.testing.allocator.free(first_health);
    try std.testing.expect(std.mem.indexOf(u8, first_manifest, "must-never-persist") == null);
    try std.testing.expect(std.mem.indexOf(u8, first_manifest, ".env.local") == null);
    try std.testing.expect(std.mem.indexOf(u8, first_manifest, "/Users/") == null);

    var second = try zgraphy.Indexer.buildRepository(std.testing.allocator, std.testing.io, tmp.dir, zgraphy.Operations.buildOptions(config.value));
    defer second.deinit();
    try zgraphy.Store.save(std.testing.io, tmp.dir, config.value.database, &second.graph);
    try zgraphy.Operations.publish(std.testing.allocator, std.testing.io, tmp.dir, config.value, &second);
    const second_manifest = try tmp.dir.readFileAlloc(std.testing.io, config.value.content_manifest, std.testing.allocator, .limited(4 * 1024 * 1024));
    defer std.testing.allocator.free(second_manifest);
    const second_health = try tmp.dir.readFileAlloc(std.testing.io, config.value.health_report, std.testing.allocator, .limited(1024 * 1024));
    defer std.testing.allocator.free(second_health);
    try std.testing.expectEqualSlices(u8, first_manifest, second_manifest);
    try std.testing.expectEqualSlices(u8, first_health, second_health);

    const effective = zgraphy.Operations.effectiveConfig(config.value);
    try std.testing.expectEqualStrings(config.value.repository_id, effective.config.repository_id);
    try std.testing.expect(effective.fields.len >= 10);
    for (effective.fields) |field| try std.testing.expectEqual(zgraphy.Operations.ConfigSource.repository, field.source);
    var clean = try zgraphy.Operations.doctor(std.testing.allocator, std.testing.io, tmp.dir, config.value);
    try std.testing.expectEqual(zgraphy.Operations.HealthStatus.healthy, clean.status);
    try std.testing.expect(clean.ready);
    try std.testing.expectEqual(@as(usize, 0), clean.diagnostics().len);
    const clean_json = try zgraphy.Operations.encodeDoctorAlloc(std.testing.allocator, config.value, &clean);
    defer std.testing.allocator.free(clean_json);
    var parsed_clean = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, clean_json, .{});
    defer parsed_clean.deinit();

    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/main.zig", .data = "pub fn main() void { changed(); }\nfn changed() void {}\n" });
    var stale = try zgraphy.Operations.doctor(std.testing.allocator, std.testing.io, tmp.dir, config.value);
    try std.testing.expectEqual(zgraphy.Operations.HealthStatus.stale, stale.status);
    try std.testing.expect(!stale.ready);
    try std.testing.expectEqualStrings("source_manifest_changed", stale.diagnostics()[0].code);
    const stale_json = try zgraphy.Operations.encodeDoctorAlloc(std.testing.allocator, config.value, &stale);
    defer std.testing.allocator.free(stale_json);
    try std.testing.expect(std.mem.indexOf(u8, stale_json, "/Users/") == null);
    try std.testing.expect(std.mem.indexOf(u8, stale_json, "must-never-persist") == null);

    try assertions.boolean(.{
        .id = "zgraphy.m1.operational-deterministic",
        .label = "repeated clean builds publish byte-identical redacted content and health evidence",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1512, .column = 1 },
        .repair_hint = "remove timestamps and host paths and bind publication to sorted discovery and ownership manifests",
    }, std.mem.eql(u8, first_manifest, second_manifest) and std.mem.eql(u8, first_health, second_health));
    try assertions.boolean(.{
        .id = "zgraphy.m1.doctor-freshness",
        .label = "doctor distinguishes ready clean state from typed source staleness with effective config authority",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1512, .column = 1 },
        .repair_hint = "compare the current bounded manifest to the published generation and emit source_manifest_changed",
    }, clean.status == .healthy and clean.ready and stale.status == .stale and !stale.ready and effective.fields.len >= 10);
    try assertions.noFindings(.{ .id = "zgraphy.m1.operational-no-findings", .label = "operational baseline validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m1.operational-no-pending", .label = "operational baseline validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy M2 Zig parser boundary emits exact AST facts without lexical false positives" {
    const scenario = zstd.Testing.Scenario{
        .id = "m2-zig-parser-boundary",
        .label = "Compiler AST emits exact bounded Zig structural facts without lexical false positives",
        .requirement = "req-m2-zig-parser-boundary",
        .acceptance_check = "check-m2-zig-parser-boundary",
        .component = "zgraphy",
        .command = "test",
        .default_seed = 1901,
        .source_roots = &.{ "src/zig_parser.zig", "test/fixtures/zig-parser/deep.zig", "src/indexer.zig", "src/model.zig", "src/root.zig", "src/main.zig", "test/all_test.zig" },
        .tags = &.{ "acceptance", "m2", "zig", "parser", "ast", "span", "declaration", "import", "call", "deterministic" },
    };
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = scenario,
        .seed = 1901,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    const source = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "test/fixtures/zig-parser/deep.zig", std.testing.allocator, .limited(64 * 1024));
    defer std.testing.allocator.free(source);
    var first = try zgraphy.ZigParser.parse(std.testing.allocator, "test/fixtures/zig-parser/deep.zig", source, .{});
    defer first.deinit();
    var second = try zgraphy.ZigParser.parse(std.testing.allocator, "test/fixtures/zig-parser/deep.zig", source, .{});
    defer second.deinit();
    try zgraphy.ZigParser.validate(&first);
    try zgraphy.ZigParser.validate(&second);
    try std.testing.expectEqualSlices(u8, &first.fingerprint, &second.fingerprint);
    try std.testing.expectEqual(@as(usize, 4), first.declarations.len);
    try std.testing.expectEqual(@as(usize, 1), first.imports.len);
    try std.testing.expectEqual(@as(usize, 3), first.calls.len);

    const service = first.findDeclaration("Service") orelse return error.MissingParsedService;
    try std.testing.expectEqual(zgraphy.ZigParser.DeclarationKind.structure, service.kind);
    try std.testing.expectEqual(@as(u32, 6), service.name_span.start_line);
    const handle = first.findDeclaration("handle") orelse return error.MissingParsedHandle;
    try std.testing.expectEqual(zgraphy.ZigParser.DeclarationKind.function, handle.kind);
    try std.testing.expectEqual(@as(u32, 7), handle.name_span.start_line);
    try std.testing.expectEqual(@as(u32, 12), handle.name_span.start_column);
    try std.testing.expectEqualStrings("handle", source[handle.name_span.start_byte..handle.name_span.end_byte]);
    const helper = first.findDeclaration("helper") orelse return error.MissingParsedHelper;
    try std.testing.expectEqual(@as(u32, 17), helper.name_span.start_line);
    const parsed_test = first.findDeclaration("service handles") orelse return error.MissingParsedTest;
    try std.testing.expectEqual(zgraphy.ZigParser.DeclarationKind.test_decl, parsed_test.kind);
    try std.testing.expect(first.findDeclaration("phantom") == null);
    try std.testing.expect(first.findDeclaration("commented_out") == null);

    const imported = first.findImport("std") orelse return error.MissingParsedImport;
    try std.testing.expectEqual(@as(u32, 1), imported.span.start_line);
    const helper_call = first.findCall("helper") orelse return error.MissingParsedHelperCall;
    try std.testing.expectEqualStrings("handle", helper_call.enclosing_declaration);
    try std.testing.expectEqual(@as(u32, 12), helper_call.callee_span.start_line);
    try std.testing.expectEqual(@as(u32, 9), helper_call.callee_span.start_column);
    const field_call = first.findCall("std.debug.print") orelse return error.MissingParsedFieldCall;
    try std.testing.expectEqualStrings("handle", field_call.enclosing_declaration);
    const test_call = first.findCall("service.handle") orelse return error.MissingParsedTestCall;
    try std.testing.expectEqualStrings("service handles", test_call.enclosing_declaration);
    try std.testing.expect(first.findCall("invented") == null);
    try std.testing.expect(first.findCall("also_invented") == null);

    var graph = try zgraphy.RepositoryGraph.init(std.testing.allocator, .{});
    defer graph.deinit();
    try zgraphy.Indexer.indexZigSource(&graph, "test/fixtures/zig-parser/deep.zig", source);
    const graph_handle = graph.findNodeByLabel("handle") orelse return error.MissingIndexedAstHandle;
    const graph_helper = graph.findNodeByLabel("helper") orelse return error.MissingIndexedAstHelper;
    try std.testing.expectEqual(@as(u32, 7), graph_handle.line);
    try std.testing.expect(graph.hasEdge(graph_handle.id, graph_helper.id, .calls));
    try std.testing.expect(graph.findNodeByLabel("phantom") == null);
    try std.testing.expect(graph.findNodeByLabel("commented_out") == null);

    try std.testing.expectError(error.InvalidZigSource, zgraphy.ZigParser.parse(std.testing.allocator, "src/broken.zig", "pub fn broken(", .{}));
    try std.testing.expectError(error.ZigSourceLimitExceeded, zgraphy.ZigParser.parse(std.testing.allocator, "src/large.zig", "pub fn main() void {}", .{ .max_source_bytes = 4 }));

    try assertions.boolean(.{
        .id = "zgraphy.m2.zig-parser-exact-spans",
        .label = "compiler AST facts retain exact byte line and column evidence for multiline declarations imports and calls",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1606, .column = 1 },
        .repair_hint = "derive spans from AST token offsets and keep one-based source coordinates",
    }, handle.name_span.start_line == 7 and handle.name_span.start_column == 12 and helper_call.callee_span.start_line == 12 and helper_call.callee_span.start_column == 9);
    try assertions.boolean(.{
        .id = "zgraphy.m2.zig-parser-no-lexical-facts",
        .label = "comments and string bodies cannot invent declarations or calls",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1606, .column = 1 },
        .repair_hint = "extract only compiler AST nodes and reject parse errors before publishing facts",
    }, first.findDeclaration("phantom") == null and first.findDeclaration("commented_out") == null and first.findCall("invented") == null and first.findCall("also_invented") == null and graph.findNodeByLabel("phantom") == null);
    try assertions.noFindings(.{ .id = "zgraphy.m2.zig-parser-no-findings", .label = "Zig parser boundary validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m2.zig-parser-no-pending", .label = "Zig parser boundary validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy M2 Zig resolution preserves scope import candidates and ambiguity" {
    const scenario = zstd.Testing.Scenario{
        .id = "m2-zig-resolution",
        .label = "Zig scope and import evidence preserves exact resolved ambiguous and unresolved call candidates",
        .requirement = "req-m2-zig-resolution",
        .acceptance_check = "check-m2-zig-resolution",
        .component = "zgraphy",
        .command = "test",
        .default_seed = 1902,
        .source_roots = &.{ "src/zig_parser.zig", "src/zig_resolution.zig", "src/indexer.zig", "src/model.zig", "src/semantic_schema.zig", "src/semantic-schema.v2.json", "src/differential.zig", "benchmarks/fixtures/zig-ambiguity", "benchmarks/gold/zig-ambiguity.canonical.v1.json", "src/root.zig", "src/main.zig", "test/all_test.zig" },
        .tags = &.{ "acceptance", "m2", "zig", "scope", "import", "resolution", "candidate", "ambiguity", "benchmark", "deterministic" },
    };
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = scenario,
        .seed = 1902,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    var fixture = try std.Io.Dir.cwd().openDir(std.testing.io, "benchmarks/fixtures/zig-ambiguity", .{ .iterate = true, .follow_symlinks = false });
    defer fixture.close(std.testing.io);
    const paths = [_][]const u8{ "src/beta.zig", "src/main.zig", "src/alpha.zig" };
    var corpus = try zgraphy.ZigResolution.Corpus.init(std.testing.allocator, .{});
    defer corpus.deinit();
    for (paths) |path| {
        const source = try fixture.readFileAlloc(std.testing.io, path, std.testing.allocator, .limited(64 * 1024));
        defer std.testing.allocator.free(source);
        try corpus.addSource(path, source);
    }
    const parsed_main = corpus.parsedForPath("src/main.zig") orelse return error.MissingParsedMain;
    const alpha_import = parsed_main.findImportBinding("alpha") orelse return error.MissingAlphaImportBinding;
    const beta_import = parsed_main.findImportBinding("beta") orelse return error.MissingBetaImportBinding;
    try std.testing.expectEqualStrings("alpha.zig", alpha_import.target);
    try std.testing.expectEqualStrings("beta.zig", beta_import.target);
    const loader_binding = parsed_main.findBinding("loader", "choose") orelse return error.MissingLoaderBinding;
    try std.testing.expectEqual(zgraphy.ZigParser.BindingScope.local, loader_binding.scope);
    var loader_reference_count: usize = 0;
    var saw_alpha_reference = false;
    var saw_beta_reference = false;
    for (parsed_main.binding_references) |reference| {
        if (!std.mem.eql(u8, reference.binding, "loader") or !std.mem.eql(u8, reference.enclosing_declaration, "choose")) continue;
        loader_reference_count += 1;
        if (std.mem.eql(u8, reference.expression, "alpha.load")) saw_alpha_reference = true;
        if (std.mem.eql(u8, reference.expression, "beta.load")) saw_beta_reference = true;
    }
    try std.testing.expectEqual(@as(usize, 2), loader_reference_count);
    try std.testing.expect(saw_alpha_reference and saw_beta_reference);
    var first = try corpus.resolve();
    defer first.deinit();
    var second = try corpus.resolve();
    defer second.deinit();
    try zgraphy.ZigResolution.validate(&first);
    try zgraphy.ZigResolution.validate(&second);
    try std.testing.expectEqualSlices(u8, &first.fingerprint, &second.fingerprint);

    const loader = first.findCall("src/main.zig", "choose", "loader") orelse return error.MissingLoaderResolution;
    try std.testing.expectEqual(zgraphy.ZigResolution.Status.ambiguous, loader.status);
    const candidates = first.candidatesFor(loader);
    try std.testing.expectEqual(@as(usize, 2), candidates.len);
    try std.testing.expectEqualStrings("src/alpha.zig", candidates[0].target_path);
    try std.testing.expectEqualStrings("load", candidates[0].target_name);
    try std.testing.expectEqual(zgraphy.ZigResolution.CandidateReason.binding_flow, candidates[0].reason);
    try std.testing.expectEqualStrings("src/beta.zig", candidates[1].target_path);
    try std.testing.expectEqualStrings("load", candidates[1].target_name);
    try std.testing.expectEqual(zgraphy.ZigResolution.CandidateReason.binding_flow, candidates[1].reason);

    var duplicate_guard = try zgraphy.ZigResolution.Corpus.init(std.testing.allocator, .{});
    defer duplicate_guard.deinit();
    try duplicate_guard.addSource("src/alpha.zig", "pub fn load() void {}\n");
    try std.testing.expectError(error.DuplicateZigSourcePath, duplicate_guard.addSource("src/alpha.zig", "pub fn load() void {}\n"));
    var file_guard = try zgraphy.ZigResolution.Corpus.init(std.testing.allocator, .{ .max_files = 1 });
    defer file_guard.deinit();
    try file_guard.addSource("src/alpha.zig", "pub fn load() void {}\n");
    try std.testing.expectError(error.ZigResolutionFileLimitExceeded, file_guard.addSource("src/beta.zig", "pub fn load() void {}\n"));

    var escaping = try zgraphy.ZigResolution.Corpus.init(std.testing.allocator, .{});
    defer escaping.deinit();
    try escaping.addSource("src/main.zig",
        \\const outside = @import("../../outside.zig");
        \\pub fn invoke() void { outside.load(); }
    );
    var escaping_result = try escaping.resolve();
    defer escaping_result.deinit();
    const escaping_call = escaping_result.findCall("src/main.zig", "invoke", "outside.load") orelse return error.MissingEscapingCall;
    try std.testing.expectEqual(zgraphy.ZigResolution.Status.unresolved, escaping_call.status);
    try std.testing.expectEqual(@as(usize, 0), escaping_result.candidatesFor(escaping_call).len);

    var candidate_guard = try zgraphy.ZigResolution.Corpus.init(std.testing.allocator, .{ .max_candidates = 1 });
    defer candidate_guard.deinit();
    try candidate_guard.addSource("src/alpha.zig", "pub fn load() void {}\n");
    try candidate_guard.addSource("src/beta.zig", "pub fn load() void {}\n");
    try candidate_guard.addSource("src/main.zig",
        \\const alpha = @import("alpha.zig");
        \\const beta = @import("beta.zig");
        \\pub fn invoke(flag: bool) void {
        \\    const loader = if (flag) alpha.load else beta.load;
        \\    loader();
        \\}
    );
    try std.testing.expectError(error.ZigResolutionCandidateLimitExceeded, candidate_guard.resolve());

    var built = try zgraphy.Indexer.buildRepository(std.testing.allocator, std.testing.io, fixture, .{});
    defer built.deinit();
    var loader_node: ?*const zgraphy.Node = null;
    var alpha_load: ?*const zgraphy.Node = null;
    var beta_load: ?*const zgraphy.Node = null;
    for (built.graph.nodes.items) |*node| {
        if (node.kind == .concept and std.mem.eql(u8, node.path, "src/main.zig") and std.mem.eql(u8, node.label, "loader")) loader_node = node;
        if (node.kind == .symbol and std.mem.eql(u8, node.path, "src/alpha.zig") and std.mem.eql(u8, node.label, "load")) alpha_load = node;
        if (node.kind == .symbol and std.mem.eql(u8, node.path, "src/beta.zig") and std.mem.eql(u8, node.label, "load")) beta_load = node;
    }
    try std.testing.expect(loader_node != null and alpha_load != null and beta_load != null);
    try std.testing.expect(built.graph.hasEdge(loader_node.?.id, alpha_load.?.id, .dispatches_to));
    try std.testing.expect(built.graph.hasEdge(loader_node.?.id, beta_load.?.id, .dispatches_to));

    var gold = try zgraphy.Benchmark.parseEmbeddedGold(std.testing.allocator, "benchmarks/gold/zig-ambiguity.canonical.v1.json");
    defer gold.deinit();
    var receipt = try zgraphy.Differential.projectZgraphy(std.testing.allocator, &built.graph, &gold.value);
    defer receipt.deinit(std.testing.allocator);
    try zgraphy.Differential.validateReceipt(&receipt);
    try std.testing.expectEqual(@as(usize, 12), receipt.relations.matched);
    try std.testing.expectEqual(@as(usize, 0), receipt.relations.missing);
    try std.testing.expectEqual(@as(usize, 1), receipt.facts.matched);
    try std.testing.expectEqual(@as(usize, 0), receipt.facts.missing);

    try assertions.boolean(.{
        .id = "zgraphy.m2.zig-resolution-candidates",
        .label = "called function-value binding preserves both exact imported callable candidates",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1698, .column = 1 },
        .repair_hint = "resolve local binding initializer field references through exact static import bindings and retain every candidate",
    }, loader_reference_count == 2 and saw_alpha_reference and saw_beta_reference and loader.status == .ambiguous and candidates.len == 2 and built.graph.hasEdge(loader_node.?.id, alpha_load.?.id, .dispatches_to) and built.graph.hasEdge(loader_node.?.id, beta_load.?.id, .dispatches_to));
    try assertions.boolean(.{
        .id = "zgraphy.m2.zig-resolution-benchmark",
        .label = "native graph matches canonical candidate relations and ambiguity fact without invented targets",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1698, .column = 1 },
        .repair_hint = "materialize validated dispatch candidates and derive ambiguity only from complete graph evidence",
    }, receipt.relations.missing == 0 and receipt.facts.missing == 0);
    try assertions.noFindings(.{ .id = "zgraphy.m2.zig-resolution-no-findings", .label = "Zig resolution validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m2.zig-resolution-no-pending", .label = "Zig resolution validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy M2 TypeScript parser boundary emits exact native AST facts" {
    const scenario = zstd.Testing.Scenario{
        .id = "m2-typescript-parser-boundary",
        .label = "Native TypeScript TSX and JavaScript syntax trees emit exact bounded structural facts",
        .requirement = "req-m2-typescript-parser-boundary",
        .acceptance_check = "check-m2-typescript-parser-boundary",
        .component = "zgraphy",
        .command = "test",
        .default_seed = 1903,
        .source_roots = &.{ "src/typescript_parser.zig", "test/fixtures/typescript-parser/deep.tsx", "test/fixtures/typescript-parser/deep.js", "build.zig", "build.zig.zon", "THIRD_PARTY_NOTICES.md", "src/root.zig", "test/all_test.zig" },
        .tags = &.{ "acceptance", "m2", "typescript", "tsx", "javascript", "tree-sitter", "parser", "ast", "span", "import", "call", "deterministic" },
    };
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = scenario,
        .seed = 1903,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    const tsx_source = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "test/fixtures/typescript-parser/deep.tsx", std.testing.allocator, .limited(128 * 1024));
    defer std.testing.allocator.free(tsx_source);
    var first = try zgraphy.TypeScriptParser.parse(std.testing.allocator, "test/fixtures/typescript-parser/deep.tsx", tsx_source, .tsx, .{});
    defer first.deinit();
    var second = try zgraphy.TypeScriptParser.parse(std.testing.allocator, "test/fixtures/typescript-parser/deep.tsx", tsx_source, .tsx, .{});
    defer second.deinit();
    try zgraphy.TypeScriptParser.validate(&first);
    try zgraphy.TypeScriptParser.validate(&second);
    try std.testing.expectEqualSlices(u8, &first.fingerprint, &second.fingerprint);
    try std.testing.expectEqual(zgraphy.TypeScriptParser.LanguageMode.tsx, first.language);

    const order = first.findDeclaration("Order") orelse return error.MissingTypeScriptOrder;
    try std.testing.expectEqual(zgraphy.TypeScriptParser.DeclarationKind.interface, order.kind);
    try std.testing.expect(order.exported);
    try std.testing.expectEqual(@as(u32, 9), order.name_span.start_line);
    const controller = first.findDeclaration("OrdersController") orelse return error.MissingTypeScriptController;
    try std.testing.expectEqual(zgraphy.TypeScriptParser.DeclarationKind.class, controller.kind);
    const load = first.findDeclaration("load") orelse return error.MissingTypeScriptLoad;
    try std.testing.expectEqual(zgraphy.TypeScriptParser.DeclarationKind.method, load.kind);
    try std.testing.expectEqualStrings("OrdersController", load.enclosing_declaration);
    try std.testing.expectEqual(@as(u32, 24), load.name_span.start_line);
    const fetch_order = first.findDeclaration("fetchOrder") orelse return error.MissingTypeScriptFetchOrder;
    try std.testing.expectEqual(zgraphy.TypeScriptParser.DeclarationKind.function_value, fetch_order.kind);
    try std.testing.expect(fetch_order.exported);
    const page = first.findDeclaration("OrderPage") orelse return error.MissingTypeScriptOrderPage;
    try std.testing.expectEqual(zgraphy.TypeScriptParser.DeclarationKind.function, page.kind);
    try std.testing.expect(first.findDeclaration("invented") == null);
    try std.testing.expect(first.findDeclaration("commentedOut") == null);

    try std.testing.expectEqual(@as(usize, 5), first.imports.len);
    const lazy_import = first.findImport("./lazy") orelse return error.MissingTypeScriptDynamicModuleImport;
    try std.testing.expectEqual(zgraphy.TypeScriptParser.ImportKind.dynamic, lazy_import.kind);
    const connect = first.findImport("@connectrpc/connect") orelse return error.MissingTypeScriptConnectImport;
    try std.testing.expectEqual(@as(u32, 1), connect.span.start_line);
    const default_transport = first.findImportBinding("defaultTransport") orelse return error.MissingDefaultImportBinding;
    try std.testing.expectEqual(zgraphy.TypeScriptParser.ImportBindingKind.default, default_transport.kind);
    const make_client = first.findImportBinding("makeClient") orelse return error.MissingAliasedImportBinding;
    try std.testing.expectEqualStrings("createClient", make_client.imported);
    try std.testing.expectEqual(zgraphy.TypeScriptParser.ImportBindingKind.named, make_client.kind);
    const client_options = first.findImportBinding("ClientOptions") orelse return error.MissingTypeOnlyImportBinding;
    try std.testing.expect(client_options.type_only);
    const solid = first.findImportBinding("Solid") orelse return error.MissingNamespaceImportBinding;
    try std.testing.expectEqual(zgraphy.TypeScriptParser.ImportBindingKind.namespace, solid.kind);
    const legacy = first.findImportBinding("legacy") orelse return error.MissingImportRequireBinding;
    try std.testing.expectEqual(zgraphy.TypeScriptParser.ImportBindingKind.import_require, legacy.kind);

    const member_call = first.findCall("this.client.getOrder") orelse return error.MissingTypeScriptMemberCall;
    try std.testing.expectEqual(zgraphy.TypeScriptParser.CallKind.member, member_call.kind);
    try std.testing.expectEqualStrings("this.client", member_call.receiver);
    try std.testing.expectEqualStrings("getOrder", member_call.member);
    try std.testing.expectEqualStrings("OrdersController.load", member_call.enclosing_declaration);
    const constructor_call = first.findCall("OrdersController") orelse return error.MissingTypeScriptConstructorCall;
    try std.testing.expectEqual(zgraphy.TypeScriptParser.CallKind.constructor, constructor_call.kind);
    try std.testing.expectEqualStrings("fetchOrder", constructor_call.enclosing_declaration);
    const dynamic_import = first.findCall("import") orelse return error.MissingTypeScriptDynamicImport;
    try std.testing.expectEqual(zgraphy.TypeScriptParser.CallKind.dynamic_import, dynamic_import.kind);
    try std.testing.expectEqualStrings("OrderPage", dynamic_import.enclosing_declaration);
    const jsx_callback = first.findCall("fetchOrder") orelse return error.MissingTypeScriptJsxCallback;
    try std.testing.expectEqualStrings("OrderPage", jsx_callback.enclosing_declaration);
    try std.testing.expect(first.findCall("phantomCall") == null);
    try std.testing.expect(first.findCall("alsoPhantom") == null);

    const js_source = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "test/fixtures/typescript-parser/deep.js", std.testing.allocator, .limited(64 * 1024));
    defer std.testing.allocator.free(js_source);
    var javascript = try zgraphy.TypeScriptParser.parse(std.testing.allocator, "test/fixtures/typescript-parser/deep.js", js_source, .javascript, .{});
    defer javascript.deinit();
    try std.testing.expect(javascript.findDeclaration("run") != null);
    const send = javascript.findCall("client.send") orelse return error.MissingJavaScriptMemberCall;
    try std.testing.expectEqualStrings("run", send.enclosing_declaration);
    try std.testing.expect(javascript.findDeclaration("phantom") == null and javascript.findCall("invented") == null);

    try std.testing.expectError(error.InvalidTypeScriptSource, zgraphy.TypeScriptParser.parse(std.testing.allocator, "src/broken.ts", "export function broken(", .typescript, .{}));
    try std.testing.expectError(error.TypeScriptSourceLimitExceeded, zgraphy.TypeScriptParser.parse(std.testing.allocator, "src/large.ts", "export const value = 1;", .typescript, .{ .max_source_bytes = 4 }));
    try std.testing.expectError(error.TypeScriptNodeLimitExceeded, zgraphy.TypeScriptParser.parse(std.testing.allocator, "src/nodes.ts", "export const value = 1;", .typescript, .{ .max_nodes = 1 }));
    try std.testing.expectError(error.TypeScriptDepthLimitExceeded, zgraphy.TypeScriptParser.parse(std.testing.allocator, "src/depth.ts", "export function f() { return g(); }", .typescript, .{ .max_depth = 1 }));
    try std.testing.expectError(error.TypeScriptFactLimitExceeded, zgraphy.TypeScriptParser.parse(std.testing.allocator, "src/facts.ts", "export const a = f(); export const b = g();", .typescript, .{ .max_facts = 1 }));

    try assertions.boolean(.{
        .id = "zgraphy.m2.typescript-parser-exact",
        .label = "native syntax trees preserve exact declarations imports bindings calls receivers and enclosing scopes",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1840, .column = 1 },
        .repair_hint = "extract only named tree-sitter nodes and retain exact source-qualified spans and enclosing declarations",
    }, order.name_span.start_line == 9 and load.name_span.start_line == 24 and first.imports.len == 5 and lazy_import.kind == .dynamic and member_call.kind == .member and constructor_call.kind == .constructor and dynamic_import.kind == .dynamic_import);
    try assertions.boolean(.{
        .id = "zgraphy.m2.typescript-parser-no-lexical-facts",
        .label = "TS TSX and JavaScript comments strings and JSX cannot invent declarations or calls",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1840, .column = 1 },
        .repair_hint = "reject syntax-error trees and publish facts only from matching named AST nodes",
    }, first.findDeclaration("invented") == null and first.findDeclaration("commentedOut") == null and first.findCall("phantomCall") == null and first.findCall("alsoPhantom") == null and javascript.findDeclaration("phantom") == null and javascript.findCall("invented") == null);
    try assertions.noFindings(.{ .id = "zgraphy.m2.typescript-parser-no-findings", .label = "TypeScript parser boundary validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m2.typescript-parser-no-pending", .label = "TypeScript parser boundary validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy M2 TypeScript module resolution preserves inventory config workspace and candidate truth" {
    const scenario = zstd.Testing.Scenario{
        .id = "m2-typescript-module-resolution",
        .label = "TypeScript and JavaScript module references resolve through exact repository config and workspace evidence",
        .requirement = "req-m2-typescript-module-resolution",
        .acceptance_check = "check-m2-typescript-module-resolution",
        .component = "zgraphy",
        .command = "test",
        .default_seed = 1904,
        .source_roots = &.{ "src/typescript_resolution.zig", "src/typescript_parser.zig", "src/indexer.zig", "src/model.zig", "src/discovery.zig", "src/ownership.zig", "src/semantic_schema.zig", "src/semantic-schema.v2.json", "test/fixtures/typescript-resolution", "benchmarks/adapter-fixtures/graphify-0.9.17/typescript-resolution-overlap.json", "src/root.zig", "test/all_test.zig" },
        .tags = &.{ "acceptance", "m2", "typescript", "javascript", "module", "resolution", "tsconfig", "workspace", "exports", "dynamic-import", "commonjs", "ambiguity", "security", "graphify", "differential", "deterministic" },
    };
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = scenario,
        .seed = 1904,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    var fixture = try std.Io.Dir.cwd().openDir(std.testing.io, "test/fixtures/typescript-resolution", .{ .iterate = true, .follow_symlinks = false });
    defer fixture.close(std.testing.io);
    var discovered = try zgraphy.Discovery.scan(std.testing.allocator, std.testing.io, fixture, .{});
    defer discovered.deinit();

    var first_corpus = try loadTypeScriptResolutionCorpus(std.testing.allocator, fixture, &discovered, .{});
    defer first_corpus.deinit();
    var first = try first_corpus.resolve();
    defer first.deinit();
    var second_corpus = try loadTypeScriptResolutionCorpus(std.testing.allocator, fixture, &discovered, .{});
    defer second_corpus.deinit();
    var second = try second_corpus.resolve();
    defer second.deinit();
    try zgraphy.TypeScriptResolution.validate(&first);
    try zgraphy.TypeScriptResolution.validate(&second);
    try std.testing.expectEqualSlices(u8, &first.fingerprint, &second.fingerprint);

    const source = "apps/web/src/page.ts";
    try expectTypeScriptResolution(&first, source, "./local", .static, .resolved, "apps/web/src/local.ts", .source_extension);
    try expectTypeScriptResolution(&first, source, "./esm.js", .static, .resolved, "apps/web/src/esm.ts", .esm_source_substitution);
    try expectTypeScriptResolution(&first, source, "./feature", .static, .resolved, "apps/web/src/feature.ts", .source_extension);
    try expectTypeScriptResolution(&first, source, "./directory", .static, .resolved, "apps/web/src/directory/index.ts", .directory_index);
    try expectTypeScriptResolution(&first, source, "./multi.shared", .static, .resolved, "apps/web/src/multi.shared.ts", .source_extension);
    try expectTypeScriptResolution(&first, source, "./state.svelte", .static, .resolved, "apps/web/src/state.svelte.ts", .source_extension);
    try expectTypeScriptResolution(&first, source, "@exact", .static, .resolved, "packages/exact/src/exact.ts", .tsconfig_exact);
    try expectTypeScriptResolution(&first, source, "@shared/shared", .static, .resolved, "packages/shared/src/shared.ts", .tsconfig_wildcard);
    try expectTypeScriptResolution(&first, source, "@fallback/extra", .static, .resolved, "packages/shared/src/extra.ts", .tsconfig_wildcard);
    try expectTypeScriptResolution(&first, source, "@legacy/client", .static, .resolved, "packages/shared/src/client.ts", .tsconfig_directory_prefix);
    try expectTypeScriptResolution(&first, source, "@array-parent/client", .static, .resolved, "packages/shared/src/client.ts", .tsconfig_wildcard);
    try expectTypeScriptResolution(&first, source, "@cycle/client", .static, .resolved, "packages/shared/src/client.ts", .tsconfig_wildcard);
    try expectTypeScriptResolution(&first, source, "@override", .static, .resolved, "packages/exact/src/exact.ts", .tsconfig_exact);
    try expectTypeScriptResolution(&first, source, "packages/shared/src/client", .static, .resolved, "packages/shared/src/client.ts", .tsconfig_base_url);
    try expectTypeScriptResolution(&first, source, "@acme/shared", .static, .resolved, "packages/shared/src/index.ts", .workspace_export);
    try expectTypeScriptResolution(&first, source, "@acme/shared/client", .static, .resolved, "packages/shared/src/client.ts", .workspace_export);
    try expectTypeScriptResolution(&first, source, "@acme/shared/extra", .static, .resolved, "packages/shared/src/extra.ts", .workspace_export);
    try expectTypeScriptResolution(&first, source, "@acme/fallback", .static, .resolved, "packages/fallback/src/index.ts", .workspace_entry_fallback);
    try expectTypeScriptResolution(&first, source, "./legacy", .import_require, .resolved, "apps/web/src/legacy.ts", .source_extension);
    try expectTypeScriptResolution(&first, source, "./lazy", .dynamic, .resolved, "apps/web/src/lazy.ts", .source_extension);
    try expectTypeScriptResolution(&first, "apps/web/src/page.cjs", "./local", .commonjs_require, .resolved, "apps/web/src/local.ts", .source_extension);
    try expectTypeScriptResolution(&first, "npm-fallback/apps/web/page.ts", "@nested/only", .static, .resolved, "npm-fallback/packages/only/src/index.ts", .workspace_entry_fallback);

    const duplicate = first.findResolution(source, "@acme/duplicate", .static) orelse return error.MissingDuplicateWorkspaceResolution;
    try std.testing.expectEqual(zgraphy.TypeScriptResolution.Status.ambiguous, duplicate.status);
    const duplicate_candidates = first.candidatesFor(duplicate);
    try std.testing.expectEqual(@as(usize, 2), duplicate_candidates.len);
    try std.testing.expectEqualStrings("duplicates/a/src/index.ts", duplicate_candidates[0].target_path);
    try std.testing.expectEqualStrings("duplicates/b/src/index.ts", duplicate_candidates[1].target_path);

    const escaped = first.findResolution(source, "@acme/evil", .static) orelse return error.MissingEscapedWorkspaceResolution;
    try std.testing.expectEqual(zgraphy.TypeScriptResolution.Status.unresolved, escaped.status);
    try std.testing.expectEqual(@as(usize, 0), escaped.candidate_count);
    try std.testing.expect(first.hasDiagnostic(.package_escape, "packages/evil/package.json"));
    try std.testing.expect(first.hasDiagnostic(.config_cycle, "configs/cycle-a.json"));

    const external = first.findResolution(source, "tailwindcss/colors", .static) orelse return error.MissingExternalResolution;
    try std.testing.expectEqual(zgraphy.TypeScriptResolution.Status.external, external.status);
    try std.testing.expectEqual(@as(usize, 0), external.candidate_count);
    const pnpm_authority = first.findResolution(source, "@acme/npm-only", .static) orelse return error.MissingPnpmAuthorityResolution;
    try std.testing.expectEqual(zgraphy.TypeScriptResolution.Status.external, pnpm_authority.status);
    const missing = first.findResolution(source, "./missing", .static) orelse return error.MissingDanglingResolution;
    try std.testing.expectEqual(zgraphy.TypeScriptResolution.Status.unresolved, missing.status);
    try std.testing.expect(first.findResolution(source, "path", .dynamic) == null);

    var built = try zgraphy.Indexer.buildRepository(std.testing.allocator, std.testing.io, fixture, .{
        .max_nodes = 20_000,
        .max_edges = 80_000,
    });
    defer built.deinit();
    const page_file = findGraphNode(&built.graph, .file, source, "page.ts") orelse return error.MissingTypeScriptPageNode;
    const local_file = findGraphNode(&built.graph, .file, "apps/web/src/local.ts", "local.ts") orelse return error.MissingTypeScriptLocalNode;
    const local_reference = findGraphNode(&built.graph, .module_reference, source, "./local") orelse return error.MissingLocalModuleReference;
    try std.testing.expect(built.graph.hasEdge(page_file.id, local_reference.id, .imports));
    try std.testing.expect(built.graph.hasEdge(local_reference.id, local_file.id, .resolves_to));
    const lazy_reference = findGraphNode(&built.graph, .module_reference, source, "./lazy") orelse return error.MissingLazyModuleReference;
    try std.testing.expect(built.graph.hasEdge(page_file.id, lazy_reference.id, .deferred_imports));
    try std.testing.expect(!built.graph.hasEdge(page_file.id, local_file.id, .deferred_imports));
    const duplicate_reference = findGraphNode(&built.graph, .module_reference, source, "@acme/duplicate") orelse return error.MissingDuplicateModuleReference;
    try std.testing.expectEqual(@as(usize, 2), countOutgoingGraphEdges(&built.graph, duplicate_reference.id, .resolves_to));
    const missing_reference = findGraphNode(&built.graph, .module_reference, source, "./missing") orelse return error.MissingDanglingModuleReference;
    try std.testing.expectEqual(@as(usize, 0), countOutgoingGraphEdges(&built.graph, missing_reference.id, .resolves_to));
    const external_reference = findGraphNode(&built.graph, .module_reference, source, "tailwindcss/colors") orelse return error.MissingExternalModuleReference;
    const external_node = findGraphNode(&built.graph, .external_module, "external/typescript/tailwindcss/colors", "tailwindcss/colors") orelse return error.MissingNamespacedExternalModule;
    try std.testing.expect(built.graph.hasEdge(external_reference.id, external_node.id, .resolves_to));
    const python_colors = findGraphNode(&built.graph, .file, "tools/colors.py", "colors.py") orelse return error.MissingPythonColorsNode;
    try std.testing.expect(!built.graph.hasEdge(external_reference.id, python_colors.id, .resolves_to));

    const overlap_bytes = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "benchmarks/adapter-fixtures/graphify-0.9.17/typescript-resolution-overlap.json", std.testing.allocator, .limited(128 * 1024));
    defer std.testing.allocator.free(overlap_bytes);
    var overlap = try std.json.parseFromSlice(GraphifyTypeScriptOverlap, std.testing.allocator, overlap_bytes, .{ .allocate = .alloc_always, .ignore_unknown_fields = false });
    defer overlap.deinit();
    try std.testing.expectEqualStrings("zgraphy.graphify-typescript-overlap.v1", overlap.value.schema);
    try std.testing.expectEqualStrings("0.9.17", overlap.value.baseline.version);
    try std.testing.expectEqualStrings("cb96bdaa0c367bec8d5c5aee5d7c9ebb727e9780", overlap.value.baseline.commit);
    try std.testing.expectEqual(@as(usize, 16), overlap.value.facts.len);
    for (overlap.value.facts) |fact| {
        try std.testing.expect(graphHasModuleResolution(&built.graph, fact.source, fact.target, fact.deferred));
    }
    try std.testing.expectEqual(@as(usize, 3), overlap.value.classified_differences.len);

    var bounded = try zgraphy.TypeScriptResolution.Corpus.init(std.testing.allocator, .{ .max_files = 1 });
    defer bounded.deinit();
    try bounded.addFile("a.ts");
    try std.testing.expectError(error.TypeScriptResolutionFileLimitExceeded, bounded.addFile("b.ts"));
    try std.testing.expectError(error.InvalidTypeScriptResolutionPath, bounded.addFile("../escape.ts"));
    var path_bounded = try zgraphy.TypeScriptResolution.Corpus.init(std.testing.allocator, .{ .max_path_bytes = 3 });
    defer path_bounded.deinit();
    try std.testing.expectError(error.TypeScriptResolutionPathLimitExceeded, path_bounded.addFile("a.ts"));
    var document_bounded = try zgraphy.TypeScriptResolution.Corpus.init(std.testing.allocator, .{ .max_document_bytes = 1 });
    defer document_bounded.deinit();
    try document_bounded.addFile("package.json");
    try std.testing.expectError(error.TypeScriptResolutionDocumentByteLimitExceeded, document_bounded.addDocument("package.json", "{}"));

    var depth_corpus = try loadTypeScriptResolutionCorpus(std.testing.allocator, fixture, &discovered, .{ .max_config_depth = 1 });
    defer depth_corpus.deinit();
    var depth_result = try depth_corpus.resolve();
    defer depth_result.deinit();
    try std.testing.expect(hasTypeScriptResolutionDiagnostic(&depth_result, .config_limit));
    var candidate_corpus = try loadTypeScriptResolutionCorpus(std.testing.allocator, fixture, &discovered, .{ .max_candidates_per_import = 1 });
    defer candidate_corpus.deinit();
    var candidate_result = try candidate_corpus.resolve();
    defer candidate_result.deinit();
    const exhausted_duplicate = candidate_result.findResolution(source, "@acme/duplicate", .static) orelse return error.MissingExhaustedDuplicateResolution;
    try std.testing.expectEqual(zgraphy.TypeScriptResolution.Status.exhausted, exhausted_duplicate.status);
    try std.testing.expectEqual(@as(usize, 0), exhausted_duplicate.candidate_count);
    var result_bounded = try loadTypeScriptResolutionCorpus(std.testing.allocator, fixture, &discovered, .{ .max_result_bytes = 1 });
    defer result_bounded.deinit();
    try std.testing.expectError(error.TypeScriptResolutionResultLimitExceeded, result_bounded.resolve());

    try assertions.boolean(.{
        .id = "zgraphy.m2.typescript-module-resolution-truth",
        .label = "relative alias workspace dynamic and CommonJS references retain exact inventory-grounded candidates",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1967, .column = 1 },
        .repair_hint = "preserve resolver precedence and retain the exact rule and authority that produced each candidate",
    }, first.summary.resolved >= 19 and duplicate.status == .ambiguous and escaped.status == .unresolved and external.status == .external and built.graph.hasEdge(local_reference.id, local_file.id, .resolves_to));
    try assertions.boolean(.{
        .id = "zgraphy.m2.typescript-module-resolution-safety",
        .label = "config cycles package escapes externals and duplicate packages remain explicit without invented local edges",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 1967, .column = 1 },
        .repair_hint = "fail closed on path containment and preserve typed diagnostics and all ambiguous candidates",
    }, first.hasDiagnostic(.package_escape, "packages/evil/package.json") and first.hasDiagnostic(.config_cycle, "configs/cycle-a.json") and duplicate_candidates.len == 2 and external.candidate_count == 0);
    try assertions.noFindings(.{ .id = "zgraphy.m2.typescript-module-resolution-no-findings", .label = "TypeScript module resolution validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m2.typescript-module-resolution-no-pending", .label = "TypeScript module resolution validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

fn loadTypeScriptResolutionCorpus(
    allocator: std.mem.Allocator,
    fixture: std.Io.Dir,
    discovered: *const zgraphy.Discovery.Result,
    options: zgraphy.TypeScriptResolution.Options,
) !zgraphy.TypeScriptResolution.Corpus {
    var corpus = try zgraphy.TypeScriptResolution.Corpus.init(allocator, options);
    errdefer corpus.deinit();
    for (discovered.records) |record| {
        if (!isPlacedDiscoveryRecord(record.disposition)) continue;
        try corpus.addFile(record.relative_path);
    }
    for (discovered.records) |record| {
        if (!isPlacedDiscoveryRecord(record.disposition)) continue;
        if (isTypeScriptResolutionDocument(record.relative_path)) {
            const bytes = try readVerifiedFixtureFile(allocator, fixture, &record, 4 * 1024 * 1024);
            defer allocator.free(bytes);
            try corpus.addDocument(record.relative_path, bytes);
        }
        const mode = typeScriptModeForPath(record.relative_path) orelse continue;
        const source = try readVerifiedFixtureFile(allocator, fixture, &record, 4 * 1024 * 1024);
        defer allocator.free(source);
        var parsed = try zgraphy.TypeScriptParser.parse(allocator, record.relative_path, source, mode, .{});
        defer parsed.deinit();
        try corpus.addParsed(&parsed);
    }
    return corpus;
}

fn readVerifiedFixtureFile(
    allocator: std.mem.Allocator,
    fixture: std.Io.Dir,
    record: *const zgraphy.Discovery.Record,
    max_bytes: usize,
) ![]u8 {
    const bytes = try fixture.readFileAlloc(std.testing.io, record.relative_path, allocator, .limited(max_bytes));
    errdefer allocator.free(bytes);
    const expected = record.content_digest orelse return error.MissingFixtureDigest;
    var actual: [32]u8 = @splat(0);
    std.crypto.hash.sha2.Sha256.hash(bytes, &actual, .{});
    if (!std.mem.eql(u8, &expected, &actual)) return error.FixtureChangedAfterDiscovery;
    return bytes;
}

fn isPlacedDiscoveryRecord(disposition: zgraphy.Discovery.Disposition) bool {
    return disposition == .deeply_indexed or disposition == .placed_unsupported or disposition == .placed_asset;
}

fn isTypeScriptResolutionDocument(path: []const u8) bool {
    const basename = std.fs.path.basename(path);
    return std.mem.eql(u8, basename, "package.json") or
        std.mem.eql(u8, basename, "pnpm-workspace.yaml") or
        std.mem.eql(u8, std.fs.path.extension(path), ".json");
}

fn typeScriptModeForPath(path: []const u8) ?zgraphy.TypeScriptParser.LanguageMode {
    const extension = std.fs.path.extension(path);
    if (std.mem.eql(u8, extension, ".tsx")) return .tsx;
    if (std.mem.eql(u8, extension, ".jsx")) return .jsx;
    if (std.mem.eql(u8, extension, ".ts") or std.mem.eql(u8, extension, ".mts") or std.mem.eql(u8, extension, ".cts")) return .typescript;
    if (std.mem.eql(u8, extension, ".js") or std.mem.eql(u8, extension, ".mjs") or std.mem.eql(u8, extension, ".cjs")) return .javascript;
    return null;
}

fn expectTypeScriptResolution(
    result: *const zgraphy.TypeScriptResolution.Result,
    source_path: []const u8,
    specifier: []const u8,
    import_kind: zgraphy.TypeScriptParser.ImportKind,
    status: zgraphy.TypeScriptResolution.Status,
    target_path: []const u8,
    rule: zgraphy.TypeScriptResolution.Rule,
) !void {
    const resolution = result.findResolution(source_path, specifier, import_kind) orelse return error.MissingTypeScriptModuleResolution;
    try std.testing.expectEqual(status, resolution.status);
    const candidates = result.candidatesFor(resolution);
    try std.testing.expectEqual(@as(usize, 1), candidates.len);
    try std.testing.expectEqualStrings(target_path, candidates[0].target_path);
    try std.testing.expectEqual(rule, candidates[0].rule);
}

fn findGraphNode(
    graph: *const zgraphy.RepositoryGraph,
    kind: zgraphy.NodeKind,
    path: []const u8,
    label: []const u8,
) ?*const zgraphy.Node {
    for (graph.nodes.items) |*node| {
        if (node.kind == kind and std.mem.eql(u8, node.path, path) and std.mem.eql(u8, node.label, label)) return node;
    }
    return null;
}

fn countOutgoingGraphEdges(graph: *const zgraphy.RepositoryGraph, from: u64, relation: zgraphy.Relation) usize {
    var count: usize = 0;
    for (graph.edges.items) |edge| if (edge.from == from and edge.relation == relation) {
        count += 1;
    };
    return count;
}

const GraphifyTypeScriptOverlap = struct {
    const Baseline = struct {
        product: []const u8,
        version: []const u8,
        commit: []const u8,
        mode: []const u8,
        source_graph_sha256: []const u8,
    };
    const Fact = struct {
        source: []const u8,
        target: []const u8,
        deferred: bool,
    };
    const Difference = struct {
        kind: []const u8,
        specifier: []const u8,
        graphify_target: []const u8,
        zgraphy_expectation: []const u8,
    };

    schema: []const u8,
    baseline: Baseline,
    facts: []const Fact,
    classified_differences: []const Difference,
};

fn graphHasModuleResolution(graph: *const zgraphy.RepositoryGraph, source_path: []const u8, target_path: []const u8, deferred: bool) bool {
    const source = findGraphNode(graph, .file, source_path, std.fs.path.basename(source_path)) orelse return false;
    const target = findGraphNode(graph, .file, target_path, std.fs.path.basename(target_path)) orelse return false;
    const relation: zgraphy.Relation = if (deferred) .deferred_imports else .imports;
    for (graph.edges.items) |import_edge| {
        if (import_edge.from != source.id or import_edge.relation != relation) continue;
        const reference = graph.findNode(import_edge.to) orelse continue;
        if (reference.kind != .module_reference) continue;
        if (graph.hasEdge(reference.id, target.id, .resolves_to)) return true;
    }
    return false;
}

fn hasTypeScriptResolutionDiagnostic(result: *const zgraphy.TypeScriptResolution.Result, kind: zgraphy.TypeScriptResolution.DiagnosticKind) bool {
    for (result.diagnostics) |diagnostic| if (diagnostic.kind == kind) return true;
    return false;
}

test "zgraphy M2 TypeScript symbol resolution preserves exports aliases scopes and call candidates" {
    const scenario = zstd.Testing.Scenario{
        .id = "m2-typescript-symbol-resolution",
        .label = "TypeScript and JavaScript exports barrels imports aliases and typed calls resolve to exact origin symbols",
        .requirement = "req-m2-typescript-symbol-resolution",
        .acceptance_check = "check-m2-typescript-symbol-resolution",
        .component = "zgraphy",
        .command = "test",
        .default_seed = 1905,
        .source_roots = &.{ "src/typescript_symbols.zig", "src/typescript_resolution.zig", "src/typescript_parser.zig", "src/indexer.zig", "src/model.zig", "src/semantic_schema.zig", "src/semantic-schema.v2.json", "test/fixtures/typescript-symbols", "benchmarks/adapter-fixtures/graphify-0.9.17/typescript-symbols-overlap.json", "src/root.zig", "test/all_test.zig" },
        .tags = &.{ "acceptance", "m2", "typescript", "javascript", "symbol", "export", "re-export", "barrel", "alias", "default", "namespace", "call", "receiver", "scope", "ambiguity", "graphify", "differential", "deterministic" },
    };
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = scenario,
        .seed = 1905,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    var fixture = try std.Io.Dir.cwd().openDir(std.testing.io, "test/fixtures/typescript-symbols", .{ .iterate = true, .follow_symlinks = false });
    defer fixture.close(std.testing.io);
    const paths = [_][]const u8{
        "src/barrel.ts",
        "src/chain-00.ts",
        "src/chain-01.ts",
        "src/chain-02.ts",
        "src/chain-03.ts",
        "src/chain-04.ts",
        "src/chain-05.ts",
        "src/chain-06.ts",
        "src/chain-07.ts",
        "src/chain-08.ts",
        "src/chain-09.ts",
        "src/chain-10.ts",
        "src/chain-11.ts",
        "src/chain-12.ts",
        "src/chain-13.ts",
        "src/chain-14.ts",
        "src/chain-15.ts",
        "src/chain-16.ts",
        "src/chain-17.ts",
        "src/consumer.ts",
        "src/cycle-a.ts",
        "src/cycle-b.ts",
        "src/local-barrel.ts",
        "src/origin.ts",
        "src/other.ts",
        "src/phantom.ts",
    };
    var symbols = try zgraphy.TypeScriptSymbols.Corpus.init(std.testing.allocator, .{});
    defer symbols.deinit();
    var modules = try zgraphy.TypeScriptResolution.Corpus.init(std.testing.allocator, .{});
    defer modules.deinit();
    for (paths) |path| try modules.addFile(path);
    for (paths) |path| {
        const source = try fixture.readFileAlloc(std.testing.io, path, std.testing.allocator, .limited(128 * 1024));
        defer std.testing.allocator.free(source);
        try symbols.addSource(path, source, .typescript);
        const parsed = symbols.parsedForPath(path) orelse return error.MissingParsedTypeScriptSymbolSource;
        try modules.addParsed(parsed);
    }
    var module_result = try modules.resolve();
    defer module_result.deinit();
    var first = try symbols.resolve(&module_result);
    defer first.deinit();
    var second = try symbols.resolve(&module_result);
    defer second.deinit();
    try std.testing.expectEqualSlices(u8, &first.fingerprint, &second.fingerprint);

    try expectTypeScriptSymbolCandidate(&first, .export_binding, "src/barrel.ts", "PublicService", "src/origin.ts", "", "Service");
    try expectTypeScriptSymbolCandidate(&first, .import_binding, "src/consumer.ts", "check", "src/origin.ts", "", "validate");
    try expectTypeScriptSymbolCandidate(&first, .import_binding, "src/consumer.ts", "createThing", "src/origin.ts", "", "makeThing");
    try expectTypeScriptSymbolCandidate(&first, .import_binding, "src/consumer.ts", "DeepService", "src/origin.ts", "", "Service");
    try expectTypeScriptSymbolCandidate(&first, .import_binding, "src/consumer.ts", "cycleValidate", "src/origin.ts", "", "validate");
    try expectTypeScriptSymbolCandidate(&first, .direct_call, "src/consumer.ts", "check", "src/origin.ts", "", "validate");
    try expectTypeScriptSymbolCandidate(&first, .direct_call, "src/consumer.ts", "createThing", "src/origin.ts", "", "makeThing");
    try expectTypeScriptSymbolCandidate(&first, .direct_call, "src/consumer.ts", "cycleValidate", "src/origin.ts", "", "validate");
    try expectTypeScriptSymbolCandidate(&first, .member_call, "src/consumer.ts", "api.validate", "src/origin.ts", "", "validate");
    try expectTypeScriptSymbolCandidate(&first, .member_call, "src/consumer.ts", "local.doThing", "src/origin.ts", "Service", "doThing");
    try expectTypeScriptSymbolCandidate(&first, .member_call, "src/consumer.ts", "this.service.doThing", "src/origin.ts", "Service", "doThing");
    try expectTypeScriptSymbolCandidate(&first, .member_call, "src/consumer.ts", "other.doThing", "src/other.ts", "OtherService", "doThing");
    try expectTypeScriptSymbolCandidate(&first, .member_call, "src/consumer.ts", "deep.doThing", "src/origin.ts", "Service", "doThing");
    try expectTypeScriptSymbolCandidate(&first, .member_call, "src/consumer.ts", "service.doThing", "src/origin.ts", "Service", "doThing");
    try expectTypeScriptSymbolCandidate(&first, .member_call, "src/consumer.ts", "PublicService.make", "src/origin.ts", "Service", "make");
    try expectTypeScriptSymbolCandidate(&first, .constructor_call, "src/consumer.ts", "PublicService", "src/origin.ts", "", "Service");
    try std.testing.expect(hasTypeScriptSymbolDiagnostic(&first, .export_cycle));
    const phantom = first.findResolution(.direct_call, "src/consumer.ts", "encode") orelse return error.MissingPhantomCallOutcome;
    try std.testing.expectEqual(zgraphy.TypeScriptSymbols.Status.unresolved, phantom.status);
    const untyped = first.findResolution(.member_call, "src/consumer.ts", "untyped.doThing") orelse return error.MissingUntypedReceiverOutcome;
    try std.testing.expectEqual(zgraphy.TypeScriptSymbols.Status.unresolved, untyped.status);
    const indexed = first.findResolution(.member_call, "src/consumer.ts", "values[0].doThing") orelse return error.MissingIndexedReceiverOutcome;
    try std.testing.expectEqual(zgraphy.TypeScriptSymbols.Status.unresolved, indexed.status);

    var built = try zgraphy.Indexer.buildRepository(std.testing.allocator, std.testing.io, fixture, .{
        .max_nodes = 20_000,
        .max_edges = 80_000,
    });
    defer built.deinit();
    const consumer_file = findGraphNode(&built.graph, .file, "src/consumer.ts", "consumer.ts") orelse return error.MissingSymbolConsumerFile;
    const origin_file = findGraphNode(&built.graph, .file, "src/origin.ts", "origin.ts") orelse return error.MissingSymbolOriginFile;
    const origin_service = findGraphNode(&built.graph, .symbol, "src/origin.ts", "Service") orelse return error.MissingOriginServiceSymbol;
    const origin_method = findGraphNode(&built.graph, .symbol, "src/origin.ts", "doThing") orelse return error.MissingOriginMethodSymbol;
    const other_method = findGraphNode(&built.graph, .symbol, "src/other.ts", "doThing") orelse return error.MissingOtherMethodSymbol;
    const controller = findGraphNode(&built.graph, .symbol, "src/consumer.ts", "Controller") orelse return error.MissingControllerSymbol;
    const controller_run = findGraphNode(&built.graph, .symbol, "src/consumer.ts", "run") orelse return error.MissingControllerRunSymbol;
    const public_service = findGraphNode(&built.graph, .symbol, "src/consumer.ts", "PublicService") orelse return error.MissingImportedPublicServiceSymbol;
    const barrel_service = findGraphNode(&built.graph, .symbol, "src/barrel.ts", "PublicService") orelse return error.MissingBarrelPublicServiceSymbol;
    const phantom_encode = findGraphNode(&built.graph, .symbol, "src/phantom.ts", "encode") orelse return error.MissingPhantomEncodeSymbol;
    try std.testing.expect(built.graph.hasEdge(consumer_file.id, public_service.id, .declares));
    try std.testing.expect(built.graph.hasEdge(public_service.id, origin_file.id, .imports_from));
    try std.testing.expect(built.graph.hasEdge(public_service.id, origin_service.id, .aliases));
    try std.testing.expect(built.graph.hasEdge(barrel_service.id, origin_service.id, .re_exports));
    try std.testing.expect(built.graph.hasEdge(origin_service.id, origin_method.id, .declares));
    try std.testing.expect(built.graph.hasEdge(controller.id, controller_run.id, .declares));
    try std.testing.expect(built.graph.hasEdge(controller_run.id, origin_method.id, .calls));
    try std.testing.expect(built.graph.hasEdge(controller_run.id, other_method.id, .calls));
    try std.testing.expect(built.graph.hasEdge(controller_run.id, origin_service.id, .instantiates));
    try std.testing.expect(!built.graph.hasEdge(controller_run.id, phantom_encode.id, .calls));

    const overlap_bytes = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "benchmarks/adapter-fixtures/graphify-0.9.17/typescript-symbols-overlap.json", std.testing.allocator, .limited(128 * 1024));
    defer std.testing.allocator.free(overlap_bytes);
    var overlap = try std.json.parseFromSlice(GraphifyTypeScriptSymbolOverlap, std.testing.allocator, overlap_bytes, .{ .allocate = .alloc_always, .ignore_unknown_fields = false });
    defer overlap.deinit();
    try std.testing.expectEqualStrings("zgraphy.graphify-typescript-symbol-overlap.v1", overlap.value.schema);
    try std.testing.expectEqualStrings("cb96bdaa0c367bec8d5c5aee5d7c9ebb727e9780", overlap.value.baseline.commit);
    try std.testing.expectEqualStrings("ee2f728fa46e493bd566cf5926c6d1cc305c2b7e977e3c8f8adfc8d55f8e5135", overlap.value.baseline.source_graph_sha256);
    try std.testing.expect(overlap.value.facts.len >= 9);
    try std.testing.expect(overlap.value.classified_differences.len >= 4);
    for (overlap.value.facts) |fact| try expectTypeScriptSymbolCandidate(
        &first,
        typeScriptSymbolFactKind(fact.kind) orelse return error.InvalidGraphifyTypeScriptSymbolFactKind,
        fact.source_path,
        fact.subject,
        fact.target_path,
        fact.target_enclosing,
        fact.target_name,
    );
    for (overlap.value.negative_facts) |fact| {
        const outcome = first.findResolution(
            typeScriptSymbolFactKind(fact.kind) orelse return error.InvalidGraphifyTypeScriptSymbolNegativeFactKind,
            fact.source_path,
            fact.subject,
        ) orelse return error.MissingGraphifyTypeScriptSymbolNegativeFact;
        try std.testing.expectEqual(zgraphy.TypeScriptSymbols.Status.unresolved, outcome.status);
        try std.testing.expectEqual(@as(usize, 0), outcome.candidate_count);
    }

    try assertions.boolean(.{
        .id = "zgraphy.m2.typescript-symbol-origin",
        .label = "imports barrels defaults namespaces and scoped receivers preserve exact origin declarations",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 2270, .column = 1 },
        .repair_hint = "resolve only through explicit export closure module candidates import aliases and lexical type bindings",
    }, first.summary.resolved >= 18 and phantom.status == .unresolved and built.graph.hasEdge(controller_run.id, origin_method.id, .calls));
    try assertions.boolean(.{
        .id = "zgraphy.m2.typescript-symbol-no-global-name-fallback",
        .label = "unimported names untyped arrays and indexed receivers cannot manufacture cross-file call edges",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 2270, .column = 1 },
        .repair_hint = "remove repository-wide name fallback and require one supported receiver evidence path",
    }, phantom.candidate_count == 0 and untyped.candidate_count == 0 and indexed.candidate_count == 0);
    try assertions.noFindings(.{ .id = "zgraphy.m2.typescript-symbol-no-findings", .label = "TypeScript symbol resolution validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m2.typescript-symbol-no-pending", .label = "TypeScript symbol resolution validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

fn hasTypeScriptSymbolDiagnostic(result: *const zgraphy.TypeScriptSymbols.Result, kind: zgraphy.TypeScriptSymbols.DiagnosticKind) bool {
    for (result.diagnostics) |diagnostic| if (diagnostic.kind == kind) return true;
    return false;
}

const GraphifyTypeScriptSymbolOverlap = struct {
    const Baseline = struct {
        product: []const u8,
        version: []const u8,
        commit: []const u8,
        mode: []const u8,
        source_graph_sha256: []const u8,
    };
    const Fact = struct {
        kind: []const u8,
        source_path: []const u8,
        subject: []const u8,
        target_path: []const u8,
        target_enclosing: []const u8,
        target_name: []const u8,
    };
    const NegativeFact = struct {
        kind: []const u8,
        source_path: []const u8,
        subject: []const u8,
    };
    const Difference = struct {
        kind: []const u8,
        graphify_behavior: []const u8,
        zgraphy_improvement: []const u8,
    };

    schema: []const u8,
    baseline: Baseline,
    facts: []const Fact,
    negative_facts: []const NegativeFact,
    classified_differences: []const Difference,
};

fn typeScriptSymbolFactKind(value: []const u8) ?zgraphy.TypeScriptSymbols.FactKind {
    inline for (std.meta.fields(zgraphy.TypeScriptSymbols.FactKind)) |field| {
        if (std.mem.eql(u8, value, field.name)) return @enumFromInt(field.value);
    }
    return null;
}

fn expectTypeScriptSymbolCandidate(
    result: *const zgraphy.TypeScriptSymbols.Result,
    kind: zgraphy.TypeScriptSymbols.FactKind,
    source_path: []const u8,
    subject: []const u8,
    target_path: []const u8,
    target_enclosing: []const u8,
    target_name: []const u8,
) !void {
    const resolution = result.findResolution(kind, source_path, subject) orelse return error.MissingTypeScriptSymbolResolution;
    try std.testing.expectEqual(zgraphy.TypeScriptSymbols.Status.resolved, resolution.status);
    const candidates = result.candidatesFor(resolution);
    try std.testing.expectEqual(@as(usize, 1), candidates.len);
    try std.testing.expectEqualStrings(target_path, candidates[0].target_path);
    try std.testing.expectEqualStrings(target_enclosing, candidates[0].target_enclosing_declaration);
    try std.testing.expectEqualStrings(target_name, candidates[0].target_name);
}

test "zgraphy M2 Proto generated lineage preserves canonical contracts and strict generator evidence" {
    const GraphifyGap = struct {
        schema: []const u8,
        classification: []const u8,
        baseline: struct {
            product: []const u8,
            version: []const u8,
            commit: []const u8,
            mode: []const u8,
            fixture: []const u8,
            source_graph_sha256: []const u8,
            proto_source_sha256: []const u8,
        },
        observed: struct {
            nodes: usize,
            relations: usize,
            proto_files: usize,
            canonical_packages: usize,
            canonical_services: usize,
            canonical_operations: usize,
            canonical_messages: usize,
            canonical_fields: usize,
            generated_lineage_relations: usize,
        },
        expected_canonical_spine: struct {
            package: []const u8,
            services: []const []const u8,
            operations: []const []const u8,
            messages: []const []const u8,
            fields: []const []const u8,
        },
        limitations: []const []const u8,
    };
    const scenario = zstd.Testing.Scenario{
        .id = "m2-proto-generated-lineage",
        .label = "Canonical Proto identities and generated TypeScript Zig bindings share one exact source lineage",
        .requirement = "req-m2-proto-generated-lineage",
        .acceptance_check = "check-m2-proto-generated-lineage",
        .component = "zgraphy",
        .command = "test",
        .default_seed = 1906,
        .source_roots = &.{ "src/protobuf_parser.zig", "src/protobuf_resolution.zig", "src/generated_lineage.zig", "src/indexer.zig", "src/model.zig", "src/semantic_schema.zig", "src/semantic-schema.v2.json", "test/fixtures/proto-lineage", "benchmarks/fixtures/fullstack-orders", "benchmarks/adapter-fixtures/graphify-0.9.17/proto-lineage-gap.json", "src/root.zig", "test/all_test.zig" },
        .tags = &.{ "acceptance", "m2", "proto", "protobuf", "package", "service", "rpc", "message", "field", "field-number", "type-reference", "generated", "protobuf-es", "protoc-gen-zig", "lineage", "typescript", "zig", "graphify", "differential", "deterministic" },
    };
    var evidence = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "zgraphy",
        .suite = "zgraphy-tests",
        .scenario = scenario,
        .seed = 1906,
    });
    defer evidence.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&evidence);

    const gap_bytes = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "benchmarks/adapter-fixtures/graphify-0.9.17/proto-lineage-gap.json", std.testing.allocator, .limited(128 * 1024));
    defer std.testing.allocator.free(gap_bytes);
    var gap = try std.json.parseFromSlice(GraphifyGap, std.testing.allocator, gap_bytes, .{ .ignore_unknown_fields = false });
    defer gap.deinit();
    try std.testing.expectEqualStrings("zgraphy.graphify-proto-lineage-gap.v1", gap.value.schema);
    try std.testing.expectEqualStrings("confirmed-gap", gap.value.classification);
    try std.testing.expectEqualStrings("Graphify", gap.value.baseline.product);
    try std.testing.expectEqualStrings("0.9.17", gap.value.baseline.version);
    try std.testing.expectEqualStrings(zgraphy.Parity.pinned_graphify_commit, gap.value.baseline.commit);
    try std.testing.expectEqual(@as(usize, 11), gap.value.observed.nodes);
    try std.testing.expectEqual(@as(usize, 19), gap.value.observed.relations);
    try std.testing.expectEqual(@as(usize, 0), gap.value.observed.proto_files);
    try std.testing.expectEqual(@as(usize, 0), gap.value.observed.canonical_packages);
    try std.testing.expectEqual(@as(usize, 0), gap.value.observed.canonical_services);
    try std.testing.expectEqual(@as(usize, 0), gap.value.observed.canonical_operations);
    try std.testing.expectEqual(@as(usize, 0), gap.value.observed.canonical_messages);
    try std.testing.expectEqual(@as(usize, 0), gap.value.observed.canonical_fields);
    try std.testing.expectEqual(@as(usize, 0), gap.value.observed.generated_lineage_relations);
    try std.testing.expectEqualStrings("orders.v1", gap.value.expected_canonical_spine.package);
    try std.testing.expectEqualStrings("orders.v1.OrdersService/GetOrder", gap.value.expected_canonical_spine.operations[0]);

    var fullstack_root = try std.Io.Dir.cwd().openDir(std.testing.io, "benchmarks/fixtures/fullstack-orders", .{ .iterate = true, .follow_symlinks = false });
    defer fullstack_root.close(std.testing.io);
    var fullstack = try zgraphy.Indexer.buildRepository(std.testing.allocator, std.testing.io, fullstack_root, .{
        .repository_id = "repo-24062406240624062406240624062406",
        .max_nodes = 4096,
        .max_edges = 16_384,
    });
    defer fullstack.deinit();
    _ = findGraphNode(&fullstack.graph, .package, "proto/orders/v1/orders.proto", "orders.v1") orelse return error.MissingFullstackProtoPackage;
    _ = findGraphNode(&fullstack.graph, .service, "proto/orders/v1/orders.proto", "orders.v1.OrdersService") orelse return error.MissingFullstackProtoService;
    _ = findGraphNode(&fullstack.graph, .operation, "proto/orders/v1/orders.proto", "orders.v1.OrdersService/GetOrder") orelse return error.MissingFullstackProtoOperation;
    _ = findGraphNode(&fullstack.graph, .message, "proto/orders/v1/orders.proto", "orders.v1.GetOrderRequest") orelse return error.MissingFullstackProtoRequest;
    _ = findGraphNode(&fullstack.graph, .message, "proto/orders/v1/orders.proto", "orders.v1.Order") orelse return error.MissingFullstackProtoResponse;
    try std.testing.expect(fullstack.summary.proto_entities >= 8);

    var fixture = try std.Io.Dir.cwd().openDir(std.testing.io, "test/fixtures/proto-lineage", .{ .iterate = true, .follow_symlinks = false });
    defer fixture.close(std.testing.io);
    var corpus = try zgraphy.ProtobufResolution.Corpus.init(std.testing.allocator, .{});
    defer corpus.deinit();
    for ([_][]const u8{ "proto/common/v1/money.proto", "proto/orders/v1/orders.proto" }) |path| {
        const source = try fixture.readFileAlloc(std.testing.io, path, std.testing.allocator, .limited(128 * 1024));
        defer std.testing.allocator.free(source);
        try corpus.addSource(path, source);
    }
    var first = try corpus.resolve();
    defer first.deinit();
    var second = try corpus.resolve();
    defer second.deinit();
    try std.testing.expectEqualSlices(u8, &first.fingerprint, &second.fingerprint);
    var reversed_corpus = try zgraphy.ProtobufResolution.Corpus.init(std.testing.allocator, .{});
    defer reversed_corpus.deinit();
    for ([_][]const u8{ "proto/orders/v1/orders.proto", "proto/common/v1/money.proto" }) |path| {
        const source = try fixture.readFileAlloc(std.testing.io, path, std.testing.allocator, .limited(128 * 1024));
        defer std.testing.allocator.free(source);
        try reversed_corpus.addSource(path, source);
    }
    var reversed = try reversed_corpus.resolve();
    defer reversed.deinit();
    try std.testing.expectEqualSlices(u8, &first.fingerprint, &reversed.fingerprint);

    _ = first.findEntity(.package, "orders.v1") orelse return error.MissingOrdersProtoPackage;
    _ = first.findEntity(.message, "orders.v1.GetOrderRequest") orelse return error.MissingGetOrderRequestMessage;
    _ = first.findEntity(.message, "orders.v1.Order") orelse return error.MissingOrderMessage;
    _ = first.findEntity(.message, "orders.v1.Order.Item") orelse return error.MissingNestedOrderItemMessage;
    _ = first.findEntity(.enumeration, "orders.v1.Order.State") orelse return error.MissingOrderStateEnum;
    _ = first.findEntity(.service, "orders.v1.OrdersService") orelse return error.MissingOrdersProtoService;
    _ = first.findEntity(.operation, "orders.v1.OrdersService/GetOrder") orelse return error.MissingGetOrderOperation;
    const id_field = first.findEntity(.field, "orders.v1.Order#1") orelse return error.MissingStableOrderIdField;
    try std.testing.expectEqualStrings("orders.v1.Order.id", id_field.display_name);
    try std.testing.expectEqual(@as(i64, 1), id_field.number);
    try expectProtobufReference(&first, .field_type, "orders.v1.Order#2", "proto/common/v1/money.proto", .message, "common.v1.Money");
    try expectProtobufReference(&first, .rpc_request, "orders.v1.OrdersService/GetOrder", "proto/orders/v1/orders.proto", .message, "orders.v1.GetOrderRequest");
    try expectProtobufReference(&first, .rpc_response, "orders.v1.OrdersService/GetOrder", "proto/orders/v1/orders.proto", .message, "orders.v1.Order");
    const timestamp = first.findReference(.field_type, "orders.v1.Order#3") orelse return error.MissingExternalTimestampReference;
    try std.testing.expectEqual(zgraphy.ProtobufResolution.Status.external, timestamp.status);
    try std.testing.expectEqual(@as(usize, 0), timestamp.candidate_count);

    var visibility_corpus = try zgraphy.ProtobufResolution.Corpus.init(std.testing.allocator, .{});
    defer visibility_corpus.deinit();
    for ([_]struct { path: []const u8, source: []const u8 }{
        .{ .path = "proto/shared.proto", .source = "syntax = \"proto3\"; package shared; message Shared {}" },
        .{ .path = "proto/facade.proto", .source = "syntax = \"proto3\"; package facade; import public \"proto/shared.proto\";" },
        .{ .path = "proto/consumer.proto", .source = "syntax = \"proto3\"; package app; import \"proto/facade.proto\"; message Uses { shared.Shared value = 1; }" },
        .{ .path = "vendor/a/common/v1/money.proto", .source = "syntax = \"proto3\"; package common.v1; message Money {}" },
        .{ .path = "vendor/b/common/v1/money.proto", .source = "syntax = \"proto3\"; package common.v1; message Money {}" },
        .{ .path = "proto/ambiguous.proto", .source = "syntax = \"proto3\"; package app; import \"common/v1/money.proto\"; message Priced { common.v1.Money total = 1; }" },
        .{ .path = "unrelated/ghost.proto", .source = "syntax = \"proto3\"; package ghost; message Phantom {}" },
        .{ .path = "proto/no-import.proto", .source = "syntax = \"proto3\"; package app; message NoImport { ghost.Phantom value = 1; }" },
    }) |document| try visibility_corpus.addSource(document.path, document.source);
    var visibility = try visibility_corpus.resolve();
    defer visibility.deinit();
    try expectProtobufReference(&visibility, .field_type, "app.Uses#1", "proto/shared.proto", .message, "shared.Shared");
    const ambiguous_import = visibility.findReference(.field_type, "app.Priced#1") orelse return error.MissingAmbiguousProtoImportReference;
    try std.testing.expectEqual(zgraphy.ProtobufResolution.Status.ambiguous, ambiguous_import.status);
    try std.testing.expectEqual(@as(usize, 2), ambiguous_import.candidate_count);
    const forbidden_global = visibility.findReference(.field_type, "app.NoImport#1") orelse return error.MissingNoGlobalFallbackReference;
    try std.testing.expectEqual(zgraphy.ProtobufResolution.Status.unresolved, forbidden_global.status);
    try std.testing.expectEqual(@as(usize, 0), forbidden_global.candidate_count);

    var generated = try zgraphy.GeneratedLineage.Corpus.init(std.testing.allocator, .{});
    defer generated.deinit();
    for ([_]struct { path: []const u8, language: zgraphy.GeneratedLineage.Language }{
        .{ .path = "frontend/gen/orders/v1/orders_pb.ts", .language = .typescript },
        .{ .path = "backend/gen/orders/v1.pb.zig", .language = .zig },
        .{ .path = "frontend/gen/orders/v1/deceptive_pb.ts", .language = .typescript },
        .{ .path = "backend/gen/orders/deceptive.pb.zig", .language = .zig },
        .{ .path = "frontend/src/deceptive.ts", .language = .typescript },
        .{ .path = "backend/src/deceptive.zig", .language = .zig },
    }) |source_spec| {
        const source = try fixture.readFileAlloc(std.testing.io, source_spec.path, std.testing.allocator, .limited(128 * 1024));
        defer std.testing.allocator.free(source);
        try generated.addSource(source_spec.path, source, source_spec.language);
    }
    var lineage = try generated.resolve(&first);
    defer lineage.deinit();
    var reversed_generated = try zgraphy.GeneratedLineage.Corpus.init(std.testing.allocator, .{});
    defer reversed_generated.deinit();
    for ([_]struct { path: []const u8, language: zgraphy.GeneratedLineage.Language }{
        .{ .path = "backend/src/deceptive.zig", .language = .zig },
        .{ .path = "frontend/src/deceptive.ts", .language = .typescript },
        .{ .path = "backend/gen/orders/deceptive.pb.zig", .language = .zig },
        .{ .path = "frontend/gen/orders/v1/deceptive_pb.ts", .language = .typescript },
        .{ .path = "backend/gen/orders/v1.pb.zig", .language = .zig },
        .{ .path = "frontend/gen/orders/v1/orders_pb.ts", .language = .typescript },
    }) |source_spec| {
        const source = try fixture.readFileAlloc(std.testing.io, source_spec.path, std.testing.allocator, .limited(128 * 1024));
        defer std.testing.allocator.free(source);
        try reversed_generated.addSource(source_spec.path, source, source_spec.language);
    }
    var reversed_lineage = try reversed_generated.resolve(&first);
    defer reversed_lineage.deinit();
    try std.testing.expectEqualSlices(u8, &lineage.fingerprint, &reversed_lineage.fingerprint);
    try expectGeneratedBinding(&lineage, .typescript, .file, "frontend/gen/orders/v1/orders_pb.ts", "orders/v1/orders.proto");
    try expectGeneratedBinding(&lineage, .typescript, .service, "frontend/gen/orders/v1/orders_pb.ts", "orders.v1.OrdersService");
    try expectGeneratedBinding(&lineage, .typescript, .operation, "frontend/gen/orders/v1/orders_pb.ts", "orders.v1.OrdersService/GetOrder");
    try expectGeneratedBinding(&lineage, .zig, .service, "backend/gen/orders/v1.pb.zig", "orders.v1.OrdersService");
    try expectGeneratedBinding(&lineage, .zig, .operation, "backend/gen/orders/v1.pb.zig", "orders.v1.OrdersService/GetOrder");
    try std.testing.expect(lineage.findBinding(.typescript, .service, "frontend/src/deceptive.ts", "orders.v1.OrdersService") == null);
    try std.testing.expect(lineage.findBinding(.zig, .message, "backend/src/deceptive.zig", "orders.v1.Order") == null);
    try std.testing.expect(lineage.findBinding(.typescript, .service, "frontend/gen/orders/v1/deceptive_pb.ts", "orders.v1.OrdersService") == null);
    try std.testing.expect(lineage.findBinding(.zig, .service, "backend/gen/orders/deceptive.pb.zig", "orders.v1.OrdersService") == null);

    var built = try zgraphy.Indexer.buildRepository(std.testing.allocator, std.testing.io, fixture, .{
        .repository_id = "repo-19061906190619061906190619061906",
        .max_nodes = 4096,
        .max_edges = 16_384,
    });
    defer built.deinit();
    const proto_file = findGraphNode(&built.graph, .file, "proto/orders/v1/orders.proto", "orders.proto") orelse return error.MissingGraphedOrdersProtoFile;
    const service = findGraphNode(&built.graph, .service, "proto/orders/v1/orders.proto", "orders.v1.OrdersService") orelse return error.MissingGraphedOrdersService;
    const operation = findGraphNode(&built.graph, .operation, "proto/orders/v1/orders.proto", "orders.v1.OrdersService/GetOrder") orelse return error.MissingGraphedGetOrderOperation;
    const order = findGraphNode(&built.graph, .message, "proto/orders/v1/orders.proto", "orders.v1.Order") orelse return error.MissingGraphedOrderMessage;
    const request = findGraphNode(&built.graph, .message, "proto/orders/v1/orders.proto", "orders.v1.GetOrderRequest") orelse return error.MissingGraphedGetOrderRequest;
    const total = findGraphNode(&built.graph, .field, "proto/orders/v1/orders.proto", "orders.v1.Order#2") orelse return error.MissingGraphedOrderTotalField;
    const money = findGraphNode(&built.graph, .message, "proto/common/v1/money.proto", "common.v1.Money") orelse return error.MissingGraphedMoneyMessage;
    const ts_service = findGraphNode(&built.graph, .service, "frontend/gen/orders/v1/orders_pb.ts", "orders.v1.OrdersService") orelse return error.MissingGraphedGeneratedTypeScriptService;
    const zig_service = findGraphNode(&built.graph, .service, "backend/gen/orders/v1.pb.zig", "orders.v1.OrdersService") orelse return error.MissingGraphedGeneratedZigService;
    const ts_file = findGraphNode(&built.graph, .file, "frontend/gen/orders/v1/orders_pb.ts", "orders_pb.ts") orelse return error.MissingGraphedGeneratedTypeScriptFile;
    try std.testing.expect(built.graph.hasEdge(proto_file.id, service.id, .declares));
    try std.testing.expect(built.graph.hasEdge(service.id, operation.id, .declares));
    try std.testing.expect(built.graph.hasEdge(order.id, total.id, .has_field));
    try std.testing.expect(built.graph.hasEdge(operation.id, request.id, .uses_request));
    try std.testing.expect(built.graph.hasEdge(operation.id, order.id, .uses_response));
    try std.testing.expect(built.graph.hasEdge(total.id, money.id, .references_type));
    try std.testing.expect(built.graph.hasEdge(ts_service.id, service.id, .generated_client_for));
    try std.testing.expect(built.graph.hasEdge(zig_service.id, service.id, .generated_server_for));
    try std.testing.expect(built.graph.hasEdge(ts_file.id, proto_file.id, .generated_from));

    try assertions.boolean(.{
        .id = "zgraphy.m2.proto-canonical-identity",
        .label = "Proto packages operations messages and immutable-number fields have exact source-qualified identities",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 2500, .column = 1 },
        .repair_hint = "derive canonical identities from parsed package lexical owner and field number before resolving references",
    }, first.summary.resolved >= 3 and timestamp.status == .external and built.graph.hasEdge(operation.id, request.id, .uses_request));
    try assertions.boolean(.{
        .id = "zgraphy.m2.generated-lineage-strict",
        .label = "only strict Protobuf-ES and protoc-gen-zig evidence links generated bindings to canonical source",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 2500, .column = 1 },
        .repair_hint = "require generator header package or source marker and exact canonical entity candidates",
    }, lineage.bindings.len >= 10 and built.graph.hasEdge(ts_service.id, service.id, .generated_client_for) and built.graph.hasEdge(zig_service.id, service.id, .generated_server_for));
    try assertions.noFindings(.{ .id = "zgraphy.m2.proto-lineage-no-findings", .label = "Proto generated-lineage validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m2.proto-lineage-no-pending", .label = "Proto generated-lineage validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}

test "zgraphy M2 Proto generated lineage enforces corpus result and marker bounds" {
    var files = try zgraphy.ProtobufResolution.Corpus.init(std.testing.allocator, .{ .max_files = 1 });
    defer files.deinit();
    try files.addSource("one.proto", "syntax = \"proto3\"; message One {}");
    try std.testing.expectError(error.ProtoResolutionFileLimitExceeded, files.addSource("two.proto", "syntax = \"proto3\"; message Two {}"));

    var entities = try zgraphy.ProtobufResolution.Corpus.init(std.testing.allocator, .{ .max_entities = 1 });
    defer entities.deinit();
    try entities.addSource("bounded.proto", "syntax = \"proto3\"; package bounded; message Value {}");
    try std.testing.expectError(error.ProtoResolutionEntityLimitExceeded, entities.resolve());

    try std.testing.expectError(error.InvalidGeneratedLineageOptions, zgraphy.GeneratedLineage.Corpus.init(std.testing.allocator, .{ .max_marker_bytes = 0 }));
    var documents = try zgraphy.GeneratedLineage.Corpus.init(std.testing.allocator, .{ .max_documents = 1 });
    defer documents.deinit();
    try documents.addSource("gen/one_pb.ts", "// source", .typescript);
    try std.testing.expectError(error.GeneratedLineageDocumentLimitExceeded, documents.addSource("gen/two_pb.ts", "// source", .typescript));
}

fn expectProtobufReference(
    result: *const zgraphy.ProtobufResolution.Result,
    kind: zgraphy.ProtobufResolution.ReferenceKind,
    subject: []const u8,
    target_path: []const u8,
    target_kind: zgraphy.ProtobufResolution.EntityKind,
    canonical_name: []const u8,
) !void {
    const reference = result.findReference(kind, subject) orelse return error.MissingProtobufReference;
    try std.testing.expectEqual(zgraphy.ProtobufResolution.Status.resolved, reference.status);
    const candidates = result.candidatesFor(reference);
    try std.testing.expectEqual(@as(usize, 1), candidates.len);
    try std.testing.expectEqualStrings(target_path, candidates[0].target_path);
    try std.testing.expectEqual(target_kind, candidates[0].target_kind);
    try std.testing.expectEqualStrings(canonical_name, candidates[0].canonical_name);
}

fn expectGeneratedBinding(
    result: *const zgraphy.GeneratedLineage.Result,
    language: zgraphy.GeneratedLineage.Language,
    kind: zgraphy.GeneratedLineage.BindingKind,
    source_path: []const u8,
    canonical_name: []const u8,
) !void {
    const binding = result.findBinding(language, kind, source_path, canonical_name) orelse return error.MissingGeneratedBinding;
    try std.testing.expectEqual(zgraphy.GeneratedLineage.Status.resolved, binding.status);
    try std.testing.expectEqual(@as(usize, 1), binding.candidate_count);
}
