pub const api = @import("api");
pub const worker = @import("worker");
pub const shared = @import("shared");
pub const Model = @import("model.zig").Model;
pub const CrashPoint = @import("model.zig").CrashPoint;
pub fn productionContract() bool { return shared.contract_version == 1 and api.productionContract() and worker.productionContract(); }
