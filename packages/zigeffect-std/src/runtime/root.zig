const std = @import("std");
const fx = @import("zigeffect");
const CausalGraph = @import("../causal_graph/root.zig");
const Project = @import("../project/root.zig");
const Development = @import("../development/root.zig");

pub const agent_map_schema = "zigeffect.agent.application-map.v5";
pub const agent_map_schema_version: u32 = 5;
pub const development_map_schema = "zigeffect.agent.development-map.v3";
pub const development_map_schema_version: u32 = 3;
pub const causal_health_schema = "zigeffect.causal.runtime-health.v1";
pub const causal_health_schema_version: u32 = 1;

pub const HealthStatus = enum {
    healthy,
    degraded,
};

/// Narrow semantic-event capability for transport and platform adapters. It
/// keeps the owned store private while routing boundary facts through the same
/// runtime recorder and embedded NenDB graph as structural events.
pub const CausalRecorder = fx.kernel.CausalRecorder;

pub const Health = struct {
    schema: []const u8 = causal_health_schema,
    schema_version: u32 = causal_health_schema_version,
    status: HealthStatus,
    backend: []const u8 = "nendb_embedded",
    engine_version: []const u8,
    engine_upstream_commit: []const u8,
    durable: bool = true,
    durable_records: usize,
    durable_edges: usize,
    node_capacity: usize,
    edge_capacity: usize,
    backend_failures: u64,
    failed_writes: u64,
    dropped_events: u64,
    sampled_events: u64,
    truncated_fields: u64,
    last_failure: ?[]const u8,
};

pub const Options = struct {
    graph: CausalGraph.Options = .{},
    causal_options: fx.CausalStoreOptions = .{
        .max_events = 4096,
        .max_event_string_bytes = 512,
    },
    aspects: []const fx.kernel.RuntimeAspect = &.{},
    observability: fx.kernel.RuntimeObservability = .{},
    defaults: ?fx.kernel.DefaultServices = null,
    causal_context: fx.CausalContextV2 = .{},
    /// Optional caller-owned recorder used by deterministic tests and embedded
    /// hosts. The runtime fans its NenDB backend out with any existing backend,
    /// restores that backend at shutdown, and never destroys the supplied store.
    causal_store: ?*fx.CausalStore = null,
};

/// Canonical process-level ZigEffect runtime. Unlike the lower-level
/// `fx.kernel.ManagedRuntime`, this runtime always owns a durable embedded
/// NenDB causal graph and checks persistence at shutdown.
pub fn ManagedRuntime(comptime RootLayer: type) type {
    return struct {
        const Self = @This();
        const KernelRuntime = fx.kernel.ManagedRuntime(RootLayer);

        const State = struct {
            allocator: std.mem.Allocator,
            io: std.Io,
            root: std.Io.Dir,
            graph: *CausalGraph.LocalDatabase,
            backend: *fx.CausalNendbStorageBackendState,
            store: *fx.CausalStore,
            owned_store: ?*fx.CausalStore,
            previous_backend: ?fx.CausalBackend,
            store_backend_failures_at_start: u64,
            fanout_backends: ?*[2]fx.CausalBackend,
            fanout: ?*fx.CausalFanoutBackendState,
            project_manifest_json: ?[]u8,
            causal_context: fx.CausalContextV2,
            kernel_runtime: KernelRuntime,
        };

        pub const OutputServices = RootLayer.OutputServices;
        pub const Handle = KernelRuntime.Handle;

        state: ?*State,

        pub fn make(
            allocator: std.mem.Allocator,
            io: std.Io,
            root: std.Io.Dir,
            root_layer: RootLayer,
            options: Options,
        ) !Self {
            const loaded_project = try loadProjectManifestAlloc(allocator, io, root);
            const project_manifest_json = loaded_project.json;
            errdefer if (project_manifest_json) |json| allocator.free(json);

            // The CLI opens this same graph using the manifest's safety limits,
            // so a writer allowed to exceed them produces a file its own tooling
            // cannot read. Clamping here keeps the two in agreement by
            // construction; an explicitly tighter caller bound still wins.
            var graph_options = options.graph;
            if (loaded_project.max_artifact_bytes) |limit| {
                graph_options.max_wal_bytes = @min(graph_options.max_wal_bytes, limit);
            }
            if (loaded_project.max_runtime_events) |limit| {
                graph_options.max_records = @min(graph_options.max_records, limit);
            }

            const graph = try allocator.create(CausalGraph.LocalDatabase);
            errdefer allocator.destroy(graph);
            graph.* = try CausalGraph.LocalDatabase.init(allocator, io, root, graph_options);
            errdefer graph.deinit();

            const backend = try allocator.create(fx.CausalNendbStorageBackendState);
            errdefer allocator.destroy(backend);
            backend.* = graph.storageBackend(allocator, graph_options.max_records);
            errdefer backend.deinit();

            const owned_store = if (options.causal_store == null) try allocator.create(fx.CausalStore) else null;
            errdefer if (owned_store) |store| allocator.destroy(store);
            if (owned_store) |store| store.* = fx.CausalStore.initWithOptions(allocator, options.causal_options);
            errdefer if (owned_store) |store| store.deinit();
            const store = options.causal_store orelse owned_store.?;
            const store_backend_failures_at_start = store.backendFailureCount();

            const previous_backend = store.replaceBackend(null);
            errdefer _ = store.replaceBackend(previous_backend);
            var fanout_backends: ?*[2]fx.CausalBackend = null;
            var fanout: ?*fx.CausalFanoutBackendState = null;
            if (previous_backend) |existing| {
                const backends = try allocator.create([2]fx.CausalBackend);
                errdefer allocator.destroy(backends);
                backends.* = .{ existing, backend.backend() };
                const state = try allocator.create(fx.CausalFanoutBackendState);
                errdefer allocator.destroy(state);
                state.* = fx.CausalFanoutBackendState.init(backends[0..]);
                fanout_backends = backends;
                fanout = state;
                _ = store.replaceBackend(state.backend());
            } else {
                _ = store.replaceBackend(backend.backend());
            }
            errdefer {
                _ = store.replaceBackend(previous_backend);
                if (fanout) |state| allocator.destroy(state);
                if (fanout_backends) |backends| allocator.destroy(backends);
            }

            var causal_context = options.causal_context;
            causal_context.graph_session_id = causal_context.graph_session_id orelse graph.currentSessionId();
            causal_context.runtime_instance_id = causal_context.runtime_instance_id orelse graph.currentSessionId();
            causal_context.project_id = causal_context.project_id orelse loaded_project.project_id;
            causal_context.component_id = causal_context.component_id orelse loaded_project.component_id;
            causal_context.workspace_id = causal_context.workspace_id orelse loaded_project.project_id;
            var kernel_runtime = try KernelRuntime.make(allocator, root_layer, .{
                .causal_store = store,
                .aspects = options.aspects,
                .observability = options.observability,
                .defaults = options.defaults,
                .causal_context = causal_context,
            });
            errdefer kernel_runtime.deinit();

            const state = try allocator.create(State);
            state.* = .{
                .allocator = allocator,
                .io = io,
                .root = root,
                .graph = graph,
                .backend = backend,
                .store = store,
                .owned_store = owned_store,
                .previous_backend = previous_backend,
                .store_backend_failures_at_start = store_backend_failures_at_start,
                .fanout_backends = fanout_backends,
                .fanout = fanout,
                .project_manifest_json = project_manifest_json,
                .causal_context = causal_context,
                .kernel_runtime = kernel_runtime,
            };
            return .{ .state = state };
        }

        pub fn deinit(self: *Self) void {
            self.shutdown() catch {};
        }

        /// Dispose the runtime, flush the graph, release all owned state, and
        /// fail when any event could not be persisted.
        pub fn shutdown(self: *Self) !void {
            const state = self.state orelse return;
            self.state = null;

            state.kernel_runtime.deinit();

            var flush_failure: ?anyerror = null;
            state.backend.flush() catch |failure| {
                flush_failure = failure;
            };
            const backend_failure = state.backend.lastFailure();
            const backend_failures = state.store.backendFailureCount() -| state.store_backend_failures_at_start;

            _ = state.store.replaceBackend(state.previous_backend);
            state.backend.deinit();
            if (state.fanout) |fanout| state.allocator.destroy(fanout);
            if (state.fanout_backends) |backends| state.allocator.destroy(backends);
            if (state.owned_store) |store| {
                store.deinit();
                state.allocator.destroy(store);
            }
            state.graph.deinit();
            state.allocator.destroy(state.backend);
            state.allocator.destroy(state.graph);
            if (state.project_manifest_json) |json| state.allocator.free(json);
            const allocator = state.allocator;
            allocator.destroy(state);

            if (flush_failure) |failure| return failure;
            if (backend_failure) |failure| return failure;
            if (backend_failures != 0) return error.CausalGraphWriteFailed;
        }

        pub fn handle(self: *Self) Handle {
            return self.requireState().kernel_runtime.handle();
        }

        pub fn run(self: *Self, effect: anytype) @TypeOf(effect).FailureType!@TypeOf(effect).SuccessType {
            return self.requireState().kernel_runtime.run(effect);
        }

        pub fn runWithCausalContext(
            self: *Self,
            effect: anytype,
            context: fx.CausalContextV2,
        ) @TypeOf(effect).FailureType!@TypeOf(effect).SuccessType {
            return self.requireState().kernel_runtime.runWithCausalContext(effect, context);
        }

        pub fn causalRecorder(self: *Self) CausalRecorder {
            return .{ .store = self.requireState().store };
        }

        pub fn usesCausalStore(self: *Self, store: *fx.CausalStore) bool {
            return self.requireState().store == store;
        }

        pub fn inspect(
            self: *Self,
            allocator: std.mem.Allocator,
            options: fx.kernel.InspectOptions,
        ) std.mem.Allocator.Error!fx.kernel.ApplicationSnapshot {
            return self.requireState().kernel_runtime.inspect(allocator, options);
        }

        pub fn inspectJson(
            self: *Self,
            allocator: std.mem.Allocator,
            options: fx.kernel.InspectOptions,
        ) std.mem.Allocator.Error![]u8 {
            return self.requireState().kernel_runtime.inspectJson(allocator, options);
        }

        pub fn causalHealth(self: *Self) Health {
            const state = self.requireState();
            const engine = state.graph.engineStats();
            const backend_failure = state.backend.lastFailure();
            const backend_failures = state.store.backendFailureCount() -| state.store_backend_failures_at_start;
            const failed_writes = state.backend.failedEventCount();
            return .{
                .status = if (backend_failure == null and backend_failures == 0 and failed_writes == 0) .healthy else .degraded,
                .engine_version = engine.version,
                .engine_upstream_commit = engine.upstream_commit,
                .durable_records = state.graph.recordCount(),
                .durable_edges = state.graph.edgeCount(),
                .node_capacity = engine.node_capacity,
                .edge_capacity = engine.edge_capacity,
                .backend_failures = backend_failures,
                .failed_writes = failed_writes,
                .dropped_events = state.store.droppedEventCount(),
                .sampled_events = state.store.sampledEventCount(),
                .truncated_fields = state.store.truncatedFieldCount(),
                .last_failure = if (backend_failure) |failure| @errorName(failure) else null,
            };
        }

        pub fn graphSummary(self: *Self) CausalGraph.Summary {
            return self.requireState().graph.summary();
        }

        /// Translate an event ID from this runtime's bounded recorder into the
        /// durable ID used by graph queries for the current graph session.
        pub fn durableCausalEventId(self: *Self, runtime_event_id: u64) ?u64 {
            return self.requireState().graph.durableId(runtime_event_id);
        }

        pub fn causalGraphSessionId(self: *Self) u64 {
            return self.requireState().graph.currentSessionId();
        }

        pub fn graphSummaryJsonAlloc(self: *Self, allocator: std.mem.Allocator) ![]u8 {
            return self.requireState().graph.summaryJsonAlloc(allocator);
        }

        pub fn graphRecordJsonAlloc(self: *Self, allocator: std.mem.Allocator, durable_event_id: u64) ![]u8 {
            return self.requireState().graph.recordJsonAlloc(allocator, durable_event_id);
        }

        pub fn graphSinceJsonAlloc(
            self: *Self,
            allocator: std.mem.Allocator,
            after_durable_event_id: u64,
            limit: usize,
        ) ![]u8 {
            if (limit == 0 or limit > 4096) return error.InvalidGraphQueryLimit;
            return self.requireState().graph.recordsAfterJsonAlloc(allocator, after_durable_event_id, limit);
        }

        pub fn graphChildrenJsonAlloc(self: *Self, allocator: std.mem.Allocator, durable_event_id: u64) ![]u8 {
            const state = self.requireState();
            const children = try state.graph.childrenAlloc(allocator, durable_event_id);
            defer allocator.free(children);
            return CausalGraph.childrenJsonAlloc(allocator, durable_event_id, children);
        }

        pub fn graphPathJsonAlloc(
            self: *Self,
            allocator: std.mem.Allocator,
            from_durable_event_id: u64,
            to_durable_event_id: u64,
            max_events: usize,
        ) ![]u8 {
            return self.requireState().graph.pathJsonAlloc(
                allocator,
                from_durable_event_id,
                to_durable_event_id,
                max_events,
            );
        }

        /// Compute the same opaque reference used by `.track` without exposing
        /// the source value to the graph. Guarded agent endpoints use this to
        /// turn an authorized product/order lookup into a lineage query.
        pub fn lineageReference(self: *Self, comptime Key: type, value: Key.Value) fx.Lineage.Error!fx.Lineage.Ref {
            return Key.reference(self.requireState().causal_context.project_id, value);
        }

        /// Return one bounded, progress-making page of durable NenDB records
        /// that observed the reference. Continue from `next_after_event_id`
        /// whenever `truncated` is true.
        pub fn graphLineageJsonAlloc(
            self: *Self,
            allocator: std.mem.Allocator,
            reference: fx.Lineage.Ref,
            after_durable_event_id: u64,
            limit: usize,
            scan_limit: usize,
        ) ![]u8 {
            return self.requireState().graph.lineageRecordsJsonAlloc(
                allocator,
                reference,
                after_durable_event_id,
                limit,
                scan_limit,
            );
        }

        /// Return the single bounded discovery document used by guarded agent
        /// endpoints. Follow-up event and child queries use durable graph IDs.
        pub fn agentMapJsonAlloc(
            self: *Self,
            allocator: std.mem.Allocator,
            options: fx.kernel.InspectOptions,
        ) ![]u8 {
            const application_json = try self.inspectJson(allocator, options);
            defer allocator.free(application_json);
            const graph_json = try self.graphSummaryJsonAlloc(allocator);
            defer allocator.free(graph_json);
            const health_json = try std.json.Stringify.valueAlloc(allocator, self.causalHealth(), .{});
            defer allocator.free(health_json);
            const manifest_json = self.requireState().project_manifest_json orelse "null";
            const context_json = try std.json.Stringify.valueAlloc(allocator, self.requireState().causal_context, .{});
            defer allocator.free(context_json);
            const observed_json = try self.developmentObservationJsonAlloc(allocator);
            defer allocator.free(observed_json);

            return std.fmt.allocPrint(
                allocator,
                "{{\"schema\":\"{s}\",\"schema_version\":{d},\"application\":{s},\"graph\":{s},\"causal_health\":{s},\"causal_context\":{s},\"development\":{{\"schema\":\"{s}\",\"schema_version\":{d},\"manifest\":{s},\"observed\":{s},\"artifacts\":{{\"progress\":\".zigeffect/tests/progress.jsonl\",\"proof_handoff\":\".zigeffect/handoffs/tests/latest.json\"}},\"workflow\":{{\"context\":\"zigeffect agent context --task <id-or-summary> --budget 65536 --json\",\"compatibility\":\"zigeffect compatibility --json\",\"validate\":\"zigeffect project validate --json\",\"status\":\"zigeffect agent status --json\",\"next\":\"zigeffect agent next --json\",\"tests\":\"zigeffect test list --json\",\"affected\":\"zigeffect test affected --changed <path> --json\",\"run_scenario\":\"zigeffect test run --scenario <id> --json\",\"coverage\":\"zigeffect test coverage --requirement <id> --json\",\"gaps\":\"zigeffect test gaps --requirement <id> --json\",\"graph_status\":\"zigeffect graph status --json\",\"graph_since\":\"zigeffect graph since <event-id> --limit 256 --json\",\"graph_path\":\"zigeffect graph path <from> <to> --json\",\"graph_lineage\":\"runtime.graphLineageJsonAlloc(reference, after, limit, scan_limit)\",\"handoff\":\"zigeffect agent handoff --provider <provider> --session <session> --json\"}}}},\"queries\":{{\"discovery\":\"agent_map\",\"since\":\"graph_since\",\"event\":\"graph_record\",\"children\":\"graph_children\",\"path\":\"graph_path\",\"lineage\":\"graph_lineage\",\"recent_event_id_space\":\"runtime_local\",\"durable_event_id_space\":\"graph\",\"correlation_model\":\"zigeffect.causal-context.v3\",\"default_delta_limit\":256}}}}",
                .{
                    agent_map_schema,
                    agent_map_schema_version,
                    application_json,
                    graph_json,
                    health_json,
                    context_json,
                    development_map_schema,
                    development_map_schema_version,
                    manifest_json,
                    observed_json,
                },
            );
        }

        fn developmentObservationJsonAlloc(self: *Self, allocator: std.mem.Allocator) ![]u8 {
            const state = self.requireState();
            const manifest_json = state.project_manifest_json orelse return allocator.dupe(u8, "null");
            var manifest = try Project.parseManifest(allocator, manifest_json);
            defer manifest.deinit();
            var source = try Development.sourceIdentityAlloc(allocator, state.io, state.root, .{});
            defer source.deinit();
            var evidence = try Development.collectEvidenceAlloc(
                allocator,
                state.io,
                state.root,
                manifest.value,
                source.revision,
                manifest.value.safety.limits.max_artifact_bytes,
            );
            defer evidence.deinit();
            var reconciled = try Development.reconcileAlloc(allocator, manifest.value, evidence.run(), source.revision);
            defer reconciled.deinit();
            return std.json.Stringify.valueAlloc(allocator, .{
                .source = .{ .revision = source.revision, .dirty = source.dirty },
                .requirements = reconciled.requirements,
                .checks = reconciled.checks,
                .requirements_satisfied = reconciled.requirements_satisfied,
                .requirements_open = reconciled.requirements_open,
                .checks_passed = reconciled.checks_passed,
                .checks_pending = reconciled.checks_pending,
                .checks_failed = reconciled.checks_failed,
            }, .{});
        }

        fn requireState(self: *Self) *State {
            return self.state orelse @panic("zigeffect ManagedRuntime has already been disposed");
        }
    };
}

const LoadedProject = struct {
    json: ?[]u8 = null,
    project_id: ?u64 = null,
    component_id: ?u64 = null,
    max_artifact_bytes: ?usize = null,
    max_runtime_events: ?usize = null,
};

fn loadProjectManifestAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
) !LoadedProject {
    const input = root.readFileAlloc(io, "zigeffect.project.json", allocator, .limited(4 * 1024 * 1024)) catch |failure| switch (failure) {
        error.FileNotFound => return .{},
        else => return failure,
    };
    defer allocator.free(input);
    var manifest = try Project.parseManifest(allocator, input);
    defer manifest.deinit();
    return .{
        .json = try manifest.value.jsonAlloc(allocator),
        .project_id = fx.stableCausalContextId(manifest.value.name),
        .component_id = if (manifest.value.components.len == 1) fx.stableCausalContextId(manifest.value.components[0].id) else null,
        .max_artifact_bytes = manifest.value.safety.limits.max_artifact_bytes,
        .max_runtime_events = manifest.value.safety.limits.max_runtime_events,
    };
}
