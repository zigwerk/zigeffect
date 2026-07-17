# zigeffect-parser

`zigeffect-parser` provides optional Zig-native document parser providers for
the lightweight `zigeffect-std.Parser` contract. It is offline at runtime,
bounded by caller-controlled source/node/depth/fact/label limits, and returns
fully owned normalized facts with exact spans and deterministic fingerprints.

The package supports Zig through the compiler-owned `std.zig.Ast`, TypeScript,
TSX, JavaScript, and JSX through a statically linked pinned tree-sitter runtime
and generated TypeScript grammars, and identity-bearing Proto2, Proto3, and
Editions syntax through an offline native parser. Consumers call `Zig.parse`,
`TypeScript.parse`, or `ProtocolBuffers.parse` directly. The normalized
TypeScript and Protobuf providers can also be installed as `parserLayer` and
used through `zigeffect-std.Parser.parse`.

The provider emits owned declarations, imports, import bindings, explicit
exports/re-exports, lexical receiver-type bindings, call facts, ordered call
arguments, and direct-call result bindings with exact spans. These syntax facts
let consumers recognize framework recipes without embedding framework policy
in the parser. Static ESM, TypeScript `import = require`, static-string dynamic
`import()`, and CommonJS `require()` are distinguished. Computed module
arguments remain calls without fabricated import targets. Static identifier
assignments to `exports.name`, `module.exports.name`, and `module.exports` emit
owned CommonJS export identities; computed properties and dynamic right-hand
sides are omitted. Bare typed
parameters, constructor properties and local `new` bindings are retained;
arrays, unions and computed receiver types are deliberately omitted.

The Protocol Buffers provider emits package and import facts, nested messages
and enums, immutable-number field identities, map/oneof/cardinality metadata,
enum values, services, and unary or streaming RPC request/response types. It
parses source syntax only: repository import/type resolution and generated-code
lineage remain consumers of these deterministic document facts.

The Zig provider emits compiler-AST declarations, static `@import` facts,
calls, ordered arguments, lexical bindings, and binding-flow references with
exact spans. It rejects malformed syntax and enforces source, AST-node,
delimiter-depth, fact, and label bounds before publishing an owned result. The
richer Zig binding/reference shape is currently a direct provider API; it will
join the common parser service only through a separately versioned contract
that can retain those facts without loss.

```zig
const parser = @import("zigeffect_parser");

var zig_file = try parser.Zig.parse(
    allocator,
    "src/main.zig",
    zig_source,
    .{},
);
defer zig_file.deinit();

const entrypoint = zig_file.findDeclaration("main");
const standard_library = zig_file.findImport("std");
```

```zig
const parser = @import("zigeffect_parser");

var result = try parser.TypeScript.parse(
    allocator,
    "src/app.ts",
    source,
    .typescript,
    .{},
);
defer result.deinit();
```

```zig
var contract = try parser.ProtocolBuffers.parse(
    allocator,
    "proto/orders/v1/orders.proto",
    source,
    .{},
);
defer contract.deinit();

const service = contract.findDeclaration("OrdersService");
const request = contract.findProtocolRpc("OrdersService", "GetOrder");
```

The package does not perform repository module/type resolution, type checking,
or graph construction. Those are consumers of its source-document facts.
