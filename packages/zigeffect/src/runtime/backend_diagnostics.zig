const std = @import("std");
const backend_mod = @import("backend.zig");

pub const Allocator = std.mem.Allocator;
pub const BackendCapabilities = backend_mod.BackendCapabilities;

pub const BackendFeature = enum {
    suspension,
    wake,
    timer,
    interrupt,
    durable_suspend,
    persistence,
    distribution,
    supervision,
    parallelism,
};

pub const BackendCapabilityRequirement = struct {
    feature: BackendFeature,
    operation: []const u8,
    workflow_name: ?[]const u8 = null,
};

pub const BackendCapabilityDiagnostic = struct {
    backend: BackendCapabilities,
    requirement: BackendCapabilityRequirement,
};

pub const BackendCapabilityError = error{
    UnsupportedBackendCapability,
};

pub fn backendSupportsFeature(backend: BackendCapabilities, feature: BackendFeature) bool {
    return switch (feature) {
        .suspension => backend.can_suspend,
        .wake => backend.can_wake,
        .timer => backend.can_schedule_timers,
        .interrupt => backend.can_interrupt,
        .durable_suspend => backend.can_durable_suspend,
        .persistence => backend.can_persist,
        .distribution => backend.can_distribute,
        .supervision => backend.can_supervise,
        .parallelism => backend.can_parallel,
    };
}

pub fn requireBackendFeature(backend: BackendCapabilities, requirement: BackendCapabilityRequirement) BackendCapabilityError!void {
    if (!backendSupportsFeature(backend, requirement.feature)) {
        return error.UnsupportedBackendCapability;
    }
}

pub fn formatBackendCapabilityDiagnostic(
    allocator: Allocator,
    backend: BackendCapabilities,
    requirement: BackendCapabilityRequirement,
) Allocator.Error![]const u8 {
    const workflow_name = requirement.workflow_name orelse "<none>";
    return std.fmt.allocPrint(
        allocator,
        "backend capability unavailable: backend={s} operation={s} feature={s} workflow={s} hint={s}",
        .{
            @tagName(backend.kind),
            requirement.operation,
            @tagName(requirement.feature),
            workflow_name,
            backendCapabilityHint(requirement.feature),
        },
    );
}

fn backendCapabilityHint(feature: BackendFeature) []const u8 {
    return switch (feature) {
        .suspension,
        .wake,
        .timer,
        .interrupt,
        .durable_suspend,
        => "use durableLocalBackend, asyncLocalBackend, or clusteredBackend",
        .persistence => "use durableLocalBackend or clusteredBackend",
        .distribution => "use clusteredBackend",
        .supervision,
        .parallelism,
        => "use asyncLocalBackend or clusteredBackend",
    };
}
