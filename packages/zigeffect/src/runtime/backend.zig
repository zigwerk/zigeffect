pub const BackendKind = enum {
    deterministic,
};

pub const BackendCapabilities = struct {
    kind: BackendKind,
    can_suspend: bool,
    can_interrupt_blocking_io: bool,
    can_supervise: bool,
    can_parallel: bool,
};

pub fn deterministicBackend() BackendCapabilities {
    return .{
        .kind = .deterministic,
        .can_suspend = false,
        .can_interrupt_blocking_io = false,
        .can_supervise = false,
        .can_parallel = false,
    };
}
