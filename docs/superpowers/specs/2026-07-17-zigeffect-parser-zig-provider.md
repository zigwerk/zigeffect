# Shared Zig Document Parser Provider

Date: 2026-07-17

## Decision

Promote the proven compiler-AST Zig document parser from zgraphy into the
repository-owned `zigeffect-parser` package. `zigeffect-std.Parser` remains the
dependency-light normalized document contract; `zigeffect-parser` owns native
parser implementations; zgraphy consumes a thin compatibility facade.

This closes an ownership defect rather than replacing the parser algorithm.
The accepted Zig facts, spans, ambiguity-preserving binding evidence, limits,
and deterministic behavior remain the source of truth.

## Product boundary

`zigeffect-parser.Zig` owns:

- `std.zig.Ast` parsing and malformed-source rejection;
- declarations, static `@import` facts, calls and ordered arguments;
- lexical binding definitions and binding-flow references used by exact Zig
  call resolution;
- exact byte and one-based line/column spans;
- bounded source, AST-node, syntax-depth, fact, and label processing;
- owned results, structural validation, and deterministic fingerprints.

`zgraphy.ZigParser` becomes a source-compatible re-export of that provider.
Repository resolution, graph materialization, extraction caching, semantic
supernodes, persistence, and freshness remain zgraphy responsibilities.

The provider schema and parser identity move to the `zigeffect-parser`
namespace. Existing zgraphy extraction cache entries therefore miss safely and
are rebuilt; no old provider identity is silently reused.

## Standard-library relationship

The standard library continues to expose `zigeffect-std.Parser` without
linking a native grammar. Applications opt into `zigeffect-parser` when they
need implementations. The Zig provider's richer lexical-binding result is a
direct provider API in this slice because those facts are not yet represented
by the common v4 result contract. Adding normalized binding/reference facts to
that contract and routing Zig through `DocumentParser` is a separate,
schema-versioned follow-up; this slice does not discard the evidence to fit a
smaller common shape.

## Determinism and safety

- Paths remain safe repository-relative identifiers.
- Empty, malformed, oversized, node-exhausting, over-deep, fact-exhausting,
  and overlong-label inputs fail before a result is published.
- Comments and string contents cannot manufacture declarations or calls.
- Every returned allocation has one idempotence-safe deinitialization path.
- Facts are sorted by exact source position before fingerprinting.
- Fingerprints bind provider schema/version, path, source size, every fact,
  span, binding, and summary count.
- Provider code performs no network access and retains no source or AST pointer
  after return.

## Acceptance

The slice is accepted when:

1. `zigeffect-parser` exports `Zig` and its direct provider tests prove exact
   facts, malformed/limit failures, deterministic identity, and leak freedom.
2. zgraphy's Zig parser file contains only a compatibility facade and the
   existing M2 Zig parser and resolution scenarios pass unchanged through it.
3. zgraphy's cache and clean-build equivalence scenarios pass with the new
   provider identity and no stale provider facts are reused.
4. Debug and ReleaseSafe package suites are complete under Testing v2 with
   equal discovered/executed counts, no pending tests, leaks, or logged errors.
5. zgraphy's manifest validation, focused requirement replay, project test,
   migration hygiene, and agent safety gates pass against current source.

## Deferred providers

Markdown/MDX, JSON/JSONL, YAML, TOML, HTML/CSS, source maps, retained incremental
syntax trees, and a common-contract v5 binding/reference model remain later
parser-package slices. This move makes those additions reusable by construction
without claiming them now.
