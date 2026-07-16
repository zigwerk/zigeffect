# zgraphy M2.3a: Native TypeScript/JavaScript Parser Boundary

## Problem

M1 gives TypeScript and JavaScript files placement and ownership, but not source
semantics. Graphify's strongest reusable decision is its tree-sitter-based
language boundary: declarations, imports, calls, and receiver evidence are
extracted from syntax trees before repository resolution. zgraphy needs that
same structural floor locally, with stricter limits, deterministic typed facts,
exact evidence, and no Python or Node runtime in the product path.

## Dependency decision

The reusable `zigeffect-parser` package vendors and statically compiles the
dependency-free C tree-sitter runtime and generated TypeScript and TSX grammar
C sources. `zigeffect-std.Parser` owns the normalized document-fact and causal
service contract. zgraphy imports the native provider through a thin
compatibility namespace and does not own parser implementation or grammar
sources.

- tree-sitter runtime: `v0.25.10`, commit
  `208c6cac1453315e979f05ab34b6d4f7cd0340be`, MIT;
- tree-sitter-typescript: `v0.23.2`, commit
  `f975a621f4e7f532fe322e13c4f79495e0a7b2e7`, MIT;
- `.ts`, `.mts`, `.cts`, and JavaScript-without-JSX use the TypeScript grammar;
- `.tsx`, `.jsx`, and JavaScript-with-JSX use the TSX grammar.

Using the TypeScript grammar for JavaScript is valid because JavaScript is its
syntax subset; strict JavaScript-grammar differential coverage remains an M2.3b
gate. The runtime and generated grammars link statically, operate offline after
installation, and require no API key, Python, Node, Bun, model, or network at
index time.

Vendored files live outside `src/` under
`packages/zigeffect-parser/vendor/tree-sitter-runtime/` and
`packages/zigeffect-parser/vendor/tree-sitter-typescript/` with upstream
licenses, tags, commits, source URLs, and SHA-256 checksums. Generated and
upstream runtime files are never semantically hand-edited.

## Parser contract

`TypeScriptParser.parse` accepts an allocator, safe repository-relative path,
source bytes, language mode, and explicit limits. It creates a fresh parser,
sets the pinned grammar, parses once, rejects incompatible grammars and syntax
trees containing error nodes, traverses named AST nodes, validates its result,
and releases every tree-sitter resource before return.

The parser emits:

- declarations for functions, classes, interfaces, type aliases, enums,
  methods, variables, and variable-bound arrow/function expressions;
- static imports with exact module target and source span;
- import bindings for default, named, aliased, namespace, type-only, and
  TypeScript `import x = require(...)` forms;
- calls classified as direct, member, constructor, or dynamic import;
- receiver/member evidence for member calls;
- the nearest enclosing function, method, or function-valued binding;
- exact zero-copy-derived byte and one-based line/column spans; and
- deterministic summary counts and a content-independent structural
  fingerprint keyed by path, language mode, facts, and spans.

Declaration facts carry enclosing declaration, exported status, and exact name
and declaration spans. Import bindings carry module target, imported name,
local name, binding kind, and exact span. Calls carry full compact callee,
receiver and member when structurally present, call/callee spans, and enclosing
declaration.

## Bounds and failure policy

The caller controls maximum source bytes, traversed AST nodes, traversal depth,
facts, and label bytes. Zero or excessive limits are rejected. Arithmetic is
checked. Invalid paths, empty or oversized input, incompatible language ABI,
parser allocation failure, malformed syntax, missing mandatory AST fields,
invalid string-literal module targets, node/depth exhaustion, and fact/label
exhaustion are typed errors.

The runtime parser remains capped at 4 MiB per repository source by default.
The project agent-evidence envelope is 64 MiB solely so source revision and
safety receipts can hash and attest the 17.5 MiB of generated grammar C; this
does not raise repository ingestion limits.

Tree-sitter can recover partial trees, but M2.3a does not publish partial facts:
if the root reports syntax errors, the entire parse is rejected. This mirrors
the M2.1 Zig boundary and prevents plausible-looking facts from malformed
generated or edited files entering the graph.

Comments and strings are never scanned for declarations or calls. A fact exists
only because a matching named AST node exists.

## Acceptance evidence

The controlled fixture must prove, in both TypeScript and TSX modes:

- exact spans for multiline exported declarations and methods;
- ESM default/named/aliased/namespace/type bindings and import-require;
- direct, receiver-member, constructor, and dynamic-import calls;
- correct nearest enclosing declaration for calls in functions and arrow
  functions;
- TSX parsing without treating JSX tags or string/comment lookalikes as code;
- JavaScript source parses through the declared JavaScript mode;
- repeated parses have identical facts and fingerprints;
- malformed, duplicate-limit, depth, node, fact, and source bounds are typed;
- no phantom facts from comments or strings; and
- Testing v2 reports no findings, pending fibers, leaks, logged errors,
  truncation, or stale evidence.

## Non-goals

M2.3a does not resolve module paths, `package.json` exports, tsconfig aliases,
barrels/re-exports, receiver types, decorators, generated clients, Proto
contracts, JSX component ownership, or graph edges. Those consume this parser
IR in M2.3b and M2.4. It also does not accept malformed partial trees or claim
TypeScript compiler type-checking.
