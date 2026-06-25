const std = @import("std");
const Secrets = @import("../secrets/root.zig");

pub const MemoryFileSystem = struct {
    allocator: std.mem.Allocator,
    files: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) MemoryFileSystem {
        return .{
            .allocator = allocator,
            .files = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *MemoryFileSystem) void {
        var iterator = self.files.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.files.deinit();
    }

    pub fn writeFile(
        self: *MemoryFileSystem,
        path: []const u8,
        content: []const u8,
    ) std.mem.Allocator.Error!void {
        if (self.files.fetchRemove(path)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        try self.files.put(
            try self.allocator.dupe(u8, path),
            try self.allocator.dupe(u8, content),
        );
    }

    pub fn readFile(self: MemoryFileSystem, path: []const u8) ?[]const u8 {
        return self.files.get(path);
    }

    pub fn exists(self: MemoryFileSystem, path: []const u8) bool {
        return self.files.contains(path);
    }

    pub fn deleteFile(self: *MemoryFileSystem, path: []const u8) void {
        if (self.files.fetchRemove(path)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
    }

    pub fn listPaths(self: MemoryFileSystem, allocator: std.mem.Allocator) ![]const []const u8 {
        var paths = std.ArrayList([]const u8).empty;
        errdefer {
            for (paths.items) |path| allocator.free(path);
            paths.deinit(allocator);
        }

        var iterator = self.files.keyIterator();
        while (iterator.next()) |path| {
            try paths.append(allocator, try allocator.dupe(u8, path.*));
        }

        const owned = try paths.toOwnedSlice(allocator);
        std.mem.sort([]const u8, owned, {}, lessThanPath);
        return owned;
    }

    pub fn atomicWriteFile(
        self: *MemoryFileSystem,
        path: []const u8,
        content: []const u8,
    ) std.mem.Allocator.Error!void {
        try self.writeFile(path, content);
    }
};

pub fn freePathList(allocator: std.mem.Allocator, paths: []const []const u8) void {
    for (paths) |path| allocator.free(path);
    allocator.free(paths);
}

pub fn diagnosticPathAlloc(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return Secrets.redactAlloc(allocator, path);
}

fn lessThanPath(_: void, left: []const u8, right: []const u8) bool {
    return std.mem.order(u8, left, right) == .lt;
}

test "FileSystem writes reads exists and deletes memory files" {
    var fs = MemoryFileSystem.init(std.testing.allocator);
    defer fs.deinit();

    try fs.writeFile("notes/hello.txt", "hello");

    try std.testing.expect(fs.exists("notes/hello.txt"));
    try std.testing.expectEqualStrings("hello", fs.readFile("notes/hello.txt").?);

    fs.deleteFile("notes/hello.txt");
    try std.testing.expect(!fs.exists("notes/hello.txt"));
    try std.testing.expectEqual(@as(?[]const u8, null), fs.readFile("notes/hello.txt"));
}

test "FileSystem lists paths and atomic write replaces content" {
    var fs = MemoryFileSystem.init(std.testing.allocator);
    defer fs.deinit();

    try fs.writeFile("b.txt", "b");
    try fs.writeFile("a.txt", "a");
    try fs.atomicWriteFile("a.txt", "updated");

    const paths = try fs.listPaths(std.testing.allocator);
    defer freePathList(std.testing.allocator, paths);

    try std.testing.expectEqual(@as(usize, 2), paths.len);
    try std.testing.expectEqualStrings("a.txt", paths[0]);
    try std.testing.expectEqualStrings("b.txt", paths[1]);
    try std.testing.expectEqualStrings("updated", fs.readFile("a.txt").?);
}

test "FileSystem redacts secret-shaped paths in diagnostics" {
    const diagnostic = try diagnosticPathAlloc(std.testing.allocator, "logs/token=abc123.txt");
    defer std.testing.allocator.free(diagnostic);

    try std.testing.expectEqualStrings("[REDACTED]", diagnostic);
}
