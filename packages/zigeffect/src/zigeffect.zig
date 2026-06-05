const std = @import("std");

pub const Allocator = std.mem.Allocator;

pub const ScopeError = error{MissingScope};
pub const FinalizerRegistrationError = Allocator.Error || ScopeError;
pub const DependencyError = error{
    MissingServiceRequirement,
    DuplicateServiceProvider,
};
pub const FiberId = u64;
pub const FiberStatus = enum {
    pending,
    running,
    done,
    failed,
    interrupted,
};
pub const FiberPrimitiveError = error{
    DeferredAlreadyCompleted,
    DeferredNotCompleted,
    QueueEmpty,
    QueueFull,
    SemaphoreUnavailable,
    SemaphoreOverRelease,
};

const ServiceSetBuilder = *const fn (Allocator) Allocator.Error!ServiceSet;

fn emptyServiceSet(allocator: Allocator) Allocator.Error!ServiceSet {
    return ServiceSet.init(allocator);
}

fn serviceSetBuilder(comptime services: anytype) ServiceSetBuilder {
    const Builder = struct {
        fn build(allocator: Allocator) Allocator.Error!ServiceSet {
            return ServiceSet.fromTypes(allocator, services);
        }
    };

    return Builder.build;
}

pub const ServiceSet = struct {
    allocator: Allocator,
    names: std.ArrayList([]const u8) = .empty,

    pub fn init(allocator: Allocator) ServiceSet {
        return .{ .allocator = allocator };
    }

    pub fn fromTypes(allocator: Allocator, comptime services: anytype) Allocator.Error!ServiceSet {
        var set = ServiceSet.init(allocator);
        errdefer set.deinit();

        inline for (services) |Service| {
            try set.add(Service);
        }

        return set;
    }

    pub fn deinit(self: *ServiceSet) void {
        self.names.deinit(self.allocator);
    }

    pub fn add(self: *ServiceSet, comptime Service: type) Allocator.Error!void {
        try self.addName(@typeName(Service));
    }

    pub fn addName(self: *ServiceSet, name: []const u8) Allocator.Error!void {
        if (self.contains(name)) return;
        try self.names.append(self.allocator, name);
    }

    pub fn contains(self: *const ServiceSet, name: []const u8) bool {
        for (self.names.items) |existing| {
            if (std.mem.eql(u8, existing, name)) return true;
        }
        return false;
    }

    pub fn mergeFrom(self: *ServiceSet, other: *const ServiceSet) Allocator.Error!void {
        for (other.names.items) |name| {
            try self.addName(name);
        }
    }
};

pub const DependencyIssueKind = enum {
    missing_requirement,
    duplicate_provider,
};

pub const DependencyIssue = struct {
    kind: DependencyIssueKind,
    owner: []const u8,
    service: []const u8,
    provider: ?[]const u8 = null,
};

pub const DependencyReport = struct {
    allocator: Allocator,
    issues: std.ArrayList(DependencyIssue) = .empty,

    pub fn init(allocator: Allocator) DependencyReport {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *DependencyReport) void {
        self.issues.deinit(self.allocator);
    }

    pub fn addMissing(self: *DependencyReport, owner: []const u8, service: []const u8) Allocator.Error!void {
        try self.issues.append(self.allocator, .{
            .kind = .missing_requirement,
            .owner = owner,
            .service = service,
        });
    }

    pub fn addDuplicate(
        self: *DependencyReport,
        owner: []const u8,
        service: []const u8,
        provider: []const u8,
    ) Allocator.Error!void {
        try self.issues.append(self.allocator, .{
            .kind = .duplicate_provider,
            .owner = owner,
            .service = service,
            .provider = provider,
        });
    }

    pub fn issueCount(self: *const DependencyReport) usize {
        return self.issues.items.len;
    }

    pub fn isValid(self: *const DependencyReport) bool {
        return self.issueCount() == 0;
    }

    pub fn hasMissing(self: *const DependencyReport, service: []const u8) bool {
        for (self.issues.items) |issue| {
            if (issue.kind == .missing_requirement and std.mem.eql(u8, issue.service, service)) return true;
        }
        return false;
    }

    pub fn hasDuplicate(self: *const DependencyReport, service: []const u8) bool {
        for (self.issues.items) |issue| {
            if (issue.kind == .duplicate_provider and std.mem.eql(u8, issue.service, service)) return true;
        }
        return false;
    }
};

pub fn formatDependencyReport(allocator: Allocator, label: []const u8, report: DependencyReport) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.print(
        allocator,
        "zigeffect dependency report\nprogram: {s}\nissues: {d}\n",
        .{ label, report.issueCount() },
    );

    if (report.isValid()) {
        try output.appendSlice(allocator, "status: valid\nhint: All declared service requirements are provided.");
        return output.toOwnedSlice(allocator);
    }

    for (report.issues.items) |issue| {
        switch (issue.kind) {
            .missing_requirement => try output.print(
                allocator,
                "issue: missing service requirement\nowner: {s}\nservice: {s}\nhint: Add a layer/runtime provider for this service or remove the requirement.\n",
                .{ issue.owner, issue.service },
            ),
            .duplicate_provider => try output.print(
                allocator,
                "issue: duplicate service provider\nowner: {s}\nservice: {s}\nprevious provider: {s}\nhint: Keep one provider for this service or split the graph boundary.\n",
                .{ issue.owner, issue.service, issue.provider orelse "unknown" },
            ),
        }
    }

    return output.toOwnedSlice(allocator);
}

fn effectRequiredServices(allocator: Allocator, effect: anytype) Allocator.Error!ServiceSet {
    const EffectType = @TypeOf(effect);
    if (@hasDecl(EffectType, "requiredServices")) {
        return EffectType.requiredServices(allocator);
    }
    return ServiceSet.init(allocator);
}

pub fn validateLayerRequirements(allocator: Allocator, layer: anytype, effect: anytype) Allocator.Error!DependencyReport {
    var provided = try layer.providedServices(allocator);
    defer provided.deinit();
    var required = try effectRequiredServices(allocator, effect);
    defer required.deinit();

    var report = DependencyReport.init(allocator);
    errdefer report.deinit();

    for (required.names.items) |service| {
        if (!provided.contains(service)) {
            try report.addMissing("effect", service);
        }
    }

    return report;
}

fn ensureLayerRequirements(allocator: Allocator, layer: anytype, effect: anytype) (Allocator.Error || DependencyError)!void {
    var report = try validateLayerRequirements(allocator, layer, effect);
    defer report.deinit();
    if (!report.isValid()) return error.MissingServiceRequirement;
}

pub fn Cause(comptime Failure: type) type {
    return union(enum) {
        const Self = @This();

        failure: Failure,
        defect: []const u8,
        interrupted: u64,
        finalizer_failure: []const u8,
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

pub fn Exit(comptime Success: type, comptime Failure: type) type {
    return union(enum) {
        success: Success,
        failure: Failure,
        defect: []const u8,
        interrupted: u64,
        cause: Cause(Failure),
    };
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

pub fn serviceNotFound(comptime Env: type, comptime Service: type) noreturn {
    @compileError(
        "zigeffect service not found\n\n" ++
            "requested service: " ++ @typeName(Service) ++ "\n" ++
            "environment: " ++ @typeName(Env) ++ "\n\n" ++
            "Add a branch to the environment service method:\n\n" ++
            "    pub fn service(self: *" ++ @typeName(Env) ++ ", comptime Requested: type) *Requested {\n" ++
            "        if (Requested == " ++ @typeName(Service) ++ ") return &self.<field>;\n" ++
            "        return fx.serviceNotFound(" ++ @typeName(Env) ++ ", Requested);\n" ++
            "    }\n\n" ++
            "This usually means the effect asks for a service that the layer/environment does not provide.",
    );
}

pub const Clock = struct {
    const Mode = enum {
        fake,
        system,
    };

    mode: Mode = .fake,
    current_ms: u64 = 0,

    pub fn fake(start_ms: u64) Clock {
        return .{ .mode = .fake, .current_ms = start_ms };
    }

    pub fn system() Clock {
        return .{ .mode = .system };
    }

    pub fn nowMs(self: *const Clock) u64 {
        return switch (self.mode) {
            .fake => self.current_ms,
            .system => {
                var tv: std.c.timeval = undefined;
                if (std.c.gettimeofday(&tv, null) != 0) return 0;
                return (@as(u64, @intCast(tv.sec)) * std.time.ms_per_s) + @as(u64, @intCast(@divTrunc(tv.usec, std.time.us_per_ms)));
            },
        };
    }

    pub fn sleep(self: *Clock, delay_ms: u64) void {
        switch (self.mode) {
            .fake => self.current_ms += delay_ms,
            .system => {
                const seconds = delay_ms / std.time.ms_per_s;
                const remaining_ms = delay_ms % std.time.ms_per_s;
                const ns = std.math.mul(u64, remaining_ms, std.time.ns_per_ms) catch std.math.maxInt(u64);
                var request = std.c.timespec{
                    .sec = @intCast(seconds),
                    .nsec = @intCast(ns),
                };
                while (std.c.nanosleep(&request, &request) != 0) {}
            },
        }
    }
};

pub const FakeClock = Clock;

pub fn Context(comptime Env: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        env: *Env,
        scope: ?*Scope = null,
        clock: ?*Clock = null,

        pub fn init(allocator: Allocator, env: *Env, scope: ?*Scope) Self {
            return .{
                .allocator = allocator,
                .env = env,
                .scope = scope,
            };
        }

        pub fn service(self: *Self, comptime Service: type) *Service {
            return self.env.service(Service);
        }

        pub fn addFinalizerFor(
            self: *Self,
            comptime Resource: type,
            resource: *Resource,
            comptime release: *const fn (*Resource) void,
        ) FinalizerRegistrationError!void {
            if (self.scope) |scope| {
                return scope.addFinalizerFor(Resource, resource, release);
            }
            return error.MissingScope;
        }

        pub fn addFinalizerFallibleFor(
            self: *Self,
            comptime Resource: type,
            resource: *Resource,
            comptime release: anytype,
        ) FinalizerRegistrationError!void {
            if (self.scope) |scope| {
                return scope.addFinalizerFallibleFor(Resource, resource, release);
            }
            return error.MissingScope;
        }

        pub fn addFinalizerExitFor(
            self: *Self,
            comptime Resource: type,
            resource: *Resource,
            comptime release: *const fn (*Resource, FinalizerExit) void,
        ) FinalizerRegistrationError!void {
            if (self.scope) |scope| {
                return scope.addFinalizerExitFor(Resource, resource, release);
            }
            return error.MissingScope;
        }

        pub fn addFinalizerExitFallibleFor(
            self: *Self,
            comptime Resource: type,
            resource: *Resource,
            comptime release: anytype,
        ) FinalizerRegistrationError!void {
            if (self.scope) |scope| {
                return scope.addFinalizerExitFallibleFor(Resource, resource, release);
            }
            return error.MissingScope;
        }
    };
}

pub fn Effect(comptime Success: type, comptime Failure: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Success;
        pub const FailureType = Failure;
        pub const EnvType = Env;

        const Mode = union(enum) {
            run_fn: *const fn (*Context(Env)) Failure!Success,
            succeed: Success,
            fail: Failure,
            sync_fn: *const fn () Success,
        };

        mode: Mode,

        pub fn fromFn(run_fn: *const fn (*Context(Env)) Failure!Success) Self {
            return .{ .mode = .{ .run_fn = run_fn } };
        }

        pub fn succeed(value: Success) Self {
            return .{ .mode = .{ .succeed = value } };
        }

        pub fn fail(err: Failure) Self {
            return .{ .mode = .{ .fail = err } };
        }

        pub fn sync(sync_fn: *const fn () Success) Self {
            return .{ .mode = .{ .sync_fn = sync_fn } };
        }

        pub fn run(self: Self, ctx: *Context(Env)) Failure!Success {
            return switch (self.mode) {
                .run_fn => |run_fn| run_fn(ctx),
                .succeed => |value| value,
                .fail => |err| err,
                .sync_fn => |sync_fn| sync_fn(),
            };
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Success, Failure) {
            const value = self.run(ctx) catch |err| return .{ .failure = err };
            return .{ .success = value };
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Success {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Success {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Success) Next,
        ) MapEffect(Self, Next, Failure, Env) {
            return .{
                .parent = self,
                .mapper = mapper,
            };
        }

        pub fn flatMap(
            self: Self,
            comptime Next: type,
            binder: *const fn (Success, *Context(Env)) Failure!Next,
        ) FlatMapEffect(Self, Next, Failure, Env) {
            return .{
                .parent = self,
                .binder = binder,
            };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Success, *Context(Env)) Failure!void,
        ) TapEffect(Self, Failure, Env) {
            return .{
                .parent = self,
                .action = action,
            };
        }

        pub fn mapError(
            self: Self,
            comptime NextFailure: type,
            mapper: *const fn (Failure) NextFailure,
        ) MapErrorEffect(Self, NextFailure, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn catchAll(
            self: Self,
            comptime NextFailure: type,
            handler: *const fn (Failure, *Context(Env)) NextFailure!Success,
        ) CatchAllEffect(Self, NextFailure, Env) {
            return .{ .parent = self, .handler = handler };
        }

        pub fn orElse(self: Self, fallback: anytype) OrElseEffect(Self, @TypeOf(fallback), Env) {
            return .{ .parent = self, .fallback = fallback };
        }

        pub fn tapError(
            self: Self,
            action: *const fn (Failure, *Context(Env)) Failure!void,
        ) TapErrorEffect(Self, Failure, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }

        pub fn requires(self: Self, comptime services: anytype) RequiredEffect(Self, services, Env) {
            return .{ .parent = self };
        }
    };
}

pub fn RequiredEffect(comptime Parent: type, comptime Services: anytype, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Parent.FailureType;
        pub const EnvType = Env;

        parent: Parent,

        pub fn requiredServices(allocator: Allocator) Allocator.Error!ServiceSet {
            return ServiceSet.fromTypes(allocator, Services);
        }

        pub fn run(self: Self, ctx: *Context(Env)) Parent.FailureType!Parent.SuccessType {
            return self.parent.run(ctx);
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Parent.SuccessType, Parent.FailureType) {
            return self.parent.exit(ctx);
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Parent.FailureType!Parent.SuccessType {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Parent.FailureType!Parent.SuccessType {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Parent.SuccessType) Next,
        ) MapEffect(Self, Next, Parent.FailureType, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn flatMap(
            self: Self,
            comptime Next: type,
            binder: *const fn (Parent.SuccessType, *Context(Env)) Parent.FailureType!Next,
        ) FlatMapEffect(Self, Next, Parent.FailureType, Env) {
            return .{ .parent = self, .binder = binder };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Parent.SuccessType, *Context(Env)) Parent.FailureType!void,
        ) TapEffect(Self, Parent.FailureType, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }

        pub fn requires(self: Self, comptime services: anytype) RequiredEffect(Self, services, Env) {
            return .{ .parent = self.parent };
        }
    };
}

pub fn OnExitEffect(comptime Parent: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Parent.FailureType;
        pub const EnvType = Env;

        parent: Parent,
        action: *const fn (Exit(Parent.SuccessType, Parent.FailureType), *Context(Env)) Parent.FailureType!void,

        pub fn run(self: Self, ctx: *Context(Env)) Parent.FailureType!Parent.SuccessType {
            const parent_exit = self.parent.exit(ctx);
            try self.action(parent_exit, ctx);
            return exitToResult(Parent.SuccessType, Parent.FailureType, parent_exit);
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Parent.SuccessType, Parent.FailureType) {
            const parent_exit = self.parent.exit(ctx);
            self.action(parent_exit, ctx) catch |err| return .{ .failure = err };
            return parent_exit;
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Parent.FailureType!Parent.SuccessType {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Parent.FailureType!Parent.SuccessType {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Parent.SuccessType) Next,
        ) MapEffect(Self, Next, Parent.FailureType, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn flatMap(
            self: Self,
            comptime Next: type,
            binder: *const fn (Parent.SuccessType, *Context(Env)) Parent.FailureType!Next,
        ) FlatMapEffect(Self, Next, Parent.FailureType, Env) {
            return .{ .parent = self, .binder = binder };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Parent.SuccessType, *Context(Env)) Parent.FailureType!void,
        ) TapEffect(Self, Parent.FailureType, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }
    };
}

pub fn EnsuringEffect(comptime Parent: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Parent.FailureType;
        pub const EnvType = Env;

        parent: Parent,
        finalizer: *const fn (*Context(Env)) Parent.FailureType!void,

        pub fn run(self: Self, ctx: *Context(Env)) Parent.FailureType!Parent.SuccessType {
            const parent_exit = self.parent.exit(ctx);
            try self.finalizer(ctx);
            return exitToResult(Parent.SuccessType, Parent.FailureType, parent_exit);
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Parent.SuccessType, Parent.FailureType) {
            const parent_exit = self.parent.exit(ctx);
            self.finalizer(ctx) catch |err| return .{ .cause = .{ .finalizer_failure = @errorName(err) } };
            return parent_exit;
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Parent.FailureType!Parent.SuccessType {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Parent.FailureType!Parent.SuccessType {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Parent.SuccessType) Next,
        ) MapEffect(Self, Next, Parent.FailureType, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn flatMap(
            self: Self,
            comptime Next: type,
            binder: *const fn (Parent.SuccessType, *Context(Env)) Parent.FailureType!Next,
        ) FlatMapEffect(Self, Next, Parent.FailureType, Env) {
            return .{ .parent = self, .binder = binder };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Parent.SuccessType, *Context(Env)) Parent.FailureType!void,
        ) TapEffect(Self, Parent.FailureType, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }
    };
}

pub fn MapEffect(
    comptime Parent: type,
    comptime Success: type,
    comptime Failure: type,
    comptime Env: type,
) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Success;
        pub const FailureType = Failure;
        pub const EnvType = Env;

        parent: Parent,
        mapper: *const fn (Parent.SuccessType) Success,

        pub fn run(self: Self, ctx: *Context(Env)) Failure!Success {
            return self.mapper(try self.parent.run(ctx));
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Success, Failure) {
            const value = self.run(ctx) catch |err| return .{ .failure = err };
            return .{ .success = value };
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Success {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Success {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Success) Next,
        ) MapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn flatMap(
            self: Self,
            comptime Next: type,
            binder: *const fn (Success, *Context(Env)) Failure!Next,
        ) FlatMapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .binder = binder };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Success, *Context(Env)) Failure!void,
        ) TapEffect(Self, Failure, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn mapError(
            self: Self,
            comptime NextFailure: type,
            mapper: *const fn (Failure) NextFailure,
        ) MapErrorEffect(Self, NextFailure, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn catchAll(
            self: Self,
            comptime NextFailure: type,
            handler: *const fn (Failure, *Context(Env)) NextFailure!Success,
        ) CatchAllEffect(Self, NextFailure, Env) {
            return .{ .parent = self, .handler = handler };
        }

        pub fn orElse(self: Self, fallback: anytype) OrElseEffect(Self, @TypeOf(fallback), Env) {
            return .{ .parent = self, .fallback = fallback };
        }

        pub fn tapError(
            self: Self,
            action: *const fn (Failure, *Context(Env)) Failure!void,
        ) TapErrorEffect(Self, Failure, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }
    };
}

pub fn FlatMapEffect(
    comptime Parent: type,
    comptime Success: type,
    comptime Failure: type,
    comptime Env: type,
) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Success;
        pub const FailureType = Failure;
        pub const EnvType = Env;

        parent: Parent,
        binder: *const fn (Parent.SuccessType, *Context(Env)) Failure!Success,

        pub fn run(self: Self, ctx: *Context(Env)) Failure!Success {
            return self.binder(try self.parent.run(ctx), ctx);
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Success, Failure) {
            const value = self.run(ctx) catch |err| return .{ .failure = err };
            return .{ .success = value };
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Success {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Success {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Success) Next,
        ) MapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn flatMap(
            self: Self,
            comptime Next: type,
            binder: *const fn (Success, *Context(Env)) Failure!Next,
        ) FlatMapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .binder = binder };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Success, *Context(Env)) Failure!void,
        ) TapEffect(Self, Failure, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn mapError(
            self: Self,
            comptime NextFailure: type,
            mapper: *const fn (Failure) NextFailure,
        ) MapErrorEffect(Self, NextFailure, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn catchAll(
            self: Self,
            comptime NextFailure: type,
            handler: *const fn (Failure, *Context(Env)) NextFailure!Success,
        ) CatchAllEffect(Self, NextFailure, Env) {
            return .{ .parent = self, .handler = handler };
        }

        pub fn orElse(self: Self, fallback: anytype) OrElseEffect(Self, @TypeOf(fallback), Env) {
            return .{ .parent = self, .fallback = fallback };
        }

        pub fn tapError(
            self: Self,
            action: *const fn (Failure, *Context(Env)) Failure!void,
        ) TapErrorEffect(Self, Failure, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }
    };
}

pub fn TapEffect(comptime Parent: type, comptime Failure: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Failure;
        pub const EnvType = Env;

        parent: Parent,
        action: *const fn (Parent.SuccessType, *Context(Env)) Failure!void,

        pub fn run(self: Self, ctx: *Context(Env)) Failure!Parent.SuccessType {
            const value = try self.parent.run(ctx);
            try self.action(value, ctx);
            return value;
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Parent.SuccessType, Failure) {
            const value = self.run(ctx) catch |err| return .{ .failure = err };
            return .{ .success = value };
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Parent.SuccessType {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Parent.SuccessType {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Parent.SuccessType) Next,
        ) MapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn flatMap(
            self: Self,
            comptime Next: type,
            binder: *const fn (Parent.SuccessType, *Context(Env)) Failure!Next,
        ) FlatMapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .binder = binder };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Parent.SuccessType, *Context(Env)) Failure!void,
        ) TapEffect(Self, Failure, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn mapError(
            self: Self,
            comptime NextFailure: type,
            mapper: *const fn (Failure) NextFailure,
        ) MapErrorEffect(Self, NextFailure, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn catchAll(
            self: Self,
            comptime NextFailure: type,
            handler: *const fn (Failure, *Context(Env)) NextFailure!Parent.SuccessType,
        ) CatchAllEffect(Self, NextFailure, Env) {
            return .{ .parent = self, .handler = handler };
        }

        pub fn orElse(self: Self, fallback: anytype) OrElseEffect(Self, @TypeOf(fallback), Env) {
            return .{ .parent = self, .fallback = fallback };
        }

        pub fn tapError(
            self: Self,
            action: *const fn (Failure, *Context(Env)) Failure!void,
        ) TapErrorEffect(Self, Failure, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }
    };
}

pub fn MapErrorEffect(comptime Parent: type, comptime Failure: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Failure;
        pub const EnvType = Env;

        parent: Parent,
        mapper: *const fn (Parent.FailureType) Failure,

        pub fn run(self: Self, ctx: *Context(Env)) Failure!Parent.SuccessType {
            return self.parent.run(ctx) catch |err| return self.mapper(err);
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Parent.SuccessType, Failure) {
            const value = self.run(ctx) catch |err| return .{ .failure = err };
            return .{ .success = value };
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Parent.SuccessType {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Parent.SuccessType {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Parent.SuccessType) Next,
        ) MapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn flatMap(
            self: Self,
            comptime Next: type,
            binder: *const fn (Parent.SuccessType, *Context(Env)) Failure!Next,
        ) FlatMapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .binder = binder };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Parent.SuccessType, *Context(Env)) Failure!void,
        ) TapEffect(Self, Failure, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }
    };
}

pub fn CatchAllEffect(comptime Parent: type, comptime Failure: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Failure;
        pub const EnvType = Env;

        parent: Parent,
        handler: *const fn (Parent.FailureType, *Context(Env)) Failure!Parent.SuccessType,

        pub fn run(self: Self, ctx: *Context(Env)) Failure!Parent.SuccessType {
            return self.parent.run(ctx) catch |err| self.handler(err, ctx);
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Parent.SuccessType, Failure) {
            const value = self.run(ctx) catch |err| return .{ .failure = err };
            return .{ .success = value };
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Parent.SuccessType {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Parent.SuccessType {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Parent.SuccessType) Next,
        ) MapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn flatMap(
            self: Self,
            comptime Next: type,
            binder: *const fn (Parent.SuccessType, *Context(Env)) Failure!Next,
        ) FlatMapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .binder = binder };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Parent.SuccessType, *Context(Env)) Failure!void,
        ) TapEffect(Self, Failure, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }
    };
}

pub fn OrElseEffect(comptime Parent: type, comptime Fallback: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Fallback.FailureType;
        pub const EnvType = Env;

        parent: Parent,
        fallback: Fallback,

        pub fn run(self: Self, ctx: *Context(Env)) Fallback.FailureType!Parent.SuccessType {
            return self.parent.run(ctx) catch {
                const value: Parent.SuccessType = try self.fallback.run(ctx);
                return value;
            };
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Parent.SuccessType, Fallback.FailureType) {
            const value = self.run(ctx) catch |err| return .{ .failure = err };
            return .{ .success = value };
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Fallback.FailureType!Parent.SuccessType {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Fallback.FailureType!Parent.SuccessType {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Parent.SuccessType) Next,
        ) MapEffect(Self, Next, Fallback.FailureType, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Parent.SuccessType, *Context(Env)) Fallback.FailureType!void,
        ) TapEffect(Self, Fallback.FailureType, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }
    };
}

pub fn TapErrorEffect(comptime Parent: type, comptime Failure: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Failure;
        pub const EnvType = Env;

        parent: Parent,
        action: *const fn (Parent.FailureType, *Context(Env)) Failure!void,

        pub fn run(self: Self, ctx: *Context(Env)) Failure!Parent.SuccessType {
            return self.parent.run(ctx) catch |err| {
                try self.action(err, ctx);
                return err;
            };
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Parent.SuccessType, Failure) {
            const value = self.run(ctx) catch |err| return .{ .failure = err };
            return .{ .success = value };
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Parent.SuccessType {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Parent.SuccessType {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Parent.SuccessType) Next,
        ) MapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Parent.SuccessType, *Context(Env)) Failure!void,
        ) TapEffect(Self, Failure, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }
    };
}

pub fn retryEffect(effect: anytype, ctx: *Context(@TypeOf(effect).EnvType), schedule: *Schedule) @TypeOf(effect).FailureType!@TypeOf(effect).SuccessType {
    var attempt: usize = 0;

    while (true) {
        return effect.run(ctx) catch |err| {
            if (schedule.nextDelay(attempt)) |delay_ms| {
                if (ctx.clock) |clock| {
                    clock.sleep(delay_ms);
                }
                attempt += 1;
                continue;
            }

            return err;
        };
    }
}

pub fn repeatEffect(effect: anytype, ctx: *Context(@TypeOf(effect).EnvType), schedule: *Schedule) @TypeOf(effect).FailureType!@TypeOf(effect).SuccessType {
    var repetition: usize = 0;
    var value = try effect.run(ctx);

    while (schedule.nextDelay(repetition)) |delay_ms| {
        if (ctx.clock) |clock| {
            clock.sleep(delay_ms);
        }
        repetition += 1;
        value = try effect.run(ctx);
    }

    return value;
}

pub fn acquireRelease(
    comptime Resource: type,
    comptime Failure: type,
    comptime Env: type,
    comptime acquire: *const fn (*Context(Env)) Failure!*Resource,
    comptime release: *const fn (*Resource) void,
) Effect(*Resource, Failure, Env) {
    const Runner = struct {
        fn run(ctx: *Context(Env)) Failure!*Resource {
            const resource = try acquire(ctx);
            ctx.addFinalizerFor(Resource, resource, release) catch |err| {
                release(resource);
                return err;
            };
            return resource;
        }
    };

    return Effect(*Resource, Failure, Env).fromFn(Runner.run);
}

pub fn Deferred(comptime Success: type, comptime Failure: type) type {
    return struct {
        const Self = @This();

        exit_value: ?Exit(Success, Failure) = null,

        pub fn init() Self {
            return .{};
        }

        pub fn isCompleted(self: *const Self) bool {
            return self.exit_value != null;
        }

        pub fn completeExit(self: *Self, exit: Exit(Success, Failure)) FiberPrimitiveError!void {
            if (self.isCompleted()) return error.DeferredAlreadyCompleted;
            self.exit_value = exit;
        }

        pub fn completeSuccess(self: *Self, value: Success) FiberPrimitiveError!void {
            try self.completeExit(.{ .success = value });
        }

        pub fn completeFailure(self: *Self, err: Failure) FiberPrimitiveError!void {
            try self.completeExit(.{ .failure = err });
        }

        pub fn awaitExit(self: *const Self) FiberPrimitiveError!Exit(Success, Failure) {
            return self.exit_value orelse error.DeferredNotCompleted;
        }
    };
}

pub fn Queue(comptime Item: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        items: std.ArrayList(Item) = .empty,
        capacity: ?usize = null,

        pub fn init(allocator: Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn bounded(allocator: Allocator, capacity: usize) Self {
            return .{
                .allocator = allocator,
                .capacity = capacity,
            };
        }

        pub fn deinit(self: *Self) void {
            self.items.deinit(self.allocator);
        }

        pub fn len(self: *const Self) usize {
            return self.items.items.len;
        }

        pub fn offer(self: *Self, item: Item) (Allocator.Error || FiberPrimitiveError)!void {
            if (self.capacity) |capacity| {
                if (self.items.items.len >= capacity) return error.QueueFull;
            }
            try self.items.append(self.allocator, item);
        }

        pub fn take(self: *Self) FiberPrimitiveError!Item {
            if (self.items.items.len == 0) return error.QueueEmpty;
            return self.items.orderedRemove(0);
        }
    };
}

pub const Semaphore = struct {
    permits: usize,
    max_permits: usize,

    pub fn init(permits: usize) Semaphore {
        return .{
            .permits = permits,
            .max_permits = permits,
        };
    }

    pub fn available(self: *const Semaphore) usize {
        return self.permits;
    }

    pub fn acquire(self: *Semaphore, permits: usize) FiberPrimitiveError!void {
        if (permits > self.permits) return error.SemaphoreUnavailable;
        self.permits -= permits;
    }

    pub fn release(self: *Semaphore, permits: usize) FiberPrimitiveError!void {
        if (permits > self.max_permits - self.permits) return error.SemaphoreOverRelease;
        self.permits += permits;
    }
};

const FiberRecord = struct {
    state: ?*anyopaque,
    deinit: *const fn (?*anyopaque) void,
};

fn FiberState(comptime Success: type, comptime Failure: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        const RunTask = *const fn (*Self, *Context(Env)) void;
        const DeinitTask = *const fn (?*anyopaque) void;

        allocator: Allocator,
        id: FiberId,
        scope: Scope,
        status_value: FiberStatus = .pending,
        exit_value: ?Exit(Success, Failure) = null,
        task: ?*anyopaque = null,
        run_task: ?RunTask = null,
        deinit_task: ?DeinitTask = null,

        pub fn init(
            allocator: Allocator,
            id: FiberId,
            task: ?*anyopaque,
            run_task: RunTask,
            deinit_task: DeinitTask,
        ) Self {
            return .{
                .allocator = allocator,
                .id = id,
                .scope = Scope.init(allocator),
                .task = task,
                .run_task = run_task,
                .deinit_task = deinit_task,
            };
        }

        pub fn deinit(self: *Self) void {
            if (self.task) |task| {
                self.deinit_task.?(task);
                self.task = null;
            }
            self.scope.deinit();
        }

        pub fn status(self: *const Self) FiberStatus {
            return self.status_value;
        }

        fn isComplete(self: *const Self) bool {
            return self.exit_value != null;
        }

        fn completeSuccess(self: *Self, value: Success) void {
            if (self.isComplete()) return;
            self.exit_value = .{ .success = value };
            self.status_value = .done;
        }

        fn completeFailure(self: *Self, err: Failure) void {
            if (self.isComplete()) return;
            self.exit_value = .{ .failure = err };
            self.status_value = .failed;
        }

        fn closeChildScope(self: *Self) void {
            const child_exit = self.exit_value orelse return;
            self.scope.closeWithExit(finalizerExitFromExit(child_exit));
            if (self.scope.firstFinalizerFailure()) |failure| {
                self.exit_value = .{ .cause = .{ .finalizer_failure = failure } };
                self.status_value = .failed;
            }
        }

        pub fn run(self: *Self, ctx: *Context(Env)) void {
            if (self.status_value != .pending) return;
            self.status_value = .running;
            self.run_task.?(self, ctx);
            if (self.exit_value == null) {
                self.exit_value = .{ .defect = "fiber task completed without an exit" };
                self.status_value = .failed;
            }
            self.closeChildScope();
        }

        pub fn interrupt(self: *Self) void {
            if (self.isComplete()) return;
            self.exit_value = .{ .interrupted = self.id };
            self.status_value = .interrupted;
            self.scope.closeWithExit(.{ .interrupted = self.id });
        }

        pub fn join(self: *Self, runtime: *FiberRuntime(Env)) Exit(Success, Failure) {
            if (self.status_value == .pending) {
                var ctx = runtime.context(&self.scope);
                self.run(&ctx);
            }
            return self.exit_value orelse .{ .defect = "fiber has no exit" };
        }
    };
}

pub fn Fiber(comptime Success: type, comptime Failure: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Success;
        pub const FailureType = Failure;
        pub const EnvType = Env;

        id: FiberId,
        state: *FiberState(Success, Failure, Env),
        runtime: *FiberRuntime(Env),

        pub fn status(self: Self) FiberStatus {
            return self.state.status();
        }

        pub fn joinExit(self: Self) Exit(Success, Failure) {
            return self.runtime.join(self);
        }

        pub fn interrupt(self: Self) void {
            self.runtime.interrupt(self);
        }
    };
}

pub fn FiberRuntime(comptime Env: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        env: *Env,
        clock: ?*Clock = null,
        provided_builder: ServiceSetBuilder = emptyServiceSet,
        next_fiber_id: FiberId = 1,
        fibers: std.ArrayList(FiberRecord) = .empty,

        pub fn init(allocator: Allocator, env: *Env) Self {
            return .{
                .allocator = allocator,
                .env = env,
            };
        }

        pub fn deinit(self: *Self) void {
            for (self.fibers.items) |record| {
                record.deinit(record.state);
            }
            self.fibers.deinit(self.allocator);
        }

        pub fn withClock(self: Self, clock: *Clock) Self {
            var runtime = self;
            runtime.clock = clock;
            return runtime;
        }

        pub fn provides(self: Self, comptime services: anytype) Self {
            var runtime = self;
            runtime.provided_builder = serviceSetBuilder(services);
            return runtime;
        }

        pub fn providedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            return self.provided_builder(allocator);
        }

        pub fn context(self: *Self, scope: *Scope) Context(Env) {
            var ctx = Context(Env).init(self.allocator, self.env, scope);
            ctx.clock = self.clock;
            return ctx;
        }

        pub fn fork(
            self: *Self,
            effect: anytype,
        ) (Allocator.Error || DependencyError)!Fiber(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType, Env) {
            try ensureLayerRequirements(self.allocator, self.*, effect);

            const EffectType = @TypeOf(effect);
            const State = FiberState(EffectType.SuccessType, EffectType.FailureType, Env);
            const Task = struct {
                allocator: Allocator,
                effect: EffectType,
            };
            const Runner = struct {
                fn run(state: *State, ctx: *Context(Env)) void {
                    const task: *Task = @ptrCast(@alignCast(state.task.?));
                    const value = task.effect.run(ctx) catch |err| {
                        state.completeFailure(err);
                        return;
                    };
                    state.completeSuccess(value);
                }

                fn deinit(raw: ?*anyopaque) void {
                    const task: *Task = @ptrCast(@alignCast(raw.?));
                    task.allocator.destroy(task);
                }
            };
            const StateRecord = struct {
                fn deinit(raw: ?*anyopaque) void {
                    const state: *State = @ptrCast(@alignCast(raw.?));
                    const allocator = state.allocator;
                    state.deinit();
                    allocator.destroy(state);
                }
            };

            const task = try self.allocator.create(Task);
            errdefer self.allocator.destroy(task);
            task.* = .{
                .allocator = self.allocator,
                .effect = effect,
            };

            const state = try self.allocator.create(State);
            errdefer self.allocator.destroy(state);
            state.* = State.init(self.allocator, self.next_fiber_id, task, Runner.run, Runner.deinit);
            errdefer state.deinit();

            try self.fibers.append(self.allocator, .{
                .state = state,
                .deinit = StateRecord.deinit,
            });

            const fiber = Fiber(EffectType.SuccessType, EffectType.FailureType, Env){
                .id = self.next_fiber_id,
                .state = state,
                .runtime = self,
            };
            self.next_fiber_id += 1;
            return fiber;
        }

        pub fn forkScoped(
            self: *Self,
            ctx: *Context(Env),
            effect: anytype,
        ) (Allocator.Error || DependencyError || ScopeError)!Fiber(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType, Env) {
            const parent_scope = ctx.scope orelse return error.MissingScope;
            const fiber = try self.fork(effect);
            const State = FiberState(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType, Env);
            const LeaseFinalizer = struct {
                fn interrupt(raw: ?*anyopaque, exit: FinalizerExit) void {
                    _ = exit;
                    const state: *State = @ptrCast(@alignCast(raw.?));
                    state.interrupt();
                }
            };

            parent_scope.addFinalizerExit(fiber.state, LeaseFinalizer.interrupt) catch |err| {
                self.interrupt(fiber);
                return err;
            };
            return fiber;
        }

        pub fn join(
            self: *Self,
            fiber: anytype,
        ) Exit(@TypeOf(fiber).SuccessType, @TypeOf(fiber).FailureType) {
            return fiber.state.join(self);
        }

        pub fn interrupt(self: *Self, fiber: anytype) void {
            _ = self;
            fiber.state.interrupt();
        }
    };
}

pub fn Runtime(comptime Env: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        env: *Env,
        clock: ?*Clock = null,
        provided_builder: ServiceSetBuilder = emptyServiceSet,

        pub fn init(allocator: Allocator, env: *Env) Self {
            return .{
                .allocator = allocator,
                .env = env,
            };
        }

        pub fn withClock(self: Self, clock: *Clock) Self {
            var runtime = self;
            runtime.clock = clock;
            return runtime;
        }

        pub fn provides(self: Self, comptime services: anytype) Self {
            var runtime = self;
            runtime.provided_builder = serviceSetBuilder(services);
            return runtime;
        }

        pub fn providedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            return self.provided_builder(allocator);
        }

        pub fn context(self: *Self, scope: *Scope) Context(Env) {
            var ctx = Context(Env).init(self.allocator, self.env, scope);
            ctx.clock = self.clock;
            return ctx;
        }

        pub fn run(self: *Self, effect: anytype) (Allocator.Error || DependencyError || @TypeOf(effect).FailureType)!@TypeOf(effect).SuccessType {
            try ensureLayerRequirements(self.allocator, self.*, effect);

            var scope = Scope.init(self.allocator);
            defer scope.deinit();

            var ctx = self.context(&scope);
            const value = effect.run(&ctx) catch |err| {
                scope.closeWithExit(.{ .failure = @errorName(err) });
                return err;
            };
            scope.closeWithExit(.success);
            return value;
        }

        pub fn exit(self: *Self, effect: anytype) Exit(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType) {
            var scope = Scope.init(self.allocator);
            defer scope.deinit();

            var report = validateLayerRequirements(self.allocator, self.*, effect) catch
                return .{ .defect = "dependency validation allocation failed" };
            defer report.deinit();
            if (!report.isValid()) return .{ .defect = "missing service requirements" };

            var ctx = self.context(&scope);
            const base_exit = effect.exit(&ctx);
            scope.closeWithExit(finalizerExitFromExit(base_exit));

            if (scope.firstFinalizerFailure()) |failure| {
                return .{ .cause = .{ .finalizer_failure = failure } };
            }

            return base_exit;
        }
    };
}

pub fn Layer(comptime Env: type) type {
    return LayerWithError(Env, error{});
}

pub fn LayerWithError(comptime Env: type, comptime StartupError: type) type {
    return struct {
        const Self = @This();
        pub const EnvType = Env;
        pub const StartupErrorType = StartupError;
        const BuildError = Allocator.Error || StartupError;
        const BuildFn = *const fn (Allocator, *Scope) BuildError!*Env;

        env: ?*Env = null,
        builder: ?BuildFn = null,
        provided_builder: ServiceSetBuilder = emptyServiceSet,
        required_builder: ServiceSetBuilder = emptyServiceSet,

        pub fn fromEnv(env: *Env) Self {
            return .{ .env = env };
        }

        pub fn fromBuilder(builder: BuildFn) Self {
            return .{ .builder = builder };
        }

        pub fn provides(self: Self, comptime services: anytype) ProvidedLayer(Self, services) {
            return .{ .inner = self };
        }

        pub fn requires(self: Self, comptime services: anytype) RequiredLayer(Self, services) {
            return .{ .inner = self };
        }

        pub fn providedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            return self.provided_builder(allocator);
        }

        pub fn requiredServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            return self.required_builder(allocator);
        }

        pub fn build(self: Self, allocator: Allocator, scope: *Scope) BuildError!*Env {
            if (self.env) |env| return env;
            if (self.builder) |builder| return builder(allocator, scope);
            unreachable;
        }

        pub fn context(self: Self, allocator: Allocator, scope: ?*Scope) Context(Env) {
            return Context(Env).init(allocator, self.env orelse @panic("zigeffect Layer.context requires Layer.fromEnv; use buildContext for builder layers"), scope);
        }

        pub fn buildContext(self: Self, allocator: Allocator, scope: *Scope) BuildError!Context(Env) {
            return Context(Env).init(allocator, try self.build(allocator, scope), scope);
        }

        pub fn provide(
            self: Self,
            allocator: Allocator,
            effect: anytype,
        ) (BuildError || DependencyError || @TypeOf(effect).FailureType)!@TypeOf(effect).SuccessType {
            try ensureLayerRequirements(allocator, self, effect);

            var scope = Scope.init(allocator);
            defer scope.deinit();

            var ctx = try self.buildContext(allocator, &scope);
            const value = effect.run(&ctx) catch |err| {
                scope.closeWithExit(.{ .failure = @errorName(err) });
                return err;
            };
            scope.closeWithExit(.success);
            return value;
        }

        pub fn merge(
            self: Self,
            comptime OtherEnv: type,
            comptime CombinedEnv: type,
            other: Layer(OtherEnv),
            combine: *const fn (Allocator, *Scope, *Env, *OtherEnv) Allocator.Error!*CombinedEnv,
        ) MergeLayer(Self, Layer(OtherEnv), CombinedEnv) {
            return .{
                .left = self,
                .right = other,
                .combine = combine,
            };
        }
    };
}

pub fn ProvidedLayer(comptime Inner: type, comptime Provided: anytype) type {
    return struct {
        const Self = @This();
        pub const EnvType = Inner.EnvType;
        pub const StartupErrorType = Inner.StartupErrorType;
        pub const ProvidedServices = Provided;
        const BuildError = Allocator.Error || StartupErrorType;

        inner: Inner,

        pub fn provides(self: Self, comptime services: anytype) ProvidedLayer(Inner, services) {
            return .{ .inner = self.inner };
        }

        pub fn requires(self: Self, comptime services: anytype) ProvidedLayer(RequiredLayer(Inner, services), Provided) {
            return .{ .inner = self.inner.requires(services) };
        }

        pub fn providedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            _ = self;
            return ServiceSet.fromTypes(allocator, Provided);
        }

        pub fn requiredServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            return self.inner.requiredServices(allocator);
        }

        pub fn build(self: Self, allocator: Allocator, scope: *Scope) BuildError!*EnvType {
            return self.inner.build(allocator, scope);
        }

        pub fn context(self: Self, allocator: Allocator, scope: ?*Scope) Context(EnvType) {
            return self.inner.context(allocator, scope);
        }

        pub fn buildContext(self: Self, allocator: Allocator, scope: *Scope) BuildError!Context(EnvType) {
            return Context(EnvType).init(allocator, try self.build(allocator, scope), scope);
        }

        pub fn provide(
            self: Self,
            allocator: Allocator,
            effect: anytype,
        ) (BuildError || DependencyError || @TypeOf(effect).FailureType)!@TypeOf(effect).SuccessType {
            try ensureLayerRequirements(allocator, self, effect);

            var scope = Scope.init(allocator);
            defer scope.deinit();

            var ctx = try self.buildContext(allocator, &scope);
            const value = effect.run(&ctx) catch |err| {
                scope.closeWithExit(.{ .failure = @errorName(err) });
                return err;
            };
            scope.closeWithExit(.success);
            return value;
        }

        pub fn merge(
            self: Self,
            comptime OtherEnv: type,
            comptime CombinedEnv: type,
            other: anytype,
            combine: *const fn (Allocator, *Scope, *EnvType, *OtherEnv) Allocator.Error!*CombinedEnv,
        ) MergeLayer(Self, @TypeOf(other), CombinedEnv) {
            return .{
                .left = self,
                .right = other,
                .combine = combine,
            };
        }
    };
}

pub fn RequiredLayer(comptime Inner: type, comptime Required: anytype) type {
    return struct {
        const Self = @This();
        pub const EnvType = Inner.EnvType;
        pub const StartupErrorType = Inner.StartupErrorType;
        pub const RequiredServices = Required;
        const BuildError = Allocator.Error || StartupErrorType;

        inner: Inner,

        pub fn provides(self: Self, comptime services: anytype) ProvidedLayer(Self, services) {
            return .{ .inner = self };
        }

        pub fn requires(self: Self, comptime services: anytype) RequiredLayer(Inner, services) {
            return .{ .inner = self.inner };
        }

        pub fn providedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            return self.inner.providedServices(allocator);
        }

        pub fn requiredServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            _ = self;
            return ServiceSet.fromTypes(allocator, Required);
        }

        pub fn build(self: Self, allocator: Allocator, scope: *Scope) BuildError!*EnvType {
            return self.inner.build(allocator, scope);
        }

        pub fn context(self: Self, allocator: Allocator, scope: ?*Scope) Context(EnvType) {
            return self.inner.context(allocator, scope);
        }

        pub fn buildContext(self: Self, allocator: Allocator, scope: *Scope) BuildError!Context(EnvType) {
            return Context(EnvType).init(allocator, try self.build(allocator, scope), scope);
        }

        pub fn provide(
            self: Self,
            allocator: Allocator,
            effect: anytype,
        ) (BuildError || DependencyError || @TypeOf(effect).FailureType)!@TypeOf(effect).SuccessType {
            try ensureLayerRequirements(allocator, self, effect);

            var scope = Scope.init(allocator);
            defer scope.deinit();

            var ctx = try self.buildContext(allocator, &scope);
            const value = effect.run(&ctx) catch |err| {
                scope.closeWithExit(.{ .failure = @errorName(err) });
                return err;
            };
            scope.closeWithExit(.success);
            return value;
        }

        pub fn merge(
            self: Self,
            comptime OtherEnv: type,
            comptime CombinedEnv: type,
            other: anytype,
            combine: *const fn (Allocator, *Scope, *EnvType, *OtherEnv) Allocator.Error!*CombinedEnv,
        ) MergeLayer(Self, @TypeOf(other), CombinedEnv) {
            return .{
                .left = self,
                .right = other,
                .combine = combine,
            };
        }
    };
}

pub fn MergeLayer(comptime LeftLayer: type, comptime RightLayer: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const EnvType = Env;
        pub const StartupErrorType = LeftLayer.StartupErrorType || RightLayer.StartupErrorType;
        const BuildError = Allocator.Error || StartupErrorType;

        left: LeftLayer,
        right: RightLayer,
        combine: *const fn (Allocator, *Scope, *LeftLayer.EnvType, *RightLayer.EnvType) Allocator.Error!*Env,

        pub fn providedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            var provided = ServiceSet.init(allocator);
            errdefer provided.deinit();

            var left = try self.left.providedServices(allocator);
            defer left.deinit();
            var right = try self.right.providedServices(allocator);
            defer right.deinit();
            try provided.mergeFrom(&left);
            try provided.mergeFrom(&right);
            return provided;
        }

        pub fn requiredServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            var required = ServiceSet.init(allocator);
            errdefer required.deinit();

            var left = try self.left.requiredServices(allocator);
            defer left.deinit();
            var right = try self.right.requiredServices(allocator);
            defer right.deinit();
            try required.mergeFrom(&left);
            try required.mergeFrom(&right);
            return required;
        }

        pub fn build(self: Self, allocator: Allocator, scope: *Scope) BuildError!*Env {
            const left_env = try self.left.build(allocator, scope);
            const right_env = try self.right.build(allocator, scope);
            return self.combine(allocator, scope, left_env, right_env);
        }

        pub fn buildContext(self: Self, allocator: Allocator, scope: *Scope) BuildError!Context(Env) {
            return Context(Env).init(allocator, try self.build(allocator, scope), scope);
        }

        pub fn provide(
            self: Self,
            allocator: Allocator,
            effect: anytype,
        ) (BuildError || DependencyError || @TypeOf(effect).FailureType)!@TypeOf(effect).SuccessType {
            try ensureLayerRequirements(allocator, self, effect);

            var scope = Scope.init(allocator);
            defer scope.deinit();

            var ctx = try self.buildContext(allocator, &scope);
            const value = effect.run(&ctx) catch |err| {
                scope.closeWithExit(.{ .failure = @errorName(err) });
                return err;
            };
            scope.closeWithExit(.success);
            return value;
        }
    };
}

pub const LayerGraph = struct {
    const Node = struct {
        name: []const u8,
        provides: ServiceSet,
        requires: ServiceSet,
    };

    allocator: Allocator,
    nodes: std.ArrayList(Node) = .empty,

    pub fn init(allocator: Allocator) LayerGraph {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *LayerGraph) void {
        for (self.nodes.items) |*node| {
            node.provides.deinit();
            node.requires.deinit();
        }
        self.nodes.deinit(self.allocator);
    }

    pub fn addLayer(self: *LayerGraph, name: []const u8, layer: anytype) Allocator.Error!void {
        var provides = try layer.providedServices(self.allocator);
        errdefer provides.deinit();
        var requires = try layer.requiredServices(self.allocator);
        errdefer requires.deinit();

        try self.nodes.append(self.allocator, .{
            .name = name,
            .provides = provides,
            .requires = requires,
        });
    }

    pub fn validate(self: *const LayerGraph, allocator: Allocator) Allocator.Error!DependencyReport {
        var report = DependencyReport.init(allocator);
        errdefer report.deinit();

        var provided = ServiceSet.init(allocator);
        defer provided.deinit();
        var owners = std.StringHashMap([]const u8).init(allocator);
        defer owners.deinit();

        for (self.nodes.items) |node| {
            for (node.provides.names.items) |service| {
                if (provided.contains(service)) {
                    try report.addDuplicate(node.name, service, owners.get(service) orelse "unknown");
                } else {
                    try provided.addName(service);
                    try owners.put(service, node.name);
                }
            }
        }

        for (self.nodes.items) |node| {
            for (node.requires.names.items) |service| {
                if (!provided.contains(service)) {
                    try report.addMissing(node.name, service);
                }
            }
        }

        return report;
    }
};

fn tupleFieldCount(comptime Tuple: type) usize {
    return std.meta.fields(Tuple).len;
}

fn layerEnvPointerTupleType(comptime Layers: type) type {
    const fields = std.meta.fields(Layers);
    comptime var types: [fields.len]type = undefined;
    inline for (fields, 0..) |field, index| {
        types[index] = *field.type.EnvType;
    }
    return std.meta.Tuple(&types);
}

fn layerGraphStartupErrorType(comptime Layers: type) type {
    const fields = std.meta.fields(Layers);
    comptime var StartupError = error{};
    inline for (fields) |field| {
        StartupError = StartupError || field.type.StartupErrorType;
    }
    return StartupError;
}

fn serviceTupleContains(comptime services: anytype, comptime Service: type) bool {
    inline for (services) |Declared| {
        if (Declared == Service) return true;
    }
    return false;
}

fn layerProvidesService(comptime LayerType: type, comptime Service: type) bool {
    if (!@hasDecl(LayerType, "ProvidedServices")) return false;
    return serviceTupleContains(LayerType.ProvidedServices, Service);
}

fn layerGraphNodeName(comptime LayerType: type) []const u8 {
    if (@hasDecl(LayerType, "Name")) return LayerType.Name;
    return @typeName(LayerType.EnvType);
}

fn graphDependencyError(report: *const DependencyReport) ?DependencyError {
    for (report.issues.items) |issue| {
        if (issue.kind == .duplicate_provider) return error.DuplicateServiceProvider;
    }
    for (report.issues.items) |issue| {
        if (issue.kind == .missing_requirement) return error.MissingServiceRequirement;
    }
    return null;
}

fn layerRequirementsSatisfied(allocator: Allocator, layer: anytype, provided: *const ServiceSet) Allocator.Error!bool {
    var required = try layer.requiredServices(allocator);
    defer required.deinit();

    for (required.names.items) |service| {
        if (!provided.contains(service)) return false;
    }
    return true;
}

pub fn LayerGraphEnv(comptime Layers: type) type {
    return struct {
        const Self = @This();
        pub const LayerTupleType = Layers;
        pub const EnvPointersType = layerEnvPointerTupleType(Layers);

        envs: EnvPointersType,

        pub fn service(self: *Self, comptime Service: type) *Service {
            inline for (std.meta.fields(Layers)) |field| {
                if (comptime layerProvidesService(field.type, Service)) {
                    return @field(self.envs, field.name).service(Service);
                }
            }
            return serviceNotFound(Self, Service);
        }
    };
}

pub fn LayerGraphRuntime(comptime Layers: type) type {
    return struct {
        const Self = @This();
        const LayerFields = std.meta.fields(Layers);
        pub const EnvType = LayerGraphEnv(Layers);
        pub const StartupErrorType = layerGraphStartupErrorType(Layers);
        pub const StartError = Allocator.Error || DependencyError || StartupErrorType;

        allocator: Allocator,
        layers: Layers,
        startup_scope: Scope,
        env: EnvType = undefined,
        started: bool = false,

        pub fn init(allocator: Allocator, layers: Layers) Self {
            return .{
                .allocator = allocator,
                .layers = layers,
                .startup_scope = Scope.init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.startup_scope.deinit();
            self.started = false;
        }

        pub fn providedServices(self: *const Self, allocator: Allocator) Allocator.Error!ServiceSet {
            var provided = ServiceSet.init(allocator);
            errdefer provided.deinit();

            inline for (LayerFields) |field| {
                var layer_provided = try @field(self.layers, field.name).providedServices(allocator);
                defer layer_provided.deinit();
                try provided.mergeFrom(&layer_provided);
            }

            return provided;
        }

        pub fn requiredServices(self: *const Self, allocator: Allocator) Allocator.Error!ServiceSet {
            var required = ServiceSet.init(allocator);
            errdefer required.deinit();

            inline for (LayerFields) |field| {
                var layer_required = try @field(self.layers, field.name).requiredServices(allocator);
                defer layer_required.deinit();
                try required.mergeFrom(&layer_required);
            }

            return required;
        }

        pub fn validate(self: *const Self, allocator: Allocator) Allocator.Error!DependencyReport {
            var graph = LayerGraph.init(allocator);
            defer graph.deinit();

            inline for (LayerFields) |field| {
                try graph.addLayer(layerGraphNodeName(field.type), @field(self.layers, field.name));
            }

            return graph.validate(allocator);
        }

        fn ensureValid(self: *const Self) (Allocator.Error || DependencyError)!void {
            var report = try self.validate(self.allocator);
            defer report.deinit();

            if (graphDependencyError(&report)) |err| return err;
        }

        fn buildEnvs(self: *Self) StartError!EnvType.EnvPointersType {
            var envs: EnvType.EnvPointersType = undefined;
            var built = [_]bool{false} ** tupleFieldCount(Layers);
            var provided = ServiceSet.init(self.allocator);
            defer provided.deinit();

            var remaining = tupleFieldCount(Layers);
            while (remaining > 0) {
                var progressed = false;

                inline for (LayerFields, 0..) |field, index| {
                    if (!built[index]) {
                        const layer = @field(self.layers, field.name);
                        const ready = try layerRequirementsSatisfied(self.allocator, layer, &provided);
                        if (ready) {
                            @field(envs, field.name) = try layer.build(self.allocator, &self.startup_scope);

                            var layer_provided = try layer.providedServices(self.allocator);
                            defer layer_provided.deinit();
                            try provided.mergeFrom(&layer_provided);

                            built[index] = true;
                            remaining -= 1;
                            progressed = true;
                        }
                    }
                }

                if (!progressed) return error.MissingServiceRequirement;
            }

            return envs;
        }

        pub fn start(self: *Self) StartError!*EnvType {
            if (self.started) return &self.env;

            try self.ensureValid();
            const envs = self.buildEnvs() catch |err| {
                self.startup_scope.closeWithExit(.{ .failure = @errorName(err) });
                self.startup_scope.deinit();
                self.startup_scope = Scope.init(self.allocator);
                return err;
            };

            self.env = .{ .envs = envs };
            self.started = true;
            return &self.env;
        }

        pub fn context(self: *Self, scope: *Scope) StartError!Context(EnvType) {
            const env = try self.start();
            return Context(EnvType).init(self.allocator, env, scope);
        }

        pub fn run(
            self: *Self,
            effect: anytype,
        ) (StartError || @TypeOf(effect).FailureType)!@TypeOf(effect).SuccessType {
            try ensureLayerRequirements(self.allocator, self, effect);

            var scope = Scope.init(self.allocator);
            defer scope.deinit();

            var ctx = try self.context(&scope);
            const value = effect.run(&ctx) catch |err| {
                scope.closeWithExit(.{ .failure = @errorName(err) });
                return err;
            };
            scope.closeWithExit(.success);
            return value;
        }

        pub fn exit(self: *Self, effect: anytype) Exit(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType) {
            var report = validateLayerRequirements(self.allocator, self, effect) catch
                return .{ .defect = "dependency validation allocation failed" };
            defer report.deinit();
            if (!report.isValid()) return .{ .defect = "missing service requirements" };

            var scope = Scope.init(self.allocator);
            defer scope.deinit();

            var ctx = self.context(&scope) catch |err|
                return .{ .defect = @errorName(err) };
            const base_exit = effect.exit(&ctx);
            scope.closeWithExit(finalizerExitFromExit(base_exit));

            if (scope.firstFinalizerFailure()) |failure| {
                return .{ .cause = .{ .finalizer_failure = failure } };
            }

            return base_exit;
        }
    };
}

pub fn layerGraph(allocator: Allocator, layers: anytype) LayerGraphRuntime(@TypeOf(layers)) {
    return LayerGraphRuntime(@TypeOf(layers)).init(allocator, layers);
}

pub const Scope = struct {
    const Finalizer = struct {
        state: ?*anyopaque,
        run: *const fn (?*anyopaque, FinalizerExit) ?[]const u8,
    };

    allocator: Allocator,
    finalizers: std.ArrayList(Finalizer) = .empty,
    finalizer_failures: std.ArrayList([]const u8) = .empty,
    closed: bool = false,

    pub fn init(allocator: Allocator) Scope {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Scope) void {
        if (!self.closed) self.close();
        self.finalizer_failures.deinit(self.allocator);
        self.finalizers.deinit(self.allocator);
    }

    pub fn addFinalizer(
        self: *Scope,
        state: ?*anyopaque,
        comptime run: *const fn (?*anyopaque) void,
    ) Allocator.Error!void {
        const Runner = struct {
            fn runNoFailure(raw: ?*anyopaque, exit: FinalizerExit) ?[]const u8 {
                _ = exit;
                run(raw);
                return null;
            }
        };

        try self.finalizers.append(self.allocator, .{
            .state = state,
            .run = Runner.runNoFailure,
        });
    }

    pub fn addFinalizerFallible(
        self: *Scope,
        state: ?*anyopaque,
        comptime run: anytype,
    ) Allocator.Error!void {
        const Runner = struct {
            fn runFallible(raw: ?*anyopaque, exit: FinalizerExit) ?[]const u8 {
                _ = exit;
                run(raw) catch |err| return @errorName(err);
                return null;
            }
        };

        try self.finalizers.append(self.allocator, .{
            .state = state,
            .run = Runner.runFallible,
        });
    }

    pub fn addFinalizerFor(
        self: *Scope,
        comptime Resource: type,
        resource: *Resource,
        comptime release: *const fn (*Resource) void,
    ) Allocator.Error!void {
        const Runner = struct {
            fn run(raw: ?*anyopaque, exit: FinalizerExit) ?[]const u8 {
                _ = exit;
                const typed: *Resource = @ptrCast(@alignCast(raw.?));
                release(typed);
                return null;
            }
        };

        try self.finalizers.append(self.allocator, .{
            .state = resource,
            .run = Runner.run,
        });
    }

    pub fn addFinalizerFallibleFor(
        self: *Scope,
        comptime Resource: type,
        resource: *Resource,
        comptime release: anytype,
    ) Allocator.Error!void {
        const Runner = struct {
            fn run(raw: ?*anyopaque, exit: FinalizerExit) ?[]const u8 {
                _ = exit;
                const typed: *Resource = @ptrCast(@alignCast(raw.?));
                release(typed) catch |err| return @errorName(err);
                return null;
            }
        };

        try self.finalizers.append(self.allocator, .{
            .state = resource,
            .run = Runner.run,
        });
    }

    pub fn addFinalizerExit(
        self: *Scope,
        state: ?*anyopaque,
        comptime run: *const fn (?*anyopaque, FinalizerExit) void,
    ) Allocator.Error!void {
        const Runner = struct {
            fn runNoFailure(raw: ?*anyopaque, exit: FinalizerExit) ?[]const u8 {
                run(raw, exit);
                return null;
            }
        };

        try self.finalizers.append(self.allocator, .{
            .state = state,
            .run = Runner.runNoFailure,
        });
    }

    pub fn addFinalizerExitFallible(
        self: *Scope,
        state: ?*anyopaque,
        comptime run: anytype,
    ) Allocator.Error!void {
        const Runner = struct {
            fn runFallible(raw: ?*anyopaque, exit: FinalizerExit) ?[]const u8 {
                run(raw, exit) catch |err| return @errorName(err);
                return null;
            }
        };

        try self.finalizers.append(self.allocator, .{
            .state = state,
            .run = Runner.runFallible,
        });
    }

    pub fn addFinalizerExitFor(
        self: *Scope,
        comptime Resource: type,
        resource: *Resource,
        comptime release: *const fn (*Resource, FinalizerExit) void,
    ) Allocator.Error!void {
        const Runner = struct {
            fn run(raw: ?*anyopaque, exit: FinalizerExit) ?[]const u8 {
                const typed: *Resource = @ptrCast(@alignCast(raw.?));
                release(typed, exit);
                return null;
            }
        };

        try self.finalizers.append(self.allocator, .{
            .state = resource,
            .run = Runner.run,
        });
    }

    pub fn addFinalizerExitFallibleFor(
        self: *Scope,
        comptime Resource: type,
        resource: *Resource,
        comptime release: anytype,
    ) Allocator.Error!void {
        const Runner = struct {
            fn run(raw: ?*anyopaque, exit: FinalizerExit) ?[]const u8 {
                const typed: *Resource = @ptrCast(@alignCast(raw.?));
                release(typed, exit) catch |err| return @errorName(err);
                return null;
            }
        };

        try self.finalizers.append(self.allocator, .{
            .state = resource,
            .run = Runner.run,
        });
    }

    pub fn close(self: *Scope) void {
        self.closeWithExit(.success);
    }

    pub fn closeWithExit(self: *Scope, exit: FinalizerExit) void {
        if (self.closed) return;
        while (self.finalizers.items.len > 0) {
            const index = self.finalizers.items.len - 1;
            const finalizer = self.finalizers.items[index];
            self.finalizers.items.len = index;
            if (finalizer.run(finalizer.state, exit)) |failure| {
                self.finalizer_failures.append(self.allocator, failure) catch {};
            }
        }
        self.closed = true;
    }

    pub fn finalizerFailureCount(self: *const Scope) usize {
        return self.finalizer_failures.items.len;
    }

    pub fn firstFinalizerFailure(self: *const Scope) ?[]const u8 {
        if (self.finalizer_failures.items.len == 0) return null;
        return self.finalizer_failures.items[0];
    }

    pub fn hasFinalizerFailure(self: *const Scope, expected: []const u8) bool {
        for (self.finalizer_failures.items) |failure| {
            if (std.mem.eql(u8, failure, expected)) return true;
        }
        return false;
    }
};

pub const Schedule = struct {
    const Kind = union(enum) {
        fixed: Fixed,
        exponential: Exponential,
        linear: Linear,
        repeat: Repeat,
        backoff: Backoff,
        jittered_backoff: JitteredBackoff,
        fibonacci: Fibonacci,
    };

    pub const Fixed = struct {
        max_retries: usize,
        delay_ms: u64,
    };

    pub const Spaced = struct {
        max_retries: usize,
        delay_ms: u64,
    };

    pub const Duration = struct {
        max_retries: usize,
        duration_ms: u64,
    };

    pub const Exponential = struct {
        max_retries: usize,
        base_delay_ms: u64,
        max_delay_ms: u64,
    };

    pub const Linear = struct {
        max_retries: usize,
        base_delay_ms: u64,
        step_delay_ms: u64,
        max_delay_ms: u64,
    };

    pub const Repeat = struct {
        max_repeats: usize,
        delay_ms: u64,
    };

    pub const Backoff = struct {
        max_retries: usize,
        base_delay_ms: u64,
        factor: u64,
        max_delay_ms: u64,
    };

    pub const JitteredBackoff = struct {
        max_retries: usize,
        base_delay_ms: u64,
        factor: u64,
        max_delay_ms: u64,
        jitter_ms: u64,
        seed: u64 = 0,
    };

    pub const Fibonacci = struct {
        max_retries: usize,
        base_delay_ms: u64,
        max_delay_ms: u64,
    };

    kind: Kind,

    pub fn fixed(options: Fixed) Schedule {
        return .{ .kind = .{ .fixed = options } };
    }

    pub fn once() Schedule {
        return fixed(.{ .max_retries = 1, .delay_ms = 0 });
    }

    pub fn recurs(max_retries: usize) Schedule {
        return fixed(.{ .max_retries = max_retries, .delay_ms = 0 });
    }

    pub fn spaced(options: Spaced) Schedule {
        return fixed(.{ .max_retries = options.max_retries, .delay_ms = options.delay_ms });
    }

    pub fn duration(options: Duration) Schedule {
        return fixed(.{ .max_retries = options.max_retries, .delay_ms = options.duration_ms });
    }

    pub fn exponential(options: Exponential) Schedule {
        return .{ .kind = .{ .exponential = options } };
    }

    pub fn linear(options: Linear) Schedule {
        return .{ .kind = .{ .linear = options } };
    }

    pub fn repeat(options: Repeat) Schedule {
        return .{ .kind = .{ .repeat = options } };
    }

    pub fn backoff(options: Backoff) Schedule {
        return .{ .kind = .{ .backoff = options } };
    }

    pub fn jitteredBackoff(options: JitteredBackoff) Schedule {
        return .{ .kind = .{ .jittered_backoff = options } };
    }

    pub fn fibonacci(options: Fibonacci) Schedule {
        return .{ .kind = .{ .fibonacci = options } };
    }

    pub fn nextDelay(self: *Schedule, attempt: usize) ?u64 {
        return switch (self.kind) {
            .fixed => |options| if (attempt < options.max_retries) options.delay_ms else null,
            .exponential => |options| {
                if (attempt >= options.max_retries) return null;

                var delay = options.base_delay_ms;
                var exponent: usize = 0;
                while (exponent < attempt) : (exponent += 1) {
                    delay = std.math.mul(u64, delay, 2) catch options.max_delay_ms;
                    if (delay >= options.max_delay_ms) return options.max_delay_ms;
                }

                return @min(delay, options.max_delay_ms);
            },
            .linear => |options| {
                if (attempt >= options.max_retries) return null;
                const step = std.math.mul(u64, options.step_delay_ms, attempt) catch options.max_delay_ms;
                const delay = std.math.add(u64, options.base_delay_ms, step) catch options.max_delay_ms;
                return @min(delay, options.max_delay_ms);
            },
            .repeat => |options| if (attempt < options.max_repeats) options.delay_ms else null,
            .backoff => |options| {
                if (attempt >= options.max_retries) return null;
                return backoffDelay(options.base_delay_ms, options.factor, options.max_delay_ms, attempt);
            },
            .jittered_backoff => |options| {
                if (attempt >= options.max_retries) return null;
                const base = backoffDelay(options.base_delay_ms, options.factor, options.max_delay_ms, attempt);
                const jitter = deterministicJitter(options.seed, attempt, options.jitter_ms);
                const delay = std.math.add(u64, base, jitter) catch options.max_delay_ms;
                return @min(delay, options.max_delay_ms);
            },
            .fibonacci => |options| {
                if (attempt >= options.max_retries) return null;
                return fibonacciDelay(options.base_delay_ms, options.max_delay_ms, attempt);
            },
        };
    }

    fn backoffDelay(base_delay_ms: u64, factor: u64, max_delay_ms: u64, attempt: usize) u64 {
        var delay = base_delay_ms;
        var exponent: usize = 0;
        const bounded_factor = @max(factor, 1);
        while (exponent < attempt) : (exponent += 1) {
            delay = std.math.mul(u64, delay, bounded_factor) catch max_delay_ms;
            if (delay >= max_delay_ms) return max_delay_ms;
        }
        return @min(delay, max_delay_ms);
    }

    fn deterministicJitter(seed: u64, attempt: usize, jitter_ms: u64) u64 {
        if (jitter_ms == 0) return 0;
        const mixed = seed +% (@as(u64, attempt) *% 1_103_515_245) +% 12_345;
        return mixed % (jitter_ms + 1);
    }

    fn fibonacciDelay(base_delay_ms: u64, max_delay_ms: u64, attempt: usize) u64 {
        if (attempt <= 1) return @min(base_delay_ms, max_delay_ms);

        var previous = base_delay_ms;
        var current = base_delay_ms;
        var index: usize = 2;
        while (index <= attempt) : (index += 1) {
            const next = std.math.add(u64, previous, current) catch max_delay_ms;
            previous = current;
            current = @min(next, max_delay_ms);
            if (current >= max_delay_ms) return max_delay_ms;
        }

        return current;
    }
};

pub const Logger = struct {
    allocator: Allocator,
    entries: std.ArrayList([]const u8) = .empty,

    pub fn init(allocator: Allocator) Logger {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Logger) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry);
        }
        self.entries.deinit(self.allocator);
    }

    pub fn info(self: *Logger, message: []const u8) Allocator.Error!void {
        try self.entries.append(self.allocator, try self.allocator.dupe(u8, message));
    }

    pub fn warn(self: *Logger, message: []const u8) Allocator.Error!void {
        try self.info(message);
    }

    pub fn err(self: *Logger, message: []const u8) Allocator.Error!void {
        try self.info(message);
    }
};

pub const ConfigError = error{MissingConfig};

pub const Config = struct {
    allocator: Allocator,
    values: std.StringHashMap([]const u8),

    pub fn init(allocator: Allocator) Config {
        return .{
            .allocator = allocator,
            .values = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Config) void {
        var iterator = self.values.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.values.deinit();
    }

    pub fn set(self: *Config, key: []const u8, value: []const u8) Allocator.Error!void {
        if (self.values.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }

        try self.values.put(
            try self.allocator.dupe(u8, key),
            try self.allocator.dupe(u8, value),
        );
    }

    pub fn get(self: *Config, key: []const u8) ?[]const u8 {
        return self.values.get(key);
    }

    pub fn require(self: *Config, key: []const u8) ConfigError![]const u8 {
        return self.get(key) orelse error.MissingConfig;
    }
};

pub const Metrics = struct {
    allocator: Allocator,
    counters: std.StringHashMap(i64),

    pub fn init(allocator: Allocator) Metrics {
        return .{
            .allocator = allocator,
            .counters = std.StringHashMap(i64).init(allocator),
        };
    }

    pub fn deinit(self: *Metrics) void {
        var iterator = self.counters.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.counters.deinit();
    }

    pub fn increment(self: *Metrics, name: []const u8, amount: i64) Allocator.Error!void {
        if (self.counters.getPtr(name)) |counter| {
            counter.* += amount;
            return;
        }

        try self.counters.put(try self.allocator.dupe(u8, name), amount);
    }

    pub fn get(self: *Metrics, name: []const u8) i64 {
        return self.counters.get(name) orelse 0;
    }

    pub fn gauge(self: *Metrics, name: []const u8, value: i64) Allocator.Error!void {
        if (self.counters.getPtr(name)) |counter| {
            counter.* = value;
            return;
        }

        try self.counters.put(try self.allocator.dupe(u8, name), value);
    }
};

pub const Tracing = struct {
    allocator: Allocator,
    events: std.ArrayList([]const u8) = .empty,

    pub fn init(allocator: Allocator) Tracing {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Tracing) void {
        for (self.events.items) |event_name| {
            self.allocator.free(event_name);
        }
        self.events.deinit(self.allocator);
    }

    pub fn event(self: *Tracing, name: []const u8) Allocator.Error!void {
        try self.events.append(self.allocator, try self.allocator.dupe(u8, name));
    }

    pub fn spanStart(self: *Tracing, name: []const u8) Allocator.Error!void {
        const entry = try std.fmt.allocPrint(self.allocator, "span:start:{s}", .{name});
        try self.events.append(self.allocator, entry);
    }

    pub fn spanEnd(self: *Tracing, name: []const u8) Allocator.Error!void {
        const entry = try std.fmt.allocPrint(self.allocator, "span:end:{s}", .{name});
        try self.events.append(self.allocator, entry);
    }
};

pub const MemoryFileSystem = struct {
    allocator: Allocator,
    files: std.StringHashMap([]const u8),

    pub fn init(allocator: Allocator) MemoryFileSystem {
        return .{
            .allocator = allocator,
            .files = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *MemoryFileSystem) void {
        var iterator = self.files.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.files.deinit();
    }

    pub fn writeFile(
        self: *MemoryFileSystem,
        path: []const u8,
        content: []const u8,
    ) Allocator.Error!void {
        if (self.files.fetchRemove(path)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }

        try self.files.put(
            try self.allocator.dupe(u8, path),
            try self.allocator.dupe(u8, content),
        );
    }

    pub fn readFile(self: *MemoryFileSystem, path: []const u8) ?[]const u8 {
        return self.files.get(path);
    }

    pub fn exists(self: *MemoryFileSystem, path: []const u8) bool {
        return self.files.contains(path);
    }

    pub fn deleteFile(self: *MemoryFileSystem, path: []const u8) void {
        if (self.files.fetchRemove(path)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
    }
};

pub const TestServices = struct {
    logger: Logger,
    config: Config,
    metrics: Metrics,
    tracing: Tracing,
    fs: MemoryFileSystem,
    clock: FakeClock,

    pub fn init(allocator: Allocator) TestServices {
        return .{
            .logger = Logger.init(allocator),
            .config = Config.init(allocator),
            .metrics = Metrics.init(allocator),
            .tracing = Tracing.init(allocator),
            .fs = MemoryFileSystem.init(allocator),
            .clock = .{},
        };
    }

    pub fn deinit(self: *TestServices) void {
        self.fs.deinit();
        self.tracing.deinit();
        self.metrics.deinit();
        self.config.deinit();
        self.logger.deinit();
    }

    pub fn service(self: *TestServices, comptime Service: type) *Service {
        if (Service == Logger) return &self.logger;
        if (Service == Config) return &self.config;
        if (Service == Metrics) return &self.metrics;
        if (Service == Tracing) return &self.tracing;
        if (Service == MemoryFileSystem) return &self.fs;
        if (Service == FakeClock) return &self.clock;
        return serviceNotFound(TestServices, Service);
    }
};

pub const TestEnv = struct {
    allocator: Allocator,
    scope: Scope,
    services: TestServices,

    pub fn init(allocator: Allocator) Allocator.Error!TestEnv {
        return .{
            .allocator = allocator,
            .scope = Scope.init(allocator),
            .services = TestServices.init(allocator),
        };
    }

    pub fn deinit(self: *TestEnv) void {
        self.scope.close();
        self.scope.deinit();
        self.services.deinit();
    }

    pub fn layer(self: *TestEnv) ProvidedLayer(Layer(TestServices), .{ Logger, Config, Metrics, Tracing, MemoryFileSystem, Clock }) {
        return Layer(TestServices)
            .fromEnv(&self.services)
            .provides(.{ Logger, Config, Metrics, Tracing, MemoryFileSystem, Clock });
    }

    pub fn context(self: *TestEnv) Context(TestServices) {
        var ctx = Context(TestServices).init(self.allocator, &self.services, &self.scope);
        ctx.clock = &self.services.clock;
        return ctx;
    }

    pub fn runtime(self: *TestEnv) Runtime(TestServices) {
        return Runtime(TestServices)
            .init(self.allocator, &self.services)
            .withClock(&self.services.clock)
            .provides(.{ Logger, Config, Metrics, Tracing, MemoryFileSystem, Clock });
    }

    pub fn run(self: *TestEnv, effect: anytype) (Allocator.Error || DependencyError || @TypeOf(effect).FailureType)!@TypeOf(effect).SuccessType {
        var runner = self.runtime();
        return runner.run(effect);
    }

    pub fn exit(self: *TestEnv, effect: anytype) Exit(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType) {
        var runner = self.runtime();
        return runner.exit(effect);
    }

    pub fn expectLog(self: *TestEnv, expected: []const u8) !void {
        for (self.services.logger.entries.items) |entry| {
            if (std.mem.eql(u8, entry, expected)) return;
        }
        return error.ExpectedLogNotFound;
    }

    pub fn expectTrace(self: *TestEnv, expected: []const u8) !void {
        for (self.services.tracing.events.items) |entry| {
            if (std.mem.eql(u8, entry, expected)) return;
        }
        return error.ExpectedTraceNotFound;
    }

    pub fn expectMetric(self: *TestEnv, name: []const u8, expected: i64) !void {
        try std.testing.expectEqual(expected, self.services.metrics.get(name));
    }

    pub fn expectFile(self: *TestEnv, path: []const u8, expected: []const u8) !void {
        try std.testing.expectEqualStrings(expected, self.services.fs.readFile(path) orelse return error.ExpectedFileNotFound);
    }
};
