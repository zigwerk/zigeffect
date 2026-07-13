const std = @import("std");

pub const fx = @import("zigeffect");
pub const Service = @import("service/root.zig");
pub const Schema = @import("schema/root.zig");
pub const Secrets = @import("secrets/root.zig");
pub const External = @import("external/root.zig");
pub const Capability = @import("capability/root.zig");
pub const SystemCapabilities = @import("system_capabilities.zig");
pub const Json = @import("json/root.zig");
pub const Jsonl = @import("jsonl/root.zig");
pub const Stream = @import("stream/root.zig");
pub const Sink = @import("sink/root.zig");
pub const Queue = @import("queue/root.zig");
pub const PubSub = @import("pubsub/root.zig");
pub const Path = @import("path/root.zig");
pub const Config = @import("config/root.zig");
pub const Clock = @import("clock/root.zig");
pub const Randomness = @import("random/root.zig");
pub const Ids = @import("ids/root.zig");
pub const Schedule = @import("schedule/root.zig");
pub const Resilience = @import("resilience/root.zig");
pub const Security = @import("security/root.zig");
pub const Cache = @import("cache/root.zig");
pub const Broker = @import("broker/root.zig");
pub const Boundary = @import("boundary/root.zig");
pub const ObjectStorage = @import("object_storage/root.zig");
pub const Outbox = @import("outbox/root.zig");
pub const Cli = @import("cli/root.zig");
pub const Console = @import("console/root.zig");
pub const Env = @import("env/root.zig");
pub const FileSystem = @import("filesystem/root.zig");
pub const Workspace = @import("workspace/root.zig");
pub const Process = @import("process/root.zig");
pub const Observability = @import("observability/root.zig");
pub const Testing = @import("testing/root.zig");
pub const Sql = @import("sql/root.zig");
pub const Http = @import("http/root.zig");
pub const Grpc = @import("grpc/root.zig");
pub const Agent = @import("agent/root.zig");
pub const Application = @import("application/root.zig");
pub const CausalGraph = @import("causal_graph/root.zig");
pub const Statechart = @import("statechart/root.zig");
pub const Project = @import("project/root.zig");
pub const Safety = @import("safety/root.zig");

test "zigeffect-std re-exports the engine facade" {
    try std.testing.expect(@hasDecl(fx, "effect"));
}

test "root exports Observability namespace" {
    const zstd = @import("root.zig");
    try std.testing.expect(@hasDecl(zstd, "Observability"));
    try std.testing.expect(@hasDecl(zstd.Observability, "Recorder"));
}

test "root exports the repository-owned gRPC namespace" {
    const zstd = @import("root.zig");
    try std.testing.expect(@hasDecl(zstd, "Grpc"));
    try std.testing.expect(@hasDecl(zstd.Grpc, "frameMessageAlloc"));
    try std.testing.expect(@hasDecl(zstd.Grpc, "invokeEffect"));
}

test "root exports causal Application namespace" {
    const zstd = @import("root.zig");
    try std.testing.expect(@hasDecl(zstd, "Application"));
    try std.testing.expect(@hasDecl(zstd.Application, "record"));
}

test "root exports provider conformance scoring" {
    const zstd = @import("root.zig");
    try std.testing.expect(@hasDecl(zstd.Safety, "Conformance"));
    try std.testing.expect(@hasDecl(zstd.Safety.Conformance, "scoreSuiteAlloc"));
}

test "root exports capability maturity and resolution" {
    const zstd = @import("root.zig");
    try std.testing.expect(@hasDecl(zstd, "Capability"));
    try std.testing.expect(@hasDecl(zstd.Capability, "Descriptor"));
    try std.testing.expect(@hasDecl(zstd.Capability, "resolve"));
}

test "root exports durable causal graph database" {
    const zstd = @import("root.zig");
    try std.testing.expect(@hasDecl(zstd.CausalGraph, "LocalDatabase"));
    try std.testing.expect(@hasDecl(zstd.CausalGraph, "Snapshot"));
}

test "root exports statechart artifact catalog queries" {
    const zstd = @import("root.zig");
    try std.testing.expect(@hasDecl(zstd.Statechart, "parseCatalog"));
    try std.testing.expect(@hasDecl(zstd.Statechart, "Catalog"));
    try std.testing.expectEqualStrings(".zigeffect/statecharts", zstd.Statechart.default_path);
}

test {
    std.testing.refAllDecls(Testing);
    std.testing.refAllDecls(Application);
    std.testing.refAllDecls(CausalGraph);
    std.testing.refAllDecls(Statechart);
    std.testing.refAllDecls(Project);
    std.testing.refAllDecls(Safety);
    std.testing.refAllDecls(Capability);
    std.testing.refAllDecls(SystemCapabilities);
    std.testing.refAllDecls(Http);
    std.testing.refAllDecls(Grpc);
    std.testing.refAllDecls(Sql);
    std.testing.refAllDecls(Clock);
    std.testing.refAllDecls(Randomness);
    std.testing.refAllDecls(Ids);
    std.testing.refAllDecls(Config);
    std.testing.refAllDecls(Secrets);
    std.testing.refAllDecls(Process);
    std.testing.refAllDecls(FileSystem);
    std.testing.refAllDecls(External);
    std.testing.refAllDecls(Resilience);
    std.testing.refAllDecls(Security);
    std.testing.refAllDecls(Cache);
    std.testing.refAllDecls(Broker);
    std.testing.refAllDecls(ObjectStorage);
    std.testing.refAllDecls(Application.Lifecycle);
}
