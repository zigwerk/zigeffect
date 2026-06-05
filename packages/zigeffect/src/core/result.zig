const std = @import("std");

pub const Allocator = std.mem.Allocator;

pub fn Cause(comptime Failure: type) type {
    return union(enum) {
        const Self = @This();

        failure: Failure,
        defect: []const u8,
        interrupted: u64,
        finalizer_failure: []const u8,
        failure_then_finalizer_failure: struct {
            failure: Failure,
            finalizer_failure: []const u8,
        },
        defect_then_finalizer_failure: struct {
            defect: []const u8,
            finalizer_failure: []const u8,
        },
        interrupted_then_finalizer_failure: struct {
            fiber_id: u64,
            finalizer_failure: []const u8,
        },
        sequential: struct {
            left: *const Self,
            right: *const Self,
        },
        parallel: struct {
            left: *const Self,
            right: *const Self,
        },
        annotated: struct {
            cause: *const Self,
            annotation: []const u8,
        },
    };
}

pub fn CauseTree(comptime Failure: type) type {
    return struct {
        const Self = @This();

        pub const Node = union(enum) {
            const NodeSelf = @This();

            failure: Failure,
            defect: []const u8,
            interrupted: u64,
            finalizer_failure: []const u8,
            failure_then_finalizer_failure: struct {
                failure: Failure,
                finalizer_failure: []const u8,
            },
            defect_then_finalizer_failure: struct {
                defect: []const u8,
                finalizer_failure: []const u8,
            },
            interrupted_then_finalizer_failure: struct {
                fiber_id: u64,
                finalizer_failure: []const u8,
            },
            sequential: struct {
                left: *const NodeSelf,
                right: *const NodeSelf,
            },
            parallel: struct {
                left: *const NodeSelf,
                right: *const NodeSelf,
            },
            annotated: struct {
                cause: *const NodeSelf,
                annotation: []const u8,
            },
        };

        allocator: Allocator,
        nodes: std.ArrayList(*Node) = .empty,
        root: ?*Node = null,

        pub fn init(allocator: Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            for (self.nodes.items) |node| {
                self.allocator.destroy(node);
            }
            self.nodes.deinit(self.allocator);
            self.root = null;
        }

        fn appendNode(self: *Self, node: Node) Allocator.Error!*Node {
            const owned = try self.allocator.create(Node);
            errdefer self.allocator.destroy(owned);
            owned.* = node;
            try self.nodes.append(self.allocator, owned);
            self.root = owned;
            return owned;
        }

        pub fn failure(self: *Self, err: Failure) Allocator.Error!*Node {
            return self.appendNode(.{ .failure = err });
        }

        pub fn defect(self: *Self, message: []const u8) Allocator.Error!*Node {
            return self.appendNode(.{ .defect = message });
        }

        pub fn interrupted(self: *Self, fiber_id: u64) Allocator.Error!*Node {
            return self.appendNode(.{ .interrupted = fiber_id });
        }

        pub fn finalizerFailure(self: *Self, name: []const u8) Allocator.Error!*Node {
            return self.appendNode(.{ .finalizer_failure = name });
        }

        pub fn sequential(self: *Self, left: *const Node, right: *const Node) Allocator.Error!*Node {
            return self.appendNode(.{ .sequential = .{ .left = left, .right = right } });
        }

        pub fn parallel(self: *Self, left: *const Node, right: *const Node) Allocator.Error!*Node {
            return self.appendNode(.{ .parallel = .{ .left = left, .right = right } });
        }

        pub fn annotated(self: *Self, cause: *const Node, annotation: []const u8) Allocator.Error!*Node {
            return self.appendNode(.{ .annotated = .{ .cause = cause, .annotation = annotation } });
        }

        pub fn copyFromCause(self: *Self, cause: anytype) Allocator.Error!*Node {
            return switch (cause) {
                .failure => |err| self.failure(err),
                .defect => |message| self.defect(message),
                .interrupted => |fiber_id| self.interrupted(fiber_id),
                .finalizer_failure => |name| self.finalizerFailure(name),
                .failure_then_finalizer_failure => |both| self.appendNode(.{ .failure_then_finalizer_failure = .{
                    .failure = both.failure,
                    .finalizer_failure = both.finalizer_failure,
                } }),
                .defect_then_finalizer_failure => |both| self.appendNode(.{ .defect_then_finalizer_failure = .{
                    .defect = both.defect,
                    .finalizer_failure = both.finalizer_failure,
                } }),
                .interrupted_then_finalizer_failure => |both| self.appendNode(.{ .interrupted_then_finalizer_failure = .{
                    .fiber_id = both.fiber_id,
                    .finalizer_failure = both.finalizer_failure,
                } }),
                .sequential => |pair| {
                    const left = try self.copyFromCause(pair.left.*);
                    const right = try self.copyFromCause(pair.right.*);
                    return self.sequential(left, right);
                },
                .parallel => |pair| {
                    const left = try self.copyFromCause(pair.left.*);
                    const right = try self.copyFromCause(pair.right.*);
                    return self.parallel(left, right);
                },
                .annotated => |annotation| {
                    const copied = try self.copyFromCause(annotation.cause.*);
                    return self.annotated(copied, annotation.annotation);
                },
            };
        }

        pub fn hasFinalizerFailure(self: *const Self, expected: []const u8) bool {
            const node = self.root orelse return false;
            return causeHasFinalizerFailure(node.*, expected);
        }

        pub fn hasDefect(self: *const Self, expected: []const u8) bool {
            const node = self.root orelse return false;
            return causeHasDefect(node.*, expected);
        }

        pub fn hasInterruption(self: *const Self, fiber_id: u64) bool {
            const node = self.root orelse return false;
            return causeHasInterruption(node.*, fiber_id);
        }

        pub fn format(self: *const Self, label: []const u8) Allocator.Error![]const u8 {
            const node = self.root orelse return std.fmt.allocPrint(
                self.allocator,
                "zigeffect cause report\nprogram: {s}\ncause: empty",
                .{label},
            );
            return formatCause(self.allocator, label, node.*);
        }
    };
}

pub fn Exit(comptime Success: type, comptime Failure: type) type {
    return union(enum) {
        success: Success,
        failure: Failure,
        defect: []const u8,
        interrupted: u64,
        cause: Cause(Failure),
    };
}

pub fn causeTreeWithFinalizerFailure(
    allocator: Allocator,
    comptime Success: type,
    comptime Failure: type,
    exit: Exit(Success, Failure),
    finalizer_failure: []const u8,
) Allocator.Error!CauseTree(Failure) {
    var tree = CauseTree(Failure).init(allocator);
    errdefer tree.deinit();

    switch (exit) {
        .success => {
            _ = try tree.finalizerFailure(finalizer_failure);
        },
        .failure => |err| {
            const left = try tree.failure(err);
            const right = try tree.finalizerFailure(finalizer_failure);
            _ = try tree.sequential(left, right);
        },
        .defect => |message| {
            const left = try tree.defect(message);
            const right = try tree.finalizerFailure(finalizer_failure);
            _ = try tree.sequential(left, right);
        },
        .interrupted => |fiber_id| {
            const left = try tree.interrupted(fiber_id);
            const right = try tree.finalizerFailure(finalizer_failure);
            _ = try tree.sequential(left, right);
        },
        .cause => |cause| {
            const left = try tree.copyFromCause(cause);
            const right = try tree.finalizerFailure(finalizer_failure);
            _ = try tree.sequential(left, right);
        },
    }

    return tree;
}

pub const FinalizerExit = union(enum) {
    success,
    failure: []const u8,
    defect: []const u8,
    interrupted: u64,
    cause: []const u8,
};

pub fn finalizerExitFromExit(exit: anytype) FinalizerExit {
    return switch (exit) {
        .success => .success,
        .failure => |err| .{ .failure = @errorName(err) },
        .defect => |message| .{ .defect = message },
        .interrupted => |fiber_id| .{ .interrupted = fiber_id },
        .cause => .{ .cause = "cause" },
    };
}

pub fn exitWithFinalizerFailure(
    comptime Success: type,
    comptime Failure: type,
    exit: Exit(Success, Failure),
    finalizer_failure: []const u8,
) Exit(Success, Failure) {
    return switch (exit) {
        .failure => |err| .{ .cause = .{ .failure_then_finalizer_failure = .{
            .failure = err,
            .finalizer_failure = finalizer_failure,
        } } },
        .defect => |message| .{ .cause = .{ .defect_then_finalizer_failure = .{
            .defect = message,
            .finalizer_failure = finalizer_failure,
        } } },
        .interrupted => |fiber_id| .{ .cause = .{ .interrupted_then_finalizer_failure = .{
            .fiber_id = fiber_id,
            .finalizer_failure = finalizer_failure,
        } } },
        else => .{ .cause = .{ .finalizer_failure = finalizer_failure } },
    };
}

pub fn causeHasFinalizerFailure(cause: anytype, expected: []const u8) bool {
    return switch (cause) {
        .finalizer_failure => |name| std.mem.eql(u8, name, expected),
        .failure_then_finalizer_failure => |both| std.mem.eql(u8, both.finalizer_failure, expected),
        .defect_then_finalizer_failure => |both| std.mem.eql(u8, both.finalizer_failure, expected),
        .interrupted_then_finalizer_failure => |both| std.mem.eql(u8, both.finalizer_failure, expected),
        .sequential => |pair| causeHasFinalizerFailure(pair.left.*, expected) or causeHasFinalizerFailure(pair.right.*, expected),
        .parallel => |pair| causeHasFinalizerFailure(pair.left.*, expected) or causeHasFinalizerFailure(pair.right.*, expected),
        .annotated => |annotated| causeHasFinalizerFailure(annotated.cause.*, expected),
        else => false,
    };
}

pub fn causeHasDefect(cause: anytype, expected: []const u8) bool {
    return switch (cause) {
        .defect => |message| std.mem.eql(u8, message, expected),
        .defect_then_finalizer_failure => |both| std.mem.eql(u8, both.defect, expected),
        .sequential => |pair| causeHasDefect(pair.left.*, expected) or causeHasDefect(pair.right.*, expected),
        .parallel => |pair| causeHasDefect(pair.left.*, expected) or causeHasDefect(pair.right.*, expected),
        .annotated => |annotated| causeHasDefect(annotated.cause.*, expected),
        else => false,
    };
}

pub fn causeHasInterruption(cause: anytype, fiber_id: u64) bool {
    return switch (cause) {
        .interrupted => |id| id == fiber_id,
        .interrupted_then_finalizer_failure => |both| both.fiber_id == fiber_id,
        .sequential => |pair| causeHasInterruption(pair.left.*, fiber_id) or causeHasInterruption(pair.right.*, fiber_id),
        .parallel => |pair| causeHasInterruption(pair.left.*, fiber_id) or causeHasInterruption(pair.right.*, fiber_id),
        .annotated => |annotated| causeHasInterruption(annotated.cause.*, fiber_id),
        else => false,
    };
}

pub fn exitToResult(
    comptime Success: type,
    comptime Failure: type,
    exit: Exit(Success, Failure),
) Failure!Success {
    return switch (exit) {
        .success => |value| value,
        .failure => |err| err,
        .defect => |message| std.debug.panic("zigeffect defect cannot be converted to a typed error: {s}", .{message}),
        .interrupted => |fiber_id| std.debug.panic("zigeffect interruption cannot be converted to a typed error: {d}", .{fiber_id}),
        .cause => std.debug.panic("zigeffect cause cannot be converted to a typed error; inspect Exit/Cause instead", .{}),
    };
}

pub fn formatCause(allocator: Allocator, label: []const u8, cause: anytype) Allocator.Error![]const u8 {
    return switch (cause) {
        .failure => |err| std.fmt.allocPrint(
            allocator,
            "zigeffect cause report\nprogram: {s}\ncause: failure\nerror: {s}\nhint: Handle this error in the caller or add a recovery boundary.",
            .{ label, @errorName(err) },
        ),
        .defect => |message| std.fmt.allocPrint(
            allocator,
            "zigeffect cause report\nprogram: {s}\ncause: defect\nmessage: {s}\nhint: Defects are unexpected runtime problems. Fix the program path that created this defect.",
            .{ label, message },
        ),
        .interrupted => |fiber_id| std.fmt.allocPrint(
            allocator,
            "zigeffect cause report\nprogram: {s}\ncause: interrupted\nfiber: {d}\nhint: Check the caller or supervisor that interrupted this work.",
            .{ label, fiber_id },
        ),
        .finalizer_failure => |name| std.fmt.allocPrint(
            allocator,
            "zigeffect cause report\nprogram: {s}\ncause: finalizer failure\nfinalizer error: {s}\nhint: A resource cleanup action failed. Inspect the scoped resource release path.",
            .{ label, name },
        ),
        .failure_then_finalizer_failure => |both| std.fmt.allocPrint(
            allocator,
            "zigeffect cause report\nprogram: {s}\ncause: failure then finalizer failure\nerror: {s}\nfinalizer error: {s}\nhint: Handle the program failure and inspect the scoped resource release path.",
            .{ label, @errorName(both.failure), both.finalizer_failure },
        ),
        .defect_then_finalizer_failure => |both| std.fmt.allocPrint(
            allocator,
            "zigeffect cause report\nprogram: {s}\ncause: defect then finalizer failure\nmessage: {s}\nfinalizer error: {s}\nhint: Fix the defect and inspect the scoped resource release path.",
            .{ label, both.defect, both.finalizer_failure },
        ),
        .interrupted_then_finalizer_failure => |both| std.fmt.allocPrint(
            allocator,
            "zigeffect cause report\nprogram: {s}\ncause: interrupted then finalizer failure\nfiber: {d}\nfinalizer error: {s}\nhint: Check the interrupter and inspect the scoped resource release path.",
            .{ label, both.fiber_id, both.finalizer_failure },
        ),
        .sequential => |pair| {
            const left = try formatCause(allocator, label, pair.left.*);
            defer allocator.free(left);
            const right = try formatCause(allocator, label, pair.right.*);
            defer allocator.free(right);
            return std.fmt.allocPrint(
                allocator,
                "zigeffect cause report\nprogram: {s}\ncause: sequential\nleft:\n{s}\nright:\n{s}",
                .{ label, left, right },
            );
        },
        .parallel => |pair| {
            const left = try formatCause(allocator, label, pair.left.*);
            defer allocator.free(left);
            const right = try formatCause(allocator, label, pair.right.*);
            defer allocator.free(right);
            return std.fmt.allocPrint(
                allocator,
                "zigeffect cause report\nprogram: {s}\ncause: parallel\nleft:\n{s}\nright:\n{s}",
                .{ label, left, right },
            );
        },
        .annotated => |annotated| {
            const inner = try formatCause(allocator, label, annotated.cause.*);
            defer allocator.free(inner);
            return std.fmt.allocPrint(
                allocator,
                "zigeffect cause report\nprogram: {s}\ncause: annotated\nannotation: {s}\ninner:\n{s}",
                .{ label, annotated.annotation, inner },
            );
        },
    };
}

pub fn formatExit(allocator: Allocator, label: []const u8, exit: anytype) Allocator.Error![]const u8 {
    return switch (exit) {
        .success => std.fmt.allocPrint(
            allocator,
            "zigeffect success report\nprogram: {s}\nstatus: success\nhint: Program completed successfully.",
            .{label},
        ),
        .failure => |err| std.fmt.allocPrint(
            allocator,
            "zigeffect failure report\nprogram: {s}\nstatus: failure\nerror: {s}\nhint: Handle this error in the caller or include an explicit recovery effect.",
            .{ label, @errorName(err) },
        ),
        .defect => |message| std.fmt.allocPrint(
            allocator,
            "zigeffect failure report\nprogram: {s}\nstatus: defect\nmessage: {s}\nhint: Defects are unexpected runtime problems. Fix the program path that created this defect.",
            .{ label, message },
        ),
        .interrupted => |fiber_id| std.fmt.allocPrint(
            allocator,
            "zigeffect failure report\nprogram: {s}\nstatus: interrupted\nfiber: {d}\nhint: Check the caller or supervisor that interrupted this work.",
            .{ label, fiber_id },
        ),
        .cause => |cause| formatCause(allocator, label, cause),
    };
}
