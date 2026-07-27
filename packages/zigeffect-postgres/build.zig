const std = @import("std");

fn addV2Test(b: *std.Build, runner: std.Build.LazyPath, options: std.Build.TestOptions) *std.Build.Step.Compile {
    var configured = options;
    configured.test_runner = .{ .path = runner, .mode = .server };
    return b.addTest(configured);
}

const HostOpenSsl = struct {
    include: std.Build.LazyPath,
    lib: std.Build.LazyPath,
};

/// Locate OpenSSL when the host toolchain cannot find it on its default paths.
///
/// Hosted Linux keeps OpenSSL under `/usr/include` and `/usr/lib`, which the
/// native toolchain already searches, so this is a no-op there. macOS resolves
/// system headers against the Xcode SDK, which ships no OpenSSL at all, so a
/// native macOS build fails to translate `<openssl/ssl.h>` and to link `-lssl`
/// unless it is pointed at the Homebrew keg explicitly. Callers can always
/// override the result with `-Dopenssl_include_path` / `-Dopenssl_lib_path`.
fn detectHostOpenSsl(b: *std.Build, target: std.Build.ResolvedTarget) ?HostOpenSsl {
    if (target.result.os.tag != .macos) return null;
    const io = b.graph.io;
    const prefixes = [_][]const u8{
        "/opt/homebrew/opt/openssl@3",
        "/usr/local/opt/openssl@3",
        "/opt/homebrew/opt/openssl",
        "/usr/local/opt/openssl",
    };
    for (prefixes) |prefix| {
        const header = b.pathJoin(&.{ prefix, "include", "openssl", "ssl.h" });
        std.Io.Dir.accessAbsolute(io, header, .{}) catch continue;
        return .{
            .include = .{ .cwd_relative = b.pathJoin(&.{ prefix, "include" }) },
            .lib = .{ .cwd_relative = b.pathJoin(&.{ prefix, "lib" }) },
        };
    }
    return null;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    // Nothing here is installed — every artifact this package builds is a test or
    // test infrastructure — so the package default is the test default. A bare
    // `zig build test` in Debug spends most of its time in the harness capturing
    // ten stack frames per allocation. `-Doptimize` still works and still means
    // what it says; `-Doptimize=Debug` restores the traces.
    const optimize = b.option(
        std.builtin.OptimizeMode,
        "optimize",
        "Optimize mode (default ReleaseSafe; this package installs nothing)",
    ) orelse .ReleaseSafe;

    const zigeffect_std_dependency = b.dependency("zigeffect_std", .{});
    const zigeffect_std = zigeffect_std_dependency.module("zigeffect_std");
    const testing_runner = zigeffect_std_dependency.module("zigeffect_test_runner").root_source_file.?;
    const host_openssl = detectHostOpenSsl(b, target);
    const openssl_include_path = b.option(std.Build.LazyPath, "openssl_include_path", "OpenSSL include directory for the selected target") orelse
        if (host_openssl) |found| found.include else null;
    const openssl_lib_path = b.option(std.Build.LazyPath, "openssl_lib_path", "OpenSSL library directory for the selected target") orelse
        if (host_openssl) |found| found.lib else null;
    const pg = b.dependency("pg", .{
        .target = target,
        .optimize = optimize,
        .openssl = true,
        .openssl_lib_name = @as([]const u8, "ssl"),
        .openssl_include_path = openssl_include_path,
        .openssl_lib_path = openssl_lib_path,
    }).module("pg");

    const zigeffect_postgres = b.addModule("zigeffect_postgres", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    zigeffect_postgres.addImport("zigeffect_std", zigeffect_std);
    zigeffect_postgres.addImport("pg", pg);

    const tests = addV2Test(b, testing_runner, .{
        .name = "zigeffect-postgres-tests",
        .root_module = zigeffect_postgres,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run zigeffect-postgres tests");
    test_step.dependOn(&run_tests.step);

    const examples_step = b.step("examples", "Build zigeffect-postgres examples");
    addExample(b, examples_step, target, optimize, testing_runner, zigeffect_postgres, "migrate", "examples/migrate.zig");

    const cockroach_live = b.addSystemCommand(&.{"bash"});
    cockroach_live.addFileArg(b.path("scripts/cockroach-tls-test.sh"));
    const cockroach_live_step = b.step("cockroach-live-test", "Run native verified-TLS tests against disposable CockroachDB");
    cockroach_live_step.dependOn(&cockroach_live.step);
}

fn addExample(
    b: *std.Build,
    examples_step: *std.Build.Step,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    testing_runner: std.Build.LazyPath,
    zigeffect_postgres: *std.Build.Module,
    name: []const u8,
    path: []const u8,
) void {
    const module = b.createModule(.{
        .root_source_file = b.path(path),
        .target = target,
        .optimize = optimize,
    });
    module.addImport("zigeffect_postgres", zigeffect_postgres);

    const executable = b.addExecutable(.{
        .name = b.fmt("zigeffect-postgres-{s}", .{name}),
        .root_module = module,
    });
    const tests = addV2Test(b, testing_runner, .{
        .name = b.fmt("zigeffect-postgres-{s}-tests", .{name}),
        .root_module = module,
    });
    const run_tests = b.addRunArtifact(tests);

    examples_step.dependOn(&executable.step);
    examples_step.dependOn(&run_tests.step);
}
