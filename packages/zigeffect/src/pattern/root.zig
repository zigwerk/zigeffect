pub const matcher = @import("matcher.zig");

pub const any = matcher.any;
pub const matches = matcher.matches;
pub const capture = matcher.capture;
pub const bind = matcher.bind;
pub const range = matcher.range;
pub const predicate = matcher.predicate;
pub const some = matcher.some;
pub const none = matcher.none;
pub const Pattern = matcher.Pattern;
pub const RangeMode = matcher.RangeMode;
pub const Range = matcher.Range;
