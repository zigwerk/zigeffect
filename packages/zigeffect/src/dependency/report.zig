const std = @import("std");

pub const Allocator = std.mem.Allocator;

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
