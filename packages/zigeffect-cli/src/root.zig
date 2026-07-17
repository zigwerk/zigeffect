const std = @import("std");
pub const zstd = @import("zigeffect_std");
const templates = @import("templates.zig");
pub const safety = @import("safety_command.zig");
pub const distribution = @import("distribution.zig");

pub const version = distribution.cli_version;

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
    UnknownShell,
    InvalidOptionCombination,
    InvalidEventId,
    InvalidLimit,
    InvalidStatechartId,
    InvalidInstanceId,
    InvalidSeed,
    InvalidFault,
    MissingScenario,
};

pub const ScaffoldProfile = enum { @"local-fake", @"integration-real", production };
pub const ScaffoldOptions = struct {
    kind: zstd.Project.ProjectKind,
    name: []const u8,
    target: []const u8,
    zigeffect_path: []const u8 = "../zigeffect",
    zigeffect_std_path: []const u8 = "../zigeffect-std",
    dry_run: bool = false,
    json: bool = false,
    force: bool = false,
    profile: ScaffoldProfile = .@"local-fake",
};

pub const Action = union(enum) {
    help,
    version,
    completions: distribution.Shell,
    compatibility: CompatibilityOptions,
    upgrade: UpgradeOptions,
    graph: GraphOptions,
    statechart: StatechartOptions,
    @"test": TestOptions,
    new: ScaffoldOptions,
    project: ProjectOptions,
    safety: SafetyOptions,
    agent: AgentOptions,
    benchmark: BenchmarkOptions,
    add: AddOptions,
    generate: GenerateOptions,
};

pub const CompatibilityOptions = struct {
    root: []const u8 = ".",
    json: bool = false,
};

pub const UpgradeOptions = struct {
    root: []const u8 = ".",
    dry_run: bool = true,
    apply: bool = false,
    json: bool = false,
};

pub const GraphOperation = enum { status, since, event, children, path };
pub const GraphOptions = struct {
    operation: GraphOperation,
    event_id: u64 = 0,
    to_event_id: u64 = 0,
    limit: usize = 256,
    root: []const u8 = ".",
    component: ?[]const u8 = null,
    json: bool = false,
};

pub const StatechartOperation = enum { list, show, versions, instances, trace, explain, coverage, paths, studio, fleet, controls, compile, propose, verify, review, approve, application, patterns, pattern, @"export" };
pub const StatechartOptions = struct {
    operation: StatechartOperation,
    machine_id: []const u8 = "",
    instance_id: u64 = 0,
    format: zstd.Statechart.ExportFormat = .native,
    root: []const u8 = ".",
    component: ?[]const u8 = null,
    json: bool = false,
    input_path: []const u8 = "",
    output_path: []const u8 = "",
    pattern_kind: ?zstd.Statechart.Plan.PatternKind = null,
    namespace: []const u8 = "workflow",
    apply: bool = false,
};

pub const TestOperation = enum { list, run, affected, explain, replay, snapshot, coverage, gaps, stress, history };
pub const TestOptions = struct {
    operation: TestOperation,
    root: []const u8 = ".",
    scenario: []const u8 = "",
    requirement: []const u8 = "",
    component: []const u8 = "",
    tag: []const u8 = "",
    changed: []const u8 = "",
    seed: ?u64 = null,
    fault: []const u8 = "",
    json: bool = false,
    apply: bool = false,
    runs: usize = 8,
    profile: []const u8 = "",
};

pub const ProjectOperation = enum { show, validate, doctor, check, @"test", dev };
pub const ProjectOptions = struct {
    operation: ProjectOperation,
    root: []const u8 = ".",
    json: bool = false,
    agent: bool = false,
    profile: []const u8 = "",
    evidence_time_ms: i64 = 0,
};
pub const SafetyOperation = enum { explain, replay, baseline };
pub const SafetyOptions = struct {
    operation: SafetyOperation,
    finding_id: []const u8 = "",
    receipt: []const u8 = ".zigeffect/receipts/latest-safety.json",
    root: []const u8 = ".",
};
pub const AgentOperation = enum { status, requirements, checks, evidence, next, context, handoff };
pub const AgentOptions = struct {
    operation: AgentOperation,
    root: []const u8 = ".",
    provider: []const u8 = "local",
    session: []const u8 = "local-session",
    jsonl: bool = false,
    profile: []const u8 = "",
    task: []const u8 = "",
    changed: []const u8 = "",
    budget: usize = 32 * 1024,
};
pub const BenchmarkOperation = enum { score, conformance, run };
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
pub const GenerateKind = enum { service, layer, schema, cli, http, sql, statechart, statechart_actor, durable_statechart, statechart_test, @"test" };
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
    if (eql(args[0], "completions")) return .{ .completions = try parseCompletionsArgs(args[1..]) };
    if (eql(args[0], "compatibility")) return .{ .compatibility = try parseCompatibilityArgs(args[1..]) };
    if (eql(args[0], "upgrade")) return .{ .upgrade = try parseUpgradeArgs(args[1..]) };
    if (eql(args[0], "graph")) return .{ .graph = try parseGraphArgs(args[1..]) };
    if (eql(args[0], "statechart")) return .{ .statechart = try parseStatechartArgs(args[1..]) };
    if (eql(args[0], "test")) return .{ .@"test" = try parseTestArgs(args[1..]) };
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
    var profile_set = false;
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
        } else if (eql(token, "--profile")) {
            if (profile_set) return error.DuplicateOption;
            const value = try optionValue(args, &index);
            options.profile = std.meta.stringToEnum(ScaffoldProfile, value) orelse return error.UnknownOption;
            profile_set = true;
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
    try distribution.addScaffoldMetadata(&plan, options.name, options.kind);
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
    return runAllocWithEnvironment(allocator, io, base_dir, args, null);
}

pub fn runAllocWithEnvironment(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    args: []const []const u8,
    environment: ?*const std.process.Environ.Map,
) !RunResult {
    const action = try parseArgs(args);
    switch (action) {
        .help => return .{ .allocator = allocator, .exit_code = 0, .output = try allocator.dupe(u8, helpText()) },
        .version => return .{ .allocator = allocator, .exit_code = 0, .output = try std.fmt.allocPrint(allocator, "zigeffect {s}\n", .{version}) },
        .completions => |shell| return .{ .allocator = allocator, .exit_code = 0, .output = try allocator.dupe(u8, distribution.completionScript(shell)) },
        .compatibility => |options| return runCompatibilityAlloc(allocator, io, base_dir, options),
        .upgrade => |options| return runUpgradeAlloc(allocator, io, base_dir, options),
        .graph => |options| return runGraphAlloc(allocator, io, base_dir, options),
        .statechart => |options| return switch (options.operation) {
            .compile => runStatechartCompileAlloc(allocator, io, base_dir, options),
            .propose, .verify, .review, .approve, .application => runStatechartStudioArtifactAlloc(allocator, io, base_dir, options),
            .patterns => runStatechartPatternsAlloc(allocator),
            .pattern => runStatechartPatternAlloc(allocator, options),
            else => runStatechartAlloc(allocator, io, base_dir, options),
        },
        .@"test" => |options| return runTestAlloc(allocator, io, base_dir, options, environment),
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

const UpgradeAction = enum { create, update, unchanged, conflict, migrate };
const UpgradePath = struct { path: []const u8, action: UpgradeAction };

const UpgradeReport = struct {
    schema: []const u8 = distribution.upgrade_receipt_schema,
    schema_version: u32 = 1,
    project: []const u8,
    kind: zstd.Project.ProjectKind,
    from_project_schema: []const u8,
    to_project_schema: []const u8 = zstd.Project.schema_version,
    from_template_version: ?u32,
    to_template_version: u32 = distribution.template_version,
    status: []const u8,
    dry_run: bool,
    state_adoption: bool,
    created: usize,
    updated: usize,
    unchanged: usize,
    conflicts: usize,
    user_owned_preserved: usize,
    paths: []const UpgradePath,
};

fn runCompatibilityAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    options: CompatibilityOptions,
) !RunResult {
    var project_dir = try openTargetDir(io, base_dir, options.root);
    defer project_dir.close(io);
    const manifest_text = try readOptionalFileAlloc(allocator, io, project_dir, "zigeffect.project.json", 4 * 1024 * 1024);
    defer if (manifest_text) |text| allocator.free(text);
    if (manifest_text == null) {
        const report = distribution.CompatibilityReport{
            .project_present = false,
            .compatible = true,
            .upgrade_required = false,
        };
        const output = if (options.json)
            try std.json.Stringify.valueAlloc(allocator, report, .{})
        else
            try std.fmt.allocPrint(allocator, "zigeffect {s}: Zig >= {s} and < {s}; project schema {s}\n", .{
                distribution.cli_version,
                distribution.minimum_zig_version,
                distribution.maximum_zig_version_exclusive,
                zstd.Project.schema_version,
            });
        return .{ .allocator = allocator, .exit_code = 0, .output = output };
    }

    var manifest = try distribution.parseMigratableManifest(allocator, manifest_text.?);
    defer manifest.deinit();
    const metadata_text = try readOptionalFileAlloc(allocator, io, project_dir, distribution.compatibility_path, 1024 * 1024);
    defer if (metadata_text) |text| allocator.free(text);
    var metadata_valid = false;
    if (metadata_text) |text| {
        if (distribution.parseCompatibility(allocator, text)) |parsed_value| {
            var parsed = parsed_value;
            defer parsed.deinit();
            metadata_valid = std.mem.eql(u8, parsed.value.project, manifest.parsed.value.name) and
                parsed.value.kind == manifest.parsed.value.kind;
        } else |_| {}
    }
    const compatible = !manifest.migrated and metadata_valid;
    const report = distribution.CompatibilityReport{
        .project_present = true,
        .project = manifest.parsed.value.name,
        .kind = manifest.parsed.value.kind,
        .detected_project_schema = manifest.original_schema,
        .metadata_present = metadata_text != null,
        .compatible = compatible,
        .upgrade_required = !compatible,
    };
    const output = if (options.json)
        try std.json.Stringify.valueAlloc(allocator, report, .{})
    else
        try std.fmt.allocPrint(allocator, "{s}: {s}; schema={s}; metadata={s}; cli={s}\n", .{
            manifest.parsed.value.name,
            if (compatible) "compatible" else "upgrade required",
            manifest.original_schema,
            if (metadata_valid) "compatible" else "missing or incompatible",
            distribution.cli_version,
        });
    return .{ .allocator = allocator, .exit_code = if (compatible) 0 else 1, .output = output };
}

fn runGraphAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    options: GraphOptions,
) !RunResult {
    var project_dir = try openTargetDir(io, base_dir, options.root);
    defer project_dir.close(io);
    const manifest_text = try project_dir.readFileAlloc(io, "zigeffect.project.json", allocator, .limited(4 * 1024 * 1024));
    defer allocator.free(manifest_text);
    var manifest = try zstd.Project.parseManifest(allocator, manifest_text);
    defer manifest.deinit();
    if (manifest.value.kind == .system and options.component == null) return error.ComponentRequired;
    var component_dir: ?std.Io.Dir = null;
    defer if (component_dir) |*dir| dir.close(io);
    const graph_root = if (options.component) |component_id| graph_root: {
        const component = manifest.value.component(component_id) orelse return error.ComponentNotFound;
        if (std.mem.eql(u8, component.path, ".")) break :graph_root project_dir;
        component_dir = try project_dir.openDir(io, component.path, .{ .follow_symlinks = false });
        break :graph_root component_dir.?;
    } else project_dir;
    const graph_options = zstd.CausalGraph.Options{
        .path = manifest.value.artifacts.graph,
        .max_wal_bytes = manifest.value.safety.limits.max_artifact_bytes,
        .max_records = manifest.value.safety.limits.max_runtime_events,
    };
    var snapshot = zstd.CausalGraph.Snapshot.open(allocator, io, graph_root, graph_options) catch |failure| switch (failure) {
        error.FileNotFound => if (options.operation == .status or (options.operation == .since and options.event_id == 0))
            try zstd.CausalGraph.Snapshot.empty(allocator, graph_options)
        else
            return failure,
        else => return failure,
    };
    defer snapshot.deinit();

    const output = switch (options.operation) {
        .status => if (options.json)
            try snapshot.summaryJsonAlloc(allocator)
        else status: {
            const summary = snapshot.summary();
            break :status try std.fmt.allocPrint(allocator, "{s}{s}{s}: records={d} edges={d} sessions={d} bytes={d} partial={d}\n", .{
                manifest.value.name,
                if (options.component != null) "/" else "",
                options.component orelse "",
                summary.records,
                summary.edges,
                summary.sessions,
                summary.wal_bytes,
                summary.trailing_partial_bytes,
            });
        },
        .event => try snapshot.recordJsonAlloc(allocator, options.event_id),
        .since => try snapshot.recordsAfterJsonAlloc(allocator, options.event_id, options.limit),
        .children => children: {
            const ids = try snapshot.childrenAlloc(allocator, options.event_id);
            defer allocator.free(ids);
            if (options.json) break :children try zstd.CausalGraph.childrenJsonAlloc(allocator, options.event_id, ids);
            var text_output = std.ArrayList(u8).empty;
            errdefer text_output.deinit(allocator);
            try text_output.print(allocator, "event {d} children={d}\n", .{ options.event_id, ids.len });
            for (ids) |id| try text_output.print(allocator, "- {d}\n", .{id});
            break :children try text_output.toOwnedSlice(allocator);
        },
        .path => path: {
            var graph_path = try snapshot.pathAlloc(allocator, options.event_id, options.to_event_id, options.limit);
            defer graph_path.deinit();
            if (options.json) break :path try graph_path.jsonAlloc(allocator);
            var text_output = std.ArrayList(u8).empty;
            errdefer text_output.deinit(allocator);
            try text_output.print(allocator, "event {d} -> {d} path={d}\n", .{ options.event_id, options.to_event_id, graph_path.event_ids.len });
            for (graph_path.event_ids) |id| try text_output.print(allocator, "- {d}\n", .{id});
            break :path try text_output.toOwnedSlice(allocator);
        },
    };
    return .{ .allocator = allocator, .exit_code = 0, .output = output };
}

fn runStatechartAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    options: StatechartOptions,
) !RunResult {
    var project_dir = try openTargetDir(io, base_dir, options.root);
    defer project_dir.close(io);
    const manifest_text = try project_dir.readFileAlloc(io, "zigeffect.project.json", allocator, .limited(4 * 1024 * 1024));
    defer allocator.free(manifest_text);
    var manifest = try zstd.Project.parseManifest(allocator, manifest_text);
    defer manifest.deinit();
    if (manifest.value.kind == .system and options.component == null) return error.ComponentRequired;

    var component_dir: ?std.Io.Dir = null;
    defer if (component_dir) |*dir| dir.close(io);
    const artifact_root = if (options.component) |component_id| artifact_root: {
        const component = manifest.value.component(component_id) orelse return error.ComponentNotFound;
        if (std.mem.eql(u8, component.path, ".")) break :artifact_root project_dir;
        component_dir = try project_dir.openDir(io, component.path, .{ .follow_symlinks = false });
        break :artifact_root component_dir.?;
    } else project_dir;

    if (options.operation == .compile) return runStatechartCompileAlloc(allocator, io, artifact_root, options);
    if (options.operation == .patterns) return runStatechartPatternsAlloc(allocator);
    if (options.operation == .pattern) return runStatechartPatternAlloc(allocator, options);

    var statechart_dir = try artifact_root.openDir(io, manifest.value.artifacts.statecharts, .{ .follow_symlinks = false });
    defer statechart_dir.close(io);
    var catalog = try zstd.Statechart.readCatalogRecovering(
        allocator,
        io,
        statechart_dir,
        manifest.value.safety.limits.max_artifact_bytes,
    );
    defer catalog.deinit();

    const output = switch (options.operation) {
        .list => try catalog.value.listJsonAlloc(allocator),
        .show => try catalog.value.showJsonAlloc(allocator, options.machine_id),
        .versions => try catalog.value.versionsJsonAlloc(allocator, options.machine_id),
        .instances => try catalog.value.instancesJsonAlloc(allocator, options.machine_id),
        .trace => try catalog.value.traceJsonAlloc(allocator, options.instance_id),
        .explain => try catalog.value.explainJsonAlloc(allocator, options.instance_id),
        .coverage => try catalog.value.coverageJsonAlloc(allocator, options.machine_id),
        .paths => try catalog.value.pathsJsonAlloc(allocator, options.machine_id),
        .studio => try catalog.value.studioJsonAlloc(allocator, options.machine_id),
        .fleet => try catalog.value.fleetJsonAlloc(allocator),
        .controls => try catalog.value.controlReceiptsJsonAlloc(allocator),
        .@"export" => try catalog.value.exportAlloc(allocator, options.machine_id, options.format),
        .compile, .propose, .verify, .review, .approve, .application, .patterns, .pattern => unreachable,
    };
    return .{ .allocator = allocator, .exit_code = 0, .output = output };
}

fn runStatechartCompileAlloc(allocator: std.mem.Allocator, io: std.Io, base_dir: std.Io.Dir, options: StatechartOptions) !RunResult {
    var root = try openTargetDir(io, base_dir, options.root);
    defer root.close(io);
    const input = try root.readFileAlloc(io, options.input_path, allocator, .limited(4 * 1024 * 1024));
    defer allocator.free(input);
    var parsed = try zstd.Statechart.Plan.parse(allocator, input);
    defer parsed.deinit();
    const source = try zstd.Statechart.Plan.generateZig(allocator, parsed.value);
    errdefer allocator.free(source);
    if (!options.apply) return .{ .allocator = allocator, .exit_code = 0, .output = source };

    try writeAtomicFile(io, root, options.output_path, source);
    defer allocator.free(source);
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(source, &digest, .{});
    const receipt = .{
        .schema = "zigeffect.statechart.plan-compilation.v1",
        .schema_version = 1,
        .plan_id = parsed.value.id,
        .plan_version = parsed.value.version,
        .input = options.input_path,
        .output = options.output_path,
        .source_digest = try std.fmt.allocPrint(allocator, "sha256:{x}", .{digest}),
        .applied = true,
    };
    defer allocator.free(receipt.source_digest);
    return .{ .allocator = allocator, .exit_code = 0, .output = try std.json.Stringify.valueAlloc(allocator, receipt, .{}) };
}

fn runStatechartStudioArtifactAlloc(allocator: std.mem.Allocator, io: std.Io, base_dir: std.Io.Dir, options: StatechartOptions) !RunResult {
    var root = try openTargetDir(io, base_dir, options.root);
    defer root.close(io);
    const input = try root.readFileAlloc(io, options.input_path, allocator, .limited(4 * 1024 * 1024));
    defer allocator.free(input);
    const output = switch (options.operation) {
        .propose => artifact: {
            var parsed = try std.json.parseFromSlice(zstd.Statechart.Studio.ProposalInput, allocator, input, .{ .ignore_unknown_fields = false });
            defer parsed.deinit();
            var artifact = try zstd.Statechart.Studio.createProposal(allocator, parsed.value);
            defer artifact.deinit();
            break :artifact try zstd.Statechart.Studio.formatProposalJson(allocator, artifact.value);
        },
        .verify => artifact: {
            var parsed = try std.json.parseFromSlice(zstd.Statechart.Studio.ProofInput, allocator, input, .{ .ignore_unknown_fields = false });
            defer parsed.deinit();
            var artifact = try zstd.Statechart.Studio.createProof(allocator, parsed.value);
            defer artifact.deinit();
            break :artifact try zstd.Statechart.Studio.formatProofJson(allocator, artifact.value);
        },
        .review => artifact: {
            var parsed = try std.json.parseFromSlice(zstd.Statechart.Studio.ReviewInput, allocator, input, .{ .ignore_unknown_fields = false });
            defer parsed.deinit();
            var artifact = try zstd.Statechart.Studio.createReview(allocator, parsed.value);
            defer artifact.deinit();
            break :artifact try zstd.Statechart.Studio.formatReviewJson(allocator, artifact.value);
        },
        .approve => artifact: {
            var parsed = try std.json.parseFromSlice(zstd.Statechart.Studio.ApprovalInput, allocator, input, .{ .ignore_unknown_fields = false });
            defer parsed.deinit();
            var artifact = try zstd.Statechart.Studio.createApproval(allocator, parsed.value);
            defer artifact.deinit();
            break :artifact try zstd.Statechart.Studio.formatApprovalJson(allocator, artifact.value);
        },
        .application => artifact: {
            const ApplicationCommandInput = struct {
                proposal: zstd.Statechart.Studio.Proposal,
                proof: zstd.Statechart.Studio.Proof,
                review: zstd.Statechart.Studio.Review,
                approval: zstd.Statechart.Studio.Approval,
                application: zstd.Statechart.Studio.ApplicationInput,
            };
            var parsed = try std.json.parseFromSlice(ApplicationCommandInput, allocator, input, .{ .ignore_unknown_fields = false });
            defer parsed.deinit();
            try parsed.value.proposal.validateIntegrity(allocator);
            try parsed.value.proof.validateIntegrity(allocator);
            try parsed.value.review.validateIntegrity(allocator);
            try parsed.value.approval.validateIntegrity(allocator);
            try parsed.value.approval.validateBindingWithReview(parsed.value.proposal, parsed.value.proof, parsed.value.review, parsed.value.application.applied_ms);
            var artifact = try zstd.Statechart.Studio.createApplicationReceipt(allocator, parsed.value.application);
            defer artifact.deinit();
            try artifact.value.validateBinding(parsed.value.proposal, parsed.value.approval);
            break :artifact try zstd.Statechart.Studio.formatApplicationJson(allocator, artifact.value);
        },
        else => unreachable,
    };
    errdefer allocator.free(output);
    if (options.apply) try writeAtomicFile(io, root, options.output_path, output);
    return .{ .allocator = allocator, .exit_code = 0, .output = output };
}

fn runStatechartPatternsAlloc(allocator: std.mem.Allocator) !RunResult {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, "{\"schema\":\"zigeffect.statechart.pattern-catalog.v1\",\"patterns\":[");
    inline for (std.meta.tags(zstd.Statechart.Plan.PatternKind), 0..) |kind, index| {
        if (index != 0) try output.append(allocator, ',');
        const encoded = try std.json.Stringify.valueAlloc(allocator, @tagName(kind), .{});
        defer allocator.free(encoded);
        try output.appendSlice(allocator, encoded);
    }
    try output.appendSlice(allocator, "]}");
    return .{ .allocator = allocator, .exit_code = 0, .output = try output.toOwnedSlice(allocator) };
}

fn runStatechartPatternAlloc(allocator: std.mem.Allocator, options: StatechartOptions) !RunResult {
    var expansion = try zstd.Statechart.Plan.expandPattern(allocator, options.pattern_kind.?, options.namespace);
    defer expansion.deinit();
    const plan = zstd.Statechart.Plan.WorkflowPlan{
        .schema = zstd.Statechart.Plan.workflow_plan_schema,
        .schema_version = zstd.Statechart.Plan.workflow_plan_schema_version,
        .id = options.namespace,
        .version = 1,
        .initial = expansion.states[0].id,
        .description = "ZigEffect reusable agentic workflow pattern",
        .states = expansion.states,
        .transitions = expansion.transitions,
        .invariants = expansion.invariants,
    };
    try plan.validate();
    return .{ .allocator = allocator, .exit_code = 0, .output = try std.json.Stringify.valueAlloc(allocator, plan, .{ .whitespace = if (options.json) .minified else .indent_2 }) };
}

fn runUpgradeAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    options: UpgradeOptions,
) !RunResult {
    var project_dir = try openTargetDir(io, base_dir, options.root);
    defer project_dir.close(io);
    const manifest_text = try project_dir.readFileAlloc(io, "zigeffect.project.json", allocator, .limited(4 * 1024 * 1024));
    defer allocator.free(manifest_text);
    var manifest = try distribution.parseMigratableManifest(allocator, manifest_text);
    defer manifest.deinit();

    var expected = try generatePlan(allocator, .{
        .kind = manifest.parsed.value.kind,
        .name = manifest.parsed.value.name,
        .target = ".",
        .zigeffect_path = manifest.parsed.value.dependencies.zigeffect,
        .zigeffect_std_path = manifest.parsed.value.dependencies.zigeffect_std,
    });
    defer expected.deinit();
    const expected_state_file = findGeneratedFile(expected, distribution.scaffold_state_path) orelse return error.MissingScaffoldState;

    const old_state_text = try readOptionalFileAlloc(allocator, io, project_dir, distribution.scaffold_state_path, 4 * 1024 * 1024);
    defer if (old_state_text) |text| allocator.free(text);
    var old_state: ?distribution.ParsedState = null;
    defer if (old_state) |*state| state.deinit();
    if (old_state_text) |text| {
        old_state = try distribution.parseState(allocator, text);
        if (!std.mem.eql(u8, old_state.?.value.project, manifest.parsed.value.name) or old_state.?.value.kind != manifest.parsed.value.kind) {
            return error.ScaffoldStateProjectMismatch;
        }
    }

    var paths = std.ArrayList(UpgradePath).empty;
    defer paths.deinit(allocator);
    var created: usize = 0;
    var updated: usize = 0;
    var unchanged: usize = 0;
    var conflicts: usize = 0;
    var user_owned_preserved: usize = 0;

    for (expected.files.items) |file| {
        if (std.mem.eql(u8, file.path, distribution.scaffold_state_path) or std.mem.eql(u8, file.path, "zigeffect.project.json")) continue;
        if (!distribution.isToolOwnedPath(file.path)) {
            user_owned_preserved += 1;
            continue;
        }
        const current = try readOptionalFileAlloc(allocator, io, project_dir, file.path, 4 * 1024 * 1024);
        defer if (current) |text| allocator.free(text);
        const action: UpgradeAction = action: {
            if (current == null) {
                created += 1;
                break :action .create;
            }
            if (std.mem.eql(u8, current.?, file.content)) {
                unchanged += 1;
                break :action .unchanged;
            }
            if (old_state) |state| {
                if (state.value.managedFile(file.path)) |managed| {
                    if (distribution.digestMatches(current.?, managed.sha256)) {
                        updated += 1;
                        break :action .update;
                    }
                }
            }
            conflicts += 1;
            break :action .conflict;
        };
        try paths.append(allocator, .{ .path = file.path, .action = action });
    }

    if (manifest.migrated) {
        updated += 1;
        try paths.append(allocator, .{ .path = "zigeffect.project.json", .action = .migrate });
    }
    const state_action: UpgradeAction = if (old_state_text == null)
        .create
    else if (std.mem.eql(u8, old_state_text.?, expected_state_file.content))
        .unchanged
    else
        .update;
    switch (state_action) {
        .create => created += 1,
        .update => updated += 1,
        .unchanged => unchanged += 1,
        else => unreachable,
    }
    try paths.append(allocator, .{ .path = distribution.scaffold_state_path, .action = state_action });
    std.mem.sort(UpgradePath, paths.items, {}, lessThanUpgradePath);

    const state_adoption = old_state == null;
    const has_changes = created != 0 or updated != 0;
    const status: []const u8 = if (conflicts != 0)
        "conflict"
    else if (!has_changes)
        "current"
    else if (options.apply)
        "applied"
    else
        "planned";

    if (options.apply and conflicts == 0 and has_changes) {
        var writes = zstd.Project.FilePlan.init(allocator);
        defer writes.deinit();
        for (paths.items) |item| {
            if (item.action != .create and item.action != .update and item.action != .migrate) continue;
            if (std.mem.eql(u8, item.path, "zigeffect.project.json")) {
                const canonical = try manifest.parsed.value.jsonAlloc(allocator);
                defer allocator.free(canonical);
                try writes.add(item.path, canonical);
            } else {
                const generated = findGeneratedFile(expected, item.path) orelse return error.MissingUpgradeContent;
                try writes.add(item.path, generated.content);
            }
        }
        try writes.sort();
        _ = try writePlan(io, base_dir, options.root, writes, .{ .force = true });
    }

    const report = UpgradeReport{
        .project = manifest.parsed.value.name,
        .kind = manifest.parsed.value.kind,
        .from_project_schema = manifest.original_schema,
        .from_template_version = if (old_state) |state| state.value.template_version else null,
        .status = status,
        .dry_run = !options.apply,
        .state_adoption = state_adoption,
        .created = created,
        .updated = updated,
        .unchanged = unchanged,
        .conflicts = conflicts,
        .user_owned_preserved = user_owned_preserved,
        .paths = paths.items,
    };
    const output = if (options.json)
        try std.json.Stringify.valueAlloc(allocator, report, .{})
    else
        try formatUpgradeReportAlloc(allocator, report);
    return .{ .allocator = allocator, .exit_code = if (conflicts == 0) 0 else 3, .output = output };
}

fn formatUpgradeReportAlloc(allocator: std.mem.Allocator, report: UpgradeReport) ![]u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try output.print(allocator, "{s}: {s} (created={d} updated={d} conflicts={d} preserved={d})\n", .{
        report.project,
        report.status,
        report.created,
        report.updated,
        report.conflicts,
        report.user_owned_preserved,
    });
    for (report.paths) |item| try output.print(allocator, "- {s}: {s}\n", .{ @tagName(item.action), item.path });
    return output.toOwnedSlice(allocator);
}

fn readOptionalFileAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    path: []const u8,
    limit: usize,
) !?[]u8 {
    return dir.readFileAlloc(io, path, allocator, .limited(limit)) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
}

fn findGeneratedFile(plan: zstd.Project.FilePlan, path: []const u8) ?zstd.Project.GeneratedFile {
    for (plan.files.items) |file| {
        if (std.mem.eql(u8, file.path, path)) return file;
    }
    return null;
}

fn lessThanUpgradePath(_: void, left: UpgradePath, right: UpgradePath) bool {
    return std.mem.order(u8, left.path, right.path) == .lt;
}

fn runProjectAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    options: ProjectOptions,
) !RunResult {
    var project_dir = try openTargetDir(io, base_dir, options.root);
    defer project_dir.close(io);
    const manifest_text = try project_dir.readFileAlloc(io, "zigeffect.project.json", allocator, .limited(4 * 1024 * 1024));
    defer allocator.free(manifest_text);
    var parsed = try zstd.Project.parseManifest(allocator, manifest_text);
    defer parsed.deinit();
    var effective_options = options;
    effective_options.evidence_time_ms = realTimestampMs(io);
    var capabilities = try assessCapabilitiesVerifiedAlloc(
        allocator,
        parsed.value,
        effective_options.profile,
        effective_options.evidence_time_ms,
        .{ .io = io, .dir = project_dir },
    );
    defer capabilities.deinit();

    if (options.operation == .check and parsed.value.execution_posture == .production and capabilities.gaps != 0) {
        const output = try projectReceiptVerifiedAlloc(
            allocator,
            effective_options,
            parsed.value,
            "check",
            "failed",
            1,
            "production capability requirements are unresolved",
            "",
            "",
            .{ .io = io, .dir = project_dir },
        );
        return .{ .allocator = allocator, .exit_code = 1, .output = output };
    }
    if (options.operation == .check and options.agent) {
        const result = try safety.runProjectCheckAlloc(allocator, io, project_dir, .{});
        return safetyResult(result);
    }

    if (options.operation == .show) {
        const canonical = try parsed.value.jsonAlloc(allocator);
        return .{ .allocator = allocator, .exit_code = 0, .output = canonical };
    }
    if (options.operation == .validate) {
        const output = try projectReceiptVerifiedAlloc(allocator, effective_options, parsed.value, "validate", "passed", 0, "manifest valid", "", "", .{ .io = io, .dir = project_dir });
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
        const output = try projectReceiptVerifiedAlloc(allocator, effective_options, parsed.value, "doctor", status, missing, detail, "", "", .{ .io = io, .dir = project_dir });
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
    const receipt_options = ProjectOptions{
        .operation = options.operation,
        .root = options.root,
        .json = true,
        .profile = effective_options.profile,
        .evidence_time_ms = effective_options.evidence_time_ms,
    };
    const receipt_json = try projectReceiptVerifiedAlloc(
        allocator,
        receipt_options,
        parsed.value,
        command_id,
        status,
        exit_code,
        if (exit_code == 0) "manifest-owned command passed" else "manifest-owned command failed",
        process_result.stdout,
        process_result.stderr,
        .{ .io = io, .dir = project_dir },
    );
    errdefer allocator.free(receipt_json);
    try persistProjectCommandReceipt(allocator, io, base_dir, options.root, command_id, parsed.value.name, receipt_json, options.operation == .dev);
    const output = if (options.json)
        receipt_json
    else output: {
        defer allocator.free(receipt_json);
        break :output try projectReceiptVerifiedAlloc(
            allocator,
            effective_options,
            parsed.value,
            command_id,
            status,
            exit_code,
            if (exit_code == 0) "manifest-owned command passed" else "manifest-owned command failed",
            process_result.stdout,
            process_result.stderr,
            .{ .io = io, .dir = project_dir },
        );
    };
    return .{ .allocator = allocator, .exit_code = if (exit_code == 0) 0 else 1, .output = output };
}

fn runTestAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    options: TestOptions,
    environment: ?*const std.process.Environ.Map,
) !RunResult {
    var project_dir = try openTargetDir(io, base_dir, options.root);
    defer project_dir.close(io);
    const manifest_text = try project_dir.readFileAlloc(io, "zigeffect.project.json", allocator, .limited(4 * 1024 * 1024));
    defer allocator.free(manifest_text);
    var parsed = try zstd.Project.parseManifest(allocator, manifest_text);
    defer parsed.deinit();

    const selected = try selectTestScenariosAlloc(allocator, parsed.value, options);
    defer allocator.free(selected);
    if (options.operation == .list or options.operation == .affected) {
        const report = .{
            .schema = "zigeffect.test-list.v1",
            .project = parsed.value.name,
            .operation = options.operation,
            .discovered = parsed.value.test_scenarios.len,
            .selected = selected.len,
            .changed = options.changed,
            .limitations = if (options.operation == .affected) &.{"selection uses declared source roots and direct component dependencies"} else &.{},
            .scenarios = selected,
        };
        const output = try std.json.Stringify.valueAlloc(allocator, report, .{ .whitespace = if (options.json) .minified else .indent_2 });
        return .{ .allocator = allocator, .exit_code = 0, .output = output };
    }
    if (options.operation == .explain) {
        if (selected.len != 1) return error.MissingScenario;
        const scenario = selected[0];
        const replay = try std.fmt.allocPrint(allocator, "zigeffect test replay {s} --seed {d} --fault none:0 --root {s} --json", .{ scenario.id, scenario.default_seed, options.root });
        defer allocator.free(replay);
        const report = .{
            .schema = "zigeffect.test-explanation.v1",
            .project = parsed.value.name,
            .scenario = scenario,
            .requirement = parsed.value.requirement(scenario.requirement).?,
            .acceptance_check = parsed.value.acceptanceCheck(scenario.acceptance_check).?,
            .command = parsed.value.command(scenario.command).?,
            .replay_command = replay,
            .evidence_paths = .{
                .latest = ".zigeffect/tests/latest.json",
                .scenario = ".zigeffect/tests/receipts/<scenario>.json",
            },
        };
        const output = try std.json.Stringify.valueAlloc(allocator, report, .{ .whitespace = if (options.json) .minified else .indent_2 });
        return .{ .allocator = allocator, .exit_code = 0, .output = output };
    }
    if (options.operation == .coverage or options.operation == .gaps) {
        return runTestCoverageAlloc(allocator, io, project_dir, parsed.value.name, selected, options);
    }
    if (options.operation == .history) return runTestHistoryAlloc(allocator, io, project_dir, parsed.value.name, options);
    if (options.operation == .snapshot) return runTestSnapshotAlloc(allocator, io, project_dir, parsed.value, options);
    if (selected.len == 0) return error.MissingScenario;
    if (options.operation == .stress) return runTestStressAlloc(allocator, io, project_dir, parsed.value, selected, options, environment);
    return runSelectedTestsAlloc(allocator, io, project_dir, parsed.value, selected, options, environment);
}

fn selectTestScenariosAlloc(allocator: std.mem.Allocator, manifest: zstd.Project.Manifest, options: TestOptions) ![]zstd.Project.TestScenario {
    var selected = std.ArrayList(zstd.Project.TestScenario).empty;
    errdefer selected.deinit(allocator);
    for (manifest.test_scenarios) |scenario| {
        if (options.scenario.len != 0 and !std.mem.eql(u8, scenario.id, options.scenario)) continue;
        if (options.requirement.len != 0 and !std.mem.eql(u8, scenario.requirement, options.requirement)) continue;
        if (options.component.len != 0 and !std.mem.eql(u8, scenario.component, options.component)) continue;
        if (options.tag.len != 0 and !containsString(scenario.tags, options.tag)) continue;
        if (options.operation == .affected and !manifest.scenarioAffectedBy(scenario, options.changed)) continue;
        try selected.append(allocator, scenario);
    }
    return selected.toOwnedSlice(allocator);
}

fn runTestCoverageAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    project_dir: std.Io.Dir,
    project: []const u8,
    selected: []const zstd.Project.TestScenario,
    options: TestOptions,
) !RunResult {
    const latest = try project_dir.readFileAlloc(io, ".zigeffect/tests/latest.json", allocator, .limited(16 * 1024 * 1024));
    defer allocator.free(latest);
    var run = try zstd.Testing.parseRunReceipt(allocator, latest);
    defer run.deinit();
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, "{\"schema\":\"zigeffect.test-coverage-query.v1\",\"project\":");
    const project_json = try std.json.Stringify.valueAlloc(allocator, project, .{});
    defer allocator.free(project_json);
    try output.appendSlice(allocator, project_json);
    try output.appendSlice(allocator, ",\"operation\":");
    const operation_json = try std.json.Stringify.valueAlloc(allocator, @tagName(options.operation), .{});
    defer allocator.free(operation_json);
    try output.appendSlice(allocator, operation_json);
    try output.appendSlice(allocator, ",\"scenarios\":[");
    var first = true;
    var required_gaps: usize = 0;
    var advisory_gaps: usize = 0;
    for (run.value.receipts) |receipt| {
        var selected_receipt = false;
        for (selected) |scenario| if (std.mem.eql(u8, scenario.id, receipt.scenario.id)) {
            selected_receipt = true;
            break;
        };
        if (!selected_receipt) continue;
        var report = try zstd.Testing.Coverage.analyzeReceiptAlloc(allocator, receipt);
        defer report.deinit();
        required_gaps += report.summary.required_gaps;
        advisory_gaps += report.summary.advisory_gaps;
        if (options.operation == .gaps and report.gaps.len == 0) continue;
        if (!first) try output.append(allocator, ',');
        first = false;
        const item = if (options.operation == .gaps)
            try std.json.Stringify.valueAlloc(allocator, .{ .scenario = receipt.scenario.id, .summary = report.summary, .gaps = report.gaps }, .{})
        else
            try std.json.Stringify.valueAlloc(allocator, .{ .scenario = receipt.scenario.id, .summary = report.summary, .targets = report.targets, .hits = report.hits, .gaps = report.gaps }, .{});
        defer allocator.free(item);
        try output.appendSlice(allocator, item);
    }
    try output.print(allocator, "],\"required_gaps\":{d},\"advisory_gaps\":{d}}}", .{ required_gaps, advisory_gaps });
    return .{ .allocator = allocator, .exit_code = if (required_gaps == 0) 0 else 1, .output = try output.toOwnedSlice(allocator) };
}

fn containsString(values: []const []const u8, expected: []const u8) bool {
    for (values) |value| if (std.mem.eql(u8, value, expected)) return true;
    return false;
}

const OwnedTestExecution = struct {
    allocator: std.mem.Allocator,
    receipt: zstd.Testing.TestReceipt,
    parsed: ?zstd.Testing.Contract.ParsedReceipt = null,
    assertions: []zstd.Testing.AssertionResult = &.{},
    owns_assertions: bool = false,
    actual: []const u8,
    replay: []const u8,
    stdout_path: []const u8,
    stderr_path: []const u8,

    fn deinit(self: *OwnedTestExecution) void {
        if (self.parsed) |*parsed| parsed.deinit();
        if (self.owns_assertions) self.allocator.free(self.assertions);
        self.allocator.free(self.actual);
        self.allocator.free(self.replay);
        self.allocator.free(self.stdout_path);
        self.allocator.free(self.stderr_path);
    }
};

fn ingestProcessReceiptAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    project_dir: std.Io.Dir,
    control: zstd.Testing.Protocol.Control,
    exit_code: usize,
    replay_command: []const u8,
) !OwnedTestExecution {
    const replay = try allocator.dupe(u8, replay_command);
    errdefer allocator.free(replay);
    const empty_actual = try allocator.dupe(u8, "");
    errdefer allocator.free(empty_actual);
    const empty_stdout = try allocator.dupe(u8, "");
    errdefer allocator.free(empty_stdout);
    const empty_stderr = try allocator.dupe(u8, "");
    errdefer allocator.free(empty_stderr);

    var parsed = if (control.process_receipt_path.len > 0)
        zstd.Testing.Protocol.readPublishedReceiptAt(allocator, io, project_dir, control.process_receipt_path) catch null
    else
        zstd.Testing.Protocol.readPublishedReceipt(allocator, io, project_dir, control.scenario.id) catch null;
    if (parsed) |*native| {
        if (zstd.Testing.Protocol.validatePublishedReceipt(native.value, control)) |_| {
            var receipt = native.value;
            receipt.replay_command = replay;
            if (exit_code != 0) receipt.status = .failed;
            try receipt.validate();
            return .{
                .allocator = allocator,
                .receipt = receipt,
                .parsed = parsed,
                .actual = empty_actual,
                .replay = replay,
                .stdout_path = empty_stdout,
                .stderr_path = empty_stderr,
            };
        } else |_| {
            native.deinit();
            parsed = null;
        }
    }

    const actual = try std.fmt.allocPrint(allocator, "exit_code={d}", .{exit_code});
    allocator.free(empty_actual);
    errdefer allocator.free(actual);
    const assertions = try allocator.alloc(zstd.Testing.AssertionResult, 1);
    errdefer allocator.free(assertions);
    assertions[0] = .{
        .id = "manifest-command-exit",
        .label = "manifest-owned test command exits successfully",
        .status = if (exit_code == 0) .passed else .failed,
        .expected = "exit_code=0 and a validated native process receipt",
        .actual = actual,
        .detail = if (exit_code == 0) "command passed but native process receipt was missing or invalid" else "manifest-owned command failed",
        .repair_hint = if (exit_code == 0) "publish through zstd.Testing.TestContext.publish" else "run the replay command and inspect the first compiler or test failure",
    };
    const receipt = zstd.Testing.TestReceipt{
        .project = control.project,
        .suite = control.scenario.component,
        .scenario = control.scenario,
        .source_revision = control.source_revision,
        .zig_version = @import("builtin").zig_version_string,
        .status = if (exit_code == 0) .incomplete else .failed,
        .required = control.scenario.required,
        .started_ms = 0,
        .ended_ms = 1,
        .seed = control.seed,
        .executor = control.executor,
        .execution = .{ .command_digest = control.command_digest, .native_receipt = false },
        .fault_kind = control.fault_kind,
        .fault_index = control.fault_index,
        .schedule_choices = control.schedule_choices,
        .assertions = assertions,
        .completeness = .{ .dropped_diagnostics = 1 },
        .replay_command = replay,
        .limitations = &.{"native process receipt missing or invalid"},
    };
    try receipt.validate();
    return .{
        .allocator = allocator,
        .receipt = receipt,
        .assertions = assertions,
        .owns_assertions = true,
        .actual = actual,
        .replay = replay,
        .stdout_path = empty_stdout,
        .stderr_path = empty_stderr,
    };
}

fn runSelectedTestsAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    project_dir: std.Io.Dir,
    manifest: zstd.Project.Manifest,
    selected: []const zstd.Project.TestScenario,
    options: TestOptions,
    environment: ?*const std.process.Environ.Map,
) !RunResult {
    var executions = std.ArrayList(OwnedTestExecution).empty;
    defer {
        for (executions.items) |*execution| execution.deinit();
        executions.deinit(allocator);
    }
    var passed: usize = 0;
    var failed: usize = 0;
    var incomplete: usize = 0;
    var unsupported: usize = 0;
    var skipped: usize = 0;
    var canceled: usize = 0;
    const run_started_ms = realTimestampMs(io);
    var capabilities = try assessCapabilitiesVerifiedAlloc(allocator, manifest, options.profile, run_started_ms, .{ .io = io, .dir = project_dir });
    defer capabilities.deinit();
    var source_identity = try sourceIdentityAlloc(allocator, io, project_dir);
    defer source_identity.deinit();
    const target_name = try builtinTargetAlloc(allocator);
    defer allocator.free(target_name);
    const manifest_digest = try zstd.Development.manifestDigestAlloc(allocator, manifest);
    defer allocator.free(manifest_digest);
    try writeAtomicFile(io, project_dir, ".zigeffect/tests/progress.jsonl", "");
    try appendTestProgress(allocator, io, project_dir, manifest, .{
        .state = "run_started",
        .source_revision = source_identity.revision,
        .selected = selected.len,
        .completed = 0,
        .timestamp_ms = run_started_ms,
    });
    for (selected) |scenario| {
        const command = manifest.command(scenario.command) orelse return error.MissingProjectCommand;
        var scenario_argv = std.ArrayList([]const u8).empty;
        defer scenario_argv.deinit(allocator);
        try scenario_argv.appendSlice(allocator, command.argv);
        const filter_option = if (scenario.native_test_filter) |filter|
            try std.fmt.allocPrint(allocator, "-Dtest-filter={s}", .{filter})
        else
            null;
        defer if (filter_option) |value| allocator.free(value);
        if (filter_option) |value| try scenario_argv.append(allocator, value);
        const seed = options.seed orelse scenario.default_seed;
        const parsed_fault = parseFaultToken(options.fault);
        const fault_kind = if (parsed_fault) |fault| fault.kind else .none;
        const fault_index = if (parsed_fault) |fault| fault.index else null;
        const command_digest = try commandDigestAlloc(allocator, scenario_argv.items);
        defer allocator.free(command_digest);
        var run_hasher = std.crypto.hash.sha2.Sha256.init(.{});
        const run_nanos = std.Io.Clock.real.now(io).nanoseconds;
        const run_thread = std.Thread.getCurrentId();
        run_hasher.update(std.mem.asBytes(&run_nanos));
        run_hasher.update(std.mem.asBytes(&run_thread));
        run_hasher.update(scenario.id);
        run_hasher.update(command_digest);
        const run_id = std.fmt.bytesToHex(run_hasher.finalResult(), .lower);
        const control_path = if (environment != null)
            try zstd.Testing.Protocol.controlRunPathAlloc(allocator, scenario.id, &run_id)
        else
            try zstd.Testing.Protocol.controlPathAlloc(allocator, scenario.id);
        defer allocator.free(control_path);
        const process_receipt_path = try zstd.Testing.Protocol.processRunReceiptPathAlloc(allocator, scenario.id, &run_id);
        defer allocator.free(process_receipt_path);
        const control = zstd.Testing.Protocol.Control{
            .project = manifest.name,
            .scenario = contractScenario(scenario),
            .seed = seed,
            .fault_kind = fault_kind,
            .fault_index = fault_index,
            .executor = "deterministic",
            .source_revision = source_identity.revision,
            .command_digest = command_digest,
            .manifest_digest = manifest_digest,
            .process_receipt_path = process_receipt_path,
        };
        try zstd.Testing.Protocol.removePublishedReceipt(io, project_dir, scenario.id);
        try zstd.Testing.Protocol.removeControlAt(io, project_dir, control_path);
        try zstd.Testing.Protocol.removePublishedReceiptAt(io, project_dir, process_receipt_path);
        try zstd.Testing.Protocol.writeControlAt(allocator, io, project_dir, control_path, control);
        defer zstd.Testing.Protocol.removeControlAt(io, project_dir, control_path) catch {};
        defer zstd.Testing.Protocol.removePublishedReceiptAt(io, project_dir, process_receipt_path) catch {};
        var child_environment: ?std.process.Environ.Map = if (environment) |parent| try parent.clone(allocator) else null;
        defer if (child_environment) |*values| values.deinit();
        if (child_environment) |*values| try values.put(zstd.Testing.Protocol.control_path_environment, control_path);
        const started_ms = realTimestampMs(io);
        try appendTestProgress(allocator, io, project_dir, manifest, .{
            .state = "scenario_started",
            .scenario = scenario.id,
            .source_revision = source_identity.revision,
            .selected = selected.len,
            .completed = executions.items.len,
            .timestamp_ms = started_ms,
        });
        const process_result = try std.process.run(allocator, io, .{
            .argv = scenario_argv.items,
            .cwd = .{ .dir = project_dir },
            .environ_map = if (child_environment) |*values| values else null,
            .stdout_limit = .limited(manifest.safety.limits.max_artifact_bytes),
            .stderr_limit = .limited(manifest.safety.limits.max_artifact_bytes),
        });
        defer allocator.free(process_result.stdout);
        defer allocator.free(process_result.stderr);
        const exit_code = processExitCode(process_result.term);
        const ended_ms = realTimestampMs(io);
        const replay_fault = if (options.fault.len == 0) "none:0" else options.fault;
        const replay = try std.fmt.allocPrint(allocator, "zigeffect test replay {s} --seed {d} --fault {s} --root {s} --json", .{ scenario.id, seed, replay_fault, options.root });
        defer allocator.free(replay);
        var execution = try ingestProcessReceiptAlloc(allocator, io, project_dir, control, exit_code, replay);
        errdefer execution.deinit();
        execution.receipt.started_ms = started_ms;
        execution.receipt.ended_ms = @max(started_ms, ended_ms);
        execution.receipt.execution.tool_version = version;
        execution.receipt.execution.target = target_name;
        execution.receipt.execution.optimize = @tagName(@import("builtin").mode);
        execution.receipt.execution.worktree_dirty = source_identity.dirty;
        execution.receipt.execution.adapter_profile = capabilities.profile_id;
        execution.receipt.execution.adapters = capabilities.evidence;
        if (capabilities.gaps != 0 and execution.receipt.status == .passed) {
            execution.receipt.status = .incomplete;
        }
        if (manifest.policy.persist_raw_terminal) {
            allocator.free(execution.stdout_path);
            allocator.free(execution.stderr_path);
            execution.stdout_path = try std.fmt.allocPrint(allocator, ".zigeffect/tests/raw/{s}.stdout.txt", .{scenario.id});
            execution.stderr_path = try std.fmt.allocPrint(allocator, ".zigeffect/tests/raw/{s}.stderr.txt", .{scenario.id});
            execution.receipt.stdout_artifact = execution.stdout_path;
            execution.receipt.stderr_artifact = execution.stderr_path;
            try writeAtomicFile(io, project_dir, execution.stdout_path, process_result.stdout);
            try writeAtomicFile(io, project_dir, execution.stderr_path, process_result.stderr);
        }
        try execution.receipt.validate();
        // Replace the process-published receipt with the orchestrator-enriched
        // canonical receipt. This preserves exact target, tool, adapter,
        // worktree, and command authority for later evidence reconciliation.
        try zstd.Testing.Protocol.publishReceipt(allocator, io, project_dir, execution.receipt);
        switch (execution.receipt.status) {
            .passed => passed += 1,
            .failed => failed += 1,
            .incomplete => incomplete += 1,
            .unsupported => unsupported += 1,
            .skipped => skipped += 1,
            .canceled => canceled += 1,
        }
        const receipt_json = try execution.receipt.jsonAlloc(allocator);
        defer allocator.free(receipt_json);
        const receipt_path = try std.fmt.allocPrint(allocator, ".zigeffect/tests/receipts/{s}.json", .{scenario.id});
        defer allocator.free(receipt_path);
        try writeAtomicFile(io, project_dir, receipt_path, receipt_json);
        try executions.append(allocator, execution);
        try appendTestProgress(allocator, io, project_dir, manifest, .{
            .state = "scenario_completed",
            .scenario = scenario.id,
            .status = @tagName(executions.items[executions.items.len - 1].receipt.status),
            .source_revision = source_identity.revision,
            .selected = selected.len,
            .completed = executions.items.len,
            .timestamp_ms = ended_ms,
        });
    }
    const receipts = try allocator.alloc(zstd.Testing.TestReceipt, executions.items.len);
    defer allocator.free(receipts);
    for (executions.items, 0..) |execution, index| receipts[index] = execution.receipt;
    const regressions = try regressionCountsAlloc(allocator, io, project_dir, receipts);
    const run = zstd.Testing.TestRunReceipt{
        .project = manifest.name,
        .source_revision = source_identity.revision,
        .selection = selectionReason(options),
        .selection_value = selectionValue(options),
        .discovered = manifest.test_scenarios.len,
        .selected = selected.len,
        .passed = passed,
        .failed = failed,
        .incomplete = incomplete,
        .unsupported = unsupported,
        .skipped = skipped,
        .canceled = canceled,
        .introduced_failures = regressions.introduced,
        .resolved_failures = regressions.resolved,
        .started_ms = run_started_ms,
        .ended_ms = @max(run_started_ms, realTimestampMs(io)),
        .receipts = receipts,
        .limitations = if (source_identity.available) &.{} else &.{"Git source revision unavailable; receipt uses working-tree"},
    };
    const json = try run.jsonAlloc(allocator);
    errdefer allocator.free(json);
    try writeAtomicFile(io, project_dir, ".zigeffect/tests/latest.json", json);
    try persistTestHistory(allocator, io, project_dir, json);
    const handoff_json = try zstd.Development.testProofHandoffJsonAlloc(allocator, manifest, run);
    defer allocator.free(handoff_json);
    try writeAtomicFile(io, project_dir, ".zigeffect/handoffs/tests/latest.json", handoff_json);
    if (selected.len == 1) {
        const scenario_handoff_path = try std.fmt.allocPrint(allocator, ".zigeffect/handoffs/tests/{s}.json", .{selected[0].id});
        defer allocator.free(scenario_handoff_path);
        try writeAtomicFile(io, project_dir, scenario_handoff_path, handoff_json);
    }
    try appendTestProgress(allocator, io, project_dir, manifest, .{
        .state = "run_completed",
        .status = @tagName(run.status()),
        .source_revision = source_identity.revision,
        .selected = selected.len,
        .completed = executions.items.len,
        .timestamp_ms = run.ended_ms,
        .proof_handoff = ".zigeffect/handoffs/tests/latest.json",
    });
    const exit_code: u8 = if (failed == 0 and incomplete == 0 and unsupported == 0 and canceled == 0) 0 else 1;
    if (options.json) return .{ .allocator = allocator, .exit_code = exit_code, .output = json };
    defer allocator.free(json);
    const output = try std.fmt.allocPrint(allocator, "tests: {d} passed, {d} failed, {d} incomplete, {d} selected\nevidence: .zigeffect/tests/latest.json\n", .{ passed, failed, incomplete, selected.len });
    return .{ .allocator = allocator, .exit_code = exit_code, .output = output };
}

const RegressionCounts = struct { introduced: usize = 0, resolved: usize = 0 };

fn regressionCountsAlloc(allocator: std.mem.Allocator, io: std.Io, project_dir: std.Io.Dir, current: []const zstd.Testing.TestReceipt) !RegressionCounts {
    const previous_json = project_dir.readFileAlloc(io, ".zigeffect/tests/latest.json", allocator, .limited(16 * 1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => return .{ .introduced = countFailedReceipts(current) },
        else => return err,
    };
    defer allocator.free(previous_json);
    var previous = zstd.Testing.parseRunReceipt(allocator, previous_json) catch return .{ .introduced = countFailedReceipts(current) };
    defer previous.deinit();
    var result = RegressionCounts{};
    for (current) |receipt| if (receipt.status == .failed and !containsFailure(previous.value.receipts, receipt)) {
        result.introduced += 1;
    };
    for (previous.value.receipts) |receipt| if (receipt.status == .failed and !containsFailure(current, receipt)) {
        result.resolved += 1;
    };
    return result;
}

fn countFailedReceipts(receipts: []const zstd.Testing.TestReceipt) usize {
    var count: usize = 0;
    for (receipts) |receipt| if (receipt.status == .failed) {
        count += 1;
    };
    return count;
}

fn containsFailure(receipts: []const zstd.Testing.TestReceipt, expected: zstd.Testing.TestReceipt) bool {
    for (receipts) |receipt| {
        if (receipt.status != .failed or !std.mem.eql(u8, receipt.scenario.id, expected.scenario.id) or receipt.fault_kind != expected.fault_kind or receipt.fault_index != expected.fault_index) continue;
        const expected_assertion = firstFailedAssertion(expected);
        const actual_assertion = firstFailedAssertion(receipt);
        if (expected_assertion == null and actual_assertion == null) return true;
        if (expected_assertion != null and actual_assertion != null and std.mem.eql(u8, expected_assertion.?, actual_assertion.?)) return true;
    }
    return false;
}

fn firstFailedAssertion(receipt: zstd.Testing.TestReceipt) ?[]const u8 {
    for (receipt.assertions) |assertion| if (assertion.status == .failed) return assertion.id;
    return null;
}

fn runTestStressAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    project_dir: std.Io.Dir,
    manifest: zstd.Project.Manifest,
    selected: []const zstd.Project.TestScenario,
    options: TestOptions,
    environment: ?*const std.process.Environ.Map,
) !RunResult {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try output.print(allocator, "{{\"schema\":\"zigeffect.test-stress.v1\",\"project\":\"{s}\",\"runs_requested\":{d},\"runs\":[", .{ manifest.name, options.runs });
    var failed_runs: usize = 0;
    const base_seed = options.seed orelse if (selected.len == 0) 1 else selected[0].default_seed;
    for (0..options.runs) |index| {
        const seed = std.math.add(u64, base_seed, index) catch return error.InvalidSeed;
        var run_options = options;
        run_options.operation = .run;
        run_options.seed = seed;
        run_options.json = true;
        var result = try runSelectedTestsAlloc(allocator, io, project_dir, manifest, selected, run_options, environment);
        defer result.deinit();
        if (result.exit_code != 0) failed_runs += 1;
        if (index != 0) try output.append(allocator, ',');
        try output.appendSlice(allocator, result.output);
    }
    try output.print(allocator, "],\"failed_runs\":{d},\"passed_runs\":{d}}}", .{ failed_runs, options.runs - failed_runs });
    return .{ .allocator = allocator, .exit_code = if (failed_runs == 0) 0 else 1, .output = try output.toOwnedSlice(allocator) };
}

fn persistTestHistory(allocator: std.mem.Allocator, io: std.Io, project_dir: std.Io.Dir, run_json: []const u8) !void {
    const path = ".zigeffect/tests/history.jsonl";
    const current = project_dir.readFileAlloc(io, path, allocator, .limited(64 * 1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => try allocator.dupe(u8, ""),
        else => return err,
    };
    defer allocator.free(current);
    const next = try std.fmt.allocPrint(allocator, "{s}{s}\n", .{ current, run_json });
    defer allocator.free(next);
    try writeAtomicFile(io, project_dir, path, next);
}

const TestProgressEvent = struct {
    state: []const u8,
    scenario: []const u8 = "",
    status: []const u8 = "",
    source_revision: []const u8,
    selected: usize,
    completed: usize,
    timestamp_ms: i64,
    proof_handoff: []const u8 = "",
};

fn appendTestProgress(
    allocator: std.mem.Allocator,
    io: std.Io,
    project_dir: std.Io.Dir,
    manifest: zstd.Project.Manifest,
    event: TestProgressEvent,
) !void {
    const path = ".zigeffect/tests/progress.jsonl";
    const current = try project_dir.readFileAlloc(io, path, allocator, .limited(manifest.safety.limits.max_artifact_bytes));
    defer allocator.free(current);
    const row = try std.json.Stringify.valueAlloc(allocator, .{
        .schema = "zigeffect.test-progress.v1",
        .project = manifest.name,
        .state = event.state,
        .scenario = event.scenario,
        .status = event.status,
        .source_revision = event.source_revision,
        .selected = event.selected,
        .completed = event.completed,
        .timestamp_ms = event.timestamp_ms,
        .proof_handoff = event.proof_handoff,
    }, .{});
    defer allocator.free(row);
    const next = try std.fmt.allocPrint(allocator, "{s}{s}\n", .{ current, row });
    defer allocator.free(next);
    if (next.len > manifest.safety.limits.max_artifact_bytes) return error.ProgressArtifactLimitExceeded;
    try writeAtomicFile(io, project_dir, path, next);
}

fn runTestHistoryAlloc(allocator: std.mem.Allocator, io: std.Io, project_dir: std.Io.Dir, project: []const u8, options: TestOptions) !RunResult {
    _ = options;
    const history = project_dir.readFileAlloc(io, ".zigeffect/tests/history.jsonl", allocator, .limited(64 * 1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => try allocator.dupe(u8, ""),
        else => return err,
    };
    defer allocator.free(history);
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    const encoded_project = try std.json.Stringify.valueAlloc(allocator, project, .{});
    defer allocator.free(encoded_project);
    try output.print(allocator, "{{\"schema\":\"zigeffect.test-history.v1\",\"project\":{s},\"runs\":[", .{encoded_project});
    var count: usize = 0;
    var lines = std.mem.splitScalar(u8, history, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var parsed = try zstd.Testing.parseRunReceipt(allocator, line);
        parsed.deinit();
        if (count != 0) try output.append(allocator, ',');
        try output.appendSlice(allocator, line);
        count += 1;
    }
    try output.print(allocator, "],\"count\":{d}}}", .{count});
    return .{ .allocator = allocator, .exit_code = 0, .output = try output.toOwnedSlice(allocator) };
}

fn runTestSnapshotAlloc(allocator: std.mem.Allocator, io: std.Io, project_dir: std.Io.Dir, manifest: zstd.Project.Manifest, options: TestOptions) !RunResult {
    _ = manifest.testScenario(options.scenario) orelse return error.MissingScenario;
    const actual_path = try std.fmt.allocPrint(allocator, ".zigeffect/tests/actual/{s}.snap", .{options.scenario});
    defer allocator.free(actual_path);
    const fixture_path = try std.fmt.allocPrint(allocator, ".zigeffect/tests/snapshots/{s}.snap", .{options.scenario});
    defer allocator.free(fixture_path);
    const actual = try project_dir.readFileAlloc(io, actual_path, allocator, .limited(16 * 1024 * 1024));
    defer allocator.free(actual);
    const current = project_dir.readFileAlloc(io, fixture_path, allocator, .limited(16 * 1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => try allocator.dupe(u8, ""),
        else => return err,
    };
    defer allocator.free(current);
    var baseline = try zstd.Testing.Snapshots.captureAlloc(allocator, options.scenario, .text, current, &.{});
    defer baseline.deinit();
    var comparison = try baseline.value.compareAlloc(allocator, actual);
    defer comparison.deinit();
    var plan = try zstd.Testing.Snapshots.planUpdateAlloc(allocator, fixture_path, current, comparison);
    defer plan.deinit();
    if (options.apply) {
        try plan.verifyCurrent(allocator, current);
        try writeAtomicFile(io, project_dir, fixture_path, plan.proposed);
    }
    const report = .{
        .schema = "zigeffect.test-snapshot-update.v1",
        .project = manifest.name,
        .scenario = options.scenario,
        .equal = comparison.equal,
        .applied = options.apply,
        .path = fixture_path,
        .expected_digest = plan.expected_digest,
        .proposed_digest = plan.proposed_digest,
        .diff = comparison.diff,
    };
    const output = try std.json.Stringify.valueAlloc(allocator, report, .{ .whitespace = if (options.json) .minified else .indent_2 });
    return .{ .allocator = allocator, .exit_code = if (comparison.equal or options.apply) 0 else 2, .output = output };
}

fn contractScenario(scenario: zstd.Project.TestScenario) zstd.Testing.Scenario {
    return .{
        .id = scenario.id,
        .label = scenario.label,
        .requirement = scenario.requirement,
        .acceptance_check = scenario.acceptance_check,
        .component = scenario.component,
        .command = scenario.command,
        .source_roots = scenario.source_roots,
        .tags = scenario.tags,
        .default_seed = scenario.default_seed,
        .fault_profile = @enumFromInt(@intFromEnum(scenario.fault_profile)),
        .required = scenario.required,
    };
}

const ParsedFault = struct { kind: zstd.Testing.Contract.FaultKind, index: usize };
fn parseFaultToken(value: []const u8) ?ParsedFault {
    if (value.len == 0) return null;
    const colon = std.mem.indexOfScalar(u8, value, ':') orelse return null;
    return .{
        .kind = std.meta.stringToEnum(zstd.Testing.Contract.FaultKind, value[0..colon]) orelse return null,
        .index = std.fmt.parseInt(usize, value[colon + 1 ..], 10) catch return null,
    };
}

fn selectionReason(options: TestOptions) zstd.Testing.Contract.SelectionReason {
    if (options.operation == .replay) return .replay;
    if (options.operation == .affected) return .affected;
    if (options.scenario.len != 0) return .scenario;
    if (options.requirement.len != 0) return .requirement;
    if (options.component.len != 0) return .component;
    if (options.tag.len != 0) return .tag;
    return .all;
}

fn selectionValue(options: TestOptions) []const u8 {
    if (options.operation == .affected) return options.changed;
    if (options.requirement.len != 0) return options.requirement;
    if (options.component.len != 0) return options.component;
    if (options.tag.len != 0) return options.tag;
    if (options.scenario.len != 0) return options.scenario;
    return "";
}

fn writeAtomicFile(io: std.Io, dir: std.Io.Dir, path: []const u8, content: []const u8) !void {
    if (std.mem.lastIndexOfScalar(u8, path, '/')) |slash| try dir.createDirPath(io, path[0..slash]);
    for (0..1024) |slot| {
        if (try writeAtomicFileSlot(io, dir, path, content, slot)) return;
    }
    return error.AtomicTemporaryPathExhausted;
}

fn writeAtomicFileSlot(io: std.Io, dir: std.Io.Dir, path: []const u8, content: []const u8, slot: usize) !bool {
    const temporary = try std.fmt.allocPrint(std.heap.page_allocator, "{s}.tmp.{d}", .{ path, slot });
    defer std.heap.page_allocator.free(temporary);
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

fn realTimestampMs(io: std.Io) i64 {
    const nanos = std.Io.Clock.real.now(io).nanoseconds;
    const millis = @divTrunc(nanos, std.time.ns_per_ms);
    return std.math.cast(i64, millis) orelse if (millis < 0) std.math.minInt(i64) else std.math.maxInt(i64);
}

fn commandDigestAlloc(allocator: std.mem.Allocator, argv: []const []const u8) ![]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    for (argv) |arg| {
        hasher.update(arg);
        hasher.update(&.{0});
    }
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    hasher.final(&digest);
    return std.fmt.allocPrint(allocator, "sha256:{x}", .{digest});
}

fn sourceIdentityAlloc(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir) !zstd.Development.SourceIdentity {
    return zstd.Development.sourceIdentityAlloc(allocator, io, dir, .{});
}

fn builtinTargetAlloc(allocator: std.mem.Allocator) ![]u8 {
    const builtin = @import("builtin");
    return std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{
        @tagName(builtin.target.cpu.arch),
        @tagName(builtin.target.os.tag),
        @tagName(builtin.target.abi),
    });
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
    var source_identity = try sourceIdentityAlloc(allocator, io, project_dir);
    defer source_identity.deinit();
    var derived = try deriveAgentProtocol(allocator, io, project_dir, parsed.value, options.profile, realTimestampMs(io), source_identity.revision);
    defer derived.deinit();

    const output = switch (options.operation) {
        .status => try derived.status.jsonAlloc(allocator),
        .requirements => try encodeRequirementQueryAlloc(allocator, parsed.value.requirements, options.jsonl),
        .checks => try encodeAcceptanceQueryAlloc(allocator, parsed.value.acceptance_checks, options.jsonl),
        .evidence => try encodeCollectionAlloc(allocator, "zigeffect.evidence-query.v1", derived.evidence, options.jsonl),
        .next => try encodeCollectionAlloc(allocator, "zigeffect.next-action-query.v1", derived.actions, options.jsonl),
        .context => context: {
            const changed_paths: []const []const u8 = if (options.changed.len == 0) &.{} else &.{options.changed};
            break :context try zstd.Development.compileProjectContextJsonAlloc(allocator, io, project_dir, parsed.value, .{
                .task_id = options.task,
                .source_revision = source_identity.revision,
                .source_dirty = source_identity.dirty,
                .changed_paths = changed_paths,
                .byte_budget = options.budget,
            });
        },
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
                .adapter_profile = derived.adapter_profile,
                .adapters = derived.adapters,
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
    adapter_profile: []const u8,
    adapters: []zstd.Capability.AdapterEvidence,
    reconciliation: ?zstd.Development.Reconciliation = null,
    owned_ids: std.ArrayList([]u8) = .empty,
    tasks_owned: bool = false,
    evidence_owned: bool = false,
    actions_owned: bool = false,
    blockers_owned: bool = false,
    adapters_owned: bool = false,

    fn deinit(self: *DerivedProtocol) void {
        for (self.owned_ids.items) |id| self.allocator.free(id);
        self.owned_ids.deinit(self.allocator);
        if (self.tasks_owned) self.allocator.free(self.tasks);
        if (self.evidence_owned) self.allocator.free(self.evidence);
        if (self.actions_owned) self.allocator.free(self.actions);
        if (self.blockers_owned) self.allocator.free(self.blockers);
        if (self.adapters_owned) self.allocator.free(self.adapters);
        if (self.reconciliation) |*value| value.deinit();
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
    requested_profile: []const u8,
    evidence_time_ms: i64,
    current_source_revision: []const u8,
) !DerivedProtocol {
    var result = DerivedProtocol{
        .allocator = allocator,
        .status = undefined,
        .tasks = undefined,
        .evidence = undefined,
        .actions = undefined,
        .blockers = undefined,
        .adapter_profile = undefined,
        .adapters = undefined,
    };
    errdefer result.deinitPartial();
    const capabilities = try assessCapabilitiesVerifiedAlloc(allocator, manifest, requested_profile, evidence_time_ms, .{ .io = io, .dir = project_dir });
    result.adapter_profile = capabilities.profile_id;
    result.adapters = capabilities.evidence;
    result.adapters_owned = true;
    var collected_evidence = try zstd.Development.collectEvidenceAlloc(
        allocator,
        io,
        project_dir,
        manifest,
        current_source_revision,
        manifest.safety.limits.max_artifact_bytes,
    );
    defer collected_evidence.deinit();
    result.reconciliation = try zstd.Development.reconcileAlloc(
        allocator,
        manifest,
        collected_evidence.run(),
        current_source_revision,
    );
    const reconciled = &result.reconciliation.?;
    const open_requirements = reconciled.requirements_open;
    var blocked_requirements: usize = 0;
    for (reconciled.requirements) |requirement| if (requirement.state == .blocked) {
        blocked_requirements += 1;
    };
    result.tasks = try allocator.alloc(zstd.Project.Protocol.Task, open_requirements);
    result.tasks_owned = true;
    result.actions = try allocator.alloc(zstd.Project.Protocol.NextAction, open_requirements);
    result.actions_owned = true;
    result.blockers = try allocator.alloc([]const u8, blocked_requirements);
    result.blockers_owned = true;
    var task_index: usize = 0;
    var blocker_index: usize = 0;
    for (reconciled.requirements) |observed| {
        if (observed.state == .satisfied) continue;
        const requirement = manifest.requirement(observed.id) orelse return error.InvalidRequirement;
        const task_id = try std.fmt.allocPrint(allocator, "task-{s}", .{observed.id});
        try result.owned_ids.append(allocator, task_id);
        const action_id = try std.fmt.allocPrint(allocator, "next-{s}", .{requirement.id});
        try result.owned_ids.append(allocator, action_id);
        result.tasks[task_index] = .{
            .id = task_id,
            .requirement = observed.id,
            .component = requirement.component,
            .summary = requirement.summary,
            .status = switch (observed.state) {
                .pending => if (requirement.status == .planned) .planned else .active,
                .blocked => .blocked,
                .failed, .stale, .incomplete => .active,
                .satisfied => unreachable,
            },
        };
        result.actions[task_index] = .{
            .id = action_id,
            .requirement = observed.id,
            .component = requirement.component,
            .summary = requirement.summary,
            .command = if (hasScenarioForRequirement(manifest, observed.id)) "test" else if (manifest.command("check") != null) "check" else null,
        };
        task_index += 1;
        if (observed.state == .blocked) {
            result.blockers[blocker_index] = requirement.summary;
            blocker_index += 1;
        }
    }

    var evidence_count: usize = 0;
    for (reconciled.checks) |check| if (check.state == .passed and check.evidence_ref.len != 0) {
        evidence_count += 1;
    };
    result.evidence = try allocator.alloc(zstd.Project.Protocol.Evidence, evidence_count);
    result.evidence_owned = true;
    var evidence_index: usize = 0;
    for (reconciled.checks) |check| {
        if (check.state != .passed or check.evidence_ref.len == 0) continue;
        const evidence_id = try std.fmt.allocPrint(allocator, "evidence-{s}", .{check.id});
        try result.owned_ids.append(allocator, evidence_id);
        result.evidence[evidence_index] = .{
            .id = evidence_id,
            .requirement = check.requirement,
            .acceptance_check = check.id,
            .component = check.component,
            .kind = .test_result,
            .artifact = check.evidence_ref,
            .summary = check.reason,
        };
        evidence_index += 1;
    }
    result.status = .{
        .project = manifest.name,
        .requirements_total = manifest.requirements.len,
        .requirements_open = reconciled.requirements_open,
        .checks_total = manifest.acceptance_checks.len,
        .checks_pending = reconciled.checks_pending,
        .checks_failed = reconciled.checks_failed,
        .tasks = result.tasks,
        .evidence = result.evidence,
        .next_actions = result.actions,
        .adapter_profile = result.adapter_profile,
        .adapters = result.adapters,
    };
    try result.status.validate();
    return result;
}

fn hasScenarioForRequirement(manifest: zstd.Project.Manifest, requirement_id: []const u8) bool {
    for (manifest.test_scenarios) |scenario| if (std.mem.eql(u8, scenario.requirement, requirement_id)) return true;
    return false;
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
        .conformance => try safety.runConformanceScoreAlloc(allocator, io, project_dir, options.fixture),
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
        &[_]zstd.Project.Capability{ .cli, .http, .sql, .config, .observability, .agent, .workbench, .causal_graph, .statecharts }
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
    return projectReceiptVerifiedAlloc(allocator, options, manifest, command, status, code, detail, stdout, stderr, null);
}

const CapabilityVerification = struct {
    io: std.Io,
    dir: std.Io.Dir,
};

fn projectReceiptVerifiedAlloc(
    allocator: std.mem.Allocator,
    options: ProjectOptions,
    manifest: zstd.Project.Manifest,
    command: []const u8,
    status: []const u8,
    code: usize,
    detail: []const u8,
    stdout: []const u8,
    stderr: []const u8,
    verification: ?CapabilityVerification,
) ![]u8 {
    var capabilities = try assessCapabilitiesVerifiedAlloc(
        allocator,
        manifest,
        options.profile,
        options.evidence_time_ms,
        verification,
    );
    defer capabilities.deinit();
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
        .adapter_profile = capabilities.profile_id,
        .adapters = capabilities.evidence,
        .capability_gaps = capabilities.gaps,
    }, .{});
    return std.fmt.allocPrint(allocator, "{s}: {s} ({s}, code={d}, capability_gaps={d})\n{s}\n{s}", .{ manifest.name, command, status, code, capabilities.gaps, safe_stdout, safe_stderr });
}

const CapabilityAssessment = struct {
    allocator: std.mem.Allocator,
    profile_id: []const u8,
    evidence: []zstd.Capability.AdapterEvidence,
    gaps: usize,

    fn deinit(self: *CapabilityAssessment) void {
        self.allocator.free(self.evidence);
        self.* = undefined;
    }
};

fn assessCapabilitiesAlloc(
    allocator: std.mem.Allocator,
    manifest: zstd.Project.Manifest,
    requested_profile: []const u8,
    evidence_time_ms: i64,
) !CapabilityAssessment {
    return assessCapabilitiesVerifiedAlloc(allocator, manifest, requested_profile, evidence_time_ms, null);
}

fn assessCapabilitiesVerifiedAlloc(
    allocator: std.mem.Allocator,
    manifest: zstd.Project.Manifest,
    requested_profile: []const u8,
    evidence_time_ms: i64,
    verification: ?CapabilityVerification,
) !CapabilityAssessment {
    if (manifest.capability_requirements.len == 0) {
        return .{
            .allocator = allocator,
            .profile_id = if (manifest.execution_posture == .local) "local" else "",
            .evidence = try allocator.alloc(zstd.Capability.AdapterEvidence, 0),
            .gaps = 0,
        };
    }

    const profile = if (requested_profile.len != 0)
        manifest.adapterProfile(requested_profile)
    else if (manifest.adapter_profiles.len == 1)
        manifest.adapter_profiles[0]
    else
        null;
    if (profile == null) {
        return .{
            .allocator = allocator,
            .profile_id = requested_profile,
            .evidence = try allocator.alloc(zstd.Capability.AdapterEvidence, 0),
            .gaps = manifest.capability_requirements.len,
        };
    }

    const selected = profile.?;
    const catalog = try allocator.alloc(zstd.Capability.Descriptor, zstd.Capability.Builtin.all.len + manifest.capability_descriptors.len);
    defer allocator.free(catalog);
    @memcpy(catalog[0..zstd.Capability.Builtin.all.len], zstd.Capability.Builtin.all);
    @memcpy(catalog[zstd.Capability.Builtin.all.len..], manifest.capability_descriptors);
    const evidence = try manifest.resolveProfileAlloc(
        allocator,
        selected.id,
        catalog,
        evidence_time_ms,
    );
    var gaps = manifest.capability_requirements.len -| evidence.len;
    for (evidence) |*adapter| {
        if (adapter.result == .matched and verification != null and adapter.maturity.satisfies(.production_candidate)) {
            if (!try verifyCapabilityEvidence(allocator, verification.?, adapter.*)) {
                adapter.result = .missing_live_conformance;
            }
        }
        if (adapter.result != .matched) gaps += 1;
    }
    return .{
        .allocator = allocator,
        .profile_id = selected.id,
        .evidence = evidence,
        .gaps = gaps,
    };
}

fn verifyCapabilityEvidence(
    allocator: std.mem.Allocator,
    verification: CapabilityVerification,
    evidence: zstd.Capability.AdapterEvidence,
) !bool {
    if (evidence.conformance_authority != .live_external or evidence.conformance_receipt.len == 0 or evidence.content_sha256.len != 71) return false;
    const bytes = verification.dir.readFileAlloc(verification.io, evidence.conformance_receipt, allocator, .limited(4 * 1024 * 1024)) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return false,
    };
    defer allocator.free(bytes);
    if (zstd.Secrets.containsSecret(bytes)) return false;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    if (!std.mem.eql(u8, evidence.content_sha256[7..], &hex)) return false;
    const LiveReceipt = struct {
        schema: []const u8,
        adapter: []const u8,
        status: []const u8,
        observed_at_ms: i64,
    };
    var parsed = std.json.parseFromSlice(LiveReceipt, allocator, bytes, .{ .ignore_unknown_fields = true }) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return false,
    };
    defer parsed.deinit();
    return std.mem.eql(u8, parsed.value.schema, "zigeffect.live-conformance-receipt.v1") and
        parsed.value.adapter.len != 0 and
        std.mem.eql(u8, parsed.value.status, "passed") and
        parsed.value.observed_at_ms == evidence.observed_at_ms;
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
        .statechart => std.fmt.allocPrint(allocator, "src/statecharts/{s}.zig", .{options.name}),
        .statechart_actor => std.fmt.allocPrint(allocator, "src/actors/{s}.zig", .{options.name}),
        .durable_statechart => std.fmt.allocPrint(allocator, "src/workflows/{s}.zig", .{options.name}),
        .statechart_test => std.fmt.allocPrint(allocator, "test/{s}_statechart_test.zig", .{options.name}),
        .@"test" => std.fmt.allocPrint(allocator, "test/{s}_test.zig", .{options.name}),
    };
}

fn generatedModuleAlloc(allocator: std.mem.Allocator, options: GenerateOptions) ![]u8 {
    const body = switch (options.kind) {
        .service => return std.fmt.allocPrint(allocator,
            \\// Generated service module: {s}
            \\const std = @import("std");
            \\const zstd = @import("zigeffect_std");
            \\const kernel = zstd.fx.kernel;
            \\
            \\pub const ServiceApi = struct {{
            \\    pub const operations: []const []const u8 = &.{{"Service.execute"}};
            \\    pub fn execute(_: *@This(), input: []const u8) []const u8 {{ return input; }}
            \\}};
            \\
            \\pub const Service = kernel.Service("generated/{s}", ServiceApi);
            \\const ExecuteBase = kernel.Effect([]const u8, std.mem.Allocator.Error, .{{Service}});
            \\const ExecuteProgram = ExecuteBase.Stateful([]const u8);
            \\pub const Execute = kernel.NamedEffect(ExecuteProgram);
            \\
            \\pub fn execute(input: []const u8) Execute {{
            \\    return ExecuteProgram.init(input, struct {{
            \\        fn run(value: []const u8, ctx: *ExecuteProgram.Context) std.mem.Allocator.Error![]const u8 {{
            \\            return ctx.service(Service).execute(value);
            \\        }}
            \\    }}.run).named("Service.execute");
            \\}}
        , .{ options.name, options.name }),
        .layer =>
        \\const zstd = @import("zigeffect_std");
        \\
        \\pub fn layer(comptime Tag: type, value: Tag.API) @TypeOf(zstd.fx.kernel.Layer.succeed(Tag, value)) {
        \\    return zstd.fx.kernel.Layer.succeed(Tag, value);
        \\}
        ,
        .schema => "const zstd = @import(\"zigeffect_std\");\npub const schema = zstd.Schema.string().nonEmpty();\n",
        .cli => "const zstd = @import(\"zigeffect_std\");\npub const command = zstd.Cli.CommandSpec{ .name = \"generated\", .description = \"generated command\" };\n",
        .http => "const zstd = @import(\"zigeffect_std\");\npub const health = zstd.Http.Request{ .method = \"GET\", .url = \"http://127.0.0.1/health\" };\n",
        .sql => "const zstd = @import(\"zigeffect_std\");\npub const query = zstd.Sql.Query{ .sql = \"select 1\", .binds = &.{} };\n",
        .statechart => return renderAlloc(allocator, templates.statechart_source, &.{.{ "__MACHINE_NAME__", options.name }}),
        .statechart_actor => return renderAlloc(allocator, templates.statechart_actor_source, &.{.{ "__MACHINE_NAME__", options.name }}),
        .durable_statechart => return renderAlloc(allocator, templates.durable_statechart_source, &.{.{ "__MACHINE_NAME__", options.name }}),
        .statechart_test => return renderAlloc(allocator, templates.statechart_test_source, &.{.{ "__MACHINE_NAME__", options.name }}),
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
    \\  zigeffect completions <bash|zsh|fish>
    \\  zigeffect compatibility [--root <path>] [--json]
    \\  zigeffect upgrade [--root <path>] [--dry-run|--apply] [--json]
    \\  zigeffect graph status [--root <path>] [--component <id>] [--json]
    \\  zigeffect graph since <event-id> [--limit <count>] [--root <path>] [--component <id>] [--json]
    \\  zigeffect graph <event|children> <event-id> [--root <path>] [--component <id>] [--json]
    \\  zigeffect graph path <from-event-id> <to-event-id> [--limit <count>] [--root <path>] [--component <id>] [--json]
    \\  zigeffect statechart list [--root <path>] [--component <id>] [--json]
    \\  zigeffect statechart <show|versions|instances|coverage|paths> <machine-id> [--root <path>] [--json]
    \\  zigeffect statechart <trace|explain> <instance-id> [--root <path>] [--json]
    \\  zigeffect statechart export <machine-id> --format <native|xstate|mermaid|dot> [--root <path>]
    \\  zigeffect statechart studio <machine-id> [--root <path>] [--component <id>] [--json]
    \\  zigeffect statechart <fleet|controls> [--root <path>] [--component <id>] [--json]
    \\  zigeffect statechart compile <plan.json> [--output <source.zig> --apply] [--root <path>]
    \\  zigeffect statechart <propose|verify|review|approve|application> <input.json> [--output <artifact.json> --apply] [--root <path>]
    \\  zigeffect statechart patterns [--json]
    \\  zigeffect statechart pattern <kind> [--namespace <id>] [--json]
    \\  zigeffect test list [--requirement <id>] [--component <id>] [--tag <tag>] [--json]
    \\  zigeffect test run [--scenario <id>] [--requirement <id>] [--component <id>] [--tag <tag>] [--seed <n>] [--fault <kind:index>] [--json]
    \\  zigeffect test affected --changed <path> [--json]
    \\  zigeffect test explain <scenario> [--json]
    \\  zigeffect test replay <scenario> --seed <n> --fault <kind:index> [--json]
    \\  zigeffect test snapshot <scenario> [--apply] [--json]
    \\  zigeffect test coverage [--requirement <id>] [--component <id>] [--json]
    \\  zigeffect test gaps [--requirement <id>] [--component <id>] [--json]
    \\  zigeffect test stress [--scenario <id>] [--runs <1..256>] [--seed <n>] [--json]
    \\  zigeffect test history [--json]
    \\  zigeffect new <application|service|library|package|system> <name> [options]
    \\  zigeffect add <service|library|package> <name> [options]
    \\  zigeffect generate <service|layer|schema|cli|http|sql|statechart|statechart_actor|durable_statechart|statechart_test|test> <name> --component <id> [options]
    \\  zigeffect project <show|validate|doctor|check|test|dev> [--root <path>] [--json]
    \\  zigeffect project check --agent --json [--root <path>]
    \\  zigeffect agent <status|requirements|checks|evidence|next> [--root <path>] [--jsonl]
    \\  zigeffect agent context --task <id-or-summary> [--budget <bytes>] [--changed <path>] [--root <path>] --json
    \\  zigeffect agent handoff --provider <name> --session <id> [--root <path>]
    \\  zigeffect safety explain <finding-id> [--root <path>]
    \\  zigeffect safety replay <finding-id> [--receipt <path>]
    \\  zigeffect safety baseline [--root <path>] [--receipt <path>]
    \\  zigeffect benchmark score <fixture> --json [--root <path>]
    \\  zigeffect benchmark conformance <suite> --json [--root <path>]
    \\  zigeffect benchmark run --provider <id> --command <manifest-id> [--root <path>]
    \\
    \\Options:
    \\  --target <path>               output directory (defaults to name)
    \\  --zigeffect-path <path>       manifest path to zigeffect
    \\  --zigeffect-std-path <path>   build and manifest path to zigeffect-std
    \\  --dry-run                     print the complete plan without writing
    \\  --json                        emit a stable JSON receipt
    \\  --force                       replace only files declared by the plan
    \\  --apply                       apply a conflict-free upgrade plan
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
    const real_profile = options.profile != .@"local-fake";
    const http_path = if (real_profile) try siblingAdapterPathAlloc(allocator, std_path, "zigeffect-http") else try allocator.dupe(u8, "");
    defer allocator.free(http_path);
    const postgres_path = if (real_profile) try siblingAdapterPathAlloc(allocator, std_path, "zigeffect-postgres-libpq") else try allocator.dupe(u8, "");
    defer allocator.free(postgres_path);
    const otel_path = if (real_profile) try siblingAdapterPathAlloc(allocator, std_path, "zigeffect-otel") else try allocator.dupe(u8, "");
    defer allocator.free(otel_path);
    const adapter_zon = if (real_profile) try std.fmt.allocPrint(allocator, "        .zigeffect_http = .{{ .path = \"{s}\" }},\n        .zigeffect_postgres_libpq = .{{ .path = \"{s}\" }},\n        .zigeffect_otel = .{{ .path = \"{s}\" }},", .{ http_path, postgres_path, otel_path }) else try allocator.dupe(u8, "");
    defer allocator.free(adapter_zon);

    try addRenderedAt(plan, prefix, "build.zig", templates.executable_build, &.{
        .{ "__PROJECT_NAME__", component_name },
        .{ "__ADAPTER_DEPENDENCIES__", if (real_profile) "    const zigeffect_http = b.dependency(\"zigeffect_http\", .{ .target = target, .optimize = optimize }).module(\"zigeffect_http\");\n    const zigeffect_postgres_libpq = b.dependency(\"zigeffect_postgres_libpq\", .{ .target = target, .optimize = optimize }).module(\"zigeffect_postgres_libpq\");\n    const zigeffect_otel = b.dependency(\"zigeffect_otel\", .{ .target = target, .optimize = optimize }).module(\"zigeffect_otel\");" else "" },
        .{ "__ADAPTER_IMPORTS__", if (real_profile) "    app.addImport(\"zigeffect_http\", zigeffect_http);\n    app.addImport(\"zigeffect_postgres_libpq\", zigeffect_postgres_libpq);\n    app.addImport(\"zigeffect_otel\", zigeffect_otel);" else "" },
        .{ "__SHARED_DEPENDENCY__", if (with_shared) "    const shared = b.dependency(\"shared\", .{ .target = target, .optimize = optimize }).module(\"shared\");" else "" },
        .{ "__SHARED_IMPORT__", if (with_shared) "    app.addImport(\"shared\", shared);" else "" },
    });
    try addRenderedAt(plan, prefix, "build.zig.zon", templates.executable_zon, &.{
        .{ "__ZIG_NAME__", package_name },
        .{ "__FINGERPRINT__", fingerprint },
        .{ "__STD_PATH__", std_path },
        .{ "__ADAPTER_ZON_DEPENDENCIES__", adapter_zon },
        .{ "__SHARED_ZON_DEPENDENCY__", if (with_shared) "        .shared = .{ .path = \"../../packages/shared\" }," else "" },
    });
    try addRenderedAt(plan, prefix, "src/main.zig", if (real_profile) templates.production_main_source else templates.main_source, &.{});
    try addRenderedAt(plan, prefix, "src/app.zig", if (real_profile) templates.production_app_source else templates.app_source, &.{
        .{ "__PROJECT_NAME__", component_name },
        .{ "__SHARED_SOURCE_IMPORT__", if (with_shared) "const shared = @import(\"shared\");" else "" },
        .{ "__SHARED_SOURCE_USE__", if (with_shared) "    if (shared.contract_version != 1) return error.IncompatibleSharedContract;" else "" },
    });
    if (real_profile) {
        try addRenderedAt(plan, prefix, "src/production_wiring.zig", templates.production_wiring_source, &.{});
        try addRenderedAt(plan, prefix, "config.example.json", "{\n  \"port\": 8080,\n  \"otlp_host\": \"otel-collector\",\n  \"otlp_port\": 4318,\n  \"migration_dialect\": \"postgresql\"\n}\n", &.{});
        try addRenderedAt(plan, prefix, "test/root_test.zig", templates.production_test, &.{});
    } else {
        try addRenderedAt(plan, prefix, "src/config.zig", templates.config_source, &.{});
        try addRenderedAt(plan, prefix, "src/cli.zig", templates.cli_source, &.{.{ "__PROJECT_NAME__", component_name }});
        try addRenderedAt(plan, prefix, "src/http.zig", templates.http_source, &.{});
        try addRenderedAt(plan, prefix, "src/sql.zig", templates.sql_source, &.{});
        try addRenderedAt(plan, prefix, "src/services/greeting.zig", templates.greeting_source, &.{});
        try addRenderedAt(plan, prefix, "test/root_test.zig", templates.executable_test, &.{.{ "__PROJECT_NAME__", component_name }});
    }
    if (prefix.len != 0) {
        try addRenderedAt(plan, prefix, "README.md", templates.readme, &.{ .{ "__PROJECT_NAME__", component_name }, .{ "__PROFILE__", @tagName(options.profile) } });
    }
}

fn siblingAdapterPathAlloc(allocator: std.mem.Allocator, std_path: []const u8, adapter: []const u8) ![]u8 {
    const parent = std.fs.path.dirname(std_path) orelse ".";
    return std.fs.path.join(allocator, &.{ parent, adapter });
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
            .profile = @tagName(options.profile),
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
        .{ "__ADAPTER_ZON_DEPENDENCIES__", "" },
        .{ "__SHARED_ZON_DEPENDENCY__", "" },
    });
    try addRenderedAt(plan, prefix, "src/root.zig", if (prefix.len == 0) templates.library_source else templates.shared_source, &.{.{ "__PROJECT_NAME__", component_name }});
    try addRenderedAt(plan, prefix, "test/root_test.zig", if (prefix.len == 0) templates.library_test else templates.shared_test, if (prefix.len == 0) &.{.{ "__PROJECT_NAME__", component_name }} else &.{});
    if (changelog) try addRenderedAt(plan, prefix, "CHANGELOG.md", templates.changelog, &.{});
    if (prefix.len != 0) {
        try addRenderedAt(plan, prefix, "README.md", templates.readme, &.{ .{ "__PROJECT_NAME__", component_name }, .{ "__PROFILE__", @tagName(options.profile) } });
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
        .{ "__STD_PATH__", options.zigeffect_std_path },
    });
    try addRenderedAt(plan, "", "src/root.zig", if (options.profile == .@"local-fake") templates.system_source else templates.production_system_source, &.{});
    try addRenderedAt(plan, "", "test/root_test.zig", if (options.profile == .@"local-fake") templates.system_test else templates.production_system_test, &.{.{ "__PROJECT_NAME__", options.name }});
    try addExecutableProject(plan, options, "services/api", true);
    try addExecutableProject(plan, options, "services/worker", true);
    try addLibraryProject(plan, options, "packages/shared", "shared", false);
}

fn addRootCommon(plan: *zstd.Project.FilePlan, options: ScaffoldOptions) !void {
    try addRenderedAt(plan, "", "README.md", templates.readme, &.{ .{ "__PROJECT_NAME__", options.name }, .{ "__PROFILE__", @tagName(options.profile) } });
    const profile_json = try std.json.Stringify.valueAlloc(plan.allocator, .{ .schema = "zigeffect.adapter-profile.v1", .profile = @tagName(options.profile), .fake = options.profile == .@"local-fake", .production = options.profile == .production }, .{ .whitespace = .indent_2 });
    defer plan.allocator.free(profile_json);
    try plan.add(".zigeffect/adapter-profile.json", profile_json);
    try plan.add(".gitignore", templates.gitignore);
    try plan.add(".agents/skills/zigeffect-development/SKILL.md", templates.skill);
    try plan.add(".claude/skills/zigeffect-development/SKILL.md", templates.skill);
    try plan.add(".gemini/skills/zigeffect-development/SKILL.md", templates.skill);
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
        .{ .id = "production-check", .argv = &.{ "zig", "build", "test", "-Doptimize=ReleaseSafe" } },
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
    const scenarios = [_]zstd.Project.TestScenario{.{
        .id = "bootstrap-boundaries",
        .label = "generated boundaries compile and preserve causal safety",
        .requirement = "req-bootstrap",
        .acceptance_check = "check-bootstrap",
        .component = if (options.kind == .system) "api-service" else options.name,
        .command = "test",
        .source_roots = if (options.kind == .system) &.{ "services/api", "packages/shared", "test" } else &.{ "src", "test" },
        .tags = &.{ "acceptance", "causal", "generated" },
        .native_test_filter = switch (options.kind) {
            .application, .service => "application acceptance",
            .library, .package => "public effect validates input",
            .system => if (options.profile == .@"local-fake") "system acceptance" else "production system emits a Testing v2 capability scenario",
        },
        .default_seed = 1,
        .fault_profile = if (options.kind == .library or options.kind == .package) .allocation else .standard,
    }};
    const executable_capabilities = [_]zstd.Project.Capability{ .cli, .http, .sql, .config, .observability, .agent, .workbench, .causal_graph, .statecharts };
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
    const runtime_profile = options.kind == .application or options.kind == .service or options.kind == .system;
    const profile_component = if (options.kind == .system) "api-service" else options.name;
    const fake_requirements = [_]zstd.Project.CapabilityRequirement{
        .{ .id = "http-server", .component = profile_component, .kind = .http_server, .minimum_maturity = .fake, .features = &.{} },
        .{ .id = "sql-database", .component = profile_component, .kind = .sql_database, .minimum_maturity = .fake, .features = &.{} },
    };
    const real_maturity: zstd.Capability.Maturity = if (options.profile == .production) .production_candidate else .local_development;
    const require_live = options.profile == .production;
    const real_requirements = [_]zstd.Project.CapabilityRequirement{
        .{ .id = "http-server", .component = profile_component, .kind = .http_server, .minimum_maturity = real_maturity, .features = &.{ "http1", "graceful-drain" }, .requires_live_conformance = require_live },
        .{ .id = "sql-database", .component = profile_component, .kind = .sql_database, .minimum_maturity = real_maturity, .features = &.{ "safe-bindings", "transactions" }, .requires_live_conformance = require_live },
        .{ .id = "telemetry", .component = profile_component, .kind = .telemetry, .minimum_maturity = real_maturity, .features = &.{ "logs", "metrics", "traces" }, .requires_live_conformance = require_live },
    };
    const fake_bindings = [_]zstd.Project.AdapterBinding{
        .{ .requirement = "http-server", .adapter = "zigeffect-std.memory-http" },
        .{ .requirement = "sql-database", .adapter = "zigeffect-std.fake-sql-database" },
    };
    const real_bindings = [_]zstd.Project.AdapterBinding{
        .{ .requirement = "http-server", .adapter = "zigeffect-http.server" },
        .{ .requirement = "sql-database", .adapter = "zigeffect-postgres.libpq" },
        .{ .requirement = "telemetry", .adapter = "zigeffect-otel.otlp-http-json" },
    };
    const profiles = [_]zstd.Project.AdapterProfile{.{
        .id = @tagName(options.profile),
        .target = "native",
        .bindings = if (options.profile == .@"local-fake") fake_bindings[0..] else real_bindings[0..],
    }};
    const real_descriptors = [_]zstd.Capability.Descriptor{
        .{ .id = "zigeffect-http.server", .kind = .http_server, .maturity = .local_development, .package = "zigeffect-http", .version = "0.1.0", .features = &.{ "http1", "chunked", "middleware", "graceful-drain" }, .side_effects = .real, .limitations = &.{"generated projects must earn their own live conformance receipt"} },
        .{ .id = "zigeffect-postgres.libpq", .kind = .sql_database, .maturity = .local_development, .package = "zigeffect-postgres-libpq", .version = "0.1.0", .features = &.{ "native-protocol", "persistent-session", "safe-bindings", "prepared-statements", "cancellation", "transactions" }, .side_effects = .real, .limitations = &.{"generated projects must earn their own live database receipt"} },
        .{ .id = "zigeffect-otel.otlp-http-json", .kind = .telemetry, .maturity = .local_development, .package = "zigeffect-otel", .version = "0.1.0", .features = &.{ "otlp-http-json", "logs", "metrics", "traces", "bounded-queue", "retry", "flush", "w3c-trace-context" }, .side_effects = .real, .limitations = &.{"generated projects must earn their own collector receipt"} },
    };
    const manifest = zstd.Project.Manifest{
        .name = options.name,
        .kind = options.kind,
        .components = if (options.kind == .system) system_components[0..] else single_component[0..],
        .commands = commands[0..],
        .requirements = requirements[0..],
        .acceptance_checks = checks[0..],
        .test_scenarios = scenarios[0..],
        .execution_posture = if (runtime_profile and options.profile == .production) .production else .local,
        .capability_requirements = if (!runtime_profile) &.{} else if (options.profile == .@"local-fake") fake_requirements[0..] else real_requirements[0..],
        .capability_descriptors = if (runtime_profile and options.profile != .@"local-fake") real_descriptors[0..] else &.{},
        .adapter_profiles = if (runtime_profile) profiles[0..] else &.{},
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
    errdefer allocator.free(result);
    for (result) |*byte| {
        if (byte.* == '-') byte.* = '_';
    }
    if (result.len > 32) {
        const digest: u32 = @truncate(std.hash.Wyhash.hash(0, result));
        const bounded = try std.fmt.allocPrint(allocator, "{s}_{x:0>8}", .{ result[0..23], digest });
        allocator.free(result);
        return bounded;
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

fn parseCompletionsArgs(args: []const []const u8) CliError!distribution.Shell {
    if (args.len == 0) return error.MissingOptionValue;
    if (args.len != 1) return error.UnknownOption;
    return std.meta.stringToEnum(distribution.Shell, args[0]) orelse error.UnknownShell;
}

fn parseCompatibilityArgs(args: []const []const u8) CliError!CompatibilityOptions {
    var options = CompatibilityOptions{};
    var root_set = false;
    var index: usize = 0;
    while (index < args.len) {
        if (eql(args[index], "--root")) {
            if (root_set) return error.DuplicateOption;
            options.root = try optionValue(args, &index);
            root_set = true;
        } else if (eql(args[index], "--json")) {
            if (options.json) return error.DuplicateOption;
            options.json = true;
            index += 1;
        } else return error.UnknownOption;
    }
    try validateTarget(options.root);
    return options;
}

fn parseUpgradeArgs(args: []const []const u8) CliError!UpgradeOptions {
    var options = UpgradeOptions{};
    var root_set = false;
    var dry_run_set = false;
    var apply_set = false;
    var index: usize = 0;
    while (index < args.len) {
        if (eql(args[index], "--root")) {
            if (root_set) return error.DuplicateOption;
            options.root = try optionValue(args, &index);
            root_set = true;
        } else if (eql(args[index], "--dry-run")) {
            if (dry_run_set) return error.DuplicateOption;
            dry_run_set = true;
            index += 1;
        } else if (eql(args[index], "--apply")) {
            if (apply_set) return error.DuplicateOption;
            apply_set = true;
            options.apply = true;
            options.dry_run = false;
            index += 1;
        } else if (eql(args[index], "--json")) {
            if (options.json) return error.DuplicateOption;
            options.json = true;
            index += 1;
        } else return error.UnknownOption;
    }
    if (dry_run_set and apply_set) return error.InvalidOptionCombination;
    try validateTarget(options.root);
    return options;
}

fn parseGraphArgs(args: []const []const u8) (CliError || zstd.Project.ProjectError)!GraphOptions {
    if (args.len == 0) return error.MissingCommand;
    const operation = std.meta.stringToEnum(GraphOperation, args[0]) orelse return error.UnknownCommand;
    var options = GraphOptions{ .operation = operation };
    var root_set = false;
    var component_set = false;
    var event_id_set = false;
    var limit_set = false;
    var index: usize = 1;

    if (operation == .since or operation == .event or operation == .children or operation == .path) {
        if (index >= args.len or std.mem.startsWith(u8, args[index], "--")) return error.InvalidEventId;
        options.event_id = std.fmt.parseInt(u64, args[index], 10) catch return error.InvalidEventId;
        if (options.event_id == 0 and operation != .since) return error.InvalidEventId;
        event_id_set = true;
        index += 1;
        if (operation == .path) {
            if (index >= args.len or std.mem.startsWith(u8, args[index], "--")) return error.InvalidEventId;
            options.to_event_id = std.fmt.parseInt(u64, args[index], 10) catch return error.InvalidEventId;
            if (options.to_event_id == 0) return error.InvalidEventId;
            index += 1;
        }
    }

    while (index < args.len) {
        if (eql(args[index], "--root")) {
            if (root_set) return error.DuplicateOption;
            options.root = try optionValue(args, &index);
            root_set = true;
        } else if (eql(args[index], "--component")) {
            if (component_set) return error.DuplicateOption;
            const component = try optionValue(args, &index);
            try zstd.Project.validateIdentifier(component);
            options.component = component;
            component_set = true;
        } else if (eql(args[index], "--limit")) {
            if (operation != .since and operation != .path) return error.UnknownOption;
            if (limit_set) return error.DuplicateOption;
            const value = try optionValue(args, &index);
            options.limit = std.fmt.parseInt(usize, value, 10) catch return error.InvalidLimit;
            if (options.limit == 0 or options.limit > 4096) return error.InvalidLimit;
            limit_set = true;
        } else if (eql(args[index], "--json")) {
            if (options.json) return error.DuplicateOption;
            options.json = true;
            index += 1;
        } else return error.UnknownOption;
    }
    if ((operation == .since or operation == .event or operation == .children or operation == .path) and !event_id_set) return error.InvalidEventId;
    try validateTarget(options.root);
    return options;
}

fn parseStatechartArgs(args: []const []const u8) (CliError || zstd.Project.ProjectError)!StatechartOptions {
    if (args.len == 0) return error.MissingCommand;
    const operation = std.meta.stringToEnum(StatechartOperation, args[0]) orelse return error.UnknownCommand;
    var options = StatechartOptions{ .operation = operation };
    var index: usize = 1;
    switch (operation) {
        .show, .versions, .instances, .coverage, .paths, .studio, .@"export" => {
            if (index >= args.len or std.mem.startsWith(u8, args[index], "--")) return error.InvalidStatechartId;
            try validateStatechartId(args[index]);
            options.machine_id = args[index];
            index += 1;
        },
        .trace, .explain => {
            if (index >= args.len or std.mem.startsWith(u8, args[index], "--")) return error.InvalidInstanceId;
            options.instance_id = std.fmt.parseInt(u64, args[index], 10) catch return error.InvalidInstanceId;
            if (options.instance_id == 0) return error.InvalidInstanceId;
            index += 1;
        },
        .compile, .propose, .verify, .review, .approve, .application => {
            if (index >= args.len or std.mem.startsWith(u8, args[index], "--")) return error.InvalidTarget;
            options.input_path = args[index];
            try validateArtifactPath(options.input_path);
            index += 1;
        },
        .pattern => {
            if (index >= args.len or std.mem.startsWith(u8, args[index], "--")) return error.UnknownCommand;
            options.pattern_kind = std.meta.stringToEnum(zstd.Statechart.Plan.PatternKind, args[index]) orelse return error.UnknownCommand;
            index += 1;
        },
        .list, .fleet, .controls, .patterns => {},
    }

    var root_set = false;
    var component_set = false;
    var format_set = false;
    var namespace_set = false;
    while (index < args.len) {
        if (eql(args[index], "--root")) {
            if (root_set) return error.DuplicateOption;
            options.root = try optionValue(args, &index);
            root_set = true;
        } else if (eql(args[index], "--component")) {
            if (component_set) return error.DuplicateOption;
            const component = try optionValue(args, &index);
            try zstd.Project.validateIdentifier(component);
            options.component = component;
            component_set = true;
        } else if (eql(args[index], "--format")) {
            if (format_set or operation != .@"export") return error.DuplicateOption;
            const format = try optionValue(args, &index);
            options.format = std.meta.stringToEnum(zstd.Statechart.ExportFormat, format) orelse return error.UnknownOption;
            format_set = true;
        } else if (eql(args[index], "--json")) {
            if (options.json) return error.DuplicateOption;
            options.json = true;
            index += 1;
        } else if (eql(args[index], "--output")) {
            if (options.output_path.len != 0 or (operation != .compile and !isStudioArtifactOperation(operation))) return error.InvalidOptionCombination;
            options.output_path = try optionValue(args, &index);
            try validateArtifactPath(options.output_path);
        } else if (eql(args[index], "--namespace")) {
            if (operation != .pattern or namespace_set) return error.InvalidOptionCombination;
            options.namespace = try optionValue(args, &index);
            try validateStatechartId(options.namespace);
            namespace_set = true;
        } else if (eql(args[index], "--apply")) {
            if ((operation != .compile and !isStudioArtifactOperation(operation)) or options.apply) return error.InvalidOptionCombination;
            options.apply = true;
            index += 1;
        } else return error.UnknownOption;
    }
    if (operation == .@"export" and !format_set) return error.MissingOptionValue;
    if ((operation == .compile or isStudioArtifactOperation(operation)) and options.apply and options.output_path.len == 0) return error.MissingOptionValue;
    if ((operation == .compile or isStudioArtifactOperation(operation)) and !options.apply and options.output_path.len != 0) return error.InvalidOptionCombination;
    try validateTarget(options.root);
    return options;
}

fn isStudioArtifactOperation(operation: StatechartOperation) bool {
    return switch (operation) {
        .propose, .verify, .review, .approve, .application => true,
        else => false,
    };
}

fn validateStatechartId(id: []const u8) CliError!void {
    if (id.len == 0 or id.len > 128) return error.InvalidStatechartId;
    for (id) |byte| {
        if (!std.ascii.isAlphanumeric(byte) and byte != '.' and byte != '_' and byte != '-') return error.InvalidStatechartId;
    }
}

fn validateArtifactPath(path: []const u8) CliError!void {
    if (path.len == 0 or path.len > 1024 or std.fs.path.isAbsolute(path) or std.mem.indexOfScalar(u8, path, 0) != null or std.mem.indexOfScalar(u8, path, '\\') != null) return error.InvalidTarget;
    var segments = std.mem.splitScalar(u8, path, '/');
    while (segments.next()) |segment| {
        if (segment.len == 0 or std.mem.eql(u8, segment, ".") or std.mem.eql(u8, segment, "..")) return error.InvalidTarget;
    }
}

fn parseTestArgs(args: []const []const u8) (CliError || zstd.Project.ProjectError)!TestOptions {
    if (args.len == 0) return error.MissingCommand;
    const operation = std.meta.stringToEnum(TestOperation, args[0]) orelse return error.UnknownCommand;
    var options = TestOptions{ .operation = operation };
    var index: usize = 1;
    var runs_set = false;
    var profile_set = false;
    if (operation == .explain or operation == .replay or operation == .snapshot) {
        if (index >= args.len or std.mem.startsWith(u8, args[index], "--")) return error.MissingScenario;
        try zstd.Project.validateIdentifier(args[index]);
        options.scenario = args[index];
        index += 1;
    }
    var root_set = false;
    while (index < args.len) {
        const token = args[index];
        if (eql(token, "--root")) {
            if (root_set) return error.DuplicateOption;
            options.root = try optionValue(args, &index);
            root_set = true;
        } else if (eql(token, "--scenario")) {
            if (options.scenario.len != 0) return error.DuplicateOption;
            options.scenario = try optionValue(args, &index);
            try zstd.Project.validateIdentifier(options.scenario);
        } else if (eql(token, "--requirement")) {
            if (options.requirement.len != 0) return error.DuplicateOption;
            options.requirement = try optionValue(args, &index);
            try zstd.Project.validateIdentifier(options.requirement);
        } else if (eql(token, "--component")) {
            if (options.component.len != 0) return error.DuplicateOption;
            options.component = try optionValue(args, &index);
            try zstd.Project.validateIdentifier(options.component);
        } else if (eql(token, "--tag")) {
            if (options.tag.len != 0) return error.DuplicateOption;
            options.tag = try optionValue(args, &index);
            try zstd.Project.validateIdentifier(options.tag);
        } else if (eql(token, "--changed")) {
            if (options.changed.len != 0) return error.DuplicateOption;
            options.changed = try optionValue(args, &index);
            try zstd.Project.validateRelativePath(options.changed, false);
        } else if (eql(token, "--seed")) {
            if (options.seed != null) return error.DuplicateOption;
            const raw = try optionValue(args, &index);
            const seed = std.fmt.parseInt(u64, raw, 10) catch return error.InvalidSeed;
            if (seed == 0) return error.InvalidSeed;
            options.seed = seed;
        } else if (eql(token, "--fault")) {
            if (options.fault.len != 0) return error.DuplicateOption;
            options.fault = try optionValue(args, &index);
            if (!validFaultToken(options.fault)) return error.InvalidFault;
        } else if (eql(token, "--runs")) {
            if (operation != .stress) return error.InvalidOptionCombination;
            if (runs_set) return error.DuplicateOption;
            const raw = try optionValue(args, &index);
            options.runs = std.fmt.parseInt(usize, raw, 10) catch return error.InvalidSeed;
            if (options.runs == 0 or options.runs > 256) return error.InvalidSeed;
            runs_set = true;
        } else if (eql(token, "--profile")) {
            if (profile_set) return error.DuplicateOption;
            options.profile = try optionValue(args, &index);
            profile_set = true;
        } else if (eql(token, "--json")) {
            if (options.json) return error.DuplicateOption;
            options.json = true;
            index += 1;
        } else if (eql(token, "--apply")) {
            if (options.apply or operation != .snapshot) return error.InvalidOptionCombination;
            options.apply = true;
            index += 1;
        } else return error.UnknownOption;
    }
    if (operation == .affected and options.changed.len == 0) return error.MissingOptionValue;
    if (operation == .replay and (options.seed == null or options.fault.len == 0)) return error.MissingOptionValue;
    if (operation != .snapshot and options.apply) return error.InvalidOptionCombination;
    try validateTarget(options.root);
    return options;
}

fn validFaultToken(value: []const u8) bool {
    const colon = std.mem.indexOfScalar(u8, value, ':') orelse return false;
    if (colon == 0 or colon == value.len - 1) return false;
    if (std.meta.stringToEnum(zstd.Testing.Contract.FaultKind, value[0..colon]) == null) return false;
    _ = std.fmt.parseInt(usize, value[colon + 1 ..], 10) catch return false;
    return true;
}

fn parseProjectArgs(args: []const []const u8) (CliError || zstd.Project.ProjectError)!ProjectOptions {
    if (args.len == 0) return error.MissingCommand;
    const operation = std.meta.stringToEnum(ProjectOperation, args[0]) orelse return error.UnknownCommand;
    var options = ProjectOptions{ .operation = operation };
    var root_set = false;
    var profile_set = false;
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
        } else if (eql(args[index], "--profile")) {
            if (profile_set) return error.DuplicateOption;
            options.profile = try optionValue(args, &index);
            profile_set = true;
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
    var profile_set = false;
    var task_set = false;
    var changed_set = false;
    var budget_set = false;
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
        } else if (eql(args[index], "--profile")) {
            if (profile_set) return error.DuplicateOption;
            options.profile = try optionValue(args, &index);
            profile_set = true;
        } else if (eql(args[index], "--task")) {
            if (task_set or operation != .context) return error.DuplicateOption;
            options.task = try optionValue(args, &index);
            task_set = true;
        } else if (eql(args[index], "--changed")) {
            if (changed_set or operation != .context) return error.DuplicateOption;
            options.changed = try optionValue(args, &index);
            changed_set = true;
        } else if (eql(args[index], "--budget")) {
            if (budget_set or operation != .context) return error.DuplicateOption;
            const value = try optionValue(args, &index);
            options.budget = std.fmt.parseInt(usize, value, 10) catch return error.InvalidLimit;
            if (options.budget < 512 or options.budget > zstd.Development.max_context_bytes) return error.InvalidLimit;
            budget_set = true;
        } else if (eql(args[index], "--json") or eql(args[index], "--jsonl")) {
            if (format_set) return error.DuplicateOption;
            options.jsonl = eql(args[index], "--jsonl");
            format_set = true;
            index += 1;
        } else return error.UnknownOption;
    }
    try validateTarget(options.root);
    if (operation == .handoff and (options.provider.len == 0 or options.session.len == 0)) return error.MissingOptionValue;
    if (operation == .context and options.task.len == 0) return error.MissingOptionValue;
    return options;
}

fn parseBenchmarkArgs(args: []const []const u8) CliError!BenchmarkOptions {
    if (args.len == 0) return error.MissingCommand;
    const operation = std.meta.stringToEnum(BenchmarkOperation, args[0]) orelse return error.UnknownCommand;
    var options = BenchmarkOptions{ .operation = operation };
    var index: usize = 1;
    if (operation != .run) {
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
    try std.testing.expectEqual(distribution.Shell.zsh, (try parseArgs(&.{ "completions", "zsh" })).completions);
    const compatibility = try parseArgs(&.{ "compatibility", "--root", "demo", "--json" });
    try std.testing.expectEqualStrings("demo", compatibility.compatibility.root);
    try std.testing.expect(compatibility.compatibility.json);
    const upgrade = try parseArgs(&.{ "upgrade", "--root", "demo", "--dry-run", "--json" });
    try std.testing.expectEqualStrings("demo", upgrade.upgrade.root);
    try std.testing.expect(upgrade.upgrade.dry_run);
    try std.testing.expect(!upgrade.upgrade.apply);

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
    try std.testing.expectError(error.MissingOptionValue, parseArgs(&.{"completions"}));
    try std.testing.expectError(error.UnknownShell, parseArgs(&.{ "completions", "powershell" }));
    try std.testing.expectError(error.InvalidOptionCombination, parseArgs(&.{ "upgrade", "--dry-run", "--apply" }));
}

test "CLI parses bounded project add and generate operations" {
    const project = try parseArgs(&.{ "project", "check", "--root", "demo", "--json", "--agent", "--profile", "production" });
    try std.testing.expectEqual(ProjectOperation.check, project.project.operation);
    try std.testing.expectEqualStrings("demo", project.project.root);
    try std.testing.expect(project.project.json);
    try std.testing.expect(project.project.agent);
    try std.testing.expectEqualStrings("production", project.project.profile);

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
    const conformance = try parseArgs(&.{ "benchmark", "conformance", "fixtures/provider-suite.json", "--json" });
    try std.testing.expectEqual(BenchmarkOperation.conformance, conformance.benchmark.operation);
    try std.testing.expectEqualStrings("fixtures/provider-suite.json", conformance.benchmark.fixture);
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
    const generate_machine = try parseArgs(&.{ "generate", "statechart", "review-flow", "--component", "api-service" });
    try std.testing.expectEqual(GenerateKind.statechart, generate_machine.generate.kind);

    const graph_status = try parseArgs(&.{ "graph", "status", "--root", "demo", "--component", "api-service", "--json" });
    try std.testing.expectEqual(GraphOperation.status, graph_status.graph.operation);
    try std.testing.expectEqualStrings("demo", graph_status.graph.root);
    try std.testing.expectEqualStrings("api-service", graph_status.graph.component.?);
    try std.testing.expect(graph_status.graph.json);
    const graph_event = try parseArgs(&.{ "graph", "event", "42", "--root", "demo" });
    try std.testing.expectEqual(GraphOperation.event, graph_event.graph.operation);
    try std.testing.expectEqual(@as(u64, 42), graph_event.graph.event_id);
    const graph_children = try parseArgs(&.{ "graph", "children", "42", "--json" });
    try std.testing.expectEqual(GraphOperation.children, graph_children.graph.operation);
    const graph_since = try parseArgs(&.{ "graph", "since", "42", "--limit", "64", "--json" });
    try std.testing.expectEqual(GraphOperation.since, graph_since.graph.operation);
    try std.testing.expectEqual(@as(u64, 42), graph_since.graph.event_id);
    try std.testing.expectEqual(@as(usize, 64), graph_since.graph.limit);
    try std.testing.expectEqual(@as(u64, 0), (try parseArgs(&.{ "graph", "since", "0" })).graph.event_id);
    try std.testing.expectError(error.InvalidLimit, parseArgs(&.{ "graph", "since", "42", "--limit", "0" }));
    try std.testing.expectError(error.InvalidEventId, parseArgs(&.{ "graph", "event", "0" }));
    try std.testing.expectError(error.InvalidEventId, parseArgs(&.{ "graph", "event" }));
    try std.testing.expectError(error.InvalidEventId, parseArgs(&.{ "graph", "children", "not-a-number" }));
    try std.testing.expectError(error.UnknownOption, parseArgs(&.{ "graph", "status", "42" }));

    const statechart_show = try parseArgs(&.{ "statechart", "show", "agent.review", "--root", "demo", "--json" });
    try std.testing.expectEqual(StatechartOperation.show, statechart_show.statechart.operation);
    try std.testing.expectEqualStrings("agent.review", statechart_show.statechart.machine_id);
    try std.testing.expect(statechart_show.statechart.json);
    try std.testing.expectEqual(StatechartOperation.versions, (try parseArgs(&.{ "statechart", "versions", "agent.review", "--json" })).statechart.operation);
    const statechart_trace = try parseArgs(&.{ "statechart", "trace", "7001", "--component", "api-service" });
    try std.testing.expectEqual(@as(u64, 7001), statechart_trace.statechart.instance_id);
    try std.testing.expectEqualStrings("api-service", statechart_trace.statechart.component.?);
    const statechart_export = try parseArgs(&.{ "statechart", "export", "agent.review", "--format", "xstate" });
    try std.testing.expectEqual(zstd.Statechart.ExportFormat.xstate, statechart_export.statechart.format);
    const statechart_compile = try parseArgs(&.{ "statechart", "compile", "workflows/review.json", "--output", "src/review.zig", "--apply" });
    try std.testing.expectEqual(StatechartOperation.compile, statechart_compile.statechart.operation);
    try std.testing.expectEqualStrings("workflows/review.json", statechart_compile.statechart.input_path);
    try std.testing.expectEqualStrings("src/review.zig", statechart_compile.statechart.output_path);
    try std.testing.expect(statechart_compile.statechart.apply);
    const statechart_pattern = try parseArgs(&.{ "statechart", "pattern", "human_approval", "--namespace", "review.approval", "--json" });
    try std.testing.expectEqual(zstd.Statechart.Plan.PatternKind.human_approval, statechart_pattern.statechart.pattern_kind.?);
    try std.testing.expectEqualStrings("review.approval", statechart_pattern.statechart.namespace);
    try std.testing.expectEqual(StatechartOperation.patterns, (try parseArgs(&.{ "statechart", "patterns" })).statechart.operation);
    try std.testing.expectEqual(StatechartOperation.fleet, (try parseArgs(&.{ "statechart", "fleet", "--json" })).statechart.operation);
    try std.testing.expectEqual(StatechartOperation.controls, (try parseArgs(&.{ "statechart", "controls", "--json" })).statechart.operation);
    const propose = try parseArgs(&.{ "statechart", "propose", "proposal-input.json", "--output", ".zigeffect/statecharts/proposals/p-1.json", "--apply" });
    try std.testing.expectEqual(StatechartOperation.propose, propose.statechart.operation);
    try std.testing.expect(propose.statechart.apply);
    try std.testing.expectError(error.InvalidStatechartId, parseArgs(&.{ "statechart", "show", "../outside" }));
    try std.testing.expectError(error.InvalidInstanceId, parseArgs(&.{ "statechart", "trace", "0" }));
    try std.testing.expectError(error.MissingOptionValue, parseArgs(&.{ "statechart", "export", "agent.review" }));
    try std.testing.expectError(error.MissingOptionValue, parseArgs(&.{ "statechart", "compile", "review.json", "--apply" }));
    try std.testing.expectError(error.InvalidTarget, parseArgs(&.{ "statechart", "compile", "../outside.json" }));
    try std.testing.expectError(error.InvalidTarget, parseArgs(&.{ "statechart", "propose", "/tmp/proposal.json" }));
}

test "statechart governance CLI creates deterministic immutable proposal artifacts" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "proposal-input.json", .data =
        \\{"proposal_id":"proposal-1","machine_id":"agent.review","author":"agent:planner","title":"Add review","summary":"Require review evidence","created_ms":100,"base_version":1,"next_version":2,"base_fingerprint":41,"next_fingerprint":42,"definition_digest":"sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","diff_digest":"sha256:1123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}
    });
    var preview = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "statechart", "propose", "proposal-input.json" });
    defer preview.deinit();
    try std.testing.expect(std.mem.indexOf(u8, preview.output, "zigeffect.statechart.proposal.v1") != null);
    try std.testing.expectError(error.FileNotFound, tmp.dir.access(std.testing.io, "proposal.json", .{}));

    var applied = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "statechart", "propose", "proposal-input.json", "--output", "proposal.json", "--apply" });
    defer applied.deinit();
    const persisted = try tmp.dir.readFileAlloc(std.testing.io, "proposal.json", std.testing.allocator, .limited(1024 * 1024));
    defer std.testing.allocator.free(persisted);
    try std.testing.expectEqualStrings(applied.output, persisted);
}

test "statechart pattern commands expose the reusable agent workflow catalog" {
    var catalog = try runStatechartPatternsAlloc(std.testing.allocator);
    defer catalog.deinit();
    try std.testing.expect(std.mem.indexOf(u8, catalog.output, "human_approval") != null);
    try std.testing.expect(std.mem.indexOf(u8, catalog.output, "incident_remediation") != null);

    var expanded = try runStatechartPatternAlloc(std.testing.allocator, .{
        .operation = .pattern,
        .pattern_kind = .human_approval,
        .namespace = "review.approval",
        .json = true,
    });
    defer expanded.deinit();
    try std.testing.expect(std.mem.indexOf(u8, expanded.output, "review.approval.awaiting") != null);
    try std.testing.expect(std.mem.indexOf(u8, expanded.output, "eventually-terminal") != null);
}

test "statechart generators emit native machine actor durable and model-test modules" {
    const Case = struct { kind: GenerateKind, path: []const u8, symbol: []const u8 };
    for ([_]Case{
        .{ .kind = .statechart, .path = "src/statecharts/review-flow.zig", .symbol = "ConfigurationMachine" },
        .{ .kind = .statechart_actor, .path = "src/actors/review-flow.zig", .symbol = "ActorSystem" },
        .{ .kind = .durable_statechart, .path = "src/workflows/review-flow.zig", .symbol = "DurableStatechart" },
        .{ .kind = .statechart_test, .path = "test/review-flow_statechart_test.zig", .symbol = "fingerprint" },
    }) |case| {
        const options = GenerateOptions{ .kind = case.kind, .name = "review-flow", .component = "api-service" };
        const path = try generatedModulePathAlloc(std.testing.allocator, options);
        defer std.testing.allocator.free(path);
        try std.testing.expectEqualStrings(case.path, path);
        const source = try generatedModuleAlloc(std.testing.allocator, options);
        defer std.testing.allocator.free(source);
        try std.testing.expect(std.mem.indexOf(u8, source, case.symbol) != null);
        try std.testing.expect(std.mem.indexOf(u8, source, "__MACHINE_NAME__") == null);
        try std.testing.expect(std.mem.indexOf(u8, source, "review-flow") != null);
    }
}

test "service and layer generators emit canonical composable modules" {
    const service = try generatedModuleAlloc(std.testing.allocator, .{ .kind = .service, .name = "orders", .component = "api" });
    defer std.testing.allocator.free(service);
    try std.testing.expect(std.mem.indexOf(u8, service, "kernel.Service(\"generated/orders\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, service, "kernel.Effect") != null);
    try std.testing.expect(std.mem.indexOf(u8, service, "kernel.NamedEffect") != null);
    try std.testing.expect(std.mem.indexOf(u8, service, ".named(\"Service.execute\")") != null);
    try std.testing.expect(std.mem.indexOf(u8, service, "recordCausal") == null);
    try std.testing.expect(std.mem.indexOf(u8, service, "EffectEnv") == null);
    try std.testing.expect(std.mem.indexOf(u8, service, "zstd.fx.Context") == null);

    const layer = try generatedModuleAlloc(std.testing.allocator, .{ .kind = .layer, .name = "orders", .component = "api" });
    defer std.testing.allocator.free(layer);
    try std.testing.expect(std.mem.indexOf(u8, layer, "zstd.fx.kernel.Layer.succeed") != null);
    try std.testing.expect(std.mem.indexOf(u8, layer, "fromEnv") == null);
}

test "CLI parses provider-neutral agent queries and handoff" {
    const query = try parseArgs(&.{ "agent", "evidence", "--root", "demo", "--jsonl" });
    try std.testing.expectEqual(AgentOperation.evidence, query.agent.operation);
    try std.testing.expect(query.agent.jsonl);
    const handoff = try parseArgs(&.{ "agent", "handoff", "--provider", "claude-code", "--session", "session-7" });
    try std.testing.expectEqualStrings("claude-code", handoff.agent.provider);
    try std.testing.expectEqualStrings("session-7", handoff.agent.session);
}

test "CLI parses requirement-aware test list run affected explain replay and snapshot" {
    const list = try parseArgs(&.{ "test", "list", "--requirement", "req-bootstrap", "--tag", "acceptance", "--json" });
    try std.testing.expectEqual(TestOperation.list, list.@"test".operation);
    try std.testing.expectEqualStrings("req-bootstrap", list.@"test".requirement);
    const run = try parseArgs(&.{ "test", "run", "--scenario", "bootstrap-boundaries", "--seed", "42" });
    try std.testing.expectEqual(@as(?u64, 42), run.@"test".seed);
    const affected = try parseArgs(&.{ "test", "affected", "--changed", "src/main.zig" });
    try std.testing.expectEqualStrings("src/main.zig", affected.@"test".changed);
    const explain = try parseArgs(&.{ "test", "explain", "bootstrap-boundaries", "--json" });
    try std.testing.expectEqual(TestOperation.explain, explain.@"test".operation);
    const replay = try parseArgs(&.{ "test", "replay", "bootstrap-boundaries", "--seed", "7", "--fault", "allocation_failure:3" });
    try std.testing.expectEqualStrings("allocation_failure:3", replay.@"test".fault);
    const snapshot = try parseArgs(&.{ "test", "snapshot", "bootstrap-boundaries", "--apply" });
    try std.testing.expect(snapshot.@"test".apply);
    const coverage = try parseArgs(&.{ "test", "coverage", "--requirement", "req-bootstrap", "--json" });
    try std.testing.expectEqual(TestOperation.coverage, coverage.@"test".operation);
    const gaps = try parseArgs(&.{ "test", "gaps", "--component", "app", "--json" });
    try std.testing.expectEqual(TestOperation.gaps, gaps.@"test".operation);
    const stress = try parseArgs(&.{ "test", "stress", "--scenario", "bootstrap-boundaries", "--runs", "12", "--seed", "100", "--json" });
    try std.testing.expectEqual(TestOperation.stress, stress.@"test".operation);
    try std.testing.expectEqual(@as(usize, 12), stress.@"test".runs);
    const history = try parseArgs(&.{ "test", "history", "--json" });
    try std.testing.expectEqual(TestOperation.history, history.@"test".operation);
    try std.testing.expectError(error.InvalidSeed, parseArgs(&.{ "test", "stress", "--runs", "257" }));
    try std.testing.expectError(error.InvalidOptionCombination, parseArgs(&.{ "test", "run", "--runs", "2" }));
    try std.testing.expectError(error.InvalidSeed, parseArgs(&.{ "test", "run", "--seed", "0" }));
    try std.testing.expectError(error.InvalidFault, parseArgs(&.{ "test", "replay", "bootstrap-boundaries", "--seed", "1", "--fault", "unknown:0" }));
    try std.testing.expectError(error.MissingOptionValue, parseArgs(&.{ "test", "affected" }));
}

test "CLI ingestion requires and preserves native process receipts" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const project_scenario = zstd.Project.TestScenario{
        .id = "native-receipt",
        .label = "native receipt",
        .requirement = "req-native",
        .acceptance_check = "check-native",
        .component = "app",
        .command = "test",
        .default_seed = 42,
    };
    const control = zstd.Testing.Protocol.Control{
        .project = "demo",
        .scenario = contractScenario(project_scenario),
        .seed = 42,
        .source_revision = "working-tree",
        .command_digest = "sha256:command",
    };
    var missing = try ingestProcessReceiptAlloc(std.testing.allocator, std.testing.io, tmp.dir, control, 0, "zigeffect test replay native-receipt");
    defer missing.deinit();
    try std.testing.expectEqual(zstd.Testing.TestStatus.incomplete, missing.receipt.status);
    try std.testing.expect(!missing.receipt.execution.native_receipt);

    const assertions = [_]zstd.Testing.AssertionResult{.{ .id = "domain-proof", .label = "domain proof", .status = .passed }};
    try zstd.Testing.Protocol.publishReceipt(std.testing.allocator, std.testing.io, tmp.dir, .{
        .project = "demo",
        .suite = "acceptance",
        .scenario = control.scenario,
        .source_revision = "working-tree",
        .zig_version = @import("builtin").zig_version_string,
        .status = .passed,
        .seed = 42,
        .execution = .{ .command_digest = "sha256:command", .native_receipt = true },
        .assertions = &assertions,
    });
    var native = try ingestProcessReceiptAlloc(std.testing.allocator, std.testing.io, tmp.dir, control, 0, "zigeffect test replay native-receipt");
    defer native.deinit();
    try std.testing.expectEqual(zstd.Testing.TestStatus.passed, native.receipt.status);
    try std.testing.expectEqualStrings("domain-proof", native.receipt.assertions[0].id);
    try std.testing.expect(native.receipt.execution.native_receipt);
}

test "CLI coverage query derives agent-readable semantic gaps from latest receipts" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const project_scenario = zstd.Project.TestScenario{
        .id = "coverage-query",
        .label = "coverage query",
        .requirement = "req-coverage",
        .acceptance_check = "check-coverage",
        .component = "app",
        .command = "test",
        .default_seed = 1,
    };
    const assertions = [_]zstd.Testing.AssertionResult{.{ .id = "acceptance", .label = "acceptance", .status = .passed }};
    const receipts = [_]zstd.Testing.TestReceipt{.{
        .project = "demo",
        .suite = "acceptance",
        .scenario = contractScenario(project_scenario),
        .source_revision = "working-tree",
        .zig_version = @import("builtin").zig_version_string,
        .status = .passed,
        .seed = 1,
        .execution = .{ .native_receipt = true },
        .assertions = &assertions,
    }};
    const run = zstd.Testing.TestRunReceipt{
        .project = "demo",
        .source_revision = "working-tree",
        .discovered = 1,
        .selected = 1,
        .passed = 1,
        .failed = 0,
        .incomplete = 0,
        .unsupported = 0,
        .skipped = 0,
        .canceled = 0,
        .receipts = &receipts,
    };
    const json = try run.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try writeAtomicFile(std.testing.io, tmp.dir, ".zigeffect/tests/latest.json", json);
    var result = try runTestCoverageAlloc(std.testing.allocator, std.testing.io, tmp.dir, "demo", &.{project_scenario}, .{ .operation = .coverage, .json = true });
    defer result.deinit();
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, result.output, "native-receipt") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.output, "performance-contract") != null);
}

test "CLI test history is atomic validated and reports resolved failure fingerprints" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const project_scenario = zstd.Project.TestScenario{
        .id = "history-case",
        .label = "history case",
        .requirement = "req-history",
        .acceptance_check = "check-history",
        .component = "app",
        .command = "test",
    };
    const failed_assertions = [_]zstd.Testing.AssertionResult{.{ .id = "domain-proof", .label = "domain proof", .status = .failed }};
    const failed_receipt = zstd.Testing.TestReceipt{
        .project = "demo",
        .suite = "acceptance",
        .scenario = contractScenario(project_scenario),
        .source_revision = "working-tree",
        .zig_version = @import("builtin").zig_version_string,
        .status = .failed,
        .assertions = &failed_assertions,
    };
    const failed_run = zstd.Testing.TestRunReceipt{
        .project = "demo",
        .source_revision = "working-tree",
        .discovered = 1,
        .selected = 1,
        .passed = 0,
        .failed = 1,
        .incomplete = 0,
        .unsupported = 0,
        .skipped = 0,
        .canceled = 0,
        .receipts = &.{failed_receipt},
    };
    const json = try failed_run.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try writeAtomicFile(std.testing.io, tmp.dir, ".zigeffect/tests/latest.json", json);
    try persistTestHistory(std.testing.allocator, std.testing.io, tmp.dir, json);
    try persistTestHistory(std.testing.allocator, std.testing.io, tmp.dir, json);
    var history = try runTestHistoryAlloc(std.testing.allocator, std.testing.io, tmp.dir, "demo", .{ .operation = .history, .json = true });
    defer history.deinit();
    try std.testing.expect(std.mem.indexOf(u8, history.output, "\"count\":2") != null);

    const passed_assertions = [_]zstd.Testing.AssertionResult{.{ .id = "domain-proof", .label = "domain proof", .status = .passed }};
    const passed_receipt = zstd.Testing.TestReceipt{
        .project = "demo",
        .suite = "acceptance",
        .scenario = contractScenario(project_scenario),
        .source_revision = "working-tree",
        .zig_version = @import("builtin").zig_version_string,
        .status = .passed,
        .assertions = &passed_assertions,
    };
    const regressions = try regressionCountsAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{passed_receipt});
    try std.testing.expectEqual(@as(usize, 0), regressions.introduced);
    try std.testing.expectEqual(@as(usize, 1), regressions.resolved);
}

test "generated projects expose agent-readable test list affected and explanation output" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var plan = try generatePlan(std.testing.allocator, .{
        .kind = .application,
        .name = "test-protocol",
        .target = "test-protocol",
    });
    defer plan.deinit();
    _ = try writePlan(std.testing.io, tmp.dir, "test-protocol", plan, .{});

    var list = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "test", "list", "--root", "test-protocol", "--json" });
    defer list.deinit();
    try std.testing.expectEqual(@as(u8, 0), list.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, list.output, "bootstrap-boundaries") != null);
    try std.testing.expect(std.mem.indexOf(u8, list.output, "req-bootstrap") != null);

    var affected = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "test", "affected", "--root", "test-protocol", "--changed", "src/main.zig", "--json" });
    defer affected.deinit();
    try std.testing.expect(std.mem.indexOf(u8, affected.output, "\"selected\":1") != null);

    var explanation = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "test", "explain", "bootstrap-boundaries", "--root", "test-protocol", "--json" });
    defer explanation.deinit();
    try std.testing.expect(std.mem.indexOf(u8, explanation.output, "zigeffect test replay") != null);
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

test "project receipts expose production capability gaps and adapter identity" {
    const manifest = zstd.Project.Manifest{
        .name = "api",
        .kind = .service,
        .components = &.{.{ .id = "api", .kind = .service, .path = "." }},
        .execution_posture = .production,
        .capability_requirements = &.{.{
            .id = "public-http",
            .component = "api",
            .kind = .http_server,
            .minimum_maturity = .production_candidate,
            .requires_live_conformance = true,
        }},
        .adapter_profiles = &.{.{
            .id = "production",
            .target = "aarch64-macos",
            .bindings = &.{.{
                .requirement = "public-http",
                .adapter = "zigeffect-std.memory-http",
            }},
        }},
    };
    try manifest.validate();

    var assessment = try assessCapabilitiesAlloc(std.testing.allocator, manifest, "production", 1_500);
    defer assessment.deinit();
    try std.testing.expectEqual(@as(usize, 1), assessment.gaps);
    try std.testing.expectEqual(zstd.Capability.Match.insufficient_maturity, assessment.evidence[0].result);

    const receipt = try projectReceiptAlloc(
        std.testing.allocator,
        .{ .operation = .check, .json = true, .profile = "production", .evidence_time_ms = 1_500 },
        manifest,
        "check",
        "failed",
        1,
        "production capability requirements are unresolved",
        "",
        "",
    );
    defer std.testing.allocator.free(receipt);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "\"capability_gaps\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "zigeffect-std.memory-http") != null);
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
        try std.testing.expect(plan.find(".gemini/skills/zigeffect-development/SKILL.md") != null);
        try std.testing.expect(plan.find(distribution.compatibility_path) != null);
        try std.testing.expect(plan.find(distribution.scaffold_state_path) != null);
        try std.testing.expect(plan.find("README.md") != null);
        try std.testing.expect(plan.find("test/root_test.zig") != null);

        var parsed = try zstd.Project.parseManifest(std.testing.allocator, plan.find("zigeffect.project.json").?.content);
        defer parsed.deinit();
        try std.testing.expectEqual(kind, parsed.value.kind);
        try std.testing.expectEqual(zstd.Project.SafetyProfile.agent_safe_v1, parsed.value.safety.profile);
        try std.testing.expectEqual(@as(usize, 12), parsed.value.safety.gates.len);

        var compatibility = try distribution.parseCompatibility(std.testing.allocator, plan.find(distribution.compatibility_path).?.content);
        defer compatibility.deinit();
        try std.testing.expectEqual(kind, compatibility.value.kind);
        var state = try distribution.parseState(std.testing.allocator, plan.find(distribution.scaffold_state_path).?.content);
        defer state.deinit();
        try std.testing.expectEqual(kind, state.value.kind);
        try std.testing.expect(state.value.managedFile(distribution.compatibility_path) != null);

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
        }) |path| try std.testing.expect(plan.find(path) != null);
        try std.testing.expect(plan.find("src/causal.zig") == null);
        try std.testing.expect(plan.find("src/causal_graph.zig") == null);

        const app = plan.find("src/app.zig").?.content;
        try std.testing.expect(std.mem.indexOf(u8, app, "zstd.ManagedRuntime") != null);
        try std.testing.expect(std.mem.indexOf(u8, app, "runtime.shutdown()") != null);
        for ([_][]const u8{
            "recordCausal",
            "zstd.Application.record",
            "causal_graph_options",
            "Observability.Recorder",
            "runtime.inspect",
            "runtime.agentMapJsonAlloc",
            "runtime_options.graph",
            "attachBackend",
        }) |boilerplate| try std.testing.expect(std.mem.indexOf(u8, app, boilerplate) == null);

        var manifest = try zstd.Project.parseManifest(std.testing.allocator, plan.find("zigeffect.project.json").?.content);
        defer manifest.deinit();
        try std.testing.expect(std.mem.eql(u8, manifest.value.artifacts.graph, zstd.CausalGraph.default_path));
        try std.testing.expect(std.mem.indexOfScalar(zstd.Project.Capability, manifest.value.components[0].capabilities, .causal_graph) != null);
    }
}

test "every scaffold keeps causal infrastructure out of production source" {
    for ([_]zstd.Project.ProjectKind{ .application, .service, .library, .package, .system }) |kind| {
        var plan = try generatePlan(std.testing.allocator, .{
            .kind = kind,
            .name = "automatic-causal",
            .target = "automatic-causal",
            .zigeffect_std_path = "../../zigeffect-std",
        });
        defer plan.deinit();

        for (plan.files.items) |file| {
            const source = std.mem.startsWith(u8, file.path, "src/") or std.mem.indexOf(u8, file.path, "/src/") != null;
            if (!source or !std.mem.endsWith(u8, file.path, ".zig")) continue;
            for ([_][]const u8{
                "recordCausal",
                "CausalStore.init",
                ".causal_store =",
                "causal_graph_options",
                "attachBackend",
            }) |boilerplate| {
                try std.testing.expect(std.mem.indexOf(u8, file.content, boilerplate) == null);
            }
        }
    }
}

test "local application scaffolds teach only the canonical service layer and managed runtime architecture" {
    var plan = try generatePlan(std.testing.allocator, .{
        .kind = .application,
        .name = "canonical-app",
        .target = "canonical-app",
        .zigeffect_std_path = "../../zigeffect-std",
        .profile = .@"local-fake",
    });
    defer plan.deinit();

    const app = plan.find("src/app.zig").?.content;
    const greeting = plan.find("src/services/greeting.zig").?.content;
    const skill = plan.find(".agents/skills/zigeffect-development/SKILL.md").?.content;
    const claude_skill = plan.find(".claude/skills/zigeffect-development/SKILL.md").?.content;
    const gemini_skill = plan.find(".gemini/skills/zigeffect-development/SKILL.md").?.content;
    const readme = plan.find("README.md").?.content;
    const acceptance_test = plan.find("test/root_test.zig").?.content;
    for ([_][]const u8{
        "const kernel = zstd.fx.kernel;",
        "zstd.ManagedRuntime",
        "kernel.Layer.succeed",
        "pub fn rootLayer()",
        "pub fn runWithOptions(",
        ".flatMap(",
        ".named(\"application.bootstrap\")",
        "runtime.shutdown()",
    }) |contract| try std.testing.expect(std.mem.indexOf(u8, app, contract) != null);
    try std.testing.expect(std.mem.indexOf(u8, greeting, "kernel.Service") != null);
    try std.testing.expect(std.mem.indexOf(u8, greeting, "kernel.Effect") != null);
    try std.testing.expect(std.mem.indexOf(u8, greeting, "kernel.NamedEffect") != null);
    try std.testing.expect(std.mem.indexOf(u8, greeting, "recordCausal") == null);
    try std.testing.expect(std.mem.indexOf(u8, skill, "zstd.ManagedRuntime") != null);
    try std.testing.expectEqualStrings(skill, claude_skill);
    try std.testing.expectEqualStrings(skill, gemini_skill);
    for ([_][]const u8{
        "proof-carrying causal loop",
        "zigeffect agent context",
        ".zigeffect/tests/process-receipts/",
        ".zigeffect/tests/raw-receipts/",
        ".zigeffect/handoffs/tests/",
        "work packet",
        "fencing token",
        "zigeffect graph path",
        "project-mounted graph",
        "Re-query",
    }) |contract| try std.testing.expect(std.mem.indexOf(u8, skill, contract) != null);
    try std.testing.expect(std.mem.indexOf(u8, readme, "## Architecture") != null);
    try std.testing.expect(std.mem.indexOf(u8, readme, "`zstd.ManagedRuntime`") != null);
    try std.testing.expect(std.mem.indexOf(u8, readme, "memoized scoped") != null);
    try std.testing.expect(std.mem.indexOf(u8, acceptance_test, "context.causalStore()") != null);
    try std.testing.expect(std.mem.indexOf(u8, acceptance_test, "app.rootLayer()") != null);
    try std.testing.expect(std.mem.indexOf(u8, acceptance_test, "assertions.event(") != null);
    try std.testing.expect(std.mem.indexOf(u8, acceptance_test, ".kind = .effect_completed") != null);
    try std.testing.expect(std.mem.indexOf(u8, acceptance_test, "tmpDir") == null);

    for ([_][]const u8{
        "EffectEnv",
        "LayerGraph",
        "LayerWithError",
        "ValueProvider",
        "ctx.runEffect",
        "zstd.fx.layerGraph",
        "zstd.fx.Context(",
    }) |legacy| {
        try std.testing.expect(std.mem.indexOf(u8, app, legacy) == null);
        try std.testing.expect(std.mem.indexOf(u8, greeting, legacy) == null);
    }
    try std.testing.expect(std.mem.indexOf(u8, skill, "Compose applications once with `zstd.fx.layerGraph`") == null);
}

test "library scaffolds expose composable service effects and a default layer" {
    var plan = try generatePlan(std.testing.allocator, .{
        .kind = .library,
        .name = "canonical-library",
        .target = "canonical-library",
        .zigeffect_std_path = "../../zigeffect-std",
    });
    defer plan.deinit();

    const source = plan.find("src/root.zig").?.content;
    for ([_][]const u8{
        "kernel.Service",
        "kernel.Effect",
        "kernel.Layer.succeed",
        "defaultLayer",
        "decodeInputAlloc",
    }) |contract| try std.testing.expect(std.mem.indexOf(u8, source, contract) != null);
    const acceptance_test = plan.find("test/root_test.zig").?.content;
    try std.testing.expect(std.mem.indexOf(u8, acceptance_test, "context.causalStore()") != null);
    try std.testing.expect(std.mem.indexOf(u8, acceptance_test, "context.mapCausalEventIds(&runtime)") != null);
    try std.testing.expect(std.mem.indexOf(u8, acceptance_test, "assertions.event(") != null);
    try std.testing.expect(std.mem.indexOf(u8, source, "ManagedRuntime") == null);
    for ([_][]const u8{ "EffectEnv", "LayerGraph", "layerGraph", "ctx.runEffect" }) |legacy| {
        try std.testing.expect(std.mem.indexOf(u8, source, legacy) == null);
    }
}

test "scaffold profiles label authority and production plans use only real wiring" {
    const action = try parseArgs(&.{ "new", "application", "profile-demo", "--profile", "production" });
    try std.testing.expectEqual(ScaffoldProfile.production, action.new.profile);
    for ([_]ScaffoldProfile{ .@"local-fake", .@"integration-real", .production }) |profile| {
        var plan = try generatePlan(std.testing.allocator, .{ .kind = .application, .name = "profile-demo", .target = "profile-demo", .zigeffect_std_path = "../../zigeffect-std", .profile = profile });
        defer plan.deinit();
        const profile_record = plan.find(".zigeffect/adapter-profile.json") orelse return error.MissingAdapterProfile;
        try std.testing.expect(std.mem.indexOf(u8, profile_record.content, @tagName(profile)) != null);
        var manifest = try zstd.Project.parseManifest(std.testing.allocator, plan.find("zigeffect.project.json").?.content);
        defer manifest.deinit();
        try std.testing.expectEqual(@as(usize, if (profile == .@"local-fake") 2 else 3), manifest.value.capability_requirements.len);
        if (profile == .production) try std.testing.expectEqual(zstd.Project.ExecutionPosture.production, manifest.value.execution_posture);
        if (profile != .@"local-fake") {
            try std.testing.expect(plan.find("src/production_wiring.zig") != null);
            for (plan.files.items) |file| {
                try std.testing.expect(std.mem.indexOf(u8, file.content, "FakeDatabase") == null);
                try std.testing.expect(std.mem.indexOf(u8, file.content, "runHealthRoute") == null);
                try std.testing.expect(std.mem.indexOf(u8, file.content, "{\"port\":5178") == null);
            }
        }
    }
}

test "production scaffolds compose adapters as layers outside the root effect" {
    var plan = try generatePlan(std.testing.allocator, .{
        .kind = .application,
        .name = "composed-production",
        .target = "composed-production",
        .zigeffect_std_path = "../../zigeffect-std",
        .profile = .production,
    });
    defer plan.deinit();

    const wiring = plan.find("src/production_wiring.zig").?.content;
    for ([_][]const u8{
        "http.serverLayer()",
        "postgres.sessionLayer()",
        "postgres.poolLayer()",
        "otel.exporterLayer()",
        "zstd.ManagedRuntime",
        "pub fn rootLayer",
        "http.ApplicationMapSlot",
        "http.RuntimeApplicationMapHandler",
        "zstd.Security.secureEql",
        "zstd.Application.Lifecycle.signalLayer()",
    }) |contract| try std.testing.expect(std.mem.indexOf(u8, wiring, contract) != null);

    const config_example = plan.find("config.example.json").?.content;
    try std.testing.expect(std.mem.indexOf(u8, config_example, "database_url") == null);
    try std.testing.expect(std.mem.indexOf(u8, config_example, "agent_map_token") == null);
    try std.testing.expect(std.mem.indexOf(u8, plan.find("src/main.zig").?.content, "init.minimal.environ") != null);
    try std.testing.expect(std.mem.indexOf(u8, wiring, "allocator.create(") == null);
    try std.testing.expect(std.mem.indexOf(u8, wiring, "HandlerBundle") == null);
    try std.testing.expect(std.mem.indexOf(u8, wiring, "runtime.inspect") == null);
    try std.testing.expect(std.mem.indexOf(u8, wiring, "runtime.agentMapJsonAlloc") == null);
    try std.testing.expect(plan.find("src/causal_graph.zig") == null);

    const effect_start = std.mem.indexOf(u8, wiring, "pub fn program") orelse return error.MissingProductionEffect;
    const root_start = std.mem.indexOfPos(u8, wiring, effect_start, "pub fn run(") orelse return error.MissingCompositionRoot;
    const effect_source = wiring[effect_start..root_start];
    for ([_][]const u8{
        "http.Server.init",
        "postgres.Session.init",
        "postgres.Pool.initAlloc",
        "otel.Exporter.init",
        "CausalStore.init",
        "layerGraph",
    }) |forbidden| try std.testing.expect(std.mem.indexOf(u8, effect_source, forbidden) == null);
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
    const system_source = plan.find("src/root.zig").?.content;
    const system_test = plan.find("test/root_test.zig").?.content;
    try std.testing.expect(std.mem.indexOf(u8, system_source, "pub fn runWithOptions(") != null);
    try std.testing.expect(std.mem.indexOf(u8, system_test, "context.causalStore()") != null);
    try std.testing.expect(std.mem.indexOf(u8, system_test, "system.runWithOptions") != null);
    try std.testing.expect(std.mem.indexOf(u8, system_test, "Greeting.greet") != null);
}

test "every scaffold matches the committed compatibility snapshot" {
    const SnapshotCase = struct { kind: zstd.Project.ProjectKind, files: usize, sha256: []const u8 };
    const Snapshot = struct {
        schema: []const u8,
        schema_version: u32,
        template_schema: []const u8,
        template_version: u32,
        project: []const u8,
        cases: []const SnapshotCase,
    };
    var snapshot = try std.json.parseFromSlice(Snapshot, std.testing.allocator, @embedFile("snapshots/scaffold-contracts.v1.json"), .{ .allocate = .alloc_always });
    defer snapshot.deinit();
    try std.testing.expectEqualStrings("zigeffect.scaffold-contract-snapshot.v1", snapshot.value.schema);
    try std.testing.expectEqual(@as(u32, 1), snapshot.value.schema_version);
    try std.testing.expectEqualStrings(distribution.template_schema, snapshot.value.template_schema);
    try std.testing.expectEqual(distribution.template_version, snapshot.value.template_version);
    try std.testing.expectEqual(@as(usize, 5), snapshot.value.cases.len);

    var snapshot_matches = true;
    for (snapshot.value.cases) |expected_case| {
        var plan = try generatePlan(std.testing.allocator, .{
            .kind = expected_case.kind,
            .name = snapshot.value.project,
            .target = snapshot.value.project,
            .zigeffect_path = "../zigeffect",
            .zigeffect_std_path = "../zigeffect-std",
        });
        defer plan.deinit();
        const digest = try distribution.contractDigestAlloc(std.testing.allocator, plan);
        defer std.testing.allocator.free(digest);
        if (expected_case.files != plan.files.items.len or !std.mem.eql(u8, expected_case.sha256, digest)) {
            snapshot_matches = false;
            std.debug.print("scaffold snapshot {s}: files={d}, sha256={s}\n", .{ @tagName(expected_case.kind), plan.files.items.len, digest });
        }
    }
    try std.testing.expect(snapshot_matches);
}

test "graph commands query manifest-owned durable causal evidence" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var plan = try generatePlan(std.testing.allocator, .{
        .kind = .application,
        .name = "graph-project",
        .target = "graph-project",
    });
    defer plan.deinit();
    _ = try writePlan(std.testing.io, tmp.dir, "graph-project", plan, .{});

    {
        var root = try tmp.dir.openDir(std.testing.io, "graph-project", .{});
        defer root.close(std.testing.io);
        var database = try zstd.CausalGraph.LocalDatabase.init(std.testing.allocator, std.testing.io, root, .{});
        defer database.deinit();
        var backend = database.storageBackend(std.testing.allocator, 16);
        defer backend.deinit();
        var store = zstd.fx.CausalStore.init(std.testing.allocator);
        defer store.deinit();
        store.attachBackend(backend.backend());
        const parent = try store.record(.{ .kind = .effect_started, .label = "cli-graph-proof" });
        _ = try store.record(.{ .kind = .effect_completed, .label = "cli-graph-proof", .parent_id = parent, .status = "success" });
        try backend.flush();
        try std.testing.expectEqual(@as(u64, 0), store.backendFailureCount());
    }

    var status = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "graph", "status", "--root", "graph-project", "--json" });
    defer status.deinit();
    try std.testing.expectEqual(@as(u8, 0), status.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, status.output, "\"records\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, status.output, "\"edges\":1") != null);

    var event = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "graph", "event", "2", "--root", "graph-project", "--json" });
    defer event.deinit();
    try std.testing.expect(std.mem.indexOf(u8, event.output, "cli-graph-proof") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.output, "\"from\":1") != null);

    var since = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "graph", "since", "1", "--limit", "1", "--root", "graph-project", "--json" });
    defer since.deinit();
    try std.testing.expect(std.mem.indexOf(u8, since.output, zstd.CausalGraph.records_since_schema) != null);
    try std.testing.expect(std.mem.indexOf(u8, since.output, "\"after_event_id\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, since.output, "\"next_event_id\":2") != null);

    var children = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "graph", "children", "1", "--root", "graph-project", "--json" });
    defer children.deinit();
    try std.testing.expect(std.mem.indexOf(u8, children.output, "\"children\":[2]") != null);

    var path = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "graph", "path", "1", "2", "--limit", "8", "--root", "graph-project", "--json" });
    defer path.deinit();
    try std.testing.expect(std.mem.indexOf(u8, path.output, zstd.CausalGraph.path_schema) != null);
    try std.testing.expect(std.mem.indexOf(u8, path.output, "\"event_ids\":[1,2]") != null);
}

test "graph status and since zero expose a read-only empty first-run baseline" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var plan = try generatePlan(std.testing.allocator, .{
        .kind = .application,
        .name = "empty-graph-project",
        .target = "empty-graph-project",
    });
    defer plan.deinit();
    _ = try writePlan(std.testing.io, tmp.dir, "empty-graph-project", plan, .{});

    var status = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{
        "graph", "status", "--root", "empty-graph-project", "--json",
    });
    defer status.deinit();
    try std.testing.expectEqual(@as(u8, 0), status.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, status.output, "\"records\":0") != null);
    try std.testing.expect(std.mem.indexOf(u8, status.output, "\"newest_durable_event_id\":null") != null);

    var since = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{
        "graph", "since", "0", "--root", "empty-graph-project", "--json",
    });
    defer since.deinit();
    try std.testing.expectEqual(@as(u8, 0), since.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, since.output, "\"records\":[]") != null);
    try std.testing.expect(std.mem.indexOf(u8, since.output, "\"truncated\":false") != null);

    var project = try tmp.dir.openDir(std.testing.io, "empty-graph-project", .{});
    defer project.close(std.testing.io);
    try std.testing.expectError(error.FileNotFound, project.access(std.testing.io, ".zigeffect/graph/causal-graph.jsonl", .{}));
}

test "statechart commands query only the manifest-owned artifact catalog" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var plan = try generatePlan(std.testing.allocator, .{
        .kind = .application,
        .name = "statechart-project",
        .target = "statechart-project",
    });
    defer plan.deinit();
    _ = try writePlan(std.testing.io, tmp.dir, "statechart-project", plan, .{});

    {
        var root = try tmp.dir.openDir(std.testing.io, "statechart-project", .{});
        defer root.close(std.testing.io);
        try root.createDirPath(std.testing.io, zstd.Statechart.default_path);
        const catalog_json =
            \\{"schema":"zigeffect.statechart.catalog.v1","schema_version":1,
            \\ "definitions":[{"schema":"zigeffect.statechart.definition.v1","id":"agent.review","fingerprint":44,"states":[],"transitions":[]}],
            \\ "snapshots":[{"schema":"zigeffect.statechart.snapshot.v1","instance_id":7,"definition_fingerprint":44,"revision":2,"state":"ready"}],
            \\ "executions":[{"schema":"zigeffect.statechart.execution.v1","instance_id":7,"revision":2,"transition_id":"approve"}],
            \\ "coverage":[{"schema":"zigeffect.statechart.coverage.v1","definition_fingerprint":44,"visited":3}],
            \\ "paths":[{"schema":"zigeffect.statechart.paths.v1","definition_id":"agent.review","transitions":["approve"]}],
            \\ "projections":[{"definition_id":"agent.review","xstate":{"id":"agent.review"},"mermaid":"stateDiagram-v2","dot":"digraph statechart {}"}]}
        ;
        const catalog_path = try std.fmt.allocPrint(std.testing.allocator, "{s}/{s}", .{ zstd.Statechart.default_path, zstd.Statechart.catalog_file });
        defer std.testing.allocator.free(catalog_path);
        try root.writeFile(std.testing.io, .{ .sub_path = catalog_path, .data = catalog_json });
    }

    var list = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "statechart", "list", "--root", "statechart-project", "--json" });
    defer list.deinit();
    try std.testing.expect(std.mem.indexOf(u8, list.output, "agent.review") != null);
    var show = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "statechart", "show", "agent.review", "--root", "statechart-project", "--json" });
    defer show.deinit();
    try std.testing.expect(std.mem.indexOf(u8, show.output, "definition.v1") != null);
    var instances = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "statechart", "instances", "agent.review", "--root", "statechart-project", "--json" });
    defer instances.deinit();
    try std.testing.expect(std.mem.indexOf(u8, instances.output, "\"instance_id\":7") != null);
    var trace = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "statechart", "trace", "7", "--root", "statechart-project", "--json" });
    defer trace.deinit();
    try std.testing.expect(std.mem.indexOf(u8, trace.output, "approve") != null);
    var explanation = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "statechart", "explain", "7", "--root", "statechart-project", "--json" });
    defer explanation.deinit();
    try std.testing.expect(std.mem.indexOf(u8, explanation.output, "latest_execution") != null);
    var coverage = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "statechart", "coverage", "agent.review", "--root", "statechart-project", "--json" });
    defer coverage.deinit();
    try std.testing.expect(std.mem.indexOf(u8, coverage.output, "\"visited\":3") != null);
    var paths = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "statechart", "paths", "agent.review", "--root", "statechart-project", "--json" });
    defer paths.deinit();
    try std.testing.expect(std.mem.indexOf(u8, paths.output, "approve") != null);
    var exported = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "statechart", "export", "agent.review", "--format", "mermaid", "--root", "statechart-project" });
    defer exported.deinit();
    try std.testing.expectEqualStrings("stateDiagram-v2", exported.output);
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

test "upgrade adopts pristine scaffolds preserves user source rejects managed conflicts and migrates manifests" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var plan = try generatePlan(std.testing.allocator, .{
        .kind = .application,
        .name = "upgrade-app",
        .target = "upgrade-app",
        .zigeffect_path = "../../zigeffect",
        .zigeffect_std_path = "../../zigeffect-std",
    });
    defer plan.deinit();
    _ = try writePlan(std.testing.io, tmp.dir, "upgrade-app", plan, .{});

    var compatible = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "compatibility", "--root", "upgrade-app", "--json" });
    defer compatible.deinit();
    try std.testing.expectEqual(@as(u8, 0), compatible.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, compatible.output, "\"compatible\":true") != null);

    try tmp.dir.deleteFile(std.testing.io, "upgrade-app/.zigeffect/scaffold-state.json");
    try tmp.dir.deleteFile(std.testing.io, "upgrade-app/.zigeffect/compatibility.json");
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "upgrade-app/src/app.zig", .data = "// user-owned application source\n" });
    var adopt = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "upgrade", "--root", "upgrade-app", "--apply", "--json" });
    defer adopt.deinit();
    try std.testing.expectEqual(@as(u8, 0), adopt.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, adopt.output, "\"status\":\"applied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, adopt.output, "\"state_adoption\":true") != null);
    const preserved = try tmp.dir.readFileAlloc(std.testing.io, "upgrade-app/src/app.zig", std.testing.allocator, .limited(1024));
    defer std.testing.allocator.free(preserved);
    try std.testing.expectEqualStrings("// user-owned application source\n", preserved);

    const managed_path = "upgrade-app/.agents/skills/zigeffect-development/SKILL.md";
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = managed_path, .data = "user-edited managed skill\n" });
    var conflict = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "upgrade", "--root", "upgrade-app", "--apply", "--json" });
    defer conflict.deinit();
    try std.testing.expectEqual(@as(u8, 3), conflict.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, conflict.output, "\"status\":\"conflict\"") != null);
    const retained = try tmp.dir.readFileAlloc(std.testing.io, managed_path, std.testing.allocator, .limited(1024));
    defer std.testing.allocator.free(retained);
    try std.testing.expectEqualStrings("user-edited managed skill\n", retained);

    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = managed_path, .data = plan.find(".agents/skills/zigeffect-development/SKILL.md").?.content });
    const manifest_text = try tmp.dir.readFileAlloc(std.testing.io, "upgrade-app/zigeffect.project.json", std.testing.allocator, .limited(1024 * 1024));
    defer std.testing.allocator.free(manifest_text);
    var parsed = try std.json.parseFromSlice(zstd.Project.Manifest, std.testing.allocator, manifest_text, .{ .allocate = .alloc_always });
    defer parsed.deinit();
    parsed.value.schema = distribution.legacy_project_schema;
    const legacy = try std.json.Stringify.valueAlloc(std.testing.allocator, parsed.value, .{});
    defer std.testing.allocator.free(legacy);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "upgrade-app/zigeffect.project.json", .data = legacy });

    var migrate = try runAlloc(std.testing.allocator, std.testing.io, tmp.dir, &.{ "upgrade", "--root", "upgrade-app", "--apply", "--json" });
    defer migrate.deinit();
    try std.testing.expectEqual(@as(u8, 0), migrate.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, migrate.output, "\"action\":\"migrate\"") != null);
    const migrated_text = try tmp.dir.readFileAlloc(std.testing.io, "upgrade-app/zigeffect.project.json", std.testing.allocator, .limited(1024 * 1024));
    defer std.testing.allocator.free(migrated_text);
    var migrated = try zstd.Project.parseManifest(std.testing.allocator, migrated_text);
    defer migrated.deinit();
    try std.testing.expectEqualStrings(zstd.Project.schema_version, migrated.value.schema);
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

test "production capability evidence verifies content and rejects tampering" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(std.testing.io, "conformance");
    const receipt = "{\"schema\":\"zigeffect.live-conformance-receipt.v1\",\"adapter\":\"test.adapter\",\"status\":\"passed\",\"observed_at_ms\":1000}";
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "conformance/live.json", .data = receipt });
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(receipt, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    const digest_ref = try std.fmt.allocPrint(std.testing.allocator, "sha256:{s}", .{hex});
    defer std.testing.allocator.free(digest_ref);
    const evidence = zstd.Capability.AdapterEvidence{
        .profile_id = "production",
        .requirement_id = "http",
        .target = "native",
        .adapter_id = "test.adapter",
        .kind = .http_server,
        .maturity = .production_candidate,
        .result = .matched,
        .conformance_schema = "test.conformance",
        .conformance_version = 1,
        .conformance_receipt = "conformance/live.json",
        .conformance_authority = .live_external,
        .observed_at_ms = 1000,
        .valid_until_ms = 2000,
        .content_sha256 = digest_ref,
    };
    try std.testing.expect(try verifyCapabilityEvidence(std.testing.allocator, .{ .io = std.testing.io, .dir = tmp.dir }, evidence));
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "conformance/live.json", .data = "{}" });
    try std.testing.expect(!try verifyCapabilityEvidence(std.testing.allocator, .{ .io = std.testing.io, .dir = tmp.dir }, evidence));
}
