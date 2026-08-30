const alpha = @import("alpha.zig");
const beta = @import("beta.zig");

pub fn choose(use_alpha: bool) []const u8 {
    const loader = if (use_alpha) alpha.load else beta.load;
    return loader();
}
