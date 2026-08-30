# zgraphy M2 Zig parser boundary design

Status: accepted for implementation on 2026-07-16.

## Decision

Use Zig 0.16's compiler-owned `std.zig.Ast` as the native syntax boundary. M2
does not add tree-sitter or a parser process. The first slice runs in parallel
with the v1 graph adapter: it emits deterministic typed structural facts with
exact byte and one-based line/column spans, validates parser completeness, and
is measured against the existing scanner before promotion.

## Facts

The parser result owns declarations, imports and calls. Declarations distinguish
functions, tests, structs, enums, unions, opaque types and error sets. Imports
retain decoded static `@import` targets. Calls retain the exact callee expression
and the smallest enclosing named function where one exists. Every fact carries
a root-relative source path, start/end byte offsets, start/end line and column,
and an observed source-syntax provenance.

Comments and string contents cannot create facts because only parsed nodes and
tokens are inspected. Malformed source is rejected with a typed parse outcome;
partial AST facts are never promoted. Source, node, fact, label and parser-error
bounds are explicit.

## Identity and compatibility

Existing graph IDs remain `stableId(kind, path, label)`: spans are evidence, not
identity. Initial function/type/import labels must match v1 labels so native
differential receipts remain comparable. New scope-qualified identity is added
only with an explicit compatibility mapping in M2.2.

The parser module is independently testable. `Indexer.indexZigSource` adopts it
only after parity tests prove existing fixtures retain canonical entities and
relations. Exact-span facts become the input to scope/import resolution rather
than directly claiming resolved calls.

## Acceptance

A dedicated fixture covers multiline function signatures, nested containers,
tests, static imports, field calls, comments and strings containing fake Zig,
and malformed input. The controlled scenario proves exact spans, absence of
false declarations/calls, deterministic repeated extraction, bounded rejection
and stable labels. Existing M0/M1 and differential gates remain green.

