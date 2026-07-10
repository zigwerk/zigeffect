const std = @import("std");

pub const source_map_schema = "zigeffect.source-map.v1";
pub const source_map_schema_version: u32 = 1;
pub const redaction_marker = "<redacted>";
pub const truncation_marker = "<truncated>";

pub const SourceRefError = error{
    InvalidSourceRef,
    SourceMapFull,
    SourceRefCollision,
};

pub const SourceRefInput = struct {
    component: []const u8,
    file: []const u8,
    declaration: []const u8,
    line: u32,
    column: u32,
    fingerprint: []const u8,
    source_digest: []const u8,
};

pub const SourceRef = struct {
    id: u64,
    component: []const u8,
    file: []const u8,
    declaration: []const u8,
    line: u32,
    column: u32,
    fingerprint: []const u8,
    source_digest: []const u8,
};

pub const SourceMapOptions = struct {
    max_entries: ?usize = null,
    max_field_bytes: usize = 1024,
};

pub const SourceMap = struct {
    allocator: std.mem.Allocator,
    options: SourceMapOptions,
    entries: std.ArrayList(SourceRef) = .empty,
    truncated_fields: usize = 0,

    pub fn init(allocator: std.mem.Allocator, options: SourceMapOptions) SourceMap {
        return .{ .allocator = allocator, .options = options };
    }

    pub fn deinit(self: *SourceMap) void {
        for (self.entries.items) |entry| deinitEntry(self.allocator, entry);
        self.entries.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn register(self: *SourceMap, input: SourceRefInput) (SourceRefError || std.mem.Allocator.Error)!u64 {
        if (input.component.len == 0 or input.file.len == 0 or input.declaration.len == 0 or
            input.line == 0 or input.column == 0 or input.fingerprint.len == 0 or input.source_digest.len == 0 or
            self.options.max_field_bytes == 0)
        {
            return error.InvalidSourceRef;
        }

        const component = try self.sanitize(input.component);
        errdefer self.allocator.free(component);
        const file = try self.sanitize(input.file);
        errdefer self.allocator.free(file);
        const declaration = try self.sanitize(input.declaration);
        errdefer self.allocator.free(declaration);
        const fingerprint = try self.sanitize(input.fingerprint);
        errdefer self.allocator.free(fingerprint);
        const source_digest = try self.sanitize(input.source_digest);
        errdefer self.allocator.free(source_digest);

        const id = stableSourceRefId(.{
            .component = component,
            .file = file,
            .declaration = declaration,
            .line = input.line,
            .column = input.column,
            .fingerprint = fingerprint,
            .source_digest = source_digest,
        });
        if (self.resolve(id)) |existing| {
            if (!sourceRefMatches(existing, component, file, declaration, input.line, input.column, fingerprint, source_digest)) {
                return error.SourceRefCollision;
            }
            self.allocator.free(component);
            self.allocator.free(file);
            self.allocator.free(declaration);
            self.allocator.free(fingerprint);
            self.allocator.free(source_digest);
            return id;
        }
        if (self.options.max_entries) |max_entries| {
            if (self.entries.items.len >= max_entries) return error.SourceMapFull;
        }

        try self.entries.append(self.allocator, .{
            .id = id,
            .component = component,
            .file = file,
            .declaration = declaration,
            .line = input.line,
            .column = input.column,
            .fingerprint = fingerprint,
            .source_digest = source_digest,
        });
        return id;
    }

    pub fn registerBuiltin(
        self: *SourceMap,
        component: []const u8,
        source_digest: []const u8,
        location: std.builtin.SourceLocation,
    ) (SourceRefError || std.mem.Allocator.Error)!u64 {
        const fingerprint = try std.fmt.allocPrint(
            self.allocator,
            "builtin:{s}:{s}:{d}:{d}",
            .{ location.file, location.fn_name, location.line, location.column },
        );
        defer self.allocator.free(fingerprint);
        return self.register(.{
            .component = component,
            .file = location.file,
            .declaration = location.fn_name,
            .line = location.line,
            .column = location.column,
            .fingerprint = fingerprint,
            .source_digest = source_digest,
        });
    }

    pub fn resolve(self: *const SourceMap, id: u64) ?SourceRef {
        for (self.entries.items) |entry| if (entry.id == id) return entry;
        return null;
    }

    fn sanitize(self: *SourceMap, value: []const u8) std.mem.Allocator.Error![]const u8 {
        if (containsSensitive(value)) return self.allocator.dupe(u8, redaction_marker);
        if (value.len <= self.options.max_field_bytes) return self.allocator.dupe(u8, value);
        self.truncated_fields += 1;
        const max = self.options.max_field_bytes;
        if (max <= truncation_marker.len) return self.allocator.dupe(u8, truncation_marker[0..max]);
        var output = try self.allocator.alloc(u8, max);
        const prefix_len = max - truncation_marker.len;
        @memcpy(output[0..prefix_len], value[0..prefix_len]);
        @memcpy(output[prefix_len..], truncation_marker);
        return output;
    }
};

pub fn stableSourceRefId(input: SourceRefInput) u64 {
    var hash: u64 = 0xcbf29ce484222325;
    hashBytes(&hash, input.component);
    hashByte(&hash, 0);
    hashBytes(&hash, input.file);
    hashByte(&hash, 0);
    hashBytes(&hash, input.declaration);
    hashByte(&hash, 0);
    hashU32(&hash, input.line);
    hashU32(&hash, input.column);
    hashBytes(&hash, input.fingerprint);
    hashByte(&hash, 0);
    hashBytes(&hash, input.source_digest);
    return if (hash == 0) 1 else hash;
}

pub fn formatSourceMapJson(allocator: std.mem.Allocator, map: *const SourceMap) std.mem.Allocator.Error![]u8 {
    const value = .{
        .schema = source_map_schema,
        .schema_version = source_map_schema_version,
        .retention = .{
            .max_entries = map.options.max_entries,
            .max_field_bytes = map.options.max_field_bytes,
            .truncated_fields = map.truncated_fields,
        },
        .entries = map.entries.items,
    };
    return std.json.Stringify.valueAlloc(allocator, value, .{});
}

fn sourceRefMatches(
    existing: SourceRef,
    component: []const u8,
    file: []const u8,
    declaration: []const u8,
    line: u32,
    column: u32,
    fingerprint: []const u8,
    source_digest: []const u8,
) bool {
    return std.mem.eql(u8, existing.component, component) and
        std.mem.eql(u8, existing.file, file) and
        std.mem.eql(u8, existing.declaration, declaration) and
        existing.line == line and existing.column == column and
        std.mem.eql(u8, existing.fingerprint, fingerprint) and
        std.mem.eql(u8, existing.source_digest, source_digest);
}

fn containsSensitive(value: []const u8) bool {
    const patterns = [_][]const u8{
        "authorization", "bearer ", "password", "passwd", "token=", "secret", "private_key", "session_id",
    };
    var lower: [2048]u8 = undefined;
    const bounded = value[0..@min(value.len, lower.len)];
    for (bounded, 0..) |byte, index| lower[index] = std.ascii.toLower(byte);
    for (patterns) |pattern| {
        if (std.mem.indexOf(u8, lower[0..bounded.len], pattern) != null) return true;
    }
    if (std.mem.indexOf(u8, value, "://") != null and std.mem.indexOfScalar(u8, value, '@') != null) return true;
    return false;
}

fn hashBytes(hash: *u64, bytes: []const u8) void {
    for (bytes) |byte| hashByte(hash, byte);
}

fn hashByte(hash: *u64, byte: u8) void {
    hash.* ^= byte;
    hash.* *%= 0x100000001b3;
}

fn hashU32(hash: *u64, value: u32) void {
    hashByte(hash, @truncate(value));
    hashByte(hash, @truncate(value >> 8));
    hashByte(hash, @truncate(value >> 16));
    hashByte(hash, @truncate(value >> 24));
}

fn deinitEntry(allocator: std.mem.Allocator, entry: SourceRef) void {
    allocator.free(entry.component);
    allocator.free(entry.file);
    allocator.free(entry.declaration);
    allocator.free(entry.fingerprint);
    allocator.free(entry.source_digest);
}
