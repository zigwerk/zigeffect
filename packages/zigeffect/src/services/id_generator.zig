pub const IdGenerator = struct {
    next_value: u64 = 1,

    pub fn init(start: u64) IdGenerator {
        return .{ .next_value = start };
    }

    pub fn peek(self: *const IdGenerator) u64 {
        return self.next_value;
    }

    pub fn next(self: *IdGenerator) u64 {
        const value = self.next_value;
        self.next_value += 1;
        return value;
    }

    pub fn reset(self: *IdGenerator, start: u64) void {
        self.next_value = start;
    }
};
