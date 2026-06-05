const fx = @import("zigeffect");

const Env = struct {
    logger: fx.Logger,

    pub fn service(self: *Env, comptime Service: type) *Service {
        if (Service == fx.Logger) return &self.logger;
        return fx.serviceNotFound(Env, Service);
    }
};

pub fn main() void {
    var env: Env = undefined;
    _ = fx.Layer(Env).fromEnv(&env).provides(.{ fx.Logger, 123 });
}
