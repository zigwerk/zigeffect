const std = @import("std");

fn addV2Test(b: *std.Build, runner: std.Build.LazyPath, options: std.Build.TestOptions) *std.Build.Step.Compile {
    var configured = options;
    configured.test_runner = .{ .path = runner, .mode = .server };
    if (b.option([]const u8, "test-filter", "Compile only native tests whose names contain this text")) |filter| {
        configured.filters = &.{filter};
    }
    return b.addTest(configured);
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
    const native_sanitize: ?std.zig.SanitizeC = if (optimize == .ReleaseSafe) .full else null;
    const zstd_dependency = b.dependency("zigeffect_std", .{ .target = target, .optimize = optimize });
    const zstd = zstd_dependency.module("zigeffect_std");
    const testing_runner = zstd_dependency.module("zigeffect_test_runner").root_source_file.?;

    const tree_sitter = b.addLibrary(.{
        .name = "zigeffect-parser-tree-sitter",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .sanitize_c = native_sanitize,
        }),
    });
    tree_sitter.root_module.addCSourceFiles(.{
        .root = b.path("vendor/tree-sitter-runtime/lib/src"),
        .files = &.{
            "alloc.c",
            "get_changed_ranges.c",
            "language.c",
            "lexer.c",
            "node.c",
            "parser.c",
            "query.c",
            "stack.c",
            "subtree.c",
            "tree.c",
            "tree_cursor.c",
            "wasm_store.c",
        },
        .flags = &.{"-std=c11"},
    });
    tree_sitter.root_module.addIncludePath(b.path("vendor/tree-sitter-runtime/lib/include"));
    tree_sitter.root_module.addIncludePath(b.path("vendor/tree-sitter-runtime/lib/src"));
    tree_sitter.root_module.addCMacro("_POSIX_C_SOURCE", "200112L");
    tree_sitter.root_module.addCMacro("_DEFAULT_SOURCE", "");
    tree_sitter.root_module.addCMacro("_DARWIN_C_SOURCE", "");

    const typescript_grammars = b.addLibrary(.{
        .name = "zigeffect-parser-tree-sitter-typescript",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .sanitize_c = native_sanitize,
        }),
    });
    typescript_grammars.root_module.addCSourceFiles(.{
        .root = b.path("vendor/tree-sitter-typescript"),
        .files = &.{
            "typescript/src/parser.c",
            "typescript/src/scanner.c",
            "tsx/src/parser.c",
            "tsx/src/scanner.c",
        },
        .flags = &.{"-std=c11"},
    });
    typescript_grammars.root_module.addIncludePath(b.path("vendor/tree-sitter-runtime/lib/src"));
    typescript_grammars.root_module.addIncludePath(b.path("vendor/tree-sitter-typescript/typescript/src"));

    const module = b.addModule("zigeffect_parser", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .sanitize_c = native_sanitize,
    });
    module.addImport("zigeffect_std", zstd);
    module.addIncludePath(b.path("vendor/tree-sitter-runtime/lib/include"));
    module.linkLibrary(tree_sitter);
    module.linkLibrary(typescript_grammars);

    const tests = addV2Test(b, testing_runner, .{
        .name = "zigeffect-parser-tests",
        .root_module = module,
    });
    const run_tests = b.addRunArtifact(tests);
    b.step("test", "Run zigeffect-parser Testing v2 suite").dependOn(&run_tests.step);
}
