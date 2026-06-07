const std = @import("std");

pub const BigDecimal = struct {
    const Self = @This();

    pub const ParseError = error{InvalidBigDecimal};
    pub const Error = ParseError || std.mem.Allocator.Error;

    allocator: std.mem.Allocator,
    coefficient: []u8,
    scale: i32,
    negative: bool,

    pub fn parse(allocator: std.mem.Allocator, text: []const u8) Error!Self {
        if (text.len == 0) return error.InvalidBigDecimal;

        var index: usize = 0;
        var negative = false;
        if (text[index] == '-' or text[index] == '+') {
            negative = text[index] == '-';
            index += 1;
            if (index == text.len) return error.InvalidBigDecimal;
        }

        var digits = try allocator.alloc(u8, text.len);
        errdefer allocator.free(digits);

        var digit_count: usize = 0;
        var scale_count: usize = 0;
        var seen_decimal = false;
        while (index < text.len) : (index += 1) {
            const char = text[index];
            if (char == '.') {
                if (seen_decimal) return error.InvalidBigDecimal;
                seen_decimal = true;
                continue;
            }
            if (char < '0' or char > '9') return error.InvalidBigDecimal;
            digits[digit_count] = char;
            digit_count += 1;
            if (seen_decimal) scale_count += 1;
        }

        if (digit_count == 0) return error.InvalidBigDecimal;
        digits = try allocator.realloc(digits, digit_count);

        return .{
            .allocator = allocator,
            .coefficient = digits,
            .scale = @intCast(scale_count),
            .negative = negative,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.coefficient);
        self.coefficient = &.{};
    }

    pub fn coefficientDigits(self: Self) []const u8 {
        return self.coefficient;
    }

    pub fn scaleValue(self: Self) i32 {
        return self.scale;
    }

    pub fn isNegative(self: Self) bool {
        return self.negative;
    }

    pub fn format(self: Self, allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
        const sign_len: usize = if (self.negative) 1 else 0;
        if (self.scale <= 0) {
            const trailing_zeros: usize = @intCast(-self.scale);
            var rendered = try allocator.alloc(u8, sign_len + self.coefficient.len + trailing_zeros);
            var index: usize = 0;
            if (self.negative) {
                rendered[index] = '-';
                index += 1;
            }
            @memcpy(rendered[index..][0..self.coefficient.len], self.coefficient);
            index += self.coefficient.len;
            @memset(rendered[index..], '0');
            return rendered;
        }

        const scale_usize: usize = @intCast(self.scale);
        if (scale_usize >= self.coefficient.len) {
            const leading_zeros = scale_usize - self.coefficient.len;
            var rendered = try allocator.alloc(u8, sign_len + 2 + leading_zeros + self.coefficient.len);
            var index: usize = 0;
            if (self.negative) {
                rendered[index] = '-';
                index += 1;
            }
            rendered[index] = '0';
            index += 1;
            rendered[index] = '.';
            index += 1;
            @memset(rendered[index..][0..leading_zeros], '0');
            index += leading_zeros;
            @memcpy(rendered[index..], self.coefficient);
            return rendered;
        }

        const integer_digits = self.coefficient.len - scale_usize;
        var rendered = try allocator.alloc(u8, sign_len + self.coefficient.len + 1);
        var index: usize = 0;
        if (self.negative) {
            rendered[index] = '-';
            index += 1;
        }
        @memcpy(rendered[index..][0..integer_digits], self.coefficient[0..integer_digits]);
        index += integer_digits;
        rendered[index] = '.';
        index += 1;
        @memcpy(rendered[index..], self.coefficient[integer_digits..]);
        return rendered;
    }
};
