const std = @import("std");
const dep_services = @import("../dependency/services.zig");
const backend_mod = @import("../runtime/backend.zig");
const async_backend_mod = @import("../runtime/async_backend.zig");
const backend_diagnostics = @import("../runtime/backend_diagnostics.zig");
const journal_mod = @import("journal.zig");
const store_mod = @import("store.zig");

pub const Allocator = std.mem.Allocator;
pub const ServiceSet = dep_services.ServiceSet;
pub const BackendCapabilities = backend_mod.BackendCapabilities;
pub const deterministicBackend = backend_mod.deterministicBackend;
pub const AsyncBackend = async_backend_mod.AsyncBackend;
pub const WorkflowBackendRequirement = backend_diagnostics.BackendCapabilityRequirement;
pub const JournalStore = store_mod.JournalStore;
pub const WorkflowId = journal_mod.WorkflowId;
pub const ExecutionId = journal_mod.ExecutionId;
pub const JournalSequence = journal_mod.JournalSequence;

pub const WorkflowExecutionStatus = enum {
    running,
    completed,
    failed,
    interrupted,
    cancelled,
};

pub const WorkflowEngineError = error{
    WorkflowAlreadyRegistered,
    WorkflowNotRegistered,
    DuplicateWorkflowExecution,
    MissingServiceRequirement,
    UnsupportedBackendCapability,
    ParentWorkflowNotFound,
};

pub const WorkflowExecution = struct {
    workflow_name: []const u8,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    status: WorkflowExecutionStatus,
    started_sequence: JournalSequence,
    parent_workflow_id: ?WorkflowId = null,
    parent_execution_id: ?ExecutionId = null,
};

pub const WorkflowExecutionList = struct {
    allocator: Allocator,
    executions: []WorkflowExecution,

    pub fn deinit(self: *WorkflowExecutionList) void {
        self.allocator.free(self.executions);
    }
};

pub fn WorkflowResult(comptime Success: type, comptime Failure: type) type {
    return union(enum) {
        running: WorkflowExecution,
        completed: Success,
        failed: Failure,
        not_found,
    };
}

const WorkflowRegistration = struct {
    workflow_name: []const u8,
    workflow_id: WorkflowId,
};

pub const WorkflowEngine = struct {
    allocator: Allocator,
    journal_store: JournalStore,
    provider_services: ServiceSet,
    backend: BackendCapabilities = deterministicBackend(),
    async_backend: ?AsyncBackend = null,
    registrations: std.ArrayList(WorkflowRegistration) = .empty,
    executions: std.ArrayList(WorkflowExecution) = .empty,

    pub fn init(allocator: Allocator, journal_store: JournalStore) WorkflowEngine {
        return .{
            .allocator = allocator,
            .journal_store = journal_store,
            .provider_services = ServiceSet.init(allocator),
        };
    }

    pub fn initWithBackend(allocator: Allocator, journal_store: JournalStore, backend: BackendCapabilities) WorkflowEngine {
        var engine = WorkflowEngine.init(allocator, journal_store);
        engine.backend = backend;
        return engine;
    }

    pub fn initWithAsyncBackend(allocator: Allocator, journal_store: JournalStore, async_backend: AsyncBackend) WorkflowEngine {
        var engine = WorkflowEngine.initWithBackend(allocator, journal_store, async_backend.capabilities);
        engine.async_backend = async_backend;
        return engine;
    }

    pub fn initWithProviders(allocator: Allocator, journal_store: JournalStore, comptime providers: anytype) Allocator.Error!WorkflowEngine {
        var engine = WorkflowEngine.init(allocator, journal_store);
        errdefer engine.deinit();
        engine.provider_services = try ServiceSet.fromTypes(allocator, providers);
        return engine;
    }

    pub fn deinit(self: *WorkflowEngine) void {
        self.executions.deinit(self.allocator);
        self.registrations.deinit(self.allocator);
        self.provider_services.deinit();
    }

    pub fn backendCapabilities(self: *const WorkflowEngine) BackendCapabilities {
        return self.backend;
    }

    pub fn asyncBackend(self: *const WorkflowEngine) ?AsyncBackend {
        return self.async_backend;
    }

    pub fn withAsyncBackend(self: WorkflowEngine, async_backend: AsyncBackend) WorkflowEngine {
        var engine = self;
        engine.async_backend = async_backend;
        engine.backend = async_backend.capabilities;
        return engine;
    }

    pub fn requireBackendFeature(self: *const WorkflowEngine, requirement: WorkflowBackendRequirement) WorkflowEngineError!void {
        try backend_diagnostics.requireBackendFeature(self.backend, requirement);
    }

    pub fn formatBackendRequirementDiagnostic(self: *const WorkflowEngine, allocator: Allocator, requirement: WorkflowBackendRequirement) Allocator.Error![]const u8 {
        return backend_diagnostics.formatBackendCapabilityDiagnostic(allocator, self.backend, requirement);
    }

    pub fn register(self: *WorkflowEngine, comptime WorkflowType: type) (Allocator.Error || WorkflowEngineError)!void {
        if (self.findRegistration(WorkflowType.name) != null) return error.WorkflowAlreadyRegistered;

        var required = try WorkflowType.requiredServices(self.allocator);
        defer required.deinit();
        for (required.names.items) |required_name| {
            if (!self.provider_services.contains(required_name)) return error.MissingServiceRequirement;
        }

        try self.registrations.append(self.allocator, .{
            .workflow_name = WorkflowType.name,
            .workflow_id = workflowId(WorkflowType.name),
        });
    }

    pub fn execute(self: *WorkflowEngine, comptime WorkflowType: type, payload: WorkflowType.PayloadType) anyerror!WorkflowExecution {
        return self.executeInternal(WorkflowType, payload, null, false);
    }

    /// Starts a child workflow with durable parent identity. Repeating the same
    /// child command is idempotent and returns the existing child execution.
    pub fn executeChild(
        self: *WorkflowEngine,
        parent_workflow_id: WorkflowId,
        parent_execution_id: ExecutionId,
        comptime WorkflowType: type,
        payload: WorkflowType.PayloadType,
    ) anyerror!WorkflowExecution {
        const parent = self.findExecution(parent_execution_id) orelse return error.ParentWorkflowNotFound;
        if (parent.workflow_id != parent_workflow_id) return error.ParentWorkflowNotFound;
        return self.executeInternal(WorkflowType, payload, parent, true);
    }

    fn executeInternal(
        self: *WorkflowEngine,
        comptime WorkflowType: type,
        payload: WorkflowType.PayloadType,
        parent: ?WorkflowExecution,
        idempotent_duplicate: bool,
    ) anyerror!WorkflowExecution {
        const registration = self.findRegistration(WorkflowType.name) orelse return error.WorkflowNotRegistered;
        const idempotency_key = try WorkflowType.idempotencyKey(self.allocator, payload);
        defer self.allocator.free(idempotency_key);

        const execution_id = executionId(WorkflowType.name, idempotency_key);
        if (self.findExecution(execution_id)) |existing| {
            const expected_parent_workflow_id: ?WorkflowId = if (parent) |value| value.workflow_id else null;
            const expected_parent_execution_id: ?ExecutionId = if (parent) |value| value.execution_id else null;
            if (idempotent_duplicate and
                existing.parent_workflow_id == expected_parent_workflow_id and
                existing.parent_execution_id == expected_parent_execution_id)
            {
                return existing;
            }
            return error.DuplicateWorkflowExecution;
        }

        const sequence = try self.nextJournalSequence();
        const execution = WorkflowExecution{
            .workflow_name = WorkflowType.name,
            .workflow_id = registration.workflow_id,
            .execution_id = execution_id,
            .status = .running,
            .started_sequence = sequence,
            .parent_workflow_id = if (parent) |value| value.workflow_id else null,
            .parent_execution_id = if (parent) |value| value.execution_id else null,
        };

        try self.executions.ensureUnusedCapacity(self.allocator, 1);
        _ = try self.journal_store.append(.{
            .event = .{
                .sequence = sequence,
                .kind = .workflow_started,
                .workflow_id = execution.workflow_id,
                .execution_id = execution.execution_id,
                .parent_sequence = if (parent) |value| value.started_sequence else null,
                .parent_workflow_id = execution.parent_workflow_id,
                .parent_execution_id = execution.parent_execution_id,
                .name = WorkflowType.name,
                .status = "running",
                .idempotency_key = idempotency_key,
            },
        });
        self.executions.appendAssumeCapacity(execution);

        return execution;
    }

    pub fn poll(self: *const WorkflowEngine, comptime WorkflowType: type, execution_id: ExecutionId) !WorkflowResult(WorkflowType.SuccessType, WorkflowType.FailureType) {
        if (self.findExecution(execution_id)) |execution| {
            return .{ .running = execution };
        }
        return .not_found;
    }

    pub fn inspect(self: *const WorkflowEngine, execution_id: ExecutionId) ?WorkflowExecution {
        return self.findExecution(execution_id);
    }

    pub fn list(self: *const WorkflowEngine, allocator: Allocator) Allocator.Error!WorkflowExecutionList {
        const executions = try allocator.alloc(WorkflowExecution, self.executions.items.len);
        @memcpy(executions, self.executions.items);
        return .{ .allocator = allocator, .executions = executions };
    }

    fn nextJournalSequence(self: *WorkflowEngine) anyerror!JournalSequence {
        var events = try self.journal_store.readAll(self.allocator);
        defer events.deinit();
        if (events.events.len == 0) return 1;
        return events.events[events.events.len - 1].sequence + 1;
    }

    fn findRegistration(self: *const WorkflowEngine, workflow_name: []const u8) ?WorkflowRegistration {
        for (self.registrations.items) |registration| {
            if (std.mem.eql(u8, registration.workflow_name, workflow_name)) return registration;
        }
        return null;
    }

    fn findExecution(self: *const WorkflowEngine, execution_id: ExecutionId) ?WorkflowExecution {
        for (self.executions.items) |execution| {
            if (execution.execution_id == execution_id) return execution;
        }
        return null;
    }
};

pub fn workflowId(workflow_name: []const u8) WorkflowId {
    return std.hash.Fnv1a_64.hash(workflow_name);
}

pub fn executionId(workflow_name: []const u8, idempotency_key: []const u8) ExecutionId {
    var hasher = std.hash.Fnv1a_64.init();
    hasher.update(workflow_name);
    hasher.update(":");
    hasher.update(idempotency_key);
    return hasher.final();
}
