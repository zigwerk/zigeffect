const std = @import("std");
const zstd = @import("zigeffect_std");

pub const Contract = zstd.Parser;
pub const TypeScript = @import("typescript.zig");
pub const ProtocolBuffers = @import("protobuf.zig");

pub const NativeProvider = struct {
    pub fn parseAlloc(_: *NativeProvider, allocator: std.mem.Allocator, request: Contract.Request) !Contract.Result {
        return switch (request.language) {
            .typescript, .tsx, .javascript, .jsx => TypeScript.parse(
                allocator,
                request.path,
                request.source,
                request.language,
                request.limits,
            ),
            .protobuf => ProtocolBuffers.parse(
                allocator,
                request.path,
                request.source,
                request.limits,
            ),
            else => error.UnsupportedDocumentLanguage,
        };
    }
};

pub fn providerApi(provider: *NativeProvider) Contract.Api {
    return Contract.Api.from(NativeProvider, provider);
}

pub fn parserLayer(provider: *NativeProvider) @TypeOf(Contract.parserLayer(providerApi(provider))) {
    return Contract.parserLayer(providerApi(provider));
}

test "native provider rejects languages without an installed grammar" {
    var provider = NativeProvider{};
    try std.testing.expectError(error.UnsupportedDocumentLanguage, provider.parseAlloc(std.testing.allocator, .{
        .path = "src/main.zig",
        .source = "pub fn main() void {}",
        .language = .zig,
    }));
}

test "native provider emits owned deterministic TypeScript facts" {
    const source =
        \\import { createClient as makeClient } from "./client";
        \\export class Service {
        \\  run() { return this.client.send(makeClient()); }
        \\}
    ;
    var provider = NativeProvider{};
    var first = try provider.parseAlloc(std.testing.allocator, .{
        .path = "src/service.ts",
        .source = source,
        .language = .typescript,
    });
    defer first.deinit();
    var second = try provider.parseAlloc(std.testing.allocator, .{
        .path = "src/service.ts",
        .source = source,
        .language = .typescript,
    });
    defer second.deinit();

    try first.validate();
    try std.testing.expectEqualStrings(TypeScript.parser_id, first.parser_id);
    try std.testing.expect(first.findDeclaration("Service") != null);
    try std.testing.expect(first.findDeclaration("run") != null);
    const binding = first.findImportBinding("makeClient") orelse return error.MissingImportBinding;
    try std.testing.expectEqualStrings("createClient", binding.imported);
    const call = first.findCall("this.client.send") orelse return error.MissingMemberCall;
    try std.testing.expectEqualStrings("Service.run", call.enclosing_declaration);
    try std.testing.expectEqualSlices(u8, &first.fingerprint, &second.fingerprint);
}

test "native provider distinguishes dynamic CommonJS and computed module calls" {
    const source =
        \\const eager = require("./eager");
        \\export async function load(path: string) {
        \\  const lazy = await import("./lazy");
        \\  const unknown = await import(path);
        \\  return { eager, lazy, unknown };
        \\}
    ;
    var provider = NativeProvider{};
    var result = try provider.parseAlloc(std.testing.allocator, .{
        .path = "src/modules.ts",
        .source = source,
        .language = .typescript,
    });
    defer result.deinit();

    const commonjs = result.findImport("./eager") orelse return error.MissingCommonJsImport;
    try std.testing.expectEqual(Contract.ImportKind.commonjs_require, commonjs.kind);
    const eager = result.findImportBinding("eager") orelse return error.MissingCommonJsBinding;
    try std.testing.expectEqual(Contract.ImportBindingKind.commonjs_require, eager.kind);
    const dynamic = result.findImport("./lazy") orelse return error.MissingDynamicImport;
    try std.testing.expectEqual(Contract.ImportKind.dynamic, dynamic.kind);
    try std.testing.expect(result.findImport("path") == null);
    try std.testing.expect(result.findCall("import") != null);
}

test "native provider emits explicit exports and scoped receiver type bindings" {
    const source =
        \\export class Svc { doThing(): number { return 1; } }
        \\class Repo { save(): number { return 1; } }
        \\export { Svc as PublicSvc };
        \\export { Origin as Remote } from "./origin";
        \\export * from "./all";
        \\export * as ns from "./namespace";
        \\export default Svc;
        \\export class Controller {
        \\  constructor(private readonly repo: Repo) {}
        \\  run(svc: Svc, values: Svc[], unknown) {
        \\    const local = new Svc();
        \\    return this.repo.save() + svc.doThing() + local.doThing();
        \\  }
        \\}
    ;
    var provider = NativeProvider{};
    var result = try provider.parseAlloc(std.testing.allocator, .{
        .path = "src/exports.ts",
        .source = source,
        .language = .typescript,
    });
    defer result.deinit();

    const local_export = result.findExport("PublicSvc") orelse return error.MissingLocalNamedExport;
    try std.testing.expectEqual(Contract.ExportKind.local_named, local_export.kind);
    try std.testing.expectEqualStrings("Svc", local_export.imported);
    const remote_export = result.findExport("Remote") orelse return error.MissingNamedReExport;
    try std.testing.expectEqual(Contract.ExportKind.re_export_named, remote_export.kind);
    try std.testing.expectEqualStrings("./origin", remote_export.target);
    try std.testing.expectEqualStrings("Origin", remote_export.imported);
    const namespace_export = result.findExport("ns") orelse return error.MissingNamespaceReExport;
    try std.testing.expectEqual(Contract.ExportKind.re_export_namespace, namespace_export.kind);
    const default_export = result.findExport("default") orelse return error.MissingDefaultExport;
    try std.testing.expectEqual(Contract.ExportKind.local_default, default_export.kind);
    try std.testing.expectEqualStrings("Svc", default_export.imported);

    const property = result.findTypeBinding("this.repo", "Controller") orelse return error.MissingConstructorPropertyType;
    try std.testing.expectEqual(Contract.TypeBindingKind.constructor_parameter_property, property.kind);
    try std.testing.expectEqualStrings("Repo", property.type_name);
    const parameter = result.findTypeBinding("svc", "Controller.run") orelse return error.MissingTypedParameter;
    try std.testing.expectEqual(Contract.TypeBindingKind.parameter, parameter.kind);
    const local = result.findTypeBinding("local", "Controller.run") orelse return error.MissingConstructorInstanceBinding;
    try std.testing.expectEqual(Contract.TypeBindingKind.constructor_instance, local.kind);
    try std.testing.expectEqualStrings("Svc", local.type_name);
    try std.testing.expect(result.findTypeBinding("values", "Controller.run") == null);
    try std.testing.expect(result.findTypeBinding("unknown", "Controller.run") == null);
}

test "native provider emits exact call arguments and factory result bindings" {
    const source =
        \\import { createClient as makeClient } from "@connectrpc/connect";
        \\import { OrdersService } from "../gen/orders_pb";
        \\import { transport } from "./transport";
        \\export const ordersClient = makeClient(OrdersService, transport);
        \\export async function fetchOrder(id: string) {
        \\  return ordersClient.getOrder({ id });
        \\}
    ;
    var provider = NativeProvider{};
    var first = try provider.parseAlloc(std.testing.allocator, .{
        .path = "src/ordersClient.ts",
        .source = source,
        .language = .typescript,
    });
    defer first.deinit();
    var second = try provider.parseAlloc(std.testing.allocator, .{
        .path = "src/ordersClient.ts",
        .source = source,
        .language = .typescript,
    });
    defer second.deinit();

    const factory = first.findCall("makeClient") orelse return error.MissingFactoryCall;
    const arguments = first.argumentsFor(factory);
    try std.testing.expectEqual(@as(usize, 2), arguments.len);
    try std.testing.expectEqual(@as(u32, 0), arguments[0].index);
    try std.testing.expectEqual(Contract.ExpressionKind.identifier, arguments[0].kind);
    try std.testing.expectEqualStrings("OrdersService", arguments[0].expression);
    try std.testing.expectEqualStrings(
        "OrdersService",
        source[arguments[0].span.start_byte..arguments[0].span.end_byte],
    );
    try std.testing.expectEqualStrings("transport", arguments[1].expression);

    const binding = first.findCallBinding("ordersClient", "") orelse return error.MissingFactoryCallBinding;
    try std.testing.expectEqual(factory.span.start_byte, binding.call_span.start_byte);
    try std.testing.expectEqual(factory.span.end_byte, binding.call_span.end_byte);
    try std.testing.expectEqualStrings(
        "ordersClient",
        source[binding.name_span.start_byte..binding.name_span.end_byte],
    );
    try std.testing.expectEqual(@as(usize, 3), first.summary.call_arguments);
    try std.testing.expectEqual(@as(usize, 1), first.summary.call_bindings);
    try std.testing.expectEqualSlices(u8, &first.fingerprint, &second.fingerprint);
}

test "native provider bounds call argument and binding facts" {
    var provider = NativeProvider{};
    try std.testing.expectError(error.TypeScriptFactLimitExceeded, provider.parseAlloc(std.testing.allocator, .{
        .path = "src/bounded.ts",
        .source = "const client = createClient(Service, transport);",
        .language = .typescript,
        .limits = .{ .max_facts = 1 },
    }));
    try std.testing.expectError(error.TypeScriptLabelLimitExceeded, provider.parseAlloc(std.testing.allocator, .{
        .path = "src/labels.ts",
        .source = "run(argumentNameThatExceedsTheBound);",
        .language = .typescript,
        .limits = .{ .max_label_bytes = 8 },
    }));
}

test "native provider emits only static CommonJS export identities" {
    const source =
        \\function legacy(): number { return 1; }
        \\function primary(): number { return 2; }
        \\exports.legacy = legacy;
        \\module.exports.primary = primary;
        \\module.exports = primary;
        \\exports["computed"] = legacy;
        \\module.exports.dynamic = makeFactory();
    ;
    var provider = NativeProvider{};
    var result = try provider.parseAlloc(std.testing.allocator, .{
        .path = "src/commonjs.js",
        .source = source,
        .language = .javascript,
    });
    defer result.deinit();

    const legacy = result.findExport("legacy") orelse return error.MissingCommonJsNamedExport;
    try std.testing.expectEqual(Contract.ExportKind.commonjs_named, legacy.kind);
    try std.testing.expectEqualStrings("legacy", legacy.imported);
    const primary = result.findExport("primary") orelse return error.MissingCommonJsPropertyExport;
    try std.testing.expectEqual(Contract.ExportKind.commonjs_named, primary.kind);
    const default_export = result.findExport("default") orelse return error.MissingCommonJsDefaultExport;
    try std.testing.expectEqual(Contract.ExportKind.commonjs_default, default_export.kind);
    try std.testing.expectEqualStrings("primary", default_export.imported);
    try std.testing.expect(result.findExport("computed") == null);
    try std.testing.expect(result.findExport("dynamic") == null);
}

test "native provider emits canonical bounded Proto structural facts" {
    const source =
        \\syntax = "proto3";
        \\package orders.v1;
        \\import public "common/v1/money.proto";
        \\message Order {
        \\  string id = 1;
        \\  optional string note = 2;
        \\  map<string, int64> counters = 3;
        \\  oneof selector {
        \\    string name = 4;
        \\    uint64 number = 5;
        \\  }
        \\  message Item { string sku = 1; }
        \\  enum State { STATE_UNSPECIFIED = 0; STATE_READY = 1; }
        \\}
        \\service OrdersService {
        \\  rpc GetOrder(Order) returns (Order);
        \\  rpc Watch(stream Order) returns (stream Order) {}
        \\}
    ;
    var provider = NativeProvider{};
    var first = try provider.parseAlloc(std.testing.allocator, .{
        .path = "proto/orders/v1/orders.proto",
        .source = source,
        .language = .protobuf,
    });
    defer first.deinit();
    var second = try provider.parseAlloc(std.testing.allocator, .{
        .path = "proto/orders/v1/orders.proto",
        .source = source,
        .language = .protobuf,
    });
    defer second.deinit();

    const package = first.findProtocolPackage() orelse return error.MissingProtoPackage;
    try std.testing.expectEqualStrings("orders.v1", package.name);
    try std.testing.expect(first.findImport("common/v1/money.proto") != null);
    try std.testing.expect(first.findDeclaration("Order") != null);
    try std.testing.expect(first.findDeclaration("Order.Item") != null);
    try std.testing.expect(first.findDeclaration("OrdersService") != null);
    const field = first.findProtocolField("Order", 3) orelse return error.MissingProtoMapField;
    try std.testing.expectEqual(Contract.ProtocolFieldKind.map, field.kind);
    try std.testing.expectEqualStrings("string", field.map_key_type);
    try std.testing.expectEqualStrings("int64", field.type_name);
    const oneof = first.findProtocolField("Order", 4) orelse return error.MissingProtoOneofField;
    try std.testing.expectEqualStrings("selector", oneof.oneof_name);
    const value = first.findProtocolEnumValue("Order.State", "STATE_READY") orelse return error.MissingProtoEnumValue;
    try std.testing.expectEqual(@as(i32, 1), value.number);
    const unary = first.findProtocolRpc("OrdersService", "GetOrder") orelse return error.MissingProtoUnaryRpc;
    try std.testing.expect(!unary.client_streaming and !unary.server_streaming);
    const streaming = first.findProtocolRpc("OrdersService", "Watch") orelse return error.MissingProtoStreamingRpc;
    try std.testing.expect(streaming.client_streaming and streaming.server_streaming);
    try std.testing.expectEqualSlices(u8, &first.fingerprint, &second.fingerprint);
}

test {
    std.testing.refAllDecls(TypeScript);
    std.testing.refAllDecls(ProtocolBuffers);
}
