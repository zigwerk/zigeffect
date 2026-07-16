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
    try std.testing.expectEqualStrings("zgraphy-native-v1", receipt.adapter.adapter_version);
    try std.testing.expectEqual(@as(usize, 11), receipt.input.nodes);
    try std.testing.expectEqual(@as(usize, 12), receipt.input.relations);
    try std.testing.expectEqual(@as(usize, 8), receipt.entities.matched);
    try std.testing.expectEqual(@as(usize, 0), receipt.entities.missing);
    try std.testing.expectEqual(@as(usize, 3), receipt.entities.unexpected);
    try std.testing.expectEqual(@as(usize, 9), receipt.relations.matched);
    try std.testing.expectEqual(@as(usize, 3), receipt.relations.missing);
    try std.testing.expectEqual(@as(usize, 6), receipt.relations.unexpected);
    try std.testing.expect(!zgraphy.Differential.containsId(receipt.missing_entity_ids, "symbol:zig-ambiguity:loader"));
    try std.testing.expect(zgraphy.Differential.containsId(receipt.missing_relation_ids, "rel:zig-ambiguity:loader-candidate-alpha"));
    try std.testing.expect(zgraphy.Differential.containsId(receipt.missing_fact_ids, "fact:zig-ambiguity:loader-resolution"));

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
    try std.testing.expectEqual(@as(usize, 5), mutation_receipt.relations.unexpected);

    try assertions.boolean(.{
        .id = "zgraphy.m0.native-adapter-honest-projection",
        .label = "the native adapter maps every canonical ambiguity entity while exposing internal extras and unresolved candidate semantics",
        .source = .{ .id = "zgraphy-tests", .path = "test/all_test.zig", .line = 467, .column = 1 },
        .repair_hint = "repair native source-qualified projection without filtering internal extras or inventing ambiguity candidate edges",
    }, receipt.entities.matched == 8 and receipt.entities.missing == 0 and receipt.entities.unexpected == 3 and receipt.relations.missing == 3);
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
        .repair_hint = "reject incomplete or mixed resource samples and derive quantiles from the retained observations",
    }, graphify_resources.elapsed_ns.p50 == 130 and native_resources.elapsed_ns.p50 == 70 and resources.claims.len == 0);
    try assertions.boolean(.{
        .id = "zgraphy.m0.full-rebuild-prunes",
        .label = "a full rebuild removes deleted identities and republishes a complete clean equivalent snapshot",
        .repair_hint = "replace the complete snapshot transactionally and reject stale nodes dangling endpoints or unowned vectors",
    }, deleted_health.clean() and loaded_deleted.findNode(zgraphy.stableId(.symbol, "src/catalog.zig", "feature")) == null);
    try assertions.boolean(.{
        .id = "zgraphy.m0.freshness-honesty",
        .label = "the M0 freshness receipt does not claim incremental or automatic pre-query refresh support",
        .repair_hint = "keep unsupported capabilities explicit until an exercised updater path matches a clean build",
    }, freshness.capabilities.incremental_update == .unsupported and freshness.capabilities.pre_query_refresh == .unsupported and !freshness.freshness_gate_passed and freshness.claims.len == 0);
    try assertions.noFindings(.{ .id = "zgraphy.m0.resource-freshness-no-findings", .label = "resource and freshness validation has no causal findings" });
    try assertions.noPendingFibers(.{ .id = "zgraphy.m0.resource-freshness-no-pending", .label = "resource and freshness validation leaves no pending fibers" });
    try evidence.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}
