//! zgdb as a ZigEffect service: an opened database, scoped to a lifetime.
//!
//! **What is effectful here, and what deliberately is not.**
//!
//! `Store` is a data structure. `addNode` returns `!u64` and should keep doing
//! so: wrapping a struct-of-arrays append in an effect adds ceremony to
//! something that does no I/O, cannot fail in an interesting way, and has no
//! dependencies to inject. An effect that never suspends and never needs a
//! service is a slower `!T` with a longer name.
//!
//! What genuinely belongs in the effect system is the **lifetime**. A database is
//! acquired, used, and released; the release must happen even when the work in
//! between fails; and the thing acquiring it should not have to remember. That
//! is exactly what a scoped layer is for, and it is the boundary an application
//! actually composes against.
//!
//! So: primitives stay plain, the lifecycle is a `Layer.scoped`, and an
//! application asks for `Database` rather than constructing a store and hoping
//! its `defer` is in the right place.

const std = @import("std");
const fx = @import("zigeffect");
const Store = @import("nendb.zig");

/// What a holder of the database can do with it.
///
/// Deliberately narrow. This is the service boundary, not the store's API — a
/// consumer that wants the full struct-of-arrays surface reaches through
/// `graph`, and one that only needs to know how large the graph is does not have
/// to.
pub const DatabaseApi = struct {
    graph: *Store.GraphData,

    pub fn nodeCount(self: DatabaseApi) usize {
        return self.graph.node_count;
    }

    pub fn edgeCount(self: DatabaseApi) usize {
        return self.graph.edge_count;
    }
};

pub const Database = fx.kernel.Service("zgdb/Database", DatabaseApi);

/// Failures a caller can actually do something about.
///
/// `OutOfMemory` is separate from `CapacityExceeded` because they call for
/// different responses: one is the machine, the other is a configured budget the
/// caller chose and can raise.
pub const OpenError = error{
    OutOfMemory,
    CapacityExceeded,
};

const Owned = struct {
    allocator: std.mem.Allocator,
    graph: Store.GraphData,
};

/// Capacity the scoped database opens with.
///
/// The store's own defaults, named here so the service has one place to change
/// them and a caller can see what it is getting rather than inheriting a number
/// from two layers down.
pub const default_options = Store.Options{};

fn acquire(context: anytype) OpenError!DatabaseApi {
    const allocator = context.allocator();
    const owned = allocator.create(Owned) catch return error.OutOfMemory;
    errdefer allocator.destroy(owned);
    owned.* = .{
        .allocator = allocator,
        .graph = Store.GraphData.init(allocator, default_options) catch |failure| return switch (failure) {
            error.OutOfMemory => error.OutOfMemory,
            else => error.CapacityExceeded,
        },
    };
    return .{ .graph = &owned.graph };
}

fn release(api: *DatabaseApi) void {
    // The `Owned` wrapper exists so release can find the allocator from the one
    // pointer the service carries. Reaching it from the interior `graph` field
    // is the standard @fieldParentPtr move and is why the layout is a struct
    // rather than two independent allocations.
    const owned: *Owned = @fieldParentPtr("graph", api.graph);
    const allocator = owned.allocator;
    owned.graph.deinit();
    allocator.destroy(owned);
}

/// A database that closes itself when the scope ends.
///
/// The release runs on the failure path too, which is the whole reason this is a
/// layer rather than a constructor plus a `defer` the caller has to place
/// correctly.
pub fn layer() @TypeOf(fx.kernel.Layer.scoped(Database, OpenError, .{}, acquire, release)) {
    return fx.kernel.Layer.scoped(Database, OpenError, .{}, acquire, release);
}

/// The number of nodes in the scoped database.
///
/// A method on the service rather than a free function taking a store: the point
/// of the layer is that a caller asks the runtime for the database instead of
/// carrying one.
pub fn nodeCountEffect() fx.kernel.Effect(usize, anyerror, .{Database}) {
    return fx.kernel.Effect(usize, anyerror, .{Database}).fromFn(struct {
        fn run(ctx: *fx.kernel.ContextView(.{Database})) anyerror!usize {
            return ctx.service(Database).nodeCount();
        }
    }.run);
}

fn addProbeNode() fx.kernel.Effect(void, anyerror, .{Database}) {
    return fx.kernel.Effect(void, anyerror, .{Database}).fromFn(struct {
        fn run(ctx: *fx.kernel.ContextView(.{Database})) anyerror!void {
            const zero: [Store.embedding_dimensions]f32 = @splat(0);
            _ = try ctx.service(Database).graph.addNode(1, 0, &zero, .{
                .label = "probe",
                .path = "probe.zig",
                .search_text = "probe",
            });
        }
    }.run);
}

test "the database is a scoped service and releases itself" {
    const root = layer();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{});
    defer runtime.deinit();

    try std.testing.expectEqual(@as(usize, 0), try runtime.run(nodeCountEffect()));
    try runtime.run(addProbeNode());
    try std.testing.expectEqual(@as(usize, 1), try runtime.run(nodeCountEffect()));
    // Release runs when the runtime's scope ends, including on a failure path —
    // the leak check in this suite is what proves it rather than a comment.
}
