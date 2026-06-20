//! Effect ergonomics M1 — the small, daily-use combinators the EffectTS surface
//! exposes that this engine had not yet shipped. Each wrapper follows the same
//! Parent + run/exit structure as the existing MapEffect / TapEffect / etc., so
//! it composes naturally inside the existing pipeline.
//!
//! Milestones covered: M3.1 as / M3.2 replace / M3.3 asVoid / M3.4 andThen
//! (alias for flatMap; method on base Effect) / M3.8 when / M3.9 unless.

const std = @import("std");
const context_mod = @import("../core/context.zig");
const result_mod = @import("../core/result.zig");

pub const Context = context_mod.Context;
pub const Exit = result_mod.Exit;

// Forward-declared wrappers that AsEffect / WhenEffect chain into. The full
// `effect.zig` imports this module and references `AsEffect` / `WhenEffect`;
// `MapEffect` / `FlatMapEffect` are defined in `effect.zig` and looked up
// lazily via `@import` inside the methods (no cycle: `effect.zig` does NOT
// re-import this module from inside the chained methods).
const effect_mod = @import("effect.zig");

/// Runs the parent for its side effect, discards its success, returns a stored
/// constant. Implements `as` / `replace` (`asVoid` is the void specialization).
pub fn AsEffect(comptime Parent: type, comptime NewSuccess: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = NewSuccess;
        pub const FailureType = Parent.FailureType;
        pub const EnvType = Env;

        parent: Parent,
        replacement: NewSuccess,

        pub fn run(self: Self, ctx: *Context(Env)) Parent.FailureType!NewSuccess {
            _ = try self.parent.run(ctx);
            return self.replacement;
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(NewSuccess, Parent.FailureType) {
            const parent_exit = self.parent.exit(ctx);
            return switch (parent_exit) {
                .success => .{ .success = self.replacement },
                .failure => |err| .{ .failure = err },
                .interrupted => .interrupted,
                .defect => |msg| .{ .defect = msg },
            };
        }

        // Chainable into the existing pipeline — matches the convention of
        // every other Effect wrapper (TapEffect, OnExitEffect, etc.).
        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (NewSuccess) Next,
        ) effect_mod.MapEffect(Self, Next, Parent.FailureType, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn flatMap(
            self: Self,
            comptime Next: type,
            binder: *const fn (NewSuccess, *Context(Env)) Parent.FailureType!Next,
        ) effect_mod.FlatMapEffect(Self, Next, Parent.FailureType, Env) {
            return .{ .parent = self, .binder = binder };
        }
    };
}

/// Runs the parent only if `cond` is true; returns `?Success` (null when skipped).
/// `unless` is the inverse, implemented as `WhenEffect` with the condition flipped
/// at the factory site.
pub fn WhenEffect(comptime Parent: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = ?Parent.SuccessType;
        pub const FailureType = Parent.FailureType;
        pub const EnvType = Env;

        parent: Parent,
        cond: bool,

        pub fn run(self: Self, ctx: *Context(Env)) Parent.FailureType!?Parent.SuccessType {
            if (!self.cond) return null;
            const value = try self.parent.run(ctx);
            return value;
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(?Parent.SuccessType, Parent.FailureType) {
            if (!self.cond) return .{ .success = null };
            const parent_exit = self.parent.exit(ctx);
            return switch (parent_exit) {
                .success => |value| .{ .success = value },
                .failure => |err| .{ .failure = err },
                .interrupted => .interrupted,
                .defect => |msg| .{ .defect = msg },
            };
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (?Parent.SuccessType) Next,
        ) effect_mod.MapEffect(Self, Next, Parent.FailureType, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn flatMap(
            self: Self,
            comptime Next: type,
            binder: *const fn (?Parent.SuccessType, *Context(Env)) Parent.FailureType!Next,
        ) effect_mod.FlatMapEffect(Self, Next, Parent.FailureType, Env) {
            return .{ .parent = self, .binder = binder };
        }
    };
}
