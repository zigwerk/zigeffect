const std = @import("std");
const model = @import("model.zig");
const owned = @import("memory.zig");
const discovery = @import("discovery.zig");
const extraction_cache = @import("extraction_cache.zig");
const ownership = @import("ownership.zig");
const zig_parser = @import("zig_parser.zig");
const zig_resolution = @import("zig_resolution.zig");
const typescript_parser = @import("typescript_parser.zig");
const typescript_resolution = @import("typescript_resolution.zig");
const typescript_symbols = @import("typescript_symbols.zig");
const protobuf_parser = @import("protobuf_parser.zig");
const protobuf_resolution = @import("protobuf_resolution.zig");
const generated_lineage = @import("generated_lineage.zig");
const rpc_continuity = @import("rpc_continuity.zig");
const semantic_recipes = @import("semantic_recipes.zig");

pub const max_manifest_bytes: usize = 4 * 1024 * 1024;
pub const max_causal_bytes: usize = 64 * 1024 * 1024;
pub const causal_wal_path = ".zigeffect/graph/causal-graph.jsonl";

pub const BuildOptions = struct {
    repository_id: []const u8 = "repo-0123456789abcdef0123456789abcdef",
    max_entries: usize = 200_000,
    max_files: usize = 100_000,
    max_file_bytes: usize = 4 * 1024 * 1024,
    max_source_bytes: usize = 512 * 1024 * 1024,
    max_depth: usize = 128,
    max_path_bytes: usize = std.fs.max_path_bytes,
    max_nodes: usize = 100_000,
    max_edges: usize = 500_000,
    max_lexical_postings: usize = 4_000_000,
    max_hyperedges: usize = 100_000,
    max_hyperedge_participants: usize = 1_000_000,
    max_hyperedge_evidence: usize = 1_000_000,
    max_supernodes: usize = 100_000,
    max_supernode_members: usize = 1_000_000,
    max_supernode_evidence: usize = 1_000_000,
    max_supernode_proof_steps: usize = 1_000_000,
    extraction_cache_options: extraction_cache.Options = .{},
    previous_graph: ?*const model.RepositoryGraph = null,
};

pub const BuildSummary = struct {
    files_discovered: usize = 0,
    files_placed: usize = 0,
    files_indexed: usize = 0,
    files_skipped: usize = 0,
    source_bytes: usize = 0,
    discovery_manifest_digest: [32]u8 = @splat(0),
    discovery: discovery.Summary = .{},
    ownership_manifest_digest: [32]u8 = @splat(0),
    ownership: ownership.Summary = .{},
    causal_records: usize = 0,
    module_resolutions: usize = 0,
    module_resolution_diagnostics: usize = 0,
    symbol_resolutions: usize = 0,
    symbol_resolution_diagnostics: usize = 0,
    proto_entities: usize = 0,
    proto_references: usize = 0,
    proto_resolution_diagnostics: usize = 0,
    generated_bindings: usize = 0,
    rpc_observations: usize = 0,
    rpc_interactions: usize = 0,
    request_paths: usize = 0,
    feature_supernodes: usize = 0,
    derived_hyperedges_reused: usize = 0,
    derived_hyperedges_recomputed: usize = 0,
    derived_supernodes_reused: usize = 0,
    derived_supernodes_recomputed: usize = 0,
    cacheable_files: usize = 0,
    cache_hits: usize = 0,
    cache_misses: usize = 0,
    cache_rejected: usize = 0,
    cache_writes: usize = 0,
    reparsed_files: usize = 0,
    direct_invalidations: usize = 0,
    invalidation_closure: usize = 0,
    nodes: usize = 0,
    edges: usize = 0,
    vectors: usize = 0,
};

pub const BuildResult = struct {
    graph: model.RepositoryGraph,
    summary: BuildSummary,
    discovery_result: discovery.Result,
    ownership_result: ownership.Result,
    extraction: extraction_cache.BuildEvidence,

    pub fn deinit(self: *BuildResult) void {
        self.extraction.deinit();
        self.ownership_result.deinit();
        self.discovery_result.deinit();
        self.graph.deinit();
    }
};

const Symbol = struct {
    id: u64,
    name: []const u8,
    line: u32,
    kind: zig_parser.DeclarationKind,
    span: zig_parser.Span,
};

const LocalBinding = struct {
    id: u64,
    name: []const u8,
    enclosing_declaration: []const u8,
};

pub fn buildRepository(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    options: BuildOptions,
) !BuildResult {
    if (options.max_entries == 0 or options.max_files == 0 or options.max_file_bytes == 0 or
        options.max_source_bytes == 0 or options.max_depth == 0 or options.max_path_bytes == 0)
    {
        return error.InvalidLimit;
    }
    var graph = try model.RepositoryGraph.init(allocator, .{
        .max_nodes = options.max_nodes,
        .max_edges = options.max_edges,
        .max_lexical_postings = options.max_lexical_postings,
        .max_hyperedges = options.max_hyperedges,
        .max_hyperedge_participants = options.max_hyperedge_participants,
        .max_hyperedge_evidence = options.max_hyperedge_evidence,
        .max_supernodes = options.max_supernodes,
        .max_supernode_members = options.max_supernode_members,
        .max_supernode_evidence = options.max_supernode_evidence,
        .max_supernode_proof_steps = options.max_supernode_proof_steps,
    });
    errdefer graph.deinit();
    var discovered = try discovery.scan(allocator, io, root, .{
        .repository_id = options.repository_id,
        .max_entries = options.max_entries,
        .max_files = options.max_files,
        .max_file_bytes = options.max_file_bytes,
        .max_total_bytes = options.max_source_bytes,
        .max_depth = options.max_depth,
        .max_path_bytes = options.max_path_bytes,
    });
    errdefer discovered.deinit();
    try discovery.materialize(&graph, &discovered);
    var owned_context = try ownership.analyze(allocator, io, root, &discovered, .{
        .max_manifest_bytes = options.max_file_bytes,
    });
    errdefer owned_context.deinit();
    try ownership.materialize(&graph, &discovered, &owned_context);

    var summary = BuildSummary{
        .files_discovered = discovered.summary.total,
        .files_placed = discovered.summary.deeply_indexed + discovered.summary.placed_unsupported + discovered.summary.placed_asset,
        .files_skipped = discovered.summary.total - (discovered.summary.deeply_indexed + discovered.summary.placed_unsupported + discovered.summary.placed_asset),
        .discovery_manifest_digest = discovered.manifest_digest,
        .discovery = discovered.summary,
        .ownership_manifest_digest = owned_context.manifest_digest,
        .ownership = owned_context.summary,
    };
    var extraction = try extraction_cache.Session.init(allocator, io, root, options.extraction_cache_options);
    defer extraction.deinit();
    var zig_corpus = try zig_resolution.Corpus.init(allocator, .{
        .max_files = options.max_files,
        .max_symbols = options.max_nodes,
        .max_resolutions = options.max_edges,
        .max_candidates = options.max_edges,
        .parser = .{ .max_source_bytes = options.max_file_bytes },
    });
    defer zig_corpus.deinit();
    var typescript_corpus = try typescript_resolution.Corpus.init(allocator, .{
        .max_files = options.max_files,
        .max_imports = options.max_edges,
        .max_documents = options.max_files,
        .max_document_bytes = options.max_file_bytes,
        .max_total_document_bytes = options.max_source_bytes,
        .max_candidates = options.max_edges,
        .max_result_bytes = options.max_source_bytes,
    });
    defer typescript_corpus.deinit();
    var typescript_symbol_corpus = try typescript_symbols.Corpus.init(allocator, .{
        .max_files = options.max_files,
        .max_facts = options.max_edges,
        .max_candidates = options.max_edges,
        .max_result_bytes = options.max_source_bytes,
        .parser = .{ .max_source_bytes = options.max_file_bytes },
    });
    defer typescript_symbol_corpus.deinit();
    var protobuf_corpus = try protobuf_resolution.Corpus.init(allocator, .{
        .max_files = options.max_files,
        .max_entities = options.max_nodes,
        .max_references = options.max_edges,
        .max_candidates = options.max_edges,
        .max_result_bytes = options.max_source_bytes,
        .parser = .{ .max_source_bytes = options.max_file_bytes },
    });
    defer protobuf_corpus.deinit();
    var generated_corpus = try generated_lineage.Corpus.init(allocator, .{
        .max_documents = options.max_files,
        .max_document_bytes = options.max_file_bytes,
        .max_links = options.max_edges,
        .max_candidates = options.max_edges,
    });
    defer generated_corpus.deinit();
    var continuity_corpus = try rpc_continuity.Corpus.init(allocator, .{
        .max_documents = options.max_files,
        .max_document_bytes = options.max_file_bytes,
        .max_total_document_bytes = options.max_source_bytes,
        .max_observations = options.max_edges,
        .max_candidates = options.max_edges,
        .max_interactions = options.max_edges,
    });
    defer continuity_corpus.deinit();
    for (discovered.records) |record| {
        if (!isPlaced(record.disposition)) continue;
        try typescript_corpus.addFile(record.relative_path);
    }
    for (discovered.records) |record| {
        if (!isPlaced(record.disposition) or !isTypeScriptResolutionDocument(record.relative_path)) continue;
        const document = try readVerifiedSource(allocator, io, root, record.relative_path, options.max_file_bytes, record.content_digest);
        defer allocator.free(document);
        summary.source_bytes = std.math.add(usize, summary.source_bytes, document.len) catch return error.SourceLimitExceeded;
        if (summary.source_bytes > options.max_source_bytes) return error.SourceLimitExceeded;
        try typescript_corpus.addDocument(record.relative_path, document);
    }
    for (discovered.records) |record| {
        if (record.disposition != .deeply_indexed or record.classification.language != .proto) continue;
        const source = try readVerifiedSource(allocator, io, root, record.relative_path, options.max_file_bytes, record.content_digest);
        defer allocator.free(source);
        summary.source_bytes = std.math.add(usize, summary.source_bytes, source.len) catch return error.SourceLimitExceeded;
        if (summary.source_bytes > options.max_source_bytes) return error.SourceLimitExceeded;
        const digest = record.content_digest orelse return error.MissingDiscoveryFingerprint;
        var parsed = (try extraction.loadDocument(
            record.relative_path,
            .proto,
            digest,
            source,
            .protobuf,
            protobuf_parser.parser_id,
            protobuf_parser.parser_version,
            protobuf_corpus.options.parser,
        )) orelse parsed: {
            var value = try protobuf_parser.parse(allocator, record.relative_path, source, protobuf_corpus.options.parser);
            errdefer value.deinit();
            try extraction.storeDocument(record.relative_path, .proto, digest, source, .protobuf, protobuf_parser.parser_id, protobuf_parser.parser_version, protobuf_corpus.options.parser, &value);
            break :parsed value;
        };
        defer parsed.deinit();
        try protobuf_corpus.addParsedOwned(&parsed);
        try continuity_corpus.addSource(record.relative_path, source, .protobuf);
        summary.files_indexed += 1;
    }
    for (discovered.records) |record| {
        if (record.disposition != .deeply_indexed or record.classification.language != .zig) continue;
        const source = try readVerifiedSource(allocator, io, root, record.relative_path, options.max_file_bytes, record.content_digest);
        defer allocator.free(source);
        summary.source_bytes = std.math.add(usize, summary.source_bytes, source.len) catch return error.SourceLimitExceeded;
        if (summary.source_bytes > options.max_source_bytes) return error.SourceLimitExceeded;
        if (record.classification.is_generated) try generated_corpus.addSource(record.relative_path, source, .zig);
        try continuity_corpus.addSource(record.relative_path, source, .zig);
        const digest = record.content_digest orelse return error.MissingDiscoveryFingerprint;
        var parsed_value = (try extraction.loadZig(record.relative_path, digest, source, zig_corpus.options.parser)) orelse parsed: {
            var value = try zig_parser.parse(allocator, record.relative_path, source, zig_corpus.options.parser);
            errdefer value.deinit();
            try extraction.storeZig(record.relative_path, digest, source, zig_corpus.options.parser, &value);
            break :parsed value;
        };
        defer parsed_value.deinit();
        try zig_corpus.addParsedOwned(&parsed_value);
        const parsed = zig_corpus.parsedForPath(record.relative_path) orelse return error.MissingParsedZigSource;
        try indexParsedZigSource(&graph, record.relative_path, source, parsed);
        summary.files_indexed += 1;
    }
    for (discovered.records) |record| {
        if (record.disposition != .deeply_indexed or
            (record.classification.language != .typescript and record.classification.language != .javascript)) continue;
        const source = try readVerifiedSource(allocator, io, root, record.relative_path, options.max_file_bytes, record.content_digest);
        defer allocator.free(source);
        summary.source_bytes = std.math.add(usize, summary.source_bytes, source.len) catch return error.SourceLimitExceeded;
        if (summary.source_bytes > options.max_source_bytes) return error.SourceLimitExceeded;
        if (record.classification.is_generated) try generated_corpus.addSource(record.relative_path, source, .typescript);
        const mode = typeScriptModeForPath(record.relative_path) orelse return error.UnsupportedTypeScriptSourceExtension;
        const continuity_language = continuityLanguage(mode) orelse return error.UnsupportedTypeScriptSourceExtension;
        try continuity_corpus.addSource(record.relative_path, source, continuity_language);
        const parser_options = typescript_parser.Options{ .max_source_bytes = options.max_file_bytes };
        const digest = record.content_digest orelse return error.MissingDiscoveryFingerprint;
        var parsed = (try extraction.loadDocument(
            record.relative_path,
            record.classification.language,
            digest,
            source,
            mode,
            typescript_parser.parser_id,
            typescript_parser.parser_version,
            parser_options,
        )) orelse parsed_value: {
            var value = try typescript_parser.parse(allocator, record.relative_path, source, mode, parser_options);
            errdefer value.deinit();
            try extraction.storeDocument(record.relative_path, record.classification.language, digest, source, mode, typescript_parser.parser_id, typescript_parser.parser_version, parser_options, &value);
            break :parsed_value value;
        };
        defer parsed.deinit();
        try typescript_corpus.addParsed(&parsed);
        try indexParsedTypeScriptSource(&graph, record.relative_path, source, &parsed);
        try typescript_symbol_corpus.addParsedOwned(&parsed);
        summary.files_indexed += 1;
    }
    for (discovered.records) |record| {
        if (!std.mem.eql(u8, record.relative_path, "zigeffect.project.json")) continue;
        const manifest = try readVerifiedSource(allocator, io, root, record.relative_path, @min(options.max_file_bytes, max_manifest_bytes), record.content_digest);
        defer allocator.free(manifest);
        summary.source_bytes = std.math.add(usize, summary.source_bytes, manifest.len) catch return error.SourceLimitExceeded;
        if (summary.source_bytes > options.max_source_bytes) return error.SourceLimitExceeded;
        try indexZigEffectManifest(&graph, manifest);
        summary.files_indexed += 1;
    }
    try resolveFileImports(&graph);
    var resolutions = try zig_corpus.resolve();
    defer resolutions.deinit();
    try materializeZigResolutions(&graph, &resolutions);
    var module_resolutions = try typescript_corpus.resolve();
    defer module_resolutions.deinit();
    try materializeTypeScriptResolutions(&graph, &module_resolutions);
    summary.module_resolutions = module_resolutions.summary.imports;
    summary.module_resolution_diagnostics = module_resolutions.summary.diagnostics;
    var symbol_resolutions = try typescript_symbol_corpus.resolve(&module_resolutions);
    defer symbol_resolutions.deinit();
    try materializeTypeScriptSymbols(&graph, &symbol_resolutions);
    summary.symbol_resolutions = symbol_resolutions.summary.facts;
    summary.symbol_resolution_diagnostics = symbol_resolutions.summary.diagnostics;
    var proto_resolutions = try protobuf_corpus.resolve();
    defer proto_resolutions.deinit();
    try materializeProtobufResolutions(&graph, &proto_resolutions);
    summary.proto_entities = proto_resolutions.summary.entities;
    summary.proto_references = proto_resolutions.summary.references;
    summary.proto_resolution_diagnostics = proto_resolutions.summary.diagnostics;
    var generated = try generated_corpus.resolve(&proto_resolutions);
    defer generated.deinit();
    try materializeGeneratedLineage(&graph, &proto_resolutions, &generated);
    summary.generated_bindings = generated.summary.links;
    var continuity = try continuity_corpus.resolvePrepared(.{
        .proto = &proto_resolutions,
        .protobuf = &protobuf_corpus,
        .lineage = &generated,
        .modules = &module_resolutions,
        .typescript = typescript_symbol_corpus.parsedResults(),
        .zig = zig_corpus.parsedResults(),
    });
    defer continuity.deinit();
    const derived = try materializeRpcContinuity(
        &graph,
        &proto_resolutions,
        &continuity,
        &typescript_symbol_corpus,
        &zig_corpus,
        &extraction,
        options.previous_graph,
    );
    summary.rpc_observations = continuity.summary.observations;
    summary.rpc_interactions = continuity.summary.interactions;
    summary.request_paths = graph.hyperedgeCount();
    summary.feature_supernodes = graph.supernodeCount();
    summary.derived_hyperedges_reused = derived.hyperedges_reused;
    summary.derived_hyperedges_recomputed = derived.hyperedges_recomputed;
    summary.derived_supernodes_reused = derived.supernodes_reused;
    summary.derived_supernodes_recomputed = derived.supernodes_recomputed;
    const causal_records = root.readFileAlloc(io, causal_wal_path, allocator, .limited(max_causal_bytes)) catch |failure| switch (failure) {
        error.FileNotFound => null,
        else => return failure,
    };
    if (causal_records) |records| {
        defer allocator.free(records);
        summary.causal_records = try indexCausalRecords(&graph, causal_wal_path, records);
    }
    upgradeCorroboratedCalls(&graph);
    summary.nodes = graph.nodeCount();
    summary.edges = graph.edgeCount();
    summary.vectors = graph.vectorCount();
    var extraction_evidence = try extraction.finish(&graph);
    errdefer extraction_evidence.deinit();
    summary.cacheable_files = extraction_evidence.stats.cacheable_files;
    summary.cache_hits = extraction_evidence.stats.hits;
    summary.cache_misses = extraction_evidence.stats.misses;
    summary.cache_rejected = extraction_evidence.stats.rejected;
    summary.cache_writes = extraction_evidence.stats.writes;
    summary.reparsed_files = extraction_evidence.stats.reparsed_files;
    summary.direct_invalidations = extraction_evidence.stats.direct_invalidations;
    summary.invalidation_closure = extraction_evidence.stats.invalidation_closure;
    return .{
        .graph = graph,
        .summary = summary,
        .discovery_result = discovered,
        .ownership_result = owned_context,
        .extraction = extraction_evidence,
    };
}

fn readVerifiedSource(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    path: []const u8,
    max_bytes: usize,
    expected_digest: ?[32]u8,
) ![]u8 {
    const expected = expected_digest orelse return error.MissingDiscoveryFingerprint;
    const source = root.readFileAlloc(io, path, allocator, .limited(max_bytes)) catch return error.DiscoveryContentUnavailable;
    errdefer allocator.free(source);
    var actual: [32]u8 = @splat(0);
    std.crypto.hash.sha2.Sha256.hash(source, &actual, .{});
    if (!std.mem.eql(u8, &expected, &actual)) return error.DiscoveryContentChanged;
    return source;
}

pub fn indexZigSource(graph: *model.RepositoryGraph, path: []const u8, source: []const u8) !void {
    try validateSourcePath(path);
    var parsed = try zig_parser.parse(graph.allocator, path, source, .{});
    defer parsed.deinit();
    try indexParsedZigSource(graph, path, source, &parsed);
}

pub fn indexTypeScriptSource(
    graph: *model.RepositoryGraph,
    path: []const u8,
    source: []const u8,
    mode: typescript_parser.LanguageMode,
) !void {
    try validateSourcePath(path);
    var parsed = try typescript_parser.parse(graph.allocator, path, source, mode, .{});
    defer parsed.deinit();
    try indexParsedTypeScriptSource(graph, path, source, &parsed);
}

fn indexParsedTypeScriptSource(
    graph: *model.RepositoryGraph,
    path: []const u8,
    source: []const u8,
    parsed: *const typescript_parser.Result,
) !void {
    try typescript_parser.validate(parsed);
    const file_id = try graph.addNode(.{
        .kind = .file,
        .label = std.fs.path.basename(path),
        .path = path,
        .line = 1,
        .search_text = path,
    });
    for (parsed.declarations) |declaration_fact| {
        const scope = if (declaration_fact.enclosing_declaration.len == 0)
            path
        else
            try std.fmt.allocPrint(graph.allocator, "{s}#{s}", .{ path, declaration_fact.enclosing_declaration });
        defer if (declaration_fact.enclosing_declaration.len > 0) graph.allocator.free(scope);
        const symbol_id = try graph.addNode(.{
            .id = model.stableId(.symbol, scope, declaration_fact.name),
            .kind = .symbol,
            .label = declaration_fact.name,
            .path = path,
            .line = declaration_fact.name_span.start_line,
            .search_text = source[declaration_fact.span.start_byte..declaration_fact.span.end_byte],
        });
        const owner_id = if (declaration_fact.enclosing_declaration.len == 0)
            file_id
        else if (findQualifiedTypeScriptSymbol(graph, path, declaration_fact.enclosing_declaration)) |owner|
            owner.id
        else
            file_id;
        try graph.addEdge(.{
            .from = owner_id,
            .to = symbol_id,
            .relation = .declares,
            .provenance = .extracted,
            .source_path = path,
            .line = declaration_fact.name_span.start_line,
        });
    }
}

fn indexParsedZigSource(
    graph: *model.RepositoryGraph,
    path: []const u8,
    source: []const u8,
    parsed: *const zig_parser.Result,
) !void {
    const file_label = std.fs.path.basename(path);
    const file_id = try graph.addNode(.{
        .kind = .file,
        .label = file_label,
        .path = path,
        .line = 1,
        .search_text = path,
    });

    var symbols: std.ArrayList(Symbol) = .empty;
    defer symbols.deinit(graph.allocator);
    var local_bindings: std.ArrayList(LocalBinding) = .empty;
    defer local_bindings.deinit(graph.allocator);
    for (parsed.declarations) |declaration_fact| {
        const line_number = declaration_fact.name_span.start_line;
        const search_text = source[declaration_fact.span.start_byte..declaration_fact.span.end_byte];
        const symbol_id = try graph.addNode(.{
            .kind = .symbol,
            .label = declaration_fact.name,
            .path = path,
            .line = line_number,
            .search_text = search_text,
        });
        try symbols.append(graph.allocator, .{
            .id = symbol_id,
            .name = graph.findNode(symbol_id).?.label,
            .line = line_number,
            .kind = declaration_fact.kind,
            .span = declaration_fact.span,
        });
    }
    for (parsed.declarations, 0..) |declaration_fact, declaration_index| {
        const owner = if (smallestContainingDeclaration(parsed.declarations, declaration_index)) |owner_index|
            symbols.items[owner_index].id
        else
            file_id;
        try graph.addEdge(.{
            .from = owner,
            .to = symbols.items[declaration_index].id,
            .relation = .declares,
            .provenance = .extracted,
            .source_path = path,
            .line = declaration_fact.name_span.start_line,
        });
    }
    for (parsed.bindings) |binding_fact| {
        if (binding_fact.scope != .local) continue;
        const owner = findUniqueSymbol(symbols.items, binding_fact.enclosing_declaration) orelse continue;
        const binding_id = try graph.addNode(.{
            .kind = .concept,
            .label = binding_fact.name,
            .path = path,
            .line = binding_fact.name_span.start_line,
            .search_text = source[binding_fact.span.start_byte..binding_fact.span.end_byte],
        });
        try graph.addEdge(.{
            .from = owner,
            .to = binding_id,
            .relation = .declares,
            .provenance = .extracted,
            .source_path = path,
            .line = binding_fact.name_span.start_line,
        });
        try local_bindings.append(graph.allocator, .{
            .id = binding_id,
            .name = graph.findNode(binding_id).?.label,
            .enclosing_declaration = binding_fact.enclosing_declaration,
        });
    }
    for (parsed.imports) |import_fact| {
        const external_id = try graph.addNode(.{
            .kind = .external_module,
            .label = import_fact.target,
            .path = import_fact.target,
            .line = import_fact.span.start_line,
            .search_text = import_fact.target,
        });
        try graph.addEdge(.{
            .from = file_id,
            .to = external_id,
            .relation = .imports,
            .provenance = .extracted,
            .source_path = path,
            .line = import_fact.span.start_line,
        });
    }
    for (parsed.calls) |call_fact| {
        const caller = findUniqueSymbol(symbols.items, call_fact.enclosing_declaration) orelse continue;
        const caller_symbol = findSymbolById(symbols.items, caller) orelse continue;
        const callee = calleeLeaf(call_fact.callee);
        if (callee.len == 0) continue;
        const local_target = findUniqueLocalBinding(local_bindings.items, callee, call_fact.enclosing_declaration);
        const target = local_target orelse findUniqueSymbol(symbols.items, callee) orelse try graph.addNode(.{
            .kind = .concept,
            .label = callee,
            .path = path,
            .line = call_fact.callee_span.start_line,
            .search_text = call_fact.callee,
        });
        if (target == caller) continue;
        const target_node = graph.findNode(target) orelse continue;
        try graph.addEdge(.{
            .from = caller,
            .to = target,
            .relation = if (caller_symbol.kind == .test_decl and target_node.kind == .symbol) .covers else .calls,
            .provenance = callProvenance(graph, file_id, local_target, target_node),
            .source_path = path,
            .line = call_fact.callee_span.start_line,
        });
    }
}

/// How much this call edge is worth believing.
///
/// The old rule was `if (local_target != null) .extracted` — whether the callee
/// was found in the same file. That reports locality and calls it evidence: an
/// agent filtering on `.extracted` was filtering on "defined nearby", which says
/// nothing about whether the edge is real.
///
/// The corroborating fact was already in the graph and unread. A file's
/// `imports` edges are written before this loop runs, and 163 of them in this
/// repository's own index already resolve to `file` nodes with real paths rather
/// than to unresolved specifiers. So the question "does the caller's file import
/// the file this symbol lives in" is answerable here, today, without any new
/// resolution.
///
/// The ladder, strongest first:
///   - same file            -> extracted. The definition is right there.
///   - imported file        -> extracted. A second fact agrees.
///   - resolved elsewhere   -> inferred. A name matched; nothing corroborates it.
///   - invented placeholder -> ambiguous. No definition was found at all.
///
/// Unresolved specifiers — package names, anything the import pass could not
/// place — contribute nothing rather than counting as evidence. An import edge
/// pointing at `std` cannot corroborate a call to `foo`.
fn callProvenance(
    graph: *const model.RepositoryGraph,
    file_id: u64,
    local_target: ?u64,
    target_node: *const model.Node,
) model.Provenance {
    if (local_target != null) return .extracted;
    if (target_node.kind == .concept) return .ambiguous;
    if (importsFile(graph, file_id, target_node.path)) return .extracted;
    return .inferred;
}

/// Exposed for tests: the predicate the evidence ladder rests on is the part
/// worth pinning, because a wrong answer here labels a guess `.extracted`.
pub fn importsFileForTest(graph: *const model.RepositoryGraph, file_id: u64, path: []const u8) bool {
    return importsFile(graph, file_id, path);
}

pub fn upgradeCorroboratedCallsForTest(graph: *model.RepositoryGraph) void {
    upgradeCorroboratedCalls(graph);
}

/// Whether `file_id` has an `imports` edge to a file node at `path`.
///
/// Only resolved edges count. An `external_module` target carries the specifier
/// as written, which is a different namespace from a repository path, and
/// comparing across the two would match by coincidence.
fn importsFile(graph: *const model.RepositoryGraph, file_id: u64, path: []const u8) bool {
    if (path.len == 0) return false;
    for (graph.outgoingEdges(file_id)) |edge_index| {
        const edge = graph.edgeAt(edge_index) orelse continue;
        if (edge.relation != .imports) continue;
        const imported = graph.findNode(edge.to) orelse continue;
        if (imported.kind != .file) continue;
        if (std.mem.eql(u8, imported.path, path)) return true;
    }
    return false;
}

fn calleeLeaf(callee: []const u8) []const u8 {
    const dot = std.mem.lastIndexOfScalar(u8, callee, '.');
    const leaf = if (dot) |index| callee[index + 1 ..] else callee;
    if (std.mem.lastIndexOfScalar(u8, leaf, ')')) |close| {
        if (close + 1 < leaf.len) return leaf[close + 1 ..];
    }
    return leaf;
}

pub fn indexZigEffectManifest(graph: *model.RepositoryGraph, json: []const u8) !void {
    if (json.len == 0 or json.len > max_manifest_bytes) return error.InvalidManifest;
    var parsed = std.json.parseFromSlice(std.json.Value, graph.allocator, json, .{}) catch return error.InvalidManifest;
    defer parsed.deinit();
    const root = switch (parsed.value) {
        .object => |object| object,
        else => return error.InvalidManifest,
    };
    const schema = valueString(root.get("schema")) orelse return error.InvalidManifest;
    if (!std.mem.eql(u8, schema, "zigeffect.project.v1")) return error.UnsupportedManifest;

    if (root.get("components")) |value| if (value == .array) {
        for (value.array.items) |item| {
            const object = valueObject(item) orelse continue;
            const id = valueString(object.get("id")) orelse continue;
            const path = valueString(object.get("path")) orelse "";
            _ = try graph.addNode(.{ .kind = .component, .label = id, .path = path, .search_text = id });
        }
        for (value.array.items) |item| {
            const object = valueObject(item) orelse continue;
            const id = valueString(object.get("id")) orelse continue;
            const component = findByKindAndLabel(graph, .component, id) orelse continue;
            const component_id = component.id;
            const component_path = component.path;
            if (findSourceByPath(graph, component_path)) |source| {
                try graph.addEdge(.{ .from = component_id, .to = source.id, .relation = .source_root, .provenance = .extracted, .source_path = "zigeffect.project.json" });
            }
            if (object.get("depends_on")) |dependencies| if (dependencies == .array) {
                for (dependencies.array.items) |dependency_value| {
                    const dependency_label = valueString(dependency_value) orelse continue;
                    const dependency = findByKindAndLabel(graph, .component, dependency_label) orelse continue;
                    try graph.addEdge(.{ .from = component_id, .to = dependency.id, .relation = .depends_on, .provenance = .extracted, .source_path = "zigeffect.project.json" });
                }
            };
        }
    };
    if (root.get("commands")) |value| if (value == .array) {
        for (value.array.items) |item| {
            const object = valueObject(item) orelse continue;
            const id = valueString(object.get("id")) orelse continue;
            _ = try graph.addNode(.{ .kind = .command, .label = id, .path = "zigeffect.project.json", .search_text = id });
        }
    };
    if (root.get("requirements")) |value| if (value == .array) {
        for (value.array.items) |item| {
            const object = valueObject(item) orelse continue;
            const id = valueString(object.get("id")) orelse continue;
            const summary = valueString(object.get("summary")) orelse id;
            const requirement_id = try graph.addNode(.{ .kind = .requirement, .label = id, .path = "zigeffect.project.json", .search_text = summary });
            if (valueString(object.get("component"))) |component_label| {
                if (findByKindAndLabel(graph, .component, component_label)) |component| {
                    try graph.addEdge(.{ .from = requirement_id, .to = component.id, .relation = .satisfies, .provenance = .extracted, .source_path = "zigeffect.project.json" });
                }
            }
        }
    };
    if (root.get("acceptance_checks")) |value| if (value == .array) {
        for (value.array.items) |item| {
            const object = valueObject(item) orelse continue;
            const id = valueString(object.get("id")) orelse continue;
            const expectation = valueString(object.get("expectation")) orelse id;
            const check_id = try graph.addNode(.{ .kind = .acceptance_check, .label = id, .path = "zigeffect.project.json", .search_text = expectation });
            if (valueString(object.get("requirement"))) |requirement_label| {
                if (findByKindAndLabel(graph, .requirement, requirement_label)) |requirement| {
                    try graph.addEdge(.{ .from = requirement.id, .to = check_id, .relation = .verified_by, .provenance = .extracted, .source_path = "zigeffect.project.json" });
                }
            }
            if (valueString(object.get("command"))) |command_label| {
                if (findByKindAndLabel(graph, .command, command_label)) |command| {
                    try graph.addEdge(.{ .from = check_id, .to = command.id, .relation = .executes, .provenance = .extracted, .source_path = "zigeffect.project.json" });
                }
            }
        }
    };
    if (root.get("test_scenarios")) |value| if (value == .array) {
        for (value.array.items) |item| {
            const object = valueObject(item) orelse continue;
            const id = valueString(object.get("id")) orelse continue;
            const label = valueString(object.get("label")) orelse id;
            const scenario_id = try graph.addNode(.{ .kind = .test_scenario, .label = id, .path = "zigeffect.project.json", .search_text = label });
            if (valueString(object.get("requirement"))) |requirement_label| {
                if (findByKindAndLabel(graph, .requirement, requirement_label)) |requirement| {
                    try graph.addEdge(.{ .from = scenario_id, .to = requirement.id, .relation = .covers, .provenance = .extracted, .source_path = "zigeffect.project.json" });
                }
            }
            if (valueString(object.get("command"))) |command_label| {
                if (findByKindAndLabel(graph, .command, command_label)) |command| {
                    try graph.addEdge(.{ .from = scenario_id, .to = command.id, .relation = .executes, .provenance = .extracted, .source_path = "zigeffect.project.json" });
                }
            }
            if (object.get("source_roots")) |roots| if (roots == .array) {
                for (roots.array.items) |source_value| {
                    const source_path = valueString(source_value) orelse continue;
                    if (findSourceByPath(graph, source_path)) |source| {
                        try graph.addEdge(.{ .from = scenario_id, .to = source.id, .relation = .source_root, .provenance = .extracted, .source_path = "zigeffect.project.json" });
                    }
                }
            };
        }
    };
}

pub fn indexCausalRecords(graph: *model.RepositoryGraph, wal_path: []const u8, jsonl: []const u8) !usize {
    if (jsonl.len > max_causal_bytes) return error.CausalGraphTooLarge;
    const PersistedNode = struct { properties: []const u8 };
    const PersistedRecord = struct { session_id: u64, node: PersistedNode };
    const Properties = struct {
        event_id: u64,
        kind: []const u8,
        parent_id: ?u64 = null,
        label: []const u8 = "",
        status: []const u8 = "",
        domain_entity_ref: []const u8 = "",
    };
    const Parent = struct { session_id: u64, child: u64, parent_event_id: u64 };
    var parents: std.ArrayList(Parent) = .empty;
    defer parents.deinit(graph.allocator);
    var imported: usize = 0;
    var lines = std.mem.splitScalar(u8, jsonl, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var persisted = std.json.parseFromSlice(PersistedRecord, graph.allocator, line, .{ .ignore_unknown_fields = true }) catch return error.InvalidCausalRecord;
        defer persisted.deinit();
        var properties = std.json.parseFromSlice(Properties, graph.allocator, persisted.value.node.properties, .{ .ignore_unknown_fields = true }) catch return error.InvalidCausalRecord;
        defer properties.deinit();
        const event = properties.value;
        var id_buffer = [_]u8{0} ** 32;
        const event_identity = std.fmt.bufPrint(&id_buffer, "{d}:{d}", .{ persisted.value.session_id, event.event_id }) catch return error.InvalidCausalRecord;
        const search_text = try std.fmt.allocPrint(graph.allocator, "{s} {s} {s}", .{ event.kind, event.label, event.status });
        defer graph.allocator.free(search_text);
        const node_id = try graph.addNode(.{
            .kind = .causal_event,
            .label = if (event.label.len > 0) event.label else event.kind,
            .path = wal_path,
            .search_text = search_text,
            .id = model.stableId(.causal_event, wal_path, event_identity),
        });
        if (event.parent_id) |parent_event_id| try parents.append(graph.allocator, .{
            .session_id = persisted.value.session_id,
            .child = node_id,
            .parent_event_id = parent_event_id,
        });
        if (sourceRefTarget(graph, event.domain_entity_ref)) |source| {
            try graph.addEdge(.{
                .from = node_id,
                .to = source.id,
                .relation = .observed_at,
                .provenance = .extracted,
                .source_path = wal_path,
            });
        }
        imported += 1;
    }
    for (parents.items) |parent| {
        var id_buffer = [_]u8{0} ** 32;
        const parent_identity = std.fmt.bufPrint(&id_buffer, "{d}:{d}", .{ parent.session_id, parent.parent_event_id }) catch continue;
        const parent_id = model.stableId(.causal_event, wal_path, parent_identity);
        if (graph.findNode(parent_id) == null) continue;
        try graph.addEdge(.{
            .from = parent_id,
            .to = parent.child,
            .relation = .causal_parent,
            .provenance = .extracted,
            .source_path = wal_path,
        });
    }
    return imported;
}

const Declaration = struct { name: []const u8 };

fn declaration(line: []const u8) ?Declaration {
    if (functionName(line)) |name| return .{ .name = name };
    const const_at = std.mem.indexOf(u8, line, "const ") orelse return null;
    const tail = line[const_at + "const ".len ..];
    const equals = std.mem.indexOfScalar(u8, tail, '=') orelse return null;
    const name = std.mem.trim(u8, tail[0..equals], " \t");
    if (name.len == 0) return null;
    const value = tail[equals + 1 ..];
    if (std.mem.indexOf(u8, value, "struct") == null and
        std.mem.indexOf(u8, value, "enum") == null and
        std.mem.indexOf(u8, value, "union") == null and
        std.mem.indexOf(u8, value, "error{") == null) return null;
    return .{ .name = name };
}

fn functionName(line: []const u8) ?[]const u8 {
    const fn_at = std.mem.indexOf(u8, line, "fn ") orelse return null;
    const start = fn_at + 3;
    var end = start;
    while (end < line.len and isIdentifierByte(line[end])) end += 1;
    if (end == start or end >= line.len or line[end] != '(') return null;
    return line[start..end];
}

fn importTarget(line: []const u8) ?[]const u8 {
    const marker = "@import(\"";
    const start_at = std.mem.indexOf(u8, line, marker) orelse return null;
    const start = start_at + marker.len;
    const end_offset = std.mem.indexOfScalar(u8, line[start..], '"') orelse return null;
    return line[start .. start + end_offset];
}

fn stripLineComment(line: []const u8) []const u8 {
    var in_string = false;
    var escaped = false;
    var index: usize = 0;
    while (index + 1 < line.len) : (index += 1) {
        const char = line[index];
        if (escaped) {
            escaped = false;
            continue;
        }
        if (char == '\\' and in_string) {
            escaped = true;
            continue;
        }
        if (char == '"') in_string = !in_string;
        if (!in_string and char == '/' and line[index + 1] == '/') return line[0..index];
    }
    return line;
}

fn stripComments(line: []const u8, in_block_comment: *bool) []const u8 {
    var visible = line;
    if (in_block_comment.*) {
        const end = std.mem.indexOf(u8, visible, "*/") orelse return "";
        visible = visible[end + 2 ..];
        in_block_comment.* = false;
    }
    const without_line_comment = stripLineComment(visible);
    if (blockCommentStart(without_line_comment)) |start| {
        if (std.mem.indexOf(u8, without_line_comment[start + 2 ..], "*/") == null) in_block_comment.* = true;
        return without_line_comment[0..start];
    }
    return without_line_comment;
}

fn blockCommentStart(line: []const u8) ?usize {
    var in_string = false;
    var escaped = false;
    var index: usize = 0;
    while (index + 1 < line.len) : (index += 1) {
        const char = line[index];
        if (escaped) {
            escaped = false;
            continue;
        }
        if (char == '\\' and in_string) {
            escaped = true;
            continue;
        }
        if (char == '"') in_string = !in_string;
        if (!in_string and char == '/' and line[index + 1] == '*') return index;
    }
    return null;
}

fn braceDelta(line: []const u8) isize {
    var delta: isize = 0;
    var in_string = false;
    for (line) |char| {
        if (char == '"') in_string = !in_string;
        if (in_string) continue;
        if (char == '{') delta += 1;
        if (char == '}') delta -= 1;
    }
    return delta;
}

fn findUniqueSymbol(symbols: []const Symbol, name: []const u8) ?u64 {
    var found: ?u64 = null;
    for (symbols) |symbol| {
        if (!std.mem.eql(u8, symbol.name, name)) continue;
        if (found != null) return null;
        found = symbol.id;
    }
    return found;
}

fn findSymbolById(symbols: []const Symbol, id: u64) ?*const Symbol {
    for (symbols) |*symbol| if (symbol.id == id) return symbol;
    return null;
}

fn smallestContainingDeclaration(declarations: []const zig_parser.Declaration, child_index: usize) ?usize {
    const child = declarations[child_index];
    var best: ?usize = null;
    var best_width: usize = std.math.maxInt(usize);
    for (declarations, 0..) |candidate, index| {
        if (index == child_index or !declarationCanContain(candidate.kind) or
            candidate.span.start_byte >= child.span.start_byte or candidate.span.end_byte <= child.span.end_byte) continue;
        const width = candidate.span.end_byte - candidate.span.start_byte;
        if (width < best_width) {
            best = index;
            best_width = width;
        }
    }
    return best;
}

fn declarationCanContain(kind: zig_parser.DeclarationKind) bool {
    return kind == .structure or kind == .enumeration or kind == .union_type or kind == .opaque_type;
}

fn findUniqueLocalBinding(bindings: []const LocalBinding, name: []const u8, enclosing: []const u8) ?u64 {
    var found: ?u64 = null;
    for (bindings) |binding| {
        if (!std.mem.eql(u8, binding.name, name) or !std.mem.eql(u8, binding.enclosing_declaration, enclosing)) continue;
        if (found != null) return null;
        found = binding.id;
    }
    return found;
}

const CallIterator = struct {
    line: []const u8,
    cursor: usize = 0,

    fn init(line: []const u8) CallIterator {
        return .{ .line = line };
    }

    fn next(self: *CallIterator) ?[]const u8 {
        while (self.cursor < self.line.len) {
            const open_offset = std.mem.indexOfScalar(u8, self.line[self.cursor..], '(') orelse return null;
            const open = self.cursor + open_offset;
            var start = open;
            while (start > 0 and isIdentifierByte(self.line[start - 1])) start -= 1;
            self.cursor = open + 1;
            if (start == open) continue;
            return self.line[start..open];
        }
        return null;
    }
};

fn isIdentifierByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

fn isControlWord(value: []const u8) bool {
    for ([_][]const u8{ "if", "for", "while", "switch", "catch", "return", "defer", "errdefer" }) |word| {
        if (std.mem.eql(u8, word, value)) return true;
    }
    return false;
}

fn validateSourcePath(path: []const u8) !void {
    if (path.len == 0 or path[0] == '/' or std.mem.indexOf(u8, path, "..") != null or std.mem.indexOfScalar(u8, path, '\\') != null) {
        return error.InvalidSourcePath;
    }
}

fn valueString(value: ?std.json.Value) ?[]const u8 {
    const present = value orelse return null;
    return switch (present) {
        .string => |text| text,
        else => null,
    };
}

fn valueObject(value: std.json.Value) ?std.json.ObjectMap {
    return switch (value) {
        .object => |object| object,
        else => null,
    };
}

fn findByKindAndLabel(graph: *const model.RepositoryGraph, kind: model.NodeKind, label: []const u8) ?*const model.Node {
    for (graph.nodes.items) |*node| if (node.kind == kind and std.mem.eql(u8, node.label, label)) return node;
    return null;
}

fn findByKindPathAndLabel(
    graph: *const model.RepositoryGraph,
    kind: model.NodeKind,
    path: []const u8,
    label: []const u8,
) ?*const model.Node {
    for (graph.nodes.items) |*node| {
        if (node.kind == kind and std.mem.eql(u8, node.path, path) and std.mem.eql(u8, node.label, label)) return node;
    }
    return null;
}

fn findFileByPath(graph: *const model.RepositoryGraph, path: []const u8) ?*const model.Node {
    for (graph.nodes.items) |*node| if (node.kind == .file and std.mem.eql(u8, node.path, path)) return node;
    return null;
}

fn findSourceByPath(graph: *const model.RepositoryGraph, path: []const u8) ?*const model.Node {
    for (graph.nodes.items) |*node| {
        if ((node.kind == .file or node.kind == .directory) and std.mem.eql(u8, node.path, path)) return node;
    }
    return null;
}

fn sourceRefTarget(graph: *const model.RepositoryGraph, source_ref: []const u8) ?*const model.Node {
    const prefix = "zgraphy://source/";
    if (!std.mem.startsWith(u8, source_ref, prefix)) return null;
    const identity = source_ref[prefix.len..];
    const fragment = std.mem.lastIndexOfScalar(u8, identity, '#') orelse return null;
    const path = identity[0..fragment];
    const symbol = identity[fragment + 1 ..];
    if (path.len == 0 or symbol.len == 0 or path[0] == '/' or std.mem.indexOf(u8, path, "..") != null) return null;
    for (graph.nodes.items) |*node| {
        if (node.kind == .symbol and std.mem.eql(u8, node.path, path) and std.mem.eql(u8, node.label, symbol)) return node;
    }
    return null;
}

fn supportedPath(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".zig") or std.mem.eql(u8, path, "zigeffect.project.json");
}

const IgnoreRules = struct {
    allocator: std.mem.Allocator,
    patterns: std.ArrayList([]const u8) = .empty,

    fn deinit(self: *IgnoreRules) void {
        for (self.patterns.items) |pattern| self.allocator.free(pattern);
        self.patterns.deinit(self.allocator);
    }

    fn matches(self: *const IgnoreRules, path: []const u8) bool {
        for (self.patterns.items) |pattern| if (ignorePatternMatches(pattern, path)) return true;
        return false;
    }
};

fn loadIgnoreRules(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir) !IgnoreRules {
    var rules = IgnoreRules{ .allocator = allocator };
    errdefer rules.deinit();
    for ([_][]const u8{ ".gitignore", ".zgraphyignore" }) |ignore_path| {
        const contents = root.readFileAlloc(io, ignore_path, allocator, .limited(512 * 1024)) catch |failure| switch (failure) {
            error.FileNotFound => continue,
            else => return failure,
        };
        defer allocator.free(contents);
        var lines = std.mem.splitScalar(u8, contents, '\n');
        while (lines.next()) |raw_line| {
            var line = std.mem.trim(u8, raw_line, " \t\r");
            if (line.len == 0 or line[0] == '#') continue;
            if (line[0] == '!') continue;
            if (line[0] == '/') line = line[1..];
            if (line.len == 0 or line.len > 1024 or rules.patterns.items.len >= 4096) return error.InvalidIgnoreRule;
            try rules.patterns.append(allocator, try owned.copy(u8, allocator, line));
        }
    }
    return rules;
}

fn ignorePatternMatches(pattern: []const u8, path: []const u8) bool {
    if (std.mem.endsWith(u8, pattern, "/**")) {
        const prefix = pattern[0 .. pattern.len - 3];
        return std.mem.eql(u8, path, prefix) or (std.mem.startsWith(u8, path, prefix) and path.len > prefix.len and path[prefix.len] == '/');
    }
    if (std.mem.endsWith(u8, pattern, "/")) {
        const directory = pattern[0 .. pattern.len - 1];
        return std.mem.eql(u8, path, directory) or (std.mem.startsWith(u8, path, directory) and path.len > directory.len and path[directory.len] == '/');
    }
    if (std.mem.startsWith(u8, pattern, "*")) return std.mem.endsWith(u8, path, pattern[1..]);
    if (std.mem.indexOfScalar(u8, pattern, '/') == null) {
        var components = std.mem.splitScalar(u8, path, '/');
        while (components.next()) |component| if (std.mem.eql(u8, component, pattern)) return true;
    }
    return std.mem.eql(u8, path, pattern);
}

fn mandatoryExcluded(path: []const u8) bool {
    var components = std.mem.splitScalar(u8, path, '/');
    while (components.next()) |component| {
        for ([_][]const u8{ ".git", ".zgraphy", ".zig-cache", "zig-out", "node_modules", "zig-pkg" }) |excluded| {
            if (std.mem.eql(u8, component, excluded)) return true;
        }
    }
    return false;
}

fn looksBinary(source: []const u8) bool {
    const sample = source[0..@min(source.len, 8192)];
    return std.mem.indexOfScalar(u8, sample, 0) != null;
}

fn linkFileHierarchy(graph: *model.RepositoryGraph, repository_id: u64, path: []const u8) !void {
    const file = findFileByPath(graph, path) orelse return error.MissingIndexedFile;
    const file_id = file.id;
    const parent_path = std.fs.path.dirname(path) orelse {
        try graph.addEdge(.{ .from = repository_id, .to = file_id, .relation = .contains, .provenance = .extracted });
        return;
    };
    const directory_id = try graph.addNode(.{
        .kind = .directory,
        .label = std.fs.path.basename(parent_path),
        .path = parent_path,
        .search_text = parent_path,
    });
    try graph.addEdge(.{ .from = repository_id, .to = directory_id, .relation = .contains, .provenance = .extracted });
    try graph.addEdge(.{ .from = directory_id, .to = file_id, .relation = .contains, .provenance = .extracted });
}

fn resolveFileImports(graph: *model.RepositoryGraph) !void {
    const edges = try owned.copy(model.Edge, graph.allocator, graph.edges.items);
    defer graph.allocator.free(edges);
    for (edges) |edge| {
        if (edge.relation != .imports) continue;
        const importer = graph.findNode(edge.from) orelse continue;
        const external = graph.findNode(edge.to) orelse continue;
        if (importer.kind != .file or external.kind != .external_module) continue;
        var resolved_path_buffer = [_]u8{0} ** std.fs.max_path_bytes;
        const parent = std.fs.path.dirname(importer.path) orelse "";
        const candidate = if (parent.len == 0)
            std.fmt.bufPrint(&resolved_path_buffer, "{s}", .{external.path}) catch continue
        else
            std.fmt.bufPrint(&resolved_path_buffer, "{s}/{s}", .{ parent, external.path }) catch continue;
        const target = findFileByPath(graph, candidate) orelse continue;
        try graph.addEdge(.{
            .from = importer.id,
            .to = target.id,
            .relation = .imports,
            .provenance = .inferred,
            .source_path = importer.path,
            .line = edge.line,
        });
    }
}

/// Promote call edges whose target has an import agreeing with them.
///
/// The evidence ladder cannot run where the call is written: `indexParsedZigSource`
/// decides provenance per file, and the imports it would consult are still
/// unresolved specifiers at that moment — `resolveFileImports` above is what
/// turns `./helper.zig` into an edge to a file node, and it runs only once every
/// file has been seen.
///
/// Nor can it run inside `resolveFileImports`: the cross-file calls it would
/// promote do not exist yet either. `materializeZigResolutions` is what binds a
/// callee name to a symbol in another file, and it runs after. Placed there this
/// pass promoted exactly nothing on this repository — 34 extracted edges, all of
/// them same-file locality from the earlier rule — while the corroboration it
/// was looking for was present for all 155 cross-file calls.
///
/// So it runs last, once both facts exist. Only `.inferred` is promoted:
/// `.extracted` is already as strong, and `.ambiguous` means no definition was
/// found at all, which an import cannot fix.
fn upgradeCorroboratedCalls(graph: *model.RepositoryGraph) void {
    for (graph.edges.items) |*edge| {
        if (edge.provenance != .inferred) continue;
        if (edge.relation != .calls and edge.relation != .covers) continue;
        const target = graph.findNode(edge.to) orelse continue;
        if (target.kind != .symbol) continue;
        const importer = findFileByPath(graph, edge.source_path) orelse continue;
        if (importsFile(graph, importer.id, target.path)) edge.provenance = .extracted;
    }
}

fn materializeProtobufResolutions(graph: *model.RepositoryGraph, result: *const protobuf_resolution.Result) !void {
    try protobuf_resolution.validate(result);
    for (result.entities) |entity| {
        const kind = protobufNodeKind(entity.kind);
        const search_text = try std.fmt.allocPrint(graph.allocator, "{s} {s} protobuf {s}", .{
            entity.canonical_name,
            entity.display_name,
            @tagName(entity.kind),
        });
        defer graph.allocator.free(search_text);
        const entity_id = try graph.addNode(.{
            .id = model.stableId(kind, entity.source_path, entity.canonical_name),
            .kind = kind,
            .label = entity.canonical_name,
            .path = entity.source_path,
            .line = entity.span.start_line,
            .search_text = search_text,
        });
        const file = findFileByPath(graph, entity.source_path) orelse return error.MissingProtobufSourceFileNode;
        try graph.addEdge(.{
            .from = file.id,
            .to = entity_id,
            .relation = .declares,
            .provenance = .extracted,
            .source_path = entity.source_path,
            .line = entity.span.start_line,
        });
    }

    for (result.entities) |entity| switch (entity.kind) {
        .package => {},
        .message, .enumeration, .service => {
            const package = packageEntityFor(result, entity.source_path) orelse continue;
            const package_node = protobufEntityNode(graph, package) orelse return error.MissingProtobufPackageNode;
            const entity_node = protobufEntityNode(graph, &entity) orelse return error.MissingProtobufEntityNode;
            try graph.addEdge(.{
                .from = package_node.id,
                .to = entity_node.id,
                .relation = .declares,
                .provenance = .extracted,
                .source_path = entity.source_path,
                .line = entity.span.start_line,
            });
        },
        .operation => {
            const slash = std.mem.lastIndexOfScalar(u8, entity.canonical_name, '/') orelse continue;
            const service = findProtobufEntity(result, .service, entity.source_path, entity.canonical_name[0..slash]) orelse continue;
            const service_node = protobufEntityNode(graph, service) orelse return error.MissingProtobufServiceNode;
            const operation_node = protobufEntityNode(graph, &entity) orelse return error.MissingProtobufOperationNode;
            try graph.addEdge(.{
                .from = service_node.id,
                .to = operation_node.id,
                .relation = .declares,
                .provenance = .extracted,
                .source_path = entity.source_path,
                .line = entity.span.start_line,
            });
        },
        .field => {
            const hash = std.mem.lastIndexOfScalar(u8, entity.canonical_name, '#') orelse continue;
            const message = findProtobufEntity(result, .message, entity.source_path, entity.canonical_name[0..hash]) orelse continue;
            const message_node = protobufEntityNode(graph, message) orelse return error.MissingProtobufMessageNode;
            const field_node = protobufEntityNode(graph, &entity) orelse return error.MissingProtobufFieldNode;
            try graph.addEdge(.{
                .from = message_node.id,
                .to = field_node.id,
                .relation = .has_field,
                .provenance = .extracted,
                .source_path = entity.source_path,
                .line = entity.span.start_line,
            });
        },
        .enum_value => {
            const enumeration = enumOwnerEntity(result, &entity) orelse continue;
            const enum_node = protobufEntityNode(graph, enumeration) orelse return error.MissingProtobufEnumNode;
            const value_node = protobufEntityNode(graph, &entity) orelse return error.MissingProtobufEnumValueNode;
            try graph.addEdge(.{
                .from = enum_node.id,
                .to = value_node.id,
                .relation = .declares,
                .provenance = .extracted,
                .source_path = entity.source_path,
                .line = entity.span.start_line,
            });
        },
    };

    for (result.references) |reference| {
        const owner_kind: protobuf_resolution.EntityKind = switch (reference.kind) {
            .field_type => .field,
            .rpc_request, .rpc_response => .operation,
        };
        const owner = findProtobufEntity(result, owner_kind, reference.source_path, reference.owner) orelse return error.MissingProtobufReferenceOwner;
        const owner_node = protobufEntityNode(graph, owner) orelse return error.MissingProtobufReferenceOwnerNode;
        const relation: model.Relation = switch (reference.kind) {
            .field_type => .references_type,
            .rpc_request => .uses_request,
            .rpc_response => .uses_response,
        };
        const provenance: model.Provenance = if (reference.status == .ambiguous) .ambiguous else .inferred;
        for (result.candidatesFor(&reference)) |candidate| {
            const target = &result.entities[candidate.entity_index];
            const target_node = protobufEntityNode(graph, target) orelse return error.MissingProtobufReferenceTargetNode;
            try graph.addEdge(.{
                .from = owner_node.id,
                .to = target_node.id,
                .relation = relation,
                .provenance = provenance,
                .source_path = reference.source_path,
                .line = reference.span.start_line,
            });
        }
        if (reference.status == .external) {
            const external_path = try std.fmt.allocPrint(graph.allocator, "external/protobuf/{s}", .{reference.target});
            defer graph.allocator.free(external_path);
            const external_id = try graph.addNode(.{
                .kind = .type,
                .label = reference.target,
                .path = external_path,
                .line = reference.span.start_line,
                .search_text = reference.target,
            });
            try graph.addEdge(.{
                .from = owner_node.id,
                .to = external_id,
                .relation = relation,
                .provenance = .inferred,
                .source_path = reference.source_path,
                .line = reference.span.start_line,
            });
        }
    }
}

fn materializeGeneratedLineage(
    graph: *model.RepositoryGraph,
    proto: *const protobuf_resolution.Result,
    result: *const generated_lineage.Result,
) !void {
    try generated_lineage.validate(result, proto);
    for (result.links) |link| {
        const generated_file = findFileByPath(graph, link.generated_path) orelse return error.MissingGeneratedSourceFileNode;
        const source_id = if (link.kind == .file)
            generated_file.id
        else blk: {
            const kind = generatedNodeKind(link.kind);
            const search_text = try std.fmt.allocPrint(graph.allocator, "{s} {s} {s} generated protobuf", .{
                link.canonical_name,
                link.generated_symbol,
                @tagName(link.generator),
            });
            defer graph.allocator.free(search_text);
            const binding_id = try graph.addNode(.{
                .id = model.stableId(kind, link.generated_path, link.canonical_name),
                .kind = kind,
                .label = link.canonical_name,
                .path = link.generated_path,
                .line = 1,
                .search_text = search_text,
            });
            try graph.addEdge(.{
                .from = generated_file.id,
                .to = binding_id,
                .relation = .declares,
                .provenance = .extracted,
                .source_path = link.generated_path,
                .line = 1,
            });
            break :blk binding_id;
        };
        const relation: model.Relation = if (link.kind == .service)
            switch (link.direction) {
                .generated_client_for => .generated_client_for,
                .generated_server_for => .generated_server_for,
                .generated_from => .generated_from,
            }
        else
            .generated_from;
        const provenance: model.Provenance = if (link.status == .ambiguous) .ambiguous else .inferred;
        for (result.candidatesFor(&link)) |candidate| {
            const target_entity = &proto.entities[candidate.entity_index];
            const target_id = if (link.kind == .file)
                (findFileByPath(graph, target_entity.source_path) orelse return error.MissingGeneratedProtoFileTarget).id
            else
                (protobufEntityNode(graph, target_entity) orelse return error.MissingGeneratedProtoEntityTarget).id;
            try graph.addEdge(.{
                .from = source_id,
                .to = target_id,
                .relation = relation,
                .provenance = provenance,
                .source_path = link.generated_path,
                .line = 1,
            });
        }
    }
}

const DerivedRecordStats = struct {
    hyperedges_reused: usize = 0,
    hyperedges_recomputed: usize = 0,
    supernodes_reused: usize = 0,
    supernodes_recomputed: usize = 0,
};

const DerivedRecordOutcome = struct {
    hyperedge_reused: bool,
    supernode_reused: bool,
};

fn materializeRpcContinuity(
    graph: *model.RepositoryGraph,
    proto: *const protobuf_resolution.Result,
    result: *const rpc_continuity.Result,
    typescript: *const typescript_symbols.Corpus,
    zig: *const zig_resolution.Corpus,
    extraction: *extraction_cache.Session,
    previous_graph: ?*const model.RepositoryGraph,
) !DerivedRecordStats {
    try rpc_continuity.validate(result);
    if (!std.mem.eql(u8, &result.proto_fingerprint, &proto.fingerprint)) return error.RpcContinuityProtoSnapshotMismatch;
    for (result.observations) |observation| {
        if (observation.status != .resolved or observation.candidate_count != 1) continue;
        const source = switch (observation.role) {
            .frontend_invocation => findQualifiedTypeScriptSymbol(graph, observation.source_path, observation.source_symbol),
            .backend_handler => findUniqueQualifiedZigSymbol(graph, observation.source_path, observation.source_symbol),
        } orelse return error.MissingRpcContinuitySourceNode;
        const candidate = result.candidatesFor(&observation)[0];
        if (candidate.entity_index >= proto.entities.len or
            !std.mem.eql(u8, candidate.canonical_operation, proto.entities[candidate.entity_index].canonical_name) or
            !std.mem.eql(u8, candidate.proto_source_path, proto.entities[candidate.entity_index].source_path))
        {
            return error.RpcContinuityProtoSnapshotMismatch;
        }
        const operation = protobufEntityNode(graph, &proto.entities[candidate.entity_index]) orelse return error.MissingRpcContinuityOperationNode;
        try graph.addEdge(.{
            .from = source.id,
            .to = operation.id,
            .relation = switch (observation.role) {
                .frontend_invocation => .invokes_operation,
                .backend_handler => .handles_operation,
            },
            .provenance = .inferred,
            .source_path = observation.source_path,
            .line = observation.span.start_line,
        });
    }
    var invalidations = try extraction.previewInvalidations(graph);
    defer invalidations.deinit();
    var stats: DerivedRecordStats = .{};
    for (result.interactions) |interaction| {
        const outcome = try materializeRpcInteraction(graph, proto, result, &interaction, typescript, zig, previous_graph, &invalidations);
        if (outcome.hyperedge_reused) stats.hyperedges_reused += 1 else stats.hyperedges_recomputed += 1;
        if (outcome.supernode_reused) stats.supernodes_reused += 1 else stats.supernodes_recomputed += 1;
    }
    return stats;
}

fn materializeRpcInteraction(
    graph: *model.RepositoryGraph,
    proto: *const protobuf_resolution.Result,
    result: *const rpc_continuity.Result,
    interaction: *const rpc_continuity.Interaction,
    typescript: *const typescript_symbols.Corpus,
    zig: *const zig_resolution.Corpus,
    previous_graph: ?*const model.RepositoryGraph,
    invalidations: *const extraction_cache.InvalidationPreview,
) !DerivedRecordOutcome {
    const frontend_observation = &result.observations[interaction.frontend_observation_index];
    const backend_observation = &result.observations[interaction.backend_observation_index];
    const frontend = findQualifiedTypeScriptSymbol(graph, frontend_observation.source_path, frontend_observation.source_symbol) orelse return error.MissingRpcContinuitySourceNode;
    const client = findQualifiedTypeScriptSymbol(graph, frontend_observation.source_path, frontend_observation.supporting_symbol) orelse return error.MissingRpcClientBindingNode;
    const backend = findUniqueQualifiedZigSymbol(graph, backend_observation.source_path, backend_observation.source_symbol) orelse return error.MissingRpcContinuitySourceNode;
    const implementation = findUniqueQualifiedZigSymbol(graph, backend_observation.source_path, backend_observation.supporting_symbol) orelse return error.MissingRpcImplementationContainerNode;
    const frontend_candidate = result.candidatesFor(frontend_observation)[0];
    const operation_entity = &proto.entities[frontend_candidate.entity_index];
    const operation = protobufEntityNode(graph, operation_entity) orelse return error.MissingRpcContinuityOperationNode;
    const request_entity = findUniqueProtobufEntityByCanonical(proto, .message, interaction.request_type) orelse return error.MissingRpcRequestEntity;
    const response_entity = findUniqueProtobufEntityByCanonical(proto, .message, interaction.response_type) orelse return error.MissingRpcResponseEntity;
    const request = protobufEntityNode(graph, request_entity) orelse return error.MissingRpcRequestNode;
    const response = protobufEntityNode(graph, response_entity) orelse return error.MissingRpcResponseNode;
    const slash = std.mem.lastIndexOfScalar(u8, interaction.canonical_operation, '/') orelse return error.InvalidRpcOperationIdentity;
    const service_entity = findProtobufEntity(proto, .service, operation_entity.source_path, interaction.canonical_operation[0..slash]) orelse return error.MissingRpcServiceEntity;
    const service = protobufEntityNode(graph, service_entity) orelse return error.MissingRpcServiceNode;

    try graph.addEdge(.{
        .from = frontend.id,
        .to = client.id,
        .relation = .calls,
        .provenance = .inferred,
        .source_path = frontend_observation.source_path,
        .line = frontend_observation.span.start_line,
    });
    try graph.addEdge(.{
        .from = client.id,
        .to = service.id,
        .relation = .generated_from,
        .provenance = .inferred,
        .source_path = frontend_observation.source_path,
        .line = frontend_observation.supporting_span.start_line,
    });
    try graph.addEdge(.{
        .from = implementation.id,
        .to = backend.id,
        .relation = .declares,
        .provenance = .extracted,
        .source_path = backend_observation.source_path,
        .line = backend_observation.span.start_line,
    });

    const ui = uniqueIncomingNode(graph, frontend.id, .passes_callback);
    const loader = uniqueOutgoingNode(graph, backend.id, .calls);
    const focused_test = uniqueIncomingNode(graph, backend.id, .covers);
    var participants: [10]model.Participant = @splat(.{ .role = .ui_consumer, .node_id = 0 });
    var participant_count: usize = 0;
    appendParticipant(&participants, &participant_count, .frontend_callsite, frontend.id);
    appendParticipant(&participants, &participant_count, .client_binding, client.id);
    appendParticipant(&participants, &participant_count, .canonical_operation, operation.id);
    appendParticipant(&participants, &participant_count, .request_message, request.id);
    appendParticipant(&participants, &participant_count, .response_message, response.id);
    appendParticipant(&participants, &participant_count, .implementation_container, implementation.id);
    appendParticipant(&participants, &participant_count, .backend_handler, backend.id);
    if (ui) |node| appendParticipant(&participants, &participant_count, .ui_consumer, node.id);
    if (loader) |node| appendParticipant(&participants, &participant_count, .data_loader, node.id);
    if (focused_test) |node| appendParticipant(&participants, &participant_count, .focused_test, node.id);

    var direct_evidence: [10]model.SourceEvidence = @splat(.{
        .role = .frontend_invocation,
        .source_path = "",
        .span = .{ .start_byte = 0, .end_byte = 0, .start_line = 0, .start_column = 0, .end_line = 0, .end_column = 0 },
    });
    var evidence_count: usize = 0;
    appendEvidence(&direct_evidence, &evidence_count, .frontend_invocation, frontend_observation.source_path, modelSpan(frontend_observation.span));
    appendEvidence(&direct_evidence, &evidence_count, .client_binding, frontend_observation.source_path, modelSpan(frontend_observation.supporting_span));
    appendEvidence(&direct_evidence, &evidence_count, .canonical_contract, operation_entity.source_path, protobufSpan(operation_entity.span));
    appendEvidence(&direct_evidence, &evidence_count, .request_schema, request_entity.source_path, protobufSpan(request_entity.span));
    appendEvidence(&direct_evidence, &evidence_count, .response_schema, response_entity.source_path, protobufSpan(response_entity.span));
    appendEvidence(&direct_evidence, &evidence_count, .implementation_container, backend_observation.source_path, modelSpan(backend_observation.supporting_span));
    appendEvidence(&direct_evidence, &evidence_count, .backend_handler, backend_observation.source_path, modelSpan(backend_observation.span));
    if (ui) |node| if (typescriptDeclarationSpan(typescript, node.path, node.label)) |span| {
        appendEvidence(&direct_evidence, &evidence_count, .ui_consumer, node.path, typescriptModelSpan(span));
    };
    if (loader) |node| if (zigDeclarationSpan(zig, node.path, node.label)) |span| {
        appendEvidence(&direct_evidence, &evidence_count, .data_loader, node.path, zigModelSpan(span));
    };
    if (focused_test) |node| if (zigDeclarationSpan(zig, node.path, node.label)) |span| {
        appendEvidence(&direct_evidence, &evidence_count, .focused_test, node.path, zigModelSpan(span));
    };

    var members: [10]model.SupernodeMember = @splat(.{ .role = .ui_consumer, .node_id = 0, .reason = "" });
    var member_count: usize = 0;
    appendMember(&members, &member_count, .frontend_callsite, frontend.id, "resolved generated-client invocation");
    appendMember(&members, &member_count, .client_binding, client.id, "exact Connect client binding");
    appendMember(&members, &member_count, .canonical_operation, operation.id, "canonical Proto operation");
    appendMember(&members, &member_count, .request_message, request.id, "canonical request message");
    appendMember(&members, &member_count, .response_message, response.id, "canonical response message");
    appendMember(&members, &member_count, .implementation_container, implementation.id, "registered Zig implementation container");
    appendMember(&members, &member_count, .backend_handler, backend.id, "exact registered Zig handler");
    if (ui) |node| appendMember(&members, &member_count, .ui_consumer, node.id, "resolved frontend callback consumer");
    if (loader) |node| appendMember(&members, &member_count, .data_loader, node.id, "resolved backend data dependency");
    if (focused_test) |node| appendMember(&members, &member_count, .focused_test, node.id, "focused Zig test coverage");

    var proof_steps: [12]model.ProofStep = @splat(.{ .from = 0, .to = 0, .relation = .contains });
    var proof_count: usize = 0;
    if (ui) |node| appendProof(&proof_steps, &proof_count, node.id, frontend.id, .passes_callback);
    appendProof(&proof_steps, &proof_count, frontend.id, client.id, .calls);
    appendProof(&proof_steps, &proof_count, client.id, service.id, .generated_from);
    appendProof(&proof_steps, &proof_count, frontend.id, operation.id, .invokes_operation);
    appendProof(&proof_steps, &proof_count, operation.id, request.id, .uses_request);
    appendProof(&proof_steps, &proof_count, operation.id, response.id, .uses_response);
    appendProof(&proof_steps, &proof_count, implementation.id, backend.id, .declares);
    appendProof(&proof_steps, &proof_count, backend.id, operation.id, .handles_operation);
    if (loader) |node| appendProof(&proof_steps, &proof_count, backend.id, node.id, .calls);
    if (focused_test) |node| appendProof(&proof_steps, &proof_count, node.id, backend.id, .covers);

    const complete_feature = ui != null and loader != null and focused_test != null;
    const interaction_fingerprint = rpcInteractionFingerprint(
        interaction,
        participants[0..participant_count],
        direct_evidence[0..evidence_count],
        proof_steps[0..proof_count],
    );
    const feature_name = try std.fmt.allocPrint(graph.allocator, "{s} feature", .{interaction.canonical_operation});
    defer graph.allocator.free(feature_name);
    const synopsis = try std.fmt.allocPrint(graph.allocator, "Frontend invocation reaches the registered Zig handler through canonical operation {s} with request {s} and response {s}.", .{
        interaction.canonical_operation,
        interaction.request_type,
        interaction.response_type,
    });
    defer graph.allocator.free(synopsis);
    const materialized = try semantic_recipes.materializeRequestPath(graph, previous_graph, invalidations, .{
        .canonical_name = interaction.canonical_operation,
        .interaction_fingerprint = interaction_fingerprint,
        .participants = participants[0..participant_count],
        .evidence = direct_evidence[0..evidence_count],
        .feature_name = feature_name,
        .feature_synopsis = synopsis,
        .completeness = if (complete_feature) .end_to_end_feature else .contract_path,
        .members = members[0..member_count],
        .proof_steps = proof_steps[0..proof_count],
    });
    return .{
        .hyperedge_reused = materialized.hyperedge_reused,
        .supernode_reused = materialized.supernode_reused,
    };
}

fn appendParticipant(output: *[10]model.Participant, count: *usize, role: model.ParticipantRole, node_id: u64) void {
    output[count.*] = .{ .role = role, .node_id = node_id };
    count.* += 1;
}

fn appendEvidence(output: *[10]model.SourceEvidence, count: *usize, role: model.EvidenceRole, path: []const u8, span: model.SourceSpan) void {
    output[count.*] = .{ .role = role, .source_path = path, .span = span };
    count.* += 1;
}

fn appendMember(output: *[10]model.SupernodeMember, count: *usize, role: model.ParticipantRole, node_id: u64, reason: []const u8) void {
    output[count.*] = .{ .role = role, .node_id = node_id, .reason = reason };
    count.* += 1;
}

fn appendProof(output: *[12]model.ProofStep, count: *usize, from: u64, to: u64, relation: model.Relation) void {
    output[count.*] = .{ .from = from, .to = to, .relation = relation };
    count.* += 1;
}

fn uniqueIncomingNode(graph: *const model.RepositoryGraph, to: u64, relation: model.Relation) ?*const model.Node {
    var found: ?*const model.Node = null;
    for (graph.edges.items) |edge| {
        if (edge.to != to or edge.relation != relation) continue;
        const node = graph.findNode(edge.from) orelse continue;
        if (found != null and found.?.id != node.id) return null;
        found = node;
    }
    return found;
}

fn uniqueOutgoingNode(graph: *const model.RepositoryGraph, from: u64, relation: model.Relation) ?*const model.Node {
    var found: ?*const model.Node = null;
    for (graph.edges.items) |edge| {
        if (edge.from != from or edge.relation != relation) continue;
        const node = graph.findNode(edge.to) orelse continue;
        if (found != null and found.?.id != node.id) return null;
        found = node;
    }
    return found;
}

fn findUniqueProtobufEntityByCanonical(
    result: *const protobuf_resolution.Result,
    kind: protobuf_resolution.EntityKind,
    canonical_name: []const u8,
) ?*const protobuf_resolution.Entity {
    var found: ?*const protobuf_resolution.Entity = null;
    for (result.entities) |*entity| {
        if (entity.kind != kind or !std.mem.eql(u8, entity.canonical_name, canonical_name)) continue;
        if (found != null) return null;
        found = entity;
    }
    return found;
}

fn typescriptDeclarationSpan(corpus: *const typescript_symbols.Corpus, path: []const u8, name: []const u8) ?typescript_parser.Span {
    const parsed = corpus.parsedForPath(path) orelse return null;
    var found: ?typescript_parser.Span = null;
    for (parsed.declarations) |item| {
        if (!std.mem.eql(u8, item.name, name)) continue;
        if (found != null) return null;
        found = item.name_span;
    }
    return found;
}

fn zigDeclarationSpan(corpus: *const zig_resolution.Corpus, path: []const u8, name: []const u8) ?zig_parser.Span {
    const parsed = corpus.parsedForPath(path) orelse return null;
    var found: ?zig_parser.Span = null;
    for (parsed.declarations) |item| {
        if (!std.mem.eql(u8, item.name, name)) continue;
        if (found != null) return null;
        found = item.name_span;
    }
    return found;
}

fn modelSpan(span: rpc_continuity.SourceSpan) model.SourceSpan {
    return .{
        .start_byte = span.start_byte,
        .end_byte = span.end_byte,
        .start_line = span.start_line,
        .start_column = span.start_column,
        .end_line = span.end_line,
        .end_column = span.end_column,
    };
}

fn protobufSpan(span: anytype) model.SourceSpan {
    return .{
        .start_byte = span.start_byte,
        .end_byte = span.end_byte,
        .start_line = span.start_line,
        .start_column = span.start_column,
        .end_line = span.end_line,
        .end_column = span.end_column,
    };
}

fn typescriptModelSpan(span: typescript_parser.Span) model.SourceSpan {
    return protobufSpan(span);
}

fn zigModelSpan(span: zig_parser.Span) model.SourceSpan {
    return protobufSpan(span);
}

fn rpcInteractionFingerprint(
    interaction: *const rpc_continuity.Interaction,
    participants: []const model.Participant,
    evidence: []const model.SourceEvidence,
    proofs: []const model.ProofStep,
) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateInteractionBytes(&hasher, "rpc-interaction-local-v2");
    updateInteractionBytes(&hasher, semantic_recipes.findById(.rpc_request_path_v2).name);
    updateInteractionBytes(&hasher, semantic_recipes.findById(.end_to_end_feature_v2).name);
    updateInteractionBytes(&hasher, interaction.canonical_operation);
    updateInteractionBytes(&hasher, interaction.request_type);
    updateInteractionBytes(&hasher, interaction.response_type);
    inline for (std.meta.fields(model.ParticipantRole)) |field| {
        const role: model.ParticipantRole = @enumFromInt(field.value);
        for (participants) |participant| if (participant.role == role) {
            updateInteractionInt(&hasher, @intFromEnum(participant.role));
            updateInteractionInt(&hasher, participant.node_id);
        };
    }
    inline for (std.meta.fields(model.EvidenceRole)) |field| {
        const role: model.EvidenceRole = @enumFromInt(field.value);
        for (evidence) |item| if (item.role == role) {
            updateInteractionInt(&hasher, @intFromEnum(item.role));
            updateInteractionBytes(&hasher, item.source_path);
            updateInteractionSpan(&hasher, item.span);
        };
    }
    for (proofs) |proof| {
        updateInteractionInt(&hasher, proof.from);
        updateInteractionInt(&hasher, proof.to);
        updateInteractionInt(&hasher, @intFromEnum(proof.relation));
    }
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    return digest;
}

fn updateInteractionSpan(hasher: *std.crypto.hash.sha2.Sha256, span: model.SourceSpan) void {
    updateInteractionInt(hasher, span.start_byte);
    updateInteractionInt(hasher, span.end_byte);
    updateInteractionInt(hasher, span.start_line);
    updateInteractionInt(hasher, span.start_column);
    updateInteractionInt(hasher, span.end_line);
    updateInteractionInt(hasher, span.end_column);
}

fn updateInteractionBytes(hasher: *std.crypto.hash.sha2.Sha256, value: []const u8) void {
    updateInteractionInt(hasher, value.len);
    hasher.update(value);
}

fn updateInteractionInt(hasher: *std.crypto.hash.sha2.Sha256, value: anytype) void {
    var bytes: [8]u8 = @splat(0);
    std.mem.writeInt(u64, &bytes, @intCast(value), .little);
    hasher.update(&bytes);
}

fn findUniqueQualifiedZigSymbol(graph: *const model.RepositoryGraph, path: []const u8, qualified: []const u8) ?*const model.Node {
    const dot = std.mem.lastIndexOfScalar(u8, qualified, '.');
    const leaf = if (dot) |index| qualified[index + 1 ..] else qualified;
    var found: ?*const model.Node = null;
    for (graph.nodes.items) |*node| {
        if (node.kind != .symbol or !std.mem.eql(u8, node.path, path) or !std.mem.eql(u8, node.label, leaf)) continue;
        if (found != null) return null;
        found = node;
    }
    return found;
}

fn protobufNodeKind(kind: protobuf_resolution.EntityKind) model.NodeKind {
    return switch (kind) {
        .package => .package,
        .message => .message,
        .enumeration => .type,
        .service => .service,
        .operation => .operation,
        .field => .field,
        .enum_value => .symbol,
    };
}

fn generatedNodeKind(kind: generated_lineage.LinkKind) model.NodeKind {
    return switch (kind) {
        .file => .file,
        .message => .message,
        .enumeration => .type,
        .service => .service,
        .operation => .operation,
    };
}

fn protobufEntityNode(graph: *const model.RepositoryGraph, entity: *const protobuf_resolution.Entity) ?*const model.Node {
    return graph.findNode(model.stableId(protobufNodeKind(entity.kind), entity.source_path, entity.canonical_name));
}

fn packageEntityFor(result: *const protobuf_resolution.Result, source_path: []const u8) ?*const protobuf_resolution.Entity {
    for (result.entities, 0..) |entity, index| {
        if (entity.kind == .package and std.mem.eql(u8, entity.source_path, source_path)) return &result.entities[index];
    }
    return null;
}

fn findProtobufEntity(
    result: *const protobuf_resolution.Result,
    kind: protobuf_resolution.EntityKind,
    source_path: []const u8,
    canonical_name: []const u8,
) ?*const protobuf_resolution.Entity {
    for (result.entities, 0..) |entity, index| {
        if (entity.kind == kind and std.mem.eql(u8, entity.source_path, source_path) and
            std.mem.eql(u8, entity.canonical_name, canonical_name)) return &result.entities[index];
    }
    return null;
}

fn enumOwnerEntity(result: *const protobuf_resolution.Result, value: *const protobuf_resolution.Entity) ?*const protobuf_resolution.Entity {
    var found: ?*const protobuf_resolution.Entity = null;
    for (result.entities, 0..) |entity, index| {
        if (entity.kind != .enumeration or !std.mem.eql(u8, entity.source_path, value.source_path) or
            value.canonical_name.len <= entity.canonical_name.len or
            !std.mem.startsWith(u8, value.canonical_name, entity.canonical_name) or
            value.canonical_name[entity.canonical_name.len] != '.') continue;
        if (found == null or entity.canonical_name.len > found.?.canonical_name.len) found = &result.entities[index];
    }
    return found;
}

fn materializeZigResolutions(graph: *model.RepositoryGraph, result: *const zig_resolution.Result) !void {
    try zig_resolution.validate(result);
    for (result.resolutions) |resolution| {
        const caller = findByKindPathAndLabel(graph, .symbol, resolution.source_path, resolution.enclosing_declaration) orelse continue;
        const local_binding = findByKindPathAndLabel(graph, .concept, resolution.source_path, resolution.callee);
        const is_local_binding = if (local_binding) |binding| graph.hasEdge(caller.id, binding.id, .declares) else false;
        const candidates = result.candidatesFor(&resolution);
        if (is_local_binding) {
            for (candidates) |candidate| {
                const target = findByKindPathAndLabel(graph, .symbol, candidate.target_path, candidate.target_name) orelse continue;
                try graph.addEdge(.{
                    .from = local_binding.?.id,
                    .to = target.id,
                    .relation = .dispatches_to,
                    .provenance = if (resolution.status == .ambiguous) .ambiguous else .inferred,
                    .source_path = resolution.source_path,
                    .line = resolution.call_span.start_line,
                });
            }
            continue;
        }
        if (resolution.status != .resolved or candidates.len != 1) continue;
        const target = findByKindPathAndLabel(graph, .symbol, candidates[0].target_path, candidates[0].target_name) orelse continue;
        if (caller.id == target.id) continue;
        try graph.addEdge(.{
            .from = caller.id,
            .to = target.id,
            .relation = .calls,
            .provenance = .inferred,
            .source_path = resolution.source_path,
            .line = resolution.call_span.start_line,
        });
    }
}

fn materializeTypeScriptResolutions(graph: *model.RepositoryGraph, result: *const typescript_resolution.Result) !void {
    try typescript_resolution.validate(result);
    for (result.resolutions) |resolution| {
        const importer = findFileByPath(graph, resolution.source_path) orelse return error.MissingTypeScriptImporterNode;
        const importer_id = importer.id;
        const identity = try std.fmt.allocPrint(graph.allocator, "{s}@{d}:{s}", .{
            resolution.specifier,
            resolution.span.start_byte,
            @tagName(resolution.import_kind),
        });
        defer graph.allocator.free(identity);
        const search_text = try std.fmt.allocPrint(graph.allocator, "{s} {s} {s}", .{
            resolution.specifier,
            @tagName(resolution.import_kind),
            @tagName(resolution.status),
        });
        defer graph.allocator.free(search_text);
        const reference_id = try graph.addNode(.{
            .id = model.stableId(.module_reference, resolution.source_path, identity),
            .kind = .module_reference,
            .label = resolution.specifier,
            .path = resolution.source_path,
            .line = resolution.span.start_line,
            .search_text = search_text,
        });
        try graph.addEdge(.{
            .from = importer_id,
            .to = reference_id,
            .relation = if (resolution.import_kind == .dynamic) .deferred_imports else .imports,
            .provenance = .extracted,
            .source_path = resolution.source_path,
            .line = resolution.span.start_line,
        });
        for (result.candidatesFor(&resolution)) |candidate| {
            const target = findFileByPath(graph, candidate.target_path) orelse return error.MissingTypeScriptResolutionCandidateNode;
            try graph.addEdge(.{
                .from = reference_id,
                .to = target.id,
                .relation = .resolves_to,
                .provenance = if (resolution.status == .ambiguous) .ambiguous else .inferred,
                .source_path = resolution.source_path,
                .line = resolution.span.start_line,
            });
        }
        if (resolution.status == .external) {
            const external_path = try std.fmt.allocPrint(graph.allocator, "external/typescript/{s}", .{resolution.specifier});
            defer graph.allocator.free(external_path);
            const external_id = try graph.addNode(.{
                .kind = .external_module,
                .label = resolution.specifier,
                .path = external_path,
                .line = resolution.span.start_line,
                .search_text = resolution.specifier,
            });
            try graph.addEdge(.{
                .from = reference_id,
                .to = external_id,
                .relation = .resolves_to,
                .provenance = .inferred,
                .source_path = resolution.source_path,
                .line = resolution.span.start_line,
            });
        }
    }
}

fn materializeTypeScriptSymbols(graph: *model.RepositoryGraph, result: *const typescript_symbols.Result) !void {
    try typescript_symbols.validate(result);
    for (result.resolutions) |resolution| {
        const provenance: model.Provenance = if (resolution.status == .ambiguous) .ambiguous else .inferred;
        const resolved_candidates = result.candidatesFor(&resolution);
        switch (resolution.kind) {
            .import_binding => {
                const alias_id = try addTypeScriptAliasNode(graph, resolution, "import");
                const file = findFileByPath(graph, resolution.source_path) orelse return error.MissingTypeScriptSymbolSourceFile;
                try graph.addEdge(.{
                    .from = file.id,
                    .to = alias_id,
                    .relation = .declares,
                    .provenance = .extracted,
                    .source_path = resolution.source_path,
                    .line = resolution.span.start_line,
                });
                for (resolved_candidates) |candidate| {
                    const target_file = findFileByPath(graph, candidate.target_path) orelse continue;
                    try graph.addEdge(.{
                        .from = alias_id,
                        .to = target_file.id,
                        .relation = .imports_from,
                        .provenance = provenance,
                        .source_path = resolution.source_path,
                        .line = resolution.span.start_line,
                    });
                    if (std.mem.eql(u8, candidate.target_name, "*")) continue;
                    const target = findResolvedTypeScriptSymbol(graph, candidate.target_path, candidate.target_enclosing_declaration, candidate.target_name) orelse continue;
                    try graph.addEdge(.{
                        .from = alias_id,
                        .to = target.id,
                        .relation = .aliases,
                        .provenance = provenance,
                        .source_path = resolution.source_path,
                        .line = resolution.span.start_line,
                    });
                }
            },
            .export_binding => {
                const public_id = try addTypeScriptAliasNode(graph, resolution, "export");
                const file = findFileByPath(graph, resolution.source_path) orelse return error.MissingTypeScriptSymbolSourceFile;
                try graph.addEdge(.{
                    .from = file.id,
                    .to = public_id,
                    .relation = .declares,
                    .provenance = .extracted,
                    .source_path = resolution.source_path,
                    .line = resolution.span.start_line,
                });
                for (resolved_candidates) |candidate| {
                    const target = if (std.mem.eql(u8, candidate.target_name, "*"))
                        findFileByPath(graph, candidate.target_path)
                    else
                        findResolvedTypeScriptSymbol(graph, candidate.target_path, candidate.target_enclosing_declaration, candidate.target_name);
                    const target_node = target orelse continue;
                    try graph.addEdge(.{
                        .from = public_id,
                        .to = target_node.id,
                        .relation = .re_exports,
                        .provenance = provenance,
                        .source_path = resolution.source_path,
                        .line = resolution.span.start_line,
                    });
                    if (!std.mem.eql(u8, candidate.target_name, "*")) try graph.addEdge(.{
                        .from = public_id,
                        .to = target_node.id,
                        .relation = .aliases,
                        .provenance = provenance,
                        .source_path = resolution.source_path,
                        .line = resolution.span.start_line,
                    });
                }
            },
            .direct_call, .member_call, .constructor_call, .callback_reference => {
                const caller = findQualifiedTypeScriptSymbol(graph, resolution.source_path, resolution.enclosing_declaration) orelse continue;
                for (resolved_candidates) |candidate| {
                    if (std.mem.eql(u8, candidate.target_name, "*")) continue;
                    const target = findResolvedTypeScriptSymbol(graph, candidate.target_path, candidate.target_enclosing_declaration, candidate.target_name) orelse continue;
                    if (caller.id == target.id) continue;
                    try graph.addEdge(.{
                        .from = caller.id,
                        .to = target.id,
                        .relation = if (resolution.kind == .constructor_call)
                            .instantiates
                        else if (resolution.kind == .callback_reference)
                            .passes_callback
                        else
                            .calls,
                        .provenance = provenance,
                        .source_path = resolution.source_path,
                        .line = resolution.span.start_line,
                    });
                }
            },
        }
    }
}

fn addTypeScriptAliasNode(graph: *model.RepositoryGraph, resolution: typescript_symbols.Resolution, category: []const u8) !u64 {
    const identity = try std.fmt.allocPrint(graph.allocator, "{s}@{d}:{s}", .{ category, resolution.span.start_byte, resolution.subject });
    defer graph.allocator.free(identity);
    const scope = try std.fmt.allocPrint(graph.allocator, "{s}#{s}", .{ resolution.source_path, identity });
    defer graph.allocator.free(scope);
    const search_text = try std.fmt.allocPrint(graph.allocator, "{s} {s} {s}", .{ resolution.subject, category, @tagName(resolution.status) });
    defer graph.allocator.free(search_text);
    return graph.addNode(.{
        .id = model.stableId(.symbol, scope, resolution.subject),
        .kind = .symbol,
        .label = resolution.subject,
        .path = resolution.source_path,
        .line = resolution.span.start_line,
        .search_text = search_text,
    });
}

fn findResolvedTypeScriptSymbol(
    graph: *const model.RepositoryGraph,
    path: []const u8,
    enclosing_declaration: []const u8,
    name: []const u8,
) ?*const model.Node {
    if (enclosing_declaration.len == 0) return graph.findNode(model.stableId(.symbol, path, name));
    var scope_buffer: [std.fs.max_path_bytes + 4096]u8 = @splat(0);
    const scope = std.fmt.bufPrint(&scope_buffer, "{s}#{s}", .{ path, enclosing_declaration }) catch return null;
    return graph.findNode(model.stableId(.symbol, scope, name));
}

fn findQualifiedTypeScriptSymbol(graph: *const model.RepositoryGraph, path: []const u8, qualified_name: []const u8) ?*const model.Node {
    if (qualified_name.len == 0) return null;
    const separator = std.mem.lastIndexOfScalar(u8, qualified_name, '.');
    const owner = if (separator) |index| qualified_name[0..index] else "";
    const name = if (separator) |index| qualified_name[index + 1 ..] else qualified_name;
    return findResolvedTypeScriptSymbol(graph, path, owner, name);
}

fn isPlaced(disposition: discovery.Disposition) bool {
    return disposition == .deeply_indexed or disposition == .placed_unsupported or disposition == .placed_asset;
}

fn isTypeScriptResolutionDocument(path: []const u8) bool {
    const basename = std.fs.path.basename(path);
    return std.mem.eql(u8, basename, "package.json") or
        std.mem.eql(u8, basename, "pnpm-workspace.yaml") or
        std.mem.eql(u8, std.fs.path.extension(path), ".json");
}

fn typeScriptModeForPath(path: []const u8) ?typescript_parser.LanguageMode {
    const extension = std.fs.path.extension(path);
    if (std.mem.eql(u8, extension, ".tsx")) return .tsx;
    if (std.mem.eql(u8, extension, ".jsx")) return .jsx;
    if (std.mem.eql(u8, extension, ".ts") or std.mem.eql(u8, extension, ".mts") or std.mem.eql(u8, extension, ".cts")) return .typescript;
    if (std.mem.eql(u8, extension, ".js") or std.mem.eql(u8, extension, ".mjs") or std.mem.eql(u8, extension, ".cjs")) return .javascript;
    return null;
}

fn continuityLanguage(mode: typescript_parser.LanguageMode) ?rpc_continuity.Language {
    return switch (mode) {
        .typescript => .typescript,
        .tsx => .tsx,
        .javascript => .javascript,
        .jsx => .jsx,
        else => null,
    };
}
