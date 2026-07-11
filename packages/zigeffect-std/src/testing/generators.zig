const std = @import("std");
const Schema = @import("../schema/root.zig");
const Contract = @import("contract.zig");

pub const GeneratorError = error{
    InvalidBounds,
    UnsatisfiableSchema,
    GeneratorRequired,
};

pub const Seeded = struct {
    seed: u64,
    state: u64,

    pub fn init(seed: u64) !Seeded {
        if (seed == 0) return error.InvalidBounds;
        return .{ .seed = seed, .state = seed };
    }

    pub fn next(self: *Seeded) u64 {
        var value = self.state;
        value ^= value << 13;
        value ^= value >> 7;
        value ^= value << 17;
        self.state = value;
        return value;
    }

    pub fn bounded(self: *Seeded, bound: usize) usize {
        if (bound == 0) return 0;
        return @intCast(self.next() % bound);
    }
};

pub fn Generated(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        value: T,

        pub fn deinit(self: *@This()) void {
            Schema.freeOwnedDecoded(self.allocator, self.value);
            self.* = undefined;
        }
    };
}

pub fn generate(allocator: std.mem.Allocator, schema: anytype, seeded: *Seeded) !Generated(@TypeOf(schema).Output) {
    return .{ .allocator = allocator, .value = try generateValue(allocator, schema, seeded) };
}

pub const InvalidCase = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    json: []const u8,
    expected_path: []const u8,
    expected_kind: Schema.IssueKind,

    pub fn deinit(self: *InvalidCase) void {
        self.allocator.free(self.name);
        self.allocator.free(self.json);
        self.allocator.free(self.expected_path);
    }
};

pub fn invalidCaseAlloc(allocator: std.mem.Allocator, schema: anytype) !InvalidCase {
    const kind = generatorKind(@TypeOf(schema));
    const name: []const u8 = if (std.mem.eql(u8, kind, "string")) "wrong-type-string" else if (std.mem.eql(u8, kind, "integer")) "wrong-type-integer" else if (std.mem.eql(u8, kind, "boolean")) "wrong-type-boolean" else "wrong-root-type";
    const json: []const u8 = if (std.mem.eql(u8, kind, "string")) "42" else if (std.mem.eql(u8, kind, "integer")) "\"not-an-integer\"" else if (std.mem.eql(u8, kind, "boolean")) "0" else "null";
    return .{
        .allocator = allocator,
        .name = try allocator.dupe(u8, name),
        .json = try allocator.dupe(u8, json),
        .expected_path = try allocator.dupe(u8, "$"),
        .expected_kind = .invalid_type,
    };
}

pub const PropertyOptions = struct {
    seed: u64 = 1,
    cases: usize = 100,
    max_shrinks: usize = 64,
};

pub const PropertyReceipt = struct {
    allocator: std.mem.Allocator,
    seed: u64,
    executed: usize,
    passed: bool,
    failing_case_index: ?usize = null,
    shrink_steps: usize = 0,
    minimal_json: []const u8 = "",
    error_name: []const u8 = "",
    shrink_path: []const u8 = "",

    pub fn deinit(self: *PropertyReceipt) void {
        self.allocator.free(self.minimal_json);
        self.allocator.free(self.error_name);
        self.allocator.free(self.shrink_path);
    }

    pub fn minimalCase(self: PropertyReceipt) ?Contract.MinimalCase {
        const index = self.failing_case_index orelse return null;
        return .{ .kind = "property", .input = self.minimal_json, .seed = self.seed, .case_index = index, .shrink_steps = self.shrink_steps, .shrink_path = self.shrink_path };
    }
};

pub fn runProperty(
    allocator: std.mem.Allocator,
    schema: anytype,
    state: anytype,
    comptime property: fn (@TypeOf(state), @TypeOf(schema).Output) anyerror!void,
    options: PropertyOptions,
) !PropertyReceipt {
    if (options.seed == 0 or options.cases == 0) return error.InvalidBounds;
    var seeded = try Seeded.init(options.seed);
    for (0..options.cases) |index| {
        var generated = try generate(allocator, schema, &seeded);
        defer generated.deinit();
        property(state, generated.value) catch |err| {
            var shrink = try shrinkFailureAlloc(allocator, schema, state, property, generated.value, options.max_shrinks);
            errdefer shrink.deinit();
            const error_name = try allocator.dupe(u8, @errorName(err));
            return .{
                .allocator = allocator,
                .seed = options.seed,
                .executed = index + 1,
                .passed = false,
                .failing_case_index = index,
                .shrink_steps = shrink.steps,
                .minimal_json = shrink.minimal_json,
                .error_name = error_name,
                .shrink_path = shrink.path,
            };
        };
    }
    const minimal_json = try allocator.dupe(u8, "");
    errdefer allocator.free(minimal_json);
    const error_name = try allocator.dupe(u8, "");
    errdefer allocator.free(error_name);
    const shrink_path = try allocator.dupe(u8, "");
    return .{
        .allocator = allocator,
        .seed = options.seed,
        .executed = options.cases,
        .passed = true,
        .minimal_json = minimal_json,
        .error_name = error_name,
        .shrink_path = shrink_path,
    };
}

pub const ShrinkResult = struct {
    allocator: std.mem.Allocator,
    minimal_json: []const u8,
    path: []const u8,
    steps: usize = 0,

    pub fn deinit(self: *ShrinkResult) void {
        self.allocator.free(self.minimal_json);
        self.allocator.free(self.path);
    }
};

pub fn CustomShrinker(comptime T: type) type {
    return struct {
        state: *anyopaque,
        next_fn: *const fn (*anyopaque, T, usize) ?T,

        pub fn next(self: @This(), current: T, step: usize) ?T {
            return self.next_fn(self.state, current, step);
        }
    };
}

pub fn shrinkFailureCustomAlloc(
    allocator: std.mem.Allocator,
    schema: anytype,
    state: anytype,
    comptime property: fn (@TypeOf(state), @TypeOf(schema).Output) anyerror!void,
    failing_value: @TypeOf(schema).Output,
    shrinker: CustomShrinker(@TypeOf(schema).Output),
    max_steps: usize,
) !ShrinkResult {
    var result = ShrinkResult{
        .allocator = allocator,
        .minimal_json = try Schema.encodeJsonAlloc(allocator, schema, failing_value),
        .path = try allocator.dupe(u8, ""),
    };
    errdefer result.deinit();
    var current = failing_value;
    while (result.steps < max_steps) {
        const candidate = shrinker.next(current, result.steps) orelse break;
        if (try acceptCandidate(allocator, schema, state, property, candidate, "custom", &result, max_steps)) current = candidate else break;
    }
    return result;
}

pub const BoundaryBias = enum { minimum, maximum };

/// Generates an exact primitive boundary where the schema declares one. More
/// complex schemas deliberately return `BoundaryGeneratorRequired` so an agent
/// cannot mistake ordinary random data for boundary evidence.
pub fn generateBoundary(allocator: std.mem.Allocator, schema: anytype, bias: BoundaryBias) !Generated(@TypeOf(schema).Output) {
    const kind = @TypeOf(schema).generator_kind;
    if (comptime std.mem.eql(u8, kind, "integer")) return .{
        .allocator = allocator,
        .value = switch (bias) {
            .minimum => schema.min_value orelse std.math.minInt(i64),
            .maximum => schema.max_value orelse std.math.maxInt(i64),
        },
    };
    if (comptime std.mem.eql(u8, kind, "boolean")) return .{ .allocator = allocator, .value = bias == .maximum };
    if (comptime std.mem.eql(u8, kind, "enum")) {
        if (@TypeOf(schema).generator_choices.len == 0) return error.UnsatisfiableSchema;
        const index: usize = if (bias == .minimum) 0 else @TypeOf(schema).generator_choices.len - 1;
        return .{ .allocator = allocator, .value = try allocator.dupe(u8, @TypeOf(schema).generator_choices[index]) };
    }
    return error.BoundaryGeneratorRequired;
}

pub fn shrinkFailureAlloc(
    allocator: std.mem.Allocator,
    schema: anytype,
    state: anytype,
    comptime property: fn (@TypeOf(state), @TypeOf(schema).Output) anyerror!void,
    failing_value: @TypeOf(schema).Output,
    max_steps: usize,
) !ShrinkResult {
    var result = ShrinkResult{
        .allocator = allocator,
        .minimal_json = try Schema.encodeJsonAlloc(allocator, schema, failing_value),
        .path = try allocator.dupe(u8, ""),
    };
    errdefer result.deinit();
    if (max_steps == 0) return result;
    const kind = @TypeOf(schema).generator_kind;

    if (comptime std.mem.eql(u8, kind, "integer")) {
        var current = failing_value;
        const floor = schema.min_value orelse 0;
        while (result.steps < max_steps and current != floor) {
            const next = floor + @divTrunc(current - floor, 2);
            if (next == current) break;
            if (try acceptCandidate(allocator, schema, state, property, next, "integer:toward-min", &result, max_steps)) {
                current = next;
            } else break;
        }
    } else if (comptime std.mem.eql(u8, kind, "float")) {
        var current = failing_value;
        const floor = schema.min_value orelse 0.0;
        while (result.steps < max_steps and current != floor) {
            const next = floor + (current - floor) / 2.0;
            if (next == current) break;
            if (try acceptCandidate(allocator, schema, state, property, next, "float:toward-min", &result, max_steps)) current = next else break;
        }
    } else if (comptime std.mem.eql(u8, kind, "decimal")) {
        _ = try acceptCandidate(allocator, schema, state, property, "0", "decimal:zero", &result, max_steps);
    } else if (comptime std.mem.eql(u8, kind, "bytes")) {
        if (failing_value.len != 0) _ = try acceptCandidate(allocator, schema, state, property, "", "bytes:empty", &result, max_steps);
    } else if (comptime std.mem.eql(u8, kind, "time")) {
        if (failing_value != 0) _ = try acceptCandidate(allocator, schema, state, property, 0, "time:epoch", &result, max_steps);
    } else if (comptime std.mem.eql(u8, kind, "boolean")) {
        if (failing_value) _ = try acceptCandidate(allocator, schema, state, property, false, "boolean:false", &result, max_steps);
    } else if (comptime std.mem.eql(u8, kind, "string")) {
        var length = failing_value.len;
        const minimum = @max(schema.min_len orelse 0, @as(usize, @intFromBool(schema.require_non_empty)));
        while (result.steps < max_steps and length > minimum) {
            const next = @max(minimum, @divTrunc(length, 2));
            if (next == length) break;
            if (try acceptCandidate(allocator, schema, state, property, failing_value[0..next], "string:length", &result, max_steps)) {
                length = next;
            } else if (next != minimum) {
                if (try acceptCandidate(allocator, schema, state, property, failing_value[0..minimum], "string:length", &result, max_steps)) length = minimum else break;
            } else break;
        }
    } else if (comptime std.mem.eql(u8, kind, "optional")) {
        if (failing_value != null) _ = try acceptCandidate(allocator, schema, state, property, null, "optional:null", &result, max_steps);
    } else if (comptime std.mem.eql(u8, kind, "array")) {
        var length = failing_value.len;
        while (result.steps < max_steps and length > 0) {
            const next = @divTrunc(length, 2);
            if (try acceptCandidate(allocator, schema, state, property, failing_value[0..next], "array:length", &result, max_steps)) {
                length = next;
            } else break;
        }
    } else if (comptime std.mem.eql(u8, kind, "map")) {
        var length = failing_value.len;
        while (result.steps < max_steps and length > 0) {
            const next = @divTrunc(length, 2);
            if (try acceptCandidate(allocator, schema, state, property, failing_value[0..next], "map:entries", &result, max_steps)) length = next else break;
        }
    } else if (comptime std.mem.eql(u8, kind, "tuple")) {
        var candidate = failing_value;
        const first_kind = @TypeOf(schema.first).generator_kind;
        if (comptime std.mem.eql(u8, first_kind, "integer")) candidate.first = schema.first.min_value orelse 0 else if (comptime std.mem.eql(u8, first_kind, "boolean")) candidate.first = false;
        _ = try acceptCandidate(allocator, schema, state, property, candidate, "tuple:first", &result, max_steps);
        candidate = failing_value;
        const second_kind = @TypeOf(schema.second).generator_kind;
        if (comptime std.mem.eql(u8, second_kind, "integer")) candidate.second = schema.second.min_value orelse 0 else if (comptime std.mem.eql(u8, second_kind, "boolean")) candidate.second = false;
        _ = try acceptCandidate(allocator, schema, state, property, candidate, "tuple:second", &result, max_steps);
    } else if (comptime std.mem.eql(u8, kind, "tagged_union")) {
        var seeded = try Seeded.init(1);
        const candidate = try generateValue(allocator, schema, &seeded);
        defer Schema.freeDecoded(allocator, candidate);
        _ = try acceptCandidate(allocator, schema, state, property, candidate, "tagged-union:canonical", &result, max_steps);
    } else if (comptime std.mem.eql(u8, kind, "enum")) {
        if (@TypeOf(schema).generator_choices.len != 0) {
            _ = try acceptCandidate(allocator, schema, state, property, @TypeOf(schema).generator_choices[0], "enum:first", &result, max_steps);
        }
    } else if (comptime std.mem.eql(u8, kind, "default")) {
        result.deinit();
        return shrinkFailureAlloc(allocator, schema.inner, state, property, failing_value, max_steps);
    } else if (comptime std.mem.eql(u8, kind, "brand")) {
        result.deinit();
        return shrinkFailureAlloc(allocator, schema.inner, state, property, failing_value, max_steps);
    } else if (comptime std.mem.eql(u8, kind, "refinement")) {
        result.deinit();
        return shrinkFailureAlloc(allocator, schema.inner, state, property, failing_value, max_steps);
    } else if (comptime std.mem.eql(u8, kind, "lazy")) {
        result.deinit();
        return shrinkFailureAlloc(allocator, schema.resolved(), state, property, failing_value, max_steps);
    } else if (comptime std.mem.eql(u8, kind, "versioned")) {
        result.deinit();
        return shrinkFailureAlloc(allocator, schema.current, state, property, failing_value, max_steps);
    } else if (comptime std.mem.eql(u8, kind, "struct")) {
        var current = failing_value;
        inline for (schema.fields) |field| {
            if (result.steps < max_steps) {
                const name = @TypeOf(field).Name;
                const field_kind = @TypeOf(field.schema).generator_kind;
                var candidate = current;
                var changed = true;
                if (comptime std.mem.eql(u8, field_kind, "integer")) {
                    @field(candidate, name) = field.schema.min_value orelse 0;
                } else if (comptime std.mem.eql(u8, field_kind, "boolean")) {
                    @field(candidate, name) = false;
                } else if (comptime std.mem.eql(u8, field_kind, "optional")) {
                    @field(candidate, name) = null;
                } else if (comptime std.mem.eql(u8, field_kind, "string")) {
                    const minimum = @max(field.schema.min_len orelse 0, @as(usize, @intFromBool(field.schema.require_non_empty)));
                    @field(candidate, name) = @field(current, name)[0..@min(minimum, @field(current, name).len)];
                } else if (comptime std.mem.eql(u8, field_kind, "array")) {
                    @field(candidate, name) = @field(current, name)[0..0];
                } else if (comptime std.mem.eql(u8, field_kind, "enum")) {
                    if (@TypeOf(field.schema).generator_choices.len != 0) @field(candidate, name) = @TypeOf(field.schema).generator_choices[0] else changed = false;
                } else {
                    changed = false;
                }
                if (changed) {
                    const path = "struct:" ++ name;
                    if (try acceptCandidate(allocator, schema, state, property, candidate, path, &result, max_steps)) current = candidate;
                }
            }
        }
    } else if (comptime std.mem.eql(u8, kind, "derived")) {
        var current = failing_value;
        inline for (@typeInfo(@TypeOf(failing_value)).@"struct".fields) |field| {
            if (result.steps < max_steps) {
                var candidate = current;
                var changed = true;
                switch (@typeInfo(field.type)) {
                    .bool => @field(candidate, field.name) = false,
                    .int => @field(candidate, field.name) = 0,
                    .optional => @field(candidate, field.name) = null,
                    .@"enum" => @field(candidate, field.name) = @enumFromInt(@typeInfo(field.type).@"enum".fields[0].value),
                    .pointer => |pointer| if (pointer.size == .slice) {
                        @field(candidate, field.name) = @field(current, field.name)[0..0];
                    } else {
                        changed = false;
                    },
                    else => changed = false,
                }
                if (changed) {
                    const path = "derived:" ++ field.name;
                    if (try acceptCandidate(allocator, schema, state, property, candidate, path, &result, max_steps)) current = candidate;
                }
            }
        }
    }
    return result;
}

fn acceptCandidate(
    allocator: std.mem.Allocator,
    schema: anytype,
    state: anytype,
    comptime property: fn (@TypeOf(state), @TypeOf(schema).Output) anyerror!void,
    candidate: @TypeOf(schema).Output,
    path: []const u8,
    result: *ShrinkResult,
    max_steps: usize,
) !bool {
    if (result.steps >= max_steps) return false;
    property(state, candidate) catch {
        const encoded = Schema.encodeJsonAlloc(allocator, schema, candidate) catch return false;
        errdefer allocator.free(encoded);
        const owned_path = try allocator.dupe(u8, path);
        allocator.free(result.minimal_json);
        allocator.free(result.path);
        result.minimal_json = encoded;
        result.path = owned_path;
        result.steps += 1;
        return true;
    };
    return false;
}

pub fn CustomGenerator(comptime T: type) type {
    return struct {
        state: *anyopaque,
        generate_fn: *const fn (*anyopaque, std.mem.Allocator, *Seeded) anyerror!T,

        pub fn generate(self: @This(), allocator: std.mem.Allocator, seeded: *Seeded) !T {
            return self.generate_fn(self.state, allocator, seeded);
        }
    };
}

fn generateValue(allocator: std.mem.Allocator, schema: anytype, seeded: *Seeded) !@TypeOf(schema).Output {
    const S = @TypeOf(schema);
    if (!@hasDecl(S, "generator_kind")) return error.GeneratorRequired;
    const kind = S.generator_kind;
    if (comptime std.mem.eql(u8, kind, "string")) return generateString(allocator, schema, seeded);
    if (comptime std.mem.eql(u8, kind, "integer")) {
        const minimum = schema.min_value orelse -1000;
        const maximum = schema.max_value orelse 1000;
        if (minimum > maximum) return error.UnsatisfiableSchema;
        const span: u64 = @intCast(@as(i128, maximum) - @as(i128, minimum) + 1);
        return minimum + @as(i64, @intCast(seeded.next() % span));
    }
    if (comptime std.mem.eql(u8, kind, "boolean")) return seeded.bounded(2) == 1;
    if (comptime std.mem.eql(u8, kind, "float")) {
        const minimum = schema.min_value orelse -1000.0;
        const maximum = schema.max_value orelse 1000.0;
        if (!std.math.isFinite(minimum) or !std.math.isFinite(maximum) or minimum > maximum) return error.UnsatisfiableSchema;
        const unit = @as(f64, @floatFromInt(seeded.next() % 1_000_001)) / 1_000_000.0;
        return minimum + (maximum - minimum) * unit;
    }
    if (comptime std.mem.eql(u8, kind, "decimal")) {
        if (schema.max_digits == 0) return error.UnsatisfiableSchema;
        const whole = seeded.next() % 1_000_000;
        if (schema.max_scale == 0) return std.fmt.allocPrint(allocator, "{d}", .{whole});
        _ = seeded.next();
        return allocator.dupe(u8, "0.0");
    }
    if (comptime std.mem.eql(u8, kind, "bytes")) {
        const raw_len = seeded.bounded(@min(schema.max_bytes, 32) + 1);
        const raw = try allocator.alloc(u8, raw_len); defer allocator.free(raw);
        for (raw) |*byte| byte.* = @truncate(seeded.next());
        const encoded = try allocator.alloc(u8, std.base64.standard.Encoder.calcSize(raw.len));
        _ = std.base64.standard.Encoder.encode(encoded, raw);
        return encoded;
    }
    if (comptime std.mem.eql(u8, kind, "time")) return if (schema.allow_negative) @as(i64, @bitCast(seeded.next())) else @as(i64, @intCast(seeded.next() % std.math.maxInt(i32)));
    if (comptime std.mem.eql(u8, kind, "literal")) return allocator.dupe(u8, S.literal);
    if (comptime std.mem.eql(u8, kind, "optional")) {
        if (seeded.bounded(3) == 0) return null;
        return try generateValue(allocator, schema.inner, seeded);
    }
    if (comptime std.mem.eql(u8, kind, "array")) {
        const len = seeded.bounded(5);
        const values = try allocator.alloc(@TypeOf(schema.inner).Output, len);
        errdefer allocator.free(values);
        var initialized: usize = 0;
        errdefer for (values[0..initialized]) |value| Schema.freeDecoded(allocator, value);
        for (values) |*value| {
            value.* = try generateValue(allocator, schema.inner, seeded);
            initialized += 1;
        }
        return values;
    }
    if (comptime std.mem.eql(u8, kind, "tuple")) {
        const first = try generateValue(allocator, schema.first, seeded); errdefer Schema.freeDecoded(allocator, first);
        return .{ .first = first, .second = try generateValue(allocator, schema.second, seeded) };
    }
    if (comptime std.mem.eql(u8, kind, "tagged_union")) {
        if (seeded.bounded(2) == 0) return .{ .first = try generateValue(allocator, schema.first, seeded) };
        return .{ .second = try generateValue(allocator, schema.second, seeded) };
    }
    if (comptime std.mem.eql(u8, kind, "map")) {
        const len = seeded.bounded(@min(schema.max_entries, 4) + 1);
        const entries = try allocator.alloc(S.Entry, len); errdefer allocator.free(entries);
        var initialized: usize = 0;
        errdefer for (entries[0..initialized]) |entry| { allocator.free(entry.key); Schema.freeDecoded(allocator, entry.value); };
        for (entries, 0..) |*entry, index| { entry.* = .{ .key = try std.fmt.allocPrint(allocator, "key-{d}", .{index}), .value = try generateValue(allocator, schema.inner, seeded) }; initialized += 1; }
        return entries;
    }
    if (comptime std.mem.eql(u8, kind, "enum")) {
        if (S.generator_choices.len == 0) return error.UnsatisfiableSchema;
        return allocator.dupe(u8, S.generator_choices[seeded.bounded(S.generator_choices.len)]);
    }
    if (comptime std.mem.eql(u8, kind, "default")) return generateValue(allocator, schema.inner, seeded);
    if (comptime std.mem.eql(u8, kind, "brand")) return generateValue(allocator, schema.inner, seeded);
    if (comptime std.mem.eql(u8, kind, "refinement")) {
        for (0..256) |_| {
            const candidate = try generateValue(allocator, schema.inner, seeded);
            if (schema.accepts(candidate)) return candidate;
            Schema.freeDecoded(allocator, candidate);
        }
        return error.UnsatisfiableSchema;
    }
    if (comptime std.mem.eql(u8, kind, "lazy")) return generateValue(allocator, schema.resolved(), seeded);
    if (comptime std.mem.eql(u8, kind, "versioned")) return generateValue(allocator, schema.current, seeded);
    if (comptime std.mem.eql(u8, kind, "struct")) {
        var output: S.Output = undefined;
        var initialized: usize = 0;
        errdefer {
            inline for (schema.fields, 0..) |field, index| if (index < initialized) Schema.freeDecoded(allocator, @field(output, @TypeOf(field).Name));
        }
        inline for (schema.fields) |field| {
            @field(output, @TypeOf(field).Name) = try generateValue(allocator, field.schema, seeded);
            initialized += 1;
        }
        return output;
    }
    if (comptime std.mem.eql(u8, kind, "derived")) return generateDerived(allocator, schema, seeded);
    if (comptime std.mem.eql(u8, kind, "transform")) return error.GeneratorRequired;
    return error.GeneratorRequired;
}

fn generateDerived(allocator: std.mem.Allocator, schema: anytype, seeded: *Seeded) !@TypeOf(schema).Output {
    const Output = @TypeOf(schema).Output;
    var output: Output = undefined;
    inline for (@typeInfo(Output).@"struct".fields) |field| {
        if (@hasField(@TypeOf(schema.overrides), field.name)) {
            @field(output, field.name) = try generateValue(allocator, @field(schema.overrides, field.name), seeded);
        } else {
            @field(output, field.name) = try generateInferred(allocator, field.type, seeded);
        }
    }
    return output;
}

fn generateInferred(allocator: std.mem.Allocator, comptime T: type, seeded: *Seeded) !T {
    return switch (@typeInfo(T)) {
        .bool => seeded.bounded(2) == 1,
        .int => @intCast(seeded.next() % 101),
        .float => @floatFromInt(seeded.next() % 101),
        .optional => |info| if (seeded.bounded(3) == 0) null else try generateInferred(allocator, info.child, seeded),
        .@"enum" => |info| @enumFromInt(info.fields[seeded.bounded(info.fields.len)].value),
        .pointer => |info| if (info.size == .slice and info.child == u8) try allocator.dupe(u8, "generated") else error.GeneratorRequired,
        else => error.GeneratorRequired,
    };
}

fn generateString(allocator: std.mem.Allocator, schema: Schema.StringSchema, seeded: *Seeded) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    if (schema.starts_with) |prefix| try output.appendSlice(allocator, prefix);
    if (schema.contains_text) |needle| if (std.mem.indexOf(u8, output.items, needle) == null) try output.appendSlice(allocator, needle);
    const suffix_len = if (schema.ends_with) |suffix| suffix.len else 0;
    const required_non_empty: usize = if (schema.require_non_empty) 1 else 0;
    const minimum: usize = @max(schema.min_len orelse 0, required_non_empty);
    const maximum = schema.max_len orelse @max(minimum + 16, output.items.len + suffix_len);
    if (output.items.len + suffix_len > maximum or minimum > maximum) return error.UnsatisfiableSchema;
    const available = maximum - output.items.len - suffix_len;
    const required = if (minimum > output.items.len + suffix_len) minimum - output.items.len - suffix_len else 0;
    const extra = if (available > required) seeded.bounded(available - required + 1) else 0;
    for (0..required + extra) |_| try output.append(allocator, @intCast('a' + seeded.bounded(26)));
    if (schema.ends_with) |suffix| try output.appendSlice(allocator, suffix);
    return output.toOwnedSlice(allocator);
}

fn generatorKind(comptime S: type) []const u8 {
    if (!@hasDecl(S, "generator_kind")) return "unknown";
    return S.generator_kind;
}

test "schema generation is deterministic and respects primitive constraints" {
    var left = try Seeded.init(42);
    var right = try Seeded.init(42);
    const string_schema = Schema.string().nonEmpty().minLen(5).maxLen(12).startsWith("id-");
    var first = try generate(std.testing.allocator, string_schema, &left);
    defer first.deinit();
    var second = try generate(std.testing.allocator, string_schema, &right);
    defer second.deinit();
    try std.testing.expectEqualStrings(first.value, second.value);
    try std.testing.expect(first.value.len >= 5 and first.value.len <= 12);
    const integer_schema = Schema.integer().min(10).max(20);
    var number = try generate(std.testing.allocator, integer_schema, &left);
    defer number.deinit();
    try std.testing.expect(number.value >= 10 and number.value <= 20);
}

test "schema generation supports enum optional array and struct outputs" {
    const Input = struct { name: []const u8, enabled: ?bool, roles: []const []const u8 };
    var seeded = try Seeded.init(9);
    const schema = Schema.structSchema(Input, .{
        Schema.field("name", Schema.string().nonEmpty().maxLen(12)),
        Schema.field("enabled", Schema.optional(Schema.boolean())),
        Schema.field("roles", Schema.array(std.testing.allocator, Schema.stringEnum(&.{ "reader", "writer" }))),
    });
    var generated = try generate(std.testing.allocator, schema, &seeded);
    defer generated.deinit();
    try std.testing.expect(generated.value.name.len > 0);
    for (generated.value.roles) |role| try std.testing.expect(std.mem.eql(u8, role, "reader") or std.mem.eql(u8, role, "writer"));
}

test "property runner shrinks integer counterexamples and emits replay metadata" {
    const State = struct { limit: i64 };
    const Property = struct {
        fn check(state: *State, value: i64) !void {
            if (value > state.limit) return error.TooLarge;
        }
    };
    var state = State{ .limit = 4 };
    var receipt = try runProperty(std.testing.allocator, Schema.integer().min(0).max(100), &state, Property.check, .{ .seed = 17, .cases = 100 });
    defer receipt.deinit();
    try std.testing.expect(!receipt.passed);
    try std.testing.expect(receipt.failing_case_index != null);
    try std.testing.expect(receipt.minimalCase() != null);
}

test "structural shrinking minimizes strings arrays and explicit structs" {
    const AlwaysFails = struct {
        fn string(_: void, _: []const u8) !void {
            return error.Counterexample;
        }
        fn array(_: void, _: []const i64) !void {
            return error.Counterexample;
        }
    };
    var string_result = try shrinkFailureAlloc(std.testing.allocator, Schema.string().minLen(1).maxLen(16), {}, AlwaysFails.string, "abcdefgh", 32);
    defer string_result.deinit();
    try std.testing.expect(string_result.steps > 0);
    try std.testing.expectEqualStrings("string:length", string_result.path);

    const values = [_]i64{ 1, 2, 3, 4 };
    var array_result = try shrinkFailureAlloc(std.testing.allocator, Schema.array(std.testing.allocator, Schema.integer()), {}, AlwaysFails.array, values[0..], 32);
    defer array_result.deinit();
    try std.testing.expect(array_result.steps > 0);
    try std.testing.expectEqualStrings("array:length", array_result.path);

    const Input = struct { count: i64, enabled: bool };
    const StructProperty = struct {
        fn check(_: void, _: Input) !void {
            return error.Counterexample;
        }
    };
    const schema = Schema.structSchema(Input, .{ Schema.field("count", Schema.integer().min(0)), Schema.field("enabled", Schema.boolean()) });
    var struct_result = try shrinkFailureAlloc(std.testing.allocator, schema, {}, StructProperty.check, .{ .count = 100, .enabled = true }, 32);
    defer struct_result.deinit();
    try std.testing.expect(struct_result.steps >= 2);
    try std.testing.expect(std.mem.indexOf(u8, struct_result.path, "struct:") != null);
}

test "transforms require an explicit lawful custom generator" {
    const Mapper = struct {
        fn map(value: i64) Schema.SchemaError!u64 {
            return @intCast(value);
        }
    };
    var seeded = try Seeded.init(1);
    const schema = Schema.transform(Schema.integer().min(0), u64, Mapper.map);
    try std.testing.expectError(error.GeneratorRequired, generate(std.testing.allocator, schema, &seeded));
}

test "boundary generation and custom shrinking are explicit and deterministic" {
    var low = try generateBoundary(std.testing.allocator, Schema.integer().min(-2).max(8), .minimum);
    defer low.deinit();
    var high = try generateBoundary(std.testing.allocator, Schema.integer().min(-2).max(8), .maximum);
    defer high.deinit();
    try std.testing.expectEqual(@as(i64, -2), low.value);
    try std.testing.expectEqual(@as(i64, 8), high.value);

    const Property = struct {
        fn check(_: void, _: i64) !void {
            return error.Counterexample;
        }
    };
    const State = struct {
        fn next(_: *anyopaque, current: i64, _: usize) ?i64 {
            if (current == 0) return null;
            return @divTrunc(current, 2);
        }
    };
    var state: u8 = 0;
    var result = try shrinkFailureCustomAlloc(std.testing.allocator, Schema.integer(), {}, Property.check, 64, .{ .state = &state, .next_fn = State.next }, 32);
    defer result.deinit();
    try std.testing.expect(result.steps > 0);
    try std.testing.expectEqualStrings("custom", result.path);
}

test "production schema constructs generate deterministically and release ownership" {
    const Positive = struct { fn check(value: i64) bool { return value >= 0; } };
    var seeded = try Seeded.init(77);
    var float_value = try generate(std.testing.allocator, Schema.float().min(-1).max(1), &seeded); defer float_value.deinit();
    var decimal_value = try generate(std.testing.allocator, Schema.decimal(), &seeded); defer decimal_value.deinit();
    var bytes_value = try generate(std.testing.allocator, Schema.bytes(), &seeded); defer bytes_value.deinit();
    var tuple_value = try generate(std.testing.allocator, Schema.tuple2(Schema.literal("fixed"), Schema.refine(Schema.integer().min(0), "positive", Positive.check)), &seeded); defer tuple_value.deinit();
    var union_value = try generate(std.testing.allocator, Schema.taggedUnion2(Schema.string(), Schema.boolean(), "text", "flag"), &seeded); defer union_value.deinit();
    var map_value = try generate(std.testing.allocator, Schema.map(std.testing.allocator, Schema.durationMillis()), &seeded); defer map_value.deinit();
    try std.testing.expect(std.math.isFinite(float_value.value));
    try std.testing.expect(decimal_value.value.len != 0 and bytes_value.value.len % 4 == 0);
    try std.testing.expectEqualStrings("fixed", tuple_value.value.first);
    _ = union_value.value; _ = map_value.value;
}

test "production primitive shrinkers minimize floats decimals bytes and time" {
    const FloatProperty = struct { fn check(_: void, _: f64) !void { return error.Counterexample; } };
    var float_result = try shrinkFailureAlloc(std.testing.allocator, Schema.float().min(0).max(100), {}, FloatProperty.check, 80, 16);
    defer float_result.deinit();
    try std.testing.expect(float_result.steps > 0);
    try std.testing.expect(std.mem.indexOf(u8, float_result.path, "float:toward-min") != null);

    const BytesProperty = struct { fn check(_: void, _: []const u8) !void { return error.Counterexample; } };
    var bytes_result = try shrinkFailureAlloc(std.testing.allocator, Schema.bytes(), {}, BytesProperty.check, "YWJj", 4);
    defer bytes_result.deinit();
    try std.testing.expectEqualStrings("bytes:empty", bytes_result.path);

    const TimeProperty = struct { fn check(_: void, _: i64) !void { return error.Counterexample; } };
    var time_result = try shrinkFailureAlloc(std.testing.allocator, Schema.timestampMillis(), {}, TimeProperty.check, 1234, 4);
    defer time_result.deinit();
    try std.testing.expectEqualStrings("time:epoch", time_result.path);
}
