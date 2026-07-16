# zigeffect-parser

`zigeffect-parser` provides optional Zig-native document parser providers for
the lightweight `zigeffect-std.Parser` contract. It is offline at runtime,
bounded by caller-controlled source/node/depth/fact/label limits, and returns
fully owned normalized facts with exact spans and deterministic fingerprints.

The initial provider supports TypeScript, TSX, JavaScript, and JSX using a
statically linked pinned tree-sitter runtime and generated TypeScript grammars.
Consumers can call `TypeScript.parse` directly or install `parserLayer` in a
ZigEffect runtime and use `zigeffect-std.Parser.parse`.

The provider emits owned declarations, imports, import bindings, explicit
exports/re-exports, lexical receiver-type bindings and call facts with exact
spans. Static ESM, TypeScript `import = require`, static-string dynamic
`import()`, and CommonJS `require()` are distinguished. Computed module
arguments remain calls without fabricated import targets. Static identifier
assignments to `exports.name`, `module.exports.name`, and `module.exports` emit
owned CommonJS export identities; computed properties and dynamic right-hand
sides are omitted. Bare typed
parameters, constructor properties and local `new` bindings are retained;
arrays, unions and computed receiver types are deliberately omitted.

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

The package does not perform repository module resolution or type checking.
Those are consumers of its source-document facts.
