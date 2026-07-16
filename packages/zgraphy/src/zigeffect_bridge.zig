const std = @import("std");
const zstd = @import("zigeffect_std");

const kernel = zstd.fx.kernel;

pub const Link = struct {
    source_ref: []const u8,
    label: []const u8,
    status: []const u8 = "observed",
};

const LinkBase = kernel.Effect(void, error{}, .{});
pub const LinkEffect = LinkBase.Stateful(Link);

pub fn linkEffect(link: Link) LinkEffect {
    return LinkEffect.init(link, struct {
        fn run(value: Link, ctx: *LinkEffect.Context) error{}!void {
            _ = ctx.recordCausal(.{
                .kind = .activity_completed,
                .label = value.label,
                .status = value.status,
                .domain_entity_ref = value.source_ref,
                .redacted_detail = "zgraphy-source-link",
            });
        }
    }.run);
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
