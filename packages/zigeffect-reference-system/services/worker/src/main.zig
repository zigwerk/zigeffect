const std = @import("std");
const app = @import("app");

pub fn main(init: std.process.Init) !void {
    try app.run(init.gpa, init.io, init.minimal.environ);
}
