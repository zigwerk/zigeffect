const std = @import("std");
const zgraphy = @import("zgraphy");
const zstd = @import("zigeffect_std");
const owned = zgraphy.Memory;

const CommandProgram = zstd.fx.kernel.Effect(void, anyerror, .{zgraphy.Application.ApplicationInputs});

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 2 or isHelp(args[1])) {
        try printHelp(init.io);
        return;
    }
    const root_path = selectedRoot(args);
    var root = try std.Io.Dir.cwd().openDir(init.io, root_path, .{ .iterate = true, .follow_symlinks = false });
    defer root.close(init.io);
    try root.createDirPath(init.io, ".zgraphy");
    const main_layer = zgraphy.Application.rootLayer(.{ .io = init.io, .root = root, .args = args });
    var runtime = try zstd.ManagedRuntime(@TypeOf(main_layer)).make(
        init.gpa,
        init.io,
        root,
        main_layer,
        .{ .graph = .{ .path = zgraphy.Application.causal_graph_path, .max_records = 4096, .max_wal_bytes = 16 * 1024 * 1024 } },
    );
    defer runtime.deinit();
    try runtime.run(commandEffect());
    var application = try runtime.inspect(init.gpa, .{ .max_recent_events = 64 });
    defer application.deinit();
    if (application.services.len == 0) return error.InvalidApplicationSnapshot;
    if (runtime.causalHealth().status != .healthy) return error.CausalRuntimeUnhealthy;
    try runtime.shutdown();
}

fn commandEffect() CommandProgram {
    return CommandProgram.fromFn(struct {
        fn run(ctx: *CommandProgram.Context) anyerror!void {
            const value = ctx.service(zgraphy.Application.ApplicationInputs);
            const command = value.args[1];
            dispatch(ctx.allocator(), value.io, value.root, value.args) catch |failure| {
                _ = ctx.recordCausal(.{
                    .kind = .activity_completed,
                    .label = "zgraphy.cli",
                    .status = "failure",
                    .redacted_detail = @errorName(failure),
                });
                return failure;
            };
            _ = ctx.recordCausal(.{
                .kind = .activity_completed,
                .label = command,
                .status = "success",
                .redacted_detail = "zgraphy-cli-command",
            });
        }
    }.run);
}

fn dispatch(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, args: []const []const u8) !void {
    const command = args[1];
    if (std.mem.eql(u8, command, "init")) return runInit(allocator, io, root, hasFlag(args, "--json"));
    if (std.mem.eql(u8, command, "build") or std.mem.eql(u8, command, "ingest")) return runBuild(allocator, io, root, hasFlag(args, "--json"));
    if (std.mem.eql(u8, command, "status")) return runStatus(allocator, io, root, hasFlag(args, "--json"));
    if (std.mem.eql(u8, command, "doctor")) return runDoctor(allocator, io, root, hasFlag(args, "--json"));
    if (std.mem.eql(u8, command, "query")) return runQuery(allocator, io, root, args);
    if (std.mem.eql(u8, command, "explain")) return runExplain(allocator, io, root, args);
    if (std.mem.eql(u8, command, "path")) return runPath(allocator, io, root, args);
    if (std.mem.eql(u8, command, "parity")) return runParity(allocator, io, hasFlag(args, "--json"));
    if (std.mem.eql(u8, command, "schema")) return runSemanticSchema(allocator, io, args);
    if (std.mem.eql(u8, command, "contracts")) return runOperationalContracts(allocator, io, args);
    if (std.mem.eql(u8, command, "security")) return runSecurityBaseline(allocator, io, args);
    if (std.mem.eql(u8, command, "evaluation")) return runEvaluationContracts(allocator, io, args);
    if (std.mem.eql(u8, command, "benchmark")) return runBenchmark(allocator, io, root, args);
    return error.InvalidCommand;
}

fn runInit(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, json: bool) !void {
    const status = try zgraphy.Project.init(allocator, io, root);
    if (json) return writeJson(io, allocator, .{
        .schema = "zgraphy.init.v1",
        .status = @tagName(status),
        .config = zgraphy.Project.config_path,
    });
    return switch (status) {
        .initialized => writeText(io, allocator, "initialized {s}\n", .{zgraphy.Project.config_path}),
        .already_initialized => writeText(io, allocator, "already initialized {s}\n", .{zgraphy.Project.config_path}),
    };
}

fn runBuild(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, json: bool) !void {
    var config = try zgraphy.Project.loadConfig(allocator, io, root);
    defer config.deinit();
    var built = try zgraphy.Indexer.buildRepository(allocator, io, root, zgraphy.Operations.buildOptions(config.value));
    defer built.deinit();
    try zgraphy.Store.save(io, root, config.value.database, &built.graph);
    try zgraphy.Operations.publish(allocator, io, root, config.value, &built);
    if (json) return writeJson(io, allocator, .{
        .schema = "zgraphy.build.v1",
        .status = "complete",
        .database = config.value.database,
        .summary = built.summary,
    });
    return writeText(io, allocator, "built {d} nodes, {d} edges, {d} vectors, {d} request paths, {d} feature supernodes from {d} files -> {s}\n", .{
        built.summary.nodes,
        built.summary.edges,
        built.summary.vectors,
        built.summary.request_paths,
        built.summary.feature_supernodes,
        built.summary.files_indexed,
        config.value.database,
    });
}

fn runDoctor(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, json: bool) !void {
    var config = try zgraphy.Project.loadConfig(allocator, io, root);
    defer config.deinit();
    var report = try zgraphy.Operations.doctor(allocator, io, root, config.value);
    if (json) {
        const encoded = try zgraphy.Operations.encodeDoctorAlloc(allocator, config.value, &report);
        defer allocator.free(encoded);
        try std.Io.File.stdout().writeStreamingAll(io, encoded);
        return std.Io.File.stdout().writeStreamingAll(io, "\n");
    }
    return writeText(io, allocator, "{s}: {d} nodes, {d} edges, {d} vectors, {d} diagnostics\n", .{
        @tagName(report.status),
        report.nodes,
        report.edges,
        report.vectors,
        report.diagnostics().len,
    });
}

fn runStatus(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, json: bool) !void {
    var loaded = try loadGraph(allocator, io, root);
    defer loaded.deinit();
    const stats = loaded.graph.topology.stats();
    if (json) return writeJson(io, allocator, .{
        .schema = "zgraphy.status.v1",
        .status = "ready",
        .database = loaded.database,
        .stats = stats,
        .semantic = .{
            .hyperedges = loaded.graph.hyperedgeCount(),
            .supernodes = loaded.graph.supernodeCount(),
        },
    });
    return writeText(io, allocator, "ready: {d} nodes, {d} edges, {d} vectors, {d} hyperedges, {d} supernodes ({s}, {s})\n", .{
        stats.node_count,
        stats.edge_count,
        stats.vector_count,
        loaded.graph.hyperedgeCount(),
        loaded.graph.supernodeCount(),
        stats.engine,
        stats.embedder_name,
    });
}

fn runParity(allocator: std.mem.Allocator, io: std.Io, json: bool) !void {
    var parsed = try zgraphy.Parity.parseEmbedded(allocator);
    defer parsed.deinit();
    try zgraphy.Parity.validate(&parsed.value);
    const summary = zgraphy.Parity.summarize(&parsed.value);
    if (json) return writeJson(io, allocator, .{
        .schema = zgraphy.Parity.schema,
        .schema_version = zgraphy.Parity.schema_version,
        .baseline = parsed.value.baseline,
        .summary = summary,
        .capabilities = parsed.value.capabilities,
    });
    return writeText(io, allocator, "Graphify {s} {s}: {d} capability families ({d} core, {d} improved, {d} optional, {d} visual-deferred)\n", .{
        parsed.value.baseline.version,
        parsed.value.baseline.commit,
        summary.total,
        summary.core_parity,
        summary.improved_equivalent,
        summary.optional_parity,
        summary.deferred_visual,
    });
}

fn runSemanticSchema(allocator: std.mem.Allocator, io: std.Io, args: []const []const u8) !void {
    var parsed = try zgraphy.SemanticSchema.parseEmbedded(allocator);
    defer parsed.deinit();
    try zgraphy.SemanticSchema.validate(&parsed.value);
    const digest = zgraphy.SemanticSchema.contractDigest();
    const digest_hex = std.fmt.bytesToHex(digest, .lower);

    if (positional(args, 0)) |relation_name| {
        const relation = try zgraphy.SemanticSchema.resolveRelation(&parsed.value, relation_name);
        if (hasFlag(args, "--json")) return writeJson(io, allocator, .{
            .schema = "zgraphy.semantic-relation.v2",
            .schema_version = zgraphy.SemanticSchema.schema_version,
            .contract_digest = digest_hex,
            .relation = relation,
        });
        return writeText(io, allocator, "{s}: {s} -> {s} ({s}, evidence {s}, reverse traversal {any}, parallel {any})\n", .{
            relation.name,
            relation.source_role,
            relation.target_role,
            relation.family,
            @tagName(relation.evidence),
            relation.reverse_traversal,
            relation.parallel_instances,
        });
    }

    if (hasFlag(args, "--json")) return writeJson(io, allocator, .{
        .schema = parsed.value.schema,
        .schema_version = parsed.value.schema_version,
        .contract_digest = digest_hex,
        .maturity = parsed.value.maturity,
        .record_count = parsed.value.records.len,
        .node_kind_count = parsed.value.node_kinds.len,
        .origin_count = parsed.value.origins.len,
        .epistemic_status_count = parsed.value.epistemic_statuses.len,
        .family_count = parsed.value.families.len,
        .relation_count = parsed.value.relations.len,
        .compatibility_mapping_count = parsed.value.compatibility.len,
        .graphify_provenance_mapping_count = parsed.value.graphify_provenance.len,
        .migration = parsed.value.migration,
        .storage = .{
            .current_schema = zgraphy.Store.current_schema,
            .legacy_read_schema = zgraphy.Store.schema,
            .hyperedges = true,
            .supernodes = true,
            .complete_schema_v2 = false,
        },
    });
    return writeText(io, allocator, "semantic schema v{d}: {d} records, {d} node kinds, {d} provenance origins, {d} statuses, {d} relation families, {d} relations (hyperedge/supernode storage active; full generations pending)\n", .{
        parsed.value.schema_version,
        parsed.value.records.len,
        parsed.value.node_kinds.len,
        parsed.value.origins.len,
        parsed.value.epistemic_statuses.len,
        parsed.value.families.len,
        parsed.value.relations.len,
    });
}

fn runOperationalContracts(allocator: std.mem.Allocator, io: std.Io, args: []const []const u8) !void {
    var parsed = try zgraphy.OperationalContracts.parseEmbedded(allocator);
    defer parsed.deinit();
    try zgraphy.OperationalContracts.validate(&parsed.value);
    const digest = zgraphy.OperationalContracts.contractDigest();
    const digest_hex = std.fmt.bytesToHex(digest, .lower);

    if (positional(args, 0)) |section| {
        if (std.mem.eql(u8, section, "provider")) return writeJson(io, allocator, .{ .contract_digest = digest_hex, .provider = parsed.value.provider });
        if (std.mem.eql(u8, section, "conformance")) return writeJson(io, allocator, .{ .contract_digest = digest_hex, .conformance = parsed.value.conformance });
        if (std.mem.eql(u8, section, "config")) return writeJson(io, allocator, .{ .contract_digest = digest_hex, .config = parsed.value.config });
        if (std.mem.eql(u8, section, "health")) return writeJson(io, allocator, .{ .contract_digest = digest_hex, .health = parsed.value.health });
        if (std.mem.eql(u8, section, "diagnostic")) return writeJson(io, allocator, .{ .contract_digest = digest_hex, .diagnostic = parsed.value.diagnostic });
        if (std.mem.eql(u8, section, "migration")) return writeJson(io, allocator, .{ .contract_digest = digest_hex, .migration = parsed.value.migration });
        return error.UnknownOperationalContract;
    }

    if (hasFlag(args, "--json")) return writeJson(io, allocator, .{
        .schema = parsed.value.schema,
        .schema_version = parsed.value.schema_version,
        .contract_digest = digest_hex,
        .maturity = parsed.value.maturity,
        .provider_kinds = parsed.value.provider.kinds.len,
        .authorities = parsed.value.provider.authorities.len,
        .conformance_dimensions = parsed.value.conformance.dimensions.len,
        .conformance_profiles = parsed.value.conformance.profiles.len,
        .config_modes = parsed.value.config.modes.len,
        .health_statuses = parsed.value.health.statuses.len,
        .health_dimensions = parsed.value.health.dimensions.len,
        .diagnostic_stages = parsed.value.diagnostic.stages.len,
        .migration_states = parsed.value.migration.states.len,
        .runtime_schemas_changed = true,
        .external_authority_granted = false,
    });
    return writeText(io, allocator, "operational contracts v{d}: {d} provider kinds, {d} conformance dimensions, {d} config modes, {d} health dimensions (config v2 identity/bounds active, no external authority)\n", .{
        parsed.value.schema_version,
        parsed.value.provider.kinds.len,
        parsed.value.conformance.dimensions.len,
        parsed.value.config.modes.len,
        parsed.value.health.dimensions.len,
    });
}

fn runSecurityBaseline(allocator: std.mem.Allocator, io: std.Io, args: []const []const u8) !void {
    var parsed = try zgraphy.SecurityBaseline.parseEmbedded(allocator);
    defer parsed.deinit();
    try zgraphy.SecurityBaseline.validate(&parsed.value);
    const digest = zgraphy.SecurityBaseline.catalogDigest();
    const digest_hex = std.fmt.bytesToHex(digest, .lower);

    if (positional(args, 0)) |threat_id| {
        const threat = zgraphy.SecurityBaseline.findThreat(&parsed.value, threat_id) orelse return error.UnknownSecurityThreat;
        return writeJson(io, allocator, .{
            .schema = "zgraphy.security-threat.v1",
            .catalog_digest = digest_hex,
            .threat = threat,
        });
    }

    const summary = zgraphy.SecurityBaseline.summarize(&parsed.value);
    if (hasFlag(args, "--json")) return writeJson(io, allocator, .{
        .schema = parsed.value.schema,
        .schema_version = parsed.value.schema_version,
        .catalog_digest = digest_hex,
        .graphify_version = parsed.value.graphify.version,
        .graphify_commit = parsed.value.graphify.commit,
        .boundaries = parsed.value.boundaries.len,
        .assets = parsed.value.assets.len,
        .controls = parsed.value.controls.len,
        .summary = summary,
    });
    return writeText(io, allocator, "security baseline: {d} threats, {d} controls; fixtures {d} exercised, {d} contract, {d} planned, {d} deferred, {d} absent guards\n", .{
        summary.total,
        parsed.value.controls.len,
        summary.exercised,
        summary.contract_exercised,
        summary.planned,
        summary.deferred,
        summary.not_applicable,
    });
}

fn runEvaluationContracts(allocator: std.mem.Allocator, io: std.Io, args: []const []const u8) !void {
    var parsed = try zgraphy.EvaluationContracts.parseEmbedded(allocator);
    defer parsed.deinit();
    try zgraphy.EvaluationContracts.validate(&parsed.value);
    const digest = zgraphy.EvaluationContracts.contractDigest();
    const digest_hex = std.fmt.bytesToHex(digest, .lower);

    if (positional(args, 0)) |kind_name| {
        const kind = std.meta.stringToEnum(zgraphy.EvaluationContracts.EvaluationKind, kind_name) orelse return error.UnknownEvaluationKind;
        const definition = zgraphy.EvaluationContracts.findDefinition(&parsed.value, kind) orelse return error.UnknownEvaluationKind;
        return writeJson(io, allocator, .{
            .schema = "zgraphy.evaluation-definition.v1",
            .contract_digest = digest_hex,
            .definition = definition,
            .claim_policy = parsed.value.claim_policy,
        });
    }

    var active_baselines: usize = 0;
    var schema_only: usize = 0;
    for (parsed.value.definitions) |definition| switch (definition.evidence_state) {
        .active_baseline => active_baselines += 1,
        .schema_only => schema_only += 1,
    };
    if (hasFlag(args, "--json")) return writeJson(io, allocator, .{
        .schema = parsed.value.schema,
        .schema_version = parsed.value.schema_version,
        .contract_digest = digest_hex,
        .definitions = parsed.value.definitions,
        .claim_policy = parsed.value.claim_policy,
        .active_baselines = active_baselines,
        .schema_only = schema_only,
    });
    return writeText(io, allocator, "evaluation contracts: {d} kinds, {d} active baselines, {d} schema-only; claims {s}\n", .{
        parsed.value.definitions.len,
        active_baselines,
        schema_only,
        @tagName(parsed.value.claim_policy.maturity),
    });
}

fn runBenchmark(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, args: []const []const u8) !void {
    const subcommand = positional(args, 0) orelse "corpus";
    var corpus = try zgraphy.Benchmark.parseEmbeddedCorpus(allocator);
    defer corpus.deinit();
    try zgraphy.Benchmark.validateCorpus(&corpus.value);
    if (std.mem.eql(u8, subcommand, "workload")) {
        return runBenchmarkWorkload(allocator, io, root, args, &corpus.value);
    }
    if (std.mem.eql(u8, subcommand, "resources")) {
        return runResourceMatrix(allocator, io, root, args);
    }
    if (std.mem.eql(u8, subcommand, "freshness")) {
        return runFreshnessReceipt(allocator, io, root, args);
    }
    if (std.mem.eql(u8, subcommand, "matrix")) {
        return runQualityMatrix(allocator, io, root, args, &corpus.value);
    }
    if (std.mem.eql(u8, subcommand, "lexical")) {
        const fixture_id = positional(args, 1) orelse return error.MissingBenchmarkFixture;
        const fixture = zgraphy.Benchmark.findFixture(&corpus.value, fixture_id) orelse return error.UnknownBenchmarkFixture;
        const fixture_root = positional(args, 2) orelse fixture.scan_root;
        var fixture_dir = try root.openDir(io, fixture_root, .{ .iterate = true, .follow_symlinks = false });
        defer fixture_dir.close(io);
        var graph = try zgraphy.Lexical.build(allocator, io, fixture_dir, .{});
        defer graph.deinit();
        var gold = try zgraphy.Benchmark.parseEmbeddedGold(allocator, fixture.gold);
        defer gold.deinit();
        var receipt = try zgraphy.Differential.projectLexical(allocator, &graph, &gold.value);
        defer receipt.deinit(allocator);
        try zgraphy.Differential.validateReceipt(&receipt);
        if (hasFlag(args, "--json")) return writeJson(io, allocator, receipt);
        return writeText(io, allocator, "lexical {s}: entities {d}/{d}, relations {d}/{d}, unmatched tokens {d}\n", .{
            fixture.id,
            receipt.entities.matched,
            receipt.entities.expected,
            receipt.relations.matched,
            receipt.relations.expected,
            receipt.entities.unexpected,
        });
    }
    if (std.mem.eql(u8, subcommand, "zgraphy")) {
        const fixture_id = positional(args, 1) orelse return error.MissingBenchmarkFixture;
        const fixture = zgraphy.Benchmark.findFixture(&corpus.value, fixture_id) orelse return error.UnknownBenchmarkFixture;
        const fixture_root = positional(args, 2) orelse fixture.scan_root;
        var fixture_dir = try root.openDir(io, fixture_root, .{ .iterate = true, .follow_symlinks = false });
        defer fixture_dir.close(io);
        var built = try zgraphy.Indexer.buildRepository(allocator, io, fixture_dir, .{});
        defer built.deinit();
        var gold = try zgraphy.Benchmark.parseEmbeddedGold(allocator, fixture.gold);
        defer gold.deinit();
        try zgraphy.Benchmark.validateGold(&gold.value, fixture.id);
        var receipt = try zgraphy.Differential.projectZgraphy(allocator, &built.graph, &gold.value);
        defer receipt.deinit(allocator);
        try zgraphy.Differential.validateReceipt(&receipt);
        if (hasFlag(args, "--json")) return writeJson(io, allocator, receipt);
        return writeText(io, allocator, "zgraphy {s}: entities {d}/{d}, relations {d}/{d}, unmappable nodes {d}, unmappable relations {d}\n", .{
            fixture.id,
            receipt.entities.matched,
            receipt.entities.expected,
            receipt.relations.matched,
            receipt.relations.expected,
            receipt.entities.unexpected,
            receipt.relations.unexpected,
        });
    }
    if (std.mem.eql(u8, subcommand, "graphify")) {
        const fixture_id = positional(args, 1) orelse return error.MissingBenchmarkFixture;
        const graph_path = positional(args, 2) orelse return error.MissingBenchmarkGraph;
        const fixture = zgraphy.Benchmark.findFixture(&corpus.value, fixture_id) orelse return error.UnknownBenchmarkFixture;
        var gold = try zgraphy.Benchmark.parseEmbeddedGold(allocator, fixture.gold);
        defer gold.deinit();
        try zgraphy.Benchmark.validateGold(&gold.value, fixture.id);
        const bytes = try root.readFileAlloc(io, graph_path, allocator, .limited(zgraphy.Differential.max_graph_bytes));
        defer allocator.free(bytes);
        var graph = try zgraphy.Differential.parseGraphify(allocator, bytes);
        defer graph.deinit();
        var receipt = try zgraphy.Differential.projectGraphify(allocator, &graph.value, &gold.value);
        defer receipt.deinit(allocator);
        try zgraphy.Differential.validateReceipt(&receipt);
        if (hasFlag(args, "--json")) return writeJson(io, allocator, receipt);
        return writeText(io, allocator, "Graphify {s}: entities {d}/{d}, relations {d}/{d}, unmappable nodes {d}, unmappable relations {d}\n", .{
            fixture.id,
            receipt.entities.matched,
            receipt.entities.expected,
            receipt.relations.matched,
            receipt.relations.expected,
            receipt.entities.unexpected,
            receipt.relations.unexpected,
        });
    }
    if (!std.mem.eql(u8, subcommand, "corpus")) return error.InvalidBenchmarkCommand;
    var summary = zgraphy.Benchmark.CorpusSummary{};
    for (corpus.value.fixtures) |fixture| {
        var gold = try zgraphy.Benchmark.parseEmbeddedGold(allocator, fixture.gold);
        defer gold.deinit();
        try zgraphy.Benchmark.validateGold(&gold.value, fixture.id);
        summary.include(&fixture, &gold.value);
    }
    if (hasFlag(args, "--json")) return writeJson(io, allocator, .{
        .schema = zgraphy.Benchmark.corpus_schema,
        .schema_version = zgraphy.Benchmark.schema_version,
        .canonical_ir_schema = zgraphy.Benchmark.canonical_ir_schema,
        .baseline = corpus.value.baseline,
        .summary = summary,
        .fixtures = corpus.value.fixtures,
    });
    return writeText(io, allocator, "canonical corpus: {d} fixtures, {d} entities, {d} relations, {d} facts, {d} retrieval tasks, {d} mutations\n", .{
        summary.fixtures,
        summary.entities,
        summary.relations,
        summary.facts,
        summary.retrieval_tasks,
        summary.mutations,
    });
}

fn runFreshnessReceipt(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, args: []const []const u8) !void {
    const transition_path = positional(args, 1) orelse return error.MissingFreshnessTransitions;
    const bytes = try root.readFileAlloc(io, transition_path, allocator, .limited(zgraphy.Freshness.max_transition_file_bytes));
    defer allocator.free(bytes);
    var parsed = try zgraphy.Freshness.parseTransitionFile(allocator, bytes);
    defer parsed.deinit();
    const digest = zgraphy.Benchmark.canonicalCorpusDigest();
    const digest_hex = std.fmt.bytesToHex(digest, .lower);
    var corpus_identity_buffer: ["sha256:".len + digest_hex.len]u8 = @splat(0);
    const corpus_identity = try std.fmt.bufPrint(&corpus_identity_buffer, "sha256:{s}", .{&digest_hex});
    var receipt = try zgraphy.Freshness.build(allocator, corpus_identity, parsed.value.transitions, zgraphy.Freshness.Capabilities.currentM0());
    defer receipt.deinit(allocator);
    try zgraphy.Freshness.validate(&receipt);
    if (hasFlag(args, "--json")) return writeJson(io, allocator, receipt);
    return writeText(io, allocator, "freshness baseline: {d} full rebuild transitions, gate {s}, incremental {s}, pre-query refresh {s}\n", .{
        receipt.transitions.len,
        if (receipt.freshness_gate_passed) "passed" else "failed",
        @tagName(receipt.capabilities.incremental_update),
        @tagName(receipt.capabilities.pre_query_refresh),
    });
}

fn runResourceMatrix(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, args: []const []const u8) !void {
    const sample_path = positional(args, 1) orelse return error.MissingResourceSamples;
    const source_revision = try requiredStringOption(args, "--source-revision");
    const graphify_python = try requiredStringOption(args, "--graphify-python");
    const graphify_environment = try requiredStringOption(args, "--graphify-environment");
    const machine_digest = try requiredStringOption(args, "--machine");
    const configuration_digest = try requiredStringOption(args, "--configuration");
    const warmups: u16 = @intCast(try numericOption(args, "--warmups", 2, 1, zgraphy.ResourceMatrix.max_repetitions));
    const repetitions: u16 = @intCast(try numericOption(args, "--repetitions", 7, 7, zgraphy.ResourceMatrix.max_repetitions));
    const bytes = try root.readFileAlloc(io, sample_path, allocator, .limited(zgraphy.ResourceMatrix.max_sample_file_bytes));
    defer allocator.free(bytes);
    var parsed = try zgraphy.ResourceMatrix.parseSampleFile(allocator, bytes);
    defer parsed.deinit();

    const digest = zgraphy.Benchmark.canonicalCorpusDigest();
    const digest_hex = std.fmt.bytesToHex(digest, .lower);
    var corpus_identity_buffer: ["sha256:".len + digest_hex.len]u8 = @splat(0);
    const corpus_identity = try std.fmt.bufPrint(&corpus_identity_buffer, "sha256:{s}", .{&digest_hex});
    var receipt = try zgraphy.ResourceMatrix.build(allocator, .{
        .corpus_digest = corpus_identity,
        .zgraphy_source_revision = source_revision,
        .graphify_python = graphify_python,
        .graphify_environment_digest = graphify_environment,
        .machine_digest = machine_digest,
        .configuration_digest = configuration_digest,
    }, .{ .warmups = warmups, .repetitions = repetitions }, parsed.value.samples);
    defer receipt.deinit(allocator);
    try zgraphy.ResourceMatrix.validate(&receipt);
    if (hasFlag(args, "--json")) return writeJson(io, allocator, receipt);
    for (receipt.aggregates) |aggregate| {
        try writeText(io, allocator, "{s} {s} {s}: p50 {d} ns, p95 {d} ns, peak RSS p50 {d} bytes, persisted p50 {d} bytes\n", .{
            @tagName(aggregate.engine),
            aggregate.fixture_id,
            @tagName(aggregate.workload),
            aggregate.elapsed_ns.p50,
            aggregate.elapsed_ns.p95,
            aggregate.peak_rss_bytes.p50,
            aggregate.persisted_bytes.p50,
        });
    }
}

fn runBenchmarkWorkload(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    args: []const []const u8,
    corpus: *const zgraphy.Benchmark.Corpus,
) !void {
    const fixture_id = positional(args, 1) orelse return error.MissingBenchmarkFixture;
    const workload_name = positional(args, 2) orelse return error.MissingBenchmarkWorkload;
    const workload = parseWorkload(workload_name) orelse return error.InvalidBenchmarkWorkload;
    if (workload == .bounded_query) return error.UnsupportedBenchmarkWorkload;
    const fixture = zgraphy.Benchmark.findFixture(corpus, fixture_id) orelse return error.UnknownBenchmarkFixture;
    const fixture_root = positional(args, 3) orelse fixture.scan_root;

    if (workload == .warm_unchanged_build) {
        var warm_dir = try root.openDir(io, fixture_root, .{ .iterate = true, .follow_symlinks = false });
        defer warm_dir.close(io);
        var warm = try zgraphy.Indexer.buildRepository(allocator, io, warm_dir, .{});
        warm.deinit();
    }

    const started = std.Io.Clock.awake.now(io).nanoseconds;
    var fixture_dir = try root.openDir(io, fixture_root, .{ .iterate = true, .follow_symlinks = false });
    defer fixture_dir.close(io);
    var built = try zgraphy.Indexer.buildRepository(allocator, io, fixture_dir, .{});
    defer built.deinit();
    try root.createDirPath(io, ".zgraphy/benchmarks/workloads");
    const snapshot_path = try std.fmt.allocPrint(allocator, ".zgraphy/benchmarks/workloads/{s}-{s}.nendb.jsonl", .{ fixture.id, @tagName(workload) });
    defer allocator.free(snapshot_path);
    try zgraphy.Store.save(io, root, snapshot_path, &built.graph);
    const ended = std.Io.Clock.awake.now(io).nanoseconds;
    if (ended <= started) return error.InvalidBenchmarkClock;

    const snapshot = try root.readFileAlloc(io, snapshot_path, allocator, .limited(zgraphy.Store.max_snapshot_bytes));
    defer allocator.free(snapshot);
    var loaded = try zgraphy.Store.load(allocator, io, root, snapshot_path, .{});
    defer loaded.deinit();
    const health = zgraphy.Freshness.inspect(&loaded);
    if (!health.clean()) return error.UnhealthyBenchmarkGraph;
    const fingerprint = try zgraphy.Freshness.fingerprint(allocator, &built.graph);
    const loaded_fingerprint = try zgraphy.Freshness.fingerprint(allocator, &loaded);
    if (!std.mem.eql(u8, &fingerprint, &loaded_fingerprint)) return error.IncompleteBenchmarkSnapshot;
    const fingerprint_hex = std.fmt.bytesToHex(fingerprint, .lower);
    var fingerprint_buffer: ["sha256:".len + fingerprint_hex.len]u8 = @splat(0);
    const fingerprint_identity = try std.fmt.bufPrint(&fingerprint_buffer, "sha256:{s}", .{&fingerprint_hex});

    var gold = try zgraphy.Benchmark.parseEmbeddedGold(allocator, fixture.gold);
    defer gold.deinit();
    var quality = try zgraphy.Differential.projectZgraphy(allocator, &built.graph, &gold.value);
    defer quality.deinit(allocator);
    try zgraphy.Differential.validateReceipt(&quality);
    if (loaded.nodeCount() > 1024) return error.BenchmarkIdentityProbeLimit;
    const identities = try zgraphy.Memory.slice(zgraphy.ResourceMatrix.IdentityProbe, allocator, loaded.nodeCount());
    defer allocator.free(identities);
    for (loaded.nodes.items, 0..) |node, index| {
        identities[index] = .{ .id = node.id, .kind = node.kind, .label = node.label, .path = node.path };
    }

    const observation = zgraphy.ResourceMatrix.WorkloadObservation{
        .fixture_id = fixture.id,
        .workload = workload,
        .workload_elapsed_ns = @intCast(ended - started),
        .persisted_bytes = snapshot.len,
        .nodes = built.graph.nodeCount(),
        .relations = built.graph.edgeCount(),
        .vectors = built.graph.vectorCount(),
        .dangling_edges = health.dangling_edges,
        .true_orphans = health.true_orphans,
        .unowned_vectors = health.unowned_vectors,
        .graph_fingerprint = fingerprint_identity,
        .entities_expected = quality.entities.expected,
        .entities_matched = quality.entities.matched,
        .relations_expected = quality.relations.expected,
        .relations_matched = quality.relations.matched,
        .identities = identities,
        .snapshot_complete = true,
    };
    try zgraphy.ResourceMatrix.validateObservation(&observation);
    if (hasFlag(args, "--json")) return writeJson(io, allocator, observation);
    return writeText(io, allocator, "zgraphy {s} {s}: {d} ns, {d} persisted bytes, {d} nodes, {d} relations\n", .{
        fixture.id,
        @tagName(workload),
        observation.workload_elapsed_ns,
        observation.persisted_bytes,
        observation.nodes,
        observation.relations,
    });
}

fn parseWorkload(value: []const u8) ?zgraphy.ResourceMatrix.Workload {
    if (std.mem.eql(u8, value, "cold-build") or std.mem.eql(u8, value, "cold_build")) return .cold_build;
    if (std.mem.eql(u8, value, "warm-unchanged-build") or std.mem.eql(u8, value, "warm_unchanged_build")) return .warm_unchanged_build;
    if (std.mem.eql(u8, value, "one-file-modify") or std.mem.eql(u8, value, "one_file_modify")) return .one_file_modify;
    if (std.mem.eql(u8, value, "rename")) return .rename;
    if (std.mem.eql(u8, value, "delete")) return .delete;
    if (std.mem.eql(u8, value, "bounded-query") or std.mem.eql(u8, value, "bounded_query")) return .bounded_query;
    return null;
}

fn runQualityMatrix(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    args: []const []const u8,
    corpus: *const zgraphy.Benchmark.Corpus,
) !void {
    const graphify_root = positional(args, 1) orelse ".zgraphy/benchmarks/runs/graphify";
    const source_revision = try requiredStringOption(args, "--source-revision");
    const graphify_python = try requiredStringOption(args, "--graphify-python");
    const graphify_environment = try requiredStringOption(args, "--graphify-environment");
    if (corpus.fixtures.len != 3) return error.UnsupportedQualityCorpus;

    var runs: std.ArrayList(zgraphy.QualityMatrix.Run) = .empty;
    defer runs.deinit(allocator);
    try runs.ensureTotalCapacity(allocator, 9);
    for (corpus.fixtures) |fixture| {
        var gold = try zgraphy.Benchmark.parseEmbeddedGold(allocator, fixture.gold);
        defer gold.deinit();
        try zgraphy.Benchmark.validateGold(&gold.value, fixture.id);

        const graph_path = try std.fs.path.join(allocator, &.{ graphify_root, fixture.id, "graphify-out/graph.json" });
        defer allocator.free(graph_path);
        const graph_bytes = try root.readFileAlloc(io, graph_path, allocator, .limited(zgraphy.Differential.max_graph_bytes));
        defer allocator.free(graph_bytes);
        var graphify_graph = try zgraphy.Differential.parseGraphify(allocator, graph_bytes);
        defer graphify_graph.deinit();
        var graphify_receipt = try zgraphy.Differential.projectGraphify(allocator, &graphify_graph.value, &gold.value);
        defer graphify_receipt.deinit(allocator);
        try zgraphy.Differential.validateReceipt(&graphify_receipt);
        var graphify_run = try zgraphy.QualityMatrix.Run.fromReceipt(&graphify_receipt);
        graphify_run.fixture_id = fixture.id;
        runs.appendAssumeCapacity(graphify_run);

        var native_dir = try root.openDir(io, fixture.scan_root, .{ .iterate = true, .follow_symlinks = false });
        defer native_dir.close(io);
        var built = try zgraphy.Indexer.buildRepository(allocator, io, native_dir, .{});
        defer built.deinit();
        var native_receipt = try zgraphy.Differential.projectZgraphy(allocator, &built.graph, &gold.value);
        defer native_receipt.deinit(allocator);
        try zgraphy.Differential.validateReceipt(&native_receipt);
        var native_run = try zgraphy.QualityMatrix.Run.fromReceipt(&native_receipt);
        native_run.fixture_id = fixture.id;
        runs.appendAssumeCapacity(native_run);

        var lexical_dir = try root.openDir(io, fixture.scan_root, .{ .iterate = true, .follow_symlinks = false });
        defer lexical_dir.close(io);
        var lexical_graph = try zgraphy.Lexical.build(allocator, io, lexical_dir, .{});
        defer lexical_graph.deinit();
        var lexical_receipt = try zgraphy.Differential.projectLexical(allocator, &lexical_graph, &gold.value);
        defer lexical_receipt.deinit(allocator);
        try zgraphy.Differential.validateReceipt(&lexical_receipt);
        var lexical_run = try zgraphy.QualityMatrix.Run.fromReceipt(&lexical_receipt);
        lexical_run.fixture_id = fixture.id;
        runs.appendAssumeCapacity(lexical_run);
    }
    if (runs.items.len != 9) return error.IncompleteQualityMatrix;

    const digest = zgraphy.Benchmark.canonicalCorpusDigest();
    const digest_hex = std.fmt.bytesToHex(digest, .lower);
    var corpus_identity_buffer: ["sha256:".len + digest_hex.len]u8 = @splat(0);
    const corpus_identity = try std.fmt.bufPrint(&corpus_identity_buffer, "sha256:{s}", .{&digest_hex});
    var matrix = try zgraphy.QualityMatrix.build(allocator, .{
        .corpus_digest = corpus_identity,
        .zgraphy_source_revision = source_revision,
        .graphify_python = graphify_python,
        .graphify_environment_digest = graphify_environment,
    }, runs.items);
    defer matrix.deinit(allocator);
    try zgraphy.QualityMatrix.validate(&matrix);
    if (hasFlag(args, "--json")) return writeJson(io, allocator, matrix);

    const graphify = zgraphy.QualityMatrix.findAggregate(&matrix, .graphify) orelse return error.MissingGraphifyAggregate;
    const native = zgraphy.QualityMatrix.findAggregate(&matrix, .zgraphy) orelse return error.MissingZgraphyAggregate;
    const lexical = zgraphy.QualityMatrix.findAggregate(&matrix, .lexical) orelse return error.MissingLexicalAggregate;
    return writeText(io, allocator, "quality baseline: Graphify entities {d}/{d}, relations {d}/{d}; zgraphy entities {d}/{d}, relations {d}/{d}; lexical entities {d}/{d}, relations {d}/{d} ({s})\n", .{
        graphify.entities.matched,
        graphify.entities.expected,
        graphify.relations.matched,
        graphify.relations.expected,
        native.entities.matched,
        native.entities.expected,
        native.relations.matched,
        native.relations.expected,
        lexical.entities.matched,
        lexical.entities.expected,
        lexical.relations.matched,
        lexical.relations.expected,
        matrix.promotion_status,
    });
}

fn runQuery(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, args: []const []const u8) !void {
    const query = positional(args, 0) orelse return error.MissingQuery;
    const limit = try numericOption(args, "--limit", 10, 1, 1024);
    var loaded = try loadGraph(allocator, io, root);
    defer loaded.deinit();
    var results = try zgraphy.Search.queryAlloc(allocator, &loaded.graph, query, .{ .limit = limit });
    defer results.deinit();
    if (hasFlag(args, "--json")) {
        const views = try owned.slice(ResultView, allocator, results.items.len);
        defer allocator.free(views);
        for (results.items, 0..) |result, index| views[index] = resultView(&loaded.graph, result);
        return writeJson(io, allocator, .{
            .schema = "zgraphy.query.v1",
            .query = query,
            .embedder = results.embedder,
            .results = views,
        });
    }
    for (results.items) |result| {
        const node = loaded.graph.findNode(result.node_id).?;
        try writeText(io, allocator, "{s} [{s}] {s}:{d} score={d:.3} keyword={d:.3} vector={d:.3} graph={d:.3}\n", .{
            node.label,
            @tagName(node.kind),
            node.path,
            node.line,
            result.score,
            result.keyword_score,
            result.vector_score,
            result.graph_score,
        });
    }
}

fn runExplain(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, args: []const []const u8) !void {
    const selector = positional(args, 0) orelse return error.MissingNode;
    var loaded = try loadGraph(allocator, io, root);
    defer loaded.deinit();
    const node = findNode(&loaded.graph, selector) orelse return error.NodeNotFound;
    var outgoing: usize = 0;
    var incoming: usize = 0;
    for (loaded.graph.edges.items) |edge| {
        if (edge.from == node.id) outgoing += 1;
        if (edge.to == node.id) incoming += 1;
    }
    const semantic_limit: usize = 64;
    const request_path_count = matchingHyperedgeCount(&loaded.graph, node.id);
    const feature_count = matchingSupernodeCount(&loaded.graph, node.id);
    const request_paths = try owned.slice(zgraphy.Model.Hyperedge, allocator, @min(request_path_count, semantic_limit));
    defer allocator.free(request_paths);
    const features = try owned.slice(zgraphy.Model.Supernode, allocator, @min(feature_count, semantic_limit));
    defer allocator.free(features);
    copyMatchingHyperedges(&loaded.graph, node.id, request_paths);
    copyMatchingSupernodes(&loaded.graph, node.id, features);
    if (hasFlag(args, "--json")) return writeJson(io, allocator, .{
        .schema = "zgraphy.explain.v2",
        .node = node.*,
        .incoming = incoming,
        .outgoing = outgoing,
        .request_paths = request_paths,
        .features = features,
        .semantic_truncated = request_path_count > request_paths.len or feature_count > features.len,
    });
    return writeText(io, allocator, "{s} id={d} kind={s} source={s}:{d} incoming={d} outgoing={d} request_paths={d} features={d}\n", .{
        node.label,
        node.id,
        @tagName(node.kind),
        node.path,
        node.line,
        incoming,
        outgoing,
        request_path_count,
        feature_count,
    });
}

fn matchingHyperedgeCount(graph: *const zgraphy.RepositoryGraph, node_id: u64) usize {
    var count: usize = 0;
    for (graph.hyperedges.items) |hyperedge| {
        for (hyperedge.participants) |participant| {
            if (participant.node_id != node_id) continue;
            count += 1;
            break;
        }
    }
    return count;
}

fn matchingSupernodeCount(graph: *const zgraphy.RepositoryGraph, node_id: u64) usize {
    var count: usize = 0;
    for (graph.supernodes.items) |supernode| {
        for (supernode.members) |member| {
            if (member.node_id != node_id) continue;
            count += 1;
            break;
        }
    }
    return count;
}

fn copyMatchingHyperedges(graph: *const zgraphy.RepositoryGraph, node_id: u64, output: []zgraphy.Model.Hyperedge) void {
    var write: usize = 0;
    for (graph.hyperedges.items) |hyperedge| {
        if (write >= output.len) return;
        for (hyperedge.participants) |participant| {
            if (participant.node_id != node_id) continue;
            output[write] = hyperedge;
            write += 1;
            break;
        }
    }
}

fn copyMatchingSupernodes(graph: *const zgraphy.RepositoryGraph, node_id: u64, output: []zgraphy.Model.Supernode) void {
    var write: usize = 0;
    for (graph.supernodes.items) |supernode| {
        if (write >= output.len) return;
        for (supernode.members) |member| {
            if (member.node_id != node_id) continue;
            output[write] = supernode;
            write += 1;
            break;
        }
    }
}

fn runPath(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, args: []const []const u8) !void {
    const from_selector = positional(args, 0) orelse return error.MissingFromNode;
    const to_selector = positional(args, 1) orelse return error.MissingToNode;
    const max_hops = try numericOption(args, "--max-hops", 8, 1, 128);
    var loaded = try loadGraph(allocator, io, root);
    defer loaded.deinit();
    const from = findNode(&loaded.graph, from_selector) orelse return error.NodeNotFound;
    const to = findNode(&loaded.graph, to_selector) orelse return error.NodeNotFound;
    var path = try loaded.graph.shortestPathAlloc(allocator, from.id, to.id, max_hops);
    defer path.deinit();
    if (hasFlag(args, "--json")) return writeJson(io, allocator, .{
        .schema = "zgraphy.path.v1",
        .complete = path.complete,
        .exhausted = path.exhausted,
        .node_ids = path.node_ids,
    });
    if (!path.complete) return writeText(io, allocator, "no path within {d} hops (bound_exhausted={any})\n", .{ max_hops, path.exhausted });
    for (path.node_ids, 0..) |id, index| {
        const node = loaded.graph.findNode(id).?;
        if (index > 0) try std.Io.File.stdout().writeStreamingAll(io, " -> ");
        try std.Io.File.stdout().writeStreamingAll(io, node.label);
    }
    try std.Io.File.stdout().writeStreamingAll(io, "\n");
}

const LoadedGraph = struct {
    allocator: std.mem.Allocator,
    graph: zgraphy.RepositoryGraph,
    database: []const u8,

    fn deinit(self: *LoadedGraph) void {
        self.graph.deinit();
        self.allocator.free(self.database);
    }
};

fn loadGraph(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir) !LoadedGraph {
    var config = try zgraphy.Project.loadConfig(allocator, io, root);
    defer config.deinit();
    const database = try owned.copy(u8, allocator, config.value.database);
    errdefer allocator.free(database);
    return .{
        .allocator = allocator,
        .graph = try zgraphy.Store.load(allocator, io, root, database, .{
            .max_nodes = config.value.max_nodes,
            .max_edges = config.value.max_edges,
        }),
        .database = database,
    };
}

const ResultView = struct {
    id: u64,
    label: []const u8,
    kind: zgraphy.NodeKind,
    path: []const u8,
    line: u32,
    score: f32,
    keyword_score: f32,
    vector_score: f32,
    graph_score: f32,
};

fn resultView(graph: *const zgraphy.RepositoryGraph, result: zgraphy.Search.Result) ResultView {
    const node = graph.findNode(result.node_id).?;
    return .{
        .id = node.id,
        .label = node.label,
        .kind = node.kind,
        .path = node.path,
        .line = node.line,
        .score = result.score,
        .keyword_score = result.keyword_score,
        .vector_score = result.vector_score,
        .graph_score = result.graph_score,
    };
}

fn findNode(graph: *const zgraphy.RepositoryGraph, selector: []const u8) ?*const zgraphy.Node {
    const id = std.fmt.parseInt(u64, selector, 10) catch return graph.findNodeByLabel(selector);
    return graph.findNode(id);
}

fn positional(args: []const []const u8, wanted: usize) ?[]const u8 {
    var found: usize = 0;
    var index: usize = 2;
    while (index < args.len) : (index += 1) {
        if (std.mem.startsWith(u8, args[index], "--")) {
            if (optionTakesValue(args[index]) and index + 1 < args.len) index += 1;
            continue;
        }
        if (isRootPosition(args, index)) continue;
        if (found == wanted) return args[index];
        found += 1;
    }
    return null;
}

fn requiredStringOption(args: []const []const u8, name: []const u8) ![]const u8 {
    for (args, 0..) |arg, index| {
        if (!std.mem.eql(u8, arg, name)) continue;
        if (index + 1 >= args.len or std.mem.startsWith(u8, args[index + 1], "--")) return error.MissingOptionValue;
        return args[index + 1];
    }
    return error.MissingOption;
}

fn optionTakesValue(option: []const u8) bool {
    return std.mem.eql(u8, option, "--limit") or
        std.mem.eql(u8, option, "--max-hops") or
        std.mem.eql(u8, option, "--source-revision") or
        std.mem.eql(u8, option, "--graphify-python") or
        std.mem.eql(u8, option, "--graphify-environment") or
        std.mem.eql(u8, option, "--machine") or
        std.mem.eql(u8, option, "--configuration") or
        std.mem.eql(u8, option, "--warmups") or
        std.mem.eql(u8, option, "--repetitions");
}

fn numericOption(args: []const []const u8, name: []const u8, default: usize, minimum: usize, maximum: usize) !usize {
    for (args, 0..) |arg, index| {
        if (!std.mem.eql(u8, arg, name)) continue;
        if (index + 1 >= args.len) return error.MissingOptionValue;
        const value = try std.fmt.parseInt(usize, args[index + 1], 10);
        if (value < minimum or value > maximum) return error.InvalidOptionValue;
        return value;
    }
    return default;
}

fn selectedRoot(args: []const []const u8) []const u8 {
    if (args.len >= 3 and
        (std.mem.eql(u8, args[1], "init") or std.mem.eql(u8, args[1], "build") or std.mem.eql(u8, args[1], "ingest") or std.mem.eql(u8, args[1], "doctor")) and
        !std.mem.startsWith(u8, args[2], "--")) return args[2];
    return ".";
}

fn isRootPosition(args: []const []const u8, index: usize) bool {
    return index == 2 and !std.mem.eql(u8, selectedRoot(args), ".");
}

fn hasFlag(args: []const []const u8, flag: []const u8) bool {
    for (args) |arg| if (std.mem.eql(u8, arg, flag)) return true;
    return false;
}

fn isHelp(value: []const u8) bool {
    return std.mem.eql(u8, value, "--help") or std.mem.eql(u8, value, "-h") or std.mem.eql(u8, value, "help");
}

fn writeJson(io: std.Io, allocator: std.mem.Allocator, value: anytype) !void {
    const encoded = try std.json.Stringify.valueAlloc(allocator, value, .{});
    defer allocator.free(encoded);
    try std.Io.File.stdout().writeStreamingAll(io, encoded);
    try std.Io.File.stdout().writeStreamingAll(io, "\n");
}

fn writeText(io: std.Io, allocator: std.mem.Allocator, comptime format: []const u8, args: anytype) !void {
    const text = try std.fmt.allocPrint(allocator, format, args);
    defer allocator.free(text);
    try std.Io.File.stdout().writeStreamingAll(io, text);
}

fn printHelp(io: std.Io) !void {
    try std.Io.File.stdout().writeStreamingAll(io,
        \\zgraphy - local Zig repository knowledge graph
        \\
        \\Usage:
        \\  zgraphy init [root] [--json]
        \\  zgraphy build [root] [--json]
        \\  zgraphy ingest [root] [--json]
        \\  zgraphy query <text> [--limit N] [--json]
        \\  zgraphy explain <node-id-or-label> [--json]
        \\  zgraphy path <from> <to> [--max-hops N] [--json]
        \\  zgraphy status [--json]
        \\  zgraphy doctor [root] [--json]
        \\  zgraphy parity [--json]
        \\  zgraphy schema [relation] [--json]
        \\  zgraphy contracts [provider|conformance|config|health|diagnostic|migration] [--json]
        \\  zgraphy security [ZG-THR-NNN] [--json]
        \\  zgraphy evaluation [extraction|retrieval|agent_task|performance|resource] [--json]
        \\  zgraphy benchmark corpus [--json]
        \\  zgraphy benchmark lexical <fixture-id> [fixture-root] [--json]
        \\  zgraphy benchmark zgraphy <fixture-id> [fixture-root] [--json]
        \\  zgraphy benchmark graphify <fixture-id> <graph.json> [--json]
        \\  zgraphy benchmark matrix [graphify-run-root] --source-revision <sha256> --graphify-python <version> --graphify-environment <sha256> [--json]
        \\  zgraphy benchmark workload <fixture-id> <cold-build|warm-unchanged-build|one-file-modify|rename|delete> [fixture-root] [--json]
        \\  zgraphy benchmark resources <samples.json> --source-revision <sha256> --graphify-python <version> --graphify-environment <sha256> --machine <sha256> --configuration <sha256> [--warmups N] [--repetitions N] [--json]
        \\  zgraphy benchmark freshness <transitions.json> [--json]
        \\
    );
}
