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

pub const Options = struct {
    path: []const u8 = default_path,
    wal_name: []const u8 = default_wal_name,
    max_records: usize = default_max_records,
    max_wal_bytes: usize = 64 * 1024 * 1024,
    max_record_bytes: usize = 512 * 1024,
    sync_on_write: bool = true,
    recover_partial_tail: bool = true,

    pub fn validate(self: Options) !void {
        try Project.validateRelativePath(self.path, false);
        try Project.validateRelativePath(self.wal_name, false);
        if (std.mem.indexOfScalar(u8, self.wal_name, '/') != null or
            self.max_records == 0 or
            self.max_records > max_records or
            self.max_wal_bytes == 0 or
            self.max_record_bytes == 0 or
            self.max_record_bytes > self.max_wal_bytes)
        {
            return error.InvalidGraphOptions;
        }
        if (Secrets.containsSecret(self.path) or Secrets.containsSecret(self.wal_name)) return error.SecretDetected;
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

const IndexEntry = struct {
    sequence: u64,
    session_id: u64,
    durable_event_id: u64,
    source_event_id: u64,
    durable_parent_id: ?u64,
    offset: usize,
    length: usize,
};

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
        self.loadExisting() catch |err| {
            self.current_source_index.deinit(allocator);
            self.durable_entry_index.deinit(allocator);
            self.entries.deinit(allocator);
            return err;
        };
        return self;
    }

    pub fn deinit(self: *LocalDatabase) void {
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

    fn loadExisting(self: *LocalDatabase) !void {
        const content = try self.graph_dir.readFileAlloc(
            self.io,
            self.options.wal_name,
            self.allocator,
            .limited(self.options.max_wal_bytes),
        );
        defer self.allocator.free(content);
        var scan = try scanContent(self.allocator, content, self.options);
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

    fn rebuildNendb(self: *LocalDatabase, content: []const u8) !void {
        var line_start: usize = 0;
        while (std.mem.indexOfScalarPos(u8, content, line_start, '\n')) |newline| {
            const line = content[line_start..newline];
            var parsed = std.json.parseFromSlice(PersistedRecord, self.allocator, line, .{ .allocate = .alloc_always }) catch return error.CorruptGraph;
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
        if (self.entries.items.len >= self.options.max_records) return error.GraphDatabaseFull;
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
        try self.entries.ensureUnusedCapacity(self.allocator, 1);
        try self.durable_entry_index.ensureUnusedCapacity(self.allocator, 1);
        try self.current_source_index.ensureUnusedCapacity(self.allocator, 1);
        const offset_u64 = try self.wal_file.length(self.io);
        const required = std.math.add(u64, offset_u64, @as(u64, @intCast(row.len + 1))) catch return error.GraphDatabaseFull;
        if (required > self.options.max_wal_bytes) return error.GraphDatabaseFull;
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

fn persistedRowContainsLineage(
    allocator: std.mem.Allocator,
    row: []const u8,
    reference: fx.Lineage.Ref,
) !bool {
    var persisted = std.json.parseFromSlice(PersistedRecord, allocator, row, .{ .allocate = .alloc_always }) catch
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
        var scan = try scanContent(allocator, content, options);
        defer scan.deinit(allocator);
        const path = try allocator.dupe(u8, options.path);
        errdefer allocator.free(path);
        const wal_name = try allocator.dupe(u8, options.wal_name);
        errdefer allocator.free(wal_name);
        const entries = try scan.entries.toOwnedSlice(allocator);
        return .{
            .allocator = allocator,
            .path = path,
            .wal_name = wal_name,
            .content = content,
            .entries = entries,
            .edge_count = scan.edge_count,
            .last_complete_offset = scan.last_complete_offset,
        };
    }

    pub fn deinit(self: *Snapshot) void {
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

    pub fn childrenAlloc(self: *const Snapshot, allocator: std.mem.Allocator, durable_event_id: u64) ![]u64 {
        return childrenFromEntriesAlloc(allocator, self.entries, durable_event_id);
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

fn scanContent(allocator: std.mem.Allocator, content: []const u8, options: Options) !ScanResult {
    var result = ScanResult{};
    errdefer result.deinit(allocator);
    var line_start: usize = 0;
    while (std.mem.indexOfScalarPos(u8, content, line_start, '\n')) |newline| {
        const line = content[line_start..newline];
        if (line.len == 0 or line.len > options.max_record_bytes or result.entries.items.len >= options.max_records) {
            return error.CorruptGraph;
        }
        var parsed = std.json.parseFromSlice(PersistedRecord, allocator, line, .{ .allocate = .alloc_always }) catch return error.CorruptGraph;
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
            .offset = line_start,
            .length = line.len,
        });
        try result.seen_nodes.put(allocator, parsed.value.node.id, .{
            .session_id = parsed.value.session_id,
            .source_event_id = parsed.value.node.source_event_id,
        });
        if (parsed.value.session_id != result.max_session_id) result.last_source_event_id = 0;
        result.max_session_id = @max(result.max_session_id, parsed.value.session_id);
        result.last_source_event_id = parsed.value.node.source_event_id;
        result.max_durable_event_id = parsed.value.node.id;
        line_start = newline + 1;
        result.last_complete_offset = line_start;
    }
    return result;
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
    try std.testing.expectError(error.CorruptGraph, scanContent(std.testing.allocator, duplicate_wal, .{}));
    const cross_wal = try std.fmt.allocPrint(std.testing.allocator, "{s}\n{s}\n", .{ first_json, cross_json });
    defer std.testing.allocator.free(cross_wal);
    try std.testing.expectError(error.CorruptGraph, scanContent(std.testing.allocator, cross_wal, .{}));
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
