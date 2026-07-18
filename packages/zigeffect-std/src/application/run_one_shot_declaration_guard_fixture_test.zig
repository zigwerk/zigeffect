const LegacySignature = struct {
    pub fn runOneShot(
        comptime ApplicationLayer: type,
        comptime ServiceApp: type,
        allocator: std.mem.Allocator,
        io: std.Io,
        root: std.Io.Dir,
        application_layer: ApplicationLayer,
        application: ServiceApp,
        argv: []const []const u8,
        options: OneShotOptions,
    ) anyerror!OneShotResult(ServiceApp.SuccessType) {
        unreachable;
    }
};

pub fn runOneShot(
    comptime ApplicationLayer: type,
    comptime ServiceApp: type,
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    application_layer: ApplicationLayer,
    preflight: ServiceApp,
    argv: []const []const u8,
    options: OneShotOptions,
) anyerror!OneShotResult(ServiceApp.SuccessType) {
    unreachable;
}
