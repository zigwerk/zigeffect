const fx = @import("zigeffect");

const Resource = struct {
    id: u32,
};

const ResourceError = error{Boom};

fn acquire(ctx: *fx.Context(fx.TestServices)) ResourceError!*Resource {
    return ctx.allocator.create(Resource) catch error.Boom;
}

fn release(resource: *Resource) void {
    resource.id = 0;
}

pub fn main() void {
    _ = fx.acquireRelease(
        Resource,
        ResourceError,
        fx.TestServices,
        acquire,
        release,
    );
}
