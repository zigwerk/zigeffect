const std = @import("std");
const Secrets = @import("../secrets/root.zig");

pub const schema_version = "zigeffect.project.v1";

pub const ProjectError = error{
    UnsupportedSchema,
    InvalidName,
    InvalidVersion,
    InvalidPath,
    InvalidProjectShape,
    DuplicateComponent,
    DuplicateComponentPath,
    MissingDependency,
    SelfDependency,
    DependencyCycle,
    DuplicateCapability,
    InvalidCommand,
    DuplicateCommand,
    InvalidRequirement,
    DuplicateRequirement,
    InvalidAcceptanceCheck,
    DuplicateAcceptanceCheck,
    SecretDetected,
    DuplicatePath,
};

pub const ProjectKind = enum {
    application,
    service,
    library,
    package,
    system,
};

pub const ComponentKind = enum {
    application,
    service,
    library,
    package,
};

pub const Capability = enum {
    cli,
    http,
    sql,
    config,
    observability,
    agent,
    workbench,
};

pub const Component = struct {
    id: []const u8,
    kind: ComponentKind,
    path: []const u8,
    depends_on: []const []const u8 = &.{},
    capabilities: []const Capability = &.{},
};

pub const Command = struct {
    id: []const u8,
    argv: []const []const u8,
    component: ?[]const u8 = null,
};

pub const RequirementStatus = enum {
    planned,
    active,
    satisfied,
    blocked,
};

pub const Requirement = struct {
    id: []const u8,
    summary: []const u8,
    component: []const u8,
    status: RequirementStatus = .planned,
};

pub const AcceptanceStatus = enum {
    pending,
    passed,
    failed,
    blocked,
};

pub const AcceptanceCheck = struct {
    id: []const u8,
    requirement: []const u8,
    command: []const u8,
    expectation: []const u8,
    status: AcceptanceStatus = .pending,
};

pub const Policy = struct {
    allow_network: bool = false,
    require_approval_for_processes: bool = true,
    persist_raw_terminal: bool = false,
};

pub const ArtifactPaths = struct {
    sessions: []const u8 = ".zigeffect/sessions",
    causal: []const u8 = ".zigeffect/causal",
    receipts: []const u8 = ".zigeffect/receipts",
};

pub const DependencyPaths = struct {
    zigeffect: []const u8 = "../zigeffect",
    zigeffect_std: []const u8 = "../zigeffect-std",
};

pub const Manifest = struct {
    schema: []const u8 = schema_version,
    name: []const u8,
    version: []const u8 = "0.1.0",
    kind: ProjectKind,
    components: []const Component,
    commands: []const Command = &.{},
    requirements: []const Requirement = &.{},
    acceptance_checks: []const AcceptanceCheck = &.{},
    policy: Policy = .{},
    artifacts: ArtifactPaths = .{},
    dependencies: DependencyPaths = .{},

    pub fn validate(self: Manifest) ProjectError!void {
        if (!std.mem.eql(u8, self.schema, schema_version)) return error.UnsupportedSchema;
        try validateIdentifier(self.name);
        try ensureSafe(self.version);
        if (!isSemanticVersion(self.version)) return error.InvalidVersion;
        if (self.components.len == 0) return error.InvalidProjectShape;
        if (self.kind == .system) {
            if (self.components.len < 2) return error.InvalidProjectShape;
        } else if (self.components.len != 1) {
            return error.InvalidProjectShape;
        } else if (!std.mem.eql(u8, self.components[0].id, self.name)) {
            return error.InvalidProjectShape;
        }

        for (self.components, 0..) |item, index| {
            try validateIdentifier(item.id);
            try validateRelativePath(item.path, true);
            if (self.kind != .system and componentKindToProject(item.kind) != self.kind) {
                return error.InvalidProjectShape;
            }
            for (self.components[0..index]) |previous| {
                if (std.mem.eql(u8, previous.id, item.id)) return error.DuplicateComponent;
                if (std.mem.eql(u8, previous.path, item.path)) return error.DuplicateComponentPath;
            }
            for (item.capabilities, 0..) |capability, capability_index| {
                for (item.capabilities[0..capability_index]) |previous| {
                    if (previous == capability) return error.DuplicateCapability;
                }
            }
            for (item.depends_on) |dependency| {
                try validateIdentifier(dependency);
                if (std.mem.eql(u8, item.id, dependency)) return error.SelfDependency;
                if (self.component(dependency) == null) return error.MissingDependency;
                try ensureSafe(dependency);
            }
        }
        for (self.components) |item| {
            if (self.dependencyPathReturnsTo(item.id, item.id, 0)) {
                return error.DependencyCycle;
            }
        }

        for (self.commands, 0..) |command_item, index| {
            try validateIdentifier(command_item.id);
            if (command_item.argv.len == 0) return error.InvalidCommand;
            for (command_item.argv) |arg| {
                if (arg.len == 0) return error.InvalidCommand;
                try ensureSafe(arg);
            }
            if (command_item.component) |component_id| {
                if (self.component(component_id) == null) return error.InvalidCommand;
            }
            for (self.commands[0..index]) |previous| {
                if (std.mem.eql(u8, previous.id, command_item.id)) return error.DuplicateCommand;
            }
        }

        for (self.requirements, 0..) |requirement_item, index| {
            try validateIdentifier(requirement_item.id);
            if (requirement_item.summary.len == 0 or self.component(requirement_item.component) == null) {
                return error.InvalidRequirement;
            }
            try ensureSafe(requirement_item.summary);
            for (self.requirements[0..index]) |previous| {
                if (std.mem.eql(u8, previous.id, requirement_item.id)) return error.DuplicateRequirement;
            }
        }

        for (self.acceptance_checks, 0..) |check, index| {
            try validateIdentifier(check.id);
            if (check.expectation.len == 0 or self.requirement(check.requirement) == null or self.command(check.command) == null) {
                return error.InvalidAcceptanceCheck;
            }
            try ensureSafe(check.expectation);
            for (self.acceptance_checks[0..index]) |previous| {
                if (std.mem.eql(u8, previous.id, check.id)) return error.DuplicateAcceptanceCheck;
            }
        }

        try validateRelativePath(self.artifacts.sessions, false);
        try validateRelativePath(self.artifacts.causal, false);
        try validateRelativePath(self.artifacts.receipts, false);
        try validateDependencyPath(self.dependencies.zigeffect);
        try validateDependencyPath(self.dependencies.zigeffect_std);
    }

    pub fn component(self: Manifest, id: []const u8) ?Component {
        for (self.components) |candidate| {
            if (std.mem.eql(u8, candidate.id, id)) return candidate;
        }
        return null;
    }

    pub fn command(self: Manifest, id: []const u8) ?Command {
        for (self.commands) |candidate| {
            if (std.mem.eql(u8, candidate.id, id)) return candidate;
        }
        return null;
    }

    pub fn requirement(self: Manifest, id: []const u8) ?Requirement {
        for (self.requirements) |candidate| {
            if (std.mem.eql(u8, candidate.id, id)) return candidate;
        }
        return null;
    }

    pub fn jsonAlloc(self: Manifest, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        return std.json.Stringify.valueAlloc(allocator, self, .{});
    }

    fn dependencyPathReturnsTo(self: Manifest, start: []const u8, current: []const u8, depth: usize) bool {
        if (depth > self.components.len) return true;
        const current_component = self.component(current) orelse return false;
        for (current_component.depends_on) |dependency| {
            if (std.mem.eql(u8, dependency, start)) return true;
            if (self.dependencyPathReturnsTo(start, dependency, depth + 1)) return true;
        }
        return false;
    }
};

pub const ParsedManifest = std.json.Parsed(Manifest);

pub fn parseManifest(allocator: std.mem.Allocator, input: []const u8) !ParsedManifest {
    var parsed = try std.json.parseFromSlice(Manifest, allocator, input, .{});
    errdefer parsed.deinit();
    try parsed.value.validate();
    return parsed;
}

pub const GeneratedFile = struct {
    path: []u8,
    content: []u8,
};

pub const FilePlan = struct {
    allocator: std.mem.Allocator,
    files: std.ArrayList(GeneratedFile) = .empty,

    pub fn init(allocator: std.mem.Allocator) FilePlan {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *FilePlan) void {
        for (self.files.items) |file| {
            self.allocator.free(file.path);
            self.allocator.free(file.content);
        }
        self.files.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn add(self: *FilePlan, path: []const u8, content: []const u8) (ProjectError || std.mem.Allocator.Error)!void {
        try validateRelativePath(path, false);
        try ensureSafe(path);
        try ensureSafe(content);
        if (self.find(path) != null) return error.DuplicatePath;

        const owned_path = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(owned_path);
        const owned_content = try self.allocator.dupe(u8, content);
        errdefer self.allocator.free(owned_content);
        try self.files.append(self.allocator, .{ .path = owned_path, .content = owned_content });
    }

    pub fn sort(self: *FilePlan) ProjectError!void {
        std.mem.sort(GeneratedFile, self.files.items, {}, lessThanFile);
    }

    pub fn find(self: FilePlan, path: []const u8) ?GeneratedFile {
        for (self.files.items) |file| {
            if (std.mem.eql(u8, file.path, path)) return file;
        }
        return null;
    }
};

pub const ScaffoldStatus = enum {
    planned,
    created,
    refused,
    failed,
};

pub const ScaffoldReceipt = struct {
    schema: []const u8 = "zigeffect.scaffold-receipt.v1",
    project: []const u8,
    kind: ProjectKind,
    target: []const u8,
    status: ScaffoldStatus,
    files: usize,
    detail: []const u8 = "",

    pub fn jsonAlloc(self: ScaffoldReceipt, allocator: std.mem.Allocator) ![]u8 {
        const safe_project = try Secrets.redactAlloc(allocator, self.project);
        defer allocator.free(safe_project);
        const safe_target = try Secrets.redactAlloc(allocator, self.target);
        defer allocator.free(safe_target);
        const safe_detail = try Secrets.redactAlloc(allocator, self.detail);
        defer allocator.free(safe_detail);
        const json_value = .{
            .schema = self.schema,
            .project = safe_project,
            .kind = self.kind,
            .target = safe_target,
            .status = self.status,
            .files = self.files,
            .detail = safe_detail,
        };
        return std.json.Stringify.valueAlloc(allocator, json_value, .{});
    }
};

pub fn validateIdentifier(value: []const u8) ProjectError!void {
    if (value.len == 0 or value.len > 64 or value[0] < 'a' or value[0] > 'z') return error.InvalidName;
    var previous_dash = false;
    for (value) |byte| {
        const valid = (byte >= 'a' and byte <= 'z') or (byte >= '0' and byte <= '9') or byte == '-';
        if (!valid or (byte == '-' and previous_dash)) return error.InvalidName;
        previous_dash = byte == '-';
    }
    if (value[value.len - 1] == '-') return error.InvalidName;
    try ensureSafe(value);
}

pub fn validateRelativePath(path: []const u8, allow_root: bool) ProjectError!void {
    if (path.len == 0 or path[0] == '/' or path[path.len - 1] == '/' or std.mem.indexOfScalar(u8, path, '\\') != null or std.mem.indexOfScalar(u8, path, 0) != null) {
        return error.InvalidPath;
    }
    if (std.mem.eql(u8, path, ".")) {
        if (allow_root) return;
        return error.InvalidPath;
    }
    var segments = std.mem.splitScalar(u8, path, '/');
    while (segments.next()) |segment| {
        if (segment.len == 0 or std.mem.eql(u8, segment, ".") or std.mem.eql(u8, segment, "..")) return error.InvalidPath;
    }
}

pub fn validateDependencyPath(path: []const u8) ProjectError!void {
    if (path.len == 0 or path[0] == '/' or path[path.len - 1] == '/' or std.mem.indexOfScalar(u8, path, '\\') != null or std.mem.indexOfScalar(u8, path, 0) != null) {
        return error.InvalidPath;
    }
    var has_target = false;
    var segments = std.mem.splitScalar(u8, path, '/');
    while (segments.next()) |segment| {
        if (segment.len == 0 or std.mem.eql(u8, segment, ".")) return error.InvalidPath;
        if (!std.mem.eql(u8, segment, "..")) has_target = true;
    }
    if (!has_target) return error.InvalidPath;
    try ensureSafe(path);
}

fn componentKindToProject(kind: ComponentKind) ProjectKind {
    return switch (kind) {
        .application => .application,
        .service => .service,
        .library => .library,
        .package => .package,
    };
}

fn isSemanticVersion(value: []const u8) bool {
    var parts = std.mem.splitScalar(u8, value, '.');
    var count: usize = 0;
    while (parts.next()) |part| {
        if (part.len == 0) return false;
        for (part) |byte| if (!std.ascii.isDigit(byte)) return false;
        count += 1;
    }
    return count == 3;
}

fn ensureSafe(value: []const u8) ProjectError!void {
    if (Secrets.containsSecret(value)) return error.SecretDetected;
}

fn lessThanFile(_: void, left: GeneratedFile, right: GeneratedFile) bool {
    return std.mem.order(u8, left.path, right.path) == .lt;
}

test "Project validates a production system manifest and round trips stable JSON" {
    const shared = Component{
        .id = "shared-domain",
        .kind = .package,
        .path = "packages/shared-domain",
        .capabilities = &.{ .config, .observability },
    };
    const api = Component{
        .id = "api-service",
        .kind = .service,
        .path = "services/api-service",
        .depends_on = &.{"shared-domain"},
        .capabilities = &.{ .http, .sql, .config, .observability, .agent, .workbench },
    };
    const worker = Component{
        .id = "worker-service",
        .kind = .service,
        .path = "services/worker-service",
        .depends_on = &.{"shared-domain"},
        .capabilities = &.{ .cli, .sql, .config, .observability, .agent, .workbench },
    };
    const manifest = Manifest{
        .name = "billing-system",
        .kind = .system,
        .components = &.{ shared, api, worker },
        .commands = &.{
            .{ .id = "check", .argv = &.{ "zig", "build", "test" } },
            .{ .id = "dev", .argv = &.{ "zig", "build", "run" } },
        },
        .requirements = &.{.{
            .id = "req-health",
            .summary = "Expose typed health state",
            .component = "api-service",
        }},
        .acceptance_checks = &.{.{
            .id = "check-health",
            .requirement = "req-health",
            .command = "check",
            .expectation = "all tests pass",
        }},
    };

    try manifest.validate();

    const json = try manifest.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    var parsed = try parseManifest(std.testing.allocator, json);
    defer parsed.deinit();
    try parsed.value.validate();
    try std.testing.expectEqualStrings("billing-system", parsed.value.name);
    try std.testing.expectEqual(@as(usize, 3), parsed.value.components.len);

    const encoded_again = try parsed.value.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(encoded_again);
    try std.testing.expectEqualStrings(json, encoded_again);
}

test "Project rejects unknown schemas unsafe paths and invalid component graphs" {
    const unknown_schema = Manifest{
        .schema = "zigeffect.project.v99",
        .name = "demo-app",
        .kind = .application,
        .components = &.{.{ .id = "demo-app", .kind = .application, .path = "." }},
    };
    try std.testing.expectError(error.UnsupportedSchema, unknown_schema.validate());

    const traversal = Manifest{
        .name = "demo-app",
        .kind = .application,
        .components = &.{.{ .id = "demo-app", .kind = .application, .path = "../outside" }},
    };
    try std.testing.expectError(error.InvalidPath, traversal.validate());

    const cycle = Manifest{
        .name = "demo-system",
        .kind = .system,
        .components = &.{
            .{ .id = "service-a", .kind = .service, .path = "services/service-a", .depends_on = &.{"service-b"} },
            .{ .id = "service-b", .kind = .service, .path = "services/service-b", .depends_on = &.{"service-a"} },
        },
    };
    try std.testing.expectError(error.DependencyCycle, cycle.validate());
}

test "Project rejects malformed versions duplicates and broken dependency references" {
    const bad_version = Manifest{
        .name = "demo-app",
        .version = "1.0",
        .kind = .application,
        .components = &.{.{ .id = "demo-app", .kind = .application, .path = "." }},
    };
    try std.testing.expectError(error.InvalidVersion, bad_version.validate());

    const duplicate_component = Manifest{
        .name = "demo-system",
        .kind = .system,
        .components = &.{
            .{ .id = "api", .kind = .service, .path = "services/api" },
            .{ .id = "api", .kind = .service, .path = "services/worker" },
        },
    };
    try std.testing.expectError(error.DuplicateComponent, duplicate_component.validate());

    const duplicate_path = Manifest{
        .name = "demo-system",
        .kind = .system,
        .components = &.{
            .{ .id = "api", .kind = .service, .path = "services/api" },
            .{ .id = "worker", .kind = .service, .path = "services/api" },
        },
    };
    try std.testing.expectError(error.DuplicateComponentPath, duplicate_path.validate());

    const missing_dependency = Manifest{
        .name = "demo-system",
        .kind = .system,
        .components = &.{
            .{ .id = "api", .kind = .service, .path = "services/api", .depends_on = &.{"missing"} },
            .{ .id = "worker", .kind = .service, .path = "services/worker" },
        },
    };
    try std.testing.expectError(error.MissingDependency, missing_dependency.validate());

    const self_dependency = Manifest{
        .name = "demo-system",
        .kind = .system,
        .components = &.{
            .{ .id = "api", .kind = .service, .path = "services/api", .depends_on = &.{"api"} },
            .{ .id = "worker", .kind = .service, .path = "services/worker" },
        },
    };
    try std.testing.expectError(error.SelfDependency, self_dependency.validate());

    const duplicate_capability = Manifest{
        .name = "demo-app",
        .kind = .application,
        .components = &.{.{
            .id = "demo-app",
            .kind = .application,
            .path = ".",
            .capabilities = &.{ .http, .http },
        }},
    };
    try std.testing.expectError(error.DuplicateCapability, duplicate_capability.validate());
}

test "Project parser fails closed for unknown fields and unsafe dependency locations" {
    const unknown_field =
        \\{"schema":"zigeffect.project.v1","name":"demo-app","kind":"application","components":[{"id":"demo-app","kind":"application","path":"."}],"surprise":true}
    ;
    try std.testing.expectError(error.UnknownField, parseManifest(std.testing.allocator, unknown_field));

    const absolute_dependency = Manifest{
        .name = "demo-app",
        .kind = .application,
        .components = &.{.{ .id = "demo-app", .kind = .application, .path = "." }},
        .dependencies = .{ .zigeffect = "/tmp/zigeffect" },
    };
    try std.testing.expectError(error.InvalidPath, absolute_dependency.validate());
    try validateDependencyPath("../../../packages/zigeffect");
}

test "Project file plans own content sort deterministically and reject collisions" {
    var plan = FilePlan.init(std.testing.allocator);
    defer plan.deinit();

    var mutable = [_]u8{ 'm', 'a', 'i', 'n' };
    try plan.add("src/zeta.zig", "zeta");
    try plan.add("build.zig", mutable[0..]);
    mutable[0] = 'X';
    try plan.add("src/alpha.zig", "alpha");
    try plan.sort();

    try std.testing.expectEqualStrings("build.zig", plan.files.items[0].path);
    try std.testing.expectEqualStrings("main", plan.files.items[0].content);
    try std.testing.expectEqualStrings("src/alpha.zig", plan.files.items[1].path);
    try std.testing.expectEqualStrings("zeta", plan.find("src/zeta.zig").?.content);
    try std.testing.expectError(error.DuplicatePath, plan.add("build.zig", "other"));
    try std.testing.expectError(error.InvalidPath, plan.add("../../escape", "bad"));
}

test "Project rejects secrets and redacts receipt detail" {
    const secret_manifest = Manifest{
        .name = "demo-app",
        .kind = .application,
        .components = &.{.{ .id = "demo-app", .kind = .application, .path = "." }},
        .requirements = &.{.{
            .id = "req-secret",
            .summary = "token=sentinel-secret-for-tests",
            .component = "demo-app",
        }},
    };
    try std.testing.expectError(error.SecretDetected, secret_manifest.validate());

    const receipt = ScaffoldReceipt{
        .project = "demo-app",
        .kind = .application,
        .target = "./demo-app",
        .status = .refused,
        .files = 0,
        .detail = "authorization: Bearer sentinel-secret-for-tests",
    };
    const json = try receipt.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "sentinel-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "[REDACTED]") != null);
}
