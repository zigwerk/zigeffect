//! Hands a dying test's causal brief to whoever can decide to print it.
//!
//! The decision and the knowledge live in different places. `TestContext` knows
//! what the run did — which invariants were violated, in which scope, on which
//! fiber. Only the test runner knows whether the test *failed*, and it has to,
//! because a passing test may deliberately record a failure to exercise the
//! assertion machinery and `assertions.zig` contains one that does. So the
//! context stages unconditionally and the runner discards on every pass.
//!
//! The bridge is `@import("root")`, which in a test binary resolves to the
//! Testing v2 runner — the same mechanism that makes its `std_options` take
//! effect. That matters because `zigeffect-std` cannot import the runner: the
//! runner is supplied as a root source file to `addTest`, not as a module, and
//! a type-level dependency would be a cycle besides.
//!
//! Linked into an application, `root` is the application's main, the declaration
//! is absent, `enabled` is comptime false, and every call site here compiles to
//! nothing. No production binary carries a byte of this.

const std = @import("std");
const root = @import("root");

/// Whether the current binary has a runner that accepts briefs.
///
/// Pinned to an exact version rather than mere presence: a runner that changes
/// the contract should make this comptime-false and lose the feature loudly,
/// rather than pass bytes to something that no longer means the same thing.
pub const enabled = @hasDecl(root, "zigeffect_failure_brief_abi") and
    @TypeOf(root.zigeffect_failure_brief_abi) == u32 and
    root.zigeffect_failure_brief_abi == 1;

/// Stage `text` for the runner to print if this test turns out to have failed.
///
/// Infallible and allocation-free by contract. This runs inside `deinit`, on a
/// path that may already be unwinding an error, and a diagnostic that can fail
/// is one that turns a clear failure into a confusing one.
pub inline fn stage(text: []const u8) void {
    if (comptime !enabled) return;
    root.zigeffectStageFailureBrief(text);
}
