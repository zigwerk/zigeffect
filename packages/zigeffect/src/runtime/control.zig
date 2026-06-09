pub const SuspensionKind = enum {
    timer,
    deferred,
    queue,
    signal,
    activity,
    external,
};

pub const Suspension = struct {
    kind: SuspensionKind,
    id: u64,
    label: []const u8 = "",
};

pub const RuntimeDecision = union(enum) {
    completed,
    suspended: Suspension,
    cancelled: []const u8,
};

pub const Cancellation = struct {
    requested: bool = false,
    reason_value: ?[]const u8 = null,

    pub fn init() Cancellation {
        return .{};
    }

    pub fn request(self: *Cancellation, reason_text: []const u8) void {
        self.requested = true;
        self.reason_value = reason_text;
    }

    pub fn isRequested(self: *const Cancellation) bool {
        return self.requested;
    }

    pub fn reason(self: *const Cancellation) ?[]const u8 {
        return self.reason_value;
    }
};
