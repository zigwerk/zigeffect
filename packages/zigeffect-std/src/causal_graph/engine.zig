//! Topology engine for the causal forest.
//!
//! This is ZigEffect's own graph engine, not a general-purpose graph database,
//! and the difference is the point. A causal graph is not an arbitrary graph: it
//! is an append-only **forest** in which every node has *at most one* parent
//! (`PersistedRecord.parent_edge` is a single optional edge), and node ids are
//! strictly increasing down the log. Those two invariants collapse most of what
//! a general engine has to carry:
//!
//! - **Parent lookup is a column read.** No edge table, no adjacency search.
//!   Walking to the root is O(depth) with no index at all.
//! - **Node lookup is a binary search.** Ids are already sorted, so the id→index
//!   hash map a general engine needs does not exist here.
//! - **Children need one small index**, built as CSR (compressed sparse row):
//!   one offsets array plus one child array, filled in a single pass.
//!
//! What that replaces is worth stating plainly. Answering "children of X" today
//! costs two full passes over every record, and "descendants of X" is not
//! offered at all because it would be that cost per level. Here children is a
//! slice and descendants is a bounded breadth-first walk over contiguous memory.
//!
//! The engine holds no durable state. It is built from the entry table the
//! graph already has — which is itself restored from the derived index without
//! decoding the log — so it costs one allocation proportional to the number of
//! edges and nothing on the write path.

const std = @import("std");

pub const Error = error{
    EventNotFound,
    InvalidTraversalLimit,
};

/// One record's position and lineage. This is the node table: sorted ascending
/// by `durable_event_id`, one row per record, with the parent inline.
pub const Entry = struct {
    sequence: u64,
    session_id: u64,
    durable_event_id: u64,
    source_event_id: u64,
    durable_parent_id: ?u64,
    offset: usize,
    length: usize,
};

/// Bounds every traversal. An agent's query must never be able to walk an
/// entire graph by accident, so depth and result size are always capped and the
/// caller is told when a bound was reached rather than silently given less.
pub const TraversalOptions = struct {
    max_depth: usize = 64,
    max_results: usize = 1024,
};

pub const Traversal = struct {
    ids: []u64,
    truncated: bool,

    pub fn deinit(self: *Traversal, allocator: std.mem.Allocator) void {
        allocator.free(self.ids);
        self.* = undefined;
    }
};

/// Child adjacency in compressed sparse row form.
///
/// `offsets` has one slot per node plus a terminator; the children of node `i`
/// are `children[offsets[i]..offsets[i + 1]]`. Two counting passes build it and
/// every lookup afterwards is a slice — no hashing, no scanning, and the whole
/// structure is two contiguous allocations rather than a map of lists.
pub const Topology = struct {
    entries: []const Entry,
    offsets: []u32,
    children: []u32,

    pub fn build(allocator: std.mem.Allocator, entries: []const Entry) !Topology {
        const offsets = try allocator.alloc(u32, entries.len + 1);
        errdefer allocator.free(offsets);
        @memset(offsets, 0);

        // Pass one: count children per parent. A parent id that is not present
        // is skipped rather than rejected, so a topology can be built over any
        // prefix or window of the log without special-casing its boundary.
        var edges: usize = 0;
        for (entries) |entry| {
            const parent = entry.durable_parent_id orelse continue;
            const parent_index = indexOfIn(entries, parent) orelse continue;
            offsets[parent_index + 1] += 1;
            edges += 1;
        }
        for (1..offsets.len) |position| offsets[position] += offsets[position - 1];

        const children = try allocator.alloc(u32, edges);
        errdefer allocator.free(children);

        // Pass two: place each child. `cursor` advances the write position
        // within each parent's span, so children stay in ascending id order.
        const cursor = try allocator.alloc(u32, entries.len);
        defer allocator.free(cursor);
        @memcpy(cursor, offsets[0..entries.len]);
        for (entries, 0..) |entry, index| {
            const parent = entry.durable_parent_id orelse continue;
            const parent_index = indexOfIn(entries, parent) orelse continue;
            children[cursor[parent_index]] = @intCast(index);
            cursor[parent_index] += 1;
        }

        return .{ .entries = entries, .offsets = offsets, .children = children };
    }

    pub fn deinit(self: *Topology, allocator: std.mem.Allocator) void {
        allocator.free(self.children);
        allocator.free(self.offsets);
        self.* = undefined;
    }

    pub fn edgeCount(self: Topology) usize {
        return self.children.len;
    }

    pub fn indexOf(self: Topology, durable_event_id: u64) ?usize {
        return indexOfIn(self.entries, durable_event_id);
    }

    pub fn contains(self: Topology, durable_event_id: u64) bool {
        return self.indexOf(durable_event_id) != null;
    }

    /// Direct children, as indices into the entry table.
    pub fn childIndices(self: Topology, node_index: usize) []const u32 {
        return self.children[self.offsets[node_index]..self.offsets[node_index + 1]];
    }

    pub fn childrenAlloc(self: Topology, allocator: std.mem.Allocator, durable_event_id: u64) ![]u64 {
        const index = self.indexOf(durable_event_id) orelse return error.EventNotFound;
        const slice = self.childIndices(index);
        const ids = try allocator.alloc(u64, slice.len);
        for (slice, 0..) |child, position| ids[position] = self.entries[child].durable_event_id;
        return ids;
    }

    /// Everything caused, directly or transitively, by one event.
    ///
    /// Breadth-first so results come out nearest-cause-first, which is the order
    /// an agent reading a failure wants. Bounded on both depth and count; the
    /// result says which bound stopped it rather than silently truncating.
    pub fn descendantsAlloc(
        self: Topology,
        allocator: std.mem.Allocator,
        durable_event_id: u64,
        options: TraversalOptions,
    ) !Traversal {
        try validateOptions(options);
        const root = self.indexOf(durable_event_id) orelse return error.EventNotFound;

        var found: std.ArrayList(u64) = .empty;
        errdefer found.deinit(allocator);
        var frontier: std.ArrayList(u32) = .empty;
        defer frontier.deinit(allocator);
        var next: std.ArrayList(u32) = .empty;
        defer next.deinit(allocator);

        try frontier.append(allocator, @intCast(root));
        var truncated = false;
        var depth: usize = 0;
        while (frontier.items.len != 0 and depth < options.max_depth) : (depth += 1) {
            next.clearRetainingCapacity();
            for (frontier.items) |node_index| {
                for (self.childIndices(node_index)) |child| {
                    if (found.items.len == options.max_results) {
                        truncated = true;
                        break;
                    }
                    try found.append(allocator, self.entries[child].durable_event_id);
                    try next.append(allocator, child);
                }
                if (truncated) break;
            }
            if (truncated) break;
            std.mem.swap(std.ArrayList(u32), &frontier, &next);
        }
        // A frontier that still has work when the depth cap is hit is also a
        // truncation; not reporting it would let an agent read a partial answer
        // as a complete one.
        if (!truncated and frontier.items.len != 0 and depth >= options.max_depth) {
            for (frontier.items) |node_index| {
                if (self.childIndices(node_index).len != 0) {
                    truncated = true;
                    break;
                }
            }
        }

        return .{ .ids = try found.toOwnedSlice(allocator), .truncated = truncated };
    }

    /// The chain of causes above an event, nearest parent first.
    ///
    /// No index is involved: a single-parent forest means this is a walk up a
    /// column, O(depth) regardless of graph size. A cycle is structurally
    /// impossible because parents always precede children in the log, but the
    /// visited bound is kept so a corrupt file cannot spin.
    pub fn ancestorsAlloc(
        self: Topology,
        allocator: std.mem.Allocator,
        durable_event_id: u64,
        options: TraversalOptions,
    ) !Traversal {
        try validateOptions(options);
        var index = self.indexOf(durable_event_id) orelse return error.EventNotFound;

        var found: std.ArrayList(u64) = .empty;
        errdefer found.deinit(allocator);
        const bound = @min(options.max_results, options.max_depth);
        while (found.items.len < bound) {
            const parent = self.entries[index].durable_parent_id orelse break;
            const parent_index = self.indexOf(parent) orelse break;
            if (parent_index >= index) break;
            try found.append(allocator, parent);
            index = parent_index;
        }
        // Truncated only if the walk stopped at a bound while a further parent
        // still existed. A chain that simply reached a root is complete, even
        // when its length happens to equal the bound.
        const truncated = found.items.len == bound and
            self.entries[index].durable_parent_id != null and
            self.indexOf(self.entries[index].durable_parent_id.?) != null;
        return .{ .ids = try found.toOwnedSlice(allocator), .truncated = truncated };
    }
};

fn validateOptions(options: TraversalOptions) !void {
    if (options.max_depth == 0 or options.max_depth > 4096) return error.InvalidTraversalLimit;
    if (options.max_results == 0 or options.max_results > 4096) return error.InvalidTraversalLimit;
}

/// Ids are strictly increasing down the log, which the durable format enforces,
/// so locating a node is a binary search rather than a hash lookup.
fn indexOfIn(entries: []const Entry, durable_event_id: u64) ?usize {
    var low: usize = 0;
    var high: usize = entries.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        const candidate = entries[middle].durable_event_id;
        if (candidate == durable_event_id) return middle;
        if (candidate < durable_event_id) low = middle + 1 else high = middle;
    }
    return null;
}

fn testEntry(id: u64, parent: ?u64) Entry {
    return .{
        .sequence = id,
        .session_id = 1,
        .durable_event_id = id,
        .source_event_id = id,
        .durable_parent_id = parent,
        .offset = 0,
        .length = 1,
    };
}

test "topology answers children from an index rather than a scan" {
    //        1
    //      /   \
    //     2     3
    //    / \     \
    //   4   5     6
    const entries = [_]Entry{
        testEntry(1, null), testEntry(2, 1), testEntry(3, 1),
        testEntry(4, 2),    testEntry(5, 2), testEntry(6, 3),
    };
    var topology = try Topology.build(std.testing.allocator, &entries);
    defer topology.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), topology.edgeCount());
    try std.testing.expect(topology.contains(4));
    try std.testing.expect(!topology.contains(99));

    const roots = try topology.childrenAlloc(std.testing.allocator, 1);
    defer std.testing.allocator.free(roots);
    try std.testing.expectEqualSlices(u64, &.{ 2, 3 }, roots);

    const leaves = try topology.childrenAlloc(std.testing.allocator, 6);
    defer std.testing.allocator.free(leaves);
    try std.testing.expectEqual(@as(usize, 0), leaves.len);

    try std.testing.expectError(error.EventNotFound, topology.childrenAlloc(std.testing.allocator, 99));
}

test "descendants walk breadth-first and report every bound they hit" {
    const entries = [_]Entry{
        testEntry(1, null), testEntry(2, 1), testEntry(3, 1),
        testEntry(4, 2),    testEntry(5, 2), testEntry(6, 3),
    };
    var topology = try Topology.build(std.testing.allocator, &entries);
    defer topology.deinit(std.testing.allocator);

    var all = try topology.descendantsAlloc(std.testing.allocator, 1, .{});
    defer all.deinit(std.testing.allocator);
    // Nearest cause first: both children before any grandchild.
    try std.testing.expectEqualSlices(u64, &.{ 2, 3, 4, 5, 6 }, all.ids);
    try std.testing.expect(!all.truncated);

    // A leaf has no descendants, and that is not a truncation.
    var none = try topology.descendantsAlloc(std.testing.allocator, 5, .{});
    defer none.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), none.ids.len);
    try std.testing.expect(!none.truncated);

    // Depth-bounded: one level only, and it must admit there is more below.
    var shallow = try topology.descendantsAlloc(std.testing.allocator, 1, .{ .max_depth = 1 });
    defer shallow.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u64, &.{ 2, 3 }, shallow.ids);
    try std.testing.expect(shallow.truncated);

    // Count-bounded, likewise.
    var capped = try topology.descendantsAlloc(std.testing.allocator, 1, .{ .max_results = 2 });
    defer capped.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), capped.ids.len);
    try std.testing.expect(capped.truncated);

    // A depth bound that happens to reach every leaf is not a truncation.
    var exact = try topology.descendantsAlloc(std.testing.allocator, 1, .{ .max_depth = 2 });
    defer exact.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 5), exact.ids.len);
    try std.testing.expect(!exact.truncated);

    try std.testing.expectError(error.InvalidTraversalLimit, topology.descendantsAlloc(std.testing.allocator, 1, .{ .max_depth = 0 }));
    try std.testing.expectError(error.EventNotFound, topology.descendantsAlloc(std.testing.allocator, 99, .{}));
}

test "ancestors walk the parent column to the root" {
    const entries = [_]Entry{
        testEntry(1, null), testEntry(2, 1), testEntry(3, 2), testEntry(4, 3),
    };
    var topology = try Topology.build(std.testing.allocator, &entries);
    defer topology.deinit(std.testing.allocator);

    var chain = try topology.ancestorsAlloc(std.testing.allocator, 4, .{});
    defer chain.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u64, &.{ 3, 2, 1 }, chain.ids);
    try std.testing.expect(!chain.truncated);

    var root = try topology.ancestorsAlloc(std.testing.allocator, 1, .{});
    defer root.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), root.ids.len);

    var partial = try topology.ancestorsAlloc(std.testing.allocator, 4, .{ .max_depth = 2 });
    defer partial.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u64, &.{ 3, 2 }, partial.ids);
    try std.testing.expect(partial.truncated);
}

test "traversal costs do not grow with graph size" {
    // The point of the CSR index is that answering "children of X" stops being
    // a pass over every record. This asserts the shape rather than a timing:
    // a node's children are a contiguous slice, so a wide graph and a narrow one
    // cost the same per lookup.
    const width = 512;
    var entries: [1 + width]Entry = undefined;
    entries[0] = testEntry(1, null);
    for (1..entries.len) |position| entries[position] = testEntry(position + 1, 1);

    var topology = try Topology.build(std.testing.allocator, &entries);
    defer topology.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, width), topology.edgeCount());

    const root_index = topology.indexOf(1).?;
    // One slice, no scan, regardless of how many nodes exist.
    try std.testing.expectEqual(@as(usize, width), topology.childIndices(root_index).len);
    // A leaf's lookup is equally cheap and yields nothing.
    try std.testing.expectEqual(@as(usize, 0), topology.childIndices(topology.indexOf(300).?).len);

    var walk = try topology.descendantsAlloc(std.testing.allocator, 1, .{ .max_results = 4096 });
    defer walk.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, width), walk.ids.len);
    try std.testing.expect(!walk.truncated);
}

test "a topology built over a window ignores parents outside it" {
    // Compaction drops whole sessions, so a retained record can reference a
    // parent that is no longer present. That must not be an error.
    const entries = [_]Entry{ testEntry(10, 4), testEntry(11, 10), testEntry(12, 10) };
    var topology = try Topology.build(std.testing.allocator, &entries);
    defer topology.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), topology.edgeCount());
    var below = try topology.descendantsAlloc(std.testing.allocator, 10, .{});
    defer below.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u64, &.{ 11, 12 }, below.ids);

    var above = try topology.ancestorsAlloc(std.testing.allocator, 11, .{});
    defer above.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u64, &.{10}, above.ids);
}
