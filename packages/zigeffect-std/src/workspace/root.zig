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

pub fn ResolveEffect(comptime EffectEnv: type) type {
    return struct {
        pub const SuccessType = []const u8;
        pub const FailureType = anyerror;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Service};

        relative: []const u8,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType![]const u8 {
            const workspace = ctx.service(Service);
            const resolved = workspace.resolveAlloc(ctx.allocator, self.relative) catch |err| {
                _ = StdService.recordOperation(ctx, Service, "resolve", "failure", self.relative);
                return err;
            };
            _ = StdService.recordOperation(ctx, Service, "resolve", "success", self.relative);
            return resolved;
        }
    };
}

pub fn SnapshotEffect(comptime EffectEnv: type, comptime FileSystemService: type) type {
    return struct {
        pub const SuccessType = []const FileSnapshot;
        pub const FailureType = anyerror;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{ Service, FileSystemService };

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(_: @This(), ctx: *fx.Context(EffectEnv)) FailureType![]const FileSnapshot {
            const workspace = ctx.service(Service);
            const fs = ctx.service(FileSystemService);
            const snapshot = snapshotWithIgnoresAlloc(ctx.allocator, workspace.*, fs) catch |err| {
                _ = StdService.recordOperation(ctx, Service, "snapshot", "failure", workspace.workspace.root);
                return err;
            };
            _ = StdService.recordOperation(ctx, Service, "snapshot", "success", workspace.workspace.root);
            return snapshot;
        }
    };
}

pub fn DiffEffect(comptime EffectEnv: type) type {
    return struct {
        pub const SuccessType = []const []const u8;
        pub const FailureType = anyerror;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Service};

        before: []const FileSnapshot,
        after: []const FileSnapshot,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType![]const []const u8 {
            const workspace = ctx.service(Service);
            const diff = diffWithIgnoresAlloc(ctx.allocator, workspace.*, self.before, self.after) catch |err| {
                _ = StdService.recordOperation(ctx, Service, "diff", "failure", workspace.workspace.root);
                return err;
            };
            _ = StdService.recordOperation(ctx, Service, "diff", "success", workspace.workspace.root);
            return diff;
        }
    };
}

pub fn resolveEffect(comptime EffectEnv: type, relative: []const u8) ResolveEffect(EffectEnv) {
    return .{ .relative = relative };
}

pub fn snapshotEffect(comptime EffectEnv: type, comptime FileSystemService: type) SnapshotEffect(EffectEnv, FileSystemService) {
    return .{};
}

pub fn diffEffect(
    comptime EffectEnv: type,
    before: []const FileSnapshot,
    after: []const FileSnapshot,
) DiffEffect(EffectEnv) {
    return .{ .before = before, .after = after };
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
    const zstd = @import("../root.zig");

    var fs = FileSystem.MemoryFileSystem.init(std.testing.allocator);
    defer fs.deinit();
    try fs.writeFile("src/main.zig", "pub fn main() void {}");
    try fs.writeFile(".zig-cache/tmp", "ignored");

    const ignores = [_]IgnoreRule{.{ .prefix = ".zig-cache/" }};
    var workspace = Service.init("/repo", ignores[0..]);
    var provider = zstd.Service.Provider(.{ Service, FileSystem.MemoryFileSystem }).init(.{ &workspace, &fs });
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{ Service, FileSystem.MemoryFileSystem })
        .withCausalStore(&store);

    const resolved = try runtime.run(resolveEffect(@TypeOf(provider), "src/main.zig"));
    defer std.testing.allocator.free(resolved);
    try std.testing.expectEqualStrings("/repo/src/main.zig", resolved);

    const snapshot = try runtime.run(snapshotEffect(@TypeOf(provider), FileSystem.MemoryFileSystem));
    defer freeSnapshot(std.testing.allocator, snapshot);

    try std.testing.expectEqual(@as(usize, 1), snapshot.len);
    try std.testing.expectEqualStrings("src/main.zig", snapshot[0].path);

    var causal_snapshot = try store.snapshot(std.testing.allocator);
    defer causal_snapshot.deinit();
    try std.testing.expect(causal_snapshot.events.len >= 2);
    try std.testing.expectEqualStrings(@typeName(Service), causal_snapshot.events[0].service_key);
}

test "Workspace diff filters ignored paths and records causal facts" {
    const zstd = @import("../root.zig");

    const ignores = [_]IgnoreRule{.{ .prefix = ".zig-cache/" }};
    var workspace = Service.init("/repo", ignores[0..]);
    var provider = zstd.Service.Provider(.{Service}).init(.{&workspace});
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{Service})
        .withCausalStore(&store);

    const before = [_]FileSnapshot{
        .{ .path = "src/main.zig", .content = "old" },
        .{ .path = ".zig-cache/tmp", .content = "old" },
    };
    const after = [_]FileSnapshot{
        .{ .path = "src/main.zig", .content = "new" },
        .{ .path = ".zig-cache/tmp", .content = "new" },
    };

    const diff = try runtime.run(diffEffect(@TypeOf(provider), before[0..], after[0..]));
    defer freeDiff(std.testing.allocator, diff);

    try std.testing.expectEqual(@as(usize, 1), diff.len);
    try std.testing.expectEqualStrings("src/main.zig", diff[0]);

    var causal_snapshot = try store.snapshot(std.testing.allocator);
    defer causal_snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), causal_snapshot.events.len);
    try std.testing.expectEqualStrings("diff", causal_snapshot.events[0].label);
}
