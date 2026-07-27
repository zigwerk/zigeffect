//! ZigEffect Testing v2 runner for Zig 0.16 unit tests.
//!
//! The Zig server protocol behavior intentionally tracks Zig's default runner.
//! ZigEffect adds fail-closed, atomic suite receipts without changing the test
//! functions or their use of `std.testing`. Focused selection is performed at
//! compile time through a package's `-Dtest-filter=<text>` build option, so the
//! receipt still has equal discovered/executed counts and no artificial
//! pending tests.
const builtin = @import("builtin");

const std = @import("std");
const Io = std.Io;
const fatal = std.process.fatal;
const testing = std.testing;
const assert = std.debug.assert;
const panicFmt = std.debug.panic;
const fuzz_abi = std.Build.abi.fuzz;

const ReceiptStatus = enum { passed, skipped, failed, pending };
const ReceiptTestResult = struct {
    index: u32,
    id: []const u8,
    status: ReceiptStatus,
    error_name: ?[]const u8 = null,
    log_error_count: u32 = 0,
    leak_count: u32 = 0,
    duration_ms: u64 = 0,
};
const ReceiptCounts = struct {
    discovered: u32,
    executed: u32,
    passed: u32,
    skipped: u32,
    failed: u32,
    pending: u32,
    log_errors: u32,
    leaks: u32,
};
const ReceiptExecution = struct {
    zig_version: []const u8,
    target: []const u8,
    optimize: []const u8,
    seed: u32,
    runner_version: []const u8 = "2.0.0",
    replay_command: []const u8,
};
const ReceiptWire = struct {
    schema: []const u8 = "zigeffect.test-suite-receipt.v2",
    schema_version: u32 = 2,
    suite: []const u8,
    status: ReceiptStatus,
    complete: bool,
    started_ms: i64,
    ended_ms: i64,
    duration_ms: u64,
    execution: ReceiptExecution,
    counts: ReceiptCounts,
    tests: []const ReceiptTestResult,
    limitations: []const []const u8 = &.{},
};

// std.testing.allocator hardcodes stack_trace_frames = 10 and, unlike the
// normal DebugAllocator default, does not drop it outside Debug — so every
// alloc, free and resize captures 10+ frames in every optimize mode. On
// aarch64-macOS each frame costs a dyld image lookup plus a global mutex.
// Measured on the zgraphy suite in ReleaseSafe: 72.7s with capture, 4.5s
// without. It was 94% of the runtime.
//
// Leak DETECTION does not depend on it. Verified with a deliberate leak: the
// receipt still reports leaks: 1, still names the leaking test, still counts
// the allocations, and the suite still fails. Only the allocation SITE is
// lost. So keep capture in Debug — the mode you already switch to when you
// need that site — and stay fast everywhere else.
pub const std_options: std.Options = .{
    .logFn = log,
    .allow_stack_tracing = builtin.mode == .Debug,
};

/// Index of the test currently executing, so a panic can name the test that
/// caused it instead of leaving the whole suite ambiguous.
var running_index: ?u32 = null;
var panic_publishing: bool = false;

/// A panic aborts the process before either `.exit` arm reaches
/// `publishSuiteReceipt`, so the receipt is never rewritten and the PREVIOUS
/// run's file survives on disk still claiming `complete: true, passed: true`.
/// `zigeffect test affected` and `project check --agent` both read that file,
/// so a panicking suite reads green — precisely the failure this receipt format
/// exists to make impossible.
///
/// Publish an honest receipt, then panic exactly as before. The panicking test
/// is marked `failed` with `error_name = "panic"`, and anything the suite never
/// reached stays `pending`. Either way `passed` is false and the accounting
/// names the test that died, which is the whole point: a receipt that says
/// "something went wrong somewhere" costs a reader the same turn as no receipt.
///
/// Deliberately no causal store walk and no new allocator: the process is
/// already broken, and reading its state here would turn one failure into two.
pub const panic = std.debug.FullPanic(publishThenPanic);

fn publishThenPanic(msg: []const u8, first_trace_addr: ?usize) noreturn {
    @branchHint(.cold);
    if (!panic_publishing) {
        panic_publishing = true; // A panic raised while publishing must not recurse.
        // Before marking anything: the results array does not exist until this
        // runs, and a process that panics before `.query_test_metadata` has none.
        // Marking first silently did nothing and left the culprit as `pending`.
        initializeResults();
        if (running_index) |index| {
            if (index < suite_results.len) {
                suite_results[index].status = .failed;
                suite_results[index].error_name = "panic";
            }
        }
        publishSuiteReceipt() catch {};
    }
    std.debug.defaultPanic(msg, first_trace_addr);
}

var log_err_count: usize = 0;
var fba: std.heap.FixedBufferAllocator = .init(&fba_buffer);
var fba_buffer: [8192]u8 = undefined;
var stdin_buffer: [4096]u8 = undefined;
var stdout_buffer: [4096]u8 = undefined;
var stdin_reader: Io.File.Reader = undefined;
var stdout_writer: Io.File.Writer = undefined;
const runner_threaded_io: Io = Io.Threaded.global_single_threaded.io();
var suite_results: []ReceiptTestResult = &.{};
var suite_name: []const u8 = "zigeffect-tests";
var suite_receipt_path: []const u8 = ".zigeffect/tests/suites/zigeffect-tests.json";
var suite_replay_command: []const u8 = "zig build test";
var suite_started_ms: i64 = 0;
var suite_initialized = false;

/// Keep in sync with logic in `std.Build.addRunArtifact` which decides whether
/// the test runner will communicate with the build runner via `std.zig.Server`.
const need_simple = switch (builtin.zig_backend) {
    .stage2_aarch64,
    .stage2_powerpc,
    .stage2_riscv64,
    => true,
    else => false,
};

pub fn main(init: std.process.Init.Minimal) void {
    @disableInstrumentation();

    if (builtin.cpu.arch.isSpirV()) {
        // SPIR-V needs an special test-runner
        return;
    }

    if (need_simple) {
        return mainSimple() catch |err| panicFmt("test failure: {t}", .{err});
    }

    configureSuite(init);
    const args = init.args.toSlice(fba.allocator()) catch |err| panicFmt("unable to parse command line args: {t}", .{err});

    var listen = false;
    var opt_cache_dir: ?[]const u8 = null;

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--listen=-")) {
            listen = true;
        } else if (std.mem.startsWith(u8, arg, "--seed=")) {
            testing.random_seed = std.fmt.parseUnsigned(u32, arg["--seed=".len..], 0) catch
                @panic("unable to parse --seed command line argument");
        } else if (std.mem.startsWith(u8, arg, "--cache-dir")) {
            opt_cache_dir = arg["--cache-dir=".len..];
        } else {
            panicFmt("unrecognized command line argument: {s}", .{arg});
        }
    }

    if (builtin.fuzz) {
        const cache_dir = opt_cache_dir orelse @panic("missing --cache-dir=[path] argument");
        fuzz_abi.fuzzer_init(.fromSlice(cache_dir));
    }

    if (listen) {
        return mainServer(init) catch |err| panicFmt("internal test runner failure: {t}", .{err});
    } else {
        return mainTerminal(init);
    }
}
fn mainServer(init: std.process.Init.Minimal) !void {
    @disableInstrumentation();
    stdin_reader = .initStreaming(.stdin(), runner_threaded_io, &stdin_buffer);
    stdout_writer = .initStreaming(.stdout(), runner_threaded_io, &stdout_buffer);
    var server = try std.zig.Server.init(.{
        .in = &stdin_reader.interface,
        .out = &stdout_writer.interface,
        .zig_version = builtin.zig_version_string,
    });

    while (true) {
        const hdr = try server.receiveMessage();
        switch (hdr.tag) {
            .exit => {
                publishSuiteReceipt() catch |err| {
                    std.debug.print("ZigEffect Testing v2 failed to publish suite receipt: {t}\n", .{err});
                    return std.process.exit(1);
                };
                return std.process.exit(0);
            },
            .query_test_metadata => {
                testing.allocator_instance = .{};
                defer if (testing.allocator_instance.deinit() == .leak) {
                    @panic("internal test runner memory leak");
                };

                var string_bytes: std.ArrayList(u8) = .empty;
                defer string_bytes.deinit(testing.allocator);
                try string_bytes.append(testing.allocator, 0); // Reserve 0 for null.

                const test_fns = builtin.test_functions;
                const names = try testing.allocator.alloc(u32, test_fns.len);
                defer testing.allocator.free(names);
                const expected_panic_msgs = try testing.allocator.alloc(u32, test_fns.len);
                defer testing.allocator.free(expected_panic_msgs);

                for (test_fns, names, expected_panic_msgs) |test_fn, *name, *expected_panic_msg| {
                    name.* = @intCast(string_bytes.items.len);
                    try string_bytes.ensureUnusedCapacity(testing.allocator, test_fn.name.len + 1);
                    string_bytes.appendSliceAssumeCapacity(test_fn.name);
                    string_bytes.appendAssumeCapacity(0);
                    expected_panic_msg.* = 0;
                }

                initializeResults();

                try server.serveTestMetadata(.{
                    .names = names,
                    .expected_panic_msgs = expected_panic_msgs,
                    .string_bytes = string_bytes.items,
                });
            },

            .run_test => {
                testing.environ = init.environ;
                testing.allocator_instance = .{};
                testing.io_instance = .init(testing.allocator, .{
                    .argv0 = .init(init.args),
                    .environ = init.environ,
                });
                log_err_count = 0;
                const index = try server.receiveBody_u32();
                // The build runner restarts this binary after a crash and can
                // send .run_test without repeating .query_test_metadata, so the
                // results array may not exist yet. Indexing it then panics
                // inside the runner and buries whatever the test was reporting.
                initializeResults();
                const test_fn = builtin.test_functions[index];
                is_fuzz_test = false;
                const test_started = Io.Clock.awake.now(runner_threaded_io);

                // let the build server know we're starting the test now
                try server.serveStringMessage(.test_started, &.{});

                const TestResults = std.zig.Server.Message.TestResults;
                var error_name: ?[]const u8 = null;
                running_index = index;
                defer running_index = null;
                const status: TestResults.Status = if (test_fn.func()) |v| s: {
                    v;
                    break :s .pass;
                } else |err| switch (err) {
                    error.SkipZigTest => .skip,
                    else => s: {
                        error_name = @errorName(err);
                        if (@errorReturnTrace()) |trace| {
                            std.debug.dumpErrorReturnTrace(trace);
                        }
                        break :s .fail;
                    },
                };
                testing.io_instance.deinit();
                const leak_count = testing.allocator_instance.detectLeaks();
                testing.allocator_instance.deinitWithoutLeakChecks();
                const test_ended = Io.Clock.awake.now(runner_threaded_io);
                suite_results[index] = .{
                    .index = index,
                    .id = test_fn.name,
                    .status = switch (status) {
                        .pass => .passed,
                        .skip => .skipped,
                        .fail => .failed,
                    },
                    .error_name = error_name,
                    .log_error_count = @intCast(log_err_count),
                    .leak_count = @intCast(leak_count),
                    .duration_ms = @intCast(@max(0, test_started.durationTo(test_ended).toMilliseconds())),
                };
                try server.serveTestResults(.{
                    .index = index,
                    .flags = .{
                        .status = status,
                        .fuzz = is_fuzz_test,
                        .log_err_count = std.math.lossyCast(
                            @FieldType(TestResults.Flags, "log_err_count"),
                            log_err_count,
                        ),
                        .leak_count = std.math.lossyCast(
                            @FieldType(TestResults.Flags, "leak_count"),
                            leak_count,
                        ),
                    },
                });
            },
            .start_fuzzing => {
                // This ensures that this code won't be analyzed and hence reference fuzzer symbols
                // since they are not present.
                if (!builtin.fuzz) unreachable;

                var gpa_instance: std.heap.DebugAllocator(.{}) = .init;
                defer if (gpa_instance.deinit() == .leak) {
                    @panic("internal test runner memory leak");
                };
                const gpa = gpa_instance.allocator();
                var io_instance: Io.Threaded = .init(gpa, .{
                    .argv0 = .init(init.args),
                    .environ = init.environ,
                });
                defer io_instance.deinit();
                const io = io_instance.io();

                const mode: fuzz_abi.LimitKind = @enumFromInt(try server.receiveBody_u8());
                const amount_or_instance = try server.receiveBody_u64();
                const main_instance = mode == .iterations or amount_or_instance == 0;

                if (main_instance) {
                    const coverage = fuzz_abi.fuzzer_coverage();
                    try server.serveCoverageIdMessage(
                        coverage.id,
                        coverage.runs,
                        coverage.unique,
                        coverage.seen,
                    );
                }

                const n_tests: u32 = try server.receiveBody_u32();
                const test_indexes = try gpa.alloc(u32, n_tests);
                defer gpa.free(test_indexes);
                fuzz_runner = .{
                    .indexes = test_indexes,
                    .server = &server,
                    .gpa = gpa,
                    .io = io,
                    .input_poller = undefined,
                };

                {
                    var large_name_buf: std.ArrayList(u8) = .empty;
                    defer large_name_buf.deinit(gpa);
                    for (test_indexes) |*i| {
                        const name_len = try server.receiveBody_u32();
                        const name = if (name_len <= server.in.buffer.len)
                            try server.in.take(name_len)
                        else large_name: {
                            try large_name_buf.resize(gpa, name_len);
                            try server.in.readSliceAll(large_name_buf.items);
                            break :large_name large_name_buf.items;
                        };

                        for (0.., builtin.test_functions) |test_i, test_fn| {
                            if (std.mem.eql(u8, name, test_fn.name)) {
                                i.* = @intCast(test_i);
                                break;
                            }
                        } else {
                            panicFmt("fuzz test {s} no longer exists", .{name});
                        }

                        if (main_instance) {
                            const relocated_entry_addr = @intFromPtr(builtin.test_functions[i.*].func);
                            const entry_addr = fuzz_abi.fuzzer_unslide_address(relocated_entry_addr);
                            try server.serveU64Message(.fuzz_start_addr, entry_addr);
                        }
                    }
                }

                fuzz_abi.fuzzer_main(n_tests, testing.random_seed, mode, amount_or_instance);

                assert(mode != .forever);
                std.process.exit(0);
            },

            else => {
                std.debug.print("unsupported message: {x}\n", .{@intFromEnum(hdr.tag)});
                std.process.exit(1);
            },
        }
    }
}

fn mainTerminal(init: std.process.Init.Minimal) void {
    @disableInstrumentation();
    if (builtin.fuzz) @panic("fuzz test requires server");

    const test_fn_list = builtin.test_functions;
    initializeResults();
    var ok_count: usize = 0;
    var skip_count: usize = 0;
    var fail_count: usize = 0;
    var fuzz_count: usize = 0;
    const root_node = if (builtin.fuzz) std.Progress.Node.none else std.Progress.start(runner_threaded_io, .{
        .root_name = "Test",
        .estimated_total_items = test_fn_list.len,
    });
    const have_tty = Io.File.stderr().isTty(runner_threaded_io) catch unreachable;

    var leaks: usize = 0;
    for (test_fn_list, 0..) |test_fn, i| {
        testing.allocator_instance = .{};
        testing.io_instance = .init(testing.allocator, .{
            .argv0 = .init(init.args),
            .environ = init.environ,
        });
        defer {
            testing.io_instance.deinit();
            if (testing.allocator_instance.deinit() == .leak) leaks += 1;
        }
        testing.log_level = .warn;
        testing.environ = init.environ;

        const test_node = root_node.start(test_fn.name, 0);
        if (!have_tty) {
            std.debug.print("{d}/{d} {s}...", .{ i + 1, test_fn_list.len, test_fn.name });
        }
        is_fuzz_test = false;
        const test_started = Io.Clock.awake.now(runner_threaded_io);
        log_err_count = 0;
        var result_status: ReceiptStatus = .passed;
        var error_name: ?[]const u8 = null;
        running_index = @intCast(i);
        defer running_index = null;
        if (test_fn.func()) |_| {
            ok_count += 1;
            test_node.end();
            if (!have_tty) std.debug.print("OK\n", .{});
        } else |err| switch (err) {
            error.SkipZigTest => {
                result_status = .skipped;
                skip_count += 1;
                if (have_tty) {
                    std.debug.print("{d}/{d} {s}...SKIP\n", .{ i + 1, test_fn_list.len, test_fn.name });
                } else {
                    std.debug.print("SKIP\n", .{});
                }
                test_node.end();
            },
            else => {
                result_status = .failed;
                error_name = @errorName(err);
                fail_count += 1;
                if (have_tty) {
                    std.debug.print("{d}/{d} {s}...FAIL ({t})\n", .{
                        i + 1, test_fn_list.len, test_fn.name, err,
                    });
                } else {
                    std.debug.print("FAIL ({t})\n", .{err});
                }
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpErrorReturnTrace(trace);
                }
                test_node.end();
            },
        }
        const test_ended = Io.Clock.awake.now(runner_threaded_io);
        const leak_count = testing.allocator_instance.detectLeaks();
        suite_results[i] = .{
            .index = @intCast(i),
            .id = test_fn.name,
            .status = result_status,
            .error_name = error_name,
            .log_error_count = @intCast(log_err_count),
            .leak_count = @intCast(leak_count),
            .duration_ms = @intCast(@max(0, test_started.durationTo(test_ended).toMilliseconds())),
        };
        fuzz_count += @intFromBool(is_fuzz_test);
    }
    root_node.end();
    if (ok_count == test_fn_list.len) {
        std.debug.print("All {d} tests passed.\n", .{ok_count});
    } else {
        std.debug.print("{d} passed; {d} skipped; {d} failed.\n", .{ ok_count, skip_count, fail_count });
    }
    if (log_err_count != 0) {
        std.debug.print("{d} errors were logged.\n", .{log_err_count});
    }
    if (leaks != 0) {
        std.debug.print("{d} tests leaked memory.\n", .{leaks});
    }
    if (fuzz_count != 0) {
        std.debug.print("{d} fuzz tests found.\n", .{fuzz_count});
    }
    publishSuiteReceipt() catch |err| {
        std.debug.print("ZigEffect Testing v2 failed to publish suite receipt: {t}\n", .{err});
        std.process.exit(1);
    };
    if (leaks != 0 or log_err_count != 0 or fail_count != 0) {
        std.process.exit(1);
    }
}

fn configureSuite(init: std.process.Init.Minimal) void {
    const argv = init.args.toSlice(std.heap.page_allocator) catch &.{};
    const inferred_suite = if (argv.len == 0) suite_name else std.fs.path.basename(argv[0]);
    suite_name = init.environ.getAlloc(std.heap.page_allocator, "ZIGEFFECT_TEST_SUITE") catch inferred_suite;
    const inferred_path = std.fmt.allocPrint(std.heap.page_allocator, ".zigeffect/tests/suites/{s}.json", .{suite_name}) catch suite_receipt_path;
    suite_receipt_path = init.environ.getAlloc(std.heap.page_allocator, "ZIGEFFECT_TEST_RECEIPT") catch inferred_path;
    suite_replay_command = init.environ.getAlloc(std.heap.page_allocator, "ZIGEFFECT_TEST_REPLAY") catch suite_replay_command;
    suite_started_ms = Io.Clock.real.now(runner_threaded_io).toMilliseconds();
}

fn initializeResults() void {
    if (suite_initialized) return;
    suite_results = std.heap.page_allocator.alloc(ReceiptTestResult, builtin.test_functions.len) catch @panic("ZigEffect Testing v2 runner out of memory");
    for (builtin.test_functions, 0..) |test_fn, index| {
        suite_results[index] = .{
            .index = @intCast(index),
            .id = test_fn.name,
            .status = .pending,
        };
    }
    suite_initialized = true;
}

fn publishSuiteReceipt() !void {
    initializeResults();
    const ended_ms = Io.Clock.real.now(runner_threaded_io).toMilliseconds();
    const counts = countResults();
    // A process that executed nothing has nothing to report. After a test
    // crashes, the build runner starts the binary again; that fresh process
    // queries metadata, runs no test, and would overwrite the crashed
    // process's honest receipt with an all-pending one. Last writer wins, and
    // the last writer is the one that knows least.
    //
    // A panicking process always writes — it is the one carrying the news.
    if (!panic_publishing and counts.discovered > 0 and counts.executed == 0) return;
    const complete = counts.executed == counts.discovered and counts.pending == 0;
    const passed = complete and counts.failed == 0 and counts.log_errors == 0 and counts.leaks == 0;
    const receipt = ReceiptWire{
        .suite = suite_name,
        .status = if (passed) .passed else .failed,
        .complete = complete,
        .started_ms = suite_started_ms,
        .ended_ms = ended_ms,
        .duration_ms = @intCast(@max(0, ended_ms - suite_started_ms)),
        .execution = .{
            .zig_version = builtin.zig_version_string,
            .target = @tagName(builtin.target.cpu.arch) ++ "-" ++ @tagName(builtin.target.os.tag),
            .optimize = @tagName(builtin.mode),
            .seed = testing.random_seed,
            .replay_command = suite_replay_command,
        },
        .counts = counts,
        .tests = suite_results,
    };
    const json = try std.json.Stringify.valueAlloc(std.heap.page_allocator, receipt, .{});
    defer std.heap.page_allocator.free(json);
    const cwd = std.Io.Dir.cwd();
    if (std.mem.lastIndexOfScalar(u8, suite_receipt_path, '/')) |slash| try cwd.createDirPath(runner_threaded_io, suite_receipt_path[0..slash]);
    for (0..1024) |slot| {
        if (try writeSuiteReceiptSlot(cwd, json, slot)) return;
    }
    return error.AtomicTemporaryPathExhausted;
}

fn writeSuiteReceiptSlot(cwd: std.Io.Dir, content: []const u8, slot: usize) !bool {
    const temporary = try std.fmt.allocPrint(std.heap.page_allocator, "{s}.tmp.{d}", .{ suite_receipt_path, slot });
    defer std.heap.page_allocator.free(temporary);
    const file = cwd.createFile(runner_threaded_io, temporary, .{ .exclusive = true }) catch |err| switch (err) {
        error.PathAlreadyExists => return false,
        else => return err,
    };
    var file_open = true;
    defer if (file_open) file.close(runner_threaded_io);
    defer cwd.deleteFile(runner_threaded_io, temporary) catch {};
    try file.writeStreamingAll(runner_threaded_io, content);
    file.close(runner_threaded_io);
    file_open = false;
    cwd.rename(temporary, cwd, suite_receipt_path, runner_threaded_io) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };
    return true;
}

fn countResults() ReceiptCounts {
    var counts = ReceiptCounts{
        .discovered = @intCast(suite_results.len),
        .executed = 0,
        .passed = 0,
        .skipped = 0,
        .failed = 0,
        .pending = 0,
        .log_errors = 0,
        .leaks = 0,
    };
    for (suite_results) |result| {
        switch (result.status) {
            .passed => counts.passed += 1,
            .skipped => counts.skipped += 1,
            .failed => counts.failed += 1,
            .pending => counts.pending += 1,
        }
        if (result.status != .pending) counts.executed += 1;
        counts.log_errors +|= result.log_error_count;
        counts.leaks +|= result.leak_count;
    }
    return counts;
}

pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @EnumLiteral(),
    comptime format: []const u8,
    args: anytype,
) void {
    @disableInstrumentation();
    if (@intFromEnum(message_level) <= @intFromEnum(std.log.Level.err)) {
        log_err_count +|= 1;
    }
    if (@intFromEnum(message_level) <= @intFromEnum(testing.log_level)) {
        std.debug.print(
            "[" ++ @tagName(scope) ++ "] (" ++ @tagName(message_level) ++ "): " ++ format ++ "\n",
            args,
        );
    }
}

/// Simpler main(), exercising fewer language features, so that
/// work-in-progress backends can handle it.
pub fn mainSimple() anyerror!void {
    @disableInstrumentation();
    // is the backend capable of calling `Io.File.writeAll`?
    const enable_write = switch (builtin.zig_backend) {
        .stage2_aarch64, .stage2_riscv64 => true,
        else => false,
    };
    // is the backend capable of calling `Io.Writer.print`?
    const enable_print = switch (builtin.zig_backend) {
        .stage2_aarch64, .stage2_riscv64 => true,
        else => false,
    };

    testing.io_instance = .init(testing.allocator, .{});

    var passed: u64 = 0;
    var skipped: u64 = 0;
    var failed: u64 = 0;

    // we don't want to bring in File and Writer if the backend doesn't support it
    const stdout = if (enable_write) Io.File.stdout() else {};

    for (builtin.test_functions) |test_fn| {
        if (enable_write) {
            stdout.writeStreamingAll(runner_threaded_io, test_fn.name) catch {};
            stdout.writeStreamingAll(runner_threaded_io, "... ") catch {};
        }
        if (test_fn.func()) |_| {
            if (enable_write) stdout.writeStreamingAll(runner_threaded_io, "PASS\n") catch {};
        } else |err| {
            if (err != error.SkipZigTest) {
                if (enable_write) stdout.writeStreamingAll(runner_threaded_io, "FAIL\n") catch {};
                failed += 1;
                if (!enable_write) return err;
                continue;
            }
            if (enable_write) stdout.writeStreamingAll(runner_threaded_io, "SKIP\n") catch {};
            skipped += 1;
            continue;
        }
        passed += 1;
    }
    if (enable_print) {
        var unbuffered_stdout_writer = stdout.writer(runner_threaded_io, &.{});
        unbuffered_stdout_writer.interface.print(
            "{} passed, {} skipped, {} failed\n",
            .{ passed, skipped, failed },
        ) catch {};
    }
    if (failed != 0) std.process.exit(1);
}

var is_fuzz_test: bool = undefined;
var fuzz_runner: if (builtin.fuzz) struct {
    indexes: []u32,
    server: *std.zig.Server,
    gpa: std.mem.Allocator,
    io: Io,
    input_poller: Io.Future(Io.Cancelable!void),

    comptime {
        assert(builtin.fuzz); // `fuzz_runner` was analyzed in non-fuzzing compilation
    }

    export fn runner_test_run(i: u32) void {
        @disableInstrumentation();

        fuzz_runner.server.serveU32Message(.fuzz_test_change, i) catch |e| switch (e) {
            error.WriteFailed => panicFmt("failed to write to stdout: {t}", .{stdout_writer.err.?}),
        };

        testing.allocator_instance = .{};
        defer if (testing.allocator_instance.deinit() == .leak) std.process.exit(1);
        is_fuzz_test = false;

        builtin.test_functions[fuzz_runner.indexes[i]].func() catch |err| switch (err) {
            error.SkipZigTest => return,
            else => {
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpErrorReturnTrace(trace);
                }
                std.debug.print("failed with error.{t}\n", .{err});
                std.process.exit(1);
            },
        };

        if (!is_fuzz_test) @panic("missed call to std.testing.fuzz");
        if (log_err_count != 0) @panic("error logs detected");
    }

    export fn runner_test_name(i: u32) fuzz_abi.Slice {
        @disableInstrumentation();
        return .fromSlice(builtin.test_functions[fuzz_runner.indexes[i]].name);
    }

    export fn runner_broadcast_input(test_i: u32, bytes_slice: fuzz_abi.Slice) void {
        @disableInstrumentation();
        const bytes = bytes_slice.toSlice();
        fuzz_runner.server.serveBroadcastFuzzInputMessage(test_i, bytes) catch |e| switch (e) {
            error.WriteFailed => panicFmt("failed to write to stdout: {t}", .{stdout_writer.err.?}),
        };
    }

    export fn runner_start_input_poller() void {
        @disableInstrumentation();
        const future = fuzz_runner.io.concurrent(inputPoller, .{}) catch |e| switch (e) {
            error.ConcurrencyUnavailable => @panic("failed to spawn concurrent fuzz input poller"),
        };
        fuzz_runner.input_poller = future;
    }

    export fn runner_stop_input_poller() void {
        @disableInstrumentation();
        assert(fuzz_runner.input_poller.cancel(fuzz_runner.io) == error.Canceled);
    }

    export fn runner_futex_wait(ptr: *const u32, expected: u32) bool {
        @disableInstrumentation();
        return fuzz_runner.io.futexWait(u32, ptr, expected) == error.Canceled;
    }

    export fn runner_futex_wake(ptr: *const u32, waiters: u32) void {
        @disableInstrumentation();
        fuzz_runner.io.futexWake(u32, ptr, waiters);
    }

    fn inputPoller() Io.Cancelable!void {
        @disableInstrumentation();
        switch (inputPollerInner()) {
            error.Canceled => return error.Canceled,
            error.ReadFailed => {
                if (stdin_reader.err.? == error.Canceled) return error.Canceled;
                panicFmt("failed to read from stdin: {t}", .{stdin_reader.err.?});
            },
            error.EndOfStream => @panic("unexpected end of stdin"),
        }
    }

    fn inputPollerInner() (Io.Cancelable || Io.Reader.Error) {
        @disableInstrumentation();
        const server = fuzz_runner.server;
        var large_bytes_list: std.ArrayList(u8) = .empty;
        defer large_bytes_list.deinit(fuzz_runner.gpa);
        while (true) {
            const hdr = try server.receiveMessage();
            if (hdr.tag != .new_fuzz_input) {
                panicFmt("unexpected message: {x}\n", .{@intFromEnum(hdr.tag)});
            }
            const test_i = try server.receiveBody_u32();
            const input_len = hdr.bytes_len - 4;
            const bytes = if (input_len <= server.in.buffer.len)
                try server.in.take(input_len)
            else bytes: {
                large_bytes_list.resize(fuzz_runner.gpa, @intCast(input_len)) catch @panic("OOM");
                try server.in.readSliceAll(large_bytes_list.items);
                break :bytes large_bytes_list.items;
            };
            if (fuzz_abi.fuzzer_receive_input(test_i, .fromSlice(bytes))) {
                return error.Canceled;
            }
        }
    }
} else void = undefined;

pub fn fuzz(
    context: anytype,
    comptime testOne: fn (context: @TypeOf(context), *std.testing.Smith) anyerror!void,
    options: testing.FuzzInputOptions,
) anyerror!void {
    // Prevent this function from confusing the fuzzer by omitting its own code
    // coverage from being considered.
    @disableInstrumentation();

    // Some compiler backends are not capable of handling fuzz testing yet but
    // we still want CI test coverage enabled.
    if (need_simple) return;

    // Smoke test to ensure the test did not use conditional compilation to
    // contradict itself by making it not actually be a fuzz test when the test
    // is built in fuzz mode.
    is_fuzz_test = true;

    // Ensure no test failure occurred before starting fuzzing.
    if (log_err_count != 0) @panic("error logs detected");

    // libfuzzer is in a separate compilation unit so that its own code can be
    // excluded from code coverage instrumentation. It needs a function pointer
    // it can call for checking exactly one input. Inside this function we do
    // our standard unit test checks such as memory leaks, and interaction with
    // error logs.
    const global = struct {
        var ctx: @TypeOf(context) = undefined;

        fn test_one() callconv(.c) bool {
            @disableInstrumentation();
            testing.allocator_instance = .{};
            defer if (testing.allocator_instance.deinit() == .leak) std.process.exit(1);
            log_err_count = 0;
            testOne(ctx, @constCast(&testing.Smith{ .in = null })) catch |err| switch (err) {
                error.SkipZigTest => return true,
                else => {
                    const stderr = std.debug.lockStderr(&.{}).terminal();
                    p: {
                        if (@errorReturnTrace()) |trace| {
                            std.debug.writeErrorReturnTrace(trace, stderr) catch break :p;
                        }
                        stderr.writer.print("failed with error.{t}\n", .{err}) catch break :p;
                    }
                    std.process.exit(1);
                },
            };
            if (log_err_count != 0) {
                const stderr = std.debug.lockStderr(&.{}).terminal();
                stderr.writer.print("error logs detected\n", .{}) catch {};
                std.process.exit(1);
            }
            return false;
        }
    };

    if (builtin.fuzz) {
        // Preserve the calling test's allocator state
        const prev_allocator_state = testing.allocator_instance;
        testing.allocator_instance = .{};
        defer testing.allocator_instance = prev_allocator_state;

        global.ctx = context;
        fuzz_abi.fuzzer_set_test(&global.test_one);
        for (options.corpus) |elem|
            fuzz_abi.fuzzer_new_input(.fromSlice(elem));
        fuzz_abi.fuzzer_start_test();
        return;
    }

    // When the unit test executable is not built in fuzz mode, only run the
    // provided corpus.
    for (options.corpus) |input| {
        var smith: testing.Smith = .{ .in = input };
        try testOne(context, &smith);
    }

    // In case there is no provided corpus, also use an empty
    // string as a smoke test.
    var smith: testing.Smith = .{ .in = "" };
    try testOne(context, &smith);
}
