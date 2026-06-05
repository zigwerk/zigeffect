const std = @import("std");

pub const Allocator = std.mem.Allocator;

pub const Histogram = struct {
    count: usize = 0,
    sum: i64 = 0,
    min: i64 = 0,
    max: i64 = 0,

    pub fn observe(self: *Histogram, value: i64) void {
        if (self.count == 0) {
            self.min = value;
            self.max = value;
        } else {
            self.min = @min(self.min, value);
            self.max = @max(self.max, value);
        }
        self.count += 1;
        self.sum += value;
    }
};

pub const CounterSnapshot = struct {
    name: []const u8,
    value: i64,
};

pub const HistogramSnapshot = struct {
    name: []const u8,
    value: Histogram,
};

pub const MetricsSnapshot = struct {
    allocator: Allocator,
    counters: []CounterSnapshot,
    histograms: []HistogramSnapshot,

    pub fn deinit(self: *MetricsSnapshot) void {
        self.allocator.free(self.counters);
        self.allocator.free(self.histograms);
    }
};

pub const Metrics = struct {
    allocator: Allocator,
    counters: std.StringHashMap(i64),
    histograms: std.StringHashMap(Histogram),

    pub fn init(allocator: Allocator) Metrics {
        return .{
            .allocator = allocator,
            .counters = std.StringHashMap(i64).init(allocator),
            .histograms = std.StringHashMap(Histogram).init(allocator),
        };
    }

    pub fn deinit(self: *Metrics) void {
        var counter_iterator = self.counters.iterator();
        while (counter_iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.counters.deinit();

        var histogram_iterator = self.histograms.iterator();
        while (histogram_iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.histograms.deinit();
    }

    pub fn increment(self: *Metrics, name: []const u8, amount: i64) Allocator.Error!void {
        if (self.counters.getPtr(name)) |counter| {
            counter.* += amount;
            return;
        }

        try self.counters.put(try self.allocator.dupe(u8, name), amount);
    }

    pub fn get(self: *Metrics, name: []const u8) i64 {
        return self.counters.get(name) orelse 0;
    }

    pub fn gauge(self: *Metrics, name: []const u8, value: i64) Allocator.Error!void {
        if (self.counters.getPtr(name)) |counter| {
            counter.* = value;
            return;
        }

        try self.counters.put(try self.allocator.dupe(u8, name), value);
    }

    pub fn observe(self: *Metrics, name: []const u8, value: i64) Allocator.Error!void {
        if (self.histograms.getPtr(name)) |histogram_value| {
            histogram_value.observe(value);
            return;
        }

        var histogram_value = Histogram{};
        histogram_value.observe(value);
        try self.histograms.put(try self.allocator.dupe(u8, name), histogram_value);
    }

    pub fn histogram(self: *Metrics, name: []const u8) ?Histogram {
        return self.histograms.get(name);
    }

    pub fn snapshot(self: *Metrics, allocator: Allocator) Allocator.Error!MetricsSnapshot {
        const counters = try allocator.alloc(CounterSnapshot, self.counters.count());
        errdefer allocator.free(counters);
        const histograms = try allocator.alloc(HistogramSnapshot, self.histograms.count());
        errdefer allocator.free(histograms);

        var counter_index: usize = 0;
        var counter_iterator = self.counters.iterator();
        while (counter_iterator.next()) |entry| {
            counters[counter_index] = .{
                .name = entry.key_ptr.*,
                .value = entry.value_ptr.*,
            };
            counter_index += 1;
        }

        var histogram_index: usize = 0;
        var histogram_iterator = self.histograms.iterator();
        while (histogram_iterator.next()) |entry| {
            histograms[histogram_index] = .{
                .name = entry.key_ptr.*,
                .value = entry.value_ptr.*,
            };
            histogram_index += 1;
        }

        return .{
            .allocator = allocator,
            .counters = counters,
            .histograms = histograms,
        };
    }
};
