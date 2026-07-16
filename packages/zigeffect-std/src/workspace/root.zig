const std = @import("std");
const FileSystem = @import("../filesystem/root.zig");
const Path = @import("../path/root.zig");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

pub const FileSnapshot = struct {
    path: []const u8,
    content: []const u8,
};

pub const Workspace = struct {
    root: []const u8,

    pub fn init(root: []const u8) Workspace {
        return .{ .root = root };
    }

    pub fn resolveAlloc(
        self: Workspace,
        allocator: std.mem.Allocator,
        relative: []const u8,
    ) ![]const u8 {
        return Path.joinAlloc(allocator, &.{ self.root, relative });
    }

    pub fn snapshotAlloc(
        self: Workspace,
        allocator: std.mem.Allocator,
        fs: FileSystem.MemoryFileSystem,
    ) ![]const FileSnapshot {
        _ = self;
        const paths = try fs.listPaths(allocator);
        defer FileSystem.freePathList(allocator, paths);

        var snapshots = std.ArrayList(FileSnapshot).empty;
        errdefer {
            for (snapshots.items) |snapshot| {
                allocator.free(snapshot.path);
                allocator.free(snapshot.content);
            }
            snapshots.deinit(allocator);
        }

        for (paths) |path| {
            const content = fs.readFile(path).?;
            try snapshots.append(allocator, .{
                .path = try allocator.dupe(u8, path),
                .content = try allocator.dupe(u8, content),
            });
        }

        return snapshots.toOwnedSlice(allocator);
    }
};

pub const IgnoreRule = struct {
    prefix: []const u8,
};

pub const Service = struct {
    pub const operations: []const []const u8 = &.{ "Workspace.resolve", "Workspace.snapshot", "Workspace.diff" };

    workspace: Workspace,
    ignores: []const IgnoreRule = &.{},

    pub fn init(root: []const u8, ignores: []const IgnoreRule) Service {
        return .{
            .workspace = Workspace.init(root),
            .ignores = ignores,
        };
    }

    pub fn resolveAlloc(self: Service, allocator: std.mem.Allocator, relative: []const u8) ![]const u8 {
        return self.workspace.resolveAlloc(allocator, relative);
    }

    pub fn isIgnored(self: Service, path: []const u8) bool {
        for (self.ignores) |ignore| {
            if (std.mem.startsWith(u8, path, ignore.prefix)) return true;
        }
        return false;
    }
};

pub const WorkspaceService = fx.kernel.Service("zigeffect/std/Workspace", Service);

pub fn layer(service: Service) @TypeOf(fx.kernel.Layer.succeed(WorkspaceService, service)) {
    return fx.kernel.Layer.succeed(WorkspaceService, service);
}

pub fn resolve(relative: []const u8) fx.kernel.Effect(
    []const u8,
    anyerror,
    .{WorkspaceService},
).Stateful([]const u8) {
    const Resolve = fx.kernel.Effect([]const u8, anyerror, .{WorkspaceService});
    return Resolve.fromState([]const u8, relative, struct {
        fn run(value: []const u8, ctx: *Resolve.Context) anyerror![]const u8 {
            const operation = StdService.beginOperation(ctx, WorkspaceService.service_key, "Workspace.resolve", value);
            const resolved = ctx.service(WorkspaceService).resolveAlloc(ctx.allocator(), value) catch |failure| {
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.completeOperation(ctx, operation, "success", value);
            return resolved;
        }
    }.run);
}

pub fn capture() fx.kernel.Effect(
    []const FileSnapshot,
    anyerror,
    .{ WorkspaceService, FileSystem.FileSystem },
) {
    const SnapshotFiles = fx.kernel.Effect([]const FileSnapshot, anyerror, .{ WorkspaceService, FileSystem.FileSystem });
    return SnapshotFiles.fromFn(struct {
        fn run(ctx: *SnapshotFiles.Context) anyerror![]const FileSnapshot {
            const workspace = ctx.service(WorkspaceService);
            const operation = StdService.beginOperation(ctx, WorkspaceService.service_key, "Workspace.snapshot", workspace.workspace.root);
            const result = snapshotWithIgnoresAlloc(ctx.allocator(), workspace.*, ctx.service(FileSystem.FileSystem).*) catch |failure| {
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.completeOperation(ctx, operation, "success", workspace.workspace.root);
            return result;
        }
    }.run);
}

const DiffInput = struct { before: []const FileSnapshot, after: []const FileSnapshot };

pub fn changes(before: []const FileSnapshot, after: []const FileSnapshot) fx.kernel.Effect(
    []const []const u8,
    anyerror,
    .{WorkspaceService},
).Stateful(DiffInput) {
    const Diff = fx.kernel.Effect([]const []const u8, anyerror, .{WorkspaceService});
    return Diff.fromState(DiffInput, .{ .before = before, .after = after }, struct {
        fn run(input: DiffInput, ctx: *Diff.Context) anyerror![]const []const u8 {
            const workspace = ctx.service(WorkspaceService);
            const operation = StdService.beginOperation(ctx, WorkspaceService.service_key, "Workspace.diff", workspace.workspace.root);
            const result = diffWithIgnoresAlloc(ctx.allocator(), workspace.*, input.before, input.after) catch |failure| {
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.completeOperation(ctx, operation, "success", workspace.workspace.root);
            return result;
        }
    }.run);
}

pub fn diffAlloc(
    allocator: std.mem.Allocator,
    before: []const FileSnapshot,
    after: []const FileSnapshot,
) ![]const []const u8 {
    var diff = std.ArrayList([]const u8).empty;
    errdefer {
        for (diff.items) |path| allocator.free(path);
        diff.deinit(allocator);
    }

    for (after) |after_snapshot| {
        const before_snapshot = findSnapshot(before, after_snapshot.path);
        if (before_snapshot == null or !std.mem.eql(u8, before_snapshot.?.content, after_snapshot.content)) {
            try diff.append(allocator, try allocator.dupe(u8, after_snapshot.path));
        }
    }

    return diff.toOwnedSlice(allocator);
}

pub fn snapshotWithIgnoresAlloc(
    allocator: std.mem.Allocator,
    service: Service,
    fs: anytype,
) ![]const FileSnapshot {
    const paths = try fs.listPaths(allocator);
    defer FileSystem.freePathList(allocator, paths);

    var snapshots = std.ArrayList(FileSnapshot).empty;
    errdefer {
        for (snapshots.items) |snapshot| {
            allocator.free(snapshot.path);
            allocator.free(snapshot.content);
        }
        snapshots.deinit(allocator);
    }

    for (paths) |path| {
        if (service.isIgnored(path)) continue;
        const content = try fs.readFileAlloc(allocator, path);
        errdefer allocator.free(content);
        try snapshots.append(allocator, .{
            .path = try allocator.dupe(u8, path),
            .content = content,
        });
    }

    return snapshots.toOwnedSlice(allocator);
}

pub fn diffWithIgnoresAlloc(
    allocator: std.mem.Allocator,
    service: Service,
    before: []const FileSnapshot,
    after: []const FileSnapshot,
) ![]const []const u8 {
    var diff = std.ArrayList([]const u8).empty;
    errdefer {
        for (diff.items) |path| allocator.free(path);
        diff.deinit(allocator);
    }

    for (after) |after_snapshot| {
        if (service.isIgnored(after_snapshot.path)) continue;
        const before_snapshot = findSnapshot(before, after_snapshot.path);
        if (before_snapshot == null or !std.mem.eql(u8, before_snapshot.?.content, after_snapshot.content)) {
            try diff.append(allocator, try allocator.dupe(u8, after_snapshot.path));
        }
    }

    return diff.toOwnedSlice(allocator);
}

pub fn freeSnapshot(allocator: std.mem.Allocator, snapshot: []const FileSnapshot) void {
    for (snapshot) |file| {
        allocator.free(file.path);
        allocator.free(file.content);
    }
    allocator.free(snapshot);
}

pub fn freeDiff(allocator: std.mem.Allocator, diff: []const []const u8) void {
    for (diff) |path| allocator.free(path);
    allocator.free(diff);
}

fn findSnapshot(snapshots: []const FileSnapshot, path: []const u8) ?FileSnapshot {
    for (snapshots) |snapshot| {
        if (std.mem.eql(u8, snapshot.path, path)) return snapshot;
    }
    return null;
}

test "Workspace resolves relative paths and captures snapshots" {
    var fs = FileSystem.MemoryFileSystem.init(std.testing.allocator);
    defer fs.deinit();

    try fs.writeFile("src/main.zig", "pub fn main() void {}");
    const workspace = Workspace.init("/repo");

    const resolved = try workspace.resolveAlloc(std.testing.allocator, "src/main.zig");
    defer std.testing.allocator.free(resolved);
    try std.testing.expectEqualStrings("/repo/src/main.zig", resolved);

    const snapshot = try workspace.snapshotAlloc(std.testing.allocator, fs);
    defer freeSnapshot(std.testing.allocator, snapshot);

    try std.testing.expectEqual(@as(usize, 1), snapshot.len);
    try std.testing.expectEqualStrings("src/main.zig", snapshot[0].path);
    try std.testing.expectEqualStrings("pub fn main() void {}", snapshot[0].content);
}

test "Workspace diff reports changed files" {
    const before = [_]FileSnapshot{
        .{ .path = "a.txt", .content = "old" },
    };
    const after = [_]FileSnapshot{
        .{ .path = "a.txt", .content = "new" },
        .{ .path = "b.txt", .content = "created" },
    };

    const diff = try diffAlloc(std.testing.allocator, before[0..], after[0..]);
    defer freeDiff(std.testing.allocator, diff);

    try std.testing.expectEqual(@as(usize, 2), diff.len);
    try std.testing.expectEqualStrings("a.txt", diff[0]);
    try std.testing.expectEqualStrings("b.txt", diff[1]);
}

test "Workspace service resolves and snapshots through FileSystem effects" {
    var fs = FileSystem.MemoryFileSystem.init(std.testing.allocator);
    defer fs.deinit();
    try fs.writeFile("src/main.zig", "pub fn main() void {}");
    try fs.writeFile(".zig-cache/tmp", "ignored");

    const ignores = [_]IgnoreRule{.{ .prefix = ".zig-cache/" }};
    const workspace = Service.init("/repo", ignores[0..]);
    const root = fx.kernel.Layer.mergeAll(.{ layer(workspace), FileSystem.memory(&fs) });
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{ .causal_store = &store });
    defer runtime.deinit();

    const resolved = try runtime.run(resolve("src/main.zig"));
    defer std.testing.allocator.free(resolved);
    try std.testing.expectEqualStrings("/repo/src/main.zig", resolved);

    const files = try runtime.run(capture());
    defer freeSnapshot(std.testing.allocator, files);

    try std.testing.expectEqual(@as(usize, 1), files.len);
    try std.testing.expectEqualStrings("src/main.zig", files[0].path);

    var causal_snapshot = try store.snapshot(std.testing.allocator);
    defer causal_snapshot.deinit();
    try std.testing.expect(causal_snapshot.events.len >= 2);
    var saw = false;
    for (causal_snapshot.events) |event| {
        if (std.mem.eql(u8, event.service_key, WorkspaceService.service_key)) saw = true;
    }
    try std.testing.expect(saw);
}

test "Workspace diff filters ignored paths and records causal facts" {
    const ignores = [_]IgnoreRule{.{ .prefix = ".zig-cache/" }};
    const workspace = Service.init("/repo", ignores[0..]);
    const root = layer(workspace);
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{ .causal_store = &store });
    defer runtime.deinit();

    const before = [_]FileSnapshot{
        .{ .path = "src/main.zig", .content = "old" },
        .{ .path = ".zig-cache/tmp", .content = "old" },
    };
    const after = [_]FileSnapshot{
        .{ .path = "src/main.zig", .content = "new" },
        .{ .path = ".zig-cache/tmp", .content = "new" },
    };

    const changed = try runtime.run(changes(before[0..], after[0..]));
    defer freeDiff(std.testing.allocator, changed);

    try std.testing.expectEqual(@as(usize, 1), changed.len);
    try std.testing.expectEqualStrings("src/main.zig", changed[0]);

    var causal_snapshot = try store.snapshot(std.testing.allocator);
    defer causal_snapshot.deinit();
    var saw = false;
    for (causal_snapshot.events) |event| {
        if (event.kind == .io_completed and std.mem.eql(u8, event.service_key, WorkspaceService.service_key)) saw = true;
    }
    try std.testing.expect(saw);
}
