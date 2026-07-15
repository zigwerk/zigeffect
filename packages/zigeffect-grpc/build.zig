const std = @import("std");
const protobuf_build = @import("protobuf");

fn addV2Test(b: *std.Build, runner: std.Build.LazyPath, options: std.Build.TestOptions) *std.Build.Step.Compile {
    var configured = options;
    configured.test_runner = .{ .path = runner, .mode = .server };
    return b.addTest(configured);
}

const NativePaths = struct {
    include_dir: ?[]const u8,
    arch_include_dir: ?[]const u8,
    library_dir: ?[]const u8,
};

fn linkNative(module: *std.Build.Module, target: std.Build.ResolvedTarget, paths: NativePaths) void {
    module.link_libc = true;
    if (target.result.os.tag == .macos) {
        if (target.result.cpu.arch == .aarch64) {
            module.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
            module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
            module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/openssl@3/lib" });
        } else {
            module.addIncludePath(.{ .cwd_relative = "/usr/local/include" });
            module.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });
            module.addLibraryPath(.{ .cwd_relative = "/usr/local/opt/openssl@3/lib" });
        }
    }
    if (paths.include_dir) |path| module.addIncludePath(.{ .cwd_relative = path });
    if (paths.arch_include_dir) |path| module.addIncludePath(.{ .cwd_relative = path });
    if (paths.library_dir) |path| module.addLibraryPath(.{ .cwd_relative = path });
    module.linkSystemLibrary("nghttp2", .{});
    module.linkSystemLibrary("ssl", .{});
    module.linkSystemLibrary("crypto", .{});
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const native_paths: NativePaths = .{
        .include_dir = b.option([]const u8, "native-include-dir", "Additional native dependency include directory"),
        .arch_include_dir = b.option([]const u8, "native-arch-include-dir", "Additional architecture-specific native dependency include directory"),
        .library_dir = b.option([]const u8, "native-library-dir", "Additional native dependency library directory"),
    };
    const zstd_dep = b.dependency("zigeffect_std", .{ .target = target, .optimize = optimize });
    const zstd = zstd_dep.module("zigeffect_std");
    const otel_dep = b.dependency("zigeffect_otel", .{ .target = target, .optimize = optimize });
    const otel = otel_dep.module("zigeffect_otel");
    const runner = zstd_dep.module("zigeffect_test_runner").root_source_file.?;
    const protobuf_dep = b.dependency("protobuf", .{ .target = target, .optimize = optimize });
    const protobuf = protobuf_dep.module("protobuf");

    const generate_proto = protobuf_build.RunProtocStep.create(protobuf_dep.builder, target, .{
        .destination_directory = b.path("src/generated"),
        .source_files = &.{
            b.path("proto/zigeffect/grpc/v1/options.proto"),
            b.path("proto/zigeffect/grpc/v1/conformance.proto"),
            b.path("proto/grpc/health/v1/health.proto"),
            b.path("proto/grpc/channelz/v1/channelz.proto"),
            b.path("proto/grpc/reflection/v1/reflection.proto"),
            b.path("proto/grpc/reflection/v1alpha/reflection.proto"),
            b.path("tests/official/src/proto/grpc/testing/empty.proto"),
            b.path("tests/official/src/proto/grpc/testing/messages.proto"),
            b.path("tests/official/src/proto/grpc/testing/test.proto"),
            b.path("tests/connect-conformance/connectrpc/conformance/v1/config.proto"),
            b.path("tests/connect-conformance/connectrpc/conformance/v1/client_compat.proto"),
            b.path("tests/connect-conformance/connectrpc/conformance/v1/server_compat.proto"),
            b.path("tests/connect-conformance/connectrpc/conformance/v1/service.proto"),
        },
        .include_directories = &.{ b.path("proto"), b.path("tests/official"), b.path("tests/connect-conformance") },
        .preserve_unknown_fields = true,
    });
    const gen_proto_step = b.step("gen-proto", "Generate typed Zig bindings from Protobuf contracts");
    gen_proto_step.dependOn(&generate_proto.step);
    const buf_executable = b.option([]const u8, "buf", "Path to the pinned Buf executable") orelse "../../node_modules/.bin/buf";
    const schema_compatibility = b.addSystemCommand(&.{"bash"});
    schema_compatibility.addFileArg(b.path("tests/run_buf_breaking.sh"));
    schema_compatibility.addArg(buf_executable);
    const schema_compatibility_step = b.step("schema-compatibility-test", "Lint Protobuf and prove current compatibility plus breaking-change rejection");
    schema_compatibility_step.dependOn(&schema_compatibility.step);

    const module = b.addModule("zigeffect_grpc", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zigeffect_std", .module = zstd }},
    });
    const adversarial_iterations = b.option(u32, "adversarial-iterations", "Run the in-process defensive campaign this many times") orelse 1;
    const build_options = b.addOptions();
    build_options.addOption(
        u32,
        "grpc_adversarial_iterations",
        adversarial_iterations,
    );
    module.addOptions("build_options", build_options);
    module.addImport("protobuf", protobuf);
    module.addImport("zigeffect_otel", otel);
    linkNative(module, target, native_paths);

    const test_filter = b.option([]const u8, "test-filter", "Run only tests whose names contain this value");
    const filters: []const []const u8 = if (test_filter) |value| &.{value} else &.{};
    const tests = addV2Test(b, runner, .{ .name = "zigeffect-grpc-tests", .root_module = module, .filters = filters });
    tests.step.dependOn(&generate_proto.step);
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run native gRPC tests");
    test_step.dependOn(&run_tests.step);

    const adversarial_tests = addV2Test(b, runner, .{
        .name = "zigeffect-grpc-adversarial-tests",
        .root_module = module,
        .filters = &.{"defensive adversarial campaign"},
    });
    adversarial_tests.step.dependOn(&generate_proto.step);
    const run_adversarial_tests = b.addRunArtifact(adversarial_tests);
    run_adversarial_tests.setEnvironmentVariable("ZIGEFFECT_TEST_SUITE", "zigeffect-grpc-adversarial-tests");
    run_adversarial_tests.setEnvironmentVariable("ZIGEFFECT_TEST_RECEIPT", ".zigeffect/tests/suites/zigeffect-grpc-adversarial-tests.json");
    run_adversarial_tests.setEnvironmentVariable(
        "ZIGEFFECT_TEST_REPLAY",
        b.fmt("GRPC_ADVERSARIAL_ITERATIONS={d} tests/run_adversarial_campaign.sh", .{adversarial_iterations}),
    );
    const adversarial_test_step = b.step("adversarial-test", "Run the bounded in-process malformed-frame and certificate-rotation campaign");
    adversarial_test_step.dependOn(&run_adversarial_tests.step);

    const process_server_module = b.createModule(.{
        .root_source_file = b.path("tests/process_server.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zigeffect_grpc", .module = module }},
    });
    linkNative(process_server_module, target, native_paths);
    const process_server = b.addExecutable(.{ .name = "zigeffect-grpc-process-server", .root_module = process_server_module });
    const process_client_module = b.createModule(.{
        .root_source_file = b.path("tests/process_client.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zigeffect_grpc", .module = module }},
    });
    linkNative(process_client_module, target, native_paths);
    const process_client = b.addExecutable(.{ .name = "zigeffect-grpc-process-client", .root_module = process_client_module });
    const official_interop_server_module = b.createModule(.{
        .root_source_file = b.path("tests/official_interop_server.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zigeffect_grpc", .module = module }},
    });
    linkNative(official_interop_server_module, target, native_paths);
    const official_interop_server = b.addExecutable(.{
        .name = "zigeffect-grpc-official-interop-server",
        .root_module = official_interop_server_module,
    });
    const official_interop_server_step = b.step("official-interop-server", "Build the official gRPC interoperability server adapter");
    official_interop_server_step.dependOn(&official_interop_server.step);
    const official_interop_client_module = b.createModule(.{
        .root_source_file = b.path("tests/official_interop_client.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zigeffect_grpc", .module = module }},
    });
    linkNative(official_interop_client_module, target, native_paths);
    const official_interop_client = b.addExecutable(.{
        .name = "zigeffect-grpc-official-interop-client",
        .root_module = official_interop_client_module,
    });
    const official_interop_client_step = b.step("official-interop-client", "Build the official gRPC interoperability client adapter");
    official_interop_client_step.dependOn(&official_interop_client.step);
    const connect_server_module = b.createModule(.{
        .root_source_file = b.path("tests/connect_server.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zigeffect_grpc", .module = module }},
    });
    linkNative(connect_server_module, target, native_paths);
    const connect_server = b.addExecutable(.{ .name = "zigeffect-grpc-connect-server", .root_module = connect_server_module });
    const connect_conformance_server_module = b.createModule(.{
        .root_source_file = b.path("tests/connect_conformance_server.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zigeffect_grpc", .module = module }},
    });
    linkNative(connect_conformance_server_module, target, native_paths);
    const connect_conformance_server = b.addExecutable(.{
        .name = "zigeffect-grpc-connect-conformance-server",
        .root_module = connect_conformance_server_module,
    });
    const connect_conformance_server_step = b.step("connect-conformance-server", "Build the official Connect conformance server adapter");
    connect_conformance_server_step.dependOn(&b.addInstallArtifact(connect_conformance_server, .{}).step);
    const connect_conformance_client_module = b.createModule(.{
        .root_source_file = b.path("tests/connect_conformance_client.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zigeffect_grpc", .module = module },
            .{ .name = "zigeffect_std", .module = zstd },
        },
    });
    linkNative(connect_conformance_client_module, target, native_paths);
    const connect_conformance_client = b.addExecutable(.{
        .name = "zigeffect-grpc-connect-conformance-client",
        .root_module = connect_conformance_client_module,
    });
    const connect_conformance_client_step = b.step("connect-conformance-client", "Build the official Connect conformance client adapter");
    connect_conformance_client_step.dependOn(&b.addInstallArtifact(connect_conformance_client, .{}).step);
    const benchmark_server_module = b.createModule(.{
        .root_source_file = b.path("benchmarks/zig_server.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zigeffect_grpc", .module = module },
            .{ .name = "zigeffect_std", .module = zstd },
        },
    });
    linkNative(benchmark_server_module, target, native_paths);
    const benchmark_server = b.addExecutable(.{
        .name = "zigeffect-grpc-benchmark-server",
        .root_module = benchmark_server_module,
    });
    const install_benchmark_server = b.step("install-benchmark-server", "Build and install the instrumented benchmark server");
    install_benchmark_server.dependOn(&b.addInstallArtifact(benchmark_server, .{}).step);
    const cloud_run_module = b.createModule(.{
        .root_source_file = b.path("examples/cloud_run/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zigeffect_grpc", .module = module },
            .{ .name = "zigeffect_std", .module = zstd },
        },
    });
    linkNative(cloud_run_module, target, native_paths);
    const cloud_run = b.addExecutable(.{ .name = "zigeffect-grpc-cloud-run", .root_module = cloud_run_module });
    b.installArtifact(cloud_run);
    const install_cloud_run = b.step("install-cloud-run", "Build and install the Cloud Run service example");
    install_cloud_run.dependOn(&b.addInstallArtifact(cloud_run, .{}).step);
    const python = b.option([]const u8, "python", "Python executable containing grpcio") orelse "python3";
    const external_plain = b.addSystemCommand(&.{"bash"});
    external_plain.addFileArg(b.path("tests/run_external_interop.sh"));
    external_plain.addArtifactArg(process_server);
    external_plain.addArg(python);
    external_plain.addFileArg(b.path("tests/fixtures/cert.pem"));
    external_plain.addFileArg(b.path("tests/fixtures/key.pem"));
    external_plain.addArg("plaintext");
    const external_tls = b.addSystemCommand(&.{"bash"});
    external_tls.addFileArg(b.path("tests/run_external_interop.sh"));
    external_tls.addArtifactArg(process_server);
    external_tls.addArg(python);
    external_tls.addFileArg(b.path("tests/fixtures/cert.pem"));
    external_tls.addFileArg(b.path("tests/fixtures/key.pem"));
    external_tls.addArg("tls");
    const external_client_plain = b.addSystemCommand(&.{"bash"});
    external_client_plain.addFileArg(b.path("tests/run_external_client_interop.sh"));
    external_client_plain.addArtifactArg(process_client);
    external_client_plain.addArg(python);
    external_client_plain.addFileArg(b.path("tests/fixtures/cert.pem"));
    external_client_plain.addFileArg(b.path("tests/fixtures/key.pem"));
    external_client_plain.addArg("plaintext");
    const external_client_tls = b.addSystemCommand(&.{"bash"});
    external_client_tls.addFileArg(b.path("tests/run_external_client_interop.sh"));
    external_client_tls.addArtifactArg(process_client);
    external_client_tls.addArg(python);
    external_client_tls.addFileArg(b.path("tests/fixtures/cert.pem"));
    external_client_tls.addFileArg(b.path("tests/fixtures/key.pem"));
    external_client_tls.addArg("tls");
    const external_step = b.step("external-test", "Run Python gRPC plaintext and TLS interoperability");
    external_step.dependOn(&external_plain.step);
    external_step.dependOn(&external_tls.step);
    external_step.dependOn(&external_client_plain.step);
    external_step.dependOn(&external_client_tls.step);

    const official_plain = b.addSystemCommand(&.{"bash"});
    official_plain.addFileArg(b.path("tests/run_official_grpc_interop.sh"));
    official_plain.addArtifactArg(official_interop_server);
    official_plain.addArg(python);
    official_plain.addFileArg(b.path("tests/fixtures/grpc-test-server.pem"));
    official_plain.addFileArg(b.path("tests/fixtures/grpc-test-server.key"));
    official_plain.addArg("plaintext");
    official_plain.addArg(b.path("tests/official").getPath(b));
    const official_tls = b.addSystemCommand(&.{"bash"});
    official_tls.addFileArg(b.path("tests/run_official_grpc_interop.sh"));
    official_tls.addArtifactArg(official_interop_server);
    official_tls.addArg(python);
    official_tls.addFileArg(b.path("tests/fixtures/grpc-test-server.pem"));
    official_tls.addFileArg(b.path("tests/fixtures/grpc-test-server.key"));
    official_tls.addArg("tls");
    official_tls.addArg(b.path("tests/official").getPath(b));
    const official_client_plain = b.addSystemCommand(&.{"bash"});
    official_client_plain.addFileArg(b.path("tests/run_official_grpc_client_interop.sh"));
    official_client_plain.addArtifactArg(official_interop_client);
    official_client_plain.addArg(python);
    official_client_plain.addFileArg(b.path("tests/fixtures/grpc-test-ca.pem"));
    official_client_plain.addFileArg(b.path("tests/fixtures/grpc-test-server.pem"));
    official_client_plain.addFileArg(b.path("tests/fixtures/grpc-test-server.key"));
    official_client_plain.addArg("plaintext");
    official_client_plain.addArg(b.path("tests/official").getPath(b));
    const official_client_tls = b.addSystemCommand(&.{"bash"});
    official_client_tls.addFileArg(b.path("tests/run_official_grpc_client_interop.sh"));
    official_client_tls.addArtifactArg(official_interop_client);
    official_client_tls.addArg(python);
    official_client_tls.addFileArg(b.path("tests/fixtures/grpc-test-ca.pem"));
    official_client_tls.addFileArg(b.path("tests/fixtures/grpc-test-server.pem"));
    official_client_tls.addFileArg(b.path("tests/fixtures/grpc-test-server.key"));
    official_client_tls.addArg("tls");
    official_client_tls.addArg(b.path("tests/official").getPath(b));
    const official_interop_step = b.step("official-interop-test", "Run official gRPC Python/Zig client and server roles in plaintext and TLS modes");
    official_interop_step.dependOn(&official_plain.step);
    official_interop_step.dependOn(&official_tls.step);
    official_interop_step.dependOn(&official_client_plain.step);
    official_interop_step.dependOn(&official_client_tls.step);

    const grpc_go_client = b.option([]const u8, "grpc-go-client", "Path to the pinned official grpc-go interop client executable");
    const grpc_go_server = b.option([]const u8, "grpc-go-server", "Path to the pinned official grpc-go interop server executable");
    if (grpc_go_client != null and grpc_go_server != null) {
        const go_client_plain = b.addSystemCommand(&.{"bash"});
        go_client_plain.addFileArg(b.path("tests/run_grpc_go_client_interop.sh"));
        go_client_plain.addArtifactArg(official_interop_server);
        go_client_plain.addArg(grpc_go_client.?);
        go_client_plain.addFileArg(b.path("tests/fixtures/grpc-test-ca.pem"));
        go_client_plain.addFileArg(b.path("tests/fixtures/grpc-test-server.pem"));
        go_client_plain.addFileArg(b.path("tests/fixtures/grpc-test-server.key"));
        go_client_plain.addArg("plaintext");
        const go_client_tls = b.addSystemCommand(&.{"bash"});
        go_client_tls.addFileArg(b.path("tests/run_grpc_go_client_interop.sh"));
        go_client_tls.addArtifactArg(official_interop_server);
        go_client_tls.addArg(grpc_go_client.?);
        go_client_tls.addFileArg(b.path("tests/fixtures/grpc-test-ca.pem"));
        go_client_tls.addFileArg(b.path("tests/fixtures/grpc-test-server.pem"));
        go_client_tls.addFileArg(b.path("tests/fixtures/grpc-test-server.key"));
        go_client_tls.addArg("tls");
        const go_server_plain = b.addSystemCommand(&.{"bash"});
        go_server_plain.addFileArg(b.path("tests/run_grpc_go_server_interop.sh"));
        go_server_plain.addArtifactArg(official_interop_client);
        go_server_plain.addArg(grpc_go_server.?);
        go_server_plain.addFileArg(b.path("tests/fixtures/grpc-test-ca.pem"));
        go_server_plain.addFileArg(b.path("tests/fixtures/grpc-test-server.pem"));
        go_server_plain.addFileArg(b.path("tests/fixtures/grpc-test-server.key"));
        go_server_plain.addArg("plaintext");
        const go_server_tls = b.addSystemCommand(&.{"bash"});
        go_server_tls.addFileArg(b.path("tests/run_grpc_go_server_interop.sh"));
        go_server_tls.addArtifactArg(official_interop_client);
        go_server_tls.addArg(grpc_go_server.?);
        go_server_tls.addFileArg(b.path("tests/fixtures/grpc-test-ca.pem"));
        go_server_tls.addFileArg(b.path("tests/fixtures/grpc-test-server.pem"));
        go_server_tls.addFileArg(b.path("tests/fixtures/grpc-test-server.key"));
        go_server_tls.addArg("tls");
        const grpc_go_interop_step = b.step("grpc-go-interop-test", "Run official grpc-go/Zig client and server roles in plaintext and TLS modes");
        grpc_go_interop_step.dependOn(&go_client_plain.step);
        grpc_go_interop_step.dependOn(&go_client_tls.step);
        grpc_go_interop_step.dependOn(&go_server_plain.step);
        grpc_go_interop_step.dependOn(&go_server_tls.step);
    }

    const connect_interop = b.addSystemCommand(&.{"bash"});
    connect_interop.addFileArg(b.path("tests/run_connect_interop.sh"));
    connect_interop.addArtifactArg(connect_server);
    connect_interop.addArg(b.path("../..").getPath(b));
    const connect_step = b.step("connect-test", "Run Connect-ES v2 and CORS interoperability through an HTTP proxy");
    connect_step.dependOn(&connect_interop.step);

    if (b.option([]const u8, "connect-conformance-runner", "Path to the pinned official connectconformance executable")) |conformance_runner| {
        const connect_server_conformance = b.addSystemCommand(&.{"bash"});
        connect_server_conformance.addFileArg(b.path("tests/run_connect_conformance.sh"));
        connect_server_conformance.addArtifactArg(connect_conformance_server);
        connect_server_conformance.addArg(conformance_runner);
        connect_server_conformance.addFileArg(b.path("tests/connect-conformance/server-config.yaml"));
        const connect_client_conformance = b.addSystemCommand(&.{"bash"});
        connect_client_conformance.addFileArg(b.path("tests/run_connect_client_conformance.sh"));
        connect_client_conformance.addArtifactArg(connect_conformance_client);
        connect_client_conformance.addArg(conformance_runner);
        connect_client_conformance.addFileArg(b.path("tests/connect-conformance/client-config.yaml"));
        const connect_server_conformance_step = b.step("connect-conformance-server-test", "Run every applicable stable Connect server conformance case");
        connect_server_conformance_step.dependOn(&connect_server_conformance.step);
        const connect_client_conformance_step = b.step("connect-conformance-client-test", "Run every applicable stable Connect client conformance case");
        connect_client_conformance_step.dependOn(&connect_client_conformance.step);
        const connect_conformance_step = b.step("connect-conformance-test", "Run every applicable stable Connect client and server conformance case");
        connect_conformance_step.dependOn(&connect_server_conformance.step);
        connect_conformance_step.dependOn(&connect_client_conformance.step);
    }
}
