const std = @import("std");
const fx = @import("zigeffect");

const kernel = fx.kernel;

pub fn MachineApi(comptime DefinitionType: type) type {
    return struct {
        pub const operations: []const []const u8 = &.{"StateMachine.step"};
        definition: *const DefinitionType,
    };
}

pub fn MachineService(comptime service_key: []const u8, comptime DefinitionType: type) type {
    return kernel.Service(service_key, MachineApi(DefinitionType));
}

pub fn layer(comptime service_key: []const u8, comptime DefinitionType: type, definition: *const DefinitionType) @TypeOf(
    kernel.Layer.succeed(MachineService(service_key, DefinitionType), .{ .definition = definition }),
) {
    return kernel.Layer.succeed(MachineService(service_key, DefinitionType), .{ .definition = definition });
}

pub fn StepRequest(comptime DefinitionType: type) type {
    const Machine = fx.statechart.Machine(DefinitionType);
    return struct { snapshot: Machine.Snapshot, event: DefinitionType.EventType };
}

pub fn StepEffect(comptime service_key: []const u8, comptime DefinitionType: type) type {
    const Tag = MachineService(service_key, DefinitionType);
    const Machine = fx.statechart.Machine(DefinitionType);
    return kernel.Effect(Machine.Decision, anyerror, .{Tag}).Stateful(StepRequest(DefinitionType));
}

/// Execute one pure typed statechart decision inside the owning runtime. The
/// decision is returned unchanged and its semantic transition is recorded by
/// the runtime's causal aspects with definition and instance identity.
pub fn step(
    comptime service_key: []const u8,
    comptime DefinitionType: type,
    request: StepRequest(DefinitionType),
) StepEffect(service_key, DefinitionType) {
    const Tag = MachineService(service_key, DefinitionType);
    const Machine = fx.statechart.Machine(DefinitionType);
    const Program = StepEffect(service_key, DefinitionType);
    return Program.init(request, struct {
        fn run(input: StepRequest(DefinitionType), ctx: *Program.Context) anyerror!Machine.Decision {
            const definition = ctx.service(Tag).definition;
            const decision = try Machine.step(definition, input.snapshot, input.event);
            var event = try fx.statechart.mapDecisionToCausal(DefinitionType, ctx.allocator(), definition, &decision, null);
            defer fx.statechart.deinitMappedCausalEvent(ctx.allocator(), &event);
            event.service_key = Tag.service_key;
            _ = ctx.recordCausal(event);
            return decision;
        }
    }.run);
}

test "typed statechart services compose decisions and causal evidence" {
    const State = enum { idle, done };
    const Event = union(enum) { finish };
    const Definition = fx.statechart.Definition(State, Event, void, void);
    const definition = Definition.init(.{
        .id = "test.machine",
        .version = 1,
        .initial = .idle,
        .states = &.{ .{ .id = .idle }, .{ .id = .done, .kind = .final } },
        .transitions = &.{.{ .id = "finish", .source = .idle, .event = .finish, .target = .done }},
    });
    const Machine = fx.statechart.Machine(Definition);
    const root = layer("test/StateMachine", Definition, &definition);
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    var runtime = try kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{ .causal_store = &causal });
    defer runtime.deinit();
    const decision = try runtime.run(step("test/StateMachine", Definition, .{ .snapshot = Machine.initial(&definition, {}, 1), .event = .finish }));
    try std.testing.expectEqual(State.done, decision.next.state);
    var snapshot = try causal.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    var found = false;
    for (snapshot.events) |event| if (event.kind == .statechart_event_recorded and std.mem.eql(u8, event.service_key, "test/StateMachine")) {
        found = true;
        break;
    };
    try std.testing.expect(found);
}
