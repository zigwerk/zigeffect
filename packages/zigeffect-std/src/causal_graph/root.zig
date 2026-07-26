const std = @import("std");
const Project = @import("../project/root.zig");
const Secrets = @import("../secrets/root.zig");
const Nendb = @import("../vendor/nendb/root.zig");
const fx = @import("zigeffect");

pub const record_schema = "zigeffect.causal.local-graph-record.v1";
pub const record_schema_version: u32 = 1;
pub const summary_schema = "zigeffect.causal.local-graph-summary.v1";
pub const summary_schema_version: u32 = 1;
pub const children_schema = "zigeffect.causal.local-graph-children.v1";
pub const children_schema_version: u32 = 1;
pub const records_since_schema = "zigeffect.causal.local-graph-records-since.v1";
pub const records_since_schema_version: u32 = 1;
pub const path_schema = "zigeffect.causal.local-graph-path.v1";
pub const path_schema_version: u32 = 1;
pub const lineage_schema = "zigeffect.causal.local-graph-lineage.v1";
pub const lineage_schema_version: u32 = 1;
pub const find_schema = "zigeffect.causal.local-graph-find.v1";
pub const find_schema_version: u32 = 1;
pub const traversal_schema = "zigeffect.causal.local-graph-traversal.v1";
pub const traversal_schema_version: u32 = 1;

/// Render a bounded traversal.
///
/// `truncated` is part of the contract, not a detail: an agent reading a partial
/// causal chain as a complete one would draw the wrong conclusion, so the reply
/// always states whether a bound stopped the walk.
pub fn traversalJsonAlloc(
    allocator: std.mem.Allocator,
    direction: []const u8,
    durable_event_id: u64,
    traversal: Engine.Traversal,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    const header = try std.fmt.allocPrint(
        allocator,
        "{{\"schema\":\"{s}\",\"schema_version\":{d},\"direction\":\"{s}\",\"event_id\":{d},\"count\":{d},\"truncated\":{s},\"event_ids\":[",
        .{
            traversal_schema,
            traversal_schema_version,
            direction,
            durable_event_id,
            traversal.ids.len,
            if (traversal.truncated) "true" else "false",
        },
    );
    defer allocator.free(header);
    try output.appendSlice(allocator, header);
    for (traversal.ids, 0..) |id, position| {
        if (position != 0) try output.append(allocator, ',');
        const rendered = try std.fmt.allocPrint(allocator, "{d}", .{id});
        defer allocator.free(rendered);
        try output.appendSlice(allocator, rendered);
    }
    try output.appendSlice(allocator, "]}");
    return output.toOwnedSlice(allocator);
}

/// Derived, disposable index over the durable log. Nothing reads it yet; it is
/// introduced ahead of its readers so the format can be reviewed and tested in
/// isolation, and so a defect in it cannot affect a query result.
pub const Index = @import("index.zig");

/// Our own topology engine for the causal forest. Not a general graph database:
/// it exploits the single-parent, id-ordered shape the durable format
/// guarantees, so parent walks need no index and child lookups need one small
/// CSR array instead of a scan.
pub const Engine = @import("engine.zig");

pub const default_path = ".zigeffect/graph";
pub const default_wal_name = "causal-graph.jsonl";
pub const default_max_records: usize = 65_536;
pub const max_records: usize = Nendb.max_nodes;

pub const DatabaseError = error{
    InvalidGraphOptions,
    InvalidGraphRecord,
    UnsupportedGraphSchema,
    CorruptGraph,
    GraphRecordTooLarge,
    GraphDatabaseFull,
    DuplicateSourceEvent,
    NonMonotonicSourceEvent,
    MissingParentEvent,
    SecretDetected,
    EventNotFound,
    PathNotFound,
    InvalidPathLimit,
    SessionIdOverflow,
    DurableEventIdOverflow,
};

pub const Path = struct {
    allocator: std.mem.Allocator,
    from_event_id: u64,
    to_event_id: u64,
    event_ids: []u64,

    pub fn deinit(self: *Path) void {
        self.allocator.free(self.event_ids);
        self.* = undefined;
    }

    pub fn jsonAlloc(self: Path, allocator: std.mem.Allocator) ![]u8 {
        return std.json.Stringify.valueAlloc(allocator, .{
            .schema = path_schema,
            .schema_version = path_schema_version,
            .from_event_id = self.from_event_id,
            .to_event_id = self.to_event_id,
            .length = self.event_ids.len,
            .event_ids = self.event_ids,
        }, .{});
    }
};

/// What the graph does when a write would exceed `max_records` or `max_wal_bytes`.
pub const Retention = enum {
    /// Refuse the write. Every fact ever recorded stays addressable.
    ///
    /// This was the default while a receipt's only proof was an event id
    /// pointing into this graph — dropping a record would have let a claim
    /// outlive its justification. Receipts now carry the facts they cite, so
    /// that is no longer true and this is the explicit choice for a store that
    /// must never lose a record, not the safe default.
    fail_closed,
    /// Drop the oldest complete sessions to make room. A long-running service
    /// keeps recording instead of failing, at the cost of losing the oldest
    /// history. Sessions are pruned whole because parent edges never cross a
    /// session boundary, so no retained record is left pointing at a gap.
    ///
    /// The default. A durable event id is a local join key into a working set,
    /// and `graph event <id>` returning not-found for a pruned record is normal
    /// rather than a broken claim — the claim lives in the committed evidence.
    prune_oldest_sessions,
};

pub const Options = struct {
    path: []const u8 = default_path,
    wal_name: []const u8 = default_wal_name,
    /// Derived index sibling of the log. Deleting this file is always safe.
    index_name: []const u8 = Index.default_index_name,
    retention: Retention = .prune_oldest_sessions,
    max_records: usize = default_max_records,
    max_wal_bytes: usize = 64 * 1024 * 1024,
    max_record_bytes: usize = 512 * 1024,
    sync_on_write: bool = true,
    recover_partial_tail: bool = true,

    pub fn validate(self: Options) !void {
        try Project.validateRelativePath(self.path, false);
        try Project.validateRelativePath(self.wal_name, false);
        try Project.validateRelativePath(self.index_name, false);
        if (std.mem.indexOfScalar(u8, self.wal_name, '/') != null or
            std.mem.indexOfScalar(u8, self.index_name, '/') != null or
            std.mem.eql(u8, self.index_name, self.wal_name) or
            self.max_records == 0 or
            self.max_records > max_records or
            self.max_wal_bytes == 0 or
            self.max_record_bytes == 0 or
            self.max_record_bytes > self.max_wal_bytes)
        {
            return error.InvalidGraphOptions;
        }
        if (Secrets.containsSecret(self.path) or Secrets.containsSecret(self.wal_name) or Secrets.containsSecret(self.index_name)) return error.SecretDetected;
    }
};

pub const PersistedNode = struct {
    id: u64,
    source_event_id: u64,
    label: []const u8,
    kind: u8,
    properties: []const u8,
};

pub const PersistedEdge = struct {
    from: u64,
    to: u64,
    source_from: u64,
    source_to: u64,
    label: []const u8,
    label_id: u16,
    properties: []const u8,
};

pub const PersistedRecord = struct {
    schema: []const u8 = record_schema,
    schema_version: u32 = record_schema_version,
    sequence: u64,
    session_id: u64,
    node: PersistedNode,
    parent_edge: ?PersistedEdge = null,

    pub fn validate(self: PersistedRecord) !void {
        if (!std.mem.eql(u8, self.schema, record_schema) or self.schema_version != record_schema_version) {
            return error.UnsupportedGraphSchema;
        }
        if (self.sequence == 0 or self.session_id == 0 or self.node.id == 0 or self.node.source_event_id == 0 or
            self.node.label.len == 0 or self.node.kind == 0 or self.node.properties.len == 0)
        {
            return error.InvalidGraphRecord;
        }
        try ensureSafe(self.node.label);
        try ensureSafe(self.node.properties);
        try validateNodeProperties(self.node.properties, self.node.source_event_id, self.node.label, self.node.kind);
        if (self.parent_edge) |edge| {
            if (edge.from == 0 or edge.to != self.node.id or edge.source_from == 0 or
                edge.source_to != self.node.source_event_id or edge.source_from >= edge.source_to or
                edge.label.len == 0 or edge.label_id == 0 or edge.properties.len == 0)
            {
                return error.InvalidGraphRecord;
            }
            try ensureSafe(edge.label);
            try ensureSafe(edge.properties);
            if (!std.mem.eql(u8, edge.label, "causal_parent") or
                edge.label_id != fx.stableCausalNendbEdgeLabelId(edge.label))
            {
                return error.InvalidGraphRecord;
            }
            try validateEdgeProperties(edge.properties, edge.source_from, edge.source_to);
        }
    }
};

const NodePropertiesHeader = struct {
    schema: []const u8,
    schema_version: u32,
    event_id: u64,
    kind: []const u8,
};

const EdgePropertiesHeader = struct {
    schema: []const u8,
    schema_version: u32,
    from_event_id: u64,
    to_event_id: u64,
};

/// The entry table is the engine's node table; aliasing rather than copying
/// keeps traversal zero-copy over the rows the graph already holds.
const IndexEntry = Engine.Entry;

pub const Summary = struct {
    schema: []const u8 = summary_schema,
    schema_version: u32 = summary_schema_version,
    path: []const u8,
    wal_name: []const u8,
    records: usize,
    edges: usize,
    sessions: u64,
    newest_durable_event_id: ?u64,
    wal_bytes: usize,
    trailing_partial_bytes: usize,
    engine: []const u8 = "nendb_embedded",
    engine_version: []const u8 = Nendb.upstream_version,
    engine_upstream_commit: []const u8 = Nendb.upstream_commit,
    engine_nodes: usize,
    engine_edges: usize,
};

pub const EngineStats = struct {
    engine: []const u8 = "nendb_embedded",
    version: []const u8 = Nendb.upstream_version,
    upstream_commit: []const u8 = Nendb.upstream_commit,
    nodes: usize,
    edges: usize,
    node_capacity: usize = Nendb.max_nodes,
    edge_capacity: usize = Nendb.max_edges,
};

const ScanResult = struct {
    const NodeIdentity = struct { session_id: u64, source_event_id: u64 };

    entries: std.ArrayList(IndexEntry) = .empty,
    seen_nodes: std.AutoHashMapUnmanaged(u64, NodeIdentity) = .empty,
    last_complete_offset: usize = 0,
    edge_count: usize = 0,
    max_session_id: u64 = 0,
    max_durable_event_id: u64 = 0,
    last_source_event_id: u64 = 0,

    fn deinit(self: *ScanResult, allocator: std.mem.Allocator) void {
        self.seen_nodes.deinit(allocator);
        self.entries.deinit(allocator);
        self.* = undefined;
    }
};

pub const LocalDatabase = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    mutex: fx.SpinLock = .{},
    nendb: *Nendb.GraphData,
    graph_dir: std.Io.Dir,
    wal_file: std.Io.File,
    options: Options,
    owned_path: []u8,
    owned_wal_name: []u8,
    entries: std.ArrayList(IndexEntry) = .empty,
    durable_entry_index: std.AutoHashMapUnmanaged(u64, usize) = .empty,
    current_source_index: std.AutoHashMapUnmanaged(u64, u64) = .empty,
    edge_count: usize = 0,
    session_id: u64,
    node_base: u64,
    recovered_partial_bytes: usize = 0,
    /// Derived index, maintained alongside the log and persisted at flush.
    /// Nothing reads it yet; it is produced first so that a defect in it cannot
    /// affect a query result before it has been proven against a replay.
    index_builder: Index.Builder = undefined,
    index_dirty: bool = false,
    /// Cleared the moment the index cannot be kept faithful to the log. Once
    /// false it stays false for this process: a partially-maintained index is
    /// worse than none, because a reader could trust it.
    index_usable: bool = true,

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        root: std.Io.Dir,
        options: Options,
    ) !LocalDatabase {
        try options.validate();
        try root.createDirPath(io, options.path);
        var graph_dir = try root.openDir(io, options.path, .{ .follow_symlinks = false });
        errdefer graph_dir.close(io);
        const wal_file = try graph_dir.createFile(io, options.wal_name, .{
            .read = true,
            .truncate = false,
            .lock = .exclusive,
            .resolve_beneath = true,
        });
        errdefer wal_file.close(io);
        const owned_path = try allocator.dupe(u8, options.path);
        errdefer allocator.free(owned_path);
        const owned_wal_name = try allocator.dupe(u8, options.wal_name);
        errdefer allocator.free(owned_wal_name);
        const nendb = try allocator.create(Nendb.GraphData);
        errdefer allocator.destroy(nendb);
        nendb.* = try Nendb.GraphData.initCapacity(allocator, options.max_records, options.max_records);
        errdefer nendb.deinit();

        var self = LocalDatabase{
            .allocator = allocator,
            .io = io,
            .nendb = nendb,
            .graph_dir = graph_dir,
            .wal_file = wal_file,
            .options = options,
            .owned_path = owned_path,
            .owned_wal_name = owned_wal_name,
            .session_id = 1,
            .node_base = 0,
        };
        self.options.path = self.owned_path;
        self.options.wal_name = self.owned_wal_name;
        self.index_builder = Index.Builder.init(allocator);
        self.loadExisting() catch |err| {
            self.index_builder.deinit();
            self.current_source_index.deinit(allocator);
            self.durable_entry_index.deinit(allocator);
            self.entries.deinit(allocator);
            return err;
        };
        return self;
    }

    pub fn deinit(self: *LocalDatabase) void {
        self.index_builder.deinit();
        self.current_source_index.deinit(self.allocator);
        self.durable_entry_index.deinit(self.allocator);
        self.entries.deinit(self.allocator);
        self.nendb.deinit();
        self.allocator.destroy(self.nendb);
        self.wal_file.close(self.io);
        self.graph_dir.close(self.io);
        self.allocator.free(self.owned_wal_name);
        self.allocator.free(self.owned_path);
        self.* = undefined;
    }

    pub fn writer(self: *LocalDatabase) fx.CausalNendbGraphWriter {
        return .{ .state = self, .write = writeAdapter, .flush = flushAdapter };
    }

    pub fn storageBackend(
        self: *LocalDatabase,
        allocator: std.mem.Allocator,
        max_events: ?usize,
    ) fx.CausalNendbStorageBackendState {
        return fx.CausalNendbStorageBackendState.init(allocator, self.writer(), .{
            .max_events = max_events,
            .retain_history = false,
        });
    }

    pub fn flush(self: *LocalDatabase) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.wal_file.sync(self.io);
        // The log is durable before the index is written, so a crash in between
        // leaves a stale index that the next open detects and rebuilds.
        if (self.index_dirty) self.writeIndexUnlocked();
    }

    pub fn recordCount(self: *LocalDatabase) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.nendb.node_count;
    }

    pub fn edgeCount(self: *LocalDatabase) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.nendb.edge_count;
    }

    pub fn currentSessionId(self: *LocalDatabase) u64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.session_id;
    }

    pub fn recoveredPartialBytes(self: *LocalDatabase) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.recovered_partial_bytes;
    }

    pub fn durableId(self: *LocalDatabase, source_event_id: u64) ?u64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.durableIdUnlocked(source_event_id);
    }

    fn durableIdUnlocked(self: *const LocalDatabase, source_event_id: u64) ?u64 {
        return self.current_source_index.get(source_event_id);
    }

    pub fn contains(self: *LocalDatabase, durable_event_id: u64) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.nendb.findNodeById(durable_event_id) != null;
    }

    pub fn childrenAlloc(self: *LocalDatabase, allocator: std.mem.Allocator, durable_event_id: u64) ![]u64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.nendb.findNodeById(durable_event_id) == null) return error.EventNotFound;
        var count: usize = 0;
        for (self.nendb.edge_from[0..self.nendb.edge_count]) |from| {
            if (from == durable_event_id) count += 1;
        }
        const children = try allocator.alloc(u64, count);
        var index: usize = 0;
        for (self.nendb.edge_from[0..self.nendb.edge_count], self.nendb.edge_to[0..self.nendb.edge_count]) |from, to| {
            if (from != durable_event_id) continue;
            children[index] = to;
            index += 1;
        }
        return children;
    }

    pub fn pathAlloc(
        self: *LocalDatabase,
        allocator: std.mem.Allocator,
        from_event_id: u64,
        to_event_id: u64,
        max_events: usize,
    ) !Path {
        self.mutex.lock();
        defer self.mutex.unlock();
        return pathFromEntriesAlloc(allocator, self.entries.items, from_event_id, to_event_id, max_events);
    }

    pub fn pathJsonAlloc(
        self: *LocalDatabase,
        allocator: std.mem.Allocator,
        from_event_id: u64,
        to_event_id: u64,
        max_events: usize,
    ) ![]u8 {
        var path = try self.pathAlloc(allocator, from_event_id, to_event_id, max_events);
        defer path.deinit();
        return path.jsonAlloc(allocator);
    }

    pub fn recordJsonAlloc(self: *LocalDatabase, allocator: std.mem.Allocator, durable_event_id: u64) ![]u8 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const entry_index = self.durable_entry_index.get(durable_event_id) orelse return error.EventNotFound;
        const entry = self.entries.items[entry_index];
        const output = try allocator.alloc(u8, entry.length);
        errdefer allocator.free(output);
        const read = try self.wal_file.readPositionalAll(self.io, output, entry.offset);
        if (read != entry.length) return error.CorruptGraph;
        return output;
    }

    /// Return a bounded, ordered delta after a durable event ID. Passing zero
    /// starts at the oldest retained event and is useful for initial discovery.
    pub fn recordsAfterJsonAlloc(
        self: *LocalDatabase,
        allocator: std.mem.Allocator,
        after_durable_event_id: u64,
        limit: usize,
    ) ![]u8 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const range = try recordsAfterRange(self.entries.items, after_durable_event_id, limit);
        const next_json = if (range.next_event_id) |id|
            try std.fmt.allocPrint(allocator, "{d}", .{id})
        else
            try allocator.dupe(u8, "null");
        defer allocator.free(next_json);
        var output: std.ArrayList(u8) = .empty;
        errdefer output.deinit(allocator);
        const header = try std.fmt.allocPrint(
            allocator,
            "{{\"schema\":\"{s}\",\"schema_version\":{d},\"after_event_id\":{d},\"next_event_id\":{s},\"truncated\":{s},\"records\":[",
            .{
                records_since_schema,
                records_since_schema_version,
                after_durable_event_id,
                next_json,
                if (range.truncated) "true" else "false",
            },
        );
        defer allocator.free(header);
        try output.appendSlice(allocator, header);
        for (self.entries.items[range.start..range.end], 0..) |entry, index| {
            if (index != 0) try output.append(allocator, ',');
            const row = try allocator.alloc(u8, entry.length);
            defer allocator.free(row);
            const read = try self.wal_file.readPositionalAll(self.io, row, entry.offset);
            if (read != entry.length) return error.CorruptGraph;
            try output.appendSlice(allocator, row);
        }
        try output.appendSlice(allocator, "]}");
        return output.toOwnedSlice(allocator);
    }

    /// Scan one bounded durable page and return a flattened summary of the
    /// records matching `filter`.
    ///
    /// The durable record nests semantic identity inside an encoded property
    /// blob, which makes triage a two-stage decode over every row. This lifts
    /// `label`, `kind`, `status`, `service_key` and the correlation identifiers
    /// to the top level so an agent can select and read in one pass, then fetch
    /// the untouched full record with `recordJsonAlloc` when it needs detail.
    ///
    /// Matching is a bounded scan, not an index: `after_durable_event_id`
    /// advances over scanned records rather than matches, so a sparse query
    /// still makes progress and reports incomplete pagination explicitly.
    pub fn findRecordsJsonAlloc(
        self: *LocalDatabase,
        allocator: std.mem.Allocator,
        filter: FindFilter,
        after_durable_event_id: u64,
        limit: usize,
        scan_limit: usize,
    ) ![]u8 {
        try validateFindQuery(filter, limit, scan_limit);
        self.mutex.lock();
        defer self.mutex.unlock();

        const range = try recordsAfterRange(self.entries.items, after_durable_event_id, scan_limit);
        var rows: std.ArrayList(u8) = .empty;
        defer rows.deinit(allocator);

        var scanned: usize = 0;
        var matched: usize = 0;
        var last_scanned: ?u64 = null;
        var stopped_early = false;
        for (self.entries.items[range.start..range.end], 0..) |entry, relative_index| {
            const row = try allocator.alloc(u8, entry.length);
            defer allocator.free(row);
            const read = try self.wal_file.readPositionalAll(self.io, row, entry.offset);
            if (read != entry.length) return error.CorruptGraph;
            scanned += 1;
            last_scanned = entry.durable_event_id;
            if (try appendFindRowIfMatch(&rows, allocator, entry, row, filter, matched != 0)) {
                matched += 1;
                if (matched == limit) {
                    stopped_early = relative_index + 1 < range.end - range.start;
                    break;
                }
            }
        }

        return findResultJsonAlloc(
            allocator,
            rows.items,
            after_durable_event_id,
            last_scanned,
            scanned,
            matched,
            stopped_early or range.truncated,
        );
    }

    /// Scan one bounded durable page and return only records carrying the
    /// requested opaque typed value. `after_durable_event_id` advances over
    /// scanned records, not only matches, so sparse queries always make
    /// progress and expose incomplete pagination explicitly.
    pub fn lineageRecordsJsonAlloc(
        self: *LocalDatabase,
        allocator: std.mem.Allocator,
        reference: fx.Lineage.Ref,
        after_durable_event_id: u64,
        limit: usize,
        scan_limit: usize,
    ) ![]u8 {
        if (!reference.valid() or limit == 0 or limit > 4096 or scan_limit == 0 or scan_limit > max_records) {
            return error.InvalidGraphOptions;
        }
        self.mutex.lock();
        defer self.mutex.unlock();

        const range = try recordsAfterRange(self.entries.items, after_durable_event_id, scan_limit);
        var matches: std.ArrayList(IndexEntry) = .empty;
        defer matches.deinit(allocator);
        var scanned: usize = 0;
        var last_scanned: ?u64 = null;
        var stopped_early = false;
        for (self.entries.items[range.start..range.end], 0..) |entry, relative_index| {
            const row = try allocator.alloc(u8, entry.length);
            defer allocator.free(row);
            const read = try self.wal_file.readPositionalAll(self.io, row, entry.offset);
            if (read != entry.length) return error.CorruptGraph;
            scanned += 1;
            last_scanned = entry.durable_event_id;
            if (try persistedRowContainsLineage(allocator, row, reference)) {
                try matches.append(allocator, entry);
                if (matches.items.len == limit) {
                    stopped_early = relative_index + 1 < range.end - range.start;
                    break;
                }
            }
        }

        const truncated = stopped_early or range.truncated;
        const next_json = if (truncated and last_scanned != null)
            try std.fmt.allocPrint(allocator, "{d}", .{last_scanned.?})
        else
            try allocator.dupe(u8, "null");
        defer allocator.free(next_json);

        var output: std.ArrayList(u8) = .empty;
        errdefer output.deinit(allocator);
        const header = try std.fmt.allocPrint(
            allocator,
            "{{\"schema\":\"{s}\",\"schema_version\":{d},\"after_event_id\":{d},\"next_after_event_id\":{s},\"scanned\":{d},\"matched\":{d},\"truncated\":{s},\"reference\":",
            .{
                lineage_schema,
                lineage_schema_version,
                after_durable_event_id,
                next_json,
                scanned,
                matches.items.len,
                if (truncated) "true" else "false",
            },
        );
        defer allocator.free(header);
        try output.appendSlice(allocator, header);
        const reference_json = try std.json.Stringify.valueAlloc(allocator, reference, .{});
        defer allocator.free(reference_json);
        try output.appendSlice(allocator, reference_json);
        try output.appendSlice(allocator, ",\"records\":[");
        for (matches.items, 0..) |entry, index| {
            if (index != 0) try output.append(allocator, ',');
            const row = try allocator.alloc(u8, entry.length);
            defer allocator.free(row);
            const read = try self.wal_file.readPositionalAll(self.io, row, entry.offset);
            if (read != entry.length) return error.CorruptGraph;
            try output.appendSlice(allocator, row);
        }
        try output.appendSlice(allocator, "]}");
        return output.toOwnedSlice(allocator);
    }

    pub fn summary(self: *LocalDatabase) Summary {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.summaryUnlocked();
    }

    fn summaryUnlocked(self: *const LocalDatabase) Summary {
        const wal_bytes = self.wal_file.length(self.io) catch 0;
        var result = summaryFromEntries(
            self.options.path,
            self.options.wal_name,
            self.entries.items,
            self.edge_count,
            @intCast(wal_bytes),
            self.recovered_partial_bytes,
        );
        result.engine_nodes = self.nendb.node_count;
        result.engine_edges = self.nendb.edge_count;
        return result;
    }

    pub fn summaryJsonAlloc(self: *LocalDatabase, allocator: std.mem.Allocator) ![]u8 {
        return std.json.Stringify.valueAlloc(allocator, self.summary(), .{});
    }

    pub fn engineStats(self: *LocalDatabase) EngineStats {
        self.mutex.lock();
        defer self.mutex.unlock();
        const stats = self.nendb.getStats();
        return .{
            .nodes = stats.node_count,
            .edges = stats.edge_count,
            .node_capacity = stats.node_capacity,
            .edge_capacity = stats.edge_capacity,
        };
    }

    /// Restore all derived state from a verified index, decoding nothing.
    ///
    /// Returns false whenever the index cannot carry the whole load, in which
    /// case the caller replays the log exactly as before. Note the index is only
    /// accepted when it covers every byte: a log with a trailing partial record
    /// is longer than any index of it, so truncation recovery is never skipped.
    fn loadFromIndex(self: *LocalDatabase, content: []const u8) !bool {
        const raw = self.graph_dir.readFileAlloc(
            self.io,
            self.options.index_name,
            self.allocator,
            .limited(self.options.max_wal_bytes),
        ) catch return false;
        defer self.allocator.free(raw);

        const view = Index.parse(raw) catch return false;
        const covered: usize = @intCast(view.header.covered_bytes);
        if (covered > content.len) return false;
        if (!Index.coversPrefix(view, content.len, content[0..covered])) return false;
        if (view.entries.len > self.options.max_records) return false;

        const parent_label_id = fx.stableCausalNendbEdgeLabelId("causal_parent");
        try self.entries.ensureTotalCapacity(self.allocator, view.entries.len);
        try self.durable_entry_index.ensureUnusedCapacity(self.allocator, @intCast(view.entries.len));

        var edges: usize = 0;
        for (view.entries, 0..) |entry, position| {
            if (entry.offset + entry.length > content.len) return error.CorruptGraph;
            if (position != 0 and entry.durable_event_id <= view.entries[position - 1].durable_event_id) {
                return error.CorruptGraph;
            }
            const parent = if (entry.durable_parent_id == Index.no_parent) null else entry.durable_parent_id;
            _ = self.nendb.addNode(entry.durable_event_id, entry.node_kind) catch return error.CorruptGraph;
            if (parent) |from| {
                _ = self.nendb.addEdge(from, entry.durable_event_id, parent_label_id) catch return error.CorruptGraph;
                edges += 1;
            }
            self.entries.appendAssumeCapacity(.{
                .sequence = entry.sequence,
                .session_id = entry.session_id,
                .durable_event_id = entry.durable_event_id,
                .source_event_id = entry.source_event_id,
                .durable_parent_id = parent,
                .offset = @intCast(entry.offset),
                .length = @intCast(entry.length),
            });
            self.durable_entry_index.putAssumeCapacityNoClobber(entry.durable_event_id, position);

        }

        // The builder is seeded by copy rather than by re-interning every
        // column, which measurement showed cost more than the load saved.
        self.index_builder.seedFrom(view) catch return error.CorruptGraph;

        self.edge_count = edges;
        var max_session_id = view.header.max_session_id;
        var max_durable_event_id = view.header.max_durable_event_id;
        var last_complete_offset = covered;

        // A process writes lifecycle records after its final flush, so a log is
        // routinely longer than the index of it. Validating only those trailing
        // bytes is what makes the fast path reachable at all for a service:
        // without it a server always falls back to decoding everything.
        if (covered < content.len) {
            var scan = ScanResult{};
            defer scan.deinit(self.allocator);
            scan.entries = self.entries;
            self.entries = .empty;
            scan.edge_count = self.edge_count;
            scan.max_session_id = max_session_id;
            scan.max_durable_event_id = max_durable_event_id;
            scan.last_complete_offset = covered;
            // Parent resolution reaches back into the restored prefix, so the
            // identities the tail may reference have to be present.
            try scan.seen_nodes.ensureUnusedCapacity(self.allocator, @intCast(view.entries.len));
            for (view.entries) |entry| {
                scan.seen_nodes.putAssumeCapacity(entry.durable_event_id, .{
                    .session_id = entry.session_id,
                    .source_event_id = entry.source_event_id,
                });
            }
            if (view.entries.len != 0) {
                const newest = view.entries[view.entries.len - 1];
                if (newest.session_id == max_session_id) scan.last_source_event_id = newest.source_event_id;
            }

            const before = scan.entries.items.len;
            scanContentInto(&scan, self.allocator, content[covered..], self.options, covered, &self.index_builder) catch {
                // The tail is unreadable from here; hand the whole log back to
                // the replay path, which owns truncation recovery.
                self.entries = scan.entries;
                scan.entries = .empty;
                return false;
            };

            const parent_label = fx.stableCausalNendbEdgeLabelId("causal_parent");
            for (scan.entries.items[before..], before..) |entry, position| {
                // The scan result carries identity but not the topology kind
                // byte; the index builder recorded it for these same rows, in
                // the same order, as it validated them.
                const node_kind = if (position < self.index_builder.entries.items.len)
                    self.index_builder.entries.items[position].node_kind
                else
                    0;
                _ = self.nendb.addNode(entry.durable_event_id, node_kind) catch return error.CorruptGraph;
                if (entry.durable_parent_id) |from| {
                    _ = self.nendb.addEdge(from, entry.durable_event_id, parent_label) catch return error.CorruptGraph;
                }
                try self.durable_entry_index.put(self.allocator, entry.durable_event_id, position);
            }
            self.entries = scan.entries;
            scan.entries = .empty;
            self.edge_count = scan.edge_count;
            max_session_id = scan.max_session_id;
            max_durable_event_id = scan.max_durable_event_id;
            last_complete_offset = scan.last_complete_offset;

            if (last_complete_offset < content.len) {
                // A trailing partial record needs truncation, which the replay
                // path already implements correctly. Defer to it.
                return false;
            }
            self.index_dirty = true;
        }

        self.node_base = max_durable_event_id;
        self.session_id = std.math.add(u64, max_session_id, 1) catch return error.SessionIdOverflow;
        if (self.session_id == 0) return error.SessionIdOverflow;
        return true;
    }

    fn loadExisting(self: *LocalDatabase) !void {
        const content = try self.graph_dir.readFileAlloc(
            self.io,
            self.options.wal_name,
            self.allocator,
            .limited(self.options.max_wal_bytes),
        );
        defer self.allocator.free(content);

        // The runtime opens the graph on the process critical path — this is the
        // path that stopped a gRPC server binding on a large log. When a verified
        // index describes exactly these bytes, none of the log is decoded.
        if (try self.loadFromIndex(content)) return;

        var scan = try scanContent(self.allocator, content, self.options, &self.index_builder);
        defer scan.deinit(self.allocator);

        if (scan.last_complete_offset < content.len) {
            if (!self.options.recover_partial_tail) return error.CorruptGraph;
            self.recovered_partial_bytes = content.len - scan.last_complete_offset;
            try self.wal_file.setLength(self.io, scan.last_complete_offset);
            try self.wal_file.sync(self.io);
        }
        try self.rebuildNendb(content[0..scan.last_complete_offset]);
        self.entries = scan.entries;
        scan.entries = .empty;
        try self.durable_entry_index.ensureUnusedCapacity(self.allocator, @intCast(self.entries.items.len));
        for (self.entries.items, 0..) |entry, index| {
            self.durable_entry_index.putAssumeCapacityNoClobber(entry.durable_event_id, index);
        }
        self.edge_count = scan.edge_count;
        self.node_base = scan.max_durable_event_id;
        self.session_id = std.math.add(u64, scan.max_session_id, 1) catch return error.SessionIdOverflow;
        if (self.session_id == 0) return error.SessionIdOverflow;
    }

    /// Index of the first entry to retain when dropping oldest sessions.
    ///
    /// Prunes on whole-session boundaries and never touches the session being
    /// written, so the returned cut always leaves a referentially complete
    /// graph. Returns 0 when nothing can be dropped — a single session larger
    /// than the retention target cannot be compacted, and the caller must still
    /// fail rather than pretend there was room.
    fn retentionCutIndexUnlocked(self: *const LocalDatabase) usize {
        const target = @max(self.options.max_records / 2, 1);
        var cut: usize = 0;
        while (cut < self.entries.items.len and self.entries.items.len - cut > target) {
            const session = self.entries.items[cut].session_id;
            if (session == self.session_id) break;
            while (cut < self.entries.items.len and self.entries.items[cut].session_id == session) cut += 1;
        }
        return cut;
    }

    /// Rewrite the log without its oldest sessions and rebuild every derived
    /// index. The replacement is staged in a sibling file and renamed into
    /// place, so an interrupted compaction leaves the original log intact.
    fn pruneOldestSessionsUnlocked(self: *LocalDatabase) !void {
        const cut = self.retentionCutIndexUnlocked();
        if (cut == 0) return;

        const content = try self.graph_dir.readFileAlloc(
            self.io,
            self.options.wal_name,
            self.allocator,
            .limited(self.options.max_wal_bytes),
        );
        defer self.allocator.free(content);

        // `sequence` is the record's 1-based position in the log, so dropping a
        // prefix means every retained record has to be renumbered; a verbatim
        // copy would fail the contiguity check on the next open.
        var retained: std.ArrayList(u8) = .empty;
        defer retained.deinit(self.allocator);
        var lengths: std.ArrayList(usize) = .empty;
        defer lengths.deinit(self.allocator);
        try lengths.ensureTotalCapacity(self.allocator, self.entries.items.len - cut);
        // The index is rebuilt in this same pass, against the offsets of the file
        // being written rather than the one being replaced.
        var rebuilt_index = Index.Builder.init(self.allocator);
        errdefer rebuilt_index.deinit();
        for (self.entries.items[cut..], 0..) |entry, index| {
            if (entry.offset + entry.length > content.len) return error.CorruptGraph;
            const line = content[entry.offset .. entry.offset + entry.length];
            var parsed = std.json.parseFromSlice(PersistedRecord, self.allocator, line, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch
                return error.CorruptGraph;
            defer parsed.deinit();
            var record = parsed.value;
            record.sequence = @as(u64, @intCast(index)) + 1;
            const row = try formatRecordAlloc(self.allocator, record);
            defer self.allocator.free(row);
            const new_offset = retained.items.len;
            lengths.appendAssumeCapacity(row.len);
            try retained.appendSlice(self.allocator, row);
            try retained.append(self.allocator, '\n');
            try appendIndexRow(&rebuilt_index, self.allocator, record, entry.durable_parent_id, new_offset, row.len);
        }

        const staging_name = try std.fmt.allocPrint(self.allocator, "{s}.compact", .{self.options.wal_name});
        defer self.allocator.free(staging_name);
        {
            var staging = try self.graph_dir.createFile(self.io, staging_name, .{
                .read = true,
                .truncate = true,
                .resolve_beneath = true,
            });
            defer staging.close(self.io);
            try staging.writePositionalAll(self.io, retained.items, 0);
            try staging.sync(self.io);
        }
        try self.graph_dir.rename(staging_name, self.graph_dir, self.options.wal_name, self.io);

        self.wal_file.close(self.io);
        self.wal_file = try self.graph_dir.createFile(self.io, self.options.wal_name, .{
            .read = true,
            .truncate = false,
            .lock = .exclusive,
            .resolve_beneath = true,
        });

        // Offsets, the durable lookup table and the in-memory graph all describe
        // positions in the file that was just replaced, so every one is rebuilt.
        self.nendb.deinit();
        self.nendb.* = try Nendb.GraphData.initCapacity(
            self.allocator,
            self.options.max_records,
            self.options.max_records,
        );
        self.durable_entry_index.clearRetainingCapacity();
        var rebuilt: std.ArrayList(IndexEntry) = .empty;
        errdefer rebuilt.deinit(self.allocator);
        try rebuilt.ensureTotalCapacity(self.allocator, self.entries.items.len - cut);
        var offset: usize = 0;
        var edges: usize = 0;
        for (self.entries.items[cut..], 0..) |entry, index| {
            var moved = entry;
            moved.sequence = @as(u64, @intCast(index)) + 1;
            moved.offset = offset;
            moved.length = lengths.items[index];
            offset += moved.length + 1;
            if (entry.durable_parent_id != null) edges += 1;
            rebuilt.appendAssumeCapacity(moved);
        }
        self.edge_count = edges;

        // Every offset the previous index recorded points into a file that no
        // longer exists, so the rebuild above replaces it wholesale.
        self.index_builder.deinit();
        self.index_builder = rebuilt_index;
        self.index_usable = true;
        self.index_dirty = true;
        self.entries.deinit(self.allocator);
        self.entries = rebuilt;
        try self.durable_entry_index.ensureUnusedCapacity(self.allocator, @intCast(self.entries.items.len));
        for (self.entries.items, 0..) |entry, index| {
            self.durable_entry_index.putAssumeCapacityNoClobber(entry.durable_event_id, index);
        }
        try self.rebuildNendb(retained.items);
    }

    fn rebuildNendb(self: *LocalDatabase, content: []const u8) !void {
        var line_start: usize = 0;
        while (std.mem.indexOfScalarPos(u8, content, line_start, '\n')) |newline| {
            const line = content[line_start..newline];
            var parsed = std.json.parseFromSlice(PersistedRecord, self.allocator, line, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch return error.CorruptGraph;
            defer parsed.deinit();
            _ = self.nendb.addNode(parsed.value.node.id, parsed.value.node.kind) catch return error.CorruptGraph;
            if (parsed.value.parent_edge) |edge| {
                _ = self.nendb.addEdge(edge.from, edge.to, edge.label_id) catch return error.CorruptGraph;
            }
            line_start = newline + 1;
        }
    }

    fn appendWrite(self: *LocalDatabase, write: fx.CausalNendbWrite) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.entries.items.len >= self.options.max_records) {
            if (self.options.retention == .fail_closed) return error.GraphDatabaseFull;
            try self.pruneOldestSessionsUnlocked();
            // Compaction can only drop sessions older than the current one, so a
            // single oversized session still fills the graph.
            if (self.entries.items.len >= self.options.max_records) return error.GraphDatabaseFull;
        }
        try ensureSafe(write.node.label);
        try ensureSafe(write.node.properties);
        if (write.node.id == 0 or self.durableIdUnlocked(write.node.id) != null) return error.DuplicateSourceEvent;
        if (self.entries.items.len != 0) {
            const newest = self.entries.items[self.entries.items.len - 1];
            if (newest.session_id == self.session_id and write.node.id <= newest.source_event_id) {
                return error.NonMonotonicSourceEvent;
            }
        }

        const durable_id = std.math.add(u64, self.node_base, write.node.id) catch return error.DurableEventIdOverflow;
        if (durable_id == 0) return error.DurableEventIdOverflow;
        var persisted_edge: ?PersistedEdge = null;
        if (write.parent_edge) |edge| {
            try ensureSafe(edge.label);
            try ensureSafe(edge.properties);
            const durable_parent = self.durableIdUnlocked(edge.from) orelse return error.MissingParentEvent;
            persisted_edge = .{
                .from = durable_parent,
                .to = durable_id,
                .source_from = edge.from,
                .source_to = write.node.id,
                .label = edge.label,
                .label_id = edge.label_id,
                .properties = edge.properties,
            };
        }
        const sequence = std.math.add(u64, @as(u64, @intCast(self.entries.items.len)), 1) catch return error.GraphDatabaseFull;
        const record = PersistedRecord{
            .sequence = sequence,
            .session_id = self.session_id,
            .node = .{
                .id = durable_id,
                .source_event_id = write.node.id,
                .label = write.node.label,
                .kind = write.node.kind,
                .properties = write.node.properties,
            },
            .parent_edge = persisted_edge,
        };
        try record.validate();
        const row = try formatRecordAlloc(self.allocator, record);
        defer self.allocator.free(row);
        if (row.len > self.options.max_record_bytes) return error.GraphRecordTooLarge;

        // Byte pressure is relieved before any capacity is reserved, because
        // compaction replaces the entry list wholesale.
        const row_bytes = @as(u64, @intCast(row.len + 1));
        var length_u64 = try self.wal_file.length(self.io);
        if ((std.math.add(u64, length_u64, row_bytes) catch return error.GraphDatabaseFull) > self.options.max_wal_bytes) {
            if (self.options.retention == .fail_closed) return error.GraphDatabaseFull;
            try self.pruneOldestSessionsUnlocked();
            length_u64 = try self.wal_file.length(self.io);
            if ((std.math.add(u64, length_u64, row_bytes) catch return error.GraphDatabaseFull) > self.options.max_wal_bytes) {
                return error.GraphDatabaseFull;
            }
        }

        try self.entries.ensureUnusedCapacity(self.allocator, 1);
        try self.durable_entry_index.ensureUnusedCapacity(self.allocator, 1);
        try self.current_source_index.ensureUnusedCapacity(self.allocator, 1);
        const offset_u64 = length_u64;
        const offset: usize = @intCast(offset_u64);

        const node_index = try self.nendb.addNode(durable_id, write.node.kind);
        var edge_index: ?u32 = null;
        errdefer {
            if (edge_index) |index| self.nendb.rollbackLastEdge(index);
            self.nendb.rollbackLastNode(node_index);
        }
        if (persisted_edge) |edge| {
            edge_index = try self.nendb.addEdge(edge.from, edge.to, edge.label_id);
        }

        self.wal_file.writePositionalAll(self.io, row, offset_u64) catch |err| {
            self.wal_file.setLength(self.io, offset_u64) catch {};
            return err;
        };
        self.wal_file.writePositionalAll(self.io, "\n", offset_u64 + row.len) catch |err| {
            self.wal_file.setLength(self.io, offset_u64) catch {};
            return err;
        };
        if (self.options.sync_on_write) self.wal_file.sync(self.io) catch |err| {
            self.wal_file.setLength(self.io, offset_u64) catch {};
            return err;
        };

        const entry_index = self.entries.items.len;
        self.durable_entry_index.putAssumeCapacityNoClobber(durable_id, entry_index);
        self.current_source_index.putAssumeCapacityNoClobber(write.node.id, durable_id);
        self.entries.appendAssumeCapacity(.{
            .sequence = sequence,
            .session_id = self.session_id,
            .durable_event_id = durable_id,
            .source_event_id = write.node.id,
            .durable_parent_id = if (persisted_edge) |edge| edge.from else null,
            .offset = offset,
            .length = row.len,
        });
        if (persisted_edge != null) self.edge_count += 1;

        // Maintained incrementally so a running process never has to re-read its
        // own log. A failure here must not fail the write: the record is already
        // durable, and the index is disposable by construction, so the correct
        // response is to mark it unusable and let the next open rebuild it.
        if (self.index_usable) {
            appendIndexRow(
                &self.index_builder,
                self.allocator,
                record,
                if (persisted_edge) |edge| edge.from else null,
                offset,
                row.len,
            ) catch {
                self.index_usable = false;
            };
        }
        self.index_dirty = true;
    }

    /// Persist the derived index next to the log.
    ///
    /// Written to a sibling and renamed, so an interrupted write leaves the
    /// previous index intact rather than a half-file. A failure is swallowed
    /// deliberately: losing the index costs a rebuild, and failing a durability
    /// barrier over a disposable artifact would be strictly worse.
    fn writeIndexUnlocked(self: *LocalDatabase) void {
        if (!self.index_usable) return;
        const content = self.graph_dir.readFileAlloc(
            self.io,
            self.options.wal_name,
            self.allocator,
            .limited(self.options.max_wal_bytes),
        ) catch return;
        defer self.allocator.free(content);

        const bytes = self.index_builder.serializeAlloc(content.len, Index.digest(content)) catch return;
        defer self.allocator.free(bytes);

        const staging = std.fmt.allocPrint(self.allocator, "{s}.next", .{self.options.index_name}) catch return;
        defer self.allocator.free(staging);
        {
            var file = self.graph_dir.createFile(self.io, staging, .{
                .truncate = true,
                .resolve_beneath = true,
            }) catch return;
            defer file.close(self.io);
            file.writePositionalAll(self.io, bytes, 0) catch return;
            file.sync(self.io) catch return;
        }
        self.graph_dir.rename(staging, self.graph_dir, self.options.index_name, self.io) catch return;
        self.index_dirty = false;
    }
};

const LineagePropertiesProjection = struct {
    context: struct {
        lineage: struct {
            refs: []fx.Lineage.Ref = &.{},
            truncated: bool = false,
        } = .{},
    } = .{},
};

/// The semantic fields a triaging agent selects on. Every field is an exact
/// match; an unset field does not constrain the scan.
pub const FindFilter = struct {
    label: ?[]const u8 = null,
    kind: ?[]const u8 = null,
    status: ?[]const u8 = null,
    service_key: ?[]const u8 = null,
    requirement_id: ?u64 = null,
    acceptance_check_id: ?u64 = null,
    scenario_id: ?u64 = null,

    pub fn isEmpty(self: FindFilter) bool {
        return self.label == null and self.kind == null and self.status == null and
            self.service_key == null and self.requirement_id == null and
            self.acceptance_check_id == null and self.scenario_id == null;
    }
};

/// The stored node property blob is a JSON *string* inside the record, so the
/// semantic identity an agent filters on is one decode below the surface. This
/// projection reads only the fields `find` selects and emits.
const FindPropertiesProjection = struct {
    event_id: u64 = 0,
    kind: []const u8 = "",
    label: []const u8 = "",
    status: []const u8 = "",
    service_key: []const u8 = "",
    type_name: []const u8 = "",
    run_id: ?u64 = null,
    parent_id: ?u64 = null,
    context: struct {
        requirement_id: ?u64 = null,
        acceptance_check_id: ?u64 = null,
        scenario_id: ?u64 = null,
    } = .{},
};

fn matchesText(selector: ?[]const u8, value: []const u8) bool {
    const wanted = selector orelse return true;
    return std.mem.eql(u8, wanted, value);
}

fn matchesId(selector: ?u64, value: ?u64) bool {
    const wanted = selector orelse return true;
    return value != null and value.? == wanted;
}

fn appendOptionalId(output: *std.ArrayList(u8), allocator: std.mem.Allocator, name: []const u8, value: ?u64) !void {
    if (value) |present| {
        const rendered = try std.fmt.allocPrint(allocator, ",\"{s}\":{d}", .{ name, present });
        defer allocator.free(rendered);
        try output.appendSlice(allocator, rendered);
    } else {
        const rendered = try std.fmt.allocPrint(allocator, ",\"{s}\":null", .{name});
        defer allocator.free(rendered);
        try output.appendSlice(allocator, rendered);
    }
}

/// Emit one flattened match. Text fields come from the validated property blob
/// and are already constrained by `ensureSafe`, so they need no re-escaping.
fn appendFindRow(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    entry: IndexEntry,
    record: PersistedRecord,
    projection: FindPropertiesProjection,
) !void {
    const head = try std.fmt.allocPrint(
        allocator,
        "{{\"durable_event_id\":{d},\"source_event_id\":{d},\"sequence\":{d},\"session_id\":{d}," ++
            "\"kind\":\"{s}\",\"label\":\"{s}\",\"status\":\"{s}\",\"service_key\":\"{s}\",\"type_name\":\"{s}\"",
        .{
            entry.durable_event_id,
            entry.source_event_id,
            record.sequence,
            record.session_id,
            projection.kind,
            projection.label,
            projection.status,
            projection.service_key,
            projection.type_name,
        },
    );
    defer allocator.free(head);
    try output.appendSlice(allocator, head);
    try appendOptionalId(output, allocator, "run_id", projection.run_id);
    try appendOptionalId(output, allocator, "durable_parent_id", entry.durable_parent_id);
    try appendOptionalId(output, allocator, "requirement_id", projection.context.requirement_id);
    try appendOptionalId(output, allocator, "acceptance_check_id", projection.context.acceptance_check_id);
    try appendOptionalId(output, allocator, "scenario_id", projection.context.scenario_id);
    try output.append(allocator, '}');
}

/// Project one durable record into an index row.
///
/// The semantic columns live inside the encoded property blob, so producing them
/// costs one extra decode per record. That cost is paid only while building or
/// rebuilding the index — never while reading one — which is the whole point of
/// having it.
fn appendIndexRow(
    builder: *Index.Builder,
    allocator: std.mem.Allocator,
    record: PersistedRecord,
    durable_parent: ?u64,
    offset: usize,
    length: usize,
) !void {
    var properties = std.json.parseFromSlice(
        FindPropertiesProjection,
        allocator,
        record.node.properties,
        .{ .allocate = .alloc_always, .ignore_unknown_fields = true },
    ) catch return error.CorruptGraph;
    defer properties.deinit();
    const projected = properties.value;
    // The builder interns (copies) every string, so borrowing from the parse
    // that is about to be freed is safe. Values are passed through verbatim,
    // including empty ones, so index-backed selection matches the scan exactly.
    try builder.append(.{
        .durable_event_id = record.node.id,
        .source_event_id = record.node.source_event_id,
        .sequence = record.sequence,
        .session_id = record.session_id,
        .durable_parent_id = durable_parent,
        .offset = offset,
        .length = length,
        .node_kind = record.node.kind,
        .columns = .{
            .label = projected.label,
            .status = projected.status,
            .service_key = projected.service_key,
            .type_name = projected.type_name,
            .kind = projected.kind,
            .requirement_id = projected.context.requirement_id,
            .acceptance_check_id = projected.context.acceptance_check_id,
            .scenario_id = projected.context.scenario_id,
            .run_id = projected.run_id,
        },
    });
}

fn projectionMatches(projection: FindPropertiesProjection, filter: FindFilter) bool {
    return matchesText(filter.label, projection.label) and
        matchesText(filter.kind, projection.kind) and
        matchesText(filter.status, projection.status) and
        matchesText(filter.service_key, projection.service_key) and
        matchesId(filter.requirement_id, projection.context.requirement_id) and
        matchesId(filter.acceptance_check_id, projection.context.acceptance_check_id) and
        matchesId(filter.scenario_id, projection.context.scenario_id);
}

/// Decode one durable row, and append its flattened projection when it matches.
/// Shared by the live database and the read-only snapshot so both expose exactly
/// the same selection semantics and output shape.
fn appendFindRowIfMatch(
    rows: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    entry: IndexEntry,
    row: []const u8,
    filter: FindFilter,
    separate: bool,
) !bool {
    var persisted = std.json.parseFromSlice(PersistedRecord, allocator, row, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch
        return error.CorruptGraph;
    defer persisted.deinit();
    var properties = std.json.parseFromSlice(
        FindPropertiesProjection,
        allocator,
        persisted.value.node.properties,
        .{ .allocate = .alloc_always, .ignore_unknown_fields = true },
    ) catch return error.CorruptGraph;
    defer properties.deinit();
    if (!projectionMatches(properties.value, filter)) return false;

    if (separate) try rows.append(allocator, ',');
    try appendFindRow(rows, allocator, entry, persisted.value, properties.value);
    return true;
}

fn findResultJsonAlloc(
    allocator: std.mem.Allocator,
    rows: []const u8,
    after_durable_event_id: u64,
    last_scanned: ?u64,
    scanned: usize,
    matched: usize,
    truncated: bool,
) ![]u8 {
    const next_json = if (truncated and last_scanned != null)
        try std.fmt.allocPrint(allocator, "{d}", .{last_scanned.?})
    else
        try allocator.dupe(u8, "null");
    defer allocator.free(next_json);

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    const header = try std.fmt.allocPrint(
        allocator,
        "{{\"schema\":\"{s}\",\"schema_version\":{d},\"after_event_id\":{d},\"next_after_event_id\":{s},\"scanned\":{d},\"matched\":{d},\"truncated\":{s},\"records\":[",
        .{
            find_schema,
            find_schema_version,
            after_durable_event_id,
            next_json,
            scanned,
            matched,
            if (truncated) "true" else "false",
        },
    );
    defer allocator.free(header);
    try output.appendSlice(allocator, header);
    try output.appendSlice(allocator, rows);
    try output.appendSlice(allocator, "]}");
    return output.toOwnedSlice(allocator);
}

/// Resolve a filter's text to its interned id.
///
/// A value the log never recorded has no id, which lets a selection that cannot
/// match anything say so without touching a single entry.
fn internedId(view: Index.View, text: []const u8) ?u32 {
    var cursor: usize = 0;
    while (cursor + 2 <= view.strings.len) {
        const length = std.mem.bytesToValue(u16, view.strings[cursor..][0..2]);
        const start = cursor + 2;
        if (start + length > view.strings.len) return null;
        if (std.mem.eql(u8, view.strings[start..][0..length], text)) return @intCast(cursor);
        cursor = start + length;
    }
    return null;
}

/// A filter pre-resolved against one index, so matching is integer comparison.
const IndexedFilter = struct {
    label_id: ?u32 = null,
    kind_id: ?u32 = null,
    status_id: ?u32 = null,
    service_key_id: ?u32 = null,
    requirement_id: ?u64 = null,
    acceptance_check_id: ?u64 = null,
    scenario_id: ?u64 = null,
    /// Set when a requested value is absent from the string table entirely.
    impossible: bool = false,

    fn resolve(view: Index.View, filter: FindFilter) IndexedFilter {
        var resolved = IndexedFilter{
            .requirement_id = filter.requirement_id,
            .acceptance_check_id = filter.acceptance_check_id,
            .scenario_id = filter.scenario_id,
        };
        inline for (.{
            .{ "label", "label_id" },
            .{ "kind", "kind_id" },
            .{ "status", "status_id" },
            .{ "service_key", "service_key_id" },
        }) |pair| {
            if (@field(filter, pair[0])) |text| {
                if (internedId(view, text)) |id| {
                    @field(resolved, pair[1]) = id;
                } else {
                    resolved.impossible = true;
                }
            }
        }
        return resolved;
    }

    fn matches(self: IndexedFilter, entry: Index.Entry) bool {
        if (self.label_id) |id| if (entry.label_id != id) return false;
        if (self.kind_id) |id| if (entry.kind_id != id) return false;
        if (self.status_id) |id| if (entry.status_id != id) return false;
        if (self.service_key_id) |id| if (entry.service_key_id != id) return false;
        if (self.requirement_id) |id| if (entry.requirement_id != id) return false;
        if (self.acceptance_check_id) |id| if (entry.acceptance_check_id != id) return false;
        if (self.scenario_id) |id| if (entry.scenario_id != id) return false;
        return true;
    }
};

/// Emit a match straight from index columns. Byte-identical to the decoding
/// path, which the equivalence test enforces.
fn appendIndexedFindRow(
    rows: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    view: Index.View,
    entry: Index.Entry,
) !void {
    const head = try std.fmt.allocPrint(
        allocator,
        "{{\"durable_event_id\":{d},\"source_event_id\":{d},\"sequence\":{d},\"session_id\":{d}," ++
            "\"kind\":\"{s}\",\"label\":\"{s}\",\"status\":\"{s}\",\"service_key\":\"{s}\",\"type_name\":\"{s}\"",
        .{
            entry.durable_event_id,
            entry.source_event_id,
            entry.sequence,
            entry.session_id,
            view.text(entry.kind_id) orelse "",
            view.text(entry.label_id) orelse "",
            view.text(entry.status_id) orelse "",
            view.text(entry.service_key_id) orelse "",
            view.text(entry.type_name_id) orelse "",
        },
    );
    defer allocator.free(head);
    try rows.appendSlice(allocator, head);
    // Zero is the index's encoding of absent for every one of these: durable
    // ids are never zero, and stableCausalContextId never returns zero.
    try appendOptionalId(rows, allocator, "run_id", if (entry.run_id == 0) null else entry.run_id);
    try appendOptionalId(rows, allocator, "durable_parent_id", if (entry.durable_parent_id == Index.no_parent) null else entry.durable_parent_id);
    try appendOptionalId(rows, allocator, "requirement_id", if (entry.requirement_id == 0) null else entry.requirement_id);
    try appendOptionalId(rows, allocator, "acceptance_check_id", if (entry.acceptance_check_id == 0) null else entry.acceptance_check_id);
    try appendOptionalId(rows, allocator, "scenario_id", if (entry.scenario_id == 0) null else entry.scenario_id);
    try rows.append(allocator, '}');
}

const LoadedIndex = struct {
    entries: []IndexEntry,
    edge_count: usize,
    covered_bytes: usize,
    /// Retained so selective queries can read the semantic columns without
    /// decoding a single record. Owned by the snapshot.
    raw: []u8,
};

/// Load the derived index only if it provably describes `content`.
///
/// Returns null for every reason an index might not be usable — absent, written
/// by an incompatible build, corrupt, describing a different log, or describing
/// only a prefix of one that has since grown. There is a single correct response
/// to all of them, which is to decode the log instead, so they are not
/// distinguished. The index is never allowed to be a second source of truth: it
/// only ever saves the work of deriving what the log already says.
fn loadVerifiedIndex(
    allocator: std.mem.Allocator,
    io: std.Io,
    graph_dir: std.Io.Dir,
    options: Options,
    content: []const u8,
) !?LoadedIndex {
    const raw = graph_dir.readFileAlloc(io, options.index_name, allocator, .limited(options.max_wal_bytes)) catch
        return null;
    var keep_raw = false;
    defer if (!keep_raw) allocator.free(raw);

    const view = Index.parse(raw) catch return null;
    const covered: usize = @intCast(view.header.covered_bytes);
    // A log that has grown past the index has a tail this stage does not read.
    // Decoding the whole log is correct and is what the writer's next flush
    // will make unnecessary.
    if (covered != content.len) return null;
    if (!Index.coversPrefix(view, content.len, content[0..covered])) return null;
    if (view.entries.len > options.max_records) return null;

    const entries = try allocator.alloc(IndexEntry, view.entries.len);
    errdefer allocator.free(entries);
    for (view.entries, 0..) |entry, position| {
        // The index is a cache of a validated scan, but it is still a file on
        // disk: anything that would make a reader read outside the log, or
        // binary-search a non-monotonic array, is treated as corruption.
        if (entry.offset + entry.length > content.len) return null;
        if (position != 0 and entry.durable_event_id <= entries[position - 1].durable_event_id) return null;
        entries[position] = .{
            .sequence = entry.sequence,
            .session_id = entry.session_id,
            .durable_event_id = entry.durable_event_id,
            .source_event_id = entry.source_event_id,
            .durable_parent_id = if (entry.durable_parent_id == Index.no_parent) null else entry.durable_parent_id,
            .offset = @intCast(entry.offset),
            .length = @intCast(entry.length),
        };
    }
    keep_raw = true;
    return .{
        .entries = entries,
        .edge_count = @intCast(view.header.edge_count),
        .covered_bytes = covered,
        .raw = raw,
    };
}

fn validateFindQuery(filter: FindFilter, limit: usize, scan_limit: usize) !void {
    if (filter.isEmpty() or limit == 0 or limit > 4096 or scan_limit == 0 or scan_limit > max_records) {
        return error.InvalidGraphOptions;
    }
}

fn persistedRowContainsLineage(
    allocator: std.mem.Allocator,
    row: []const u8,
    reference: fx.Lineage.Ref,
) !bool {
    var persisted = std.json.parseFromSlice(PersistedRecord, allocator, row, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch
        return error.CorruptGraph;
    defer persisted.deinit();
    var properties = std.json.parseFromSlice(
        LineagePropertiesProjection,
        allocator,
        persisted.value.node.properties,
        .{ .allocate = .alloc_always, .ignore_unknown_fields = true },
    ) catch return error.CorruptGraph;
    defer properties.deinit();
    for (properties.value.context.lineage.refs) |candidate| {
        if (candidate.sameIdentity(reference)) return true;
    }
    return false;
}

pub const Snapshot = struct {
    allocator: std.mem.Allocator,
    path: []u8,
    wal_name: []u8,
    content: []u8,
    entries: []IndexEntry,
    edge_count: usize,
    last_complete_offset: usize,
    /// Present only when this snapshot was opened from a verified index.
    index_raw: ?[]u8 = null,
    /// Child adjacency over `entries`. Built once at open because it is two
    /// small contiguous arrays — 4 bytes per node and per edge — and every
    /// traversal afterwards is a slice rather than a pass over every record.
    topology: Engine.Topology,

    /// Construct a read-only zero cursor for a project that has not executed
    /// yet. This deliberately allocates no graph directory or WAL.
    pub fn empty(allocator: std.mem.Allocator, options: Options) !Snapshot {
        try options.validate();
        const path = try allocator.dupe(u8, options.path);
        errdefer allocator.free(path);
        const wal_name = try allocator.dupe(u8, options.wal_name);
        errdefer allocator.free(wal_name);
        const content = try allocator.alloc(u8, 0);
        errdefer allocator.free(content);
        const entries = try allocator.alloc(IndexEntry, 0);
        return .{
            .allocator = allocator,
            .path = path,
            .wal_name = wal_name,
            .content = content,
            .entries = entries,
            .edge_count = 0,
            .last_complete_offset = 0,
            // An empty topology still allocates its terminator, so traversal
            // over a project that has never executed answers EventNotFound
            // rather than needing a special case.
            .topology = try Engine.Topology.build(allocator, entries),
        };
    }

    pub fn open(
        allocator: std.mem.Allocator,
        io: std.Io,
        root: std.Io.Dir,
        options: Options,
    ) !Snapshot {
        try options.validate();
        var graph_dir = try root.openDir(io, options.path, .{ .follow_symlinks = false });
        defer graph_dir.close(io);
        const content = try graph_dir.readFileAlloc(io, options.wal_name, allocator, .limited(options.max_wal_bytes));
        errdefer allocator.free(content);
        const path = try allocator.dupe(u8, options.path);
        errdefer allocator.free(path);
        const wal_name = try allocator.dupe(u8, options.wal_name);
        errdefer allocator.free(wal_name);

        // Reading the log is free; decoding it is the entire cost. When a
        // verified index describes exactly these bytes, the decode is skipped.
        if (try loadVerifiedIndex(allocator, io, graph_dir, options, content)) |loaded| {
            return .{
                .allocator = allocator,
                .path = path,
                .wal_name = wal_name,
                .content = content,
                .entries = loaded.entries,
                .edge_count = loaded.edge_count,
                .last_complete_offset = loaded.covered_bytes,
                .index_raw = loaded.raw,
                .topology = try Engine.Topology.build(allocator, loaded.entries),
            };
        }

        var scan = try scanContent(allocator, content, options, null);
        defer scan.deinit(allocator);
        const entries = try scan.entries.toOwnedSlice(allocator);
        return .{
            .allocator = allocator,
            .path = path,
            .wal_name = wal_name,
            .content = content,
            .entries = entries,
            .edge_count = scan.edge_count,
            .last_complete_offset = scan.last_complete_offset,
            .topology = try Engine.Topology.build(allocator, entries),
        };
    }

    pub fn deinit(self: *Snapshot) void {
        self.topology.deinit(self.allocator);
        if (self.index_raw) |raw| self.allocator.free(raw);
        self.allocator.free(self.entries);
        self.allocator.free(self.content);
        self.allocator.free(self.wal_name);
        self.allocator.free(self.path);
        self.* = undefined;
    }

    pub fn summary(self: *const Snapshot) Summary {
        return summaryFromEntries(
            self.path,
            self.wal_name,
            self.entries,
            self.edge_count,
            self.content.len,
            self.content.len - self.last_complete_offset,
        );
    }

    pub fn summaryJsonAlloc(self: *const Snapshot, allocator: std.mem.Allocator) ![]u8 {
        return std.json.Stringify.valueAlloc(allocator, self.summary(), .{});
    }

    pub fn recordJsonAlloc(self: *const Snapshot, allocator: std.mem.Allocator, durable_event_id: u64) ![]u8 {
        const entry = findEntry(self.entries, durable_event_id) orelse return error.EventNotFound;
        return allocator.dupe(u8, self.content[entry.offset .. entry.offset + entry.length]);
    }

    pub fn recordsAfterJsonAlloc(
        self: *const Snapshot,
        allocator: std.mem.Allocator,
        after_durable_event_id: u64,
        limit: usize,
    ) ![]u8 {
        const range = try recordsAfterRange(self.entries, after_durable_event_id, limit);
        return recordsAfterJsonFromContentAlloc(
            allocator,
            self.content,
            self.entries,
            range,
            after_durable_event_id,
        );
    }

    /// Read-only counterpart of `LocalDatabase.findRecordsJsonAlloc`, used by the
    /// CLI so an agent can select causal evidence without opening the live graph.
    pub fn findRecordsJsonAlloc(
        self: *const Snapshot,
        allocator: std.mem.Allocator,
        filter: FindFilter,
        after_durable_event_id: u64,
        limit: usize,
        scan_limit: usize,
    ) ![]u8 {
        try validateFindQuery(filter, limit, scan_limit);
        const range = try recordsAfterRange(self.entries, after_durable_event_id, scan_limit);
        var rows: std.ArrayList(u8) = .empty;
        defer rows.deinit(allocator);

        // With a verified index the semantic columns are already materialised,
        // so selection compares integers instead of decoding two JSON documents
        // for every candidate row.
        if (self.index_raw) |raw| indexed: {
            const view = Index.parse(raw) catch break :indexed;
            if (view.entries.len != self.entries.len) break :indexed;
            const resolved = IndexedFilter.resolve(view, filter);

            var scanned: usize = 0;
            var matched: usize = 0;
            var last_scanned: ?u64 = null;
            var stopped_early = false;
            if (!resolved.impossible) {
                for (view.entries[range.start..range.end], 0..) |entry, relative_index| {
                    scanned += 1;
                    last_scanned = entry.durable_event_id;
                    if (!resolved.matches(entry)) continue;
                    if (matched != 0) try rows.append(allocator, ',');
                    try appendIndexedFindRow(&rows, allocator, view, entry);
                    matched += 1;
                    if (matched == limit) {
                        stopped_early = relative_index + 1 < range.end - range.start;
                        break;
                    }
                }
            } else {
                // A value the log never recorded cannot match, but pagination
                // must still advance exactly as a scan would have.
                scanned = range.end - range.start;
                if (scanned != 0) last_scanned = view.entries[range.end - 1].durable_event_id;
            }

            return findResultJsonAlloc(
                allocator,
                rows.items,
                after_durable_event_id,
                last_scanned,
                scanned,
                matched,
                stopped_early or range.truncated,
            );
        }

        var scanned: usize = 0;
        var matched: usize = 0;
        var last_scanned: ?u64 = null;
        var stopped_early = false;
        for (self.entries[range.start..range.end], 0..) |entry, relative_index| {
            const row = self.content[entry.offset .. entry.offset + entry.length];
            scanned += 1;
            last_scanned = entry.durable_event_id;
            if (try appendFindRowIfMatch(&rows, allocator, entry, row, filter, matched != 0)) {
                matched += 1;
                if (matched == limit) {
                    stopped_early = relative_index + 1 < range.end - range.start;
                    break;
                }
            }
        }

        return findResultJsonAlloc(
            allocator,
            rows.items,
            after_durable_event_id,
            last_scanned,
            scanned,
            matched,
            stopped_early or range.truncated,
        );
    }

    pub fn childrenAlloc(self: *const Snapshot, allocator: std.mem.Allocator, durable_event_id: u64) ![]u64 {
        return self.topology.childrenAlloc(allocator, durable_event_id);
    }

    /// One node's indexed columns, resolved.
    ///
    /// The storage engine exposes columns; it deliberately does not own a
    /// predicate language. Deciding what "matches" is the query layer's job, so
    /// this returns the materialised values and lets a caller compose them.
    pub const NodeView = struct {
        durable_event_id: u64,
        session_id: u64,
        label: []const u8,
        kind: []const u8,
        status: []const u8,
        service_key: []const u8,
        type_name: []const u8,
        requirement_id: u64,
        acceptance_check_id: u64,
        scenario_id: u64,
        run_id: u64,
    };

    pub fn nodeCount(self: *const Snapshot) usize {
        return self.entries.len;
    }

    /// Columns for the node at `position`, without decoding the log.
    ///
    /// Null when this snapshot was opened by replay rather than from an index,
    /// because then the semantic columns were never materialised. A caller that
    /// needs them should say so rather than silently receive empty strings.
    pub fn nodeAt(self: *const Snapshot, position: usize) ?NodeView {
        if (position >= self.entries.len) return null;
        const raw = self.index_raw orelse return null;
        const view = Index.parse(raw) catch return null;
        if (position >= view.entries.len) return null;
        const entry = view.entries[position];
        if (entry.durable_event_id != self.entries[position].durable_event_id) return null;
        return .{
            .durable_event_id = entry.durable_event_id,
            .session_id = entry.session_id,
            .label = view.text(entry.label_id) orelse "",
            .kind = view.text(entry.kind_id) orelse "",
            .status = view.text(entry.status_id) orelse "",
            .service_key = view.text(entry.service_key_id) orelse "",
            .type_name = view.text(entry.type_name_id) orelse "",
            .requirement_id = entry.requirement_id,
            .acceptance_check_id = entry.acceptance_check_id,
            .scenario_id = entry.scenario_id,
            .run_id = entry.run_id,
        };
    }

    /// Everything this event caused, directly or transitively.
    pub fn descendantsAlloc(
        self: *const Snapshot,
        allocator: std.mem.Allocator,
        durable_event_id: u64,
        options: Engine.TraversalOptions,
    ) !Engine.Traversal {
        return self.topology.descendantsAlloc(allocator, durable_event_id, options);
    }

    /// The chain of causes above this event, nearest parent first.
    pub fn ancestorsAlloc(
        self: *const Snapshot,
        allocator: std.mem.Allocator,
        durable_event_id: u64,
        options: Engine.TraversalOptions,
    ) !Engine.Traversal {
        return self.topology.ancestorsAlloc(allocator, durable_event_id, options);
    }

    pub fn pathAlloc(
        self: *const Snapshot,
        allocator: std.mem.Allocator,
        from_event_id: u64,
        to_event_id: u64,
        max_events: usize,
    ) !Path {
        return pathFromEntriesAlloc(allocator, self.entries, from_event_id, to_event_id, max_events);
    }

    pub fn pathJsonAlloc(
        self: *const Snapshot,
        allocator: std.mem.Allocator,
        from_event_id: u64,
        to_event_id: u64,
        max_events: usize,
    ) ![]u8 {
        var path = try self.pathAlloc(allocator, from_event_id, to_event_id, max_events);
        defer path.deinit();
        return path.jsonAlloc(allocator);
    }
};

fn pathFromEntriesAlloc(
    allocator: std.mem.Allocator,
    entries: []const IndexEntry,
    from_event_id: u64,
    to_event_id: u64,
    max_events: usize,
) !Path {
    if (from_event_id == 0 or to_event_id == 0) return error.EventNotFound;
    if (max_events < 1 or max_events > 4096) return error.InvalidPathLimit;
    var from_found = false;
    var to_found = false;
    for (entries) |entry| {
        from_found = from_found or entry.durable_event_id == from_event_id;
        to_found = to_found or entry.durable_event_id == to_event_id;
    }
    if (!from_found or !to_found) return error.EventNotFound;

    var reverse = std.ArrayList(u64).empty;
    errdefer reverse.deinit(allocator);
    var cursor: ?u64 = to_event_id;
    while (cursor) |event_id| {
        if (reverse.items.len >= max_events) return error.PathNotFound;
        try reverse.append(allocator, event_id);
        if (event_id == from_event_id) {
            std.mem.reverse(u64, reverse.items);
            return .{
                .allocator = allocator,
                .from_event_id = from_event_id,
                .to_event_id = to_event_id,
                .event_ids = try reverse.toOwnedSlice(allocator),
            };
        }
        var parent: ?u64 = null;
        for (entries) |entry| {
            if (entry.durable_event_id != event_id) continue;
            parent = entry.durable_parent_id;
            break;
        }
        cursor = parent;
    }
    return error.PathNotFound;
}

pub fn childrenJsonAlloc(allocator: std.mem.Allocator, durable_event_id: u64, children: []const u64) ![]u8 {
    return std.json.Stringify.valueAlloc(allocator, .{
        .schema = children_schema,
        .schema_version = children_schema_version,
        .event_id = durable_event_id,
        .children = children,
    }, .{});
}

fn writeAdapter(raw: ?*anyopaque, write: fx.CausalNendbWrite) anyerror!void {
    const self: *LocalDatabase = @ptrCast(@alignCast(raw.?));
    try self.appendWrite(write);
}

fn flushAdapter(raw: ?*anyopaque) anyerror!void {
    const self: *LocalDatabase = @ptrCast(@alignCast(raw.?));
    try self.flush();
}

fn formatRecordAlloc(allocator: std.mem.Allocator, record: PersistedRecord) ![]u8 {
    return std.json.Stringify.valueAlloc(allocator, record, .{});
}

/// Validate and index the log.
///
/// `index_builder`, when supplied, is populated in this same pass so that
/// building the derived index costs no additional traversal of the log.
fn scanContent(
    allocator: std.mem.Allocator,
    content: []const u8,
    options: Options,
    index_builder: ?*Index.Builder,
) !ScanResult {
    var result = ScanResult{};
    errdefer result.deinit(allocator);
    try scanContentInto(&result, allocator, content, options, 0, index_builder);
    return result;
}

/// Validate `content` into an existing, possibly pre-seeded, result.
///
/// `base_offset` is added to every recorded byte position, which is what lets a
/// caller that already restored a prefix from the index validate only the bytes
/// beyond it. All invariant checking lives here so a resumed scan cannot enforce
/// a weaker contract than a full one.
fn scanContentInto(
    result: *ScanResult,
    allocator: std.mem.Allocator,
    content: []const u8,
    options: Options,
    base_offset: usize,
    index_builder: ?*Index.Builder,
) !void {
    var line_start: usize = 0;
    while (std.mem.indexOfScalarPos(u8, content, line_start, '\n')) |newline| {
        const line = content[line_start..newline];
        if (line.len == 0 or line.len > options.max_record_bytes or result.entries.items.len >= options.max_records) {
            return error.CorruptGraph;
        }
        var parsed = std.json.parseFromSlice(PersistedRecord, allocator, line, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch return error.CorruptGraph;
        defer parsed.deinit();
        parsed.value.validate() catch |err| switch (err) {
            error.SecretDetected => return error.SecretDetected,
            error.UnsupportedGraphSchema => return error.UnsupportedGraphSchema,
            else => return error.CorruptGraph,
        };
        const expected_sequence = @as(u64, @intCast(result.entries.items.len)) + 1;
        if (parsed.value.sequence != expected_sequence or
            parsed.value.session_id < result.max_session_id or
            parsed.value.node.id <= result.max_durable_event_id)
        {
            return error.CorruptGraph;
        }
        if (parsed.value.session_id == result.max_session_id and
            parsed.value.node.source_event_id <= result.last_source_event_id)
        {
            return error.CorruptGraph;
        }
        const durable_parent = if (parsed.value.parent_edge) |edge| parent: {
            const parent_entry = result.seen_nodes.get(edge.from) orelse return error.CorruptGraph;
            if (parent_entry.session_id != parsed.value.session_id or parent_entry.source_event_id != edge.source_from) {
                return error.CorruptGraph;
            }
            result.edge_count += 1;
            break :parent edge.from;
        } else null;
        try result.entries.append(allocator, .{
            .sequence = parsed.value.sequence,
            .session_id = parsed.value.session_id,
            .durable_event_id = parsed.value.node.id,
            .source_event_id = parsed.value.node.source_event_id,
            .durable_parent_id = durable_parent,
            .offset = base_offset + line_start,
            .length = line.len,
        });
        if (index_builder) |builder| {
            try appendIndexRow(builder, allocator, parsed.value, durable_parent, base_offset + line_start, line.len);
        }
        try result.seen_nodes.put(allocator, parsed.value.node.id, .{
            .session_id = parsed.value.session_id,
            .source_event_id = parsed.value.node.source_event_id,
        });
        if (parsed.value.session_id != result.max_session_id) result.last_source_event_id = 0;
        result.max_session_id = @max(result.max_session_id, parsed.value.session_id);
        result.last_source_event_id = parsed.value.node.source_event_id;
        result.max_durable_event_id = parsed.value.node.id;
        line_start = newline + 1;
        result.last_complete_offset = base_offset + line_start;
    }
}

fn summaryFromEntries(
    path: []const u8,
    wal_name: []const u8,
    entries: []const IndexEntry,
    edge_count: usize,
    wal_bytes: usize,
    partial_bytes: usize,
) Summary {
    var sessions: u64 = 0;
    for (entries) |entry| sessions = @max(sessions, entry.session_id);
    return .{
        .path = path,
        .wal_name = wal_name,
        .records = entries.len,
        .edges = edge_count,
        .sessions = sessions,
        .newest_durable_event_id = if (entries.len == 0) null else entries[entries.len - 1].durable_event_id,
        .wal_bytes = wal_bytes,
        .trailing_partial_bytes = partial_bytes,
        .engine_nodes = entries.len,
        .engine_edges = edge_count,
    };
}

fn findEntry(entries: []const IndexEntry, durable_event_id: u64) ?IndexEntry {
    var low: usize = 0;
    var high: usize = entries.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        const candidate = entries[middle];
        if (candidate.durable_event_id < durable_event_id) {
            low = middle + 1;
        } else if (candidate.durable_event_id > durable_event_id) {
            high = middle;
        } else {
            return candidate;
        }
    }
    return null;
}

const RecordRange = struct {
    start: usize,
    end: usize,
    next_event_id: ?u64,
    truncated: bool,
};

fn recordsAfterRange(entries: []const IndexEntry, after_durable_event_id: u64, limit: usize) !RecordRange {
    if (limit == 0) return error.InvalidGraphOptions;
    const start = if (after_durable_event_id == 0) @as(usize, 0) else start: {
        var low: usize = 0;
        var high: usize = entries.len;
        while (low < high) {
            const middle = low + (high - low) / 2;
            const candidate = entries[middle].durable_event_id;
            if (candidate < after_durable_event_id) {
                low = middle + 1;
            } else if (candidate > after_durable_event_id) {
                high = middle;
            } else {
                break :start middle + 1;
            }
        }
        return error.EventNotFound;
    };
    const end = @min(entries.len, start +| limit);
    return .{
        .start = start,
        .end = end,
        .next_event_id = if (end == start) null else entries[end - 1].durable_event_id,
        .truncated = end < entries.len,
    };
}

fn recordsAfterJsonFromContentAlloc(
    allocator: std.mem.Allocator,
    content: []const u8,
    entries: []const IndexEntry,
    range: RecordRange,
    after_durable_event_id: u64,
) ![]u8 {
    const next_json = if (range.next_event_id) |id|
        try std.fmt.allocPrint(allocator, "{d}", .{id})
    else
        try allocator.dupe(u8, "null");
    defer allocator.free(next_json);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    const header = try std.fmt.allocPrint(
        allocator,
        "{{\"schema\":\"{s}\",\"schema_version\":{d},\"after_event_id\":{d},\"next_event_id\":{s},\"truncated\":{s},\"records\":[",
        .{ records_since_schema, records_since_schema_version, after_durable_event_id, next_json, if (range.truncated) "true" else "false" },
    );
    defer allocator.free(header);
    try output.appendSlice(allocator, header);
    for (entries[range.start..range.end], 0..) |entry, index| {
        if (index != 0) try output.append(allocator, ',');
        try output.appendSlice(allocator, content[entry.offset .. entry.offset + entry.length]);
    }
    try output.appendSlice(allocator, "]}");
    return output.toOwnedSlice(allocator);
}

fn childrenFromEntriesAlloc(allocator: std.mem.Allocator, entries: []const IndexEntry, durable_event_id: u64) ![]u64 {
    if (findEntry(entries, durable_event_id) == null) return error.EventNotFound;
    var count: usize = 0;
    for (entries) |entry| if (entry.durable_parent_id == durable_event_id) {
        count += 1;
    };
    const children = try allocator.alloc(u64, count);
    var index: usize = 0;
    for (entries) |entry| if (entry.durable_parent_id == durable_event_id) {
        children[index] = entry.durable_event_id;
        index += 1;
    };
    return children;
}

fn ensureSafe(value: []const u8) !void {
    if (Secrets.containsSecret(value)) return error.SecretDetected;
}

fn validateNodeProperties(
    properties: []const u8,
    source_event_id: u64,
    label: []const u8,
    kind: u8,
) !void {
    var parsed = std.json.parseFromSlice(NodePropertiesHeader, std.heap.page_allocator, properties, .{
        .allocate = .alloc_if_needed,
        .ignore_unknown_fields = true,
    }) catch return error.InvalidGraphRecord;
    defer parsed.deinit();
    if (!std.mem.eql(u8, parsed.value.schema, fx.causal_nendb_node_schema) or
        parsed.value.schema_version != fx.causal_nendb_node_schema_version or
        parsed.value.event_id != source_event_id or
        !std.mem.eql(u8, label, "causal_event") or
        kind != fx.stableCausalNendbLabelId(parsed.value.kind))
    {
        return error.InvalidGraphRecord;
    }
}

fn validateEdgeProperties(properties: []const u8, source_from: u64, source_to: u64) !void {
    var parsed = std.json.parseFromSlice(EdgePropertiesHeader, std.heap.page_allocator, properties, .{
        .allocate = .alloc_if_needed,
        .ignore_unknown_fields = true,
    }) catch return error.InvalidGraphRecord;
    defer parsed.deinit();
    if (!std.mem.eql(u8, parsed.value.schema, fx.causal_nendb_edge_schema) or
        parsed.value.schema_version != fx.causal_nendb_edge_schema_version or
        parsed.value.from_event_id != source_from or
        parsed.value.to_event_id != source_to)
    {
        return error.InvalidGraphRecord;
    }
}

fn testRecord(source_id: u64, parent_id: ?u64, detail: []const u8) fx.CausalEvent {
    return .{
        .kind = if (parent_id == null) .effect_started else .effect_completed,
        .parent_id = parent_id,
        .label = "test",
        .status = if (parent_id == null) "running" else "success",
        .redacted_detail = detail,
        .id = source_id,
    };
}

test "local causal graph persists restart-safe sessions and parent traversal" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var first_durable_id: u64 = 0;
    {
        var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{});
        defer database.deinit();
        var backend = database.storageBackend(std.testing.allocator, 16);
        defer backend.deinit();
        var store = fx.CausalStore.init(std.testing.allocator);
        defer store.deinit();
        store.attachBackend(backend.backend());
        const first = try store.record(testRecord(0, null, "safe"));
        const second = try store.record(testRecord(0, first, "safe"));
        try backend.flush();
        try std.testing.expectEqual(@as(u64, 0), store.backendFailureCount());
        try std.testing.expectEqual(@as(usize, 2), database.recordCount());
        try std.testing.expectEqual(@as(usize, 1), database.edgeCount());
        first_durable_id = database.durableId(first).?;
        const second_durable_id = database.durableId(second).?;
        const children = try database.childrenAlloc(std.testing.allocator, first_durable_id);
        defer std.testing.allocator.free(children);
        try std.testing.expectEqualSlices(u64, &.{second_durable_id}, children);
    }
    {
        var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{});
        defer database.deinit();
        try std.testing.expectEqual(@as(usize, 2), database.recordCount());
        try std.testing.expectEqual(@as(u64, 2), database.currentSessionId());
        var backend = database.storageBackend(std.testing.allocator, 16);
        defer backend.deinit();
        var store = fx.CausalStore.init(std.testing.allocator);
        defer store.deinit();
        store.attachBackend(backend.backend());
        const local = try store.record(testRecord(0, null, "second-session"));
        const durable = database.durableId(local).?;
        try std.testing.expect(durable > first_durable_id);
    }
    var snapshot = try Snapshot.open(std.testing.allocator, std.testing.io, tmp.dir, .{});
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 3), snapshot.summary().records);
    try std.testing.expectEqual(@as(u64, 2), snapshot.summary().sessions);
    const json = try snapshot.recordJsonAlloc(std.testing.allocator, first_durable_id);
    defer std.testing.allocator.free(json);
    var parsed = try std.json.parseFromSlice(PersistedRecord, std.testing.allocator, json, .{ .allocate = .alloc_always });
    defer parsed.deinit();
    try std.testing.expectEqual(first_durable_id, parsed.value.node.id);
}

test "local causal graph recovers only a trailing partial record" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    {
        var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{});
        defer database.deinit();
        var backend = database.storageBackend(std.testing.allocator, 4);
        defer backend.deinit();
        var store = fx.CausalStore.init(std.testing.allocator);
        defer store.deinit();
        store.attachBackend(backend.backend());
        _ = try store.record(testRecord(0, null, "safe"));
    }
    var graph_dir = try tmp.dir.openDir(std.testing.io, default_path, .{});
    defer graph_dir.close(std.testing.io);
    var file = try graph_dir.openFile(std.testing.io, default_wal_name, .{ .mode = .read_write });
    const offset = try file.length(std.testing.io);
    try file.writePositionalAll(std.testing.io, "{\"schema\":", offset);
    file.close(std.testing.io);
    var recovered = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{});
    defer recovered.deinit();
    try std.testing.expectEqual(@as(usize, 10), recovered.recoveredPartialBytes());
    try std.testing.expectEqual(@as(usize, 1), recovered.recordCount());
}

test "local causal graph fails closed for corruption limits and secrets" {
    var corrupt_tmp = std.testing.tmpDir(.{});
    defer corrupt_tmp.cleanup();
    try corrupt_tmp.dir.createDirPath(std.testing.io, default_path);
    try corrupt_tmp.dir.writeFile(std.testing.io, .{ .sub_path = default_path ++ "/" ++ default_wal_name, .data = "{}\n" });
    try std.testing.expectError(error.CorruptGraph, LocalDatabase.init(std.testing.allocator, std.testing.io, corrupt_tmp.dir, .{}));

    var limited_tmp = std.testing.tmpDir(.{});
    defer limited_tmp.cleanup();
    var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, limited_tmp.dir, .{ .max_records = 1 });
    defer database.deinit();
    var backend = database.storageBackend(std.testing.allocator, null);
    defer backend.deinit();
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    store.attachBackend(backend.backend());
    _ = try store.record(testRecord(0, null, "safe"));
    _ = try store.record(testRecord(0, null, "safe"));
    try std.testing.expectEqual(@as(u64, 1), store.backendFailureCount());
    try std.testing.expectEqual(@as(usize, 1), database.recordCount());

    var secret_tmp = std.testing.tmpDir(.{});
    defer secret_tmp.cleanup();
    var secret_database = try LocalDatabase.init(std.testing.allocator, std.testing.io, secret_tmp.dir, .{});
    defer secret_database.deinit();
    const secret_write = fx.CausalNendbWrite{ .node = .{
        .id = 9,
        .label = "causal_event",
        .kind = 1,
        .properties = "token=sentinel-secret-for-tests",
    } };
    try std.testing.expectError(error.SecretDetected, secret_database.appendWrite(secret_write));
}

test "causal graph record formatting releases every partial allocation" {
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const record = PersistedRecord{
                .sequence = 1,
                .session_id = 1,
                .node = .{
                    .id = 1,
                    .source_event_id = 1,
                    .label = "causal_event",
                    .kind = fx.stableCausalNendbLabelId("effect_started"),
                    .properties = "{\"schema\":\"zigeffect.causal.nendb_node.v1\",\"schema_version\":1,\"event_id\":1,\"kind\":\"effect_started\"}",
                },
            };
            const json = try formatRecordAlloc(allocator, record);
            allocator.free(json);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}

test "causal graph scan rejects duplicate source ids and cross-session parents" {
    const first = PersistedRecord{
        .sequence = 1,
        .session_id = 1,
        .node = .{
            .id = 1,
            .source_event_id = 1,
            .label = "causal_event",
            .kind = fx.stableCausalNendbLabelId("effect_started"),
            .properties = "{\"schema\":\"zigeffect.causal.nendb_node.v1\",\"schema_version\":1,\"event_id\":1,\"kind\":\"effect_started\"}",
        },
    };
    const duplicate = PersistedRecord{
        .sequence = 2,
        .session_id = 1,
        .node = .{
            .id = 2,
            .source_event_id = 1,
            .label = "causal_event",
            .kind = fx.stableCausalNendbLabelId("effect_started"),
            .properties = first.node.properties,
        },
    };
    const cross_session = PersistedRecord{
        .sequence = 2,
        .session_id = 2,
        .node = .{
            .id = 2,
            .source_event_id = 2,
            .label = "causal_event",
            .kind = fx.stableCausalNendbLabelId("effect_completed"),
            .properties = "{\"schema\":\"zigeffect.causal.nendb_node.v1\",\"schema_version\":1,\"event_id\":2,\"kind\":\"effect_completed\"}",
        },
        .parent_edge = .{
            .from = 1,
            .to = 2,
            .source_from = 1,
            .source_to = 2,
            .label = "causal_parent",
            .label_id = fx.stableCausalNendbEdgeLabelId("causal_parent"),
            .properties = "{\"schema\":\"zigeffect.causal.nendb_edge.v1\",\"schema_version\":1,\"from_event_id\":1,\"to_event_id\":2}",
        },
    };
    const first_json = try formatRecordAlloc(std.testing.allocator, first);
    defer std.testing.allocator.free(first_json);
    const duplicate_json = try formatRecordAlloc(std.testing.allocator, duplicate);
    defer std.testing.allocator.free(duplicate_json);
    const cross_json = try formatRecordAlloc(std.testing.allocator, cross_session);
    defer std.testing.allocator.free(cross_json);
    const duplicate_wal = try std.fmt.allocPrint(std.testing.allocator, "{s}\n{s}\n", .{ first_json, duplicate_json });
    defer std.testing.allocator.free(duplicate_wal);
    try std.testing.expectError(error.CorruptGraph, scanContent(std.testing.allocator, duplicate_wal, .{}, null));
    const cross_wal = try std.fmt.allocPrint(std.testing.allocator, "{s}\n{s}\n", .{ first_json, cross_json });
    defer std.testing.allocator.free(cross_wal);
    try std.testing.expectError(error.CorruptGraph, scanContent(std.testing.allocator, cross_wal, .{}, null));
}

test "causal graph rejects non-monotonic source ids before writing" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{});
    defer database.deinit();
    try database.appendWrite(.{ .node = .{
        .id = 2,
        .label = "causal_event",
        .kind = fx.stableCausalNendbLabelId("effect_started"),
        .properties = "{\"schema\":\"zigeffect.causal.nendb_node.v1\",\"schema_version\":1,\"event_id\":2,\"kind\":\"effect_started\"}",
    } });
    try std.testing.expectError(error.NonMonotonicSourceEvent, database.appendWrite(.{ .node = .{
        .id = 1,
        .label = "causal_event",
        .kind = fx.stableCausalNendbLabelId("effect_started"),
        .properties = "{\"schema\":\"zigeffect.causal.nendb_node.v1\",\"schema_version\":1,\"event_id\":1,\"kind\":\"effect_started\"}",
    } }));
    try std.testing.expectEqual(@as(usize, 1), database.recordCount());
}

test "causal graph validates projected node and edge metadata" {
    var invalid_node = PersistedRecord{
        .sequence = 1,
        .session_id = 1,
        .node = .{
            .id = 1,
            .source_event_id = 1,
            .label = "causal_event",
            .kind = fx.stableCausalNendbLabelId("effect_completed"),
            .properties = "{\"schema\":\"zigeffect.causal.nendb_node.v1\",\"schema_version\":1,\"event_id\":1,\"kind\":\"effect_started\"}",
        },
    };
    try std.testing.expectError(error.InvalidGraphRecord, invalid_node.validate());
    invalid_node.node.kind = fx.stableCausalNendbLabelId("effect_started");
    try invalid_node.validate();

    const invalid_edge = PersistedRecord{
        .sequence = 2,
        .session_id = 1,
        .node = .{
            .id = 2,
            .source_event_id = 2,
            .label = "causal_event",
            .kind = fx.stableCausalNendbLabelId("effect_completed"),
            .properties = "{\"schema\":\"zigeffect.causal.nendb_node.v1\",\"schema_version\":1,\"event_id\":2,\"kind\":\"effect_completed\"}",
        },
        .parent_edge = .{
            .from = 1,
            .to = 2,
            .source_from = 1,
            .source_to = 2,
            .label = "causal_parent",
            .label_id = fx.stableCausalNendbEdgeLabelId("causal_parent"),
            .properties = "{\"schema\":\"zigeffect.causal.nendb_edge.v1\",\"schema_version\":1,\"from_event_id\":1,\"to_event_id\":99}",
        },
    };
    try std.testing.expectError(error.InvalidGraphRecord, invalid_edge.validate());
}

test "durable causal graph returns bounded paginated typed lineage records" {
    const ProductId = fx.Lineage.Key([]const u8, .{
        .name = "commerce.product.id",
        .privacy = .internal,
        .propagation = .distributed,
        .export_policy = .otel,
    });
    const product = try ProductId.reference(77, "product-42");
    const lineage = fx.Lineage.Set.empty.with(product);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{});
    defer database.deinit();

    const events = [_]fx.CausalEvent{
        .{ .id = 1, .kind = .run_started, .label = "matching-start", .context = .{ .lineage = lineage } },
        .{ .id = 2, .kind = .activity_completed, .parent_id = 1, .label = "unrelated" },
        .{ .id = 3, .kind = .run_completed, .parent_id = 2, .label = "matching-end", .context = .{ .lineage = lineage } },
    };
    for (events) |event| {
        var write = try fx.mapCausalEventToNendbWrite(std.testing.allocator, event);
        defer fx.deinitCausalNendbWrite(std.testing.allocator, &write);
        try database.appendWrite(write);
    }

    const json = try database.lineageRecordsJsonAlloc(std.testing.allocator, product, 0, 8, 8);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "zigeffect.causal.local-graph-lineage.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "matching-start") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "matching-end") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "unrelated") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "product-42") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"scanned\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"matched\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"truncated\":false") != null);

    const first_page = try database.lineageRecordsJsonAlloc(std.testing.allocator, product, 0, 1, 8);
    defer std.testing.allocator.free(first_page);
    try std.testing.expect(std.mem.indexOf(u8, first_page, "\"next_after_event_id\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, first_page, "\"truncated\":true") != null);
    const second_page = try database.lineageRecordsJsonAlloc(std.testing.allocator, product, 1, 8, 8);
    defer std.testing.allocator.free(second_page);
    try std.testing.expect(std.mem.indexOf(u8, second_page, "matching-end") != null);
    try std.testing.expect(std.mem.indexOf(u8, second_page, "matching-start") == null);
}

test "the incrementally maintained index equals a full replay of the same log" {
    // The index is written by two different paths: appended row-by-row while a
    // process runs, and rebuilt wholesale when a log is opened. If those two ever
    // disagree, a reader that trusts the index sees something the log does not
    // say. This pins them together.
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const events = [_]fx.CausalEvent{
        .{ .id = 1, .kind = .run_started, .label = "run", .status = "running", .service_key = "application/A" },
        .{ .id = 2, .kind = .effect_completed, .parent_id = 1, .label = "A.create", .status = "success", .service_key = "application/A", .context = .{ .requirement_id = 77, .scenario_id = 88 } },
        .{ .id = 3, .kind = .effect_completed, .parent_id = 2, .label = "A.create", .status = "failure", .type_name = "Invalid" },
        .{ .id = 4, .kind = .run_completed, .parent_id = 3, .label = "run", .status = "success" },
    };

    var incremental_bytes: []u8 = undefined;
    {
        var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{});
        defer database.deinit();
        for (events) |event| {
            var write = try fx.mapCausalEventToNendbWrite(std.testing.allocator, event);
            defer fx.deinitCausalNendbWrite(std.testing.allocator, &write);
            try database.appendWrite(write);
        }
        try database.flush();
        // Captured from the builder that was maintained append-by-append.
        const content = try database.graph_dir.readFileAlloc(std.testing.io, default_wal_name, std.testing.allocator, .limited(1 << 20));
        defer std.testing.allocator.free(content);
        incremental_bytes = try database.index_builder.serializeAlloc(content.len, Index.digest(content));
    }
    defer std.testing.allocator.free(incremental_bytes);

    // Reopening replays the log and rebuilds the index from scratch.
    var reopened = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{});
    defer reopened.deinit();
    const content = try reopened.graph_dir.readFileAlloc(std.testing.io, default_wal_name, std.testing.allocator, .limited(1 << 20));
    defer std.testing.allocator.free(content);
    const replayed_bytes = try reopened.index_builder.serializeAlloc(content.len, Index.digest(content));
    defer std.testing.allocator.free(replayed_bytes);

    try std.testing.expectEqualSlices(u8, incremental_bytes, replayed_bytes);

    // And the index actually describes the log it claims to.
    const view = try Index.parse(replayed_bytes);
    try std.testing.expectEqual(@as(u32, 4), view.header.entry_count);
    try std.testing.expectEqual(@as(u64, 3), view.header.edge_count);
    try std.testing.expect(Index.coversPrefix(view, content.len, content));

    // Spot-check that semantic columns survived the projection.
    try std.testing.expectEqualStrings("A.create", view.text(view.entries[1].label_id).?);
    try std.testing.expectEqualStrings("success", view.text(view.entries[1].status_id).?);
    try std.testing.expectEqual(@as(u64, 77), view.entries[1].requirement_id);
    try std.testing.expectEqual(@as(u64, 88), view.entries[1].scenario_id);
    try std.testing.expectEqualStrings("failure", view.text(view.entries[2].status_id).?);
    try std.testing.expectEqualStrings("Invalid", view.text(view.entries[2].type_name_id).?);

    // Offsets must locate the real log line, since that is how a reader will
    // fetch full detail without decoding everything.
    const entry = view.entries[2];
    const line = content[entry.offset..][0..entry.length];
    // The property blob is stored as an escaped JSON string inside the record,
    // which is exactly why a reader needs the projected columns to filter on.
    try std.testing.expect(std.mem.indexOf(u8, line, "\\\"status\\\":\\\"failure\\\"") != null);

    // The persisted file must match what the builder produced.
    var graph_dir = try tmp.dir.openDir(std.testing.io, default_path, .{ .follow_symlinks = false });
    defer graph_dir.close(std.testing.io);
    const on_disk = try graph_dir.readFileAlloc(std.testing.io, Index.default_index_name, std.testing.allocator, .limited(1 << 20));
    defer std.testing.allocator.free(on_disk);
    try std.testing.expectEqualSlices(u8, incremental_bytes, on_disk);
}

test "an index covering only a prefix is completed by validating the tail" {
    // A process writes lifecycle records after its final flush, so in practice
    // the log is almost always longer than the index of it. If that case fell
    // back to a full replay, a service would never take the fast path at all —
    // which is exactly what measurement showed before this existed.
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    {
        var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{});
        defer database.deinit();
        var first = try fx.mapCausalEventToNendbWrite(std.testing.allocator, .{ .id = 1, .kind = .run_started, .label = "covered" });
        defer fx.deinitCausalNendbWrite(std.testing.allocator, &first);
        try database.appendWrite(first);
        // Index is persisted here...
        try database.flush();
        // ...and these land after it, exactly like shutdown lifecycle records.
        var second = try fx.mapCausalEventToNendbWrite(std.testing.allocator, .{ .id = 2, .kind = .activity_completed, .parent_id = 1, .label = "after-flush", .status = "success" });
        defer fx.deinitCausalNendbWrite(std.testing.allocator, &second);
        try database.appendWrite(second);
        var third = try fx.mapCausalEventToNendbWrite(std.testing.allocator, .{ .id = 3, .kind = .run_completed, .parent_id = 2, .label = "after-flush", .status = "success" });
        defer fx.deinitCausalNendbWrite(std.testing.allocator, &third);
        try database.appendWrite(third);
    }

    var graph_dir = try tmp.dir.openDir(std.testing.io, default_path, .{ .follow_symlinks = false });
    defer graph_dir.close(std.testing.io);
    const log = try graph_dir.readFileAlloc(std.testing.io, default_wal_name, std.testing.allocator, .limited(1 << 20));
    defer std.testing.allocator.free(log);
    const stale = try graph_dir.readFileAlloc(std.testing.io, Index.default_index_name, std.testing.allocator, .limited(1 << 20));
    defer std.testing.allocator.free(stale);
    const stale_view = try Index.parse(stale);
    // Precondition: the index really does cover only part of the log.
    try std.testing.expectEqual(@as(u32, 1), stale_view.header.entry_count);
    try std.testing.expect(stale_view.header.covered_bytes < log.len);

    // Scoped: the writer holds the log's exclusive lock, so the replay below
    // cannot open until this one is closed.
    var resumed_summary: []u8 = undefined;
    var resumed_index: []u8 = undefined;
    var resumed_session: u64 = 0;
    {
    var resumed = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{});
    defer resumed.deinit();
    try std.testing.expectEqual(@as(usize, 3), resumed.recordCount());
    try std.testing.expectEqual(@as(usize, 2), resumed.edgeCount());
    // Records written after the flush must be addressable and selectable.
    try std.testing.expect(resumed.contains(3));
    const found = try resumed.findRecordsJsonAlloc(std.testing.allocator, .{ .label = "after-flush" }, 0, 8, 64);
    defer std.testing.allocator.free(found);
    try std.testing.expect(std.mem.indexOf(u8, found, "\"matched\":2") != null);

    // Completing from a partial index must land in exactly the state a full
    // replay would have produced, including the index it will next persist.
    resumed_summary = try resumed.summaryJsonAlloc(std.testing.allocator);
    resumed_index = try resumed.index_builder.serializeAlloc(log.len, Index.digest(log));
    resumed_session = resumed.currentSessionId();
    }
    defer std.testing.allocator.free(resumed_summary);
    defer std.testing.allocator.free(resumed_index);

    try graph_dir.deleteFile(std.testing.io, Index.default_index_name);
    var replayed = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{});
    defer replayed.deinit();
    const replayed_summary = try replayed.summaryJsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(replayed_summary);
    const replayed_index = try replayed.index_builder.serializeAlloc(log.len, Index.digest(log));
    defer std.testing.allocator.free(replayed_index);

    try std.testing.expectEqualStrings(replayed_summary, resumed_summary);
    try std.testing.expectEqual(replayed.currentSessionId(), resumed_session);
    try std.testing.expectEqualSlices(u8, replayed_index, resumed_index);
}

test "opening the writer from an index restores the same state as replaying" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const events = [_]fx.CausalEvent{
        .{ .id = 1, .kind = .run_started, .label = "run", .status = "running" },
        .{ .id = 2, .kind = .effect_completed, .parent_id = 1, .label = "B.do", .status = "success", .service_key = "application/B", .context = .{ .requirement_id = 5 } },
        .{ .id = 3, .kind = .run_completed, .parent_id = 2, .label = "run", .status = "success" },
    };
    {
        var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{});
        defer database.deinit();
        for (events) |event| {
            var write = try fx.mapCausalEventToNendbWrite(std.testing.allocator, event);
            defer fx.deinitCausalNendbWrite(std.testing.allocator, &write);
            try database.appendWrite(write);
        }
        try database.flush();
    }

    var graph_dir = try tmp.dir.openDir(std.testing.io, default_path, .{ .follow_symlinks = false });
    defer graph_dir.close(std.testing.io);

    const Observed = struct { records: usize, edges: usize, session: u64, engine_nodes: usize, engine_edges: usize, summary: []u8, index_bytes: []u8 };
    const observe = struct {
        fn run(root: std.Io.Dir) !Observed {
            var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, root, .{});
            defer database.deinit();
            const stats = database.engineStats();
            const content = try database.graph_dir.readFileAlloc(std.testing.io, default_wal_name, std.testing.allocator, .limited(1 << 20));
            defer std.testing.allocator.free(content);
            return .{
                .records = database.recordCount(),
                .edges = database.edgeCount(),
                .session = database.currentSessionId(),
                .engine_nodes = stats.nodes,
                .engine_edges = stats.edges,
                .summary = try database.summaryJsonAlloc(std.testing.allocator),
                .index_bytes = try database.index_builder.serializeAlloc(content.len, Index.digest(content)),
            };
        }
    }.run;

    const from_index = try observe(tmp.dir);
    defer std.testing.allocator.free(from_index.summary);
    defer std.testing.allocator.free(from_index.index_bytes);

    try graph_dir.deleteFile(std.testing.io, Index.default_index_name);
    const from_replay = try observe(tmp.dir);
    defer std.testing.allocator.free(from_replay.summary);
    defer std.testing.allocator.free(from_replay.index_bytes);

    try std.testing.expectEqual(from_replay.records, from_index.records);
    try std.testing.expectEqual(from_replay.edges, from_index.edges);
    // Session assignment drives durable id derivation for everything written
    // next, so a disagreement here would corrupt the log rather than a query.
    try std.testing.expectEqual(from_replay.session, from_index.session);
    try std.testing.expectEqual(from_replay.engine_nodes, from_index.engine_nodes);
    try std.testing.expectEqual(from_replay.engine_edges, from_index.engine_edges);
    try std.testing.expectEqualStrings(from_replay.summary, from_index.summary);
    // The builder must be fully repopulated: otherwise the next flush would
    // persist an index claiming to cover the log while holding only later rows.
    try std.testing.expectEqualSlices(u8, from_replay.index_bytes, from_index.index_bytes);

    // And a process that opened from the index must keep appending correctly.
    {
        var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{});
        defer database.deinit();
        var write = try fx.mapCausalEventToNendbWrite(std.testing.allocator, .{ .id = 1, .kind = .run_started, .label = "second-session" });
        defer fx.deinitCausalNendbWrite(std.testing.allocator, &write);
        try database.appendWrite(write);
        try database.flush();
        try std.testing.expectEqual(@as(usize, 4), database.recordCount());
    }
    var reopened = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{});
    defer reopened.deinit();
    try std.testing.expectEqual(@as(usize, 4), reopened.recordCount());
    const found = try reopened.findRecordsJsonAlloc(std.testing.allocator, .{ .label = "second-session" }, 0, 8, 64);
    defer std.testing.allocator.free(found);
    try std.testing.expect(std.mem.indexOf(u8, found, "\"matched\":1") != null);
}

test "an index-backed snapshot answers identically to a replayed one" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    {
        var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{});
        defer database.deinit();
        const events = [_]fx.CausalEvent{
            .{ .id = 1, .kind = .run_started, .label = "run", .status = "running" },
            .{ .id = 2, .kind = .effect_completed, .parent_id = 1, .label = "A.create", .status = "success", .service_key = "application/A", .context = .{ .requirement_id = 7 } },
            .{ .id = 3, .kind = .effect_completed, .parent_id = 2, .label = "A.create", .status = "failure" },
            .{ .id = 4, .kind = .run_completed, .parent_id = 3, .label = "run", .status = "success" },
        };
        for (events) |event| {
            var write = try fx.mapCausalEventToNendbWrite(std.testing.allocator, event);
            defer fx.deinitCausalNendbWrite(std.testing.allocator, &write);
            try database.appendWrite(write);
        }
        try database.flush();
    }

    var graph_dir = try tmp.dir.openDir(std.testing.io, default_path, .{ .follow_symlinks = false });
    defer graph_dir.close(std.testing.io);

    // Every query is asked twice: once with the index present, once with it
    // deleted so the same question is answered by decoding the log. A reader
    // must not be able to tell which happened.
    const Answers = struct {
        summary: []u8,
        since: []u8,
        record: []u8,
        children: []u8,
        found: []u8,
        found_failure: []u8,
        found_requirement: []u8,
        found_service: []u8,
        found_absent: []u8,
        found_paged: []u8,

        fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            allocator.free(self.summary);
            allocator.free(self.since);
            allocator.free(self.record);
            allocator.free(self.children);
            allocator.free(self.found);
            allocator.free(self.found_failure);
            allocator.free(self.found_requirement);
            allocator.free(self.found_service);
            allocator.free(self.found_absent);
            allocator.free(self.found_paged);
        }
    };

    const ask = struct {
        fn run(root: std.Io.Dir) !Answers {
            var snapshot = try Snapshot.open(std.testing.allocator, std.testing.io, root, .{});
            defer snapshot.deinit();
            const children_ids = try snapshot.childrenAlloc(std.testing.allocator, 2);
            defer std.testing.allocator.free(children_ids);
            return .{
                .summary = try snapshot.summaryJsonAlloc(std.testing.allocator),
                .since = try snapshot.recordsAfterJsonAlloc(std.testing.allocator, 0, 64),
                .record = try snapshot.recordJsonAlloc(std.testing.allocator, 3),
                .children = try childrenJsonAlloc(std.testing.allocator, 2, children_ids),
                .found = try snapshot.findRecordsJsonAlloc(std.testing.allocator, .{ .label = "A.create" }, 0, 16, 64),
                .found_failure = try snapshot.findRecordsJsonAlloc(std.testing.allocator, .{ .label = "A.create", .status = "failure" }, 0, 16, 64),
                .found_requirement = try snapshot.findRecordsJsonAlloc(std.testing.allocator, .{ .requirement_id = 7 }, 0, 16, 64),
                .found_service = try snapshot.findRecordsJsonAlloc(std.testing.allocator, .{ .service_key = "application/A" }, 0, 16, 64),
                // A value that was never recorded: the indexed path short-circuits,
                // and must still report pagination exactly as the scan does.
                .found_absent = try snapshot.findRecordsJsonAlloc(std.testing.allocator, .{ .label = "never-happened" }, 0, 16, 64),
                // Paginated, so truncation and the cursor are compared too.
                .found_paged = try snapshot.findRecordsJsonAlloc(std.testing.allocator, .{ .label = "A.create" }, 0, 1, 64),
            };
        }
    }.run;

    var with_index = try ask(tmp.dir);
    defer with_index.deinit(std.testing.allocator);

    // Prove the fast path was actually taken, rather than both runs replaying.
    const index_bytes = try graph_dir.readFileAlloc(std.testing.io, Index.default_index_name, std.testing.allocator, .limited(1 << 20));
    defer std.testing.allocator.free(index_bytes);
    const view = try Index.parse(index_bytes);
    try std.testing.expectEqual(@as(u32, 4), view.header.entry_count);

    try graph_dir.deleteFile(std.testing.io, Index.default_index_name);
    var without_index = try ask(tmp.dir);
    defer without_index.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(with_index.summary, without_index.summary);
    try std.testing.expectEqualStrings(with_index.since, without_index.since);
    try std.testing.expectEqualStrings(with_index.record, without_index.record);
    try std.testing.expectEqualStrings(with_index.children, without_index.children);
    try std.testing.expectEqualStrings(with_index.found, without_index.found);
    try std.testing.expectEqualStrings(with_index.found_failure, without_index.found_failure);
    try std.testing.expectEqualStrings(with_index.found_requirement, without_index.found_requirement);
    try std.testing.expectEqualStrings(with_index.found_service, without_index.found_service);
    try std.testing.expectEqualStrings(with_index.found_absent, without_index.found_absent);
    try std.testing.expectEqualStrings(with_index.found_paged, without_index.found_paged);

    // Guard against the equivalence passing vacuously.
    try std.testing.expect(std.mem.indexOf(u8, with_index.found_failure, "\"matched\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_index.found_requirement, "\"matched\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, with_index.found_absent, "\"matched\":0") != null);
}

test "a snapshot ignores an index that cannot be proven to describe the log" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    {
        var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{});
        defer database.deinit();
        var write = try fx.mapCausalEventToNendbWrite(std.testing.allocator, .{ .id = 1, .kind = .run_started, .label = "only" });
        defer fx.deinitCausalNendbWrite(std.testing.allocator, &write);
        try database.appendWrite(write);
        try database.flush();
    }

    var graph_dir = try tmp.dir.openDir(std.testing.io, default_path, .{ .follow_symlinks = false });
    defer graph_dir.close(std.testing.io);
    const good = try graph_dir.readFileAlloc(std.testing.io, Index.default_index_name, std.testing.allocator, .limited(1 << 20));
    defer std.testing.allocator.free(good);

    const cases = [_][]const u8{ "truncated", "bad-magic", "wrong-digest" };
    for (cases) |case| {
        const damaged = try std.testing.allocator.dupe(u8, good);
        defer std.testing.allocator.free(damaged);
        var write_len = damaged.len;
        if (std.mem.eql(u8, case, "truncated")) {
            write_len -= 1;
        } else if (std.mem.eql(u8, case, "bad-magic")) {
            damaged[0] = 'X';
        } else {
            // Same length, same claimed coverage, different digest.
            std.mem.writeInt(u64, damaged[32..40], 0xdead_beef, .little);
        }
        {
            var file = try graph_dir.createFile(std.testing.io, Index.default_index_name, .{ .truncate = true, .resolve_beneath = true });
            defer file.close(std.testing.io);
            try file.writePositionalAll(std.testing.io, damaged[0..write_len], 0);
        }
        // A damaged index must degrade to a replay, never to a wrong answer or
        // a failure to open.
        var snapshot = try Snapshot.open(std.testing.allocator, std.testing.io, tmp.dir, .{});
        defer snapshot.deinit();
        try std.testing.expectEqual(@as(usize, 1), snapshot.summary().records);
    }
}

test "compaction rebuilds the index against the rewritten log" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const options = Options{ .max_records = 4, .retention = .prune_oldest_sessions };

    var session: usize = 0;
    while (session < 3) : (session += 1) {
        var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, options);
        defer database.deinit();
        const events = [_]fx.CausalEvent{
            .{ .id = 1, .kind = .run_started, .label = "start" },
            .{ .id = 2, .kind = .run_completed, .parent_id = 1, .label = "end" },
        };
        for (events) |event| {
            var write = try fx.mapCausalEventToNendbWrite(std.testing.allocator, event);
            defer fx.deinitCausalNendbWrite(std.testing.allocator, &write);
            try database.appendWrite(write);
        }
        try database.flush();
    }

    var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, options);
    defer database.deinit();
    const content = try database.graph_dir.readFileAlloc(std.testing.io, default_wal_name, std.testing.allocator, .limited(1 << 20));
    defer std.testing.allocator.free(content);
    const bytes = try database.index_builder.serializeAlloc(content.len, Index.digest(content));
    defer std.testing.allocator.free(bytes);
    const view = try Index.parse(bytes);

    // Compaction rewrites every byte offset, so an index carrying the old ones
    // would point a reader at the wrong line rather than fail.
    try std.testing.expectEqual(@as(u32, @intCast(database.recordCount())), view.header.entry_count);
    try std.testing.expect(Index.coversPrefix(view, content.len, content));
    for (view.entries) |entry| {
        try std.testing.expect(entry.offset + entry.length <= content.len);
        const line = content[entry.offset..][0..entry.length];
        try std.testing.expect(std.mem.startsWith(u8, line, "{"));
        try std.testing.expect(std.mem.endsWith(u8, line, "}"));
    }
}

test "causal graph readers tolerate records written by a newer writer" {
    // The record schema will need to grow. Every reader here parses the durable
    // record directly, so without unknown-field tolerance a single added field
    // would make every existing graph unreadable — and because the failure lands
    // in LocalDatabase.init inside ManagedRuntime.make, affected processes would
    // not start at all. zgraphy's out-of-tree parser already tolerates unknown
    // fields; this proves the owning reader does too.
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    {
        var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{});
        defer database.deinit();
        const events = [_]fx.CausalEvent{
            .{ .id = 1, .kind = .run_started, .label = "before-upgrade" },
            .{ .id = 2, .kind = .run_completed, .parent_id = 1, .label = "after-upgrade" },
        };
        for (events) |event| {
            var write = try fx.mapCausalEventToNendbWrite(std.testing.allocator, event);
            defer fx.deinitCausalNendbWrite(std.testing.allocator, &write);
            try database.appendWrite(write);
        }
        try database.flush();
    }

    // Simulate a newer writer: inject a field this build has never heard of,
    // at both the record and the node level.
    var graph_dir = try tmp.dir.openDir(std.testing.io, default_path, .{ .follow_symlinks = false });
    defer graph_dir.close(std.testing.io);
    const original = try graph_dir.readFileAlloc(std.testing.io, default_wal_name, std.testing.allocator, .limited(1 << 20));
    defer std.testing.allocator.free(original);

    var upgraded: std.ArrayList(u8) = .empty;
    defer upgraded.deinit(std.testing.allocator);
    var lines = std.mem.splitScalar(u8, original, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        try upgraded.appendSlice(std.testing.allocator, line[0 .. line.len - 1]);
        try upgraded.appendSlice(std.testing.allocator, ",\"future_record_field\":42}");
        try upgraded.append(std.testing.allocator, '\n');
    }
    {
        var file = try graph_dir.createFile(std.testing.io, default_wal_name, .{ .truncate = true, .resolve_beneath = true });
        defer file.close(std.testing.io);
        try file.writePositionalAll(std.testing.io, upgraded.items, 0);
        try file.sync(std.testing.io);
    }

    // Reopening must succeed and preserve every fact, not fail with CorruptGraph.
    var reopened = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{});
    defer reopened.deinit();
    try std.testing.expectEqual(@as(usize, 2), reopened.recordCount());

    const records = try reopened.recordsAfterJsonAlloc(std.testing.allocator, 0, 8);
    defer std.testing.allocator.free(records);
    try std.testing.expect(std.mem.indexOf(u8, records, "before-upgrade") != null);
    try std.testing.expect(std.mem.indexOf(u8, records, "after-upgrade") != null);

    // The read-only snapshot path the CLI uses must tolerate it too.
    var snapshot = try Snapshot.open(std.testing.allocator, std.testing.io, tmp.dir, .{});
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 2), snapshot.summary().records);

    // And selection, which decodes both the record and its property blob.
    const found = try snapshot.findRecordsJsonAlloc(std.testing.allocator, .{ .label = "after-upgrade" }, 0, 8, 8);
    defer std.testing.allocator.free(found);
    try std.testing.expect(std.mem.indexOf(u8, found, "\"matched\":1") != null);
}

test "causal graph retention drops oldest sessions instead of failing closed" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const options = Options{ .max_records = 4, .retention = .prune_oldest_sessions };

    // Three separate sessions, two records each, written across reopens so the
    // graph accumulates history the way a long-running service does.
    var session: usize = 0;
    while (session < 3) : (session += 1) {
        var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, options);
        defer database.deinit();
        const events = [_]fx.CausalEvent{
            .{ .id = 1, .kind = .run_started, .label = "session-start" },
            .{ .id = 2, .kind = .run_completed, .parent_id = 1, .label = "session-end" },
        };
        for (events) |event| {
            var write = try fx.mapCausalEventToNendbWrite(std.testing.allocator, event);
            defer fx.deinitCausalNendbWrite(std.testing.allocator, &write);
            try database.appendWrite(write);
        }
        try database.flush();
    }

    var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, options);
    defer database.deinit();
    // Six writes against a four-record graph: the oldest session was dropped
    // rather than the sixth write being refused.
    try std.testing.expect(database.recordCount() <= options.max_records);
    try std.testing.expect(database.recordCount() > 0);

    // Every retained record still resolves, and each retained child still finds
    // its parent, so compaction left no dangling reference behind.
    const summary_json = try database.summaryJsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(summary_json);
    try std.testing.expect(std.mem.indexOf(u8, summary_json, "\"trailing_partial_bytes\":0") != null);

    const records = try database.recordsAfterJsonAlloc(std.testing.allocator, 0, 64);
    defer std.testing.allocator.free(records);
    var parsed = try std.json.parseFromSlice(
        struct { records: []struct { node: struct { id: u64 }, parent_edge: ?struct { from: u64 } = null } },
        std.testing.allocator,
        records,
        .{ .allocate = .alloc_always, .ignore_unknown_fields = true },
    );
    defer parsed.deinit();
    try std.testing.expect(parsed.value.records.len > 0);
    for (parsed.value.records) |record| {
        const resolved = try database.recordJsonAlloc(std.testing.allocator, record.node.id);
        std.testing.allocator.free(resolved);
        if (record.parent_edge) |edge| try std.testing.expect(database.contains(edge.from));
    }
}

test "the default keeps a long-running store writable" {
    // A service must not stop recording because its working set filled. This is
    // only safe because a receipt now carries the facts it cites, so pruning a
    // record no longer invalidates a claim that referenced it.
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var session: usize = 0;
    while (session < 4) : (session += 1) {
        var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{ .max_records = 4 });
        defer database.deinit();
        const events = [_]fx.CausalEvent{
            .{ .id = 1, .kind = .run_started, .label = "start" },
            .{ .id = 2, .kind = .run_completed, .parent_id = 1, .label = "end" },
        };
        for (events) |event| {
            var write = try fx.mapCausalEventToNendbWrite(std.testing.allocator, event);
            defer fx.deinitCausalNendbWrite(std.testing.allocator, &write);
            // No GraphDatabaseFull: the store makes room instead of refusing.
            try database.appendWrite(write);
        }
        try database.flush();
    }

    var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{ .max_records = 4 });
    defer database.deinit();
    try std.testing.expect(database.recordCount() <= 4);
    try std.testing.expect(database.recordCount() > 0);
}

test "fail_closed is available for a store that must never lose a record" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{
        .max_records = 2,
        .retention = .fail_closed,
    });
    defer database.deinit();

    const events = [_]fx.CausalEvent{
        .{ .id = 1, .kind = .run_started, .label = "first" },
        .{ .id = 2, .kind = .activity_completed, .parent_id = 1, .label = "second" },
        .{ .id = 3, .kind = .run_completed, .parent_id = 2, .label = "third" },
    };
    var write_one = try fx.mapCausalEventToNendbWrite(std.testing.allocator, events[0]);
    defer fx.deinitCausalNendbWrite(std.testing.allocator, &write_one);
    try database.appendWrite(write_one);
    var write_two = try fx.mapCausalEventToNendbWrite(std.testing.allocator, events[1]);
    defer fx.deinitCausalNendbWrite(std.testing.allocator, &write_two);
    try database.appendWrite(write_two);
    var write_three = try fx.mapCausalEventToNendbWrite(std.testing.allocator, events[2]);
    defer fx.deinitCausalNendbWrite(std.testing.allocator, &write_three);
    try std.testing.expectError(error.GraphDatabaseFull, database.appendWrite(write_three));
    try std.testing.expectEqual(@as(usize, 2), database.recordCount());
}

test "durable causal graph selects flattened records by semantic identity" {
    const requirement = fx.stableCausalContextId("req-todo-domain");
    const other_requirement = fx.stableCausalContextId("req-grpc-boundary");

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var database = try LocalDatabase.init(std.testing.allocator, std.testing.io, tmp.dir, .{});
    defer database.deinit();

    const events = [_]fx.CausalEvent{
        .{
            .id = 1,
            .kind = .run_started,
            .label = "TodoService.create",
            .status = "success",
            .service_key = "application/TodoService",
            .context = .{ .requirement_id = requirement },
        },
        .{
            .id = 2,
            .kind = .activity_completed,
            .parent_id = 1,
            .label = "TodoService.create",
            .status = "failure",
            .service_key = "application/TodoService",
            .context = .{ .requirement_id = requirement },
        },
        .{
            .id = 3,
            .kind = .activity_completed,
            .parent_id = 2,
            .label = "TodoService.create",
            .status = "failure",
            .service_key = "application/TodoService",
            .context = .{ .requirement_id = other_requirement },
        },
    };
    for (events) |event| {
        var write = try fx.mapCausalEventToNendbWrite(std.testing.allocator, event);
        defer fx.deinitCausalNendbWrite(std.testing.allocator, &write);
        try database.appendWrite(write);
    }

    // A failure filter scoped to one requirement must exclude the identically
    // labelled failure belonging to another requirement.
    const scoped = try database.findRecordsJsonAlloc(
        std.testing.allocator,
        .{ .status = "failure", .requirement_id = requirement },
        0,
        8,
        8,
    );
    defer std.testing.allocator.free(scoped);
    try std.testing.expect(std.mem.indexOf(u8, scoped, find_schema) != null);
    try std.testing.expect(std.mem.indexOf(u8, scoped, "\"scanned\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, scoped, "\"matched\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, scoped, "\"durable_event_id\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, scoped, "\"durable_event_id\":3") == null);

    // The projection is flat: identity an agent selects on is readable without
    // decoding the nested property blob a second time.
    try std.testing.expect(std.mem.indexOf(u8, scoped, "\"label\":\"TodoService.create\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, scoped, "\"status\":\"failure\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, scoped, "\"service_key\":\"application/TodoService\"") != null);

    const by_label = try database.findRecordsJsonAlloc(std.testing.allocator, .{ .label = "TodoService.create" }, 0, 8, 8);
    defer std.testing.allocator.free(by_label);
    try std.testing.expect(std.mem.indexOf(u8, by_label, "\"matched\":3") != null);

    // Pagination advances over scanned records, not matches, so a sparse
    // selection still makes forward progress.
    const first_page = try database.findRecordsJsonAlloc(std.testing.allocator, .{ .status = "failure" }, 0, 1, 8);
    defer std.testing.allocator.free(first_page);
    try std.testing.expect(std.mem.indexOf(u8, first_page, "\"matched\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, first_page, "\"truncated\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, first_page, "\"next_after_event_id\":2") != null);

    const second = try database.findRecordsJsonAlloc(std.testing.allocator, .{ .status = "failure" }, 2, 8, 8);
    defer std.testing.allocator.free(second);
    try std.testing.expect(std.mem.indexOf(u8, second, "\"durable_event_id\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, second, "\"durable_event_id\":2") == null);

    // An unconstrained selection is rejected rather than silently returning all.
    try std.testing.expectError(
        error.InvalidGraphOptions,
        database.findRecordsJsonAlloc(std.testing.allocator, .{}, 0, 8, 8),
    );
}
