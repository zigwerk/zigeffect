//! Derived index over the durable causal log.
//!
//! The log at `causal-graph.jsonl` stays the sole source of truth: its bytes,
//! field names and invariants never change, because an out-of-tree consumer
//! (zgraphy's repository indexer) parses it directly and receipts cite durable
//! event ids into it. What that log cannot do is answer a question without being
//! parsed, and parsing is the whole cost — reading the bytes is free, while
//! decoding them runs 36 us per record in ReleaseSafe and 726 us in Debug.
//!
//! This module is the derived half: a fixed-width, machine-local, fully
//! rebuildable projection of the log. It holds the identity columns an open
//! needs and the semantic columns a selective query filters on, so both can be
//! answered without decoding JSON.
//!
//! Two rules govern everything here.
//!
//! 1. The index is **disposable**. Deleting it must never lose information, only
//!    time. Every reader must be able to fall back to replaying the log.
//! 2. The index is **verified, never trusted**. It records which prefix of the
//!    log it describes and a digest of that prefix. A reader that cannot prove
//!    the index matches the log it can actually see must ignore it.

const std = @import("std");

pub const schema = "zigeffect.causal.local-graph-index.v2";
pub const schema_version: u32 = 2;
pub const default_index_name = "causal-graph.index";

pub const magic: [8]u8 = .{ 'Z', 'C', 'G', 'I', 'D', 'X', '0', '1' };

/// Written natively and read back only after this exact value is confirmed. The
/// index is a machine-local cache, so a differing word order or width means the
/// file was produced by an incompatible build and must be rebuilt rather than
/// reinterpreted.
pub const byte_order_probe: u64 = 0x0102030405060708;

/// A string id of this value means "absent", distinguishing an empty string that
/// was recorded from a field that was not present at all.
pub const no_string: u32 = std.math.maxInt(u32);
/// A parent id of zero means the record has no parent edge; durable ids are
/// never zero (`DurableEventIdOverflow` rejects that at write time).
pub const no_parent: u64 = 0;

pub const Error = error{
    IndexUnusable,
};

pub const Header = extern struct {
    magic: [8]u8 = magic,
    byte_order: u64 = byte_order_probe,
    schema_version: u32 = schema_version,
    entry_count: u32 = 0,
    /// Length of the log prefix this index describes. A log longer than this has
    /// a tail the index does not cover; a log shorter than this is a different
    /// log and the index must be discarded.
    covered_bytes: u64 = 0,
    /// Digest of exactly `covered_bytes` of the log.
    covered_digest: u64 = 0,
    edge_count: u64 = 0,
    max_session_id: u64 = 0,
    max_durable_event_id: u64 = 0,
    string_bytes: u64 = 0,
};

/// One record's identity and its filterable semantics.
///
/// `offset`/`length` locate the untouched log line, so anything not projected
/// here is still one seek away. Text is interned into the string table and
/// compared as a `u32`, which is what makes a label filter a column scan rather
/// than a string comparison against freshly parsed JSON.
pub const Entry = extern struct {
    durable_event_id: u64,
    source_event_id: u64,
    sequence: u64,
    session_id: u64,
    durable_parent_id: u64 = no_parent,
    offset: u64,
    length: u64,
    requirement_id: u64 = 0,
    acceptance_check_id: u64 = 0,
    scenario_id: u64 = 0,
    run_id: u64 = 0,
    label_id: u32 = no_string,
    status_id: u32 = no_string,
    service_key_id: u32 = no_string,
    type_name_id: u32 = no_string,
    kind_id: u32 = no_string,
    /// The NenDB topology kind byte, so the in-memory graph can be rebuilt from
    /// the index without touching the log.
    node_kind: u8 = 0,
    reserved: [3]u8 = .{ 0, 0, 0 },
};

comptime {
    // Written to disk verbatim, so the layout is part of the format: a silent
    // padding change would shift every field on read. Pinning the sizes turns
    // that into a compile error instead of corruption.
    std.debug.assert(@sizeOf(Header) == 72);
    std.debug.assert(@alignOf(Header) == 8);
    std.debug.assert(@sizeOf(Entry) == 112);
    std.debug.assert(@alignOf(Entry) == 8);
    std.debug.assert(@offsetOf(Header, "schema_version") == 16);
}

/// Interns the text columns so entries carry ids instead of bytes.
pub const StringTable = struct {
    bytes: std.ArrayList(u8) = .empty,
    /// Content hash to id, deliberately not the string itself: keying by slice
    /// would store pointers into `bytes`, which every append can reallocate,
    /// leaving the map to rehash freed memory.
    lookup: std.AutoHashMapUnmanaged(u64, u32) = .empty,

    pub fn deinit(self: *StringTable, allocator: std.mem.Allocator) void {
        self.lookup.deinit(allocator);
        self.bytes.deinit(allocator);
    }

    /// Absent and empty are deliberately different: a field the writer never set
    /// must not be indistinguishable from one it set to "".
    pub fn intern(self: *StringTable, allocator: std.mem.Allocator, value: ?[]const u8) !u32 {
        const text = value orelse return no_string;
        if (text.len > std.math.maxInt(u16)) return error.IndexUnusable;
        const key = std.hash.Wyhash.hash(0x5f1d_2a77, text);
        if (self.lookup.get(key)) |existing| {
            // Confirm by content, so a hash collision costs a duplicate entry
            // rather than silently aliasing two different strings.
            if (resolve(self.bytes.items, existing)) |stored| {
                if (std.mem.eql(u8, stored, text)) return existing;
            }
        }
        const id: u32 = @intCast(self.bytes.items.len);
        try self.bytes.ensureUnusedCapacity(allocator, text.len + 2);
        self.bytes.appendSliceAssumeCapacity(&std.mem.toBytes(@as(u16, @intCast(text.len))));
        self.bytes.appendSliceAssumeCapacity(text);
        try self.lookup.put(allocator, key, id);
        return id;
    }

    /// `id` is read from an untrusted file, so every offset is range-checked
    /// with widening arithmetic rather than `u32` addition that could wrap.
    pub fn resolve(bytes: []const u8, id: u32) ?[]const u8 {
        if (id == no_string) return null;
        const start_of_length: usize = id;
        if (start_of_length + 2 > bytes.len) return null;
        const length: usize = std.mem.bytesToValue(u16, bytes[start_of_length..][0..2]);
        const start = start_of_length + 2;
        if (start + length > bytes.len) return null;
        return bytes[start..][0..length];
    }
};

pub fn digest(bytes: []const u8) u64 {
    return std.hash.Wyhash.hash(0x2c9a_11ef, bytes);
}

/// Accumulates entries in log order and serialises them.
pub const Builder = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(Entry) = .empty,
    strings: StringTable = .{},
    edge_count: u64 = 0,
    max_session_id: u64 = 0,
    max_durable_event_id: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) Builder {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Builder) void {
        self.strings.deinit(self.allocator);
        self.entries.deinit(self.allocator);
    }

    pub const Columns = struct {
        label: ?[]const u8 = null,
        status: ?[]const u8 = null,
        service_key: ?[]const u8 = null,
        type_name: ?[]const u8 = null,
        kind: ?[]const u8 = null,
        requirement_id: ?u64 = null,
        acceptance_check_id: ?u64 = null,
        scenario_id: ?u64 = null,
        run_id: ?u64 = null,
    };

    pub const Row = struct {
        durable_event_id: u64,
        source_event_id: u64,
        sequence: u64,
        session_id: u64,
        durable_parent_id: ?u64 = null,
        offset: u64,
        length: u64,
        node_kind: u8,
        columns: Columns = .{},
    };

    /// Adopt a previously serialised index wholesale.
    ///
    /// A process that opened from an index still has to be able to persist a
    /// complete one later, but re-interning every column to get there costs a
    /// hashmap operation per field per record — enough to erase the saving that
    /// made the index worth loading. Because string ids are offsets into the
    /// table, copying the table and the entries verbatim preserves every id
    /// exactly, so this is two memcpys plus a walk of the distinct strings to
    /// restore deduplication for whatever is appended next.
    pub fn seedFrom(self: *Builder, view: View) !void {
        std.debug.assert(self.entries.items.len == 0);
        std.debug.assert(self.strings.bytes.items.len == 0);

        try self.strings.bytes.appendSlice(self.allocator, view.strings);
        var cursor: usize = 0;
        while (cursor + 2 <= view.strings.len) {
            const length = std.mem.bytesToValue(u16, view.strings[cursor..][0..2]);
            const start = cursor + 2;
            if (start + length > view.strings.len) return error.IndexUnusable;
            const key = std.hash.Wyhash.hash(0x5f1d_2a77, view.strings[start..][0..length]);
            try self.strings.lookup.put(self.allocator, key, @intCast(cursor));
            cursor = start + length;
        }

        // The view borrows unaligned bytes straight from the file, so entries
        // are copied one at a time rather than as an aligned slice.
        try self.entries.ensureUnusedCapacity(self.allocator, view.entries.len);
        for (view.entries) |entry| self.entries.appendAssumeCapacity(entry);
        self.edge_count = view.header.edge_count;
        self.max_session_id = view.header.max_session_id;
        self.max_durable_event_id = view.header.max_durable_event_id;
    }

    pub fn append(self: *Builder, row: Row) !void {
        // Entries are binary-searched by durable id, exactly as the in-memory
        // index is today, so the ordering invariant has to hold here too.
        if (self.entries.items.len != 0) {
            const previous = self.entries.items[self.entries.items.len - 1];
            if (row.durable_event_id <= previous.durable_event_id) return error.IndexUnusable;
        }
        try self.entries.append(self.allocator, .{
            .durable_event_id = row.durable_event_id,
            .source_event_id = row.source_event_id,
            .sequence = row.sequence,
            .session_id = row.session_id,
            .durable_parent_id = row.durable_parent_id orelse no_parent,
            .offset = row.offset,
            .length = row.length,
            .requirement_id = row.columns.requirement_id orelse 0,
            .acceptance_check_id = row.columns.acceptance_check_id orelse 0,
            .scenario_id = row.columns.scenario_id orelse 0,
            .run_id = row.columns.run_id orelse 0,
            .label_id = try self.strings.intern(self.allocator, row.columns.label),
            .status_id = try self.strings.intern(self.allocator, row.columns.status),
            .service_key_id = try self.strings.intern(self.allocator, row.columns.service_key),
            .type_name_id = try self.strings.intern(self.allocator, row.columns.type_name),
            .kind_id = try self.strings.intern(self.allocator, row.columns.kind),
            .node_kind = row.node_kind,
        });
        if (row.durable_parent_id != null) self.edge_count += 1;
        self.max_session_id = @max(self.max_session_id, row.session_id);
        self.max_durable_event_id = @max(self.max_durable_event_id, row.durable_event_id);
    }

    /// Serialise for a log prefix of exactly `covered_bytes` whose digest is
    /// `covered_digest`. Callers must pass the digest of the same bytes they
    /// indexed, or every later read will correctly reject this file.
    pub fn serializeAlloc(self: *Builder, covered_bytes: u64, covered_digest: u64) ![]u8 {
        const header = Header{
            .entry_count = @intCast(self.entries.items.len),
            .covered_bytes = covered_bytes,
            .covered_digest = covered_digest,
            .edge_count = self.edge_count,
            .max_session_id = self.max_session_id,
            .max_durable_event_id = self.max_durable_event_id,
            .string_bytes = self.strings.bytes.items.len,
        };
        var output: std.ArrayList(u8) = .empty;
        errdefer output.deinit(self.allocator);
        try output.appendSlice(self.allocator, std.mem.asBytes(&header));
        try output.appendSlice(self.allocator, std.mem.sliceAsBytes(self.entries.items));
        try output.appendSlice(self.allocator, self.strings.bytes.items);
        return output.toOwnedSlice(self.allocator);
    }
};

/// A loaded index, borrowed from the caller's buffer.
pub const View = struct {
    header: Header,
    entries: []align(1) const Entry,
    strings: []const u8,

    pub fn text(self: View, id: u32) ?[]const u8 {
        return StringTable.resolve(self.strings, id);
    }
};

/// Parse an index buffer, refusing anything this build cannot read verbatim.
///
/// Returns `IndexUnusable` rather than a specific diagnosis because there is
/// exactly one correct response to every failure here: ignore the index and
/// replay the log.
pub fn parse(bytes: []const u8) Error!View {
    if (bytes.len < @sizeOf(Header)) return error.IndexUnusable;
    const header = std.mem.bytesToValue(Header, bytes[0..@sizeOf(Header)]);
    if (!std.mem.eql(u8, &header.magic, &magic)) return error.IndexUnusable;
    if (header.byte_order != byte_order_probe) return error.IndexUnusable;
    if (header.schema_version != schema_version) return error.IndexUnusable;

    // Every one of these comes straight off disk and is therefore untrusted.
    // Unchecked arithmetic here panics in safe builds and wraps in fast ones —
    // and a wrapped length passed the equality check below, yielding slices
    // pointing past the buffer. Overflow must be a rejection like any other
    // corruption, not a crash.
    const entries_bytes = std.math.mul(usize, @as(usize, header.entry_count), @sizeOf(Entry)) catch
        return error.IndexUnusable;
    const strings_start = std.math.add(usize, @sizeOf(Header), entries_bytes) catch
        return error.IndexUnusable;
    const string_bytes = std.math.cast(usize, header.string_bytes) orelse return error.IndexUnusable;
    const strings_end = std.math.add(usize, strings_start, string_bytes) catch
        return error.IndexUnusable;
    if (strings_end != bytes.len) return error.IndexUnusable;

    return .{
        .header = header,
        .entries = std.mem.bytesAsSlice(Entry, bytes[@sizeOf(Header)..strings_start]),
        .strings = bytes[strings_start..strings_end],
    };
}

/// Whether this index describes a prefix of the log the reader is actually
/// looking at. `log_prefix` must be the first `header.covered_bytes` of that log.
pub fn coversPrefix(view: View, log_length: u64, log_prefix: []const u8) bool {
    if (view.header.covered_bytes > log_length) return false;
    if (log_prefix.len != view.header.covered_bytes) return false;
    return digest(log_prefix) == view.header.covered_digest;
}

test "index round-trips entries and interned columns" {
    var builder = Builder.init(std.testing.allocator);
    defer builder.deinit();

    try builder.append(.{
        .durable_event_id = 1,
        .source_event_id = 1,
        .sequence = 1,
        .session_id = 1,
        .offset = 0,
        .length = 120,
        .node_kind = 7,
        .columns = .{ .label = "TodoService.create", .status = "success", .service_key = "application/TodoService", .kind = "effect_completed", .requirement_id = 42 },
    });
    try builder.append(.{
        .durable_event_id = 2,
        .source_event_id = 2,
        .sequence = 2,
        .session_id = 1,
        .durable_parent_id = 1,
        .offset = 121,
        .length = 130,
        .node_kind = 9,
        .columns = .{ .label = "TodoService.create", .status = "failure", .type_name = "InvalidTitle" },
    });

    const log_prefix = "line-one\nline-two\n";
    const bytes = try builder.serializeAlloc(log_prefix.len, digest(log_prefix));
    defer std.testing.allocator.free(bytes);

    const view = try parse(bytes);
    try std.testing.expectEqual(@as(u32, 2), view.header.entry_count);
    try std.testing.expectEqual(@as(u64, 1), view.header.edge_count);
    try std.testing.expectEqual(@as(u64, 2), view.header.max_durable_event_id);

    try std.testing.expectEqual(@as(u64, 1), view.entries[0].durable_event_id);
    try std.testing.expectEqual(no_parent, view.entries[0].durable_parent_id);
    try std.testing.expectEqual(@as(u64, 1), view.entries[1].durable_parent_id);
    try std.testing.expectEqual(@as(u8, 7), view.entries[0].node_kind);
    try std.testing.expectEqual(@as(u64, 42), view.entries[0].requirement_id);

    try std.testing.expectEqualStrings("TodoService.create", view.text(view.entries[0].label_id).?);
    try std.testing.expectEqualStrings("success", view.text(view.entries[0].status_id).?);
    try std.testing.expectEqualStrings("failure", view.text(view.entries[1].status_id).?);
    try std.testing.expectEqualStrings("InvalidTitle", view.text(view.entries[1].type_name_id).?);

    // Repeated text is interned once, which is what makes a filter a u32 compare.
    try std.testing.expectEqual(view.entries[0].label_id, view.entries[1].label_id);
    // Absent is distinguishable from empty.
    try std.testing.expectEqual(no_string, view.entries[1].service_key_id);
    try std.testing.expect(view.text(view.entries[1].service_key_id) == null);

    try std.testing.expect(coversPrefix(view, log_prefix.len, log_prefix));
}

test "index is rejected rather than misread when it does not match the log" {
    var builder = Builder.init(std.testing.allocator);
    defer builder.deinit();
    try builder.append(.{
        .durable_event_id = 1,
        .source_event_id = 1,
        .sequence = 1,
        .session_id = 1,
        .offset = 0,
        .length = 10,
        .node_kind = 1,
        .columns = .{ .label = "only" },
    });
    const prefix = "0123456789";
    const bytes = try builder.serializeAlloc(prefix.len, digest(prefix));
    defer std.testing.allocator.free(bytes);
    const view = try parse(bytes);

    // A log that grew still has a valid covered prefix; the caller replays the tail.
    try std.testing.expect(coversPrefix(view, 40, prefix));
    // A log shorter than the covered prefix is a different log.
    try std.testing.expect(!coversPrefix(view, 4, prefix));
    // Same length, different content: the digest must catch it.
    try std.testing.expect(!coversPrefix(view, prefix.len, "9876543210"));

    // Truncation, a wrong magic, and a future schema version are all unusable
    // rather than partially readable.
    try std.testing.expectError(error.IndexUnusable, parse(bytes[0 .. bytes.len - 1]));
    try std.testing.expectError(error.IndexUnusable, parse(bytes[0..8]));

    const corrupted = try std.testing.allocator.dupe(u8, bytes);
    defer std.testing.allocator.free(corrupted);
    corrupted[0] = 'X';
    try std.testing.expectError(error.IndexUnusable, parse(corrupted));

    const future = try std.testing.allocator.dupe(u8, bytes);
    defer std.testing.allocator.free(future);
    std.mem.writeInt(u32, future[16..20], schema_version + 1, .little);
    try std.testing.expectError(error.IndexUnusable, parse(future));
}

test "index builder refuses out-of-order durable ids" {
    var builder = Builder.init(std.testing.allocator);
    defer builder.deinit();
    try builder.append(.{
        .durable_event_id = 5,
        .source_event_id = 5,
        .sequence = 1,
        .session_id = 1,
        .offset = 0,
        .length = 10,
        .node_kind = 1,
    });
    // Readers binary-search this array; an unordered index would silently
    // return wrong records rather than fail.
    try std.testing.expectError(error.IndexUnusable, builder.append(.{
        .durable_event_id = 5,
        .source_event_id = 6,
        .sequence = 2,
        .session_id = 1,
        .offset = 11,
        .length = 10,
        .node_kind = 1,
    }));
}
