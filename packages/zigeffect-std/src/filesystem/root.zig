const std = @import("std");

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
};

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
