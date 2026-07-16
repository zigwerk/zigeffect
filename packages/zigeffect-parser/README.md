# zigeffect-parser

`zigeffect-parser` provides optional Zig-native document parser providers for
the lightweight `zigeffect-std.Parser` contract. It is offline at runtime,
bounded by caller-controlled source/node/depth/fact/label limits, and returns
fully owned normalized facts with exact spans and deterministic fingerprints.

The package supports TypeScript, TSX, JavaScript, and JSX using a statically
linked pinned tree-sitter runtime and generated TypeScript grammars. It also
provides an offline native Zig parser for identity-bearing Proto2, Proto3, and
Editions syntax. Consumers can call `TypeScript.parse` or
`ProtocolBuffers.parse` directly, or install `parserLayer` in a ZigEffect
runtime and use `zigeffect-std.Parser.parse`.

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

The package does not perform repository module/type resolution or type
checking. Those are consumers of its source-document facts.
