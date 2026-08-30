const std = @import("std");
const fx = @import("zigeffect");

const EnvA = struct {
    pub fn service(self: *EnvA, comptime Service: type) *Service {
        _ = self;
        return fx.serviceNotFound(EnvA, Service);
    }
};

const EnvB = struct {
    pub fn service(self: *EnvB, comptime Service: type) *Service {
        _ = self;
        return fx.serviceNotFound(EnvB, Service);
    }
};

const CombinedEnv = struct {
    pub fn service(self: *CombinedEnv, comptime Service: type) *Service {
        _ = self;
        return fx.serviceNotFound(CombinedEnv, Service);
    }
};

fn badMerge(_: std.mem.Allocator, _: *EnvA, _: *EnvB) std.mem.Allocator.Error!*CombinedEnv {
    return error.OutOfMemory;
}

pub fn main() void {
    var env_a = EnvA{};
    var env_b = EnvB{};
    const layer_a = fx.Layer(EnvA).fromEnv(&env_a);
    const layer_b = fx.Layer(EnvB).fromEnv(&env_b);
    _ = layer_a.merge(EnvB, CombinedEnv, layer_b, badMerge);
}
