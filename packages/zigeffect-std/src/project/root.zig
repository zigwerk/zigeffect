const std = @import("std");
const Secrets = @import("../secrets/root.zig");
const CapabilityContract = @import("../capability/root.zig");

pub const Protocol = @import("protocol.zig");

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
    InvalidTestScenario,
    DuplicateTestScenario,
    MissingTestCoverage,
    SecretDetected,
    DuplicatePath,
    MissingSafeRoot,
    MissingSafetyGate,
    InvalidSafetyRoot,
    OverlappingSafetyRoot,
    InvalidSafetyLimit,
    InvalidSafetyAllowance,
    DuplicateSafetyAllowance,
    UnauditedSafetyAllowance,
    DuplicateSafetyGate,
    InvalidCapabilityRequirement,
    DuplicateCapabilityRequirement,
    InvalidCapabilityDescriptor,
    DuplicateCapabilityDescriptor,
    InvalidAdapterProfile,
    DuplicateAdapterProfile,
    DuplicateAdapterBinding,
    IncompleteProductionProfile,
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
    causal_graph,
    statecharts,
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

pub const TestFaultProfile = enum {
    none,
    standard,
    exhaustive,
    allocation,
    schedule,
    recovery,
    executor,
};

/// Manifest-owned test intent. Commands remain the only executable authority;
/// scenarios add requirement, source, seed, and fault-selection semantics.
pub const TestScenario = struct {
    id: []const u8,
    label: []const u8,
    requirement: []const u8,
    acceptance_check: []const u8,
    component: []const u8,
    command: []const u8,
    source_roots: []const []const u8 = &.{},
    tags: []const []const u8 = &.{},
    default_seed: u64 = 1,
    fault_profile: TestFaultProfile = .standard,
    required: bool = true,
};

pub const Policy = struct {
    allow_network: bool = false,
    require_approval_for_processes: bool = true,
    persist_raw_terminal: bool = false,
};

pub const ExecutionPosture = enum {
    local,
    production,
};

pub const CapabilityRequirement = struct {
    id: []const u8,
    component: []const u8,
    kind: CapabilityContract.Kind,
    minimum_maturity: CapabilityContract.Maturity = .fake,
    features: []const []const u8 = &.{},
    target: ?[]const u8 = null,
    requires_live_conformance: bool = false,

    pub fn contract(self: CapabilityRequirement) CapabilityContract.Requirement {
        return .{
            .kind = self.kind,
            .minimum_maturity = self.minimum_maturity,
            .features = self.features,
            .target = self.target,
            .requires_live_conformance = self.requires_live_conformance,
        };
    }
};

pub const AdapterBinding = struct {
    requirement: []const u8,
    adapter: []const u8,
};

pub const AdapterProfile = struct {
    id: []const u8,
    target: []const u8,
    bindings: []const AdapterBinding = &.{},
};

pub const BoundCapabilityResolution = struct {
    requirement_id: []const u8,
    adapter_id: []const u8,
    descriptor: ?CapabilityContract.Descriptor,
    result: CapabilityContract.Match,
};

pub const SafetyProfile = enum {
    unmanaged,
    agent_safe_v1,
    audited_systems,
};

pub const GovernedConstruct = enum {
    pointer_cast,
    pointer_integer_conversion,
    opaque_pointer,
    many_pointer,
    runtime_safety_disabled,
    inline_assembly,
    foreign_interface,
    volatile_access,
    thread_local_state,
    unmanaged_thread,
    unchecked_unreachable,
    undefined_escape,
    manual_allocator_escape,
};

pub const SafetyGateKind = enum {
    source_policy,
    compile_debug,
    compile_release_safe,
    allocation_failures,
    leak_detection,
    causal_invariants,
    schedule_exploration,
    thread_sanitizer,
    c_undefined_behavior,
    stack_protection,
    fuzz,
    executor_equivalence,
};

pub const SafetyGatePolicy = struct {
    kind: SafetyGateKind,
    required: bool = true,
    command: ?[]const u8 = null,
};

pub const SafetyLimits = struct {
    max_source_bytes: usize = 8 * 1024 * 1024,
    max_findings: usize = 1024,
    max_diagnostics: usize = 1024,
    max_schedules: usize = 10_000,
    max_fuzz_cases: usize = 100_000,
    max_artifact_bytes: usize = 16 * 1024 * 1024,
    max_runtime_events: usize = 100_000,

    fn validate(self: SafetyLimits) ProjectError!void {
        if (self.max_source_bytes == 0 or
            self.max_findings == 0 or
            self.max_diagnostics == 0 or
            self.max_schedules == 0 or
            self.max_fuzz_cases == 0 or
            self.max_artifact_bytes == 0 or
            self.max_runtime_events == 0)
        {
            return error.InvalidSafetyLimit;
        }
    }
};

pub const SafetyProductionPosture = struct {
    retain_generation_checks: bool = true,
    retain_critical_invariants: bool = true,
    retain_causal_findings: bool = true,
};

pub const UnsafeAllowance = struct {
    id: []const u8,
    path: []const u8,
    construct: GovernedConstruct,
    fingerprint: []const u8,
    justification: []const u8,
    required_check: []const u8,
};

pub const SafetyPolicy = struct {
    profile: SafetyProfile = .unmanaged,
    safe_roots: []const []const u8 = &.{},
    audited_roots: []const []const u8 = &.{},
    allowances: []const UnsafeAllowance = &.{},
    gates: []const SafetyGatePolicy = &.{},
    limits: SafetyLimits = .{},
    production_posture: SafetyProductionPosture = .{},

    pub fn validate(self: SafetyPolicy, manifest: Manifest) ProjectError!void {
        try self.limits.validate();

        if (self.profile == .unmanaged) {
            if (self.safe_roots.len != 0 or self.audited_roots.len != 0 or self.allowances.len != 0 or self.gates.len != 0) {
                return error.InvalidSafetyRoot;
            }
            return;
        }
        if (self.profile == .agent_safe_v1 and self.safe_roots.len == 0) return error.MissingSafeRoot;
        if (self.profile == .audited_systems and self.audited_roots.len == 0) return error.InvalidSafetyRoot;

        try validateSafetyRoots(self.safe_roots);
        try validateSafetyRoots(self.audited_roots);
        for (self.safe_roots) |safe_root| {
            for (self.audited_roots) |audited_root| {
                if (std.mem.eql(u8, safe_root, audited_root) or pathIsWithin(safe_root, audited_root)) {
                    return error.OverlappingSafetyRoot;
                }
            }
        }

        var has_source_policy = false;
        for (self.gates, 0..) |gate, index| {
            if (gate.kind == .source_policy) has_source_policy = true;
            if (gate.command) |command_id| {
                try ensureSafe(command_id);
                if (manifest.command(command_id) == null) return error.MissingSafetyGate;
            } else if (gate.kind != .source_policy and gate.required) {
                return error.MissingSafetyGate;
            }
            for (self.gates[0..index]) |previous| {
                if (previous.kind == gate.kind) return error.DuplicateSafetyGate;
            }
        }
        if (self.profile == .agent_safe_v1 and !has_source_policy) return error.MissingSafetyGate;

        for (self.allowances, 0..) |allowance, index| {
            try validateIdentifier(allowance.id);
            try validateRelativePath(allowance.path, false);
            try ensureSafe(allowance.path);
            try ensureSafe(allowance.fingerprint);
            try ensureSafe(allowance.justification);
            try ensureSafe(allowance.required_check);
            if (!validSafetyFingerprint(allowance.fingerprint) or allowance.justification.len < 16) {
                return error.InvalidSafetyAllowance;
            }
            if (manifest.command(allowance.required_check) == null) return error.InvalidSafetyAllowance;
            var audited = false;
            for (self.audited_roots) |root| {
                if (pathIsWithin(allowance.path, root)) {
                    audited = true;
                    break;
                }
            }
            if (!audited) return error.UnauditedSafetyAllowance;
            for (self.allowances[0..index]) |previous| {
                if (std.mem.eql(u8, previous.id, allowance.id) or
                    (std.mem.eql(u8, previous.path, allowance.path) and previous.construct == allowance.construct))
                {
                    return error.DuplicateSafetyAllowance;
                }
            }
        }
    }
};

pub const ArtifactPaths = struct {
    sessions: []const u8 = ".zigeffect/sessions",
    causal: []const u8 = ".zigeffect/causal",
    receipts: []const u8 = ".zigeffect/receipts",
    graph: []const u8 = ".zigeffect/graph",
    statecharts: []const u8 = ".zigeffect/statecharts",
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
    test_scenarios: []const TestScenario = &.{},
    execution_posture: ExecutionPosture = .local,
    capability_requirements: []const CapabilityRequirement = &.{},
    capability_descriptors: []const CapabilityContract.Descriptor = &.{},
    adapter_profiles: []const AdapterProfile = &.{},
    policy: Policy = .{},
    safety: SafetyPolicy = .{},
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

        for (self.test_scenarios, 0..) |scenario, index| {
            try validateIdentifier(scenario.id);
            try ensureSafe(scenario.label);
            if (scenario.label.len == 0 or scenario.default_seed == 0) return error.InvalidTestScenario;
            const requirement_item = self.requirement(scenario.requirement) orelse return error.InvalidTestScenario;
            const acceptance = self.acceptanceCheck(scenario.acceptance_check) orelse return error.InvalidTestScenario;
            if (self.component(scenario.component) == null or self.command(scenario.command) == null) return error.InvalidTestScenario;
            if (!std.mem.eql(u8, requirement_item.component, scenario.component) or
                !std.mem.eql(u8, acceptance.requirement, scenario.requirement) or
                !std.mem.eql(u8, acceptance.command, scenario.command)) return error.InvalidTestScenario;
            for (scenario.source_roots, 0..) |root, root_index| {
                try validateRelativePath(root, false);
                try ensureSafe(root);
                for (scenario.source_roots[0..root_index]) |previous| if (std.mem.eql(u8, previous, root)) return error.InvalidTestScenario;
            }
            for (scenario.tags, 0..) |tag, tag_index| {
                try validateIdentifier(tag);
                for (scenario.tags[0..tag_index]) |previous| if (std.mem.eql(u8, previous, tag)) return error.InvalidTestScenario;
            }
            for (self.test_scenarios[0..index]) |previous| if (std.mem.eql(u8, previous.id, scenario.id)) return error.DuplicateTestScenario;
        }
        if (self.test_scenarios.len != 0) {
            for (self.acceptance_checks) |check| {
                var covered = false;
                for (self.test_scenarios) |scenario| {
                    if (scenario.required and std.mem.eql(u8, scenario.acceptance_check, check.id)) {
                        covered = true;
                        break;
                    }
                }
                if (!covered) return error.MissingTestCoverage;
            }
        }

        for (self.capability_requirements, 0..) |capability_requirement, index| {
            validateIdentifier(capability_requirement.id) catch return error.InvalidCapabilityRequirement;
            if (self.component(capability_requirement.component) == null) return error.InvalidCapabilityRequirement;
            try ensureSafe(capability_requirement.component);
            for (capability_requirement.features, 0..) |feature, feature_index| {
                validateIdentifier(feature) catch return error.InvalidCapabilityRequirement;
                for (capability_requirement.features[0..feature_index]) |previous| {
                    if (std.mem.eql(u8, feature, previous)) return error.InvalidCapabilityRequirement;
                }
            }
            if (capability_requirement.target) |target| {
                if (!validTarget(target)) return error.InvalidCapabilityRequirement;
                try ensureSafe(target);
            }
            for (self.capability_requirements[0..index]) |previous| {
                if (std.mem.eql(u8, previous.id, capability_requirement.id)) {
                    return error.DuplicateCapabilityRequirement;
                }
            }
            if (self.execution_posture == .production and
                (!capability_requirement.minimum_maturity.satisfies(.production_candidate) or
                    !capability_requirement.requires_live_conformance))
            {
                return error.IncompleteProductionProfile;
            }
        }

        for (self.capability_descriptors, 0..) |descriptor, index| {
            descriptor.validate() catch return error.InvalidCapabilityDescriptor;
            for (self.capability_descriptors[0..index]) |previous| {
                if (std.mem.eql(u8, previous.id, descriptor.id)) return error.DuplicateCapabilityDescriptor;
            }
        }

        for (self.adapter_profiles, 0..) |profile, profile_index| {
            validateIdentifier(profile.id) catch return error.InvalidAdapterProfile;
            if (!validTarget(profile.target)) return error.InvalidAdapterProfile;
            try ensureSafe(profile.target);
            for (self.adapter_profiles[0..profile_index]) |previous| {
                if (std.mem.eql(u8, previous.id, profile.id)) return error.DuplicateAdapterProfile;
            }
            for (profile.bindings, 0..) |binding, binding_index| {
                if (self.capabilityRequirement(binding.requirement) == null or !validAdapterId(binding.adapter)) {
                    return error.InvalidAdapterProfile;
                }
                try ensureSafe(binding.adapter);
                for (profile.bindings[0..binding_index]) |previous| {
                    if (std.mem.eql(u8, previous.requirement, binding.requirement)) {
                        return error.DuplicateAdapterBinding;
                    }
                }
            }
            if (self.execution_posture == .production) {
                for (self.capability_requirements) |capability_requirement| {
                    var found = false;
                    for (profile.bindings) |binding| {
                        if (std.mem.eql(u8, binding.requirement, capability_requirement.id)) {
                            found = true;
                            break;
                        }
                    }
                    if (!found) return error.IncompleteProductionProfile;
                }
            }
        }
        if (self.execution_posture == .production and
            (self.capability_requirements.len == 0 or self.adapter_profiles.len == 0))
        {
            return error.IncompleteProductionProfile;
        }

        try validateRelativePath(self.artifacts.sessions, false);
        try validateRelativePath(self.artifacts.causal, false);
        try validateRelativePath(self.artifacts.receipts, false);
        try validateRelativePath(self.artifacts.graph, false);
        try validateRelativePath(self.artifacts.statecharts, false);
        try validateDependencyPath(self.dependencies.zigeffect);
        try validateDependencyPath(self.dependencies.zigeffect_std);
        try self.safety.validate(self);
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

    pub fn acceptanceCheck(self: Manifest, id: []const u8) ?AcceptanceCheck {
        for (self.acceptance_checks) |candidate| {
            if (std.mem.eql(u8, candidate.id, id)) return candidate;
        }
        return null;
    }

    pub fn testScenario(self: Manifest, id: []const u8) ?TestScenario {
        for (self.test_scenarios) |candidate| {
            if (std.mem.eql(u8, candidate.id, id)) return candidate;
        }
        return null;
    }

    pub fn capabilityRequirement(self: Manifest, id: []const u8) ?CapabilityRequirement {
        for (self.capability_requirements) |candidate| {
            if (std.mem.eql(u8, candidate.id, id)) return candidate;
        }
        return null;
    }

    pub fn adapterProfile(self: Manifest, id: []const u8) ?AdapterProfile {
        for (self.adapter_profiles) |candidate| {
            if (std.mem.eql(u8, candidate.id, id)) return candidate;
        }
        return null;
    }

    pub fn resolveCapability(
        self: Manifest,
        profile_id: []const u8,
        requirement_id: []const u8,
        descriptors: []const CapabilityContract.Descriptor,
    ) !BoundCapabilityResolution {
        try self.validate();
        const profile = self.adapterProfile(profile_id) orelse return error.InvalidAdapterProfile;
        const capability_requirement = self.capabilityRequirement(requirement_id) orelse {
            return error.InvalidCapabilityRequirement;
        };
        var adapter_id: ?[]const u8 = null;
        for (profile.bindings) |binding| {
            if (std.mem.eql(u8, binding.requirement, requirement_id)) {
                adapter_id = binding.adapter;
                break;
            }
        }
        const selected_adapter_id = adapter_id orelse return error.InvalidAdapterProfile;

        // Resolution validates every descriptor and rejects duplicate ids even
        // when the selected adapter itself is absent or incompatible.
        var contract = capability_requirement.contract();
        if (contract.target == null) contract.target = profile.target;
        _ = try CapabilityContract.resolve(descriptors, contract);

        for (descriptors) |descriptor| {
            if (!std.mem.eql(u8, descriptor.id, selected_adapter_id)) continue;
            return .{
                .requirement_id = requirement_id,
                .adapter_id = selected_adapter_id,
                .descriptor = descriptor,
                .result = CapabilityContract.match(descriptor, contract),
            };
        }
        return .{
            .requirement_id = requirement_id,
            .adapter_id = selected_adapter_id,
            .descriptor = null,
            .result = .adapter_not_found,
        };
    }

    pub fn resolveProfileAlloc(
        self: Manifest,
        allocator: std.mem.Allocator,
        profile_id: []const u8,
        descriptors: []const CapabilityContract.Descriptor,
        evidence_time_ms: i64,
    ) ![]CapabilityContract.AdapterEvidence {
        try self.validate();
        const profile = self.adapterProfile(profile_id) orelse return error.InvalidAdapterProfile;

        for (descriptors, 0..) |descriptor, index| {
            try descriptor.validate();
            for (descriptors[0..index]) |previous| {
                if (std.mem.eql(u8, descriptor.id, previous.id)) return error.DuplicateAdapterId;
            }
        }

        const evidence = try allocator.alloc(CapabilityContract.AdapterEvidence, profile.bindings.len);
        errdefer allocator.free(evidence);
        for (profile.bindings, 0..) |binding, index| {
            const capability_requirement = self.capabilityRequirement(binding.requirement) orelse {
                return error.InvalidCapabilityRequirement;
            };
            var contract = capability_requirement.contract();
            if (contract.target == null) contract.target = profile.target;
            contract.evidence_time_ms = evidence_time_ms;

            var selected: ?CapabilityContract.Descriptor = null;
            for (descriptors) |descriptor| {
                if (std.mem.eql(u8, descriptor.id, binding.adapter)) {
                    selected = descriptor;
                    break;
                }
            }
            evidence[index] = if (selected) |descriptor|
                CapabilityContract.AdapterEvidence.fromDescriptor(
                    profile.id,
                    capability_requirement.id,
                    contract.target.?,
                    descriptor,
                    CapabilityContract.match(descriptor, contract),
                )
            else
                .{
                    .profile_id = profile.id,
                    .requirement_id = capability_requirement.id,
                    .target = contract.target.?,
                    .adapter_id = binding.adapter,
                    .kind = capability_requirement.kind,
                    .maturity = .fake,
                    .result = .adapter_not_found,
                };
            try evidence[index].validate();
        }
        return evidence;
    }

    pub fn scenarioAffectedBy(self: Manifest, scenario: TestScenario, changed_path: []const u8) bool {
        for (scenario.source_roots) |root| {
            if (pathIsWithin(changed_path, root) or pathIsWithin(root, changed_path)) return true;
        }
        if (scenario.source_roots.len != 0) return false;
        const scenario_component = self.component(scenario.component) orelse return false;
        if (pathIsWithin(changed_path, scenario_component.path)) return true;
        for (self.components) |candidate| {
            if (!pathIsWithin(changed_path, candidate.path)) continue;
            for (scenario_component.depends_on) |dependency| if (std.mem.eql(u8, dependency, candidate.id)) return true;
        }
        return false;
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

fn validateSafetyRoots(roots: []const []const u8) ProjectError!void {
    for (roots, 0..) |root, index| {
        try validateRelativePath(root, true);
        try ensureSafe(root);
        for (roots[0..index]) |previous| {
            if (std.mem.eql(u8, root, previous) or pathIsWithin(root, previous) or pathIsWithin(previous, root)) {
                return error.OverlappingSafetyRoot;
            }
        }
    }
}

fn pathIsWithin(path: []const u8, root: []const u8) bool {
    if (std.mem.eql(u8, root, ".")) return true;
    if (std.mem.eql(u8, path, root)) return true;
    return path.len > root.len and std.mem.startsWith(u8, path, root) and path[root.len] == '/';
}

fn validSafetyFingerprint(value: []const u8) bool {
    const prefix = "sha256:";
    if (!std.mem.startsWith(u8, value, prefix) or value.len < prefix.len + 16) return false;
    for (value[prefix.len..]) |byte| {
        if (!std.ascii.isHex(byte)) return false;
    }
    return true;
}

pub const ParsedManifest = std.json.Parsed(Manifest);

pub fn parseManifest(allocator: std.mem.Allocator, input: []const u8) !ParsedManifest {
    // Parsed manifests routinely outlive the read buffer used by CLI and agent
    // tooling. Own every string so callers cannot accidentally retain slices
    // into an already-released file buffer.
    var parsed = try std.json.parseFromSlice(Manifest, allocator, input, .{ .allocate = .alloc_always });
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

fn validTarget(value: []const u8) bool {
    if (value.len == 0 or value.len > 96) return false;
    for (value) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.') continue;
        return false;
    }
    return true;
}

fn validAdapterId(value: []const u8) bool {
    if (value.len == 0 or value.len > 128) return false;
    for (value) |byte| {
        if (std.ascii.isLower(byte) or std.ascii.isDigit(byte)) continue;
        if (byte == '-' or byte == '_' or byte == '.' or byte == ':') continue;
        return false;
    }
    return true;
}

fn ensureSafe(value: []const u8) ProjectError!void {
    if (Secrets.containsSecret(value)) return error.SecretDetected;
}

test "Project test scenarios bind requirement acceptance command and affected source roots" {
    const manifest = Manifest{
        .name = "demo",
        .kind = .application,
        .components = &.{.{ .id = "demo", .kind = .application, .path = "." }},
        .commands = &.{.{ .id = "test", .argv = &.{ "zig", "build", "test" } }},
        .requirements = &.{.{ .id = "req-test", .summary = "prove behavior", .component = "demo" }},
        .acceptance_checks = &.{.{ .id = "check-test", .requirement = "req-test", .command = "test", .expectation = "tests pass" }},
        .test_scenarios = &.{.{
            .id = "scenario-test",
            .label = "behavior remains correct",
            .requirement = "req-test",
            .acceptance_check = "check-test",
            .component = "demo",
            .command = "test",
            .source_roots = &.{ "src", "test" },
            .tags = &.{"acceptance"},
            .default_seed = 42,
        }},
    };
    try manifest.validate();
    try std.testing.expect(manifest.testScenario("scenario-test") != null);
    try std.testing.expect(manifest.scenarioAffectedBy(manifest.test_scenarios[0], "src/main.zig"));
    try std.testing.expect(!manifest.scenarioAffectedBy(manifest.test_scenarios[0], "README.md"));
    const json = try manifest.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    var parsed = try parseManifest(std.testing.allocator, json);
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.value.test_scenarios.len);
    try std.testing.expectEqual(@as(u64, 42), parsed.value.test_scenarios[0].default_seed);
}

test "Project rejects duplicate mismatched and uncovered test scenarios" {
    const base = Manifest{
        .name = "demo",
        .kind = .application,
        .components = &.{.{ .id = "demo", .kind = .application, .path = "." }},
        .commands = &.{.{ .id = "test", .argv = &.{ "zig", "build", "test" } }},
        .requirements = &.{.{ .id = "req-test", .summary = "prove behavior", .component = "demo" }},
        .acceptance_checks = &.{.{ .id = "check-test", .requirement = "req-test", .command = "test", .expectation = "tests pass" }},
    };
    var uncovered = base;
    uncovered.test_scenarios = &.{.{ .id = "optional", .label = "optional", .requirement = "req-test", .acceptance_check = "check-test", .component = "demo", .command = "test", .required = false }};
    try std.testing.expectError(error.MissingTestCoverage, uncovered.validate());
    var mismatch = base;
    mismatch.test_scenarios = &.{.{ .id = "bad", .label = "bad", .requirement = "req-test", .acceptance_check = "missing", .component = "demo", .command = "test" }};
    try std.testing.expectError(error.InvalidTestScenario, mismatch.validate());
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
    try std.testing.expectEqualStrings(".zigeffect/statecharts", parsed.value.artifacts.statecharts);

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

    var invalid_graph_path = unknown_schema;
    invalid_graph_path.schema = schema_version;
    invalid_graph_path.artifacts.graph = "../outside";
    try std.testing.expectError(error.InvalidPath, invalid_graph_path.validate());

    var invalid_statechart_path = unknown_schema;
    invalid_statechart_path.schema = schema_version;
    invalid_statechart_path.artifacts.statecharts = "../outside";
    try std.testing.expectError(error.InvalidPath, invalid_statechart_path.validate());

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

test "Project validates agent safe policy and round trips safety JSON" {
    const manifest = Manifest{
        .name = "safe-app",
        .kind = .application,
        .components = &.{.{ .id = "safe-app", .kind = .application, .path = "." }},
        .commands = &.{
            .{ .id = "check-debug", .argv = &.{ "zig", "build", "test", "-Doptimize=Debug" } },
            .{ .id = "check-safe", .argv = &.{ "zig", "build", "test", "-Doptimize=ReleaseSafe" } },
        },
        .safety = .{
            .profile = .agent_safe_v1,
            .safe_roots = &.{"src"},
            .audited_roots = &.{"src/platform"},
            .allowances = &.{.{
                .id = "ffi-entry",
                .path = "src/platform/native.zig",
                .construct = .foreign_interface,
                .fingerprint = "sha256:0123456789abcdef",
                .justification = "platform adapter owns the foreign ABI boundary",
                .required_check = "check-safe",
            }},
            .gates = &.{
                .{ .kind = .source_policy },
                .{ .kind = .compile_debug, .command = "check-debug" },
                .{ .kind = .compile_release_safe, .command = "check-safe" },
            },
        },
    };

    try manifest.validate();
    const json = try manifest.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    var parsed = try parseManifest(std.testing.allocator, json);
    defer parsed.deinit();

    try std.testing.expectEqual(SafetyProfile.agent_safe_v1, parsed.value.safety.profile);
    try std.testing.expectEqual(@as(usize, 1), parsed.value.safety.allowances.len);
    try std.testing.expectEqual(GovernedConstruct.foreign_interface, parsed.value.safety.allowances[0].construct);
    try std.testing.expectEqual(@as(usize, 3), parsed.value.safety.gates.len);
}

test "Project safety policy fails closed for missing roots gates and invalid limits" {
    const base = Manifest{
        .name = "safe-app",
        .kind = .application,
        .components = &.{.{ .id = "safe-app", .kind = .application, .path = "." }},
    };

    var missing_roots = base;
    missing_roots.safety = .{
        .profile = .agent_safe_v1,
        .gates = &.{.{ .kind = .source_policy }},
    };
    try std.testing.expectError(error.MissingSafeRoot, missing_roots.validate());

    var missing_gate = base;
    missing_gate.safety = .{
        .profile = .agent_safe_v1,
        .safe_roots = &.{"src"},
    };
    try std.testing.expectError(error.MissingSafetyGate, missing_gate.validate());

    var optional_capability = base;
    optional_capability.safety = .{
        .profile = .agent_safe_v1,
        .safe_roots = &.{"src"},
        .gates = &.{ .{ .kind = .source_policy }, .{ .kind = .thread_sanitizer, .required = false } },
    };
    try optional_capability.validate();

    var required_capability = optional_capability;
    required_capability.safety.gates = &.{ .{ .kind = .source_policy }, .{ .kind = .thread_sanitizer } };
    try std.testing.expectError(error.MissingSafetyGate, required_capability.validate());

    var zero_limit = base;
    zero_limit.safety = .{
        .profile = .agent_safe_v1,
        .safe_roots = &.{"src"},
        .gates = &.{.{ .kind = .source_policy }},
        .limits = .{ .max_findings = 0 },
    };
    try std.testing.expectError(error.InvalidSafetyLimit, zero_limit.validate());
}

test "Project safety policy rejects overlapping roots and unaudited allowances" {
    const overlapping = Manifest{
        .name = "safe-app",
        .kind = .application,
        .components = &.{.{ .id = "safe-app", .kind = .application, .path = "." }},
        .safety = .{
            .profile = .agent_safe_v1,
            .safe_roots = &.{ "src", "src/domain" },
            .audited_roots = &.{"adapters"},
            .gates = &.{.{ .kind = .source_policy }},
        },
    };
    try std.testing.expectError(error.OverlappingSafetyRoot, overlapping.validate());

    const unaudited = Manifest{
        .name = "safe-app",
        .kind = .application,
        .components = &.{.{ .id = "safe-app", .kind = .application, .path = "." }},
        .commands = &.{.{ .id = "check-safe", .argv = &.{ "zig", "build", "test" } }},
        .safety = .{
            .profile = .agent_safe_v1,
            .safe_roots = &.{"src"},
            .audited_roots = &.{"adapters"},
            .allowances = &.{.{
                .id = "bad-location",
                .path = "src/raw.zig",
                .construct = .pointer_cast,
                .fingerprint = "sha256:0123456789abcdef",
                .justification = "this is deliberately outside the audited root",
                .required_check = "check-safe",
            }},
            .gates = &.{.{ .kind = .source_policy }},
        },
    };
    try std.testing.expectError(error.UnauditedSafetyAllowance, unaudited.validate());
}

test "Project safety policy rejects duplicates stale shapes and secrets" {
    const manifest = Manifest{
        .name = "safe-app",
        .kind = .application,
        .components = &.{.{ .id = "safe-app", .kind = .application, .path = "." }},
        .commands = &.{.{ .id = "check-safe", .argv = &.{ "zig", "build", "test" } }},
    };

    var duplicate_gate = manifest;
    duplicate_gate.safety = .{
        .profile = .agent_safe_v1,
        .safe_roots = &.{"src"},
        .gates = &.{ .{ .kind = .source_policy }, .{ .kind = .source_policy } },
    };
    try std.testing.expectError(error.DuplicateSafetyGate, duplicate_gate.validate());

    var malformed_fingerprint = manifest;
    malformed_fingerprint.safety = .{
        .profile = .agent_safe_v1,
        .safe_roots = &.{"src"},
        .audited_roots = &.{"adapters"},
        .allowances = &.{.{
            .id = "native-entry",
            .path = "adapters/native.zig",
            .construct = .pointer_cast,
            .fingerprint = "old",
            .justification = "adapter has a reviewed pointer conversion boundary",
            .required_check = "check-safe",
        }},
        .gates = &.{.{ .kind = .source_policy }},
    };
    try std.testing.expectError(error.InvalidSafetyAllowance, malformed_fingerprint.validate());

    var secret = manifest;
    secret.safety = .{
        .profile = .agent_safe_v1,
        .safe_roots = &.{"src"},
        .audited_roots = &.{"adapters"},
        .allowances = &.{.{
            .id = "native-entry",
            .path = "adapters/native.zig",
            .construct = .pointer_cast,
            .fingerprint = "sha256:0123456789abcdef",
            .justification = "authorization: Bearer sentinel-secret-for-tests",
            .required_check = "check-safe",
        }},
        .gates = &.{.{ .kind = .source_policy }},
    };
    try std.testing.expectError(error.SecretDetected, secret.validate());
}

test "Project capability requirements and adapter profiles round trip" {
    const manifest = Manifest{
        .name = "api",
        .kind = .service,
        .components = &.{.{ .id = "api", .kind = .service, .path = "." }},
        .capability_requirements = &.{.{
            .id = "public-http",
            .component = "api",
            .kind = .http_server,
            .minimum_maturity = .production_candidate,
            .features = &.{ "http1", "graceful-drain" },
            .target = "x86_64-linux",
            .requires_live_conformance = true,
        }},
        .adapter_profiles = &.{.{
            .id = "production-linux",
            .target = "x86_64-linux",
            .bindings = &.{.{
                .requirement = "public-http",
                .adapter = "zigeffect-http.server",
            }},
        }},
    };

    try manifest.validate();
    try std.testing.expectEqual(
        CapabilityContract.Maturity.production_candidate,
        manifest.capabilityRequirement("public-http").?.minimum_maturity,
    );
    try std.testing.expect(manifest.adapterProfile("production-linux") != null);

    const json = try manifest.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    var parsed = try parseManifest(std.testing.allocator, json);
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.value.capability_requirements.len);
    try std.testing.expectEqual(@as(usize, 1), parsed.value.adapter_profiles.len);
}

test "Project legacy manifests decode with an explicitly local empty profile" {
    const json =
        \\{"schema":"zigeffect.project.v1","name":"demo","kind":"application","components":[{"id":"demo","kind":"application","path":"."}]}
    ;
    var parsed = try parseManifest(std.testing.allocator, json);
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 0), parsed.value.capability_requirements.len);
    try std.testing.expectEqual(@as(usize, 0), parsed.value.adapter_profiles.len);
    try std.testing.expectEqual(ExecutionPosture.local, parsed.value.execution_posture);
}

test "Project rejects invalid capability requirements and adapter bindings" {
    const base = Manifest{
        .name = "api",
        .kind = .service,
        .components = &.{.{ .id = "api", .kind = .service, .path = "." }},
        .capability_requirements = &.{.{
            .id = "public-http",
            .component = "api",
            .kind = .http_server,
        }},
    };

    var missing_component = base;
    missing_component.capability_requirements = &.{.{
        .id = "public-http",
        .component = "missing",
        .kind = .http_server,
    }};
    try std.testing.expectError(error.InvalidCapabilityRequirement, missing_component.validate());

    var duplicate = base;
    duplicate.capability_requirements = &.{ base.capability_requirements[0], base.capability_requirements[0] };
    try std.testing.expectError(error.DuplicateCapabilityRequirement, duplicate.validate());

    var missing_requirement = base;
    missing_requirement.adapter_profiles = &.{.{
        .id = "production",
        .target = "x86_64-linux",
        .bindings = &.{.{ .requirement = "missing", .adapter = "adapter.http" }},
    }};
    try std.testing.expectError(error.InvalidAdapterProfile, missing_requirement.validate());

    var duplicate_binding = base;
    duplicate_binding.adapter_profiles = &.{.{
        .id = "production",
        .target = "x86_64-linux",
        .bindings = &.{
            .{ .requirement = "public-http", .adapter = "adapter.http" },
            .{ .requirement = "public-http", .adapter = "adapter.other" },
        },
    }};
    try std.testing.expectError(error.DuplicateAdapterBinding, duplicate_binding.validate());
}

test "Project production capability cannot resolve to a memory adapter" {
    const manifest = Manifest{
        .name = "api",
        .kind = .service,
        .components = &.{.{ .id = "api", .kind = .service, .path = "." }},
        .capability_requirements = &.{.{
            .id = "public-http",
            .component = "api",
            .kind = .http_server,
            .minimum_maturity = .production_candidate,
            .requires_live_conformance = true,
        }},
        .adapter_profiles = &.{.{
            .id = "production",
            .target = "x86_64-linux",
            .bindings = &.{.{
                .requirement = "public-http",
                .adapter = "zigeffect-std.memory-http",
            }},
        }},
    };
    const descriptors = [_]CapabilityContract.Descriptor{.{
        .id = "zigeffect-std.memory-http",
        .kind = .http_server,
        .maturity = .fake,
        .package = "zigeffect-std",
        .version = "0.1.0",
    }};

    const resolution = try manifest.resolveCapability("production", "public-http", &descriptors);
    try std.testing.expectEqual(CapabilityContract.Match.insufficient_maturity, resolution.result);
    try std.testing.expectEqualStrings("zigeffect-std.memory-http", resolution.adapter_id);

    const evidence = try manifest.resolveProfileAlloc(
        std.testing.allocator,
        "production",
        &descriptors,
        1_500,
    );
    defer std.testing.allocator.free(evidence);
    try std.testing.expectEqual(@as(usize, 1), evidence.len);
    try std.testing.expectEqual(CapabilityContract.Match.insufficient_maturity, evidence[0].result);
}

test "Project production posture requires complete live capability profiles" {
    var manifest = Manifest{
        .name = "api",
        .kind = .service,
        .components = &.{.{ .id = "api", .kind = .service, .path = "." }},
        .execution_posture = .production,
    };
    try std.testing.expectError(error.IncompleteProductionProfile, manifest.validate());

    manifest.capability_requirements = &.{.{
        .id = "public-http",
        .component = "api",
        .kind = .http_server,
        .minimum_maturity = .local_development,
    }};
    try std.testing.expectError(error.IncompleteProductionProfile, manifest.validate());
}
