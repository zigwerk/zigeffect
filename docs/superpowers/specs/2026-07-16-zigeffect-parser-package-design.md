# ZigEffect Parser Package Design

## Purpose

Repository intelligence, agent tools, compilers, documentation systems, and
configuration-driven applications all need the same safe parsing primitives.
Those primitives must not be owned by zgraphy. ZigEffect will provide a small
standard-library parser contract and a separate native implementation package.
zgraphy becomes the first production consumer.

## Package boundary

`zigeffect-std` owns `Parser`, the dependency-light public contract:

- document language and source identity;
- exact byte and one-based line/column spans;
- bounded parser options;
- normalized declaration, import, import-binding, explicit export,
  lexical type-binding, and call facts;
- owned parse results, validation, and deterministic fingerprints;
- a type-erased parser service, layer-compatible API, and causal parse effect.

`zigeffect-parser` owns native implementations and their third-party code:

- tree-sitter runtime lifecycle and C ABI;
- statically linked generated grammars;
- language-specific AST traversal and normalization;
- provider metadata and a ZigEffect layer;
- parser conformance, allocation-failure, malformed-input, and limit tests.

The standard library does not link tree-sitter or any grammar. Applications
that need parsing opt into `zigeffect-parser`. Implementations may also be
replaced with fakes or application-specific providers through the standard
service contract.

## Initial capability

The first provider parses TypeScript, TSX, JavaScript, and JSX with the pinned
tree-sitter runtime and TypeScript/TSX grammars already qualified for zgraphy.
It emits normalized, fully owned facts and retains no tree-sitter pointer after
return. zgraphy keeps a thin `TypeScriptParser` compatibility namespace while
all implementation and third-party sources move into `zigeffect-parser`.

The normalized result is intentionally source-oriented rather than a retained
concrete syntax tree. It can be serialized, fingerprinted, stored in NenDB,
passed through effects, and consumed after parser resources have been released.

## Future parser families

The contract is designed to add providers without changing zgraphy storage:

- Zig AST normalization;
- Proto declarations, services, messages, fields, and RPCs;
- JSON, JSONL, YAML, TOML, and package/configuration documents;
- Markdown/MDX headings, sections, links, symbols, and code fences;
- HTML/CSS and framework templates;
- generated-code identity and source-map relationships.

Each provider must explicitly declare supported languages and parser identity.
Unsupported languages fail with a typed error; there is no lexical fallback
that could publish plausible but invented semantic facts.

## Ownership and determinism

Every returned string and fact slice is owned by the result allocator. Results
have one idempotence-safe deinitialization path. Providers parse once, enforce
source/node/depth/fact/label limits, reject malformed trees, sort facts by exact
source position, validate cross-fact references, and derive SHA-256 identity
from parser version, path, language, facts, spans, and summary counts.

## ZigEffect integration

`Parser.DocumentParser` is a canonical service whose API accepts allocator,
path, bytes, language, and limits. `Parser.parse` is a typed effect requiring
that service. It emits causal start/completion evidence with redacted bounded
metadata; source content is never logged. The native package exports a static
provider API and layer, while performance-sensitive code may call the same
provider directly and receive the identical result contract.

## Acceptance

The package is accepted when:

- `zigeffect-std` tests the fakeable service contract, effect, ownership, and
  structural validation without linking native grammars;
- `zigeffect-parser` compiles and links its pinned native runtime and passes
  TypeScript/TSX/JavaScript parsing, malformed-input, deterministic identity,
  bounds, and leak checks under Testing v2;
- zgraphy no longer owns or links tree-sitter sources directly;
- zgraphy's existing M2.3 parser scenario passes unchanged through the package
  adapter; and
- Debug, ReleaseSafe, migration hygiene, and agent-safety gates report complete
  evidence with no pending tests, leaks, logged errors, or new findings.

## Non-goals

This slice does not add path/module resolution, TypeScript type checking,
incremental tree edits, retained syntax trees, semantic embeddings, Proto
linking, or Markdown parsing. Those are later providers and zgraphy resolution
milestones built on this package boundary.

## Subsequent delivery

The Proto provider was delivered with canonical generated-code lineage, and
the compiler-AST Zig provider was promoted into this package on 2026-07-17.
See `2026-07-17-zigeffect-parser-zig-provider.md` for the lossless direct Zig
result, zgraphy facade, resource bounds, and common-contract boundary.
