const std = @import("std");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

pub const redacted = "[REDACTED]";

pub const SecretString = struct {
    value: []const u8,

    pub fn expose(self: SecretString) []const u8 {
        return self.value;
    }

    pub fn display(_: SecretString) []const u8 {
        return redacted;
    }
};

pub const Reference = struct {
    provider: []const u8,
    key: []const u8,

    pub fn validate(self: Reference) !void {
        if (!validReferencePart(self.provider) or !validReferencePart(self.key)) return error.InvalidSecretReference;
    }
    pub fn displayAlloc(self: Reference, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        return std.fmt.allocPrint(allocator, "secret://{s}/{s}", .{ self.provider, self.key });
    }
};

pub const Value = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    rotation_epoch: u64 = 0,

    pub fn initAlloc(allocator: std.mem.Allocator, bytes: []const u8, epoch: u64) !Value {
        if (bytes.len == 0) return error.EmptySecret;
        return .{ .allocator = allocator, .bytes = try allocator.dupe(u8, bytes), .rotation_epoch = epoch };
    }
    pub fn expose(self: *const Value) []const u8 {
        return self.bytes;
    }
    pub fn display(_: *const Value) []const u8 {
        return redacted;
    }
    pub fn deinit(self: *Value) void {
        @memset(self.bytes, 0);
        self.allocator.free(self.bytes);
        self.* = undefined;
    }
};

pub const Access = struct { reference: Reference, epoch: u64, succeeded: bool };

pub const Audit = struct {
    allocator: std.mem.Allocator,
    accesses: std.ArrayList(Access) = .empty,
    pub fn init(allocator: std.mem.Allocator) Audit {
        return .{ .allocator = allocator };
    }
    pub fn deinit(self: *Audit) void {
        for (self.accesses.items) |access| {
            self.allocator.free(access.reference.provider);
            self.allocator.free(access.reference.key);
        }
        self.accesses.deinit(self.allocator);
    }
    /// Records only the reference and rotation epoch. Reference text is copied so
    /// audit evidence never borrows request memory and never contains material.
    pub fn record(self: *Audit, access: Access) !void {
        const provider = try self.allocator.dupe(u8, access.reference.provider);
        errdefer self.allocator.free(provider);
        const key = try self.allocator.dupe(u8, access.reference.key);
        errdefer self.allocator.free(key);
        try self.accesses.append(self.allocator, .{
            .reference = .{ .provider = provider, .key = key },
            .epoch = access.epoch,
            .succeeded = access.succeeded,
        });
    }
};

pub const Provider = struct {
    pointer: *anyopaque,
    resolve_fn: *const fn (*anyopaque, std.mem.Allocator, Reference, ?*Audit) anyerror!Value,
    pub fn from(comptime ProviderType: type, provider: *ProviderType) Provider {
        return .{ .pointer = provider, .resolve_fn = struct {
            fn resolve(raw: *anyopaque, allocator: std.mem.Allocator, reference: Reference, audit: ?*Audit) anyerror!Value {
                return (@as(*ProviderType, @ptrCast(@alignCast(raw)))).resolveAlloc(allocator, reference, audit);
            }
        }.resolve };
    }
    pub fn resolveAlloc(self: Provider, allocator: std.mem.Allocator, reference: Reference, audit: ?*Audit) !Value {
        try reference.validate();
        return self.resolve_fn(self.pointer, allocator, reference, audit);
    }
};

const StoredSecret = struct { bytes: []u8, epoch: u64 };

pub const RotatingMemoryProvider = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    values: std.StringHashMap(StoredSecret),
    mutex: std.atomic.Mutex = .unlocked,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !RotatingMemoryProvider {
        if (!validReferencePart(name)) return error.InvalidSecretReference;
        return .{ .allocator = allocator, .name = try allocator.dupe(u8, name), .values = .init(allocator) };
    }
    pub fn deinit(self: *RotatingMemoryProvider) void {
        var iterator = self.values.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            @memset(entry.value_ptr.bytes, 0);
            self.allocator.free(entry.value_ptr.bytes);
        }
        self.values.deinit();
        self.allocator.free(self.name);
    }
    pub fn asProvider(self: *RotatingMemoryProvider) Provider {
        return Provider.from(RotatingMemoryProvider, self);
    }
    pub fn rotate(self: *RotatingMemoryProvider, key: []const u8, bytes: []const u8) !u64 {
        if (!validReferencePart(key) or bytes.len == 0) return error.InvalidSecretReference;
        self.lock();
        defer self.mutex.unlock();
        const next_epoch = if (self.values.get(key)) |stored| stored.epoch + 1 else 1;
        if (self.values.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            @memset(old.value.bytes, 0);
            self.allocator.free(old.value.bytes);
        }
        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);
        const owned_bytes = try self.allocator.dupe(u8, bytes);
        errdefer self.allocator.free(owned_bytes);
        try self.values.put(owned_key, .{ .bytes = owned_bytes, .epoch = next_epoch });
        return next_epoch;
    }
    pub fn resolveAlloc(self: *RotatingMemoryProvider, allocator: std.mem.Allocator, reference: Reference, audit: ?*Audit) !Value {
        try reference.validate();
        if (!std.mem.eql(u8, reference.provider, self.name)) {
            if (audit) |target| try target.record(.{ .reference = reference, .epoch = 0, .succeeded = false });
            return error.SecretProviderMismatch;
        }
        self.lock();
        defer self.mutex.unlock();
        const stored = self.values.get(reference.key) orelse {
            if (audit) |target| try target.record(.{ .reference = reference, .epoch = 0, .succeeded = false });
            return error.SecretNotFound;
        };
        const result = try Value.initAlloc(allocator, stored.bytes, stored.epoch);
        if (audit) |target| try target.record(.{ .reference = reference, .epoch = stored.epoch, .succeeded = true });
        return result;
    }
    fn lock(self: *RotatingMemoryProvider) void {
        while (!self.mutex.tryLock()) std.Thread.yield() catch {};
    }
};

pub const EnvironmentProvider = struct {
    environ: std.process.Environ,
    prefix: []const u8 = "ZIGEFFECT_SECRET_",
    pub fn resolveAlloc(self: *EnvironmentProvider, allocator: std.mem.Allocator, reference: Reference, audit: ?*Audit) !Value {
        if (!std.mem.eql(u8, reference.provider, "environment") or !validReferencePart(reference.key)) {
            if (audit) |target| try target.record(.{ .reference = reference, .epoch = 0, .succeeded = false });
            return error.SecretProviderMismatch;
        }
        const variable = try std.fmt.allocPrint(allocator, "{s}{s}", .{ self.prefix, reference.key });
        defer allocator.free(variable);
        const bytes = std.process.Environ.getAlloc(self.environ, allocator, variable) catch |err| switch (err) {
            error.EnvironmentVariableMissing => {
                if (audit) |target| try target.record(.{ .reference = reference, .epoch = 0, .succeeded = false });
                return error.SecretNotFound;
            },
            else => return err,
        };
        defer {
            @memset(bytes, 0);
            allocator.free(bytes);
        }
        const result = try Value.initAlloc(allocator, bytes, 1);
        if (audit) |target| try target.record(.{ .reference = reference, .epoch = 1, .succeeded = true });
        return result;
    }
};

pub const FileProvider = struct {
    io: std.Io,
    dir: *std.Io.Dir,
    max_bytes: usize = 64 * 1024,
    pub fn resolveAlloc(self: *FileProvider, allocator: std.mem.Allocator, reference: Reference, audit: ?*Audit) !Value {
        if (!std.mem.eql(u8, reference.provider, "file") or !validReferencePart(reference.key)) {
            if (audit) |target| try target.record(.{ .reference = reference, .epoch = 0, .succeeded = false });
            return error.SecretProviderMismatch;
        }
        const file_name = try std.fmt.allocPrint(allocator, "{s}.secret", .{reference.key});
        defer allocator.free(file_name);
        const bytes = self.dir.readFileAlloc(self.io, file_name, allocator, .limited(self.max_bytes)) catch |err| {
            if (audit) |target| try target.record(.{ .reference = reference, .epoch = 0, .succeeded = false });
            return err;
        };
        defer {
            @memset(bytes, 0);
            allocator.free(bytes);
        }
        const trimmed = std.mem.trim(u8, bytes, "\r\n");
        const result = try Value.initAlloc(allocator, trimmed, 1);
        if (audit) |target| try target.record(.{ .reference = reference, .epoch = 1, .succeeded = true });
        return result;
    }
};

fn validReferencePart(value: []const u8) bool {
    if (value.len == 0 or value.len > 128) return false;
    for (value) |byte| if (!(std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '-')) return false;
    return true;
}

pub fn containsSecret(input: []const u8) bool {
    return fx.containsSensitiveMaterial(input);
}

fn containsSecretKeyPrefix(input: []const u8) bool {
    const needle = "sk-";
    var offset: usize = 0;
    while (offset + needle.len <= input.len) : (offset += 1) {
        if (!eqlInsensitive(input[offset .. offset + needle.len], needle)) continue;
        if (offset == 0 or !std.ascii.isAlphanumeric(input[offset - 1])) return true;
    }
    return false;
}

pub fn redactAlloc(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    if (containsSecret(input)) return allocator.dupe(u8, redacted);
    return allocator.dupe(u8, input);
}

/// Canonical serializer for any payload that can leave the process as logs,
/// receipts, causal evidence, snapshots, or Workbench data.
pub fn safeJsonAlloc(allocator: std.mem.Allocator, value: anytype, options: std.json.Stringify.Options) ![]u8 {
    const json = try std.json.Stringify.valueAlloc(allocator, value, options);
    errdefer allocator.free(json);
    if (containsSecret(json)) return error.SecretMaterialRejected;
    return json;
}

pub fn requireSafeBoundary(input: []const u8) !void {
    if (containsSecret(input)) return error.SecretMaterialRejected;
}

pub const Redactor = struct {
    pub const operations: []const []const u8 = &.{"Secrets.redact"};

    pub fn contains(_: Redactor, input: []const u8) bool {
        return containsSecret(input);
    }

    pub fn redactAlloc(_: Redactor, allocator: std.mem.Allocator, input: []const u8) std.mem.Allocator.Error![]const u8 {
        return @import("root.zig").redactAlloc(allocator, input);
    }
};

pub const RedactorService = fx.kernel.Service("zigeffect/std/Redactor", Redactor);

pub fn redactorLayer() @TypeOf(fx.kernel.Layer.succeed(RedactorService, Redactor{})) {
    return fx.kernel.Layer.succeed(RedactorService, .{});
}

pub fn redact(input: []const u8) fx.kernel.Effect(
    []const u8,
    std.mem.Allocator.Error,
    .{RedactorService},
).Stateful([]const u8) {
    const Redact = fx.kernel.Effect([]const u8, std.mem.Allocator.Error, .{RedactorService});
    return Redact.fromState([]const u8, input, struct {
        fn run(value: []const u8, ctx: *Redact.Context) std.mem.Allocator.Error![]const u8 {
            const operation = StdService.beginOperation(ctx, RedactorService.service_key, "Secrets.redact", value);
            const output = ctx.service(RedactorService).redactAlloc(ctx.allocator(), value) catch |failure| {
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.completeOperation(ctx, operation, "success", "redacted output");
            return output;
        }
    }.run);
}

fn containsInsensitive(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (needle.len > haystack.len) return false;

    var index: usize = 0;
    while (index + needle.len <= haystack.len) : (index += 1) {
        if (eqlInsensitive(haystack[index .. index + needle.len], needle)) return true;
    }
    return false;
}

fn eqlInsensitive(left: []const u8, right: []const u8) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_byte, right_byte| {
        if (std.ascii.toLower(left_byte) != std.ascii.toLower(right_byte)) return false;
    }
    return true;
}

fn containsUrlUserInfo(input: []const u8) bool {
    const scheme = std.mem.indexOf(u8, input, "://") orelse return false;
    const authority_start = scheme + 3;
    const authority_end = if (std.mem.indexOfScalarPos(u8, input, authority_start, '/')) |slash|
        slash
    else
        input.len;
    const authority = input[authority_start..authority_end];
    const at_index = std.mem.indexOfScalar(u8, authority, '@') orelse return false;
    return std.mem.indexOfScalar(u8, authority[0..at_index], ':') != null;
}

test "Secrets redacts sentinel token password and auth URL" {
    const samples = [_][]const u8{
        "sentinel-secret-for-tests",
        "token=abc123",
        "password=hunter2",
        "authorization: Bearer abc123",
        "postgres://user:pass@localhost/db",
        "sk-project-key",
    };

    for (samples) |sample| {
        const redacted_text = try redactAlloc(std.testing.allocator, sample);
        defer std.testing.allocator.free(redacted_text);

        try std.testing.expectEqualStrings(redacted, redacted_text);
    }
}

test "safe JSON rejects material at the serialization boundary" {
    try std.testing.expectError(error.SecretMaterialRejected, safeJsonAlloc(std.testing.allocator, .{ .password = "hunter2" }, .{}));
    const safe = try safeJsonAlloc(std.testing.allocator, .{ .secret_reference = "secret://environment/DATABASE_PASSWORD", .idempotency_key = "safe" }, .{});
    defer std.testing.allocator.free(safe);
    try std.testing.expect(std.mem.indexOf(u8, safe, "DATABASE_PASSWORD") != null);
}

test "SecretString never exposes raw display text" {
    const secret = SecretString{ .value = "sentinel-secret-for-tests" };

    try std.testing.expectEqualStrings("sentinel-secret-for-tests", secret.expose());
    try std.testing.expectEqualStrings(redacted, secret.display());
}

test "secret references rotate audit and zero owned values" {
    var provider = try RotatingMemoryProvider.init(std.testing.allocator, "memory");
    defer provider.deinit();
    try std.testing.expectEqual(@as(u64, 1), try provider.rotate("DATABASE_PASSWORD", "sentinel-secret-one"));
    var audit = Audit.init(std.testing.allocator);
    defer audit.deinit();
    var value = try provider.asProvider().resolveAlloc(std.testing.allocator, .{ .provider = "memory", .key = "DATABASE_PASSWORD" }, &audit);
    try std.testing.expectEqualStrings(redacted, value.display());
    try std.testing.expectEqualStrings("sentinel-secret-one", value.expose());
    value.deinit();
    try std.testing.expectEqual(@as(u64, 2), try provider.rotate("DATABASE_PASSWORD", "sentinel-secret-two"));
    try std.testing.expectEqual(@as(usize, 1), audit.accesses.items.len);
    const display = try (Reference{ .provider = "memory", .key = "DATABASE_PASSWORD" }).displayAlloc(std.testing.allocator);
    defer std.testing.allocator.free(display);
    try std.testing.expect(std.mem.indexOf(u8, display, "sentinel-secret") == null);
}

test "Secrets does not mistake an embedded sk prefix for a key" {
    try std.testing.expect(!containsSecret("task-invoice"));
    try std.testing.expect(!containsSecret("risk-model"));
    try std.testing.expect(containsSecret("key sk-project-key"));
}

test "Secrets.redact uses a canonical Redactor layer and records causal fact" {
    const root = redactorLayer();
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{ .causal_store = &store });
    defer runtime.deinit();

    const output = try runtime.run(redact("token=abc123"));
    defer std.testing.allocator.free(output);

    try std.testing.expectEqualStrings(redacted, output);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    var saw = false;
    for (snapshot.events) |event| {
        if (event.kind == .io_completed and std.mem.eql(u8, event.service_key, RedactorService.service_key)) saw = true;
    }
    try std.testing.expect(saw);
}
