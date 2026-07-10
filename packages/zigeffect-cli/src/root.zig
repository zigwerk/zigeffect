const std = @import("std");
pub const zstd = @import("zigeffect_std");
const templates = @import("templates.zig");
pub const safety = @import("safety_command.zig");

pub const version = "0.1.0";

pub const CliError = error{
    MissingCommand,
    MissingScaffoldKind,
    MissingProjectName,
    UnknownCommand,
    UnknownScaffoldKind,
    UnknownOption,
    DuplicateOption,
    MissingOptionValue,
    InvalidTarget,
};

pub const ScaffoldOptions = struct {
    kind: zstd.Project.ProjectKind,
    name: []const u8,
    target: []const u8,
    zigeffect_path: []const u8 = "../zigeffect",
    zigeffect_std_path: []const u8 = "../zigeffect-std",
    dry_run: bool = false,
    json: bool = false,
    force: bool = false,
};

pub const Action = union(enum) {
    help,
    version,
    new: ScaffoldOptions,
    project: ProjectOptions,
    safety: SafetyOptions,
    agent: AgentOptions,
    benchmark: BenchmarkOptions,
    add: AddOptions,
    generate: GenerateOptions,
};

pub const ProjectOperation = enum { show, validate, doctor, check, @"test", dev };
pub const ProjectOptions = struct {
    operation: ProjectOperation,
    root: []const u8 = ".",
    json: bool = false,
    agent: bool = false,
};
pub const SafetyOperation = enum { explain, replay, baseline };
pub const SafetyOptions = struct {
    operation: SafetyOperation,
    finding_id: []const u8 = "",
    receipt: []const u8 = ".zigeffect/receipts/latest-safety.json",
    root: []const u8 = ".",
};
pub const AgentOperation = enum { status, requirements, checks, evidence, next, handoff };
pub const AgentOptions = struct {
    operation: AgentOperation,
    root: []const u8 = ".",
    provider: []const u8 = "local",
    session: []const u8 = "local-session",
    jsonl: bool = false,
};
pub const BenchmarkOperation = enum { score, run };
pub const BenchmarkOptions = struct {
    operation: BenchmarkOperation,
    fixture: []const u8 = "",
    provider: []const u8 = "",
    command: []const u8 = "",
    root: []const u8 = ".",
};
pub const AddKind = enum { service, library, package };
pub const AddOptions = struct {
    kind: AddKind,
    name: []const u8,
    root: []const u8 = ".",
    dry_run: bool = false,
    json: bool = false,
    force: bool = false,
};
pub const GenerateKind = enum { service, layer, schema, cli, http, sql, @"test" };
pub const GenerateOptions = struct {
    kind: GenerateKind,
    name: []const u8,
    component: []const u8,
    root: []const u8 = ".",
    dry_run: bool = false,
    json: bool = false,
    force: bool = false,
};

pub fn parseArgs(args: []const []const u8) (CliError || zstd.Project.ProjectError)!Action {
    if (args.len == 0) return error.MissingCommand;
    if (args.len == 1 and (eql(args[0], "--help") or eql(args[0], "help"))) return .help;
    if (args.len == 1 and (eql(args[0], "--version") or eql(args[0], "version"))) return .version;
    if (eql(args[0], "project")) return .{ .project = try parseProjectArgs(args[1..]) };
    if (eql(args[0], "safety")) return .{ .safety = try parseSafetyArgs(args[1..]) };
    if (eql(args[0], "agent")) return .{ .agent = try parseAgentArgs(args[1..]) };
    if (eql(args[0], "benchmark")) return .{ .benchmark = try parseBenchmarkArgs(args[1..]) };
    if (eql(args[0], "add")) return .{ .add = try parseAddArgs(args[1..]) };
    if (eql(args[0], "generate")) return .{ .generate = try parseGenerateArgs(args[1..]) };
    if (!eql(args[0], "new")) return error.UnknownCommand;
    if (args.len < 2) return error.MissingScaffoldKind;
    if (args.len < 3) return error.MissingProjectName;

    const kind = parseKind(args[1]) orelse return error.UnknownScaffoldKind;
    try zstd.Project.validateIdentifier(args[2]);

    var options = ScaffoldOptions{
        .kind = kind,
        .name = args[2],
        .target = args[2],
    };
    var target_set = false;
    var zigeffect_set = false;
    var std_set = false;
    var index: usize = 3;
    while (index < args.len) {
        const token = args[index];
        if (eql(token, "--dry-run")) {
            if (options.dry_run) return error.DuplicateOption;
            options.dry_run = true;
            index += 1;
        } else if (eql(token, "--json")) {
            if (options.json) return error.DuplicateOption;
            options.json = true;
            index += 1;
        } else if (eql(token, "--force")) {
            if (options.force) return error.DuplicateOption;
            options.force = true;
            index += 1;
        } else if (eql(token, "--target")) {
            if (target_set) return error.DuplicateOption;
            options.target = try optionValue(args, &index);
            target_set = true;
        } else if (eql(token, "--zigeffect-path")) {
            if (zigeffect_set) return error.DuplicateOption;
            options.zigeffect_path = try optionValue(args, &index);
            zigeffect_set = true;
        } else if (eql(token, "--zigeffect-std-path")) {
            if (std_set) return error.DuplicateOption;
            options.zigeffect_std_path = try optionValue(args, &index);
            std_set = true;
        } else {
            return error.UnknownOption;
        }
    }

    try validateTarget(options.target);
    try zstd.Project.validateDependencyPath(options.zigeffect_path);
    try zstd.Project.validateDependencyPath(options.zigeffect_std_path);
    return .{ .new = options };
}

pub fn generatePlan(allocator: std.mem.Allocator, options: ScaffoldOptions) !zstd.Project.FilePlan {
    try zstd.Project.validateIdentifier(options.name);
    try validateTarget(options.target);
    try zstd.Project.validateDependencyPath(options.zigeffect_path);
    try zstd.Project.validateDependencyPath(options.zigeffect_std_path);

    var plan = zstd.Project.FilePlan.init(allocator);
    errdefer plan.deinit();

    switch (options.kind) {
        .application, .service => try addExecutableProject(&plan, options, "", false),
        .library => try addLibraryProject(&plan, options, "", "library", false),
        .package => try addLibraryProject(&plan, options, "", "library", true),
        .system => try addSystemProject(&plan, options),
    }
    try addRootCommon(&plan, options);
    try addManifest(&plan, options);
    try plan.sort();
    return plan;
}

pub const WriteOptions = struct {
    dry_run: bool = false,
    force: bool = false,
};

pub const WriteResult = struct {
    planned: usize,
    written: usize,
    replaced: usize,
};

pub const RunResult = struct {
    allocator: std.mem.Allocator,
    exit_code: u8,
    output: []u8,

    pub fn deinit(self: *RunResult) void {
        self.allocator.free(self.output);
        self.* = undefined;
    }
};

pub fn runAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    args: []const []const u8,
) !RunResult {
    const action = try parseArgs(args);
    switch (action) {
        .help => return .{ .allocator = allocator, .exit_code = 0, .output = try allocator.dupe(u8, helpText()) },
        .version => return .{ .allocator = allocator, .exit_code = 0, .output = try std.fmt.allocPrint(allocator, "zigeffect {s}\n", .{version}) },
        .project => |options| return runProjectAlloc(allocator, io, base_dir, options),
        .safety => |options| return runSafetyAlloc(allocator, io, base_dir, options),
        .agent => |options| return runAgentAlloc(allocator, io, base_dir, options),
        .benchmark => |options| return runBenchmarkAlloc(allocator, io, base_dir, options),
        .add => |options| return runAddAlloc(allocator, io, base_dir, options),
        .generate => |options| return runGenerateAlloc(allocator, io, base_dir, options),
        .new => |options| {
            var plan = try generatePlan(allocator, options);
            defer plan.deinit();
            const write_result = writePlan(io, base_dir, options.target, plan, .{
                .dry_run = options.dry_run,
                .force = options.force,
            }) catch |err| {
                const output = try formatScaffoldOutput(allocator, options, plan, .refused, 0, 0, @errorName(err));
                return .{ .allocator = allocator, .exit_code = if (err == error.TargetNotEmpty) 3 else 1, .output = output };
            };
            const status: zstd.Project.ScaffoldStatus = if (options.dry_run) .planned else .created;
            const output = try formatScaffoldOutput(
                allocator,
                options,
                plan,
                status,
                write_result.written,
                write_result.replaced,
                if (options.dry_run) "dry run" else "scaffold written",
            );
            return .{ .allocator = allocator, .exit_code = 0, .output = output };
        },
    }
}

pub fn writePlan(
    io: std.Io,
    base_dir: std.Io.Dir,
    target: []const u8,
    plan: zstd.Project.FilePlan,
    options: WriteOptions,
) !WriteResult {
    try validateTarget(target);
    if (options.dry_run) return .{ .planned = plan.files.items.len, .written = 0, .replaced = 0 };

    var target_dir = openTargetDir(io, base_dir, target) catch |err| switch (err) {
        error.FileNotFound => create: {
            if (std.fs.path.isAbsolute(target)) {
                try std.Io.Dir.cwd().createDirPath(io, target);
            } else {
                try base_dir.createDirPath(io, target);
            }
            break :create try openTargetDir(io, base_dir, target);
        },
        else => return err,
    };
    defer target_dir.close(io);

    if (!options.force) {
        var iterator = target_dir.iterate();
        if (try iterator.next(io) != null) return error.TargetNotEmpty;
    }

    var replaced: usize = 0;
    for (plan.files.items) |generated| {
        if (target_dir.access(io, generated.path, .{})) |_| {
            replaced += 1;
        } else |err| switch (err) {
            error.FileNotFound => {},
            else => return err,
        }

        if (std.mem.lastIndexOfScalar(u8, generated.path, '/')) |slash| {
            try target_dir.createDirPath(io, generated.path[0..slash]);
        }
        const temporary = try std.fmt.allocPrint(plan.allocator, "{s}.zigeffect-tmp", .{generated.path});
        defer plan.allocator.free(temporary);
        target_dir.writeFile(io, .{ .sub_path = temporary, .data = generated.content }) catch |err| {
            target_dir.deleteFile(io, temporary) catch {};
            return err;
        };
        target_dir.rename(temporary, target_dir, generated.path, io) catch |err| {
            target_dir.deleteFile(io, temporary) catch {};
            return err;
        };
    }
    return .{ .planned = plan.files.items.len, .written = plan.files.items.len, .replaced = replaced };
}

fn runProjectAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    options: ProjectOptions,
) !RunResult {
    var project_dir = try openTargetDir(io, base_dir, options.root);
    defer project_dir.close(io);
    if (options.operation == .check and options.agent) {
        const result = try safety.runProjectCheckAlloc(allocator, io, project_dir, .{});
        return safetyResult(result);
    }
    const manifest_text = try project_dir.readFileAlloc(io, "zigeffect.project.json", allocator, .limited(4 * 1024 * 1024));
    defer allocator.free(manifest_text);
    var parsed = try zstd.Project.parseManifest(allocator, manifest_text);
    defer parsed.deinit();

    if (options.operation == .show) {
        const canonical = try parsed.value.jsonAlloc(allocator);
        return .{ .allocator = allocator, .exit_code = 0, .output = canonical };
    }
    if (options.operation == .validate) {
        const output = try projectReceiptAlloc(allocator, options, parsed.value, "validate", "passed", 0, "manifest valid", "", "");
        return .{ .allocator = allocator, .exit_code = 0, .output = output };
    }
    if (options.operation == .doctor) {
        var missing: usize = 0;
        for (parsed.value.components) |component| {
            project_dir.access(io, component.path, .{}) catch |err| switch (err) {
                error.FileNotFound => missing += 1,
                else => return err,
            };
        }
        const status = if (missing == 0) "passed" else "failed";
        const detail = try std.fmt.allocPrint(allocator, "components={d} missing={d}", .{ parsed.value.components.len, missing });
        defer allocator.free(detail);
        const output = try projectReceiptAlloc(allocator, options, parsed.value, "doctor", status, missing, detail, "", "");
        return .{ .allocator = allocator, .exit_code = if (missing == 0) 0 else 1, .output = output };
    }

    const command_id = switch (options.operation) {
        .check => "check",
        .@"test" => "test",
        .dev => "dev",
        else => unreachable,
    };
    const command = parsed.value.command(command_id) orelse return error.MissingProjectCommand;
    const process_result = try std.process.run(allocator, io, .{
        .argv = command.argv,
        .cwd = .{ .path = options.root },
        .stdout_limit = .limited(1024 * 1024),
        .stderr_limit = .limited(1024 * 1024),
    });
    defer allocator.free(process_result.stdout);
    defer allocator.free(process_result.stderr);
    const exit_code = processExitCode(process_result.term);
    const status = if (exit_code == 0) "passed" else "failed";
    const receipt_options = ProjectOptions{ .operation = options.operation, .root = options.root, .json = true };
    const receipt_json = try projectReceiptAlloc(
        allocator,
        receipt_options,
        parsed.value,
        command_id,
        status,
        exit_code,
        if (exit_code == 0) "manifest-owned command passed" else "manifest-owned command failed",
        process_result.stdout,
        process_result.stderr,
    );
    errdefer allocator.free(receipt_json);
    try persistProjectCommandReceipt(allocator, io, base_dir, options.root, command_id, parsed.value.name, receipt_json, options.operation == .dev);
    const output = if (options.json)
        receipt_json
    else output: {
        defer allocator.free(receipt_json);
        break :output try projectReceiptAlloc(
            allocator,
            options,
            parsed.value,
            command_id,
            status,
            exit_code,
            if (exit_code == 0) "manifest-owned command passed" else "manifest-owned command failed",
            process_result.stdout,
            process_result.stderr,
        );
    };
    return .{ .allocator = allocator, .exit_code = if (exit_code == 0) 0 else 1, .output = output };
}

fn runSafetyAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    options: SafetyOptions,
) !RunResult {
    if (options.operation == .replay) {
        return safetyResult(try safety.runSafetyReplayAlloc(allocator, options.receipt, options.finding_id));
    }
    var project_dir = try openTargetDir(io, base_dir, options.root);
    defer project_dir.close(io);
    return safetyResult(switch (options.operation) {
        .explain => try safety.runSafetyExplainAlloc(allocator, io, project_dir, "zigeffect.project.json", options.finding_id),
        .baseline => try safety.runSafetyBaselineAlloc(allocator, io, project_dir, options.receipt),
        .replay => unreachable,
    });
}

fn runAgentAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    options: AgentOptions,
) !RunResult {
    var project_dir = try openTargetDir(io, base_dir, options.root);
    defer project_dir.close(io);
    const manifest_text = try project_dir.readFileAlloc(io, "zigeffect.project.json", allocator, .limited(4 * 1024 * 1024));
    defer allocator.free(manifest_text);
    var parsed = try zstd.Project.parseManifest(allocator, manifest_text);
    defer parsed.deinit();
    var derived = try deriveAgentProtocol(allocator, io, project_dir, parsed.value);
    defer derived.deinit();

    const output = switch (options.operation) {
        .status => try derived.status.jsonAlloc(allocator),
        .requirements => try encodeRequirementQueryAlloc(allocator, parsed.value.requirements, options.jsonl),
        .checks => try encodeAcceptanceQueryAlloc(allocator, parsed.value.acceptance_checks, options.jsonl),
        .evidence => try encodeCollectionAlloc(allocator, "zigeffect.evidence-query.v1", derived.evidence, options.jsonl),
        .next => try encodeCollectionAlloc(allocator, "zigeffect.next-action-query.v1", derived.actions, options.jsonl),
        .handoff => handoff: {
            const handoff = zstd.Project.Protocol.AgentHandoff{
                .project = parsed.value.name,
                .provider = options.provider,
                .session = options.session,
                .summary = if (derived.status.requirements_open == 0 and derived.status.checks_failed == 0) "project requirements satisfied" else "project work remains",
                .tasks = derived.tasks,
                .evidence = derived.evidence,
                .next_actions = derived.actions,
                .blockers = derived.blockers,
            };
            const json = try handoff.jsonAlloc(allocator);
            errdefer allocator.free(json);
            var plan = zstd.Project.FilePlan.init(allocator);
            defer plan.deinit();
            try plan.add(".zigeffect/handoffs/latest.json", json);
            _ = try writePlan(io, base_dir, options.root, plan, .{ .force = true });
            break :handoff json;
        },
    };
    return .{ .allocator = allocator, .exit_code = 0, .output = output };
}

const DerivedProtocol = struct {
    allocator: std.mem.Allocator,
    status: zstd.Project.Protocol.ProjectStatus,
    tasks: []zstd.Project.Protocol.Task,
    evidence: []zstd.Project.Protocol.Evidence,
    actions: []zstd.Project.Protocol.NextAction,
    blockers: [][]const u8,
    owned_ids: std.ArrayList([]u8) = .empty,
    tasks_owned: bool = false,
    evidence_owned: bool = false,
    actions_owned: bool = false,
    blockers_owned: bool = false,

    fn deinit(self: *DerivedProtocol) void {
        for (self.owned_ids.items) |id| self.allocator.free(id);
        self.owned_ids.deinit(self.allocator);
        if (self.tasks_owned) self.allocator.free(self.tasks);
        if (self.evidence_owned) self.allocator.free(self.evidence);
        if (self.actions_owned) self.allocator.free(self.actions);
        if (self.blockers_owned) self.allocator.free(self.blockers);
        self.* = undefined;
    }

    fn deinitPartial(self: *DerivedProtocol) void {
        self.deinit();
    }
};

fn deriveAgentProtocol(
    allocator: std.mem.Allocator,
    io: std.Io,
    project_dir: std.Io.Dir,
    manifest: zstd.Project.Manifest,
) !DerivedProtocol {
    var result = DerivedProtocol{
        .allocator = allocator,
        .status = undefined,
        .tasks = undefined,
        .evidence = undefined,
        .actions = undefined,
        .blockers = undefined,
    };
    errdefer result.deinitPartial();
    var open_requirements: usize = 0;
    var blocked_requirements: usize = 0;
    for (manifest.requirements) |requirement| {
        if (requirement.status != .satisfied) open_requirements += 1;
        if (requirement.status == .blocked) blocked_requirements += 1;
    }
    result.tasks = try allocator.alloc(zstd.Project.Protocol.Task, open_requirements);
    result.tasks_owned = true;
    result.actions = try allocator.alloc(zstd.Project.Protocol.NextAction, open_requirements);
    result.actions_owned = true;
    result.blockers = try allocator.alloc([]const u8, blocked_requirements);
    result.blockers_owned = true;
    var task_index: usize = 0;
    var blocker_index: usize = 0;
    for (manifest.requirements) |requirement| {
        if (requirement.status == .satisfied) continue;
        const task_id = try std.fmt.allocPrint(allocator, "task-{s}", .{requirement.id});
        try result.owned_ids.append(allocator, task_id);
        const action_id = try std.fmt.allocPrint(allocator, "next-{s}", .{requirement.id});
        try result.owned_ids.append(allocator, action_id);
        result.tasks[task_index] = .{
            .id = task_id,
            .requirement = requirement.id,
            .component = requirement.component,
            .summary = requirement.summary,
            .status = switch (requirement.status) {
                .planned => .planned,
                .active => .active,
                .blocked => .blocked,
                .satisfied => unreachable,
            },
        };
        result.actions[task_index] = .{
            .id = action_id,
            .requirement = requirement.id,
            .component = requirement.component,
            .summary = requirement.summary,
            .command = if (manifest.command("check") != null) "check" else null,
        };
        task_index += 1;
        if (requirement.status == .blocked) {
            result.blockers[blocker_index] = requirement.summary;
            blocker_index += 1;
        }
    }

    const has_check_receipt = check: {
        project_dir.access(io, ".zigeffect/receipts/check.json", .{}) catch |err| switch (err) {
            error.FileNotFound => break :check false,
            else => return err,
        };
        break :check true;
    };
    const evidence_count: usize = if (has_check_receipt and manifest.requirements.len > 0) 1 else 0;
    result.evidence = try allocator.alloc(zstd.Project.Protocol.Evidence, evidence_count);
    result.evidence_owned = true;
    if (evidence_count == 1) {
        result.evidence[0] = .{
            .id = "evidence-project-check",
            .requirement = manifest.requirements[0].id,
            .component = manifest.requirements[0].component,
            .kind = .test_result,
            .artifact = ".zigeffect/receipts/check.json",
            .summary = "manifest-owned project check receipt",
        };
    }
    var pending: usize = 0;
    var failed: usize = 0;
    for (manifest.acceptance_checks) |check| switch (check.status) {
        .pending => pending += 1,
        .failed => failed += 1,
        else => {},
    };
    result.status = .{
        .project = manifest.name,
        .requirements_total = manifest.requirements.len,
        .requirements_open = open_requirements,
        .checks_total = manifest.acceptance_checks.len,
        .checks_pending = pending,
        .checks_failed = failed,
        .tasks = result.tasks,
        .evidence = result.evidence,
        .next_actions = result.actions,
    };
    try result.status.validate();
    return result;
}

fn encodeCollectionAlloc(allocator: std.mem.Allocator, schema: []const u8, items: anytype, jsonl: bool) ![]u8 {
    if (!jsonl) return std.json.Stringify.valueAlloc(allocator, .{ .schema = schema, .items = items }, .{});
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    for (items) |item| {
        const line = try std.json.Stringify.valueAlloc(allocator, .{ .schema = schema, .item = item }, .{});
        defer allocator.free(line);
        try output.appendSlice(allocator, line);
        try output.append(allocator, '\n');
    }
    return output.toOwnedSlice(allocator);
}

fn encodeRequirementQueryAlloc(
    allocator: std.mem.Allocator,
    requirements: []const zstd.Project.Requirement,
    jsonl: bool,
) ![]u8 {
    var unresolved = std.ArrayList(zstd.Project.Requirement).empty;
    defer unresolved.deinit(allocator);
    for (requirements) |requirement| {
        if (requirement.status != .satisfied) try unresolved.append(allocator, requirement);
    }
    return encodeCollectionAlloc(allocator, "zigeffect.requirement-query.v1", unresolved.items, jsonl);
}

fn encodeAcceptanceQueryAlloc(
    allocator: std.mem.Allocator,
    checks: []const zstd.Project.AcceptanceCheck,
    jsonl: bool,
) ![]u8 {
    var non_passing = std.ArrayList(zstd.Project.AcceptanceCheck).empty;
    defer non_passing.deinit(allocator);
    for (checks) |check| {
        if (check.status != .passed) try non_passing.append(allocator, check);
    }
    return encodeCollectionAlloc(allocator, "zigeffect.acceptance-query.v1", non_passing.items, jsonl);
}

fn safetyResult(result: safety.CommandOutput) RunResult {
    return .{ .allocator = result.allocator, .exit_code = result.exit_code, .output = result.output };
}

fn runBenchmarkAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    options: BenchmarkOptions,
) !RunResult {
    var project_dir = try openTargetDir(io, base_dir, options.root);
    defer project_dir.close(io);
    return safetyResult(switch (options.operation) {
        .score => try safety.runBenchmarkScoreAlloc(allocator, io, project_dir, options.fixture),
        .run => try safety.runProviderBenchmarkAlloc(allocator, io, project_dir, options.provider, options.command),
    });
}

fn persistProjectCommandReceipt(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    root: []const u8,
    command: []const u8,
    project: []const u8,
    receipt_json: []const u8,
    include_workbench: bool,
) !void {
    var plan = zstd.Project.FilePlan.init(allocator);
    defer plan.deinit();
    const receipt_path = try std.fmt.allocPrint(allocator, ".zigeffect/receipts/{s}.json", .{command});
    defer allocator.free(receipt_path);
    try plan.add(receipt_path, receipt_json);
    if (include_workbench) {
        const attachment = try std.json.Stringify.valueAlloc(allocator, .{
            .schema = "zigeffect.workbench-attachment.v1",
            .project = project,
            .session = ".zigeffect/receipts/dev.json",
            .live = "ws://127.0.0.1:4318",
        }, .{});
        defer allocator.free(attachment);
        try plan.add(".zigeffect/workbench.json", attachment);
    }
    try plan.sort();
    _ = try writePlan(io, base_dir, root, plan, .{ .force = true });
}

fn runAddAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    options: AddOptions,
) !RunResult {
    var project_dir = try openTargetDir(io, base_dir, options.root);
    defer project_dir.close(io);
    const manifest_text = try project_dir.readFileAlloc(io, "zigeffect.project.json", allocator, .limited(4 * 1024 * 1024));
    defer allocator.free(manifest_text);
    var parsed = try zstd.Project.parseManifest(allocator, manifest_text);
    defer parsed.deinit();
    if (parsed.value.kind != .system) return error.ComponentsRequireSystemProject;
    if (parsed.value.component(options.name) != null) return error.DuplicateComponent;

    const component_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ addDirectory(options.kind), options.name });
    defer allocator.free(component_path);
    for (parsed.value.components) |component| {
        if (std.mem.eql(u8, component.path, component_path)) return error.DuplicateComponentPath;
    }
    const capabilities = if (options.kind == .service)
        &[_]zstd.Project.Capability{ .cli, .http, .sql, .config, .observability, .agent, .workbench }
    else
        &[_]zstd.Project.Capability{ .config, .observability, .agent, .workbench };
    const components = try allocator.alloc(zstd.Project.Component, parsed.value.components.len + 1);
    defer allocator.free(components);
    @memcpy(components[0..parsed.value.components.len], parsed.value.components);
    components[components.len - 1] = .{
        .id = options.name,
        .kind = addComponentKind(options.kind),
        .path = component_path,
        .capabilities = capabilities,
    };
    var updated = parsed.value;
    updated.components = components;
    try updated.validate();

    const adjusted_core = try pathFromComponentAlloc(allocator, component_path, parsed.value.dependencies.zigeffect);
    defer allocator.free(adjusted_core);
    const adjusted_std = try pathFromComponentAlloc(allocator, component_path, parsed.value.dependencies.zigeffect_std);
    defer allocator.free(adjusted_std);
    var nested = try generatePlan(allocator, .{
        .kind = addProjectKind(options.kind),
        .name = options.name,
        .target = options.name,
        .zigeffect_path = adjusted_core,
        .zigeffect_std_path = adjusted_std,
    });
    defer nested.deinit();
    var plan = zstd.Project.FilePlan.init(allocator);
    defer plan.deinit();
    for (nested.files.items) |file| {
        if (skipNestedCommon(file.path)) continue;
        const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ component_path, file.path });
        defer allocator.free(path);
        try plan.add(path, file.content);
    }
    const updated_json = try updated.jsonAlloc(allocator);
    defer allocator.free(updated_json);
    try plan.add("zigeffect.project.json", updated_json);
    try plan.sort();

    if (!options.dry_run and !options.force) try preflightProjectPlan(io, project_dir, plan, true);
    const write_result = try writePlan(io, base_dir, options.root, plan, .{ .dry_run = options.dry_run, .force = true });
    const output = try mutationReceiptAlloc(allocator, options.json, "add", options.name, options.root, if (options.dry_run) "planned" else "created", write_result, plan);
    return .{ .allocator = allocator, .exit_code = 0, .output = output };
}

fn runGenerateAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    options: GenerateOptions,
) !RunResult {
    var project_dir = try openTargetDir(io, base_dir, options.root);
    defer project_dir.close(io);
    const manifest_text = try project_dir.readFileAlloc(io, "zigeffect.project.json", allocator, .limited(4 * 1024 * 1024));
    defer allocator.free(manifest_text);
    var parsed = try zstd.Project.parseManifest(allocator, manifest_text);
    defer parsed.deinit();
    const component = parsed.value.component(options.component) orelse return error.MissingComponent;
    const relative = try generatedModulePathAlloc(allocator, options);
    defer allocator.free(relative);
    const path = if (std.mem.eql(u8, component.path, "."))
        try allocator.dupe(u8, relative)
    else
        try std.fmt.allocPrint(allocator, "{s}/{s}", .{ component.path, relative });
    defer allocator.free(path);
    const source = try generatedModuleAlloc(allocator, options);
    defer allocator.free(source);
    var plan = zstd.Project.FilePlan.init(allocator);
    defer plan.deinit();
    try plan.add(path, source);
    try plan.sort();
    if (!options.dry_run and !options.force) try preflightProjectPlan(io, project_dir, plan, false);
    const write_result = try writePlan(io, base_dir, options.root, plan, .{ .dry_run = options.dry_run, .force = true });
    const output = try mutationReceiptAlloc(allocator, options.json, "generate", options.name, options.root, if (options.dry_run) "planned" else "created", write_result, plan);
    return .{ .allocator = allocator, .exit_code = 0, .output = output };
}

fn projectReceiptAlloc(
    allocator: std.mem.Allocator,
    options: ProjectOptions,
    manifest: zstd.Project.Manifest,
    command: []const u8,
    status: []const u8,
    code: usize,
    detail: []const u8,
    stdout: []const u8,
    stderr: []const u8,
) ![]u8 {
    const safe_detail = try zstd.Secrets.redactAlloc(allocator, detail);
    defer allocator.free(safe_detail);
    const safe_stdout = try zstd.Secrets.redactAlloc(allocator, stdout);
    defer allocator.free(safe_stdout);
    const safe_stderr = try zstd.Secrets.redactAlloc(allocator, stderr);
    defer allocator.free(safe_stderr);
    if (options.json) return std.json.Stringify.valueAlloc(allocator, .{
        .schema = "zigeffect.project-command-receipt.v1",
        .project = manifest.name,
        .command = command,
        .status = status,
        .code = code,
        .detail = safe_detail,
        .stdout = safe_stdout,
        .stderr = safe_stderr,
    }, .{});
    return std.fmt.allocPrint(allocator, "{s}: {s} ({s}, code={d})\n{s}\n{s}", .{ manifest.name, command, status, code, safe_stdout, safe_stderr });
}

fn mutationReceiptAlloc(
    allocator: std.mem.Allocator,
    json: bool,
    operation: []const u8,
    name: []const u8,
    root: []const u8,
    status: []const u8,
    result: WriteResult,
    plan: zstd.Project.FilePlan,
) ![]u8 {
    const paths = try allocator.alloc([]const u8, plan.files.items.len);
    defer allocator.free(paths);
    for (plan.files.items, 0..) |file, index| {
        paths[index] = file.path;
    }
    if (json) return std.json.Stringify.valueAlloc(allocator, .{
        .schema = "zigeffect.project-mutation-receipt.v1",
        .operation = operation,
        .name = name,
        .root = root,
        .status = status,
        .planned = result.planned,
        .written = result.written,
        .replaced = result.replaced,
        .paths = paths,
    }, .{});
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try output.print(allocator, "{s} {s}: {s}\n", .{ operation, name, status });
    for (paths) |path| try output.print(allocator, "- {s}\n", .{path});
    return output.toOwnedSlice(allocator);
}

fn preflightProjectPlan(io: std.Io, project_dir: std.Io.Dir, plan: zstd.Project.FilePlan, allow_manifest: bool) !void {
    for (plan.files.items) |file| {
        if (allow_manifest and std.mem.eql(u8, file.path, "zigeffect.project.json")) continue;
        project_dir.access(io, file.path, .{}) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        return error.GeneratedPathConflict;
    }
}

fn generatedModulePathAlloc(allocator: std.mem.Allocator, options: GenerateOptions) ![]u8 {
    return switch (options.kind) {
        .service => std.fmt.allocPrint(allocator, "src/services/{s}.zig", .{options.name}),
        .layer => std.fmt.allocPrint(allocator, "src/layers/{s}.zig", .{options.name}),
        .schema => std.fmt.allocPrint(allocator, "src/schema/{s}.zig", .{options.name}),
        .cli => std.fmt.allocPrint(allocator, "src/commands/{s}.zig", .{options.name}),
        .http => std.fmt.allocPrint(allocator, "src/http/{s}.zig", .{options.name}),
        .sql => std.fmt.allocPrint(allocator, "src/sql/{s}.zig", .{options.name}),
        .@"test" => std.fmt.allocPrint(allocator, "test/{s}_test.zig", .{options.name}),
    };
}

fn generatedModuleAlloc(allocator: std.mem.Allocator, options: GenerateOptions) ![]u8 {
    const body = switch (options.kind) {
        .service => "pub const Service = struct {};\n",
        .layer => "pub fn layer(value: anytype) @TypeOf(value.layer()) { return value.layer(); }\n",
        .schema => "const zstd = @import(\"zigeffect_std\");\npub const schema = zstd.Schema.string().nonEmpty();\n",
        .cli => "const zstd = @import(\"zigeffect_std\");\npub const command = zstd.Cli.CommandSpec{ .name = \"generated\", .description = \"generated command\" };\n",
        .http => "const zstd = @import(\"zigeffect_std\");\npub const health = zstd.Http.Request{ .method = \"GET\", .url = \"http://127.0.0.1/health\" };\n",
        .sql => "const zstd = @import(\"zigeffect_std\");\npub const query = zstd.Sql.Query{ .sql = \"select 1\", .binds = &.{} };\n",
        .@"test" => "const std = @import(\"std\");\ntest \"generated acceptance check\" { try std.testing.expect(true); }\n",
    };
    return std.fmt.allocPrint(allocator, "// Generated {s} module: {s}\n{s}", .{ @tagName(options.kind), options.name, body });
}

fn processExitCode(term: std.process.Child.Term) usize {
    return switch (term) {
        .exited => |code| code,
        else => 1,
    };
}

fn skipNestedCommon(path: []const u8) bool {
    return std.mem.eql(u8, path, "zigeffect.project.json") or
        std.mem.eql(u8, path, ".gitignore") or
        std.mem.startsWith(u8, path, ".agents/") or
        std.mem.startsWith(u8, path, ".claude/");
}

fn addDirectory(kind: AddKind) []const u8 {
    return switch (kind) {
        .service => "services",
        .library => "libraries",
        .package => "packages",
    };
}

fn addComponentKind(kind: AddKind) zstd.Project.ComponentKind {
    return switch (kind) {
        .service => .service,
        .library => .library,
        .package => .package,
    };
}

fn addProjectKind(kind: AddKind) zstd.Project.ProjectKind {
    return switch (kind) {
        .service => .service,
        .library => .library,
        .package => .package,
    };
}

fn openTargetDir(io: std.Io, base_dir: std.Io.Dir, target: []const u8) !std.Io.Dir {
    const options = std.Io.Dir.OpenOptions{ .iterate = true, .follow_symlinks = false };
    return if (std.fs.path.isAbsolute(target))
        std.Io.Dir.openDirAbsolute(io, target, options)
    else
        base_dir.openDir(io, target, options);
}

pub fn helpText() []const u8 {
    return
    \\zigeffect - local agent-first Zig application development
    \\
    \\Usage:
    \\  zigeffect --help
    \\  zigeffect --version
    \\  zigeffect new <application|service|library|package|system> <name> [options]
    \\  zigeffect add <service|library|package> <name> [options]
    \\  zigeffect generate <service|layer|schema|cli|http|sql|test> <name> --component <id> [options]
    \\  zigeffect project <show|validate|doctor|check|test|dev> [--root <path>] [--json]
    \\  zigeffect project check --agent --json [--root <path>]
    \\  zigeffect agent <status|requirements|checks|evidence|next> [--root <path>] [--jsonl]
    \\  zigeffect agent handoff --provider <name> --session <id> [--root <path>]
    \\  zigeffect safety explain <finding-id> [--root <path>]
    \\  zigeffect safety replay <finding-id> [--receipt <path>]
    \\  zigeffect safety baseline [--root <path>] [--receipt <path>]
    \\  zigeffect benchmark score <fixture> --json [--root <path>]
    \\  zigeffect benchmark run --provider <id> --command <manifest-id> [--root <path>]
    \\
    \\Options:
    \\  --target <path>               output directory (defaults to name)
    \\  --zigeffect-path <path>       manifest path to zigeffect
    \\  --zigeffect-std-path <path>   build and manifest path to zigeffect-std
    \\  --dry-run                     print the complete plan without writing
    \\  --json                        emit a stable JSON receipt
    \\  --force                       replace only files declared by the plan
    \\
    ;
}

fn addExecutableProject(
    plan: *zstd.Project.FilePlan,
    options: ScaffoldOptions,
    prefix: []const u8,
    with_shared: bool,
) !void {
    const allocator = plan.allocator;
    const package_name = if (prefix.len == 0)
        try zigIdentifierAlloc(allocator, options.name)
    else
        try prefixedPackageNameAlloc(allocator, options.name, prefix);
    defer allocator.free(package_name);
    const fingerprint = try fingerprintAlloc(allocator, package_name);
    defer allocator.free(fingerprint);
    const std_path = if (prefix.len == 0)
        try allocator.dupe(u8, options.zigeffect_std_path)
    else
        try pathFromComponentAlloc(allocator, prefix, options.zigeffect_std_path);
    defer allocator.free(std_path);
    const component_name = if (prefix.len == 0) options.name else componentNameFromPrefix(prefix);

    try addRenderedAt(plan, prefix, "build.zig", templates.executable_build, &.{
        .{ "__PROJECT_NAME__", component_name },
        .{ "__SHARED_DEPENDENCY__", if (with_shared) "    const shared = b.dependency(\"shared\", .{}).module(\"shared\");" else "" },
        .{ "__SHARED_IMPORT__", if (with_shared) "    app.addImport(\"shared\", shared);" else "" },
    });
    try addRenderedAt(plan, prefix, "build.zig.zon", templates.executable_zon, &.{
        .{ "__ZIG_NAME__", package_name },
        .{ "__FINGERPRINT__", fingerprint },
        .{ "__STD_PATH__", std_path },
        .{ "__SHARED_ZON_DEPENDENCY__", if (with_shared) "        .shared = .{ .path = \"../../packages/shared\" }," else "" },
    });
    try addRenderedAt(plan, prefix, "src/main.zig", templates.main_source, &.{});
    try addRenderedAt(plan, prefix, "src/app.zig", templates.app_source, &.{
        .{ "__PROJECT_NAME__", component_name },
        .{ "__SHARED_SOURCE_IMPORT__", if (with_shared) "const shared = @import(\"shared\");" else "" },
        .{ "__SHARED_SOURCE_USE__", if (with_shared) "    if (shared.contract_version != 1) return error.IncompatibleSharedContract;" else "" },
    });
    try addRenderedAt(plan, prefix, "src/config.zig", templates.config_source, &.{});
    try addRenderedAt(plan, prefix, "src/cli.zig", templates.cli_source, &.{.{ "__PROJECT_NAME__", component_name }});
    try addRenderedAt(plan, prefix, "src/http.zig", templates.http_source, &.{});
    try addRenderedAt(plan, prefix, "src/sql.zig", templates.sql_source, &.{});
    try addRenderedAt(plan, prefix, "src/causal.zig", templates.causal_source, &.{});
    try addRenderedAt(plan, prefix, "src/services/greeting.zig", templates.greeting_source, &.{});
    try addRenderedAt(plan, prefix, "test/root_test.zig", templates.executable_test, &.{});
    if (prefix.len != 0) {
        try addRenderedAt(plan, prefix, "README.md", templates.readme, &.{.{ "__PROJECT_NAME__", component_name }});
    }
}

fn formatScaffoldOutput(
    allocator: std.mem.Allocator,
    options: ScaffoldOptions,
    plan: zstd.Project.FilePlan,
    status: zstd.Project.ScaffoldStatus,
    written: usize,
    replaced: usize,
    detail: []const u8,
) ![]u8 {
    const safe_target = try zstd.Secrets.redactAlloc(allocator, options.target);
    defer allocator.free(safe_target);
    const safe_detail = try zstd.Secrets.redactAlloc(allocator, detail);
    defer allocator.free(safe_detail);
    const paths = try allocator.alloc([]const u8, plan.files.items.len);
    defer allocator.free(paths);
    for (plan.files.items, 0..) |file, index| {
        paths[index] = file.path;
    }

    if (options.json) {
        return std.json.Stringify.valueAlloc(allocator, .{
            .schema = "zigeffect.scaffold-receipt.v1",
            .project = options.name,
            .kind = options.kind,
            .target = safe_target,
            .status = status,
            .planned = plan.files.items.len,
            .written = written,
            .replaced = replaced,
            .detail = safe_detail,
            .paths = paths,
        }, .{});
    }

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try output.print(allocator, "{s} {s} at {s}: {s}\n", .{ @tagName(status), @tagName(options.kind), safe_target, safe_detail });
    try output.print(allocator, "planned={d} written={d} replaced={d}\n", .{ plan.files.items.len, written, replaced });
    for (paths) |path| try output.print(allocator, "- {s}\n", .{path});
    return output.toOwnedSlice(allocator);
}

fn addLibraryProject(
    plan: *zstd.Project.FilePlan,
    options: ScaffoldOptions,
    prefix: []const u8,
    module_name: []const u8,
    changelog: bool,
) !void {
    const allocator = plan.allocator;
    const package_name = if (prefix.len == 0)
        try zigIdentifierAlloc(allocator, options.name)
    else
        try prefixedPackageNameAlloc(allocator, options.name, prefix);
    defer allocator.free(package_name);
    const fingerprint = try fingerprintAlloc(allocator, package_name);
    defer allocator.free(fingerprint);
    const std_path = if (prefix.len == 0)
        try allocator.dupe(u8, options.zigeffect_std_path)
    else
        try pathFromComponentAlloc(allocator, prefix, options.zigeffect_std_path);
    defer allocator.free(std_path);
    const component_name = if (prefix.len == 0) options.name else componentNameFromPrefix(prefix);

    try addRenderedAt(plan, prefix, "build.zig", templates.library_build, &.{
        .{ "__PROJECT_NAME__", component_name },
        .{ "__MODULE_NAME__", module_name },
    });
    try addRenderedAt(plan, prefix, "build.zig.zon", templates.executable_zon, &.{
        .{ "__ZIG_NAME__", package_name },
        .{ "__FINGERPRINT__", fingerprint },
        .{ "__STD_PATH__", std_path },
        .{ "__SHARED_ZON_DEPENDENCY__", "" },
    });
    try addRenderedAt(plan, prefix, "src/root.zig", if (prefix.len == 0) templates.library_source else templates.shared_source, &.{.{ "__PROJECT_NAME__", component_name }});
    try addRenderedAt(plan, prefix, "test/root_test.zig", if (prefix.len == 0) templates.library_test else templates.shared_test, &.{});
    if (changelog) try addRenderedAt(plan, prefix, "CHANGELOG.md", templates.changelog, &.{});
    if (prefix.len != 0) {
        try addRenderedAt(plan, prefix, "README.md", templates.readme, &.{.{ "__PROJECT_NAME__", component_name }});
    }
}

fn addSystemProject(plan: *zstd.Project.FilePlan, options: ScaffoldOptions) !void {
    const allocator = plan.allocator;
    const package_name = try zigIdentifierAlloc(allocator, options.name);
    defer allocator.free(package_name);
    const fingerprint = try fingerprintAlloc(allocator, package_name);
    defer allocator.free(fingerprint);
    try addRenderedAt(plan, "", "build.zig", templates.system_build, &.{.{ "__PROJECT_NAME__", options.name }});
    try addRenderedAt(plan, "", "build.zig.zon", templates.system_zon, &.{
        .{ "__ZIG_NAME__", package_name },
        .{ "__FINGERPRINT__", fingerprint },
    });
    try addRenderedAt(plan, "", "src/root.zig", templates.system_source, &.{});
    try addRenderedAt(plan, "", "test/root_test.zig", templates.system_test, &.{});
    try addExecutableProject(plan, options, "services/api", true);
    try addExecutableProject(plan, options, "services/worker", true);
    try addLibraryProject(plan, options, "packages/shared", "shared", false);
}

fn addRootCommon(plan: *zstd.Project.FilePlan, options: ScaffoldOptions) !void {
    try addRenderedAt(plan, "", "README.md", templates.readme, &.{.{ "__PROJECT_NAME__", options.name }});
    try plan.add(".gitignore", templates.gitignore);
    try plan.add(".agents/skills/zigeffect-development/SKILL.md", templates.skill);
    try plan.add(".claude/skills/zigeffect-development/SKILL.md", templates.skill);
}

fn addManifest(plan: *zstd.Project.FilePlan, options: ScaffoldOptions) !void {
    const commands = [_]zstd.Project.Command{
        .{ .id = "build", .argv = &.{ "zig", "build" } },
        .{ .id = "check", .argv = &.{ "zig", "build", "test" } },
        .{ .id = "check-debug", .argv = &.{ "zig", "build", "test", "-Doptimize=Debug" } },
        .{ .id = "check-safe", .argv = &.{ "zig", "build", "test", "-Doptimize=ReleaseSafe" } },
        .{ .id = "test", .argv = &.{ "zig", "build", "test" } },
        .{ .id = "dev", .argv = if (options.kind == .application or options.kind == .service) &.{ "zig", "build", "run" } else &.{ "zig", "build", "test" } },
        .{ .id = "doctor", .argv = &.{ "zig", "build", "test" } },
    };
    const requirements = [_]zstd.Project.Requirement{.{
        .id = "req-bootstrap",
        .summary = "Keep every generated boundary compiling with causal evidence",
        .component = if (options.kind == .system) "api-service" else options.name,
        .status = .active,
    }};
    const checks = [_]zstd.Project.AcceptanceCheck{.{
        .id = "check-bootstrap",
        .requirement = "req-bootstrap",
        .command = "test",
        .expectation = "all generated tests pass",
    }};
    const executable_capabilities = [_]zstd.Project.Capability{ .cli, .http, .sql, .config, .observability, .agent, .workbench };
    const library_capabilities = [_]zstd.Project.Capability{ .config, .observability, .agent, .workbench };
    const single_component = [_]zstd.Project.Component{.{
        .id = options.name,
        .kind = projectToComponentKind(options.kind),
        .path = ".",
        .capabilities = if (options.kind == .application or options.kind == .service) executable_capabilities[0..] else library_capabilities[0..],
    }};
    const system_components = [_]zstd.Project.Component{
        .{ .id = "api-service", .kind = .service, .path = "services/api", .depends_on = &.{"shared-domain"}, .capabilities = executable_capabilities[0..] },
        .{ .id = "worker-service", .kind = .service, .path = "services/worker", .depends_on = &.{"shared-domain"}, .capabilities = executable_capabilities[0..] },
        .{ .id = "shared-domain", .kind = .package, .path = "packages/shared", .capabilities = library_capabilities[0..] },
    };
    const manifest = zstd.Project.Manifest{
        .name = options.name,
        .kind = options.kind,
        .components = if (options.kind == .system) system_components[0..] else single_component[0..],
        .commands = commands[0..],
        .requirements = requirements[0..],
        .acceptance_checks = checks[0..],
        .safety = .{
            .profile = .agent_safe_v1,
            .safe_roots = if (options.kind == .system) &.{ "src", "services", "packages", "test" } else &.{ "src", "test" },
            .gates = &.{
                .{ .kind = .source_policy },
                .{ .kind = .compile_debug, .command = "check-debug" },
                .{ .kind = .compile_release_safe, .command = "check-safe" },
                .{ .kind = .allocation_failures, .command = "check-debug" },
                .{ .kind = .leak_detection, .command = "check-debug" },
                .{ .kind = .causal_invariants, .command = "check-debug" },
                .{ .kind = .schedule_exploration, .command = "check-debug" },
                .{ .kind = .executor_equivalence, .command = "check-debug" },
                .{ .kind = .thread_sanitizer, .required = false },
                .{ .kind = .c_undefined_behavior, .required = false },
                .{ .kind = .stack_protection, .required = false },
                .{ .kind = .fuzz, .required = false },
            },
        },
        .dependencies = .{
            .zigeffect = options.zigeffect_path,
            .zigeffect_std = options.zigeffect_std_path,
        },
    };
    const json = try manifest.jsonAlloc(plan.allocator);
    defer plan.allocator.free(json);
    try plan.add("zigeffect.project.json", json);
}

const Replacement = struct { []const u8, []const u8 };

fn addRenderedAt(
    plan: *zstd.Project.FilePlan,
    prefix: []const u8,
    relative_path: []const u8,
    template: []const u8,
    replacements: []const Replacement,
) !void {
    const content = try renderAlloc(plan.allocator, template, replacements);
    defer plan.allocator.free(content);
    const path = if (prefix.len == 0)
        try plan.allocator.dupe(u8, relative_path)
    else
        try std.fmt.allocPrint(plan.allocator, "{s}/{s}", .{ prefix, relative_path });
    defer plan.allocator.free(path);
    try plan.add(path, content);
}

fn renderAlloc(allocator: std.mem.Allocator, template: []const u8, replacements: []const Replacement) ![]u8 {
    var current = try allocator.dupe(u8, template);
    errdefer allocator.free(current);
    for (replacements) |replacement| {
        const next = try replaceAllAlloc(allocator, current, replacement[0], replacement[1]);
        allocator.free(current);
        current = next;
    }
    if (std.mem.indexOf(u8, current, "__") != null) return error.UnresolvedTemplateValue;
    return current;
}

fn replaceAllAlloc(allocator: std.mem.Allocator, input: []const u8, needle: []const u8, value: []const u8) ![]u8 {
    if (needle.len == 0) return allocator.dupe(u8, input);
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    var rest = input;
    while (std.mem.indexOf(u8, rest, needle)) |index| {
        try output.appendSlice(allocator, rest[0..index]);
        try output.appendSlice(allocator, value);
        rest = rest[index + needle.len ..];
    }
    try output.appendSlice(allocator, rest);
    return output.toOwnedSlice(allocator);
}

fn zigIdentifierAlloc(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    const result = try allocator.dupe(u8, name);
    for (result) |*byte| {
        if (byte.* == '-') byte.* = '_';
    }
    return result;
}

fn prefixedPackageNameAlloc(allocator: std.mem.Allocator, project: []const u8, prefix: []const u8) ![]u8 {
    const component = componentNameFromPrefix(prefix);
    const joined = try std.fmt.allocPrint(allocator, "{s}_{s}", .{ project, component });
    defer allocator.free(joined);
    return zigIdentifierAlloc(allocator, joined);
}

fn fingerprintAlloc(allocator: std.mem.Allocator, package_name: []const u8) ![]u8 {
    const upper = @as(u64, std.hash.Crc32.hash(package_name)) << 32;
    const lower: u32 = @truncate(std.hash.Wyhash.hash(0, package_name));
    return std.fmt.allocPrint(allocator, "{x}", .{upper | lower});
}

fn pathFromComponentAlloc(allocator: std.mem.Allocator, prefix: []const u8, dependency_path: []const u8) ![]u8 {
    var depth: usize = 1;
    for (prefix) |byte| {
        if (byte == '/') depth += 1;
    }
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    for (0..depth) |_| try output.appendSlice(allocator, "../");
    try output.appendSlice(allocator, dependency_path);
    return output.toOwnedSlice(allocator);
}

fn componentNameFromPrefix(prefix: []const u8) []const u8 {
    const slash = std.mem.lastIndexOfScalar(u8, prefix, '/') orelse return prefix;
    return prefix[slash + 1 ..];
}

fn projectToComponentKind(kind: zstd.Project.ProjectKind) zstd.Project.ComponentKind {
    return switch (kind) {
        .application => .application,
        .service => .service,
        .library => .library,
        .package => .package,
        .system => .application,
    };
}

fn parseKind(token: []const u8) ?zstd.Project.ProjectKind {
    if (eql(token, "application")) return .application;
    if (eql(token, "service")) return .service;
    if (eql(token, "library")) return .library;
    if (eql(token, "package")) return .package;
    if (eql(token, "system")) return .system;
    return null;
}

fn parseProjectArgs(args: []const []const u8) (CliError || zstd.Project.ProjectError)!ProjectOptions {
    if (args.len == 0) return error.MissingCommand;
    const operation = std.meta.stringToEnum(ProjectOperation, args[0]) orelse return error.UnknownCommand;
    var options = ProjectOptions{ .operation = operation };
    var root_set = false;
    var index: usize = 1;
    while (index < args.len) {
        if (eql(args[index], "--root")) {
            if (root_set) return error.DuplicateOption;
            options.root = try optionValue(args, &index);
            root_set = true;
        } else if (eql(args[index], "--json")) {
            if (options.json) return error.DuplicateOption;
            options.json = true;
            index += 1;
        } else if (eql(args[index], "--agent")) {
            if (options.agent or operation != .check) return error.DuplicateOption;
            options.agent = true;
            index += 1;
        } else return error.UnknownOption;
    }
    try validateTarget(options.root);
    return options;
}

fn parseSafetyArgs(args: []const []const u8) CliError!SafetyOptions {
    if (args.len == 0) return error.MissingCommand;
    const operation = std.meta.stringToEnum(SafetyOperation, args[0]) orelse return error.UnknownCommand;
    var options = SafetyOptions{ .operation = operation };
    var index: usize = 1;
    if (operation == .explain or operation == .replay) {
        if (index >= args.len or std.mem.startsWith(u8, args[index], "--")) return error.MissingOptionValue;
        options.finding_id = args[index];
        index += 1;
    }
    var root_set = false;
    var receipt_set = false;
    while (index < args.len) {
        if (eql(args[index], "--root")) {
            if (root_set) return error.DuplicateOption;
            options.root = try optionValue(args, &index);
            root_set = true;
        } else if (eql(args[index], "--receipt")) {
            if (receipt_set) return error.DuplicateOption;
            options.receipt = try optionValue(args, &index);
            receipt_set = true;
        } else return error.UnknownOption;
    }
    try validateTarget(options.root);
    return options;
}

fn parseAgentArgs(args: []const []const u8) CliError!AgentOptions {
    if (args.len == 0) return error.MissingCommand;
    const operation = std.meta.stringToEnum(AgentOperation, args[0]) orelse return error.UnknownCommand;
    var options = AgentOptions{ .operation = operation };
    var root_set = false;
    var provider_set = false;
    var session_set = false;
    var format_set = false;
    var index: usize = 1;
    while (index < args.len) {
        if (eql(args[index], "--root")) {
            if (root_set) return error.DuplicateOption;
            options.root = try optionValue(args, &index);
            root_set = true;
        } else if (eql(args[index], "--provider")) {
            if (provider_set) return error.DuplicateOption;
            options.provider = try optionValue(args, &index);
            provider_set = true;
        } else if (eql(args[index], "--session")) {
            if (session_set) return error.DuplicateOption;
            options.session = try optionValue(args, &index);
            session_set = true;
        } else if (eql(args[index], "--json") or eql(args[index], "--jsonl")) {
            if (format_set) return error.DuplicateOption;
            options.jsonl = eql(args[index], "--jsonl");
            format_set = true;
            index += 1;
        } else return error.UnknownOption;
    }
    try validateTarget(options.root);
    if (operation == .handoff and (options.provider.len == 0 or options.session.len == 0)) return error.MissingOptionValue;
    return options;
}

fn parseBenchmarkArgs(args: []const []const u8) CliError!BenchmarkOptions {
    if (args.len == 0) return error.MissingCommand;
    const operation = std.meta.stringToEnum(BenchmarkOperation, args[0]) orelse return error.UnknownCommand;
    var options = BenchmarkOptions{ .operation = operation };
    var index: usize = 1;
    if (operation == .score) {
        if (index >= args.len or std.mem.startsWith(u8, args[index], "--")) return error.MissingOptionValue;
        options.fixture = args[index];
        index += 1;
    }
    var root_set = false;
    var json_set = false;
    var provider_set = false;
    var command_set = false;
    while (index < args.len) {
        if (eql(args[index], "--root")) {
            if (root_set) return error.DuplicateOption;
            options.root = try optionValue(args, &index);
            root_set = true;
        } else if (eql(args[index], "--json")) {
            if (json_set) return error.DuplicateOption;
            json_set = true;
            index += 1;
        } else if (eql(args[index], "--provider")) {
            if (provider_set) return error.DuplicateOption;
            options.provider = try optionValue(args, &index);
            provider_set = true;
        } else if (eql(args[index], "--command")) {
            if (command_set) return error.DuplicateOption;
            options.command = try optionValue(args, &index);
            command_set = true;
        } else return error.UnknownOption;
    }
    if (operation == .run and (!provider_set or !command_set)) return error.MissingOptionValue;
    try validateTarget(options.root);
    return options;
}

fn parseAddArgs(args: []const []const u8) (CliError || zstd.Project.ProjectError)!AddOptions {
    if (args.len < 1) return error.MissingScaffoldKind;
    if (args.len < 2) return error.MissingProjectName;
    const kind = std.meta.stringToEnum(AddKind, args[0]) orelse return error.UnknownScaffoldKind;
    try zstd.Project.validateIdentifier(args[1]);
    var options = AddOptions{ .kind = kind, .name = args[1] };
    try parseMutationOptions(AddOptions, &options, args[2..]);
    return options;
}

fn parseGenerateArgs(args: []const []const u8) (CliError || zstd.Project.ProjectError)!GenerateOptions {
    if (args.len < 1) return error.MissingScaffoldKind;
    if (args.len < 2) return error.MissingProjectName;
    const kind = std.meta.stringToEnum(GenerateKind, args[0]) orelse return error.UnknownScaffoldKind;
    try zstd.Project.validateIdentifier(args[1]);
    var options = GenerateOptions{ .kind = kind, .name = args[1], .component = "" };
    var component_set = false;
    var root_set = false;
    var index: usize = 2;
    while (index < args.len) {
        if (eql(args[index], "--component")) {
            if (component_set) return error.DuplicateOption;
            options.component = try optionValue(args, &index);
            try zstd.Project.validateIdentifier(options.component);
            component_set = true;
        } else if (eql(args[index], "--root")) {
            if (root_set) return error.DuplicateOption;
            options.root = try optionValue(args, &index);
            root_set = true;
        } else if (eql(args[index], "--dry-run")) {
            if (options.dry_run) return error.DuplicateOption;
            options.dry_run = true;
            index += 1;
        } else if (eql(args[index], "--json")) {
            if (options.json) return error.DuplicateOption;
            options.json = true;
            index += 1;
        } else if (eql(args[index], "--force")) {
            if (options.force) return error.DuplicateOption;
            options.force = true;
            index += 1;
        } else return error.UnknownOption;
    }
    if (!component_set) return error.MissingOptionValue;
    try validateTarget(options.root);
    return options;
}

fn parseMutationOptions(comptime T: type, options: *T, args: []const []const u8) CliError!void {
    var root_set = false;
    var index: usize = 0;
    while (index < args.len) {
        if (eql(args[index], "--root")) {
            if (root_set) return error.DuplicateOption;
            options.root = try optionValue(args, &index);
            root_set = true;
        } else if (eql(args[index], "--dry-run")) {
            if (options.dry_run) return error.DuplicateOption;
            options.dry_run = true;
            index += 1;
        } else if (eql(args[index], "--json")) {
            if (options.json) return error.DuplicateOption;
            options.json = true;
            index += 1;
        } else if (eql(args[index], "--force")) {
            if (options.force) return error.DuplicateOption;
            options.force = true;
            index += 1;
        } else return error.UnknownOption;
    }
    try validateTarget(options.root);
}

fn optionValue(args: []const []const u8, index: *usize) CliError![]const u8 {
    if (index.* + 1 >= args.len) return error.MissingOptionValue;
    const value = args[index.* + 1];
    if (value.len == 0 or std.mem.startsWith(u8, value, "--")) return error.MissingOptionValue;
    index.* += 2;
    return value;
}

fn validateTarget(target: []const u8) CliError!void {
    if (target.len == 0 or std.mem.indexOfScalar(u8, target, 0) != null) return error.InvalidTarget;
}

fn eql(left: []const u8, right: []const u8) bool {
    return std.mem.eql(u8, left, right);
}

test "CLI parses help version and every new scaffold kind" {
    try std.testing.expectEqual(Action.help, try parseArgs(&.{"--help"}));
    try std.testing.expectEqual(Action.version, try parseArgs(&.{"--version"}));

    const cases = [_]struct {
        token: []const u8,
        kind: zstd.Project.ProjectKind,
    }{
        .{ .token = "application", .kind = .application },
        .{ .token = "service", .kind = .service },
        .{ .token = "library", .kind = .library },
        .{ .token = "package", .kind = .package },
        .{ .token = "system", .kind = .system },
    };
    for (cases) |case| {
        const action = try parseArgs(&.{ "new", case.token, "demo-project", "--target", "out/demo", "--zigeffect-std-path", "../../zigeffect-std", "--dry-run", "--json", "--force" });
        try std.testing.expectEqual(case.kind, action.new.kind);
        try std.testing.expectEqualStrings("demo-project", action.new.name);
        try std.testing.expectEqualStrings("out/demo", action.new.target);
        try std.testing.expectEqualStrings("../../zigeffect-std", action.new.zigeffect_std_path);
        try std.testing.expect(action.new.dry_run);
        try std.testing.expect(action.new.json);
        try std.testing.expect(action.new.force);
    }
}

test "CLI rejects incomplete unknown and duplicate arguments" {
    try std.testing.expectError(error.MissingCommand, parseArgs(&.{}));
    try std.testing.expectError(error.MissingScaffoldKind, parseArgs(&.{"new"}));
    try std.testing.expectError(error.UnknownScaffoldKind, parseArgs(&.{ "new", "thing", "demo" }));
    try std.testing.expectError(error.InvalidName, parseArgs(&.{ "new", "application", "Bad_Name" }));
    try std.testing.expectError(error.UnknownOption, parseArgs(&.{ "new", "application", "demo", "--wat" }));
    try std.testing.expectError(error.DuplicateOption, parseArgs(&.{ "new", "application", "demo", "--json", "--json" }));
    try std.testing.expectError(error.MissingOptionValue, parseArgs(&.{ "new", "application", "demo", "--target" }));
}

test "CLI parses bounded project add and generate operations" {
    const project = try parseArgs(&.{ "project", "check", "--root", "demo", "--json", "--agent" });
    try std.testing.expectEqual(ProjectOperation.check, project.project.operation);
    try std.testing.expectEqualStrings("demo", project.project.root);
    try std.testing.expect(project.project.json);
    try std.testing.expect(project.project.agent);

    const explanation = try parseArgs(&.{ "safety", "explain", "ZFX-pointer_cast-0123456789abcdef", "--root", "demo" });
    try std.testing.expectEqual(SafetyOperation.explain, explanation.safety.operation);
    try std.testing.expectEqualStrings("ZFX-pointer_cast-0123456789abcdef", explanation.safety.finding_id);
    try std.testing.expectEqualStrings("demo", explanation.safety.root);

    const baseline = try parseArgs(&.{ "safety", "baseline", "--receipt", ".zigeffect/receipts/candidate.json" });
    try std.testing.expectEqual(SafetyOperation.baseline, baseline.safety.operation);
    try std.testing.expectEqualStrings(".zigeffect/receipts/candidate.json", baseline.safety.receipt);
    try std.testing.expectError(error.MissingOptionValue, parseArgs(&.{ "safety", "replay" }));

    const benchmark = try parseArgs(&.{ "benchmark", "score", "fixtures/codex-zig.json", "--json", "--root", "demo" });
    try std.testing.expectEqual(BenchmarkOperation.score, benchmark.benchmark.operation);
    try std.testing.expectEqualStrings("fixtures/codex-zig.json", benchmark.benchmark.fixture);
    try std.testing.expectEqualStrings("demo", benchmark.benchmark.root);
    const provider_run = try parseArgs(&.{ "benchmark", "run", "--provider", "codex", "--command", "benchmark-codex" });
    try std.testing.expectEqual(BenchmarkOperation.run, provider_run.benchmark.operation);
    try std.testing.expectEqualStrings("codex", provider_run.benchmark.provider);
    try std.testing.expectEqualStrings("benchmark-codex", provider_run.benchmark.command);

    const add = try parseArgs(&.{ "add", "service", "payments", "--root", "demo", "--dry-run" });
    try std.testing.expectEqual(AddKind.service, add.add.kind);
    try std.testing.expectEqualStrings("payments", add.add.name);
    try std.testing.expect(add.add.dry_run);

    const generate = try parseArgs(&.{ "generate", "schema", "invoice", "--component", "api-service", "--root", "demo", "--force" });
    try std.testing.expectEqual(GenerateKind.schema, generate.generate.kind);
    try std.testing.expectEqualStrings("api-service", generate.generate.component);
    try std.testing.expect(generate.generate.force);
    try std.testing.expectError(error.MissingOptionValue, parseArgs(&.{ "generate", "schema", "invoice" }));
}

test "CLI parses provider-neutral agent queries and handoff" {
    const query = try parseArgs(&.{ "agent", "evidence", "--root", "demo", "--jsonl" });
    try std.testing.expectEqual(AgentOperation.evidence, query.agent.operation);
    try std.testing.expect(query.agent.jsonl);
    const handoff = try parseArgs(&.{ "agent", "handoff", "--provider", "claude-code", "--session", "session-7" });
    try std.testing.expectEqualStrings("claude-code", handoff.agent.provider);
    try std.testing.expectEqualStrings("session-7", handoff.agent.session);
}

test "agent queries expose only unresolved requirements and non-passing checks" {
    const requirements = [_]zstd.Project.Requirement{
        .{ .id = "req-open", .summary = "open work", .component = "api", .status = .active },
        .{ .id = "req-done", .summary = "finished work", .component = "api", .status = .satisfied },
    };
    const checks = [_]zstd.Project.AcceptanceCheck{
        .{ .id = "check-failed", .requirement = "req-open", .command = "check", .expectation = "passes", .status = .failed },
        .{ .id = "check-passed", .requirement = "req-done", .command = "check", .expectation = "passes", .status = .passed },
    };

    const requirement_json = try encodeRequirementQueryAlloc(std.testing.allocator, &requirements, false);
    defer std.testing.allocator.free(requirement_json);
    try std.testing.expect(std.mem.indexOf(u8, requirement_json, "req-open") != null);
    try std.testing.expect(std.mem.indexOf(u8, requirement_json, "req-done") == null);

    const check_jsonl = try encodeAcceptanceQueryAlloc(std.testing.allocator, &checks, true);
    defer std.testing.allocator.free(check_jsonl);
    try std.testing.expect(std.mem.indexOf(u8, check_jsonl, "check-failed") != null);
    try std.testing.expect(std.mem.indexOf(u8, check_jsonl, "check-passed") == null);
}

test "generator emits deterministic valid manifests skills and safe common files" {
    const kinds = [_]zstd.Project.ProjectKind{ .application, .service, .library, .package, .system };
    for (kinds) |kind| {
        var plan = try generatePlan(std.testing.allocator, .{
            .kind = kind,
            .name = "demo-project",
            .target = "demo-project",
            .zigeffect_std_path = "../../zigeffect-std",
        });
        defer plan.deinit();

        try std.testing.expect(plan.find("build.zig") != null);
        try std.testing.expect(plan.find("build.zig.zon") != null);
        try std.testing.expect(plan.find("zigeffect.project.json") != null);
        try std.testing.expect(plan.find(".agents/skills/zigeffect-development/SKILL.md") != null);
        try std.testing.expect(plan.find(".claude/skills/zigeffect-development/SKILL.md") != null);
        try std.testing.expect(plan.find("README.md") != null);
        try std.testing.expect(plan.find("test/root_test.zig") != null);

        var parsed = try zstd.Project.parseManifest(std.testing.allocator, plan.find("zigeffect.project.json").?.content);
        defer parsed.deinit();
        try std.testing.expectEqual(kind, parsed.value.kind);
        try std.testing.expectEqual(zstd.Project.SafetyProfile.agent_safe_v1, parsed.value.safety.profile);
        try std.testing.expectEqual(@as(usize, 12), parsed.value.safety.gates.len);

        for (plan.files.items[1..], 1..) |file, index| {
            try std.testing.expect(std.mem.order(u8, plan.files.items[index - 1].path, file.path) == .lt);
            try zstd.Testing.assertNoSentinelSecrets(file.content);
        }
    }
}

test "application and service plans wire every production boundary" {
    for ([_]zstd.Project.ProjectKind{ .application, .service }) |kind| {
        var plan = try generatePlan(std.testing.allocator, .{
            .kind = kind,
            .name = "demo-project",
            .target = "demo-project",
            .zigeffect_std_path = "../../zigeffect-std",
        });
        defer plan.deinit();

        for ([_][]const u8{
            "src/main.zig",
            "src/app.zig",
            "src/config.zig",
            "src/cli.zig",
            "src/http.zig",
            "src/sql.zig",
            "src/services/greeting.zig",
            "src/causal.zig",
        }) |path| try std.testing.expect(plan.find(path) != null);

        const app = plan.find("src/app.zig").?.content;
        for ([_][]const u8{
            "zstd.Application.configLoad",
            "zstd.Application.schemaDecode",
            "zstd.Application.commandExecution",
            "zstd.Application.requestHandling",
            "zstd.Application.sqlTransaction",
            "zstd.Application.externalCall",
            "zstd.Application.artifactProduction",
            "zstd.Application.componentDependency",
            "zstd.Application.acceptanceEvaluation",
        }) |semantic_helper| try std.testing.expect(std.mem.indexOf(u8, app, semantic_helper) != null);
    }
}

test "system plan contains independently buildable services and shared package" {
    var plan = try generatePlan(std.testing.allocator, .{
        .kind = .system,
        .name = "demo-system",
        .target = "demo-system",
        .zigeffect_std_path = "../../zigeffect-std",
    });
    defer plan.deinit();

    for ([_][]const u8{
        "services/api/build.zig",
        "services/api/src/main.zig",
        "services/worker/build.zig",
        "services/worker/src/main.zig",
        "packages/shared/build.zig",
        "packages/shared/src/root.zig",
    }) |path| try std.testing.expect(plan.find(path) != null);
}

test "writer dry run creates nothing and default mode refuses a non-empty target" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var plan = zstd.Project.FilePlan.init(std.testing.allocator);
    defer plan.deinit();
    try plan.add("src/main.zig", "const ready = true;\n");

    const dry = try writePlan(std.testing.io, tmp.dir, "dry-project", plan, .{ .dry_run = true });
    try std.testing.expectEqual(@as(usize, 0), dry.written);
    try std.testing.expectError(error.FileNotFound, tmp.dir.openDir(std.testing.io, "dry-project", .{}));

    try tmp.dir.createDirPath(std.testing.io, "occupied");
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "occupied/keep.txt", .data = "keep" });
    try std.testing.expectError(error.TargetNotEmpty, writePlan(std.testing.io, tmp.dir, "occupied", plan, .{}));
    const kept = try tmp.dir.readFileAlloc(std.testing.io, "occupied/keep.txt", std.testing.allocator, .limited(32));
    defer std.testing.allocator.free(kept);
    try std.testing.expectEqualStrings("keep", kept);
}

test "writer creates parents atomically and force replaces declared files only" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var first = zstd.Project.FilePlan.init(std.testing.allocator);
    defer first.deinit();
    try first.add("src/main.zig", "first\n");
    try first.add("build.zig", "build\n");

    const created = try writePlan(std.testing.io, tmp.dir, "demo", first, .{});
    try std.testing.expectEqual(@as(usize, 2), created.written);
    try std.testing.expectEqual(@as(usize, 0), created.replaced);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "demo/notes.txt", .data = "preserve" });

    var second = zstd.Project.FilePlan.init(std.testing.allocator);
    defer second.deinit();
    try second.add("src/main.zig", "second\n");
    try second.add("build.zig", "build\n");
    const forced = try writePlan(std.testing.io, tmp.dir, "demo", second, .{ .force = true });
    try std.testing.expectEqual(@as(usize, 2), forced.written);
    try std.testing.expectEqual(@as(usize, 2), forced.replaced);

    const main = try tmp.dir.readFileAlloc(std.testing.io, "demo/src/main.zig", std.testing.allocator, .limited(32));
    defer std.testing.allocator.free(main);
    try std.testing.expectEqualStrings("second\n", main);
    const notes = try tmp.dir.readFileAlloc(std.testing.io, "demo/notes.txt", std.testing.allocator, .limited(32));
    defer std.testing.allocator.free(notes);
    try std.testing.expectEqualStrings("preserve", notes);
}

test "writer accepts an explicit absolute target" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var buffer: [std.fs.max_path_bytes]u8 = undefined;
    const length = try tmp.dir.realPath(std.testing.io, &buffer);
    const target = try std.fs.path.join(std.testing.allocator, &.{ buffer[0..length], "absolute-project" });
    defer std.testing.allocator.free(target);

    var plan = zstd.Project.FilePlan.init(std.testing.allocator);
    defer plan.deinit();
    try plan.add("src/main.zig", "const ready = true;\n");
    const result = try writePlan(std.testing.io, tmp.dir, target, plan, .{});
    try std.testing.expectEqual(@as(usize, 1), result.written);
    const content = try tmp.dir.readFileAlloc(std.testing.io, "absolute-project/src/main.zig", std.testing.allocator, .limited(64));
    defer std.testing.allocator.free(content);
    try std.testing.expectEqualStrings("const ready = true;\n", content);
}

test "run emits a complete JSON dry-run and an honest refused receipt" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var dry = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{
        "new", "application", "demo-app", "--target", "demo-app", "--zigeffect-path", "../../zigeffect", "--zigeffect-std-path", "../../zigeffect-std", "--dry-run", "--json",
    });
    defer dry.deinit();
    try std.testing.expectEqual(@as(u8, 0), dry.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, dry.output, "\"status\":\"planned\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dry.output, "src/app.zig") != null);
    try std.testing.expectError(error.FileNotFound, tmp.dir.openDir(std.testing.io, "demo-app", .{}));

    try tmp.dir.createDirPath(std.testing.io, "occupied");
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "occupied/keep.txt", .data = "keep" });
    var refused = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{
        "new", "service", "demo-service", "--target", "occupied", "--json",
    });
    defer refused.deinit();
    try std.testing.expectEqual(@as(u8, 3), refused.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, refused.output, "\"status\":\"refused\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, refused.output, "TargetNotEmpty") != null);
    try zstd.Testing.assertNoSentinelSecrets(refused.output);
}
