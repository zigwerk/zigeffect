const std = @import("std");

pub const config_path = ".zgraphy/config.json";
pub const ignore_path = ".zgraphyignore";

pub const InitStatus = enum {
    initialized,
    already_initialized,
};

pub const Config = struct {
    schema: []const u8 = "zgraphy.config.v1",
    schema_version: u32 = 1,
    database: []const u8 = ".zgraphy/nendb.jsonl",
    max_files: usize = 100_000,
    max_file_bytes: usize = 4 * 1024 * 1024,
    max_source_bytes: usize = 512 * 1024 * 1024,
    max_nodes: usize = 100_000,
    max_edges: usize = 500_000,
};

pub fn init(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir) !InitStatus {
    root.access(io, config_path, .{}) catch |failure| switch (failure) {
        error.FileNotFound => {
            try root.createDirPath(io, ".zgraphy");
            const encoded = try std.json.Stringify.valueAlloc(allocator, Config{}, .{ .whitespace = .indent_2 });
            defer allocator.free(encoded);
            try root.writeFile(io, .{ .sub_path = config_path, .data = encoded });
            root.access(io, ignore_path, .{}) catch |ignore_failure| switch (ignore_failure) {
                error.FileNotFound => try root.writeFile(io, .{
                    .sub_path = ignore_path,
                    .data = ".git/\n.zgraphy/\n.zig-cache/\nzig-out/\nnode_modules/\n",
                }),
                else => return ignore_failure,
            };
            return .initialized;
        },
        else => return failure,
    };
    return .already_initialized;
}

pub fn loadConfig(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir) !std.json.Parsed(Config) {
    const bytes = try root.readFileAlloc(io, config_path, allocator, .limited(1024 * 1024));
    defer allocator.free(bytes);
    const parsed = try std.json.parseFromSlice(Config, allocator, bytes, .{ .allocate = .alloc_always });
    if (!std.mem.eql(u8, parsed.value.schema, "zgraphy.config.v1") or parsed.value.schema_version != 1) {
        var owned = parsed;
        owned.deinit();
        return error.IncompatibleConfig;
    }
    return parsed;
}
