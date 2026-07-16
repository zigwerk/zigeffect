const std = @import("std");
const Secrets = @import("../secrets/root.zig");
const Capability = @import("../capability/root.zig");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

pub const FileSystemError = error{
    FileNotFound,
    AccessDenied,
    InvalidPath,
    IoFailure,
    OutOfMemory,
};

pub const API = struct {
    pub const operations: []const []const u8 = &.{
        "FileSystem.writeFile",
        "FileSystem.readFile",
        "FileSystem.exists",
        "FileSystem.remove",
    };

    state: *anyopaque,
    write_file_fn: *const fn (*anyopaque, []const u8, []const u8) FileSystemError!void,
    read_file_alloc_fn: *const fn (*anyopaque, std.mem.Allocator, []const u8) FileSystemError![]const u8,
    exists_fn: *const fn (*anyopaque, []const u8) FileSystemError!bool,
    remove_fn: *const fn (*anyopaque, []const u8) FileSystemError!void,

    pub fn from(comptime Implementation: type, implementation: *Implementation) API {
        return .{
            .state = implementation,
            .write_file_fn = struct {
                fn call(raw: *anyopaque, path: []const u8, content: []const u8) FileSystemError!void {
                    const typed: *Implementation = @ptrCast(@alignCast(raw));
                    typed.writeFile(path, content) catch |failure| return mapFileSystemError(failure);
                }
            }.call,
            .read_file_alloc_fn = struct {
                fn call(raw: *anyopaque, allocator: std.mem.Allocator, path: []const u8) FileSystemError![]const u8 {
                    const typed: *Implementation = @ptrCast(@alignCast(raw));
                    return typed.readFileAlloc(allocator, path) catch |failure| return mapFileSystemError(failure);
                }
            }.call,
            .exists_fn = struct {
                fn call(raw: *anyopaque, path: []const u8) FileSystemError!bool {
                    const typed: *Implementation = @ptrCast(@alignCast(raw));
                    return callExists(typed, path) catch |failure| return mapFileSystemError(failure);
                }
            }.call,
            .remove_fn = struct {
                fn call(raw: *anyopaque, path: []const u8) FileSystemError!void {
                    const typed: *Implementation = @ptrCast(@alignCast(raw));
                    callDelete(typed, path) catch |failure| return mapFileSystemError(failure);
                }
            }.call,
        };
    }

    pub fn writeFile(self: API, path: []const u8, content: []const u8) FileSystemError!void {
        return self.write_file_fn(self.state, path, content);
    }

    pub fn readFileAlloc(self: API, allocator: std.mem.Allocator, path: []const u8) FileSystemError![]const u8 {
        return self.read_file_alloc_fn(self.state, allocator, path);
    }

    pub fn exists(self: API, path: []const u8) FileSystemError!bool {
        return self.exists_fn(self.state, path);
    }

    pub fn remove(self: API, path: []const u8) FileSystemError!void {
        return self.remove_fn(self.state, path);
    }
};

/// Stable portable service tag. Applications require this tag, never a
/// MemoryFileSystem, LocalFileSystem, or other concrete driver type.
pub const FileSystem = fx.kernel.Service("zigeffect/std/FileSystem", API);

pub fn layer(comptime Implementation: type, implementation: *Implementation) @TypeOf(
    fx.kernel.Layer.succeed(FileSystem, API.from(Implementation, implementation)),
) {
    return fx.kernel.Layer.succeed(FileSystem, API.from(Implementation, implementation));
}

pub fn memory(implementation: *MemoryFileSystem) @TypeOf(layer(MemoryFileSystem, implementation)) {
    return layer(MemoryFileSystem, implementation);
}

pub fn local(implementation: *LocalFileSystem) @TypeOf(layer(LocalFileSystem, implementation)) {
    return layer(LocalFileSystem, implementation);
}

pub const MemoryFileSystem = struct {
    pub const capability = Capability.Builtin.memory_filesystem;

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
        const owned_path = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(owned_path);
        const owned_content = try self.allocator.dupe(u8, content);
        errdefer self.allocator.free(owned_content);
        if (self.files.fetchRemove(path)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        try self.files.put(owned_path, owned_content);
    }

    pub fn readFile(self: MemoryFileSystem, path: []const u8) ?[]const u8 {
        return self.files.get(path);
    }

    pub fn readFileAlloc(
        self: MemoryFileSystem,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) (FileSystemError || std.mem.Allocator.Error)![]const u8 {
        const content = self.readFile(path) orelse return FileSystemError.FileNotFound;
        return allocator.dupe(u8, content);
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

pub const LocalFileSystem = struct {
    pub const capability = Capability.Builtin.local_filesystem;

    dir: *std.Io.Dir,
    io: std.Io,
    read_limit: std.Io.Limit = .limited(1024 * 1024),

    pub fn init(dir: *std.Io.Dir, io: std.Io) LocalFileSystem {
        return .{ .dir = dir, .io = io };
    }

    pub fn writeFile(
        self: *LocalFileSystem,
        path: []const u8,
        content: []const u8,
    ) !void {
        try self.dir.writeFile(self.io, .{ .sub_path = path, .data = content });
    }

    pub fn readFileAlloc(
        self: *LocalFileSystem,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) ![]const u8 {
        return self.dir.readFileAlloc(self.io, path, allocator, self.read_limit);
    }

    pub fn exists(self: *LocalFileSystem, path: []const u8) !bool {
        self.dir.access(self.io, path, .{}) catch |err| switch (err) {
            error.FileNotFound => return false,
            else => return err,
        };
        return true;
    }

    pub fn deleteFile(self: *LocalFileSystem, path: []const u8) !void {
        try self.dir.deleteFile(self.io, path);
    }
};

pub fn WriteFileEffect(comptime EffectEnv: type, comptime FileSystemService: type) type {
    return struct {
        pub const SuccessType = void;
        pub const FailureType = anyerror;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{FileSystemService};

        path: []const u8,
        content: []const u8,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!void {
            const fs = ctx.service(FileSystemService);
            fs.writeFile(self.path, self.content) catch |err| {
                _ = StdService.recordOperation(ctx, FileSystemService, "writeFile", "failure", self.path);
                return err;
            };
            _ = StdService.recordOperation(ctx, FileSystemService, "writeFile", "success", self.path);
        }
    };
}

pub fn ReadFileEffect(comptime EffectEnv: type, comptime FileSystemService: type) type {
    return struct {
        pub const SuccessType = []const u8;
        pub const FailureType = anyerror;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{FileSystemService};

        path: []const u8,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType![]const u8 {
            const fs = ctx.service(FileSystemService);
            const content = fs.readFileAlloc(ctx.allocator, self.path) catch |err| {
                _ = StdService.recordOperation(ctx, FileSystemService, "readFile", "failure", self.path);
                return err;
            };
            _ = StdService.recordOperation(ctx, FileSystemService, "readFile", "success", self.path);
            return content;
        }
    };
}

pub fn DeleteFileEffect(comptime EffectEnv: type, comptime FileSystemService: type) type {
    return struct {
        pub const SuccessType = void;
        pub const FailureType = anyerror;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{FileSystemService};

        path: []const u8,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!void {
            const fs = ctx.service(FileSystemService);
            try callDelete(fs, self.path);
            _ = StdService.recordOperation(ctx, FileSystemService, "deleteFile", "success", self.path);
        }
    };
}

pub fn ExistsEffect(comptime EffectEnv: type, comptime FileSystemService: type) type {
    return struct {
        pub const SuccessType = bool;
        pub const FailureType = anyerror;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{FileSystemService};

        path: []const u8,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!bool {
            const fs = ctx.service(FileSystemService);
            const exists_value = callExists(fs, self.path) catch |err| {
                _ = StdService.recordOperation(ctx, FileSystemService, "exists", "failure", self.path);
                return err;
            };
            _ = StdService.recordOperation(ctx, FileSystemService, "exists", if (exists_value) "present" else "missing", self.path);
            return exists_value;
        }
    };
}

pub fn writeFileEffect(
    comptime EffectEnv: type,
    comptime FileSystemService: type,
    path: []const u8,
    content: []const u8,
) WriteFileEffect(EffectEnv, FileSystemService) {
    return .{ .path = path, .content = content };
}

pub fn readFileEffect(
    comptime EffectEnv: type,
    comptime FileSystemService: type,
    path: []const u8,
) ReadFileEffect(EffectEnv, FileSystemService) {
    return .{ .path = path };
}

pub fn deleteFileEffect(
    comptime EffectEnv: type,
    comptime FileSystemService: type,
    path: []const u8,
) DeleteFileEffect(EffectEnv, FileSystemService) {
    return .{ .path = path };
}

pub fn existsEffect(
    comptime EffectEnv: type,
    comptime FileSystemService: type,
    path: []const u8,
) ExistsEffect(EffectEnv, FileSystemService) {
    return .{ .path = path };
}

const WriteInput = struct { path: []const u8, content: []const u8 };

pub fn writeFile(path: []const u8, content: []const u8) fx.kernel.Effect(
    void,
    FileSystemError,
    .{FileSystem},
).Stateful(WriteInput) {
    const Write = fx.kernel.Effect(void, FileSystemError, .{FileSystem});
    return Write.fromState(WriteInput, .{ .path = path, .content = content }, struct {
        fn run(input: WriteInput, ctx: *fx.kernel.ContextView(.{FileSystem})) FileSystemError!void {
            const operation = StdService.beginOperation(ctx, FileSystem.service_key, "FileSystem.writeFile", input.path);
            ctx.service(FileSystem).writeFile(input.path, input.content) catch |failure| {
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.completeOperation(ctx, operation, "success", input.path);
        }
    }.run);
}

pub fn readFileAlloc(path: []const u8) fx.kernel.Effect(
    []const u8,
    FileSystemError,
    .{FileSystem},
).Stateful([]const u8) {
    const Read = fx.kernel.Effect([]const u8, FileSystemError, .{FileSystem});
    return Read.fromState([]const u8, path, struct {
        fn run(value: []const u8, ctx: *fx.kernel.ContextView(.{FileSystem})) FileSystemError![]const u8 {
            const operation = StdService.beginOperation(ctx, FileSystem.service_key, "FileSystem.readFile", value);
            const content = ctx.service(FileSystem).readFileAlloc(ctx.allocator(), value) catch |failure| {
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.completeOperation(ctx, operation, "success", value);
            return content;
        }
    }.run);
}

pub fn exists(path: []const u8) fx.kernel.Effect(
    bool,
    FileSystemError,
    .{FileSystem},
).Stateful([]const u8) {
    const Exists = fx.kernel.Effect(bool, FileSystemError, .{FileSystem});
    return Exists.fromState([]const u8, path, struct {
        fn run(value: []const u8, ctx: *fx.kernel.ContextView(.{FileSystem})) FileSystemError!bool {
            const operation = StdService.beginOperation(ctx, FileSystem.service_key, "FileSystem.exists", value);
            const present = ctx.service(FileSystem).exists(value) catch |failure| {
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.completeOperation(ctx, operation, if (present) "present" else "missing", value);
            return present;
        }
    }.run);
}

pub fn remove(path: []const u8) fx.kernel.Effect(
    void,
    FileSystemError,
    .{FileSystem},
).Stateful([]const u8) {
    const Remove = fx.kernel.Effect(void, FileSystemError, .{FileSystem});
    return Remove.fromState([]const u8, path, struct {
        fn run(value: []const u8, ctx: *fx.kernel.ContextView(.{FileSystem})) FileSystemError!void {
            const operation = StdService.beginOperation(ctx, FileSystem.service_key, "FileSystem.remove", value);
            ctx.service(FileSystem).remove(value) catch |failure| {
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.completeOperation(ctx, operation, "success", value);
        }
    }.run);
}

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

fn callExists(fs: anytype, path: []const u8) anyerror!bool {
    const result = fs.exists(path);
    return switch (@typeInfo(@TypeOf(result))) {
        .error_union => try result,
        else => result,
    };
}

fn callDelete(fs: anytype, path: []const u8) anyerror!void {
    const result = fs.deleteFile(path);
    switch (@typeInfo(@TypeOf(result))) {
        .error_union => try result,
        else => {},
    }
}

fn mapFileSystemError(failure: anyerror) FileSystemError {
    return switch (failure) {
        error.OutOfMemory => error.OutOfMemory,
        error.FileNotFound => error.FileNotFound,
        error.AccessDenied, error.PermissionDenied => error.AccessDenied,
        error.BadPathName, error.InvalidUtf8, error.NameTooLong => error.InvalidPath,
        else => error.IoFailure,
    };
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

test "FileSystem memory service effects read write delete and record facts" {
    const zstd = @import("../root.zig");

    var fs = MemoryFileSystem.init(std.testing.allocator);
    defer fs.deinit();
    var provider = zstd.Service.Provider(.{MemoryFileSystem}).init(.{&fs});
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{MemoryFileSystem})
        .withCausalStore(&store);

    try runtime.run(writeFileEffect(@TypeOf(provider), MemoryFileSystem, "notes/a.txt", "hello"));
    try std.testing.expect(try runtime.run(existsEffect(@TypeOf(provider), MemoryFileSystem, "notes/a.txt")));

    const content = try runtime.run(readFileEffect(@TypeOf(provider), MemoryFileSystem, "notes/a.txt"));
    defer std.testing.allocator.free(content);
    try std.testing.expectEqualStrings("hello", content);

    try runtime.run(deleteFileEffect(@TypeOf(provider), MemoryFileSystem, "notes/a.txt"));
    try std.testing.expect(!try runtime.run(existsEffect(@TypeOf(provider), MemoryFileSystem, "notes/a.txt")));

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(zstd.Service.hasOperation(snapshot, MemoryFileSystem, "writeFile", "success"));
    try std.testing.expect(zstd.Service.hasOperation(snapshot, MemoryFileSystem, "readFile", "success"));
    try std.testing.expect(zstd.Service.hasOperation(snapshot, MemoryFileSystem, "deleteFile", "success"));
}

test "FileSystem local adapter writes reads exists and deletes in a temp dir" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var fs = LocalFileSystem.init(&tmp.dir, std.testing.io);

    try fs.writeFile("hello.txt", "local");
    try std.testing.expect(try fs.exists("hello.txt"));

    const content = try fs.readFileAlloc(std.testing.allocator, "hello.txt");
    defer std.testing.allocator.free(content);
    try std.testing.expectEqualStrings("local", content);

    try fs.deleteFile("hello.txt");
    try std.testing.expect(!try fs.exists("hello.txt"));
}
