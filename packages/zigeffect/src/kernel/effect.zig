const context_mod = @import("context.zig");
const service_mod = @import("service.zig");
const clock_mod = @import("../services/clock.zig");
const defaults_mod = @import("default_services.zig");
const identity_mod = @import("../core/runtime_identity.zig");
const lineage_mod = @import("../services/lineage.zig");

pub const RuntimeContext = context_mod.RuntimeContext;
pub const ContextView = context_mod.ContextView;
pub const Clock = clock_mod.Clock;

fn callableReturnType(comptime callable: anytype) type {
    const Callable = @TypeOf(callable);
    const function_info = switch (@typeInfo(Callable)) {
        .@"fn" => |info| info,
        .pointer => |pointer| switch (@typeInfo(pointer.child)) {
            .@"fn" => |info| info,
            else => @compileError("zigeffect combinators require a function or function pointer"),
        },
        else => @compileError("zigeffect combinators require a function or function pointer"),
    };
    return function_info.return_type orelse
        @compileError("zigeffect combinator functions must declare a return type");
}

fn assertEffectType(comptime Candidate: type) void {
    if (!@hasDecl(Candidate, "SuccessType") or
        !@hasDecl(Candidate, "FailureType") or
        !@hasDecl(Candidate, "RequiredServices") or
        !@hasDecl(Candidate, "runIn"))
    {
        @compileError(
            "zigeffect effectful combinators require a canonical Effect value; received " ++
                @typeName(Candidate),
        );
    }
}

fn assertErrorSet(comptime Candidate: type) void {
    switch (@typeInfo(Candidate)) {
        .error_set => {},
        else => @compileError(
            "zigeffect mapError mapper must return an error set; received " ++ @typeName(Candidate),
        ),
    }
}

fn assertLineageKey(comptime Key: type) void {
    if (!@hasDecl(Key, "Value") or !@hasDecl(Key, "name") or
        !@hasDecl(Key, "reference") or !@hasDecl(Key, "key_id"))
    {
        @compileError("Effect.track requires a key declared with zstd.Lineage.Key");
    }
}

/// Shared fluent API for every canonical effect description. Function aliases
/// install these operations as methods without wrapping values or allocating.
fn EffectMethods(comptime Parent: type) type {
    return struct {
        pub fn map(self: Parent, comptime mapper: anytype) MapEffect(Parent, mapper) {
            return .{ .parent = self };
        }

        pub fn flatMap(self: Parent, comptime mapper: anytype) FlatMapEffect(Parent, mapper) {
            return .{ .parent = self };
        }

        pub fn tap(self: Parent, comptime observer: anytype) TapEffect(Parent, observer) {
            return .{ .parent = self };
        }

        pub fn andThen(self: Parent, next: anytype) ThenEffect(Parent, @TypeOf(next)) {
            return .{ .parent = self, .next = next };
        }

        pub fn catchAll(self: Parent, comptime handler: anytype) CatchAllEffect(Parent, handler) {
            return .{ .parent = self };
        }

        pub fn mapError(self: Parent, comptime mapper: anytype) MapErrorEffect(Parent, mapper) {
            return .{ .parent = self };
        }

        pub fn zip(self: Parent, right: anytype) ZipEffect(Parent, @TypeOf(right)) {
            return .{ .left = self, .right = right };
        }

        pub fn named(self: Parent, label: []const u8) NamedEffect(Parent) {
            return .{ .parent = self, .label = label };
        }

        pub fn withClock(self: Parent, clock: *Clock) WithClockEffect(Parent) {
            return .{ .parent = self, .clock = clock };
        }

        pub fn withDefaults(self: Parent, overrides: defaults_mod.DefaultOverrides) WithDefaultsEffect(Parent) {
            return .{ .parent = self, .overrides = overrides };
        }

        /// Scope this effect to one typed non-raw domain reference. The
        /// runtime propagates the resulting reference; the source value is
        /// never copied into causal, graph, transport, or OTEL records.
        pub fn track(self: Parent, comptime Key: type, value: Key.Value) TrackLineageEffect(Parent, Key) {
            assertLineageKey(Key);
            return .{ .parent = self, .value = value };
        }
    };
}

fn declareEffectMethods(comptime Self: type) type {
    const Methods = EffectMethods(Self);
    return struct {
        pub const map = Methods.map;
        pub const flatMap = Methods.flatMap;
        pub const tap = Methods.tap;
        pub const andThen = Methods.andThen;
        pub const catchAll = Methods.catchAll;
        pub const mapError = Methods.mapError;
        pub const zip = Methods.zip;
        pub const named = Methods.named;
        pub const withClock = Methods.withClock;
        pub const withDefaults = Methods.withDefaults;
        pub const track = Methods.track;
    };
}

pub fn Effect(
    comptime Success: type,
    comptime Failure: type,
    comptime Requirements: anytype,
) type {
    return struct {
        const Self = @This();
        const Methods = declareEffectMethods(Self);
        pub const SuccessType = Success;
        pub const FailureType = Failure;
        pub const RequiredServices = Requirements;
        pub const Context = ContextView(Requirements);
        pub const map = Methods.map;
        pub const flatMap = Methods.flatMap;
        pub const tap = Methods.tap;
        pub const andThen = Methods.andThen;
        pub const catchAll = Methods.catchAll;
        pub const mapError = Methods.mapError;
        pub const zip = Methods.zip;
        pub const named = Methods.named;
        pub const withClock = Methods.withClock;
        pub const withDefaults = Methods.withDefaults;
        pub const track = Methods.track;

        const Mode = union(enum) {
            run_fn: *const fn (*Context) Failure!Success,
            succeed: Success,
            fail: Failure,
        };

        mode: Mode,

        pub fn fromFn(comptime run_fn: anytype) Self {
            const typed: *const fn (*Context) Failure!Success = run_fn;
            return .{ .mode = .{ .run_fn = typed } };
        }

        pub fn Stateful(comptime State: type) type {
            return StatefulEffect(Success, Failure, Requirements, State);
        }

        pub fn fromState(
            comptime State: type,
            state: State,
            comptime run_fn: *const fn (State, *Context) Failure!Success,
        ) Stateful(State) {
            return Stateful(State).init(state, run_fn);
        }

        pub fn succeed(value: Success) Self {
            return .{ .mode = .{ .succeed = value } };
        }

        pub fn fail(failure: Failure) Self {
            return .{ .mode = .{ .fail = failure } };
        }

        fn evaluate(self: Self, runtime: *RuntimeContext) Failure!Success {
            return switch (self.mode) {
                .run_fn => |run_fn| blk: {
                    var context = Context{ .runtime_context = runtime };
                    break :blk run_fn(&context);
                },
                .succeed => |value| value,
                .fail => |failure| failure,
            };
        }

        pub fn runIn(self: Self, runtime: *RuntimeContext) Failure!Success {
            const previous_parent = runtime.causal_parent_id;
            const started = runtime.emit(.{
                .kind = .effect_started,
                .label = identity_mod.boundedTypeName(Self),
                .type_name = identity_mod.boundedTypeName(Self),
                .status = "running",
            });
            runtime.causal_parent_id = started orelse previous_parent;
            defer runtime.causal_parent_id = previous_parent;

            const value = self.evaluate(runtime) catch |failure| {
                _ = runtime.emit(.{
                    .kind = .effect_completed,
                    .label = identity_mod.boundedTypeName(Self),
                    .type_name = @errorName(failure),
                    .status = "failure",
                });
                return failure;
            };
            _ = runtime.emit(.{
                .kind = .effect_completed,
                .label = identity_mod.boundedTypeName(Self),
                .status = "success",
            });
            return value;
        }
    };
}

/// A parameterized effect description. The state is ordinary immutable
/// program data (request values, operation arguments, bounded slices), while
/// dependencies remain exclusively in RequiredServices.
pub fn StatefulEffect(
    comptime Success: type,
    comptime Failure: type,
    comptime Requirements: anytype,
    comptime State: type,
) type {
    return struct {
        const Self = @This();
        const Methods = declareEffectMethods(Self);
        pub const SuccessType = Success;
        pub const FailureType = Failure;
        pub const RequiredServices = Requirements;
        pub const Context = ContextView(Requirements);
        pub const StateType = State;
        pub const map = Methods.map;
        pub const flatMap = Methods.flatMap;
        pub const tap = Methods.tap;
        pub const andThen = Methods.andThen;
        pub const catchAll = Methods.catchAll;
        pub const mapError = Methods.mapError;
        pub const zip = Methods.zip;
        pub const named = Methods.named;
        pub const withClock = Methods.withClock;
        pub const withDefaults = Methods.withDefaults;
        pub const track = Methods.track;

        state: State,
        run_fn: *const fn (State, *Context) Failure!Success,

        pub fn init(
            state: State,
            comptime run_fn: *const fn (State, *Context) Failure!Success,
        ) Self {
            return .{ .state = state, .run_fn = run_fn };
        }

        pub fn runIn(self: Self, runtime: *RuntimeContext) Failure!Success {
            const previous_parent = runtime.causal_parent_id;
            const started = runtime.emit(.{
                .kind = .effect_started,
                .label = identity_mod.boundedTypeName(Self),
                .type_name = identity_mod.boundedTypeName(Self),
                .status = "running",
            });
            runtime.causal_parent_id = started orelse previous_parent;
            defer runtime.causal_parent_id = previous_parent;

            var context = Context{ .runtime_context = runtime };
            const value = self.run_fn(self.state, &context) catch |failure| {
                _ = runtime.emit(.{
                    .kind = .effect_completed,
                    .label = identity_mod.boundedTypeName(Self),
                    .type_name = @errorName(failure),
                    .status = "failure",
                });
                return failure;
            };
            _ = runtime.emit(.{
                .kind = .effect_completed,
                .label = identity_mod.boundedTypeName(Self),
                .status = "success",
            });
            return value;
        }
    };
}

pub fn TrackLineageEffect(comptime Parent: type, comptime Key: type) type {
    assertLineageKey(Key);
    return struct {
        const Self = @This();
        const Methods = declareEffectMethods(Self);
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Parent.FailureType || lineage_mod.Error;
        pub const RequiredServices = Parent.RequiredServices;
        pub const map = Methods.map;
        pub const flatMap = Methods.flatMap;
        pub const tap = Methods.tap;
        pub const andThen = Methods.andThen;
        pub const catchAll = Methods.catchAll;
        pub const mapError = Methods.mapError;
        pub const zip = Methods.zip;
        pub const named = Methods.named;
        pub const withClock = Methods.withClock;
        pub const withDefaults = Methods.withDefaults;
        pub const track = Methods.track;

        parent: Parent,
        value: Key.Value,

        pub fn runIn(self: Self, runtime: *RuntimeContext) FailureType!SuccessType {
            const reference = Key.reference(runtime.causal_context.project_id, self.value) catch |failure| {
                _ = runtime.recordCausal(.{
                    .kind = .lineage_bound,
                    .label = Key.name,
                    .type_name = @errorName(failure),
                    .status = "rejected",
                    .redacted_detail = "typed lineage binding rejected; source value omitted",
                });
                return failure;
            };
            var scoped = runtime.*;
            scoped.causal_context.lineage = lineage_mod.Set.merge(
                runtime.causal_context.lineage,
                lineage_mod.Set.empty.with(reference),
            );
            _ = scoped.recordCausal(.{
                .kind = .lineage_bound,
                .label = Key.name,
                .type_name = @typeName(Key.Value),
                .status = "bound",
                .redacted_detail = "typed lineage reference attached; source value omitted",
            });
            return self.parent.runIn(&scoped);
        }
    };
}

pub fn WithClockEffect(comptime Parent: type) type {
    return struct {
        const Self = @This();
        const Methods = declareEffectMethods(Self);
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Parent.FailureType;
        pub const RequiredServices = Parent.RequiredServices;
        pub const map = Methods.map;
        pub const flatMap = Methods.flatMap;
        pub const tap = Methods.tap;
        pub const andThen = Methods.andThen;
        pub const catchAll = Methods.catchAll;
        pub const mapError = Methods.mapError;
        pub const zip = Methods.zip;
        pub const named = Methods.named;
        pub const withClock = Methods.withClock;
        pub const withDefaults = Methods.withDefaults;
        pub const track = Methods.track;

        parent: Parent,
        clock: *Clock,

        pub fn runIn(self: Self, runtime: *RuntimeContext) FailureType!SuccessType {
            var overridden = runtime.*;
            overridden.default_overrides = runtime.default_overrides.overlay(.{ .clock = self.clock });
            return self.parent.runIn(&overridden);
        }
    };
}

pub fn WithDefaultsEffect(comptime Parent: type) type {
    return struct {
        const Self = @This();
        const Methods = declareEffectMethods(Self);
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Parent.FailureType;
        pub const RequiredServices = Parent.RequiredServices;
        pub const map = Methods.map;
        pub const flatMap = Methods.flatMap;
        pub const tap = Methods.tap;
        pub const andThen = Methods.andThen;
        pub const catchAll = Methods.catchAll;
        pub const mapError = Methods.mapError;
        pub const zip = Methods.zip;
        pub const named = Methods.named;
        pub const withClock = Methods.withClock;
        pub const withDefaults = Methods.withDefaults;
        pub const track = Methods.track;

        parent: Parent,
        overrides: defaults_mod.DefaultOverrides,

        pub fn runIn(self: Self, runtime: *RuntimeContext) FailureType!SuccessType {
            var overridden = runtime.*;
            overridden.default_overrides = runtime.default_overrides.overlay(self.overrides);
            return self.parent.runIn(&overridden);
        }
    };
}

pub fn MapEffect(comptime Parent: type, comptime mapper: anytype) type {
    const Next = callableReturnType(mapper);
    return struct {
        const Self = @This();
        const Methods = declareEffectMethods(Self);
        pub const SuccessType = Next;
        pub const FailureType = Parent.FailureType;
        pub const RequiredServices = Parent.RequiredServices;
        pub const map = Methods.map;
        pub const flatMap = Methods.flatMap;
        pub const tap = Methods.tap;
        pub const andThen = Methods.andThen;
        pub const catchAll = Methods.catchAll;
        pub const mapError = Methods.mapError;
        pub const zip = Methods.zip;
        pub const named = Methods.named;
        pub const withClock = Methods.withClock;
        pub const withDefaults = Methods.withDefaults;
        pub const track = Methods.track;

        parent: Parent,

        pub fn runIn(self: Self, runtime: *RuntimeContext) FailureType!SuccessType {
            return mapper(try self.parent.runIn(runtime));
        }
    };
}

pub fn FlatMapEffect(comptime Parent: type, comptime mapper: anytype) type {
    const Next = callableReturnType(mapper);
    assertEffectType(Next);
    return struct {
        const Self = @This();
        const Methods = declareEffectMethods(Self);
        pub const SuccessType = Next.SuccessType;
        pub const FailureType = Parent.FailureType || Next.FailureType;
        pub const RequiredServices = service_mod.unionServices(Parent.RequiredServices, Next.RequiredServices);
        pub const map = Methods.map;
        pub const flatMap = Methods.flatMap;
        pub const tap = Methods.tap;
        pub const andThen = Methods.andThen;
        pub const catchAll = Methods.catchAll;
        pub const mapError = Methods.mapError;
        pub const zip = Methods.zip;
        pub const named = Methods.named;
        pub const withClock = Methods.withClock;
        pub const withDefaults = Methods.withDefaults;
        pub const track = Methods.track;

        parent: Parent,

        pub fn runIn(self: Self, runtime: *RuntimeContext) FailureType!SuccessType {
            const value = try self.parent.runIn(runtime);
            return mapper(value).runIn(runtime);
        }
    };
}

pub fn TapEffect(comptime Parent: type, comptime observer: anytype) type {
    const Observation = callableReturnType(observer);
    assertEffectType(Observation);
    return struct {
        const Self = @This();
        const Methods = declareEffectMethods(Self);
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Parent.FailureType || Observation.FailureType;
        pub const RequiredServices = service_mod.unionServices(Parent.RequiredServices, Observation.RequiredServices);
        pub const map = Methods.map;
        pub const flatMap = Methods.flatMap;
        pub const tap = Methods.tap;
        pub const andThen = Methods.andThen;
        pub const catchAll = Methods.catchAll;
        pub const mapError = Methods.mapError;
        pub const zip = Methods.zip;
        pub const named = Methods.named;
        pub const withClock = Methods.withClock;
        pub const withDefaults = Methods.withDefaults;
        pub const track = Methods.track;

        parent: Parent,

        pub fn runIn(self: Self, runtime: *RuntimeContext) FailureType!SuccessType {
            const value = try self.parent.runIn(runtime);
            _ = try observer(value).runIn(runtime);
            return value;
        }
    };
}

pub fn ThenEffect(comptime Parent: type, comptime Next: type) type {
    assertEffectType(Next);
    return struct {
        const Self = @This();
        const Methods = declareEffectMethods(Self);
        pub const SuccessType = Next.SuccessType;
        pub const FailureType = Parent.FailureType || Next.FailureType;
        pub const RequiredServices = service_mod.unionServices(Parent.RequiredServices, Next.RequiredServices);
        pub const map = Methods.map;
        pub const flatMap = Methods.flatMap;
        pub const tap = Methods.tap;
        pub const andThen = Methods.andThen;
        pub const catchAll = Methods.catchAll;
        pub const mapError = Methods.mapError;
        pub const zip = Methods.zip;
        pub const named = Methods.named;
        pub const withClock = Methods.withClock;
        pub const withDefaults = Methods.withDefaults;
        pub const track = Methods.track;

        parent: Parent,
        next: Next,

        pub fn runIn(self: Self, runtime: *RuntimeContext) FailureType!SuccessType {
            _ = try self.parent.runIn(runtime);
            return self.next.runIn(runtime);
        }
    };
}

pub fn CatchAllEffect(comptime Parent: type, comptime handler: anytype) type {
    const Recovery = callableReturnType(handler);
    assertEffectType(Recovery);
    if (Recovery.SuccessType != Parent.SuccessType) {
        @compileError(
            "zigeffect catchAll recovery must return the same success type; expected " ++
                @typeName(Parent.SuccessType) ++ ", received " ++ @typeName(Recovery.SuccessType),
        );
    }
    return struct {
        const Self = @This();
        const Methods = declareEffectMethods(Self);
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Recovery.FailureType;
        pub const RequiredServices = service_mod.unionServices(Parent.RequiredServices, Recovery.RequiredServices);
        pub const map = Methods.map;
        pub const flatMap = Methods.flatMap;
        pub const tap = Methods.tap;
        pub const andThen = Methods.andThen;
        pub const catchAll = Methods.catchAll;
        pub const mapError = Methods.mapError;
        pub const zip = Methods.zip;
        pub const named = Methods.named;
        pub const withClock = Methods.withClock;
        pub const withDefaults = Methods.withDefaults;
        pub const track = Methods.track;

        parent: Parent,

        pub fn runIn(self: Self, runtime: *RuntimeContext) FailureType!SuccessType {
            return self.parent.runIn(runtime) catch |failure| handler(failure).runIn(runtime);
        }
    };
}

pub fn MapErrorEffect(comptime Parent: type, comptime mapper: anytype) type {
    const NextFailure = callableReturnType(mapper);
    assertErrorSet(NextFailure);
    return struct {
        const Self = @This();
        const Methods = declareEffectMethods(Self);
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = NextFailure;
        pub const RequiredServices = Parent.RequiredServices;
        pub const map = Methods.map;
        pub const flatMap = Methods.flatMap;
        pub const tap = Methods.tap;
        pub const andThen = Methods.andThen;
        pub const catchAll = Methods.catchAll;
        pub const mapError = Methods.mapError;
        pub const zip = Methods.zip;
        pub const named = Methods.named;
        pub const withClock = Methods.withClock;
        pub const withDefaults = Methods.withDefaults;
        pub const track = Methods.track;

        parent: Parent,

        pub fn runIn(self: Self, runtime: *RuntimeContext) FailureType!SuccessType {
            return self.parent.runIn(runtime) catch |failure| return mapper(failure);
        }
    };
}

pub fn ZipResult(comptime Left: type, comptime Right: type) type {
    return struct {
        left: Left,
        right: Right,
    };
}

pub fn ZipEffect(comptime Left: type, comptime Right: type) type {
    assertEffectType(Right);
    return struct {
        const Self = @This();
        const Methods = declareEffectMethods(Self);
        pub const SuccessType = ZipResult(Left.SuccessType, Right.SuccessType);
        pub const FailureType = Left.FailureType || Right.FailureType;
        pub const RequiredServices = service_mod.unionServices(Left.RequiredServices, Right.RequiredServices);
        pub const map = Methods.map;
        pub const flatMap = Methods.flatMap;
        pub const tap = Methods.tap;
        pub const andThen = Methods.andThen;
        pub const catchAll = Methods.catchAll;
        pub const mapError = Methods.mapError;
        pub const zip = Methods.zip;
        pub const named = Methods.named;
        pub const withClock = Methods.withClock;
        pub const withDefaults = Methods.withDefaults;
        pub const track = Methods.track;

        left: Left,
        right: Right,

        pub fn runIn(self: Self, runtime: *RuntimeContext) FailureType!SuccessType {
            const left = try self.left.runIn(runtime);
            const right = try self.right.runIn(runtime);
            return .{ .left = left, .right = right };
        }
    };
}

pub fn NamedEffect(comptime Parent: type) type {
    return struct {
        const Self = @This();
        const Methods = declareEffectMethods(Self);
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Parent.FailureType;
        pub const RequiredServices = Parent.RequiredServices;
        pub const map = Methods.map;
        pub const flatMap = Methods.flatMap;
        pub const tap = Methods.tap;
        pub const andThen = Methods.andThen;
        pub const catchAll = Methods.catchAll;
        pub const mapError = Methods.mapError;
        pub const zip = Methods.zip;
        pub const named = Methods.named;
        pub const withClock = Methods.withClock;
        pub const withDefaults = Methods.withDefaults;
        pub const track = Methods.track;

        parent: Parent,
        label: []const u8,

        pub fn runtimeLabel(self: Self) []const u8 {
            return self.label;
        }

        pub fn runIn(self: Self, runtime: *RuntimeContext) FailureType!SuccessType {
            const previous_parent = runtime.causal_parent_id;
            const started = runtime.emit(.{
                .kind = .effect_started,
                .label = self.label,
                .type_name = identity_mod.boundedTypeName(Parent),
                .status = "running",
            });
            runtime.causal_parent_id = started orelse previous_parent;
            defer runtime.causal_parent_id = previous_parent;

            const value = self.parent.runIn(runtime) catch |failure| {
                _ = runtime.emit(.{
                    .kind = .effect_completed,
                    .label = self.label,
                    .type_name = @errorName(failure),
                    .status = "failure",
                });
                return failure;
            };
            _ = runtime.emit(.{
                .kind = .effect_completed,
                .label = self.label,
                .type_name = identity_mod.boundedTypeName(Parent),
                .status = "success",
            });
            return value;
        }
    };
}
