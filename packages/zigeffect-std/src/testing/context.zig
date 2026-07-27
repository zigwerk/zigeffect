const std = @import("std");
const failure_sink = @import("failure_sink.zig");
const fx = @import("zigeffect");
const Contract = @import("contract.zig");
const Project = @import("../project/root.zig");
const Protocol = @import("protocol.zig");
const Coverage = @import("coverage.zig");
const Sandbox = @import("sandbox.zig");

pub const Options = struct {
    project: []const u8,
    suite: []const u8,
    scenario: Contract.Scenario,
    source_revision: []const u8 = "working-tree",
    zig_version: []const u8 = @import("builtin").zig_version_string,
    started_ms: i64 = 0,
    seed: u64 = 1,
    executor: []const u8 = "deterministic",
    fault_kind: Contract.FaultKind = .none,
    fault_index: ?usize = null,
    schedule_choices: []const u32 = &.{},
    execution: Contract.ExecutionIdentity = .{},
    max_causal_events: usize = 4096,
    max_artifacts: usize = 64,
    max_assertions: usize = 4096,
};

pub const Artifact = struct {
    id: []const u8,
    path: []const u8,
    media_type: []const u8,
    digest: []const u8 = "",
};

pub fn FixtureRegistry(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const DeinitFn = *const fn (std.mem.Allocator, *T) void;

        allocator: std.mem.Allocator,
        values: std.StringHashMap(T),
        deinit_value: ?DeinitFn,

        pub fn init(allocator: std.mem.Allocator, deinit_value: ?DeinitFn) Self {
            return .{ .allocator = allocator, .values = std.StringHashMap(T).init(allocator), .deinit_value = deinit_value };
        }

        pub fn deinit(self: *Self) void {
            var iterator = self.values.iterator();
            while (iterator.next()) |entry| {
                if (self.deinit_value) |cleanup| cleanup(self.allocator, entry.value_ptr);
                self.allocator.free(entry.key_ptr.*);
            }
            self.values.deinit();
        }

        /// Replaces a fixture deterministically. The previous value is cleaned
        /// before the new value becomes observable.
        pub fn put(self: *Self, name: []const u8, value: T) !void {
            try validateName(name);
            const owned_name = try self.allocator.dupe(u8, name);
            errdefer self.allocator.free(owned_name);
            if (self.values.fetchRemove(name)) |old| {
                var old_value = old.value;
                if (self.deinit_value) |cleanup| cleanup(self.allocator, &old_value);
                self.allocator.free(old.key);
            }
            try self.values.put(owned_name, value);
        }

        pub fn get(self: *Self, name: []const u8) ?*T {
            return self.values.getPtr(name);
        }

        pub fn require(self: *Self, name: []const u8) !*T {
            return self.get(name) orelse error.FixtureNotFound;
        }

        pub fn count(self: *const Self) usize {
            return self.values.count();
        }
    };
}

pub const TestContext = struct {
    allocator: std.mem.Allocator,
    options: Options,
    env: fx.testing.TestEnv,
    causal_store: fx.CausalStore,
    assertions: std.ArrayList(Contract.AssertionResult) = .empty,
    artifacts: std.ArrayList(Artifact) = .empty,
    coverage_targets: std.ArrayList(Contract.CoverageTarget) = .empty,
    coverage_hits: std.ArrayList(Contract.CoverageHit) = .empty,
    evidence: std.ArrayList(Contract.NamedEvidence) = .empty,
    firewall: Sandbox.Firewall,
    limitations: std.ArrayList([]const u8) = .empty,
    dropped_assertions: usize = 0,
    truncated_artifacts: usize = 0,
    causal_event_id_space: Contract.CausalEventIdSpace = .runtime_local,
    causal_graph_session_id: ?u64 = null,
    finished: bool = false,
    control: ?Protocol.ParsedControl = null,

    pub fn init(allocator: std.mem.Allocator, options: Options) !TestContext {
        var selected = options;
        selected.execution.native_receipt = true;
        try selected.scenario.validate();
        if (selected.seed == 0 or selected.max_causal_events == 0 or selected.max_artifacts == 0 or selected.max_assertions == 0) return error.InvalidBounds;
        var env = try fx.testing.TestEnv.init(allocator);
        errdefer env.deinit();
        return .{
            .allocator = allocator,
            .options = selected,
            .env = env,
            .causal_store = fx.CausalStore.initWithOptions(allocator, .{
                .max_events = options.max_causal_events,
                .max_event_string_bytes = 512,
            }),
            .firewall = Sandbox.Firewall.init(allocator),
        };
    }

    pub fn initFromProject(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, options: Options) !TestContext {
        const environment_path = std.process.Environ.getAlloc(std.testing.environ, allocator, Protocol.control_path_environment) catch |err| switch (err) {
            error.EnvironmentVariableMissing => null,
            else => return err,
        };
        defer if (environment_path) |path| allocator.free(path);
        var parsed = (if (environment_path) |path|
            Protocol.readControlAt(allocator, io, dir, path)
        else
            Protocol.readControl(allocator, io, dir, options.scenario.id)) catch |err| switch (err) {
            error.FileNotFound => return init(allocator, options),
            else => return err,
        };
        errdefer parsed.deinit();
        if (!parsed.value.matches(options.scenario)) {
            parsed.deinit();
            return init(allocator, options);
        }
        if (!std.mem.eql(u8, parsed.value.project, options.project)) return error.ReceiptSelectionMismatch;
        var selected = options;
        selected.seed = parsed.value.seed;
        selected.executor = parsed.value.executor;
        selected.fault_kind = parsed.value.fault_kind;
        selected.fault_index = parsed.value.fault_index;
        selected.schedule_choices = parsed.value.schedule_choices;
        selected.source_revision = parsed.value.source_revision;
        selected.execution.command_digest = parsed.value.command_digest;
        selected.execution.manifest_digest = parsed.value.manifest_digest;
        selected.execution.native_receipt = true;
        var result = try init(allocator, selected);
        result.control = parsed;
        return result;
    }

    pub fn deinit(self: *TestContext) void {
        // First, while the causal store and the assertions are both still
        // alive. `defer ctx.deinit()` is the last program point where what the
        // run did and the fact that something went wrong coexist — a failed
        // assertion returns `error.AssertionFailed` and unwinds straight into
        // this same defer, so a failed assertion and a raw error take one path.
        self.stageFailureBrief();
        for (self.assertions.items) |assertion| deinitAssertion(self.allocator, assertion);
        self.assertions.deinit(self.allocator);
        for (self.artifacts.items) |artifact| deinitArtifact(self.allocator, artifact);
        self.artifacts.deinit(self.allocator);
        for (self.coverage_targets.items) |target| deinitCoverageTarget(self.allocator, target);
        self.coverage_targets.deinit(self.allocator);
        for (self.coverage_hits.items) |hit| deinitCoverageHit(self.allocator, hit);
        self.coverage_hits.deinit(self.allocator);
        for (self.evidence.items) |item| deinitNamedEvidence(self.allocator, item);
        self.evidence.deinit(self.allocator);
        self.firewall.deinit();
        for (self.limitations.items) |value| self.allocator.free(value);
        self.limitations.deinit(self.allocator);
        self.causal_store.deinit();
        self.env.deinit();
        if (self.control) |*control| control.deinit();
    }

    /// Describe what the runtime found wrong, for the runner to print if this
    /// test failed.
    ///
    /// Only findings: invariants the runtime violated without raising an error —
    /// a resource acquired and never finalized, a fiber suspended and never
    /// resumed, a service required with no provider. Those leave no stack frame,
    /// so a trace cannot show them and the compiler never saw them. That is the
    /// whole of what the causal graph knows and a stack trace does not.
    ///
    /// Deliberately not the ancestor walk. A real one measures five nodes of
    /// which four are `run_started` / `effect_started` scaffolding, and it
    /// restates `@errorName` at four times the cost. Adding it would make this
    /// something an agent learns to skip.
    fn stageFailureBrief(self: *TestContext) void {
        if (comptime !failure_sink.enabled) return;

        var findings = self.causal_store.findings(self.allocator) catch return;
        defer findings.deinit();
        if (findings.items.len == 0) return;

        var buffer: [2048]u8 = undefined;
        var written: usize = 0;
        written += (std.fmt.bufPrint(buffer[written..], "zigeffect causal brief   {s} / {s}\n", .{
            self.options.scenario.requirement,
            self.options.scenario.id,
        }) catch return).len;

        const shown = @min(findings.items.len, 4);
        for (findings.items[0..shown]) |finding| {
            written += (std.fmt.bufPrint(buffer[written..], "  finding  {s}  e#{d}", .{
                @tagName(finding.kind),
                finding.event_id,
            }) catch break).len;
            if (finding.label.len != 0) {
                written += (std.fmt.bufPrint(buffer[written..], "  {s}", .{finding.label}) catch break).len;
            }
            if (finding.scope_id) |scope| {
                written += (std.fmt.bufPrint(buffer[written..], "  scope={d}", .{scope}) catch break).len;
            }
            if (finding.fiber_id) |fiber| {
                written += (std.fmt.bufPrint(buffer[written..], "  fiber={d}", .{fiber}) catch break).len;
            }
            written += (std.fmt.bufPrint(buffer[written..], "\n", .{}) catch break).len;
        }
        if (findings.items.len > shown) {
            if (std.fmt.bufPrint(buffer[written..], "  ... {d} more\n", .{findings.items.len - shown})) |text| {
                written += text.len;
            } else |_| {}
        }
        failure_sink.stage(buffer[0..written]);
    }

    pub fn service(self: *TestContext, comptime Service: type) *Service {
        return self.env.services.service(Service);
    }

    pub fn serviceLayer(self: *TestContext, comptime services: anytype) @TypeOf(self.env.serviceLayer(services)) {
        return self.env.serviceLayer(services);
    }

    pub fn context(self: *TestContext) @TypeOf(self.env.context()) {
        return self.env.context().withCausalStore(&self.causal_store);
    }

    pub fn runtime(self: *TestContext) @TypeOf(self.env.runtime()) {
        return self.env.runtime().withCausalStore(&self.causal_store);
    }

    /// Borrow the test-owned causal store for a canonical `zstd.ManagedRuntime`.
    /// The runtime may attach its scoped durable backend, but never destroys the
    /// store and restores any previous backend before shutdown returns.
    pub fn causalStore(self: *TestContext) *fx.CausalStore {
        return &self.causal_store;
    }

    /// Derive the durable correlation context for the scenario under test.
    ///
    /// Every node the managed runtime persists inherits these identifiers, so an
    /// agent can select causal evidence by requirement, acceptance check, or
    /// scenario instead of paging the whole graph and filtering client-side.
    /// The runtime fills workspace/project/session identity itself, so only the
    /// fields the scenario actually knows are set here.
    pub fn causalContext(self: *TestContext) fx.CausalContextV2 {
        const selected = self.options.scenario;
        return .{
            .requirement_id = fx.stableCausalContextId(selected.requirement),
            .acceptance_check_id = fx.stableCausalContextId(selected.acceptance_check),
            .scenario_id = fx.stableCausalContextId(selected.id),
            .component_id = fx.stableCausalContextId(selected.component),
            .source_revision_id = fx.stableCausalContextId(self.options.source_revision),
        };
    }

    /// Convert every assertion reference from recorder-local IDs to the
    /// persistent IDs accepted by causal graph queries. Call this while the
    /// managed runtime is live, after recording assertions and before publish.
    pub fn mapCausalEventIds(self: *TestContext, managed: anytype) !void {
        if (self.finished or self.causal_event_id_space != .runtime_local) return error.InvalidCausalEventIdSpace;
        if (!managed.usesCausalStore(&self.causal_store)) return error.CausalStoreMismatch;
        for (self.assertions.items) |assertion| {
            for (assertion.causal_event_ids) |event_id| {
                _ = managed.durableCausalEventId(event_id) orelse return error.CausalEventNotDurable;
            }
        }
        for (self.assertions.items) |*assertion| {
            // Capture what each cited event was before rewriting the id, while
            // the recorder is still live and can answer. Afterwards only the
            // durable id survives, and a receipt carrying an id into a pruned or
            // absent graph proves nothing.
            const facts = try self.allocator.alloc(Contract.CausalFact, assertion.causal_event_ids.len);
            errdefer self.allocator.free(facts);
            for (assertion.causal_event_ids, facts) |event_id, *fact| {
                fact.* = .{ .event_id = managed.durableCausalEventId(event_id).? };
                for (self.causal_store.events.items) |event| {
                    if (event.id != event_id) continue;
                    fact.* = .{
                        .event_id = fact.event_id,
                        .kind = try self.allocator.dupe(u8, @tagName(event.kind)),
                        .label = try self.allocator.dupe(u8, event.label),
                        .status = try self.allocator.dupe(u8, event.status),
                        .service_key = try self.allocator.dupe(u8, event.service_key),
                    };
                    break;
                }
            }
            freeCausalFacts(self.allocator, assertion.causal_facts);
            assertion.causal_facts = facts;

            const ids = @constCast(assertion.causal_event_ids);
            for (ids) |*event_id| {
                event_id.* = managed.durableCausalEventId(event_id.*).?;
            }
        }
        self.causal_event_id_space = .graph_durable;
        self.causal_graph_session_id = managed.causalGraphSessionId();
    }

    pub fn run(self: *TestContext, effect: anytype) !@TypeOf(effect).SuccessType {
        var runner = self.runtime();
        return runner.run(effect);
    }

    pub fn exit(self: *TestContext, effect: anytype) fx.Exit(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType) {
        var runner = self.runtime();
        return runner.exit(effect);
    }

    pub fn addAssertion(self: *TestContext, assertion: Contract.AssertionResult) !void {
        if (self.assertions.items.len >= self.options.max_assertions) {
            self.dropped_assertions += 1;
            return error.AssertionLimitReached;
        }
        for (self.assertions.items) |existing| {
            if (std.mem.eql(u8, existing.id, assertion.id)) return error.DuplicateAssertion;
        }
        try assertion.validate();
        const owned = try cloneAssertion(self.allocator, assertion);
        errdefer deinitAssertion(self.allocator, owned);
        try self.assertions.append(self.allocator, owned);
    }

    pub fn addArtifact(self: *TestContext, artifact: Artifact) !void {
        if (self.artifacts.items.len >= self.options.max_artifacts) {
            self.truncated_artifacts += 1;
            return error.ArtifactLimitReached;
        }
        try validateName(artifact.id);
        try Project.validateRelativePath(artifact.path, false);
        if (artifact.media_type.len == 0 or artifact.media_type.len > 128) return error.InvalidArtifact;
        for (self.artifacts.items) |existing| {
            if (std.mem.eql(u8, existing.id, artifact.id)) return error.DuplicateArtifact;
        }
        const owned = try cloneArtifact(self.allocator, artifact);
        errdefer deinitArtifact(self.allocator, owned);
        try self.artifacts.append(self.allocator, owned);
    }

    pub fn addLimitation(self: *TestContext, limitation: []const u8) !void {
        if (limitation.len == 0 or limitation.len > 4096) return error.InvalidLimitation;
        try self.limitations.append(self.allocator, try self.allocator.dupe(u8, limitation));
    }

    pub fn addCoverageTarget(self: *TestContext, target: Contract.CoverageTarget) !void {
        try target.validate();
        for (self.coverage_targets.items) |existing| if (std.mem.eql(u8, existing.id, target.id)) return error.DuplicateCoverageTarget;
        const owned = try cloneCoverageTarget(self.allocator, target);
        errdefer deinitCoverageTarget(self.allocator, owned);
        try self.coverage_targets.append(self.allocator, owned);
    }

    pub fn addCoverageHit(self: *TestContext, hit: Contract.CoverageHit) !void {
        try hit.validate();
        var found = false;
        for (self.coverage_targets.items) |target| if (std.mem.eql(u8, target.id, hit.target_id)) {
            found = true;
            break;
        };
        if (!found) return error.UnknownCoverageTarget;
        for (self.coverage_hits.items) |existing| if (std.mem.eql(u8, existing.target_id, hit.target_id) and std.mem.eql(u8, existing.evidence_id, hit.evidence_id)) return error.DuplicateCoverageHit;
        const owned = try cloneCoverageHit(self.allocator, hit);
        errdefer deinitCoverageHit(self.allocator, owned);
        try self.coverage_hits.append(self.allocator, owned);
    }

    pub fn recordEvidence(self: *TestContext, kind: Contract.EvidenceKind, summary: Contract.EvidenceSummary) !void {
        try summary.validate();
        for (self.evidence.items) |existing| if (existing.kind == kind) return error.DuplicateEvidence;
        const owned = try cloneNamedEvidence(self.allocator, .{ .kind = kind, .summary = summary });
        errdefer deinitNamedEvidence(self.allocator, owned);
        try self.evidence.append(self.allocator, owned);
    }

    pub fn recordReport(self: *TestContext, kind: Contract.EvidenceKind, report: anytype) !void {
        try self.recordEvidence(kind, report.evidenceSummary());
    }

    pub fn authorizeSideEffect(self: *TestContext, request: Sandbox.Request) !void {
        return self.firewall.authorize(request);
    }

    pub fn allowRealSideEffect(self: *TestContext, effect: Sandbox.SideEffect) void {
        self.firewall.allowReal(effect);
    }

    pub fn finish(self: *TestContext, ended_ms: i64) !Contract.TestReceipt {
        if (self.finished) return error.AlreadyFinished;
        if (self.firewall.decisions.items.len != 0) {
            var recorded = false;
            for (self.evidence.items) |item| if (item.kind == .sandbox) {
                recorded = true;
                break;
            };
            if (!recorded) try self.recordEvidence(.sandbox, self.firewall.evidenceSummary());
        }
        self.finished = true;
        var snapshot = try self.causal_store.snapshot(self.allocator);
        defer snapshot.deinit();
        var findings = try self.causal_store.findings(self.allocator);
        defer findings.deinit();
        var fibers = try self.causal_store.fiberStates(self.allocator);
        defer fibers.deinit();

        var failed_assertions: usize = 0;
        for (self.assertions.items) |assertion| if (assertion.status == .failed) {
            failed_assertions += 1;
        };
        var leaked_resources: usize = 0;
        for (findings.items) |finding| if (finding.kind == .resource_acquired_without_finalization) {
            leaked_resources += 1;
        };
        const completeness = Contract.Completeness{
            .dropped_assertions = self.dropped_assertions,
            .dropped_runtime_events = @intCast(self.causal_store.droppedEventCount()),
            .truncated_artifacts = self.truncated_artifacts + @as(usize, @intCast(self.causal_store.truncatedFieldCount())),
            .sampled_events = @intCast(self.causal_store.sampledEventCount()),
        };
        const causal = Contract.CausalSummary{
            .events = snapshot.events.len,
            .findings = findings.items.len,
            .pending_fibers = fibers.unresolvedCount(),
            .leaked_resources = leaked_resources,
            .assertion_failures = failed_assertions,
        };
        var coverage_report = try Coverage.analyzeAlloc(self.allocator, self.coverage_targets.items, self.coverage_hits.items, false);
        defer coverage_report.deinit();
        var evidence_failed = false;
        var evidence_incomplete = false;
        for (self.evidence.items) |item| {
            if (item.summary.attempted and item.summary.status == .failed) evidence_failed = true;
            if (!item.summary.complete()) evidence_incomplete = true;
        }
        const status: Contract.TestStatus = if (failed_assertions > 0 or !causal.clean() or evidence_failed) .failed else if (!completeness.complete() or !coverage_report.summary.complete() or evidence_incomplete or (self.options.scenario.required and self.assertions.items.len == 0)) .incomplete else .passed;
        return .{
            .project = self.options.project,
            .suite = self.options.suite,
            .scenario = self.options.scenario,
            .source_revision = self.options.source_revision,
            .zig_version = self.options.zig_version,
            .status = status,
            .required = self.options.scenario.required,
            .started_ms = self.options.started_ms,
            .ended_ms = ended_ms,
            .seed = self.options.seed,
            .executor = self.options.executor,
            .fault_kind = self.options.fault_kind,
            .fault_index = self.options.fault_index,
            .schedule_choices = self.options.schedule_choices,
            .execution = self.options.execution,
            .coverage_targets = self.coverage_targets.items,
            .coverage_hits = self.coverage_hits.items,
            .coverage = coverage_report.summary,
            .evidence = self.evidence.items,
            .assertions = self.assertions.items,
            .causal_event_id_space = self.causal_event_id_space,
            .causal_graph_session_id = self.causal_graph_session_id,
            .causal = causal,
            .completeness = completeness,
            .limitations = self.limitations.items,
        };
    }

    pub fn finishAlloc(self: *TestContext, ended_ms: i64) ![]u8 {
        const receipt = try self.finish(ended_ms);
        return receipt.jsonAlloc(self.allocator);
    }

    pub fn publish(self: *TestContext, io: std.Io, dir: std.Io.Dir, ended_ms: i64) !void {
        const receipt = try self.finish(ended_ms);
        try Protocol.publishRawReceipt(self.allocator, io, dir, receipt);
        // The committable half: stable across runs, so it can be reviewed and
        // shared rather than only produced.
        try Protocol.publishRequirementEvidence(self.allocator, io, dir, receipt);
        if (self.control) |control| {
            if (control.value.process_receipt_path.len > 0)
                try Protocol.publishReceiptAt(self.allocator, io, dir, control.value.process_receipt_path, receipt)
            else
                try Protocol.publishReceipt(self.allocator, io, dir, receipt);
        }
    }
};

fn validateName(name: []const u8) !void {
    if (name.len == 0 or name.len > 128) return error.InvalidName;
    for (name) |byte| if (!(std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.')) return error.InvalidName;
}

fn dupe(allocator: std.mem.Allocator, value: []const u8) ![]const u8 {
    return allocator.dupe(u8, value);
}

fn cloneCausalFacts(allocator: std.mem.Allocator, facts: []const Contract.CausalFact) ![]Contract.CausalFact {
    const owned = try allocator.alloc(Contract.CausalFact, facts.len);
    var cloned: usize = 0;
    errdefer {
        for (owned[0..cloned]) |fact| {
            allocator.free(fact.kind);
            allocator.free(fact.label);
            allocator.free(fact.status);
            allocator.free(fact.service_key);
        }
        allocator.free(owned);
    }
    for (facts, owned) |source, *target| {
        target.* = .{
            .event_id = source.event_id,
            .kind = try dupe(allocator, source.kind),
            .label = try dupe(allocator, source.label),
            .status = try dupe(allocator, source.status),
            .service_key = try dupe(allocator, source.service_key),
        };
        cloned += 1;
    }
    return owned;
}

fn freeCausalFacts(allocator: std.mem.Allocator, facts: []const Contract.CausalFact) void {
    for (facts) |fact| {
        allocator.free(fact.kind);
        allocator.free(fact.label);
        allocator.free(fact.status);
        allocator.free(fact.service_key);
    }
    allocator.free(@constCast(facts));
}

fn cloneAssertion(allocator: std.mem.Allocator, value: Contract.AssertionResult) !Contract.AssertionResult {
    var owned = value;
    owned.id = try dupe(allocator, value.id);
    errdefer allocator.free(owned.id);
    owned.label = try dupe(allocator, value.label);
    errdefer allocator.free(owned.label);
    owned.source.id = try dupe(allocator, value.source.id);
    errdefer allocator.free(owned.source.id);
    owned.source.path = try dupe(allocator, value.source.path);
    errdefer allocator.free(owned.source.path);
    owned.causal_event_ids = try allocator.dupe(u64, value.causal_event_ids);
    errdefer allocator.free(owned.causal_event_ids);
    // Deep-copied because deinitAssertion frees these. Copying the struct by
    // value would alias the caller's slice and then free memory this context
    // never owned.
    owned.causal_facts = try cloneCausalFacts(allocator, value.causal_facts);
    errdefer freeCausalFacts(allocator, owned.causal_facts);
    owned.expected = try dupe(allocator, value.expected);
    errdefer allocator.free(owned.expected);
    owned.actual = try dupe(allocator, value.actual);
    errdefer allocator.free(owned.actual);
    owned.detail = try dupe(allocator, value.detail);
    errdefer allocator.free(owned.detail);
    owned.repair_hint = try dupe(allocator, value.repair_hint);
    return owned;
}

fn deinitAssertion(allocator: std.mem.Allocator, value: Contract.AssertionResult) void {
    allocator.free(value.id);
    allocator.free(value.label);
    allocator.free(value.source.id);
    allocator.free(value.source.path);
    allocator.free(value.causal_event_ids);
    freeCausalFacts(allocator, value.causal_facts);
    allocator.free(value.expected);
    allocator.free(value.actual);
    allocator.free(value.detail);
    allocator.free(value.repair_hint);
}

fn cloneArtifact(allocator: std.mem.Allocator, value: Artifact) !Artifact {
    var owned = value;
    owned.id = try dupe(allocator, value.id);
    errdefer allocator.free(owned.id);
    owned.path = try dupe(allocator, value.path);
    errdefer allocator.free(owned.path);
    owned.media_type = try dupe(allocator, value.media_type);
    errdefer allocator.free(owned.media_type);
    owned.digest = try dupe(allocator, value.digest);
    return owned;
}

fn deinitArtifact(allocator: std.mem.Allocator, value: Artifact) void {
    allocator.free(value.id);
    allocator.free(value.path);
    allocator.free(value.media_type);
    allocator.free(value.digest);
}

fn cloneCoverageTarget(allocator: std.mem.Allocator, value: Contract.CoverageTarget) !Contract.CoverageTarget {
    var owned = value;
    owned.id = try dupe(allocator, value.id);
    errdefer allocator.free(owned.id);
    owned.label = try dupe(allocator, value.label);
    errdefer allocator.free(owned.label);
    owned.repair_hint = try dupe(allocator, value.repair_hint);
    errdefer allocator.free(owned.repair_hint);
    owned.next_command = try dupe(allocator, value.next_command);
    return owned;
}

fn deinitCoverageTarget(allocator: std.mem.Allocator, value: Contract.CoverageTarget) void {
    allocator.free(value.id);
    allocator.free(value.label);
    allocator.free(value.repair_hint);
    allocator.free(value.next_command);
}

fn cloneCoverageHit(allocator: std.mem.Allocator, value: Contract.CoverageHit) !Contract.CoverageHit {
    const target_id = try dupe(allocator, value.target_id);
    errdefer allocator.free(target_id);
    return .{ .target_id = target_id, .evidence_id = try dupe(allocator, value.evidence_id) };
}

fn deinitCoverageHit(allocator: std.mem.Allocator, value: Contract.CoverageHit) void {
    allocator.free(value.target_id);
    allocator.free(value.evidence_id);
}

fn cloneNamedEvidence(allocator: std.mem.Allocator, value: Contract.NamedEvidence) !Contract.NamedEvidence {
    var owned = value;
    owned.summary.artifact = try dupe(allocator, value.summary.artifact);
    errdefer allocator.free(owned.summary.artifact);
    owned.summary.replay_token = try dupe(allocator, value.summary.replay_token);
    return owned;
}

fn deinitNamedEvidence(allocator: std.mem.Allocator, value: Contract.NamedEvidence) void {
    allocator.free(value.summary.artifact);
    allocator.free(value.summary.replay_token);
}

fn scenario() Contract.Scenario {
    return .{
        .id = "context-test",
        .label = "context owns test evidence",
        .requirement = "req-testing",
        .acceptance_check = "check-context",
        .component = "std-testing",
        .command = "test",
    };
}

test "typed fixture registry replaces values and runs cleanup" {
    const Value = struct { bytes: []u8 };
    const cleanup = struct {
        fn call(allocator: std.mem.Allocator, value: *Value) void {
            allocator.free(value.bytes);
        }
    }.call;
    var fixtures = FixtureRegistry(Value).init(std.testing.allocator, cleanup);
    defer fixtures.deinit();
    try fixtures.put("message", .{ .bytes = try std.testing.allocator.dupe(u8, "one") });
    try fixtures.put("message", .{ .bytes = try std.testing.allocator.dupe(u8, "two") });
    try std.testing.expectEqualStrings("two", (try fixtures.require("message")).bytes);
    try std.testing.expectEqual(@as(usize, 1), fixtures.count());
}

test "TestContext derives a redacted complete receipt from owned evidence" {
    var ctx = try TestContext.init(std.testing.allocator, .{
        .project = "demo",
        .suite = "unit",
        .scenario = scenario(),
        .started_ms = 10,
    });
    defer ctx.deinit();
    try ctx.addAssertion(.{
        .id = "assert-safe",
        .label = "output is safe",
        .status = .passed,
        .detail = "authorization: Bearer sentinel-secret-for-tests",
    });
    try ctx.addArtifact(.{ .id = "causal", .path = ".zigeffect/tests/context.jsonl", .media_type = "application/x-ndjson" });
    const json = try ctx.finishAlloc(30);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "sentinel-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"status\":\"passed\"") != null);
    try std.testing.expectEqual(@as(usize, 1), ctx.artifacts.items.len);
}

test "TestContext reads matching control and publishes native receipt" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try Protocol.writeControl(std.testing.allocator, std.testing.io, tmp.dir, .{
        .scenario = scenario(),
        .project = "demo",
        .seed = 99,
        .fault_kind = .timeout,
        .fault_index = 2,
        .executor = "deterministic",
        .source_revision = "sha256:controlled",
        .command_digest = "sha256:command",
    });
    var ctx = try TestContext.initFromProject(std.testing.allocator, std.testing.io, tmp.dir, .{
        .project = "demo",
        .suite = "unit",
        .scenario = scenario(),
    });
    defer ctx.deinit();
    try ctx.addAssertion(.{ .id = "native", .label = "native receipt", .status = .passed });
    try ctx.publish(std.testing.io, tmp.dir, 20);
    var parsed = try Protocol.readPublishedReceipt(std.testing.allocator, std.testing.io, tmp.dir, "context-test");
    defer parsed.deinit();
    try std.testing.expectEqual(@as(u64, 99), parsed.value.seed);
    try std.testing.expectEqual(Contract.FaultKind.timeout, parsed.value.fault_kind);
    try std.testing.expect(parsed.value.execution.native_receipt);
    try std.testing.expectEqualStrings("sha256:command", parsed.value.execution.command_digest);

    var raw = try Protocol.readRawReceipt(std.testing.allocator, std.testing.io, tmp.dir, "context-test");
    defer raw.deinit();
    try std.testing.expectEqualStrings("sha256:controlled", raw.value.source_revision);
}

test "uncontrolled package tests cannot overwrite authoritative process evidence" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try Protocol.writeControl(std.testing.allocator, std.testing.io, tmp.dir, .{
        .scenario = scenario(),
        .project = "demo",
        .seed = 99,
        .source_revision = "sha256:authoritative",
        .command_digest = "sha256:command",
    });
    var controlled = try TestContext.initFromProject(std.testing.allocator, std.testing.io, tmp.dir, .{
        .project = "demo",
        .suite = "unit",
        .scenario = scenario(),
    });
    defer controlled.deinit();
    try controlled.addAssertion(.{ .id = "controlled", .label = "controlled receipt", .status = .passed });
    try controlled.publish(std.testing.io, tmp.dir, 20);
    try Protocol.removeControl(std.testing.allocator, std.testing.io, tmp.dir, "context-test");

    var local = try TestContext.initFromProject(std.testing.allocator, std.testing.io, tmp.dir, .{
        .project = "demo",
        .suite = "unit",
        .scenario = scenario(),
    });
    defer local.deinit();
    try local.addAssertion(.{ .id = "local", .label = "local package receipt", .status = .passed });
    try local.publish(std.testing.io, tmp.dir, 30);

    var authoritative = try Protocol.readPublishedReceipt(std.testing.allocator, std.testing.io, tmp.dir, "context-test");
    defer authoritative.deinit();
    try std.testing.expectEqualStrings("sha256:authoritative", authoritative.value.source_revision);
    var raw = try Protocol.readRawReceipt(std.testing.allocator, std.testing.io, tmp.dir, "context-test");
    defer raw.deinit();
    try std.testing.expectEqualStrings("working-tree", raw.value.source_revision);
}

test "TestContext reports required zero-assertion and bounded evidence as incomplete" {
    var ctx = try TestContext.init(std.testing.allocator, .{
        .project = "demo",
        .suite = "unit",
        .scenario = scenario(),
        .max_assertions = 1,
    });
    defer ctx.deinit();
    try ctx.addAssertion(.{ .id = "first", .label = "first", .status = .passed });
    try std.testing.expectError(error.AssertionLimitReached, ctx.addAssertion(.{ .id = "second", .label = "second", .status = .passed }));
    const receipt = try ctx.finish(1);
    try std.testing.expectEqual(Contract.TestStatus.incomplete, receipt.status);
    try std.testing.expectEqual(@as(usize, 1), receipt.completeness.dropped_assertions);
}

test "TestContext turns required semantic coverage gaps into incomplete receipts" {
    var ctx = try TestContext.init(std.testing.allocator, .{ .project = "demo", .suite = "unit", .scenario = scenario() });
    defer ctx.deinit();
    try ctx.addAssertion(.{ .id = "behavior", .label = "behavior", .status = .passed });
    try ctx.addCoverageTarget(.{ .id = "acceptance", .label = "acceptance", .dimension = .acceptance });
    var receipt = try ctx.finish(1);
    try std.testing.expectEqual(Contract.TestStatus.incomplete, receipt.status);
    try std.testing.expectEqual(@as(usize, 1), receipt.coverage.required_gaps);

    var covered = try TestContext.init(std.testing.allocator, .{ .project = "demo", .suite = "unit", .scenario = scenario() });
    defer covered.deinit();
    try covered.addAssertion(.{ .id = "behavior", .label = "behavior", .status = .passed });
    try covered.addCoverageTarget(.{ .id = "acceptance", .label = "acceptance", .dimension = .acceptance });
    try covered.addCoverageHit(.{ .target_id = "acceptance", .evidence_id = "behavior" });
    receipt = try covered.finish(1);
    try std.testing.expectEqual(Contract.TestStatus.passed, receipt.status);
}

test "TestContext folds advanced evidence into the common verdict" {
    var ctx = try TestContext.init(std.testing.allocator, .{ .project = "demo", .suite = "unit", .scenario = scenario() });
    defer ctx.deinit();
    try ctx.addAssertion(.{ .id = "behavior", .label = "behavior", .status = .passed });
    try ctx.recordEvidence(.schedule, .{ .attempted = true, .status = .incomplete, .planned = 2, .executed = 1, .passed = 1, .truncated = true, .replay_token = "schedule:0" });
    const receipt = try ctx.finish(1);
    try std.testing.expectEqual(Contract.TestStatus.incomplete, receipt.status);
    try std.testing.expectEqual(Contract.EvidenceKind.schedule, receipt.evidence[0].kind);
}

test "TestContext owns side-effect authority and failed denials reach the receipt" {
    var ctx = try TestContext.init(std.testing.allocator, .{ .project = "demo", .suite = "unit", .scenario = scenario() });
    defer ctx.deinit();
    try ctx.addAssertion(.{ .id = "behavior", .label = "behavior", .status = .passed });
    try ctx.authorizeSideEffect(.{ .effect = .database, .adapter = .fake, .causal_event_id = 1 });
    try std.testing.expectError(error.SideEffectDenied, ctx.authorizeSideEffect(.{ .effect = .network, .adapter = .real, .causal_event_id = 2 }));
    const receipt = try ctx.finish(1);
    try std.testing.expectEqual(Contract.TestStatus.failed, receipt.status);
    try std.testing.expectEqual(Contract.EvidenceKind.sandbox, receipt.evidence[0].kind);
}

test "TestContext initialization and owned evidence are allocation-failure safe" {
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var ctx = try TestContext.init(allocator, .{ .project = "demo", .suite = "unit", .scenario = scenario() });
            defer ctx.deinit();
            try ctx.addAssertion(.{ .id = "owned", .label = "owned", .status = .passed, .actual = "value" });
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}
