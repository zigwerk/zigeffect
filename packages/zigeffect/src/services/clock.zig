const std = @import("std");

pub const Clock = struct {
    const Mode = enum {
        fake,
        system,
    };

    mode: Mode = .fake,
    current_ms: u64 = 0,

    pub fn fake(start_ms: u64) Clock {
        return .{ .mode = .fake, .current_ms = start_ms };
    }

    pub fn system() Clock {
        return .{ .mode = .system };
    }

    pub fn nowMs(self: *const Clock) u64 {
        return switch (self.mode) {
            .fake => self.current_ms,
            .system => {
                var tv: std.c.timeval = undefined;
                if (std.c.gettimeofday(&tv, null) != 0) return 0;
                return (@as(u64, @intCast(tv.sec)) * std.time.ms_per_s) + @as(u64, @intCast(@divTrunc(tv.usec, std.time.us_per_ms)));
            },
        };
    }

    pub fn sleep(self: *Clock, delay_ms: u64) void {
        switch (self.mode) {
            .fake => self.current_ms += delay_ms,
            .system => {
                const seconds = delay_ms / std.time.ms_per_s;
                const remaining_ms = delay_ms % std.time.ms_per_s;
                const ns = std.math.mul(u64, remaining_ms, std.time.ns_per_ms) catch std.math.maxInt(u64);
                var request = std.c.timespec{
                    .sec = @intCast(seconds),
                    .nsec = @intCast(ns),
                };
                while (std.c.nanosleep(&request, &request) != 0) {}
            },
        }
    }
};

pub const FakeClock = Clock;
