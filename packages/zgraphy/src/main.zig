const std = @import("std");
const zgraphy = @import("zgraphy");
const zstd = @import("zigeffect_std");
const owned = zgraphy.Memory;

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var declared_commands = zgraphy.Application.CommandApplication.init(runCommand);
    const application = declared_commands.application();
    // The framework selects, opens, and owns the repository root after parse,
    // arity, and handler resolution, using only immutable parsed authority. No
    // eager raw-argv root scan or root open remains at this process boundary; the
    // opened directory is shared with the managed runtime and application layer
    // and closed exactly once after checked shutdown and graph flush.
    const resource_factory = zgraphy.Application.commandResources();
    const result = try zstd.Application.runOneShot(
        @TypeOf(resource_factory),
        @TypeOf(application),
        init.gpa,
        init.io,
        resource_factory,
        application,
        args[1..],
        .{ .runtime = .{ .graph = .{ .path = zgraphy.Application.causal_graph_path, .max_records = 4096, .max_wal_bytes = 16 * 1024 * 1024 } } },
    );
    if (result.exit_code != .success) std.process.exit(@intCast(@intFromEnum(result.exit_code)));
}

fn runCommand(ctx: *zstd.fx.kernel.ContextView(zgraphy.Application.ApplicationServices), command_line: zstd.Cli.ParsedCommand) anyerror!void {
    const inputs = ctx.service(zgraphy.Application.ApplicationInputs);
    try dispatch(ctx.allocator(), inputs.io, inputs.root, command_line);
}

/// Command, subcommand, positional, and option authority is the resolved
/// `ParsedCommand`. Raw argv is never re-scanned here to select or feed a
/// command, so the executed handler cannot diverge from the parsed identity the
/// framework records. Root selection is likewise parsed-only and owned by the
/// framework's resource factory (`zgraphy.Application.selectRoot`); no raw-argv
/// root scan remains in this process.
fn dispatch(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, command_line: zstd.Cli.ParsedCommand) !void {
    const command = command_line.path[1];
    if (std.mem.eql(u8, command, "init")) return runInit(allocator, io, root, jsonRequested(command_line));
    if (std.mem.eql(u8, command, "build") or std.mem.eql(u8, command, "ingest")) return runBuild(allocator, io, root, jsonRequested(command_line));
    if (std.mem.eql(u8, command, "status")) return runStatus(allocator, io, root, jsonRequested(command_line));
    if (std.mem.eql(u8, command, "doctor")) return runDoctor(allocator, io, root, jsonRequested(command_line));
    if (std.mem.eql(u8, command, "watch")) return runWatch(allocator, io, root, command_line);
    if (std.mem.eql(u8, command, "gc")) return runGc(allocator, io, root, command_line);
    if (std.mem.eql(u8, command, "pin")) return runGenerationPin(allocator, io, root, command_line, true);
    if (std.mem.eql(u8, command, "unpin")) return runGenerationPin(allocator, io, root, command_line, false);
    if (std.mem.eql(u8, command, "query")) return runQuery(allocator, io, root, command_line);
    if (std.mem.eql(u8, command, "explain")) return runExplain(allocator, io, root, command_line);
    if (std.mem.eql(u8, command, "path")) return runPath(allocator, io, root, command_line);
    if (std.mem.eql(u8, command, "parity")) return runParity(allocator, io, jsonRequested(command_line));
    if (std.mem.eql(u8, command, "schema")) return runSemanticSchema(allocator, io, command_line);
    if (std.mem.eql(u8, command, "contracts")) return runOperationalContracts(allocator, io, command_line);
    if (std.mem.eql(u8, command, "security")) return runSecurityBaseline(allocator, io, command_line);
    if (std.mem.eql(u8, command, "evaluation")) return runEvaluationContracts(allocator, io, command_line);
    if (std.mem.eql(u8, command, "benchmark")) return runBenchmark(allocator, io, root, command_line);
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
    var managed = try zgraphy.Operations.updateManaged(allocator, io, root, config.value, .{});
    defer managed.deinit();
    var reader = try zgraphy.Operations.GenerationReadLease.acquireShared(io, root);
    defer reader.deinit();
    var active = try zgraphy.Operations.readActiveGeneration(allocator, io, root, config.value);
    defer active.deinit();
    if (json) return writeJson(io, allocator, .{
        .schema = "zgraphy.build.v9",
        .status = "complete",
        .update_kind = @tagName(managed.kind),
        .database = managed.publication.database,
        .generation = managed.publication.generation,
        .refresh = refreshView(&managed.publication),
        .summary = managed.summary,
        .secondary_index_schema = zgraphy.Nendb.secondary_index_schema,
        .secondary_index_fingerprint = active.value.secondary_index_fingerprint,
        .secondary_indexes = active.value.secondary_indexes,
        .delta = .{
            .schema = active.value.delta_schema,
            .journal = active.value.delta_journal,
            .fingerprint = active.value.delta_fingerprint,
            .summary = active.value.delta_summary,
        },
        .repository_context = .{
            .schema = zgraphy.RepositoryContext.schema,
            .artifact = active.value.repository_context,
            .fingerprint = active.value.repository_context_fingerprint,
        },
        .change_lineage = .{
            .schema = zgraphy.ChangeLineage.schema,
            .artifact = active.value.change_lineage,
            .input_fingerprint = active.value.change_lineage_input_fingerprint,
            .fingerprint = active.value.change_lineage_fingerprint,
            .summary = active.value.change_lineage_summary,
        },
        .origin = .{
            .schema = zgraphy.OriginLedger.schema,
            .artifact = active.value.origin_ledger,
            .input_fingerprint = active.value.origin_input_fingerprint,
            .fingerprint = active.value.origin_fingerprint,
            .summary = active.value.origin_summary,
        },
        .repair = .{
            .schema = zgraphy.Repair.schema,
            .artifact = active.value.repair_report,
            .replaces_generation = active.value.replaces_generation,
            .plan_fingerprint = active.value.repair_plan_fingerprint,
            .fingerprint = active.value.repair_fingerprint,
            .summary = active.value.repair_summary,
        },
        .retention = managed.publication.retention,
    });
    return writeText(io, allocator, "built {d} nodes, {d} edges, {d} vectors, {d} request paths, {d} feature supernodes from {d} files ({d} reparsed, {d} cache hits, derived {d}/{d} reused, {d} lexical terms) -> {s} ({s})\n", .{
        managed.summary.nodes,
        managed.summary.edges,
        managed.summary.vectors,
        managed.summary.request_paths,
        managed.summary.feature_supernodes,
        managed.summary.files_indexed,
        managed.publication.reparsed_files,
        managed.publication.cache_hits,
        managed.summary.derived_hyperedges_reused,
        managed.summary.derived_supernodes_reused,
        active.value.secondary_indexes.lexical_terms,
        managed.publication.database,
        managed.publication.generation,
    });
}

fn runGc(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, command_line: zstd.Cli.ParsedCommand) !void {
    var config = try zgraphy.Project.loadConfig(allocator, io, root);
    defer config.deinit();
    var report = try zgraphy.Operations.collectGarbage(
        allocator,
        io,
        root,
        config.value,
        if (command_line.optionValue("apply") != null) .apply else .dry_run,
    );
    defer report.deinit();
    if (jsonRequested(command_line)) {
        const fingerprint = std.fmt.bytesToHex(report.plan_fingerprint, .lower);
        return writeJson(io, allocator, .{
            .schema = zgraphy.Retention.schema,
            .schema_version = zgraphy.Retention.schema_version,
            .repository_id = report.repository_id,
            .active_generation = report.active_generation,
            .plan_fingerprint = fingerprint[0..],
            .summary = report.summary,
            .actions = report.actions,
            .complete = true,
        });
    }
    return writeText(io, allocator, "gc {s}: {d} generation and {d} cache candidates; deleted {d}/{d}; {d} failures\n", .{
        @tagName(report.summary.status),
        report.summary.generation_candidates,
        report.summary.cache_candidates,
        report.summary.generations_deleted,
        report.summary.cache_entries_deleted,
        report.summary.failed_actions,
    });
}

fn runGenerationPin(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, command_line: zstd.Cli.ParsedCommand, present: bool) !void {
    const generation = command_line.positional(0) orelse return error.MissingGeneration;
    var config = try zgraphy.Project.loadConfig(allocator, io, root);
    defer config.deinit();
    if (present) {
        try zgraphy.Operations.pinGeneration(allocator, io, root, config.value, generation);
    } else {
        try zgraphy.Operations.unpinGeneration(allocator, io, root, config.value, generation);
    }
    if (jsonRequested(command_line)) return writeJson(io, allocator, .{
        .schema = zgraphy.Retention.pins_schema,
        .schema_version = zgraphy.Retention.schema_version,
        .status = if (present) "pinned" else "unpinned",
        .generation = generation,
    });
    return writeText(io, allocator, "{s} {s}\n", .{ if (present) "pinned" else "unpinned", generation });
}

fn runWatch(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, command_line: zstd.Cli.ParsedCommand) !void {
    var config = try zgraphy.Project.loadConfig(allocator, io, root);
    defer config.deinit();
    const max_cycles = try optionalNumericOptionOf(command_line, "max-cycles", 1, 1_000_000_000);
    const summary = try zgraphy.Watch.runForeground(allocator, io, root, config.value, .{
        .poll_ms = try numericOptionOf(command_line, "poll-ms", 250, 1, 60_000),
        .debounce_ms = try numericOptionOf(command_line, "debounce-ms", 250, 1, 60_000),
        .retry_ms = try numericOptionOf(command_line, "retry-ms", 100, 1, 60_000),
        .max_cycles = max_cycles,
        .max_drain_passes = try numericOptionOf(command_line, "max-drain-passes", 20, 1, 256),
    });
    if (jsonRequested(command_line)) return writeJson(io, allocator, summary);
    return writeText(io, allocator, "watch {s}: {d} cycles, {d} changes, {d} refreshed, {d} current, {d} contentions, {d} pending requests\n", .{
        @tagName(summary.state),
        summary.cycles,
        summary.observation_changes,
        summary.refreshed,
        summary.current,
        summary.contentions,
        summary.pending_requests,
    });
}

fn runDoctor(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, json: bool) !void {
    var config = try zgraphy.Project.loadConfig(allocator, io, root);
    defer config.deinit();
    var report = try zgraphy.Operations.doctor(allocator, io, root, config.value);
    const pending = zgraphy.Watch.inspectPending(allocator, io, root, config.value.repository_id);
    const pending_fingerprint = std.fmt.bytesToHex(pending.fingerprint, .lower);
    const watch = zgraphy.Operations.WatchDoctorView{
        .status = switch (pending.status) {
            .empty => .empty,
            .ready => .ready,
            .corrupt => .corrupt,
            .unavailable => .unavailable,
        },
        .pending_requests = pending.pending_requests,
        .pending_hints = pending.pending_hints,
        .fingerprint = if (pending.has_fingerprint) pending_fingerprint[0..] else "",
        .repair_hint = pending.repair_hint,
    };
    if (json) {
        const encoded = try zgraphy.Operations.encodeDoctorWithWatchAlloc(allocator, config.value, &report, watch);
        defer allocator.free(encoded);
        try std.Io.File.stdout().writeStreamingAll(io, encoded);
        return std.Io.File.stdout().writeStreamingAll(io, "\n");
    }
    return writeText(io, allocator, "{s}: {d} nodes, {d} edges, {d} vectors, {d} diagnostics, watch queue {s} ({d} requests)\n", .{
        if (pending.status == .corrupt) "corrupt" else if (pending.status == .unavailable) "degraded" else @tagName(report.status),
        report.nodes,
        report.edges,
        report.vectors,
        report.diagnostics().len,
        @tagName(pending.status),
        pending.pending_requests,
    });
}

fn runStatus(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, json: bool) !void {
    var loaded = try loadGraph(allocator, io, root);
    defer loaded.deinit();
    var config = try zgraphy.Project.loadConfig(allocator, io, root);
    defer config.deinit();
    var reader = try zgraphy.Operations.GenerationReadLease.acquireShared(io, root);
    defer reader.deinit();
    var active = try zgraphy.Operations.readActiveGeneration(allocator, io, root, config.value);
    defer active.deinit();
    if (!std.mem.eql(u8, active.value.generation, loaded.refresh.generation)) return error.ActiveGenerationChanged;
    var repository_context = try zgraphy.RepositoryContext.read(allocator, io, root, active.value.repository_context);
    defer repository_context.deinit();
    var change_lineage = try zgraphy.ChangeLineage.read(allocator, io, root, active.value.change_lineage);
    defer change_lineage.deinit();
    const pending = zgraphy.Watch.inspectPending(allocator, io, root, config.value.repository_id);
    const pending_fingerprint = std.fmt.bytesToHex(pending.fingerprint, .lower);
    const stats = loaded.graph.topology.stats();
    const secondary_index_fingerprint = try loaded.graph.secondaryIndexFingerprint(allocator);
    const secondary_index_hex = std.fmt.bytesToHex(secondary_index_fingerprint, .lower);
    const status_label = switch (pending.status) {
        .corrupt, .unavailable => "degraded",
        .empty, .ready => "ready",
    };
    if (json) return writeJson(io, allocator, .{
        .schema = "zgraphy.status.v9",
        .status = status_label,
        .database = loaded.refresh.database,
        .generation = loaded.refresh.generation,
        .refresh = refreshView(&loaded.refresh),
        .freshness_capabilities = zgraphy.Freshness.Capabilities.currentM3_8(),
        .retention = loaded.refresh.retention,
        .watch = .{
            .statechart_id = "zgraphy.watch-coordinator",
            .statechart_version = 1,
            .queue_status = pending.status,
            .pending_requests = pending.pending_requests,
            .pending_hints = pending.pending_hints,
            .pending_fingerprint = if (pending.has_fingerprint) pending_fingerprint[0..] else "",
            .repair_hint = pending.repair_hint,
            .process_liveness = "unclaimed",
        },
        .recovery_source = loaded.recovery_source,
        .delta = .{
            .schema = zgraphy.DeltaJournal.schema,
            .journal = loaded.refresh.delta_journal,
            .fingerprint = loaded.refresh.delta_fingerprint,
            .summary = loaded.refresh.delta_summary,
        },
        .repository_context = repository_context.value,
        .change_lineage = .{
            .schema = zgraphy.ChangeLineage.schema,
            .artifact = active.value.change_lineage,
            .input_fingerprint = change_lineage.value.input_fingerprint,
            .fingerprint = change_lineage.value.fingerprint,
            .summary = change_lineage.value.summary,
        },
        .origin = .{
            .schema = zgraphy.OriginLedger.schema,
            .artifact = active.value.origin_ledger,
            .input_fingerprint = active.value.origin_input_fingerprint,
            .fingerprint = active.value.origin_fingerprint,
            .summary = active.value.origin_summary,
        },
        .repair = .{
            .schema = zgraphy.Repair.schema,
            .artifact = active.value.repair_report,
            .replaces_generation = active.value.replaces_generation,
            .plan_fingerprint = active.value.repair_plan_fingerprint,
            .fingerprint = active.value.repair_fingerprint,
            .summary = active.value.repair_summary,
        },
        .stats = stats,
        .secondary_index_schema = zgraphy.Nendb.secondary_index_schema,
        .secondary_index_fingerprint = &secondary_index_hex,
        .secondary_indexes = loaded.graph.secondaryIndexStats(),
        .semantic = .{
            .hyperedges = loaded.graph.hyperedgeCount(),
            .supernodes = loaded.graph.supernodeCount(),
        },
    });
    return writeText(io, allocator, "{s}: {d} nodes, {d} edges, {d} vectors, {d} hyperedges, {d} supernodes ({s}, {s}, generation {s}, refresh {s}, watch queue {s}/{d})\n", .{
        status_label,
        stats.node_count,
        stats.edge_count,
        stats.vector_count,
        loaded.graph.hyperedgeCount(),
        loaded.graph.supernodeCount(),
        stats.engine,
        stats.embedder_name,
        loaded.refresh.generation,
        @tagName(loaded.refresh.status),
        @tagName(pending.status),
        pending.pending_requests,
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

fn runSemanticSchema(allocator: std.mem.Allocator, io: std.Io, command_line: zstd.Cli.ParsedCommand) !void {
    var parsed = try zgraphy.SemanticSchema.parseEmbedded(allocator);
    defer parsed.deinit();
    try zgraphy.SemanticSchema.validate(&parsed.value);
    const digest = zgraphy.SemanticSchema.contractDigest();
    const digest_hex = std.fmt.bytesToHex(digest, .lower);

    if (command_line.positional(0)) |relation_name| {
        const relation = try zgraphy.SemanticSchema.resolveRelation(&parsed.value, relation_name);
        if (jsonRequested(command_line)) return writeJson(io, allocator, .{
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

    if (jsonRequested(command_line)) return writeJson(io, allocator, .{
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

fn runOperationalContracts(allocator: std.mem.Allocator, io: std.Io, command_line: zstd.Cli.ParsedCommand) !void {
    var parsed = try zgraphy.OperationalContracts.parseEmbedded(allocator);
    defer parsed.deinit();
    try zgraphy.OperationalContracts.validate(&parsed.value);
    const digest = zgraphy.OperationalContracts.contractDigest();
    const digest_hex = std.fmt.bytesToHex(digest, .lower);

    if (command_line.positional(0)) |section| {
        if (std.mem.eql(u8, section, "provider")) return writeJson(io, allocator, .{ .contract_digest = digest_hex, .provider = parsed.value.provider });
        if (std.mem.eql(u8, section, "conformance")) return writeJson(io, allocator, .{ .contract_digest = digest_hex, .conformance = parsed.value.conformance });
        if (std.mem.eql(u8, section, "config")) return writeJson(io, allocator, .{ .contract_digest = digest_hex, .config = parsed.value.config });
        if (std.mem.eql(u8, section, "health")) return writeJson(io, allocator, .{ .contract_digest = digest_hex, .health = parsed.value.health });
        if (std.mem.eql(u8, section, "diagnostic")) return writeJson(io, allocator, .{ .contract_digest = digest_hex, .diagnostic = parsed.value.diagnostic });
        if (std.mem.eql(u8, section, "migration")) return writeJson(io, allocator, .{ .contract_digest = digest_hex, .migration = parsed.value.migration });
        return error.UnknownOperationalContract;
    }

    if (jsonRequested(command_line)) return writeJson(io, allocator, .{
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

fn runSecurityBaseline(allocator: std.mem.Allocator, io: std.Io, command_line: zstd.Cli.ParsedCommand) !void {
    var parsed = try zgraphy.SecurityBaseline.parseEmbedded(allocator);
    defer parsed.deinit();
    try zgraphy.SecurityBaseline.validate(&parsed.value);
    const digest = zgraphy.SecurityBaseline.catalogDigest();
    const digest_hex = std.fmt.bytesToHex(digest, .lower);

    if (command_line.positional(0)) |threat_id| {
        const threat = zgraphy.SecurityBaseline.findThreat(&parsed.value, threat_id) orelse return error.UnknownSecurityThreat;
        return writeJson(io, allocator, .{
            .schema = "zgraphy.security-threat.v1",
            .catalog_digest = digest_hex,
            .threat = threat,
        });
    }

    const summary = zgraphy.SecurityBaseline.summarize(&parsed.value);
    if (jsonRequested(command_line)) return writeJson(io, allocator, .{
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

fn runEvaluationContracts(allocator: std.mem.Allocator, io: std.Io, command_line: zstd.Cli.ParsedCommand) !void {
    var parsed = try zgraphy.EvaluationContracts.parseEmbedded(allocator);
    defer parsed.deinit();
    try zgraphy.EvaluationContracts.validate(&parsed.value);
    const digest = zgraphy.EvaluationContracts.contractDigest();
    const digest_hex = std.fmt.bytesToHex(digest, .lower);

    if (command_line.positional(0)) |kind_name| {
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
    if (jsonRequested(command_line)) return writeJson(io, allocator, .{
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

fn runBenchmark(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, command_line: zstd.Cli.ParsedCommand) !void {
    // The benchmark leaf and its arguments come from the resolved command; the
    // framework already selected the default `corpus` leaf when none was given.
    const subcommand = command_line.command;
    var corpus = try zgraphy.Benchmark.parseEmbeddedCorpus(allocator);
    defer corpus.deinit();
    try zgraphy.Benchmark.validateCorpus(&corpus.value);
    if (std.mem.eql(u8, subcommand, "workload")) {
        return runBenchmarkWorkload(allocator, io, root, command_line, &corpus.value);
    }
    if (std.mem.eql(u8, subcommand, "resources")) {
        return runResourceMatrix(allocator, io, root, command_line);
    }
    if (std.mem.eql(u8, subcommand, "freshness")) {
        return runFreshnessReceipt(allocator, io, root, command_line);
    }
    if (std.mem.eql(u8, subcommand, "churn")) {
        return runM3ChurnReceipt(allocator, io, root, command_line);
    }
    if (std.mem.eql(u8, subcommand, "performance")) {
        return runM3PerformanceReceipt(allocator, io, root, command_line);
    }
    if (std.mem.eql(u8, subcommand, "matrix")) {
        return runQualityMatrix(allocator, io, root, command_line, &corpus.value);
    }
    if (std.mem.eql(u8, subcommand, "lexical")) {
        const fixture_id = command_line.positional(0) orelse return error.MissingBenchmarkFixture;
        const fixture = zgraphy.Benchmark.findFixture(&corpus.value, fixture_id) orelse return error.UnknownBenchmarkFixture;
        const fixture_root = command_line.positional(1) orelse fixture.scan_root;
        var fixture_dir = try root.openDir(io, fixture_root, .{ .iterate = true, .follow_symlinks = false });
        defer fixture_dir.close(io);
        var graph = try zgraphy.Lexical.build(allocator, io, fixture_dir, .{});
        defer graph.deinit();
        var gold = try zgraphy.Benchmark.parseEmbeddedGold(allocator, fixture.gold);
        defer gold.deinit();
        var receipt = try zgraphy.Differential.projectLexical(allocator, &graph, &gold.value);
        defer receipt.deinit(allocator);
        try zgraphy.Differential.validateReceipt(&receipt);
        if (jsonRequested(command_line)) return writeJson(io, allocator, receipt);
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
        const fixture_id = command_line.positional(0) orelse return error.MissingBenchmarkFixture;
        const fixture = zgraphy.Benchmark.findFixture(&corpus.value, fixture_id) orelse return error.UnknownBenchmarkFixture;
        const fixture_root = command_line.positional(1) orelse fixture.scan_root;
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
        if (jsonRequested(command_line)) return writeJson(io, allocator, receipt);
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
        const fixture_id = command_line.positional(0) orelse return error.MissingBenchmarkFixture;
        const graph_path = command_line.positional(1) orelse return error.MissingBenchmarkGraph;
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
        if (jsonRequested(command_line)) return writeJson(io, allocator, receipt);
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
    if (jsonRequested(command_line)) return writeJson(io, allocator, .{
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

fn runM3ChurnReceipt(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, command_line: zstd.Cli.ParsedCommand) !void {
    const observation_path = command_line.positional(0) orelse return error.MissingChurnObservations;
    const bytes = try root.readFileAlloc(io, observation_path, allocator, .limited(zgraphy.M3Qualification.max_churn_observation_bytes));
    defer allocator.free(bytes);
    var parsed = try zgraphy.M3Qualification.parseChurnObservationFile(allocator, bytes);
    defer parsed.deinit();
    var receipt = try zgraphy.M3Qualification.buildChurn(
        allocator,
        parsed.value.identity,
        parsed.value.budgets,
        parsed.value.transitions,
    );
    defer receipt.deinit(allocator);
    try zgraphy.M3Qualification.validateChurn(&receipt);
    if (jsonRequested(command_line)) return writeJson(io, allocator, receipt);
    return writeText(io, allocator, "M3 churn: {d} transitions, {d} operation kinds, peak {d} generations/{d} cache entries, deleted {d} generations, reader deferrals {d}, repairs {d}, gate {s}\n", .{
        receipt.summary.transitions,
        receipt.summary.operation_kinds,
        receipt.summary.peak_generations,
        receipt.summary.peak_cache_entries,
        receipt.summary.gc_generations_deleted,
        receipt.summary.reader_deferrals,
        receipt.summary.repairs,
        if (receipt.churn_gate_passed) "passed" else "failed",
    });
}

fn runM3PerformanceReceipt(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, command_line: zstd.Cli.ParsedCommand) !void {
    const sample_path = command_line.positional(0) orelse return error.MissingPerformanceSamples;
    const source_revision = try requiredStringOptionOf(command_line, "source-revision");
    const machine_digest = try requiredStringOptionOf(command_line, "machine");
    const configuration_digest = try requiredStringOptionOf(command_line, "configuration");
    const correctness_digest = try requiredStringOptionOf(command_line, "correctness");
    const quality_digest = try requiredStringOptionOf(command_line, "quality");
    const resource_digest = try requiredStringOptionOf(command_line, "resources");
    const graphify_python = try requiredStringOptionOf(command_line, "graphify-python");
    const graphify_environment = try requiredStringOptionOf(command_line, "graphify-environment");
    const warmups: u16 = @intCast(try numericOptionOf(command_line, "warmups", 2, 1, zgraphy.M3Qualification.max_repetitions));
    const repetitions: u16 = @intCast(try numericOptionOf(command_line, "repetitions", 7, zgraphy.M3Qualification.min_repetitions, zgraphy.M3Qualification.max_repetitions));
    const bytes = try root.readFileAlloc(io, sample_path, allocator, .limited(zgraphy.M3Qualification.max_performance_sample_bytes));
    defer allocator.free(bytes);
    var parsed = try zgraphy.M3Qualification.parsePerformanceSampleFile(allocator, bytes);
    defer parsed.deinit();
    const identity = parsed.value.identity;
    if (!std.mem.eql(u8, identity.source_revision, source_revision) or
        !std.mem.eql(u8, identity.machine_digest, machine_digest) or
        !std.mem.eql(u8, identity.configuration_digest, configuration_digest) or
        !std.mem.eql(u8, identity.correctness_digest, correctness_digest) or
        !std.mem.eql(u8, identity.quality_matrix_digest, quality_digest) or
        !std.mem.eql(u8, identity.resource_matrix_digest, resource_digest) or
        !std.mem.eql(u8, identity.graphify_python, graphify_python) or
        !std.mem.eql(u8, identity.graphify_environment_digest, graphify_environment) or
        parsed.value.sampling.warmups != warmups or parsed.value.sampling.repetitions != repetitions)
    {
        return error.PerformanceIdentityOptionMismatch;
    }
    var receipt = try zgraphy.M3Qualification.buildPerformance(
        allocator,
        identity,
        parsed.value.sampling,
        parsed.value.targets,
        parsed.value.samples,
    );
    defer receipt.deinit(allocator);
    try zgraphy.M3Qualification.validatePerformance(&receipt);
    if (jsonRequested(command_line)) return writeJson(io, allocator, receipt);
    return writeText(io, allocator, "M3 one-file comparison: speedup {d} bp (target {d}), RSS ratio {d} bp (max {d}), persisted ratio {d} bp, claim {s}\n", .{
        receipt.comparison.speedup_basis_points,
        receipt.targets.minimum_speedup_basis_points,
        receipt.comparison.rss_ratio_basis_points,
        receipt.targets.maximum_rss_ratio_basis_points,
        receipt.comparison.persisted_ratio_basis_points,
        if (receipt.performance_gate_passed) "earned" else "withheld",
    });
}

fn runFreshnessReceipt(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, command_line: zstd.Cli.ParsedCommand) !void {
    const transition_path = command_line.positional(0) orelse return error.MissingFreshnessTransitions;
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
    if (jsonRequested(command_line)) return writeJson(io, allocator, receipt);
    return writeText(io, allocator, "freshness baseline: {d} full rebuild transitions, gate {s}, incremental {s}, pre-query refresh {s}\n", .{
        receipt.transitions.len,
        if (receipt.freshness_gate_passed) "passed" else "failed",
        @tagName(receipt.capabilities.incremental_update),
        @tagName(receipt.capabilities.pre_query_refresh),
    });
}

fn runResourceMatrix(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, command_line: zstd.Cli.ParsedCommand) !void {
    const sample_path = command_line.positional(0) orelse return error.MissingResourceSamples;
    const source_revision = try requiredStringOptionOf(command_line, "source-revision");
    const graphify_python = try requiredStringOptionOf(command_line, "graphify-python");
    const graphify_environment = try requiredStringOptionOf(command_line, "graphify-environment");
    const machine_digest = try requiredStringOptionOf(command_line, "machine");
    const configuration_digest = try requiredStringOptionOf(command_line, "configuration");
    const warmups: u16 = @intCast(try numericOptionOf(command_line, "warmups", 2, 1, zgraphy.ResourceMatrix.max_repetitions));
    const repetitions: u16 = @intCast(try numericOptionOf(command_line, "repetitions", 7, 7, zgraphy.ResourceMatrix.max_repetitions));
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
    if (jsonRequested(command_line)) return writeJson(io, allocator, receipt);
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
    command_line: zstd.Cli.ParsedCommand,
    corpus: *const zgraphy.Benchmark.Corpus,
) !void {
    const fixture_id = command_line.positional(0) orelse return error.MissingBenchmarkFixture;
    const workload_name = command_line.positional(1) orelse return error.MissingBenchmarkWorkload;
    const workload = parseWorkload(workload_name) orelse return error.InvalidBenchmarkWorkload;
    // one_file_modify, rename and delete name incremental workloads and this
    // function mutates nothing: the timed region below is a full
    // Indexer.buildRepository for every variant, so all four would report the
    // same cold-build number under four different labels. Measuring them would
    // be worse than not measuring them, because the output looks like a result.
    //
    // They also cannot be fixed here by adding mutations alone. buildRepository
    // with default options runs with extraction_cache_options disabled
    // (extraction_cache.zig defaults `enabled` to false), so a rebuild through
    // this path is a full reparse whatever changed. A real incremental
    // measurement has to drive Operations.updateManaged against a mutated
    // working copy, which is a different harness.
    //
    // Refused by name until that exists, following bounded_query's precedent.
    // Measured manually in the meantime and recorded in the master roadmap:
    // on 173 files, cold 3,148ms, one-file edit 64ms, unchanged rebuild ~2,000ms.
    switch (workload) {
        .bounded_query, .one_file_modify, .rename, .delete => return error.UnsupportedBenchmarkWorkload,
        .cold_build, .warm_unchanged_build => {},
    }
    const fixture = zgraphy.Benchmark.findFixture(corpus, fixture_id) orelse return error.UnknownBenchmarkFixture;
    const fixture_root = command_line.positional(2) orelse fixture.scan_root;

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
    if (jsonRequested(command_line)) return writeJson(io, allocator, observation);
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
    command_line: zstd.Cli.ParsedCommand,
    corpus: *const zgraphy.Benchmark.Corpus,
) !void {
    const graphify_root = command_line.positional(0) orelse ".zgraphy/benchmarks/runs/graphify";
    const source_revision = try requiredStringOptionOf(command_line, "source-revision");
    const graphify_python = try requiredStringOptionOf(command_line, "graphify-python");
    const graphify_environment = try requiredStringOptionOf(command_line, "graphify-environment");
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
    if (jsonRequested(command_line)) return writeJson(io, allocator, matrix);

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

fn runQuery(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, command_line: zstd.Cli.ParsedCommand) !void {
    const query = command_line.positional(0) orelse return error.MissingQuery;
    const limit = try numericOptionOf(command_line, "limit", 10, 1, 1024);
    const budget_tokens = try numericOptionOf(command_line, "budget", 2000, 64, 200_000);
    const budget_chars = budget_tokens * 3;
    var loaded = try openGraph(allocator, io, root);
    defer loaded.deinit();
    var results = try zgraphy.Search.queryAlloc(allocator, &loaded.graph, query, .{ .limit = limit });
    defer results.deinit();
    if (jsonRequested(command_line)) {
        const views = try owned.slice(ResultView, allocator, results.items.len);
        defer allocator.free(views);
        for (results.items, 0..) |result, index| views[index] = resultView(&loaded.graph, result);
        return writeJson(io, allocator, .{
            .schema = "zgraphy.query.v4",
            .query = query,
            .embedder = results.embedder,
            .generation = loaded.refresh.generation,
            .refresh = refreshView(&loaded.refresh),
            .tree_verified = loaded.refresh.tree_verified,
            .confidence = @tagName(results.confidence),
            .confidence_reason = results.confidence_reason,
            .scanned = results.scanned,
            .corpus = results.corpus,
            .results = views,
        });
    }
    // Rows are bounded by a token budget, not only by --limit. `limit` bounds a
    // count, and a count says nothing about what it costs the reader: ten rows
    // of one symbol each and ten rows carrying source are wildly different
    // answers. Tokens are the scarce resource, so tokens are the unit.
    //
    // Three characters per token is graphify's approximation and is close enough
    // for text this shape. Applied now, while a row is one line, because the
    // render grows source and edges in C9 and a bound added afterwards is a
    // bound nobody trusts.
    var spent_chars: usize = 0;
    var cut: usize = 0;
    for (results.items) |result| {
        const node = loaded.graph.findNode(result.node_id).?;
        if (spent_chars >= budget_chars) {
            cut += 1;
            continue;
        }
        spent_chars += node.label.len + node.path.len + 64;
        var label_buffer: zgraphy.Sanitize.Buffer = undefined;
        var path_buffer: zgraphy.Sanitize.Buffer = undefined;
        try writeText(io, allocator, "{s} [{s}] {s}:{d} score={d:.3} keyword={d:.3} vector={d:.3} graph={d:.3}\n", .{
            zgraphy.Sanitize.clean(&label_buffer, node.label),
            @tagName(node.kind),
            zgraphy.Sanitize.clean(&path_buffer, node.path),
            node.line,
            result.score,
            result.keyword_score,
            result.vector_score,
            result.graph_score,
        });
    }
    // Say it last, where a reader who skimmed the rows still sees it. A ranking
    // is normalised, so the best of a bad set still scores 1.000 — the number
    // cannot carry this and silence reads as endorsement.
    // Name the next move. A truncation notice that only says "truncated" spends
    // the reader's attention to tell them they have a problem without telling
    // them what to do about it.
    if (cut > 0) {
        try writeText(io, allocator, "{d} more result(s) cut by a ~{d}-token budget — narrow with --kind, or raise --budget\n", .{
            cut,
            budget_tokens,
        });
    }
    if (results.confidence == .low) {
        try writeText(io, allocator, "low confidence: {s} (scanned {d} of {d} nodes)\n", .{
            results.confidence_reason,
            results.scanned,
            results.corpus,
        });
    }
    // The read path does not hash the working tree, so the answer is consistent
    // with the published generation and may not match the files on disk. An
    // unreported caveat is the same defect as no caveat.
    if (!loaded.refresh.tree_verified) {
        try writeText(io, allocator, "generation {s}; working tree not checked — run `zgraphy build` to refresh\n", .{
            loaded.refresh.generation,
        });
    }
}

fn runExplain(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, command_line: zstd.Cli.ParsedCommand) !void {
    const selector = command_line.positional(0) orelse return error.MissingNode;
    var loaded = try openGraph(allocator, io, root);
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
    if (jsonRequested(command_line)) return writeJson(io, allocator, .{
        .schema = "zgraphy.explain.v4",
        .node = node.*,
        .generation = loaded.refresh.generation,
        .refresh = refreshView(&loaded.refresh),
        .incoming = incoming,
        .outgoing = outgoing,
        .request_paths = request_paths,
        .features = features,
        .semantic_truncated = request_path_count > request_paths.len or feature_count > features.len,
    });
    var label_buffer: zgraphy.Sanitize.Buffer = undefined;
    var path_buffer: zgraphy.Sanitize.Buffer = undefined;
    return writeText(io, allocator, "{s} id={d} kind={s} source={s}:{d} incoming={d} outgoing={d} request_paths={d} features={d}\n", .{
        zgraphy.Sanitize.clean(&label_buffer, node.label),
        node.id,
        @tagName(node.kind),
        zgraphy.Sanitize.clean(&path_buffer, node.path),
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

fn runPath(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, command_line: zstd.Cli.ParsedCommand) !void {
    const from_selector = command_line.positional(0) orelse return error.MissingFromNode;
    const to_selector = command_line.positional(1) orelse return error.MissingToNode;
    const max_hops = try numericOptionOf(command_line, "max-hops", 8, 1, 128);
    var loaded = try openGraph(allocator, io, root);
    defer loaded.deinit();
    const from = findNode(&loaded.graph, from_selector) orelse return error.NodeNotFound;
    const to = findNode(&loaded.graph, to_selector) orelse return error.NodeNotFound;
    var path = try loaded.graph.shortestPathAlloc(allocator, from.id, to.id, max_hops);
    defer path.deinit();
    if (jsonRequested(command_line)) return writeJson(io, allocator, .{
        .schema = "zgraphy.path.v3",
        .generation = loaded.refresh.generation,
        .refresh = refreshView(&loaded.refresh),
        .complete = path.complete,
        .exhausted = path.exhausted,
        .node_ids = path.node_ids,
    });
    if (!path.complete) return writeText(io, allocator, "no path within {d} hops (bound_exhausted={any})\n", .{ max_hops, path.exhausted });
    for (path.node_ids, 0..) |id, index| {
        const node = loaded.graph.findNode(id).?;
        if (index > 0) try std.Io.File.stdout().writeStreamingAll(io, " -> ");
        var label_buffer: zgraphy.Sanitize.Buffer = undefined;
        try std.Io.File.stdout().writeStreamingAll(io, zgraphy.Sanitize.clean(&label_buffer, node.label));
    }
    try std.Io.File.stdout().writeStreamingAll(io, "\n");
}

const LoadedGraph = struct {
    graph: zgraphy.RepositoryGraph,
    refresh: zgraphy.Operations.Publication,
    recovery_source: zgraphy.Operations.RecoverySource,

    fn deinit(self: *LoadedGraph) void {
        self.graph.deinit();
        self.refresh.deinit();
    }
};

/// Read-only open, for commands that answer questions about the published
/// graph rather than about the working tree. Does not hash the repository and
/// takes only a shared lease, so concurrent queries succeed.
fn openGraph(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir) !LoadedGraph {
    var config = try zgraphy.Project.loadConfig(allocator, io, root);
    defer config.deinit();
    const managed = try zgraphy.Operations.openManagedGraph(allocator, io, root, config.value);
    return .{
        .graph = managed.graph,
        .refresh = managed.refresh,
        .recovery_source = managed.recovery_source,
    };
}

/// Verified open: consults the working tree and refreshes if it has moved.
/// `status` reports freshness, so it must pay for the answer it prints.
fn loadGraph(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir) !LoadedGraph {
    var config = try zgraphy.Project.loadConfig(allocator, io, root);
    defer config.deinit();
    const managed = try zgraphy.Operations.loadManagedGraph(allocator, io, root, config.value);
    return .{
        .graph = managed.graph,
        .refresh = managed.refresh,
        .recovery_source = managed.recovery_source,
    };
}

const RefreshView = struct {
    status: zgraphy.Operations.RefreshStatus,
    trigger: zgraphy.Operations.RefreshTrigger,
    activated: bool,
    generation: []const u8,
    previous_generation: []const u8,
    delta_journal: []const u8,
    delta_fingerprint: []const u8,
    delta_summary: zgraphy.DeltaJournal.Summary,
    checked_files: usize,
    reparsed_files: usize,
    cache_hits: usize,
    cache_misses: usize,
    cache_rejected: usize,
    cache_writes: usize,
    direct_invalidations: usize,
    invalidation_closure: usize,
    pruned: zgraphy.Operations.PrunedRecords,
    origin: zgraphy.OriginLedger.Summary,
    repair: zgraphy.Repair.Summary,
    retention: zgraphy.Retention.Summary,
};

fn refreshView(publication: *const zgraphy.Operations.Publication) RefreshView {
    return .{
        .status = publication.status,
        .trigger = publication.trigger,
        .activated = publication.activated,
        .generation = publication.generation,
        .previous_generation = publication.previous_generation,
        .delta_journal = publication.delta_journal,
        .delta_fingerprint = publication.delta_fingerprint,
        .delta_summary = publication.delta_summary,
        .checked_files = publication.checked_files,
        .reparsed_files = publication.reparsed_files,
        .cache_hits = publication.cache_hits,
        .cache_misses = publication.cache_misses,
        .cache_rejected = publication.cache_rejected,
        .cache_writes = publication.cache_writes,
        .direct_invalidations = publication.direct_invalidations,
        .invalidation_closure = publication.invalidation_closure,
        .pruned = publication.pruned,
        .origin = publication.origin,
        .repair = publication.repair,
        .retention = publication.retention,
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

/// Whether `--json` output was requested on the resolved command.
fn jsonRequested(command_line: zstd.Cli.ParsedCommand) bool {
    return command_line.optionValue("json") != null;
}

/// A command-owned required string option, read from the resolved command. The
/// framework parser already consumed the value atomically, so a present option
/// always carries one.
fn requiredStringOptionOf(command_line: zstd.Cli.ParsedCommand, name: []const u8) ![]const u8 {
    return command_line.optionValue(name) orelse error.MissingOption;
}

/// A command-owned numeric option with domain bounds, read from the resolved
/// command. Syntactic parsing already validated integer options; this applies
/// the command's own range policy.
fn numericOptionOf(command_line: zstd.Cli.ParsedCommand, name: []const u8, default: usize, minimum: usize, maximum: usize) !usize {
    const text = command_line.optionValue(name) orelse return default;
    const value = try std.fmt.parseInt(usize, text, 10);
    if (value < minimum or value > maximum) return error.InvalidOptionValue;
    return value;
}

fn optionalNumericOptionOf(command_line: zstd.Cli.ParsedCommand, name: []const u8, minimum: usize, maximum: usize) !?usize {
    const text = command_line.optionValue(name) orelse return null;
    const value = try std.fmt.parseInt(usize, text, 10);
    if (value < minimum or value > maximum) return error.InvalidOptionValue;
    return value;
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
