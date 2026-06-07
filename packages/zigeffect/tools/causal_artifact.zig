const std = @import("std");

pub const supported_event_taxonomy_version: u32 = 1;

pub fn appendTaxonomyVersionWarning(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    artifact_label: []const u8,
    event_taxonomy_version: ?u32,
) std.mem.Allocator.Error!void {
    const version = event_taxonomy_version orelse return;
    if (version <= supported_event_taxonomy_version) return;
    try output.print(
        allocator,
        "warning: {s} event_taxonomy_version={d} newer than supported={d}; event-kind role semantics may be incomplete\n",
        .{ artifact_label, version, supported_event_taxonomy_version },
    );
}
