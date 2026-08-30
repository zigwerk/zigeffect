const std = @import("std");
const zstd = @import("zigeffect_std");

pub const cli_version = "0.7.0";
pub const template_version: u32 = 18;
pub const template_schema = "zigeffect.scaffold-template.v1";
pub const compatibility_schema = "zigeffect.compatibility.v1";
pub const scaffold_state_schema = "zigeffect.scaffold-state.v1";
pub const upgrade_receipt_schema = "zigeffect.upgrade-receipt.v1";
pub const minimum_zig_version = "0.16.0";
pub const maximum_zig_version_exclusive = "0.17.0";
pub const legacy_project_schema = "zigeffect.project.v0";
pub const scaffold_state_path = ".zigeffect/scaffold-state.json";
pub const compatibility_path = ".zigeffect/compatibility.json";

pub const Shell = enum { bash, zsh, fish };

pub const CompatibilityMetadata = struct {
    schema: []const u8 = compatibility_schema,
    schema_version: u32 = 1,
    project: []const u8,
    kind: zstd.Project.ProjectKind,
    project_schema: []const u8 = zstd.Project.schema_version,
    template_schema: []const u8 = template_schema,
    template_version: u32 = template_version,
    cli_version: []const u8 = cli_version,
    minimum_zig_version: []const u8 = minimum_zig_version,
    maximum_zig_version_exclusive: []const u8 = maximum_zig_version_exclusive,
    zigeffect_api: []const u8 = "0.1.x",
    zigeffect_std_api: []const u8 = "0.1.x",

    pub fn validate(self: CompatibilityMetadata) !void {
        if (!std.mem.eql(u8, self.schema, compatibility_schema) or self.schema_version != 1) return error.UnsupportedCompatibilitySchema;
        try zstd.Project.validateIdentifier(self.project);
        if (!std.mem.eql(u8, self.project_schema, zstd.Project.schema_version) or
            !std.mem.eql(u8, self.template_schema, template_schema) or
            self.template_version != template_version or
            !std.mem.eql(u8, self.cli_version, cli_version) or
            !std.mem.eql(u8, self.minimum_zig_version, minimum_zig_version) or
            !std.mem.eql(u8, self.maximum_zig_version_exclusive, maximum_zig_version_exclusive) or
            !std.mem.eql(u8, self.zigeffect_api, "0.1.x") or
            !std.mem.eql(u8, self.zigeffect_std_api, "0.1.x"))
        {
            return error.IncompatibleToolchain;
        }
        if (zstd.Secrets.containsSecret(self.project)) return error.SecretDetected;
    }
};

pub const ParsedCompatibility = std.json.Parsed(CompatibilityMetadata);

pub fn parseCompatibility(allocator: std.mem.Allocator, input: []const u8) !ParsedCompatibility {
    var parsed = try std.json.parseFromSlice(CompatibilityMetadata, allocator, input, .{ .allocate = .alloc_always });
    errdefer parsed.deinit();
    try parsed.value.validate();
    return parsed;
}

pub const CompatibilityReport = struct {
    schema: []const u8 = "zigeffect.compatibility-report.v1",
    schema_version: u32 = 1,
    cli_version: []const u8 = cli_version,
    template_schema: []const u8 = template_schema,
    template_version: u32 = template_version,
    project_schema: []const u8 = zstd.Project.schema_version,
    minimum_zig_version: []const u8 = minimum_zig_version,
    maximum_zig_version_exclusive: []const u8 = maximum_zig_version_exclusive,
    project_present: bool,
    project: ?[]const u8 = null,
    kind: ?zstd.Project.ProjectKind = null,
    detected_project_schema: ?[]const u8 = null,
    metadata_present: bool = false,
    compatible: bool,
    upgrade_required: bool,
};

pub const ManagedFile = struct {
    path: []const u8,
    sha256: []const u8,
};

pub const ScaffoldState = struct {
    schema: []const u8 = scaffold_state_schema,
    schema_version: u32 = 1,
    project: []const u8,
    kind: zstd.Project.ProjectKind,
    project_schema: []const u8 = zstd.Project.schema_version,
    template_schema: []const u8 = template_schema,
    template_version: u32 = template_version,
    cli_version: []const u8 = cli_version,
    managed_files: []const ManagedFile,

    pub fn validate(self: ScaffoldState) !void {
        if (!std.mem.eql(u8, self.schema, scaffold_state_schema) or self.schema_version != 1) return error.UnsupportedScaffoldState;
        try zstd.Project.validateIdentifier(self.project);
        if (!std.mem.eql(u8, self.project_schema, zstd.Project.schema_version)) return error.UnsupportedProjectSchema;
        if (!std.mem.eql(u8, self.template_schema, template_schema) or self.template_version == 0 or self.template_version > template_version) {
            return error.UnsupportedTemplateSchema;
        }
        if (zstd.Secrets.containsSecret(self.cli_version) or zstd.Secrets.containsSecret(self.project)) return error.SecretDetected;
        const state_cli = std.SemanticVersion.parse(self.cli_version) catch return error.InvalidScaffoldState;
        const running_cli = std.SemanticVersion.parse(cli_version) catch unreachable;
        if (state_cli.order(running_cli) == .gt) return error.NewerCliRequired;
        if (self.managed_files.len == 0) return error.InvalidScaffoldState;
        for (self.managed_files, 0..) |file, index| {
            try zstd.Project.validateRelativePath(file.path, false);
            if (zstd.Secrets.containsSecret(file.path) or zstd.Secrets.containsSecret(file.sha256)) return error.SecretDetected;
            if (!isToolOwnedPath(file.path) or !validDigest(file.sha256)) return error.InvalidScaffoldState;
            for (self.managed_files[0..index]) |previous| {
                if (std.mem.eql(u8, previous.path, file.path)) return error.DuplicateManagedPath;
            }
        }
    }

    pub fn managedFile(self: ScaffoldState, path: []const u8) ?ManagedFile {
        for (self.managed_files) |file| {
            if (std.mem.eql(u8, file.path, path)) return file;
        }
        return null;
    }
};

pub const ParsedState = std.json.Parsed(ScaffoldState);

pub fn parseState(allocator: std.mem.Allocator, input: []const u8) !ParsedState {
    var parsed = try std.json.parseFromSlice(ScaffoldState, allocator, input, .{ .allocate = .alloc_always });
    errdefer parsed.deinit();
    try parsed.value.validate();
    return parsed;
}

pub const MigratableManifest = struct {
    parsed: std.json.Parsed(zstd.Project.Manifest),
    original_schema: []const u8,
    migrated: bool,

    pub fn deinit(self: *MigratableManifest) void {
        self.parsed.deinit();
        self.* = undefined;
    }
};

pub fn parseMigratableManifest(allocator: std.mem.Allocator, input: []const u8) !MigratableManifest {
    var parsed = try std.json.parseFromSlice(zstd.Project.Manifest, allocator, input, .{ .allocate = .alloc_always });
    errdefer parsed.deinit();
    const original_schema = parsed.value.schema;
    const migrated = std.mem.eql(u8, original_schema, legacy_project_schema);
    if (!migrated and !std.mem.eql(u8, original_schema, zstd.Project.schema_version)) return error.UnsupportedProjectSchema;
    if (migrated) parsed.value.schema = zstd.Project.schema_version;
    try parsed.value.validate();
    return .{ .parsed = parsed, .original_schema = original_schema, .migrated = migrated };
}

pub fn completionScript(shell: Shell) []const u8 {
    return switch (shell) {
        .bash =>
        \\# zigeffect bash completion
        \\_zigeffect_complete() {
        \\  local commands="init create new add generate graph statechart test project safety agent benchmark compatibility upgrade completions help version"
        \\  local kinds="application service library package system"
        \\  if [[ ${COMP_CWORD} -eq 1 ]]; then COMPREPLY=( $(compgen -W "$commands" -- "${COMP_WORDS[COMP_CWORD]}") ); return; fi
        \\  if [[ ${COMP_WORDS[1]} == new && ${COMP_CWORD} -eq 2 ]]; then COMPREPLY=( $(compgen -W "$kinds" -- "${COMP_WORDS[COMP_CWORD]}") ); return; fi
        \\  COMPREPLY=( $(compgen -W "--root --component --json --jsonl --dry-run --apply --force --target --provider --command" -- "${COMP_WORDS[COMP_CWORD]}") )
        \\}
        \\complete -F _zigeffect_complete zigeffect
        \\
        ,
        .zsh =>
        \\#compdef zigeffect
        \\_zigeffect() {
        \\  local -a commands
        \\  commands=(init create new add generate graph statechart test project safety agent benchmark compatibility upgrade completions help version)
        \\  if (( CURRENT == 2 )); then _describe 'command' commands; return; fi
        \\  _arguments '*:argument:->args'
        \\}
        \\compdef _zigeffect zigeffect
        \\
        ,
        .fish =>
        \\# zigeffect fish completion
        \\complete -c zigeffect -f
        \\complete -c zigeffect -n '__fish_use_subcommand' -a 'init create new add generate graph statechart test project safety agent benchmark compatibility upgrade completions help version'
        \\complete -c zigeffect -n '__fish_seen_subcommand_from create' -l kind -a 'application service library package system'
        \\complete -c zigeffect -n '__fish_seen_subcommand_from new' -a 'application service library package system'
        \\complete -c zigeffect -l root -r
        \\complete -c zigeffect -l json
        \\complete -c zigeffect -l dry-run
        \\complete -c zigeffect -l apply
        \\
        ,
    };
}

pub fn compatibilityJsonAlloc(
    allocator: std.mem.Allocator,
    project: []const u8,
    kind: zstd.Project.ProjectKind,
) ![]u8 {
    try zstd.Project.validateIdentifier(project);
    return std.json.Stringify.valueAlloc(allocator, CompatibilityMetadata{ .project = project, .kind = kind }, .{});
}

pub fn addScaffoldMetadata(
    plan: *zstd.Project.FilePlan,
    project: []const u8,
    kind: zstd.Project.ProjectKind,
) !void {
    const compatibility = try compatibilityJsonAlloc(plan.allocator, project, kind);
    defer plan.allocator.free(compatibility);
    try plan.add(compatibility_path, compatibility);
    try plan.sort();

    const state = try stateJsonAlloc(plan.allocator, project, kind, plan.*);
    defer plan.allocator.free(state);
    try plan.add(scaffold_state_path, state);
}

pub fn stateJsonAlloc(
    allocator: std.mem.Allocator,
    project: []const u8,
    kind: zstd.Project.ProjectKind,
    plan: zstd.Project.FilePlan,
) ![]u8 {
    var count: usize = 0;
    for (plan.files.items) |file| if (isToolOwnedPath(file.path)) {
        count += 1;
    };
    if (count == 0) return error.MissingManagedFiles;

    const entries = try allocator.alloc(ManagedFile, count);
    defer allocator.free(entries);
    var owned_digests = std.ArrayList([]u8).empty;
    defer {
        for (owned_digests.items) |digest| allocator.free(digest);
        owned_digests.deinit(allocator);
    }
    var index: usize = 0;
    for (plan.files.items) |file| {
        if (!isToolOwnedPath(file.path)) continue;
        const digest = try digestAlloc(allocator, file.content);
        errdefer allocator.free(digest);
        try owned_digests.append(allocator, digest);
        entries[index] = .{ .path = file.path, .sha256 = digest };
        index += 1;
    }
    const state = ScaffoldState{ .project = project, .kind = kind, .managed_files = entries };
    try state.validate();
    return std.json.Stringify.valueAlloc(allocator, state, .{});
}

pub fn contractDigestAlloc(allocator: std.mem.Allocator, plan: zstd.Project.FilePlan) ![]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(template_schema);
    hasher.update(&.{0});
    for (plan.files.items) |file| {
        if (std.mem.eql(u8, file.path, scaffold_state_path)) continue;
        hasher.update(file.path);
        hasher.update(&.{0});
        hasher.update(file.content);
        hasher.update(&.{0});
    }
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    hasher.final(&digest);
    return std.fmt.allocPrint(allocator, "sha256:{x}", .{digest});
}

pub fn digestAlloc(allocator: std.mem.Allocator, content: []const u8) ![]u8 {
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(content, &digest, .{});
    return std.fmt.allocPrint(allocator, "sha256:{x}", .{digest});
}

pub fn digestMatches(content: []const u8, expected: []const u8) bool {
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(content, &digest, .{});
    var buffer: [71]u8 = undefined;
    const actual = std.fmt.bufPrint(&buffer, "sha256:{x}", .{digest}) catch return false;
    return std.mem.eql(u8, actual, expected);
}

pub fn isToolOwnedPath(path: []const u8) bool {
    return std.mem.eql(u8, path, compatibility_path) or
        std.mem.startsWith(u8, path, ".agents/skills/zigeffect-") or
        std.mem.startsWith(u8, path, ".claude/skills/zigeffect-");
}

fn validDigest(value: []const u8) bool {
    if (value.len != 71 or !std.mem.startsWith(u8, value, "sha256:")) return false;
    for (value[7..]) |byte| {
        if (!std.ascii.isHex(byte)) return false;
    }
    return true;
}

test "distribution metadata validates managed hashes and legacy manifest migration" {
    const manifest = zstd.Project.Manifest{
        .schema = legacy_project_schema,
        .name = "demo-app",
        .kind = .application,
        .components = &.{.{ .id = "demo-app", .kind = .application, .path = "." }},
    };
    const json = try std.json.Stringify.valueAlloc(std.testing.allocator, manifest, .{});
    defer std.testing.allocator.free(json);
    var migrated = try parseMigratableManifest(std.testing.allocator, json);
    defer migrated.deinit();
    try std.testing.expect(migrated.migrated);
    try std.testing.expectEqualStrings(zstd.Project.schema_version, migrated.parsed.value.schema);

    const digest = try digestAlloc(std.testing.allocator, "content");
    defer std.testing.allocator.free(digest);
    const state = ScaffoldState{
        .project = "demo-app",
        .kind = .application,
        .managed_files = &.{.{ .path = compatibility_path, .sha256 = digest }},
    };
    try state.validate();
    try std.testing.expect(digestMatches("content", digest));
    try std.testing.expect(!digestMatches("changed", digest));

    var secret_state = state;
    secret_state.cli_version = "token=sentinel-secret-for-tests";
    try std.testing.expectError(error.SecretDetected, secret_state.validate());

    var future_template = state;
    future_template.template_version = template_version + 1;
    try std.testing.expectError(error.UnsupportedTemplateSchema, future_template.validate());
    var future_cli = state;
    future_cli.cli_version = "0.8.0";
    try std.testing.expectError(error.NewerCliRequired, future_cli.validate());
}

test "completion scripts cover every distribution command" {
    inline for (std.meta.tags(Shell)) |shell| {
        const script = completionScript(shell);
        try std.testing.expect(std.mem.indexOf(u8, script, "zigeffect") != null);
        try std.testing.expect(std.mem.indexOf(u8, script, "compatibility") != null);
        try std.testing.expect(std.mem.indexOf(u8, script, "upgrade") != null);
    }
}

test "scaffold metadata releases every partial allocation" {
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var plan = zstd.Project.FilePlan.init(allocator);
            defer plan.deinit();
            try plan.add(".agents/skills/zigeffect-development/SKILL.md", "skill\n");
            try plan.add(".claude/skills/zigeffect-development/SKILL.md", "skill\n");
            try plan.add(".gemini/skills/zigeffect-development/SKILL.md", "skill\n");
            try plan.add("src/main.zig", "pub fn main() void {}\n");
            try addScaffoldMetadata(&plan, "allocation-app", .application);
            try plan.sort();
            const digest = try contractDigestAlloc(allocator, plan);
            allocator.free(digest);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}
