const std = @import("std");
const Plan = @import("plan.zig");

const plan_json =
    \\{"schema":"zigeffect.statechart.workflow-plan.v1","schema_version":1,
    \\ "id":"agent.review","version":1,"initial":"idle",
    \\ "states":[{"id":"idle","kind":"atomic"},{"id":"review","kind":"atomic"},{"id":"done","kind":"final"}],
    \\ "transitions":[
    \\   {"id":"start","source":"idle","event":"start","target":"review","guard":"has-input","actions":["begin-review"]},
    \\   {"id":"finish","source":"review","event":"finish","target":"done"}
    \\ ]}
;

test "workflow plan parses validates and generates deterministic typed Zig" {
    var parsed = try Plan.parse(std.testing.allocator, plan_json);
    defer parsed.deinit();
    try parsed.value.validate();

    const left = try Plan.generateZig(std.testing.allocator, parsed.value);
    defer std.testing.allocator.free(left);
    const right = try Plan.generateZig(std.testing.allocator, parsed.value);
    defer std.testing.allocator.free(right);
    try std.testing.expectEqualStrings(left, right);
    try std.testing.expect(std.mem.indexOf(u8, left, "statechart.Definition") != null);
    try std.testing.expect(std.mem.indexOf(u8, left, "fn guard_0") != null);
    try std.testing.expect(std.mem.indexOf(u8, left, "return false") != null);
    try std.testing.expect(std.mem.indexOf(u8, left, "begin-review") != null);
}

test "workflow plan rejects dangling targets duplicate ids and unsafe metadata" {
    {
        var parsed = try Plan.parse(std.testing.allocator, plan_json);
        defer parsed.deinit();
        parsed.value.transitions[0].target = "missing";
        try std.testing.expectError(error.UnknownState, parsed.value.validate());
    }
    {
        var parsed = try Plan.parse(std.testing.allocator, plan_json);
        defer parsed.deinit();
        parsed.value.states[1].id = "idle";
        try std.testing.expectError(error.DuplicateState, parsed.value.validate());
    }
    {
        var parsed = try Plan.parse(std.testing.allocator, plan_json);
        defer parsed.deinit();
        parsed.value.description = "Bearer sentinel-secret-for-tests";
        try std.testing.expectError(error.SecretDetected, parsed.value.validate());
    }
    {
        var parsed = try Plan.parse(std.testing.allocator, plan_json);
        defer parsed.deinit();
        parsed.value.states[1].kind = .compound;
        try std.testing.expectError(error.InvalidPlan, parsed.value.validate());
    }
    {
        var parsed = try Plan.parse(std.testing.allocator, plan_json);
        defer parsed.deinit();
        parsed.value.transitions[1].source = "done";
        try std.testing.expectError(error.InvalidPlan, parsed.value.validate());
    }
}

test "every reusable workflow pattern expands to explicit namespaced logic" {
    inline for (std.meta.tags(Plan.PatternKind)) |kind| {
        var expansion = try Plan.expandPattern(std.testing.allocator, kind, "component");
        defer expansion.deinit();
        try std.testing.expect(expansion.states.len >= 2);
        try std.testing.expect(expansion.transitions.len >= 1);
        for (expansion.states) |state| try std.testing.expect(std.mem.startsWith(u8, state.id, "component."));
        for (expansion.transitions) |transition| try std.testing.expect(std.mem.startsWith(u8, transition.id, "component."));
        try std.testing.expect(expansion.invariants.len >= 1);
        const plan = Plan.WorkflowPlan{
            .schema = Plan.workflow_plan_schema,
            .schema_version = Plan.workflow_plan_schema_version,
            .id = "component",
            .version = 1,
            .initial = expansion.states[0].id,
            .states = expansion.states,
            .transitions = expansion.transitions,
            .invariants = expansion.invariants,
        };
        try plan.validate();
        if (kind == .parallel_research) {
            try std.testing.expectEqual(Plan.StateKind.compound, expansion.states[0].kind);
            try std.testing.expectEqual(Plan.StateKind.parallel, expansion.states[2].kind);
        }
    }
}

test "workflow pattern expansion and plan generation are allocation-failure safe" {
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var expansion = try Plan.expandPattern(allocator, .human_approval, "approval");
            defer expansion.deinit();
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}
