pub const BackendKind = enum {
    deterministic,
    durable_local,
    async_local,
    clustered,
};

pub const BackendCapabilities = struct {
    kind: BackendKind,
    can_suspend: bool,
    can_wake: bool,
    can_schedule_timers: bool,
    can_interrupt: bool,
    can_durable_suspend: bool,
    can_interrupt_blocking_io: bool,
    can_supervise: bool,
    can_parallel: bool,
    can_persist: bool,
    can_distribute: bool,
};

pub fn deterministicBackend() BackendCapabilities {
    return .{
        .kind = .deterministic,
        .can_suspend = false,
        .can_wake = false,
        .can_schedule_timers = false,
        .can_interrupt = false,
        .can_durable_suspend = false,
        .can_interrupt_blocking_io = false,
        .can_supervise = false,
        .can_parallel = false,
        .can_persist = false,
        .can_distribute = false,
    };
}

pub fn durableLocalBackend() BackendCapabilities {
    return .{
        .kind = .durable_local,
        .can_suspend = true,
        .can_wake = true,
        .can_schedule_timers = true,
        .can_interrupt = true,
        .can_durable_suspend = true,
        .can_interrupt_blocking_io = false,
        .can_supervise = false,
        .can_parallel = false,
        .can_persist = true,
        .can_distribute = false,
    };
}

pub fn asyncLocalBackend() BackendCapabilities {
    return .{
        .kind = .async_local,
        .can_suspend = true,
        .can_wake = true,
        .can_schedule_timers = true,
        .can_interrupt = true,
        .can_durable_suspend = false,
        .can_interrupt_blocking_io = true,
        .can_supervise = true,
        .can_parallel = true,
        .can_persist = false,
        .can_distribute = false,
    };
}

pub fn clusteredBackend() BackendCapabilities {
    return .{
        .kind = .clustered,
        .can_suspend = true,
        .can_wake = true,
        .can_schedule_timers = true,
        .can_interrupt = true,
        .can_durable_suspend = true,
        .can_interrupt_blocking_io = true,
        .can_supervise = true,
        .can_parallel = true,
        .can_persist = true,
        .can_distribute = true,
    };
}
