const std = @import("std");
const Contract = @import("contract.zig");

pub const control_schema = "zigeffect.test-control.v2";
pub const control_schema_version: u32 = 2;
pub const control_root = ".zigeffect/tests/controls";
pub const control_path_environment = "ZIGEFFECT_TEST_CONTROL";
pub const process_receipt_root = ".zigeffect/tests/process-receipts";
pub const process_run_receipt_root = ".zigeffect/tests/process-runs";
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
    process_receipt_path: []const u8 = "",
    required_native_receipt: bool = true,

    pub fn validate(self: Control) !void {
        if (!std.mem.eql(u8, self.schema, control_schema) or self.schema_version != control_schema_version) return error.UnsupportedControlSchema;
        try self.scenario.validate();
        try validateIdentifier(self.project);
        if (self.seed == 0) return error.InvalidControl;
        try validateIdentifier(self.executor);
        if (self.source_revision.len == 0 or self.source_revision.len > 4096) return error.InvalidControl;
        if (self.command_digest.len > 256 or self.manifest_digest.len > 256) return error.InvalidControl;
        if (self.process_receipt_path.len > 0) try validateArtifactPath(self.process_receipt_path, process_run_receipt_root);
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
    const path = try controlPathAlloc(allocator, control.scenario.id);
    defer allocator.free(path);
    try writeControlAt(allocator, io, dir, path, control);
}

pub fn writeControlAt(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, path: []const u8, control: Control) !void {
    try validateArtifactPath(path, control_root);
    const json = try control.jsonAlloc(allocator);
    defer allocator.free(json);
    try writeAtomicFile(allocator, io, dir, path, json);
}

pub fn readControl(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, scenario_id: []const u8) !ParsedControl {
    const path = try controlPathAlloc(allocator, scenario_id);
    defer allocator.free(path);
    return readControlAt(allocator, io, dir, path);
}

pub fn readControlAt(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, path: []const u8) !ParsedControl {
    try validateArtifactPath(path, control_root);
    const json = try dir.readFileAlloc(io, path, allocator, .limited(1024 * 1024));
    defer allocator.free(json);
    return parseControl(allocator, json);
}

pub fn removeControl(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, scenario_id: []const u8) !void {
    const path = try controlPathAlloc(allocator, scenario_id);
    defer allocator.free(path);
    try removeControlAt(io, dir, path);
}

pub fn removeControlAt(io: std.Io, dir: std.Io.Dir, path: []const u8) !void {
    try validateArtifactPath(path, control_root);
    dir.deleteFile(io, path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
}

pub fn controlPathAlloc(allocator: std.mem.Allocator, scenario_id: []const u8) ![]u8 {
    try validateIdentifier(scenario_id);
    return std.fmt.allocPrint(allocator, "{s}/{s}.json", .{ control_root, scenario_id });
}

pub fn controlRunPathAlloc(allocator: std.mem.Allocator, scenario_id: []const u8, run_id: []const u8) ![]u8 {
    try validateIdentifier(scenario_id);
    try validateIdentifier(run_id);
    return std.fmt.allocPrint(allocator, "{s}/{s}-{s}.json", .{ control_root, scenario_id, run_id });
}

pub fn processRunReceiptPathAlloc(allocator: std.mem.Allocator, scenario_id: []const u8, run_id: []const u8) ![]u8 {
    try validateIdentifier(scenario_id);
    try validateIdentifier(run_id);
    return std.fmt.allocPrint(allocator, "{s}/{s}-{s}.json", .{ process_run_receipt_root, scenario_id, run_id });
}

pub fn publishedReceiptPathAlloc(allocator: std.mem.Allocator, scenario_id: []const u8) ![]u8 {
    try validateIdentifier(scenario_id);
    return std.fmt.allocPrint(allocator, "{s}/{s}.json", .{ process_receipt_root, scenario_id });
}

pub fn rawReceiptPathAlloc(allocator: std.mem.Allocator, scenario_id: []const u8) ![]u8 {
    try validateIdentifier(scenario_id);
    return std.fmt.allocPrint(allocator, "{s}/{s}.json", .{ raw_receipt_root, scenario_id });
}

pub const evidence_root = ".zigeffect/evidence";

/// Write the committable proof for a requirement.
///
/// Keyed by requirement and replaced in place, so the file count is the number
/// of requirements rather than the number of runs, and a re-run of unchanged
/// code produces a byte-identical file.
pub fn publishRequirementEvidence(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    receipt_value: Contract.TestReceipt,
) !void {
    if (receipt_value.scenario.requirement.len == 0) return;
    const json = try Contract.requirementEvidenceJsonAlloc(allocator, receipt_value);
    defer allocator.free(json);
    if (Secrets.containsSecret(json)) return error.SecretDetected;
    // Keyed by requirement *and* scenario: several scenarios can prove one
    // requirement, and keying by requirement alone would let whichever ran last
    // overwrite the others' evidence.
    const path = try std.fmt.allocPrint(allocator, "{s}/{s}.{s}.json", .{
        evidence_root,
        receipt_value.scenario.requirement,
        receipt_value.scenario.id,
    });
    defer allocator.free(path);
    try writeAtomicFile(allocator, io, dir, path, json);
}

pub fn publishReceipt(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, receipt_value: Contract.TestReceipt) !void {
    const json = try receipt_value.jsonAlloc(allocator);
    defer allocator.free(json);
    if (Secrets.containsSecret(json)) return error.SecretDetected;
    const path = try publishedReceiptPathAlloc(allocator, receipt_value.scenario.id);
    defer allocator.free(path);
    try writeAtomicFile(allocator, io, dir, path, json);
}

pub fn publishReceiptAt(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, path: []const u8, receipt_value: Contract.TestReceipt) !void {
    try validateArtifactPath(path, process_run_receipt_root);
    const json = try receipt_value.jsonAlloc(allocator);
    defer allocator.free(json);
    if (Secrets.containsSecret(json)) return error.SecretDetected;
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

pub fn readPublishedReceiptAt(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, path: []const u8) !Contract.ParsedReceipt {
    try validateArtifactPath(path, process_run_receipt_root);
    const json = try dir.readFileAlloc(io, path, allocator, .limited(16 * 1024 * 1024));
    defer allocator.free(json);
    if (Secrets.containsSecret(json)) return error.SecretDetected;
    return Contract.parseReceipt(allocator, json);
}

pub fn removePublishedReceiptAt(io: std.Io, dir: std.Io.Dir, path: []const u8) !void {
    try validateArtifactPath(path, process_run_receipt_root);
    dir.deleteFile(io, path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
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
    for (0..1024) |slot| {
        if (try writeAtomicSlot(allocator, io, dir, path, content, slot)) return;
    }
    return error.AtomicTemporaryPathExhausted;
}

fn writeAtomicSlot(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    path: []const u8,
    content: []const u8,
    slot: usize,
) !bool {
    const temporary = try std.fmt.allocPrint(allocator, "{s}.tmp.{d}", .{ path, slot });
    defer allocator.free(temporary);
    const file = dir.createFile(io, temporary, .{ .exclusive = true }) catch |err| switch (err) {
        error.PathAlreadyExists => return false,
        else => return err,
    };
    var file_open = true;
    defer if (file_open) file.close(io);
    defer dir.deleteFile(io, temporary) catch {};
    try file.writeStreamingAll(io, content);
    file.close(io);
    file_open = false;
    dir.rename(temporary, dir, path, io) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };
    return true;
}

fn validateIdentifier(value: []const u8) !void {
    if (value.len == 0 or value.len > 128) return error.InvalidIdentifier;
    for (value) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.') continue;
        return error.InvalidIdentifier;
    }
}

fn validateArtifactPath(path: []const u8, root: []const u8) !void {
    if (path.len <= root.len + 6 or path.len > 1024 or !std.mem.startsWith(u8, path, root) or path[root.len] != '/' or
        std.mem.indexOfScalar(u8, path[root.len + 1 ..], '/') != null or !std.mem.endsWith(u8, path, ".json"))
    {
        return error.InvalidIdentifier;
    }
    try validateIdentifier(path[root.len + 1 .. path.len - ".json".len]);
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

test "control and process receipts use scenario-scoped atomic project paths" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const control = Control{ .scenario = scenario(), .project = "demo", .seed = 42, .source_revision = "sha256:abc" };
    try writeControl(std.testing.allocator, std.testing.io, tmp.dir, control);
    var parsed_control = try readControl(std.testing.allocator, std.testing.io, tmp.dir, "receipt-protocol");
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

test "run-scoped controls and process receipts remain isolated" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const first_control = try controlRunPathAlloc(std.testing.allocator, "receipt-protocol", "run-one");
    defer std.testing.allocator.free(first_control);
    const second_control = try controlRunPathAlloc(std.testing.allocator, "receipt-protocol", "run-two");
    defer std.testing.allocator.free(second_control);
    const first_receipt = try processRunReceiptPathAlloc(std.testing.allocator, "receipt-protocol", "run-one");
    defer std.testing.allocator.free(first_receipt);
    const second_receipt = try processRunReceiptPathAlloc(std.testing.allocator, "receipt-protocol", "run-two");
    defer std.testing.allocator.free(second_receipt);
    var first = receipt();
    first.seed = 41;
    var second = receipt();
    second.seed = 42;
    try writeControlAt(std.testing.allocator, std.testing.io, tmp.dir, first_control, .{
        .scenario = scenario(),
        .project = "demo",
        .seed = 41,
        .process_receipt_path = first_receipt,
    });
    try writeControlAt(std.testing.allocator, std.testing.io, tmp.dir, second_control, .{
        .scenario = scenario(),
        .project = "demo",
        .seed = 42,
        .process_receipt_path = second_receipt,
    });
    try publishReceiptAt(std.testing.allocator, std.testing.io, tmp.dir, first_receipt, first);
    try publishReceiptAt(std.testing.allocator, std.testing.io, tmp.dir, second_receipt, second);
    var parsed_first = try readPublishedReceiptAt(std.testing.allocator, std.testing.io, tmp.dir, first_receipt);
    defer parsed_first.deinit();
    var parsed_second = try readPublishedReceiptAt(std.testing.allocator, std.testing.io, tmp.dir, second_receipt);
    defer parsed_second.deinit();
    try std.testing.expectEqual(@as(u64, 41), parsed_first.value.seed);
    try std.testing.expectEqual(@as(u64, 42), parsed_second.value.seed);
}

test "atomic receipt publication advances past an occupied temporary slot" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const raw_path = try rawReceiptPathAlloc(std.testing.allocator, "receipt-protocol");
    defer std.testing.allocator.free(raw_path);
    const occupied_temporary = try std.fmt.allocPrint(std.testing.allocator, "{s}.tmp.0", .{raw_path});
    defer std.testing.allocator.free(occupied_temporary);
    if (std.mem.lastIndexOfScalar(u8, occupied_temporary, '/')) |slash| try tmp.dir.createDirPath(std.testing.io, occupied_temporary[0..slash]);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = occupied_temporary, .data = "occupied-by-another-writer" });

    try publishRawReceipt(std.testing.allocator, std.testing.io, tmp.dir, receipt());
    var published = try readRawReceipt(std.testing.allocator, std.testing.io, tmp.dir, "receipt-protocol");
    defer published.deinit();
    try std.testing.expectEqual(Contract.TestStatus.passed, published.value.verdict());
    const occupied = try tmp.dir.readFileAlloc(std.testing.io, occupied_temporary, std.testing.allocator, .limited(64));
    defer std.testing.allocator.free(occupied);
    try std.testing.expectEqualStrings("occupied-by-another-writer", occupied);
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
