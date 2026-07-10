const std = @import("std");
pub const zstd = @import("zigeffect_std");
const templates = @import("templates.zig");

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
};

pub fn parseArgs(args: []const []const u8) (CliError || zstd.Project.ProjectError)!Action {
    if (args.len == 0) return error.MissingCommand;
    if (args.len == 1 and (eql(args[0], "--help") or eql(args[0], "help"))) return .help;
    if (args.len == 1 and (eql(args[0], "--version") or eql(args[0], "version"))) return .version;
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
        try std.testing.expectEqual(@as(usize, 3), parsed.value.safety.gates.len);

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
