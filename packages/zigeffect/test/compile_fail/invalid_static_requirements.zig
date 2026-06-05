const fx = @import("zigeffect");

const Provider = fx.ProvidedLayer(fx.Layer(fx.TestServices), .{fx.Logger});
const Consumer = @TypeOf(
    fx.Effect(u32, error{}, fx.TestServices)
        .succeed(1)
        .requires(.{ fx.Logger, fx.Config }),
);

comptime {
    fx.assertStaticRequirementsSatisfied(Provider, Consumer);
}

pub fn main() void {}
