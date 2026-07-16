const std = @import("std");
const Contract = @import("contract.zig");

pub const control_schema = "zigeffect.test-control.v1";
pub const control_schema_version: u32 = 1;
pub const control_path = ".zigeffect/tests/control.json";
pub const process_receipt_root = ".zigeffect/tests/process-receipts";
pub const raw_receipt_root = ".zigeffect/tests/raw-receipts";

const Secrets = @import("../secrets/root.zig");

pub const ProtocolError = error{
    UnsupportedControlSchema,
    InvalidIdentifier,
    InvalidControl,
    SecretDetected,
    ReceiptSelectionMismatch,
};

pub const Control = struct {
    schema: []const u8 = control_schema,
    schema_version: u32 = control_schema_version,
    scenario: Contract.Scenario,
    project: []const u8,
    seed: u64,
    fault_kind: Contract.FaultKind = .none,
    fault_index: ?usize = null,
    schedule_choices: []const u32 = &.{},
    executor: []const u8 = "deterministic",
    source_revision: []const u8 = "working-tree",
    command_digest: []const u8 = "",
    manifest_digest: []const u8 = "",
    required_native_receipt: bool = true,

    pub fn validate(self: Control) !void {
        if (!std.mem.eql(u8, self.schema, control_schema) or self.schema_version != control_schema_version) return error.UnsupportedControlSchema;
        try self.scenario.validate();
        try validateIdentifier(self.project);
        if (self.seed == 0) return error.InvalidControl;
        try validateIdentifier(self.executor);
        if (self.source_revision.len == 0 or self.source_revision.len > 4096) return error.InvalidControl;
        if (self.command_digest.len > 256 or self.manifest_digest.len > 256) return error.InvalidControl;
        if (Secrets.containsSecret(self.source_revision) or Secrets.containsSecret(self.command_digest) or Secrets.containsSecret(self.manifest_digest)) return error.SecretDetected;
    }

    pub fn matches(self: Control, selected: Contract.Scenario) bool {
        return std.mem.eql(u8, self.scenario.id, selected.id) and
            std.mem.eql(u8, self.scenario.requirement, selected.requirement) and
            std.mem.eql(u8, self.scenario.acceptance_check, selected.acceptance_check) and
            std.mem.eql(u8, self.scenario.component, selected.component) and
            std.mem.eql(u8, self.scenario.command, selected.command);
    }

    pub fn jsonAlloc(self: Control, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        const json = try std.json.Stringify.valueAlloc(allocator, self, .{});
        errdefer allocator.free(json);
        if (Secrets.containsSecret(json)) return error.SecretDetected;
        return json;
    }
};

pub const ParsedControl = std.json.Parsed(Control);

pub fn parseControl(allocator: std.mem.Allocator, input: []const u8) !ParsedControl {
    if (Secrets.containsSecret(input)) return error.SecretDetected;
    var parsed = try std.json.parseFromSlice(Control, allocator, input, .{ .allocate = .alloc_always });
    errdefer parsed.deinit();
    try parsed.value.validate();
    return parsed;
}

pub fn writeControl(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, control: Control) !void {
    const json = try control.jsonAlloc(allocator);
    defer allocator.free(json);
    try writeAtomicFile(allocator, io, dir, control_path, json);
}

pub fn readControl(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir) !ParsedControl {
    const json = try dir.readFileAlloc(io, control_path, allocator, .limited(1024 * 1024));
    defer allocator.free(json);
    return parseControl(allocator, json);
}

pub fn removeControl(io: std.Io, dir: std.Io.Dir) !void {
    dir.deleteFile(io, control_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
}

pub fn publishedReceiptPathAlloc(allocator: std.mem.Allocator, scenario_id: []const u8) ![]u8 {
    try validateIdentifier(scenario_id);
    return std.fmt.allocPrint(allocator, "{s}/{s}.json", .{ process_receipt_root, scenario_id });
}

pub fn rawReceiptPathAlloc(allocator: std.mem.Allocator, scenario_id: []const u8) ![]u8 {
    try validateIdentifier(scenario_id);
    return std.fmt.allocPrint(allocator, "{s}/{s}.json", .{ raw_receipt_root, scenario_id });
}

pub fn publishReceipt(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, receipt_value: Contract.TestReceipt) !void {
    const json = try receipt_value.jsonAlloc(allocator);
    defer allocator.free(json);
    if (Secrets.containsSecret(json)) return error.SecretDetected;
    const path = try publishedReceiptPathAlloc(allocator, receipt_value.scenario.id);
    defer allocator.free(path);
    try writeAtomicFile(allocator, io, dir, path, json);
}

pub fn publishRawReceipt(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, receipt_value: Contract.TestReceipt) !void {
    const json = try receipt_value.jsonAlloc(allocator);
    defer allocator.free(json);
    if (Secrets.containsSecret(json)) return error.SecretDetected;
    const path = try rawReceiptPathAlloc(allocator, receipt_value.scenario.id);
    defer allocator.free(path);
    try writeAtomicFile(allocator, io, dir, path, json);
}

pub fn readPublishedReceipt(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, scenario_id: []const u8) !Contract.ParsedReceipt {
    const path = try publishedReceiptPathAlloc(allocator, scenario_id);
    defer allocator.free(path);
    const json = try dir.readFileAlloc(io, path, allocator, .limited(16 * 1024 * 1024));
    defer allocator.free(json);
    if (Secrets.containsSecret(json)) return error.SecretDetected;
    return Contract.parseReceipt(allocator, json);
}

pub fn readRawReceipt(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, scenario_id: []const u8) !Contract.ParsedReceipt {
    const path = try rawReceiptPathAlloc(allocator, scenario_id);
    defer allocator.free(path);
    const json = try dir.readFileAlloc(io, path, allocator, .limited(16 * 1024 * 1024));
    defer allocator.free(json);
    if (Secrets.containsSecret(json)) return error.SecretDetected;
    return Contract.parseReceipt(allocator, json);
}

pub fn removePublishedReceipt(io: std.Io, dir: std.Io.Dir, scenario_id: []const u8) !void {
    const path = try publishedReceiptPathAlloc(std.heap.page_allocator, scenario_id);
    defer std.heap.page_allocator.free(path);
    dir.deleteFile(io, path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
}

pub fn validatePublishedReceipt(receipt_value: Contract.TestReceipt, control: Control) !void {
    try control.validate();
    try receipt_value.validate();
    if (!control.matches(receipt_value.scenario) or
        !std.mem.eql(u8, receipt_value.project, control.project) or
        receipt_value.seed != control.seed or
        receipt_value.fault_kind != control.fault_kind or
        receipt_value.fault_index != control.fault_index or
        !std.mem.eql(u8, receipt_value.executor, control.executor) or
        (control.source_revision.len != 0 and !std.mem.eql(u8, receipt_value.source_revision, control.source_revision)))
    {
        return error.ReceiptSelectionMismatch;
    }
    if (control.required_native_receipt and !receipt_value.execution.native_receipt) return error.ReceiptSelectionMismatch;
    if (control.command_digest.len != 0 and !std.mem.eql(u8, receipt_value.execution.command_digest, control.command_digest)) return error.ReceiptSelectionMismatch;
    if (control.manifest_digest.len != 0 and !std.mem.eql(u8, receipt_value.execution.manifest_digest, control.manifest_digest)) return error.ReceiptSelectionMismatch;
    if (!std.mem.eql(u32, receipt_value.schedule_choices, control.schedule_choices)) return error.ReceiptSelectionMismatch;
}

fn writeAtomicFile(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, path: []const u8, content: []const u8) !void {
    if (std.mem.lastIndexOfScalar(u8, path, '/')) |slash| try dir.createDirPath(io, path[0..slash]);
    const temporary = try std.fmt.allocPrint(allocator, "{s}.tmp", .{path});
    defer allocator.free(temporary);
    dir.writeFile(io, .{ .sub_path = temporary, .data = content }) catch |err| {
        dir.deleteFile(io, temporary) catch {};
        return err;
    };
    dir.rename(temporary, dir, path, io) catch |err| {
        dir.deleteFile(io, temporary) catch {};
        return err;
    };
}

fn validateIdentifier(value: []const u8) !void {
    if (value.len == 0 or value.len > 128) return error.InvalidIdentifier;
    for (value) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.') continue;
        return error.InvalidIdentifier;
    }
}

fn scenario() Contract.Scenario {
    return .{
        .id = "receipt-protocol",
        .label = "process receipts are validated",
        .requirement = "req-testing-v2",
        .acceptance_check = "check-receipts",
        .component = "std-testing",
        .command = "test",
        .default_seed = 42,
    };
}

fn receipt() Contract.TestReceipt {
    return .{
        .project = "demo",
        .suite = "acceptance",
        .scenario = scenario(),
        .source_revision = "sha256:abc",
        .zig_version = @import("builtin").zig_version_string,
        .status = .passed,
        .started_ms = 10,
        .ended_ms = 20,
        .seed = 42,
        .executor = "deterministic",
        .execution = .{ .native_receipt = true },
        .assertions = &.{.{
            .id = "published",
            .label = "receipt published",
            .status = .passed,
        }},
    };
}

test "control round trips and matches only the selected scenario" {
    const value = Control{
        .scenario = scenario(),
        .project = "demo",
        .seed = 42,
        .fault_kind = .timeout,
        .fault_index = 3,
        .schedule_choices = &.{ 1, 0, 2 },
        .executor = "deterministic",
        .source_revision = "sha256:abc",
        .command_digest = "sha256:def",
    };
    const json = try value.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    var parsed = try parseControl(std.testing.allocator, json);
    defer parsed.deinit();
    try std.testing.expect(parsed.value.matches(scenario()));
    var different = scenario();
    different.id = "other";
    try std.testing.expect(!parsed.value.matches(different));
}

test "control and process receipts use fixed atomic project paths" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const control = Control{ .scenario = scenario(), .project = "demo", .seed = 42, .source_revision = "sha256:abc" };
    try writeControl(std.testing.allocator, std.testing.io, tmp.dir, control);
    var parsed_control = try readControl(std.testing.allocator, std.testing.io, tmp.dir);
    defer parsed_control.deinit();
    try std.testing.expectEqualStrings("receipt-protocol", parsed_control.value.scenario.id);

    try publishReceipt(std.testing.allocator, std.testing.io, tmp.dir, receipt());
    var parsed_receipt = try readPublishedReceipt(std.testing.allocator, std.testing.io, tmp.dir, "receipt-protocol");
    defer parsed_receipt.deinit();
    try std.testing.expectEqual(Contract.TestStatus.passed, parsed_receipt.value.verdict());
    try validatePublishedReceipt(parsed_receipt.value, control);

    try removePublishedReceipt(std.testing.io, tmp.dir, "receipt-protocol");
    try std.testing.expectError(error.FileNotFound, readPublishedReceipt(std.testing.allocator, std.testing.io, tmp.dir, "receipt-protocol"));
}

test "receipt validation rejects stale selection metadata" {
    const control = Control{ .scenario = scenario(), .project = "demo", .seed = 42, .executor = "deterministic" };
    var stale = receipt();
    stale.seed = 9;
    try std.testing.expectError(error.ReceiptSelectionMismatch, validatePublishedReceipt(stale, control));
}

test "protocol paths reject traversal and secrets" {
    try std.testing.expectError(error.InvalidIdentifier, publishedReceiptPathAlloc(std.testing.allocator, "../escape"));
    var control = Control{ .scenario = scenario(), .project = "demo", .seed = 42, .source_revision = "sentinel-secret-for-tests" };
    try std.testing.expectError(error.SecretDetected, control.validate());
}
