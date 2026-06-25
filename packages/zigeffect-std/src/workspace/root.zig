const std = @import("std");
const FileSystem = @import("../filesystem/root.zig");
const Path = @import("../path/root.zig");

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
