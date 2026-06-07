const std = @import("std");
const causal_run = @import("causal_run");

const proposal_suffix = "-scenario-proposal.json";
const registry_patch_suffix = "-registry-patch";

const Options = struct {
    proposal_path: []const u8,
};

const RegistryPatchPaths = struct {
    json: []const u8,
    text: []const u8,
    zig: []const u8,

    fn deinit(self: RegistryPatchPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
        allocator.free(self.zig);
    }
};

fn parseOptions(args: []const []const u8) !Options {
    if (args.len < 3) return error.MissingProposalPath;
    if (args.len > 3) return error.TooManyArguments;
    if (!std.mem.eql(u8, args[1], "--from-proposal")) return error.UnknownFlag;
    if (!std.mem.endsWith(u8, args[2], proposal_suffix)) return error.InvalidProposalPath;

    return .{ .proposal_path = args[2] };
}

fn registryPatchPathsFromProposal(allocator: std.mem.Allocator, proposal_path: []const u8) !RegistryPatchPaths {
    if (!std.mem.endsWith(u8, proposal_path, proposal_suffix)) return error.InvalidProposalPath;
    const prefix = proposal_path[0 .. proposal_path.len - proposal_suffix.len];

    const json = try std.fmt.allocPrint(allocator, "{s}{s}.json", .{ prefix, registry_patch_suffix });
    errdefer allocator.free(json);
    const text = try std.fmt.allocPrint(allocator, "{s}{s}.txt", .{ prefix, registry_patch_suffix });
    errdefer allocator.free(text);
    const zig = try std.fmt.allocPrint(allocator, "{s}{s}.zig", .{ prefix, registry_patch_suffix });

    return .{ .json = json, .text = text, .zig = zig };
}

fn identifierFromSlug(allocator: std.mem.Allocator, slug: []const u8) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    if (slug.len > 0 and slug[0] >= '0' and slug[0] <= '9') {
        try output.appendSlice(allocator, "scenario_");
    }

    var previous_underscore = false;
    for (slug) |byte| {
        const normalized = switch (byte) {
            'A'...'Z' => byte + 32,
            'a'...'z', '0'...'9' => byte,
            else => '_',
        };
        if (normalized == '_') {
            if (!previous_underscore and output.items.len > 0) try output.append(allocator, '_');
            previous_underscore = true;
        } else {
            try output.append(allocator, normalized);
            previous_underscore = false;
        }
    }

    while (output.items.len > 0 and output.items[output.items.len - 1] == '_') {
        output.items.len -= 1;
    }

    if (output.items.len == 0) try output.appendSlice(allocator, "scenario");
    return output.toOwnedSlice(allocator);
}

fn usage() []const u8 {
    return "usage: zig build causal-scenario-registry-patch -- --from-proposal <scenario-proposal.json>\n";
}

test "registry patch parses from-proposal option and rejects invalid shapes" {
    const options = try parseOptions(&.{
        "zigeffect-causal-scenario-registry-patch",
        "--from-proposal",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.json",
    });
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.json",
        options.proposal_path,
    );

    try std.testing.expectError(error.MissingProposalPath, parseOptions(&.{
        "zigeffect-causal-scenario-registry-patch",
    }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{
        "zigeffect-causal-scenario-registry-patch",
        "--proposal",
        "x.json",
    }));
    try std.testing.expectError(error.InvalidProposalPath, parseOptions(&.{
        "zigeffect-causal-scenario-registry-patch",
        "--from-proposal",
        "proposal.json",
    }));
}

test "registry patch output paths are derived from proposal path" {
    const paths = try registryPatchPathsFromProposal(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json",
    );
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json",
        paths.json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.txt",
        paths.text,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.zig",
        paths.zig,
    );
}

test "registry patch identifiers are stable Zig identifiers" {
    const identifier = try identifierFromSlug(std.testing.allocator, "learned-dogfood-service-resolution");
    defer std.testing.allocator.free(identifier);
    try std.testing.expectEqualStrings("learned_dogfood_service_resolution", identifier);

    const digit = try identifierFromSlug(std.testing.allocator, "123-example");
    defer std.testing.allocator.free(digit);
    try std.testing.expectEqualStrings("scenario_123_example", digit);
}
