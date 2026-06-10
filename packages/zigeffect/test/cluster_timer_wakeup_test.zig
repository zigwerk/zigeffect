const std = @import("std");
const fx = @import("zigeffect");

test "cluster timer wakeup public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "timer_wakeup"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTimerWakeup"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTimerWakeupBatch"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTimerWakeupReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTimerWakeupIndex"));
    try std.testing.expect(@hasDecl(fx, "ClusterTimerWakeupIndex"));
}
