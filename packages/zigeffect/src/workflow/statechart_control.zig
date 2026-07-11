const control = @import("../statechart/control.zig");
const lifecycle_mod = @import("lifecycle.zig");
const replay = @import("replay.zig");

pub fn WorkflowControlAdapter(comptime Event: type) type {
    return struct {
        const Self = @This();
        const Plane = control.ControlPlane(Event);

        lifecycle: *lifecycle_mod.WorkflowLifecycle,
        definition_fingerprint: u64,
        fence_epoch: u64,

        pub fn init(lifecycle: *lifecycle_mod.WorkflowLifecycle, definition_fingerprint: u64, fence_epoch: u64) Self {
            return .{ .lifecycle = lifecycle, .definition_fingerprint = definition_fingerprint, .fence_epoch = fence_epoch };
        }

        pub fn adapter(self: *Self) Plane.Adapter {
            return .{ .context = self, .inspect_fn = inspect, .apply_fn = apply };
        }

        fn inspect(context: *anyopaque, instance_id: u64) anyerror!Plane.InstanceState {
            const self: *Self = @ptrCast(@alignCast(context));
            if (instance_id != self.lifecycle.workflow_id) return error.WorkflowNotFound;
            return .{
                .definition_fingerprint = self.definition_fingerprint,
                .fence_epoch = self.fence_epoch,
                .status = mapStatus(try self.lifecycle.inspectStatus()),
            };
        }

        fn apply(context: *anyopaque, request: Plane.Request) anyerror!void {
            const self: *Self = @ptrCast(@alignCast(context));
            if (request.instance_id != self.lifecycle.workflow_id) return error.WorkflowNotFound;
            const changed = switch (request.operation) {
                .inspect => true,
                .@"suspend" => try self.lifecycle.suspendWorkflow(request.reason),
                .@"resume", .retry => try self.lifecycle.resumeWorkflow(request.reason),
                .cancel, .drain => try self.lifecycle.cancel(request.reason),
                .start, .signal, .checkpoint, .restart, .migrate => return error.UnsupportedWorkflowControlOperation,
            };
            if (!changed) return error.WorkflowControlStateConflict;
        }

        fn mapStatus(status: replay.WorkflowStatus) control.InstanceStatus {
            return switch (status) {
                .pending => .pending,
                .running => .running,
                .suspended => .suspended,
                .completed => .completed,
                .failed, .defect => .failed,
                .cancelled, .interrupted => .cancelled,
            };
        }
    };
}
