const std = @import("std");
const discovery = @import("discovery.zig");

pub const config_path = ".zgraphy/config.json";
pub const config_next_path = ".zgraphy/config.json.next";
pub const ignore_path = ".zgraphyignore";

pub const InitStatus = enum {
    initialized,
    already_initialized,
};

pub const Config = struct {
    schema: []const u8 = "zgraphy.config.v2",
    schema_version: u32 = 2,
    repository_id: []const u8 = "repo-00000000000000000000000000000000",
    database: []const u8 = ".zgraphy/nendb.jsonl",
    content_manifest: []const u8 = ".zgraphy/content-manifest.json",
    health_report: []const u8 = ".zgraphy/graph-health.json",
    max_entries: usize = 200_000,
    max_files: usize = 100_000,
    max_file_bytes: usize = 4 * 1024 * 1024,
    max_source_bytes: usize = 512 * 1024 * 1024,
    max_depth: usize = 128,
    max_path_bytes: usize = std.fs.max_path_bytes,
    max_nodes: usize = 100_000,
    max_edges: usize = 500_000,
    automatic_gc: bool = true,
    retention_generations: usize = 8,
    retention_grace_ms: u64 = 5 * 60 * 1000,
};

const ConfigV1 = struct {
    schema: []const u8 = "zgraphy.config.v1",
    schema_version: u32 = 1,
    database: []const u8 = ".zgraphy/nendb.jsonl",
    max_files: usize = 100_000,
    max_file_bytes: usize = 4 * 1024 * 1024,
    max_source_bytes: usize = 512 * 1024 * 1024,
    max_nodes: usize = 100_000,
    max_edges: usize = 500_000,
};

const ConfigHeader = struct {
    schema: []const u8,
    schema_version: u32,
};

pub fn init(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir) !InitStatus {
    root.access(io, config_path, .{}) catch |failure| switch (failure) {
        error.FileNotFound => {
            try root.createDirPath(io, ".zgraphy");
            var repository_id_buffer: [37]u8 = @splat(0);
            const repository_id = try generateRepositoryId(io, &repository_id_buffer);
            try writeConfig(allocator, io, root, .{ .repository_id = repository_id });
            try ensureIgnoreFile(io, root);
            return .initialized;
        },
        else => return failure,
    };
    var config = try loadConfig(allocator, io, root);
    config.deinit();
    try ensureIgnoreFile(io, root);
    return .already_initialized;
}

pub fn loadConfig(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir) !std.json.Parsed(Config) {
    const bytes = try root.readFileAlloc(io, config_path, allocator, .limited(1024 * 1024));
    defer allocator.free(bytes);

    var header = std.json.parseFromSlice(ConfigHeader, allocator, bytes, .{ .ignore_unknown_fields = true }) catch return error.InvalidConfig;
    defer header.deinit();
    if (std.mem.eql(u8, header.value.schema, "zgraphy.config.v1") and header.value.schema_version == 1) {
        var legacy = std.json.parseFromSlice(ConfigV1, allocator, bytes, .{ .allocate = .alloc_always }) catch return error.InvalidConfig;
        defer legacy.deinit();
        var repository_id_buffer: [37]u8 = @splat(0);
        const repository_id = try generateRepositoryId(io, &repository_id_buffer);
        try writeConfig(allocator, io, root, .{
            .repository_id = repository_id,
            .database = legacy.value.database,
            .max_files = legacy.value.max_files,
            .max_file_bytes = legacy.value.max_file_bytes,
            .max_source_bytes = legacy.value.max_source_bytes,
            .max_nodes = legacy.value.max_nodes,
            .max_edges = legacy.value.max_edges,
        });
        return loadConfig(allocator, io, root);
    }
    if (!std.mem.eql(u8, header.value.schema, "zgraphy.config.v2") or header.value.schema_version != 2) return error.IncompatibleConfig;

    const parsed = std.json.parseFromSlice(Config, allocator, bytes, .{ .allocate = .alloc_always }) catch return error.InvalidConfig;
    validateConfig(parsed.value) catch |failure| {
        var invalid = parsed;
        invalid.deinit();
        return failure;
    };
    return parsed;
}

pub fn validateConfig(config: Config) !void {
    if (!std.mem.eql(u8, config.schema, "zgraphy.config.v2") or config.schema_version != 2 or
        !discovery.isValidRepositoryId(config.repository_id) or !validOwnedPath(config.database) or
        !validOwnedPath(config.content_manifest) or !validOwnedPath(config.health_report) or
        config.max_entries == 0 or config.max_files == 0 or config.max_file_bytes == 0 or
        config.max_source_bytes == 0 or config.max_depth == 0 or config.max_path_bytes == 0 or
        config.max_path_bytes > std.fs.max_path_bytes or config.max_nodes == 0 or config.max_edges == 0 or
        config.retention_generations < 2 or config.retention_generations > 128 or
        config.retention_grace_ms > 30 * 24 * 60 * 60 * 1000)
    {
        return error.InvalidConfig;
    }
}

fn validOwnedPath(path: []const u8) bool {
    return path.len > 0 and !std.fs.path.isAbsolute(path) and std.mem.indexOf(u8, path, "..") == null and
        std.mem.indexOfScalar(u8, path, '\\') == null;
}

fn generateRepositoryId(io: std.Io, output: *[37]u8) ![]const u8 {
    var entropy: [16]u8 = @splat(0);
    try io.randomSecure(&entropy);
    output[0..5].* = "repo-".*;
    output[5..].* = std.fmt.bytesToHex(entropy, .lower);
    return output;
}

fn writeConfig(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, config: Config) !void {
    try validateConfig(config);
    const encoded = try std.json.Stringify.valueAlloc(allocator, config, .{ .whitespace = .indent_2 });
    defer allocator.free(encoded);
    root.deleteFile(io, config_next_path) catch |failure| switch (failure) {
        error.FileNotFound => {},
        else => return failure,
    };
    try root.writeFile(io, .{ .sub_path = config_next_path, .data = encoded });
    errdefer root.deleteFile(io, config_next_path) catch {};
    try root.rename(config_next_path, root, config_path, io);
}

fn ensureIgnoreFile(io: std.Io, root: std.Io.Dir) !void {
    root.access(io, ignore_path, .{}) catch |failure| switch (failure) {
        error.FileNotFound => try root.writeFile(io, .{
            .sub_path = ignore_path,
            .data = ".git/\n.zgraphy/\n.zigeffect/\n.zig-cache/\nzig-out/\nnode_modules/\n",
        }),
        else => return failure,
    };
}
