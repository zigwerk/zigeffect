const fx = @import("zigeffect");

const Declared = fx.kernel.Service("compile/Declared", struct {});
const Undeclared = fx.kernel.Service("compile/Undeclared", struct {});

const Program = fx.kernel.Effect(void, error{}, .{Declared});
const program = Program.fromFn(struct {
    fn run(ctx: *Program.Context) error{}!void {
        _ = ctx.service(Undeclared);
    }
}.run);

pub fn main() void {
    _ = program;
}
