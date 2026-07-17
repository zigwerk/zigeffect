const std = @import("std");
const zstd = @import("zigeffect_std");

const kernel = zstd.fx.kernel;

pub const Link = struct {
    source_ref: []const u8,
    label: []const u8,
    status: []const u8 = "observed",
};

pub const RecordingError = std.mem.Allocator.Error || error{
    InjectedSourceLinkRecordingFailure,
    InvalidSourceLinkStatus,
};

pub const Fake = struct {
    calls: usize = 0,
    last_event: ?zstd.fx.CausalEvent = null,
    fail_recording: bool = false,

    fn record(self: *Fake, event: zstd.fx.CausalEvent) RecordingError!void {
        self.calls += 1;
        if (self.fail_recording) return error.InjectedSourceLinkRecordingFailure;
        self.last_event = event;
    }
};

pub const SourceLinkEventsApi = union(enum) {
    pub const operations: []const []const u8 = &.{"SourceLinkEvents.record"};

    live: kernel.CausalRecorder,
    fake: *Fake,

    pub fn record(self: SourceLinkEventsApi, link: Link) RecordingError!void {
        if (!std.mem.eql(u8, link.status, "observed")) return error.InvalidSourceLinkStatus;
        const event = sourceLinkEvent(link);
        switch (self) {
            .live => |recorder| _ = try recorder.record(event),
            .fake => |fake| try fake.record(event),
        }
    }
};

pub const SourceLinkEvents = kernel.Service("zgraphy/SourceLinkEvents", SourceLinkEventsApi);

const LiveFactory = struct {
    fn make(ctx: *kernel.ContextView(.{})) SourceLinkEventsApi {
        return .{ .live = ctx.causalRecorder() };
    }
};

pub fn liveLayer() @TypeOf(kernel.Layer.sync(SourceLinkEvents, .{}, LiveFactory.make)) {
    return kernel.Layer.sync(SourceLinkEvents, .{}, LiveFactory.make);
}

pub fn fakeLayer(fake: *Fake) @TypeOf(kernel.Layer.succeed(SourceLinkEvents, SourceLinkEventsApi{ .fake = fake })) {
    return kernel.Layer.succeed(SourceLinkEvents, .{ .fake = fake });
}

const LinkBase = kernel.Effect(void, RecordingError, .{SourceLinkEvents});
pub const LinkEffect = LinkBase.Stateful(Link);

pub fn linkEffect(link: Link) LinkEffect {
    return LinkEffect.init(link, struct {
        fn run(value: Link, ctx: *LinkEffect.Context) RecordingError!void {
            try ctx.service(SourceLinkEvents).record(value);
        }
    }.run);
}

fn sourceLinkEvent(link: Link) zstd.fx.CausalEvent {
    return .{
        .kind = .span_recorded,
        .type_name = "zgraphy.source.link",
        .service_key = SourceLinkEvents.service_key,
        .label = link.label,
        .status = link.status,
        .domain_entity_ref = link.source_ref,
        .redacted_detail = "bounded zgraphy source link observed",
    };
}

pub fn sourceRefAlloc(allocator: std.mem.Allocator, path: []const u8, symbol: []const u8) ![]u8 {
    try validatePath(path);
    try validateSymbol(symbol);
    return std.fmt.allocPrint(allocator, "zgraphy://source/{s}#{s}", .{ path, symbol });
}

fn validatePath(path: []const u8) !void {
    if (path.len == 0 or path.len > 4096 or path[0] == '/' or
        std.mem.indexOf(u8, path, "..") != null or
        std.mem.indexOfScalar(u8, path, '\\') != null or
        std.mem.indexOfScalar(u8, path, '#') != null)
    {
        return error.InvalidSourcePath;
    }
}

fn validateSymbol(symbol: []const u8) !void {
    if (symbol.len == 0 or symbol.len > 256) return error.InvalidSymbol;
    for (symbol) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '.' or byte == '-') continue;
        return error.InvalidSymbol;
    }
}
