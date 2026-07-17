const std = @import("std");

pub const max_refs: usize = 8;
pub const max_baggage_bytes: usize = 512;
pub const max_header_bytes: usize = 8 * 1024;
pub const baggage_member_name = "zigeffect-lineage";

pub const Privacy = enum(u8) {
    public = 0,
    internal = 1,
    personal = 2,
};

pub const Propagation = enum(u8) {
    fiber = 0,
    distributed = 1,
};

pub const Export = enum(u8) {
    graph_only = 0,
    otel = 1,
};

pub const Error = error{
    MissingProjectIdentity,
    InvalidBaggage,
    BaggageTooLarge,
};

pub const KeyOptions = struct {
    name: []const u8,
    privacy: Privacy = .internal,
    propagation: Propagation = .fiber,
    export_policy: Export = .graph_only,
};

/// An allocation-free, non-raw identity carried by causal context. The source
/// value is deliberately absent; equality and graph lookup use only the domain
/// key and its 128-bit projection. This is correlation, not anonymization.
pub const Ref = struct {
    key_id: u64 = 0,
    value_id_high: u64 = 0,
    value_id_low: u64 = 0,
    privacy: Privacy = .internal,
    propagation: Propagation = .fiber,
    export_policy: Export = .graph_only,

    pub fn valid(self: Ref) bool {
        return self.key_id != 0 and (self.value_id_high != 0 or self.value_id_low != 0) and
            !(self.privacy == .personal and self.export_policy == .otel);
    }

    pub fn sameIdentity(self: Ref, other: Ref) bool {
        return self.key_id == other.key_id and
            self.value_id_high == other.value_id_high and
            self.value_id_low == other.value_id_low;
    }
};

/// Fixed causal baggage copied with runtime and fiber contexts. Child context
/// replaces the same key and otherwise extends the set. Overflow is explicit.
pub const Set = struct {
    refs: [max_refs]Ref = [_]Ref{.{}} ** max_refs,
    count: u8 = 0,
    truncated: bool = false,

    pub const empty: Set = .{};

    pub fn active(self: *const Set) []const Ref {
        return self.refs[0..@min(@as(usize, self.count), max_refs)];
    }

    pub fn isEmpty(self: Set) bool {
        return self.count == 0 and !self.truncated;
    }

    pub fn contains(self: Set, expected: Ref) bool {
        for (self.active()) |candidate| {
            if (candidate.sameIdentity(expected)) return true;
        }
        return false;
    }

    pub fn with(self: Set, reference: Ref) Set {
        if (!reference.valid()) return self;
        var result = self;
        for (result.active(), 0..) |candidate, index| {
            if (candidate.key_id != reference.key_id) continue;
            result.refs[index] = reference;
            return result;
        }
        if (result.count < max_refs) {
            result.refs[result.count] = reference;
            result.count += 1;
            return result;
        }
        result.refs[max_refs - 1] = reference;
        result.truncated = true;
        return result;
    }

    /// Merge with child priority. Every child reference is retained before
    /// distinct parent references, so a full context cannot discard the value
    /// that established the current scope.
    pub fn merge(parent: Set, child: Set) Set {
        var result = Set.empty;
        result.truncated = parent.truncated or child.truncated;
        for (child.active()) |reference| result = result.with(reference);
        for (parent.active()) |reference| {
            var shadowed = false;
            for (child.active()) |candidate| {
                if (candidate.key_id == reference.key_id) {
                    shadowed = true;
                    break;
                }
            }
            if (shadowed) continue;
            const before = result.count;
            result = result.with(reference);
            if (before == max_refs) result.truncated = true;
        }
        return result;
    }

    pub fn telemetryCount(self: Set) usize {
        var count: usize = 0;
        for (self.active()) |reference| {
            if (reference.export_policy == .otel) count += 1;
        }
        return count;
    }

    pub fn jsonStringify(self: Set, writer: anytype) !void {
        try writer.write(.{
            .refs = self.active(),
            .truncated = self.truncated,
        });
    }

    /// Encode only references explicitly allowed to cross a trusted service
    /// boundary. Values remain opaque fixed-width hexadecimal projections.
    pub fn formatBaggage(self: Set, buffer: *[max_baggage_bytes]u8) Error![]const u8 {
        var offset: usize = 0;
        var emitted: usize = 0;
        for (self.active()) |reference| {
            if (reference.propagation != .distributed) continue;
            if (emitted == 0) {
                const prefix = std.fmt.bufPrint(buffer[offset..], "{s}=", .{baggage_member_name}) catch
                    return error.BaggageTooLarge;
                offset += prefix.len;
            } else {
                if (offset >= buffer.len) return error.BaggageTooLarge;
                buffer[offset] = '~';
                offset += 1;
            }
            const encoded = std.fmt.bufPrint(
                buffer[offset..],
                "{x:0>16}.{x:0>16}.{x:0>16}.{d}{d}{d}",
                .{
                    reference.key_id,
                    reference.value_id_high,
                    reference.value_id_low,
                    @intFromEnum(reference.privacy),
                    @intFromEnum(reference.propagation),
                    @intFromEnum(reference.export_policy),
                },
            ) catch return error.BaggageTooLarge;
            offset += encoded.len;
            emitted += 1;
        }
        return buffer[0..offset];
    }

    /// Parse the one ZigEffect W3C baggage member while ignoring unrelated
    /// members. Duplicate or malformed ZigEffect members fail closed.
    pub fn parseBaggage(header: []const u8) Error!Set {
        if (header.len > max_header_bytes) return error.BaggageTooLarge;
        var output = Set.empty;
        var found = false;
        var members = std.mem.splitScalar(u8, header, ',');
        while (members.next()) |raw_member| {
            const member = std.mem.trim(u8, raw_member, " \t");
            const separator = std.mem.indexOfScalar(u8, member, '=') orelse continue;
            const name = std.mem.trim(u8, member[0..separator], " \t");
            if (!std.mem.eql(u8, name, baggage_member_name)) continue;
            if (found) return error.InvalidBaggage;
            found = true;
            const encoded_refs = member[separator + 1 ..];
            if (encoded_refs.len == 0 or encoded_refs.len > max_baggage_bytes) return error.InvalidBaggage;
            var refs = std.mem.splitScalar(u8, encoded_refs, '~');
            while (refs.next()) |encoded| {
                if (output.count >= max_refs) return error.InvalidBaggage;
                const reference = try parseRef(encoded);
                output = output.with(reference);
            }
        }
        return output;
    }
};

fn parseRef(encoded: []const u8) Error!Ref {
    var fields = std.mem.splitScalar(u8, encoded, '.');
    const key = fields.next() orelse return error.InvalidBaggage;
    const high = fields.next() orelse return error.InvalidBaggage;
    const low = fields.next() orelse return error.InvalidBaggage;
    const flags = fields.next() orelse return error.InvalidBaggage;
    if (fields.next() != null or key.len != 16 or high.len != 16 or low.len != 16 or flags.len != 3) {
        return error.InvalidBaggage;
    }
    const privacy_raw = std.fmt.parseInt(u8, flags[0..1], 10) catch return error.InvalidBaggage;
    const propagation_raw = std.fmt.parseInt(u8, flags[1..2], 10) catch return error.InvalidBaggage;
    const export_raw = std.fmt.parseInt(u8, flags[2..3], 10) catch return error.InvalidBaggage;
    if (privacy_raw > @intFromEnum(Privacy.personal) or
        propagation_raw > @intFromEnum(Propagation.distributed) or
        export_raw > @intFromEnum(Export.otel))
    {
        return error.InvalidBaggage;
    }
    const privacy: Privacy = @enumFromInt(privacy_raw);
    const propagation: Propagation = @enumFromInt(propagation_raw);
    const export_policy: Export = @enumFromInt(export_raw);
    const reference = Ref{
        .key_id = std.fmt.parseInt(u64, key, 16) catch return error.InvalidBaggage,
        .value_id_high = std.fmt.parseInt(u64, high, 16) catch return error.InvalidBaggage,
        .value_id_low = std.fmt.parseInt(u64, low, 16) catch return error.InvalidBaggage,
        .privacy = privacy,
        .propagation = propagation,
        .export_policy = export_policy,
    };
    if (!reference.valid() or reference.propagation != .distributed) return error.InvalidBaggage;
    return reference;
}

pub fn Key(comptime ValueType: type, comptime options: KeyOptions) type {
    comptime {
        if (options.name.len == 0 or options.name.len > 96) {
            @compileError("ZigEffect lineage key names must contain 1..96 bytes");
        }
        for (options.name) |byte| {
            if (!(std.ascii.isAlphanumeric(byte) or byte == '.' or byte == '_' or byte == '-')) {
                @compileError("ZigEffect lineage key names may contain only letters, digits, '.', '_' and '-'");
            }
        }
        if (options.privacy == .personal and options.export_policy == .otel) {
            @compileError("personal ZigEffect lineage keys are graph-only and cannot be exported to OTEL");
        }
        assertSupportedValueType(ValueType);
    }

    return struct {
        pub const Value = ValueType;
        pub const name = options.name;
        pub const key_id = stableNameId(options.name);
        pub const privacy = options.privacy;
        pub const propagation = options.propagation;
        pub const export_policy = options.export_policy;

        pub fn reference(project_id: ?u64, value: Value) Error!Ref {
            if (privacy != .public and project_id == null) return error.MissingProjectIdentity;

            var hasher = std.crypto.hash.sha2.Sha256.init(.{});
            hasher.update("zigeffect.lineage.v1\x00");
            hasher.update(name);
            hasher.update("\x00");
            hasher.update(@tagName(privacy));
            hasher.update("\x00");
            if (privacy != .public) updateCanonicalInteger(&hasher, project_id.?);
            hasher.update("\x00");
            updateCanonicalValue(&hasher, value);
            var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
            hasher.final(&digest);
            const positive_mask: u64 = std.math.maxInt(i64);
            const high = std.mem.readInt(u64, digest[0..8], .big) & positive_mask;
            var low = std.mem.readInt(u64, digest[8..16], .big) & positive_mask;
            if (high == 0 and low == 0) low = 1;
            return .{
                .key_id = key_id,
                .value_id_high = high,
                .value_id_low = low,
                .privacy = privacy,
                .propagation = propagation,
                .export_policy = export_policy,
            };
        }
    };
}

fn stableNameId(value: []const u8) u64 {
    var hash: u64 = 14695981039346656037;
    for (value) |byte| {
        hash ^= byte;
        hash *%= 1099511628211;
    }
    hash &= std.math.maxInt(i64);
    return if (hash == 0) 1 else hash;
}

fn assertSupportedValueType(comptime ValueType: type) void {
    switch (@typeInfo(ValueType)) {
        .bool, .int, .comptime_int, .@"enum" => {},
        .pointer => |pointer| {
            if (pointer.size != .slice or pointer.child != u8) {
                @compileError("ZigEffect lineage keys support only byte slices, byte arrays, integers, booleans and enums");
            }
        },
        .array => |array| {
            if (array.child != u8) {
                @compileError("ZigEffect lineage keys support only byte slices, byte arrays, integers, booleans and enums");
            }
        },
        else => @compileError("ZigEffect lineage keys support only byte slices, byte arrays, integers, booleans and enums"),
    }
}

fn updateCanonicalInteger(hasher: *std.crypto.hash.sha2.Sha256, value: anytype) void {
    var buffer: [64]u8 = undefined;
    const encoded = std.fmt.bufPrint(&buffer, "{d}", .{value}) catch unreachable;
    hasher.update(encoded);
}

fn updateCanonicalValue(hasher: *std.crypto.hash.sha2.Sha256, value: anytype) void {
    const ValueType = @TypeOf(value);
    switch (@typeInfo(ValueType)) {
        .bool => hasher.update(if (value) "true" else "false"),
        .int, .comptime_int => updateCanonicalInteger(hasher, value),
        .@"enum" => hasher.update(@tagName(value)),
        .pointer => hasher.update(value),
        .array => hasher.update(value[0..]),
        else => unreachable,
    }
}

test "lineage set merge gives child keys priority and reports overflow" {
    const Example = Key(u64, .{ .name = "test.id", .privacy = .public });
    const reference = try Example.reference(null, 1);
    var parent = Set.empty.with(reference);
    var index: u64 = 0;
    while (index < max_refs) : (index += 1) {
        var distinct = reference;
        distinct.key_id += index + 1;
        parent = parent.with(distinct);
    }
    try std.testing.expect(parent.truncated);
    const child = Set.empty.with(reference);
    const merged = Set.merge(parent, child);
    try std.testing.expect(merged.contains(reference));
    try std.testing.expect(merged.truncated);
}
