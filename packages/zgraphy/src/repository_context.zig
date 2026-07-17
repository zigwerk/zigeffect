const std = @import("std");
const memory = @import("memory.zig");

pub const schema = "zgraphy.repository-context.v1";
pub const schema_version: u32 = 1;
pub const max_artifact_bytes: usize = 64 * 1024;
pub const max_git_pointer_bytes: usize = 16 * 1024;
pub const max_head_bytes: usize = 16 * 1024;
pub const max_packed_refs_bytes: usize = 32 * 1024 * 1024;
pub const max_ref_bytes: usize = 1024;

pub const Presence = enum {
    absent,
    git,
};

pub const WorktreeKind = enum {
    none,
    primary,
    linked,
};

pub const HeadKind = enum {
    none,
    symbolic,
    detached,
    unborn,
};

pub const Artifact = struct {
    schema: []const u8 = schema,
    schema_version: u32 = schema_version,
    presence: Presence,
    worktree_kind: WorktreeKind,
    head_kind: HeadKind,
    head_ref: []const u8,
    head_oid: []const u8,
    common_repository_id: []const u8,
    worktree_id: []const u8,
    fingerprint: []const u8,
    complete: bool = true,
};

pub const Owned = struct {
    allocator: std.mem.Allocator,
    value: Artifact,

    pub fn deinit(self: *Owned) void {
        self.allocator.free(self.value.head_ref);
        self.allocator.free(self.value.head_oid);
        self.allocator.free(self.value.common_repository_id);
        self.allocator.free(self.value.worktree_id);
        self.allocator.free(self.value.fingerprint);
        self.value.head_ref = &.{};
        self.value.head_oid = &.{};
        self.value.common_repository_id = &.{};
        self.value.worktree_id = &.{};
        self.value.fingerprint = &.{};
    }
};

const FingerprintInput = struct {
    schema: []const u8 = schema,
    schema_version: u32 = schema_version,
    presence: Presence,
    worktree_kind: WorktreeKind,
    head_kind: HeadKind,
    head_ref: []const u8,
    head_oid: []const u8,
    common_repository_id: []const u8,
    worktree_id: []const u8,
    complete: bool = true,
};

pub fn inspect(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir) !Owned {
    const stat = root.statFile(io, ".git", .{ .follow_symlinks = false }) catch |failure| switch (failure) {
        error.FileNotFound => return makeOwned(allocator, .absent, .none, .none, "", "", "", ""),
        else => return failure,
    };
    if (stat.kind == .sym_link) return error.SymlinkGitMetadataUnsupported;

    var root_path_buffer = [_]u8{0} ** std.fs.max_path_bytes;
    const root_path_length = try root.realPath(io, &root_path_buffer);
    const root_path = root_path_buffer[0..root_path_length];

    const GitLocation = struct {
        path: []u8,
        worktree_kind: WorktreeKind,
    };
    const git_location: GitLocation = switch (stat.kind) {
        .directory => .{
            .path = try std.fs.path.resolve(allocator, &.{ root_path, ".git" }),
            .worktree_kind = .primary,
        },
        .file => blk: {
            const pointer_bytes = try root.readFileAlloc(io, ".git", allocator, .limited(max_git_pointer_bytes));
            defer allocator.free(pointer_bytes);
            const pointer = std.mem.trim(u8, pointer_bytes, " \t\r\n");
            if (!std.mem.startsWith(u8, pointer, "gitdir:")) return error.InvalidGitPointer;
            const raw_path = std.mem.trim(u8, pointer["gitdir:".len..], " \t");
            try validateMetadataPath(raw_path);
            const path = if (std.fs.path.isAbsolute(raw_path))
                try memory.copy(u8, allocator, raw_path)
            else
                try std.fs.path.resolve(allocator, &.{ root_path, raw_path });
            break :blk .{ .path = path, .worktree_kind = .linked };
        },
        else => return error.InvalidGitMetadataKind,
    };
    const git_path = git_location.path;
    defer allocator.free(git_path);
    const worktree_kind = git_location.worktree_kind;

    var git_dir = try std.Io.Dir.openDirAbsolute(io, git_path, .{});
    defer git_dir.close(io);
    const canonical_git_path = try realPathAlloc(allocator, io, git_dir);
    defer allocator.free(canonical_git_path);

    var common_path = try memory.copy(u8, allocator, canonical_git_path);
    defer allocator.free(common_path);
    if (worktree_kind == .linked) {
        const commondir_bytes = git_dir.readFileAlloc(io, "commondir", allocator, .limited(max_git_pointer_bytes)) catch |failure| switch (failure) {
            error.FileNotFound => null,
            else => return failure,
        };
        if (commondir_bytes) |bytes| {
            defer allocator.free(bytes);
            const raw_path = std.mem.trim(u8, bytes, " \t\r\n");
            try validateMetadataPath(raw_path);
            const resolved = if (std.fs.path.isAbsolute(raw_path))
                try memory.copy(u8, allocator, raw_path)
            else
                try std.fs.path.resolve(allocator, &.{ canonical_git_path, raw_path });
            defer allocator.free(resolved);
            var common_dir_for_path = try std.Io.Dir.openDirAbsolute(io, resolved, .{});
            defer common_dir_for_path.close(io);
            const canonical_common = try realPathAlloc(allocator, io, common_dir_for_path);
            allocator.free(common_path);
            common_path = canonical_common;
        }
    }
    var common_dir = try std.Io.Dir.openDirAbsolute(io, common_path, .{});
    defer common_dir.close(io);

    const common_id = try opaquePathIdentityAlloc(allocator, "git-common-v1", common_path);
    defer allocator.free(common_id);
    const worktree_id = try opaquePathIdentityAlloc(allocator, "git-worktree-v1", canonical_git_path);
    defer allocator.free(worktree_id);

    const head_bytes = try git_dir.readFileAlloc(io, "HEAD", allocator, .limited(max_head_bytes));
    defer allocator.free(head_bytes);
    const head = std.mem.trim(u8, head_bytes, " \t\r\n");
    if (head.len == 0 or head.len > max_head_bytes or std.mem.indexOfScalar(u8, head, 0) != null) return error.InvalidGitHead;

    if (std.mem.startsWith(u8, head, "ref:")) {
        const head_ref = std.mem.trim(u8, head["ref:".len..], " \t");
        try validateRef(head_ref);
        const oid = try resolveRefAlloc(allocator, io, git_dir, common_dir, head_ref);
        defer if (oid) |value| allocator.free(value);
        return makeOwned(
            allocator,
            .git,
            worktree_kind,
            if (oid == null) .unborn else .symbolic,
            head_ref,
            if (oid) |value| value else "",
            common_id,
            worktree_id,
        );
    }
    try validateOid(head);
    return makeOwned(allocator, .git, worktree_kind, .detached, "", head, common_id, worktree_id);
}

pub fn encodeAlloc(allocator: std.mem.Allocator, artifact: Artifact) ![]u8 {
    try validate(allocator, artifact);
    const bytes = try std.json.Stringify.valueAlloc(allocator, artifact, .{ .whitespace = .indent_2 });
    if (bytes.len > max_artifact_bytes) {
        allocator.free(bytes);
        return error.RepositoryContextTooLarge;
    }
    return bytes;
}

pub fn read(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    path: []const u8,
) !std.json.Parsed(Artifact) {
    const bytes = try root.readFileAlloc(io, path, allocator, .limited(max_artifact_bytes));
    defer allocator.free(bytes);
    var parsed = std.json.parseFromSlice(Artifact, allocator, bytes, .{ .allocate = .alloc_always }) catch return error.CorruptRepositoryContext;
    errdefer parsed.deinit();
    try validate(allocator, parsed.value);
    return parsed;
}

pub fn validate(allocator: std.mem.Allocator, artifact: Artifact) !void {
    if (!artifact.complete or !std.mem.eql(u8, artifact.schema, schema) or artifact.schema_version != schema_version) {
        return error.IncompatibleRepositoryContext;
    }
    switch (artifact.presence) {
        .absent => if (artifact.worktree_kind != .none or artifact.head_kind != .none or artifact.head_ref.len != 0 or
            artifact.head_oid.len != 0 or artifact.common_repository_id.len != 0 or artifact.worktree_id.len != 0)
        {
            return error.InvalidRepositoryContext;
        },
        .git => {
            if (artifact.worktree_kind == .none or artifact.head_kind == .none or artifact.common_repository_id.len != 71 or
                artifact.worktree_id.len != 71)
            {
                return error.InvalidRepositoryContext;
            }
            if (!validSha256Identity(artifact.common_repository_id) or !validSha256Identity(artifact.worktree_id)) {
                return error.InvalidRepositoryContext;
            }
            if (artifact.head_ref.len > 0) try validateRef(artifact.head_ref);
            if (artifact.head_oid.len > 0) try validateOid(artifact.head_oid);
            switch (artifact.head_kind) {
                .symbolic => if (artifact.head_ref.len == 0 or artifact.head_oid.len == 0) return error.InvalidRepositoryContext,
                .unborn => if (artifact.head_ref.len == 0 or artifact.head_oid.len != 0) return error.InvalidRepositoryContext,
                .detached => if (artifact.head_ref.len != 0 or artifact.head_oid.len == 0) return error.InvalidRepositoryContext,
                .none => return error.InvalidRepositoryContext,
            }
        },
    }
    const expected = try fingerprintAlloc(allocator, artifact);
    defer allocator.free(expected);
    if (!std.mem.eql(u8, expected, artifact.fingerprint)) return error.RepositoryContextFingerprintMismatch;
}

fn makeOwned(
    allocator: std.mem.Allocator,
    presence: Presence,
    worktree_kind: WorktreeKind,
    head_kind: HeadKind,
    head_ref: []const u8,
    head_oid: []const u8,
    common_repository_id: []const u8,
    worktree_id: []const u8,
) !Owned {
    const owned_ref = try memory.copy(u8, allocator, head_ref);
    errdefer allocator.free(owned_ref);
    const owned_oid = try memory.copy(u8, allocator, head_oid);
    errdefer allocator.free(owned_oid);
    const owned_common = try memory.copy(u8, allocator, common_repository_id);
    errdefer allocator.free(owned_common);
    const owned_worktree = try memory.copy(u8, allocator, worktree_id);
    errdefer allocator.free(owned_worktree);
    const input = Artifact{
        .presence = presence,
        .worktree_kind = worktree_kind,
        .head_kind = head_kind,
        .head_ref = owned_ref,
        .head_oid = owned_oid,
        .common_repository_id = owned_common,
        .worktree_id = owned_worktree,
        .fingerprint = "",
    };
    const fingerprint = try fingerprintAlloc(allocator, input);
    errdefer allocator.free(fingerprint);
    return .{
        .allocator = allocator,
        .value = .{
            .presence = presence,
            .worktree_kind = worktree_kind,
            .head_kind = head_kind,
            .head_ref = owned_ref,
            .head_oid = owned_oid,
            .common_repository_id = owned_common,
            .worktree_id = owned_worktree,
            .fingerprint = fingerprint,
        },
    };
}

fn fingerprintAlloc(allocator: std.mem.Allocator, artifact: Artifact) ![]u8 {
    const payload = FingerprintInput{
        .presence = artifact.presence,
        .worktree_kind = artifact.worktree_kind,
        .head_kind = artifact.head_kind,
        .head_ref = artifact.head_ref,
        .head_oid = artifact.head_oid,
        .common_repository_id = artifact.common_repository_id,
        .worktree_id = artifact.worktree_id,
    };
    const bytes = try std.json.Stringify.valueAlloc(allocator, payload, .{});
    defer allocator.free(bytes);
    return sha256IdentityAlloc(allocator, bytes);
}

fn opaquePathIdentityAlloc(allocator: std.mem.Allocator, domain: []const u8, path: []const u8) ![]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(domain);
    hasher.update(&.{0});
    hasher.update(path);
    var digest = [_]u8{0} ** 32;
    hasher.final(&digest);
    const hex = std.fmt.bytesToHex(digest, .lower);
    return std.fmt.allocPrint(allocator, "sha256:{s}", .{hex});
}

fn sha256IdentityAlloc(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var digest = [_]u8{0} ** 32;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    return std.fmt.allocPrint(allocator, "sha256:{s}", .{hex});
}

fn realPathAlloc(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir) ![]u8 {
    var buffer = [_]u8{0} ** std.fs.max_path_bytes;
    const length = try dir.realPath(io, &buffer);
    return memory.copy(u8, allocator, buffer[0..length]);
}

fn validateMetadataPath(path: []const u8) !void {
    if (path.len == 0 or path.len > std.fs.max_path_bytes or std.mem.indexOfScalar(u8, path, 0) != null or
        std.mem.indexOfScalar(u8, path, '\n') != null or std.mem.indexOfScalar(u8, path, '\r') != null)
    {
        return error.InvalidGitMetadataPath;
    }
}

fn validateRef(ref: []const u8) !void {
    if (ref.len <= "refs/".len or ref.len > max_ref_bytes or !std.mem.startsWith(u8, ref, "refs/") or
        std.mem.indexOf(u8, ref, "..") != null or std.mem.indexOf(u8, ref, "//") != null or
        std.mem.indexOf(u8, ref, "@{") != null or std.mem.indexOfScalar(u8, ref, '\\') != null or
        ref[ref.len - 1] == '/' or ref[ref.len - 1] == '.' or std.mem.endsWith(u8, ref, ".lock"))
    {
        return error.InvalidGitRef;
    }
    for (ref) |byte| if (byte < 0x21 or byte == 0x7f or byte == '~' or byte == '^' or byte == ':' or byte == '?' or byte == '*' or byte == '[') {
        return error.InvalidGitRef;
    };
}

fn validateOid(oid: []const u8) !void {
    if (oid.len != 40 and oid.len != 64) return error.InvalidGitObjectId;
    for (oid) |byte| if (!std.ascii.isHex(byte)) return error.InvalidGitObjectId;
}

fn validSha256Identity(value: []const u8) bool {
    if (value.len != 71 or !std.mem.startsWith(u8, value, "sha256:")) return false;
    for (value[7..]) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    return true;
}

fn resolveRefAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    git_dir: std.Io.Dir,
    common_dir: std.Io.Dir,
    ref: []const u8,
) !?[]u8 {
    if (try readLooseRefAlloc(allocator, io, git_dir, ref)) |oid| return oid;
    if (try readLooseRefAlloc(allocator, io, common_dir, ref)) |oid| return oid;
    const packed_refs = common_dir.readFileAlloc(io, "packed-refs", allocator, .limited(max_packed_refs_bytes)) catch |failure| switch (failure) {
        error.FileNotFound => return null,
        else => return failure,
    };
    defer allocator.free(packed_refs);
    var lines = std.mem.splitScalar(u8, packed_refs, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#' or line[0] == '^') continue;
        const separator = std.mem.indexOfScalar(u8, line, ' ') orelse continue;
        const oid = line[0..separator];
        const candidate_ref = std.mem.trim(u8, line[separator + 1 ..], " \t");
        if (!std.mem.eql(u8, candidate_ref, ref)) continue;
        try validateOid(oid);
        return @as(?[]u8, try memory.copy(u8, allocator, oid));
    }
    return null;
}

fn readLooseRefAlloc(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, ref: []const u8) !?[]u8 {
    const bytes = dir.readFileAlloc(io, ref, allocator, .limited(max_head_bytes)) catch |failure| switch (failure) {
        error.FileNotFound => return null,
        else => return failure,
    };
    defer allocator.free(bytes);
    const oid = std.mem.trim(u8, bytes, " \t\r\n");
    try validateOid(oid);
    return @as(?[]u8, try memory.copy(u8, allocator, oid));
}
