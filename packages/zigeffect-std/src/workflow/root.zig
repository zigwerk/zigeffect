const std = @import("std");
const fx = @import("zigeffect");
const Service = @import("../service/root.zig");

const kernel = fx.kernel;

pub const JournalApi = struct {
    pub const operations: []const []const u8 = &.{ "WorkflowJournal.append", "WorkflowJournal.read-all" };
    store: fx.workflow.JournalStore,
};
pub const Journal = kernel.Service("zigeffect/std/WorkflowJournal", JournalApi);

pub fn journalLayer(store: fx.workflow.JournalStore) @TypeOf(kernel.Layer.succeed(Journal, .{ .store = store })) {
    return kernel.Layer.succeed(Journal, .{ .store = store });
}

const AppendProgram = kernel.Effect(fx.workflow.JournalSequence, fx.workflow.JournalStoreAppendError, .{Journal}).Stateful(fx.workflow.JournalAppend);
pub fn append(request: fx.workflow.JournalAppend) AppendProgram {
    return AppendProgram.init(request, struct {
        fn run(input: fx.workflow.JournalAppend, ctx: *AppendProgram.Context) fx.workflow.JournalStoreAppendError!fx.workflow.JournalSequence {
            const sequence = ctx.service(Journal).store.append(input) catch |failure| {
                _ = Service.recordSemantic(ctx, .workflow_event_recorded, Journal.service_key, fx.workflow.workflowEventKindName(input.event.kind), "failure", @errorName(failure));
                return failure;
            };
            _ = ctx.recordCausal(.{
                .kind = .workflow_event_recorded,
                .service_key = Journal.service_key,
                .run_id = input.event.workflow_id,
                .scope_id = input.event.execution_id,
                .span_id = sequence,
                .label = fx.workflow.workflowEventKindName(input.event.kind),
                .status = "committed",
                .redacted_detail = "typed workflow journal event committed",
            });
            return sequence;
        }
    }.run);
}

pub const ReadAll = kernel.Effect(fx.workflow.JournalEventBatch, fx.workflow.JournalStoreReadError, .{Journal});
pub fn readAll() ReadAll {
    return ReadAll.fromFn(struct {
        fn run(ctx: *ReadAll.Context) fx.workflow.JournalStoreReadError!fx.workflow.JournalEventBatch {
            const events = try ctx.service(Journal).store.readAll(ctx.allocator());
            _ = Service.recordSemantic(ctx, .workflow_event_recorded, Journal.service_key, "WorkflowJournal.read-all", "success", "bounded journal replay loaded");
            return events;
        }
    }.run);
}

test "workflow journals are runtime services with causal append evidence" {
    var memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer memory.deinit();
    const root = journalLayer(memory.asJournalStore());
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    var runtime = try kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{ .causal_store = &causal });
    defer runtime.deinit();
    _ = try runtime.run(append(.{ .event = .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 9 } }));
    var events = try runtime.run(readAll());
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 1), events.events.len);
    var snapshot = try causal.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    var found = false;
    for (snapshot.events) |event| if (event.kind == .workflow_event_recorded and std.mem.eql(u8, event.service_key, Journal.service_key)) {
        found = true;
        break;
    };
    try std.testing.expect(found);
}
