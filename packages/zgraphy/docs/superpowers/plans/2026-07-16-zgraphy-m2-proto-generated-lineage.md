# zgraphy M2.4 Implementation Plan

1. Register the Proto/generated-lineage requirement, acceptance check and
   required Testing v2 scenario, then load agent context by requirement ID.
2. Advance `zigeffect-std.Parser` to structural-facts v3 with owned Proto
   package, field, enum-value and RPC facts, validation, deinit, summaries,
   lookup helpers and deterministic fingerprints.
3. Add failing `zigeffect-parser` tests for Proto2/Proto3/Editions packages,
   imports, nested types, fields, oneofs, maps, enum values and streaming RPCs.
4. Implement the bounded native Proto lexer/parser and expose it through the
   existing fakeable parser service/layer.
5. Add a controlled source-grounded fixture containing a canonical contract,
   protoc-gen-es output, protoc-gen-zig output and deceptive ordinary files.
6. Add a failing `protobuf_resolution.zig` scenario for canonical names,
   field-number identity, lexical/import type resolution, ambiguity,
   diagnostics, bounds and fingerprints.
7. Implement the pure immutable Proto corpus and resolver without global-name
   fallback.
8. Add a failing generated-lineage scenario for file/message/enum/service/RPC
   mappings and marker/package/source ambiguity.
9. Implement strict Protobuf-ES and protoc-gen-zig lineage extraction and exact
   canonical candidate matching.
10. Promote Proto discovery to deep indexing and materialize type, service,
    operation, message, field, ownership, request/response/type-reference and
    generated lineage nodes/edges.
11. Run pinned Graphify 0.9.17 on the controlled and `fullstack-orders`
    fixtures, record source graph digests and classify the Proto identity gap.
12. Run parser, standard-library and zgraphy focused/full Debug and ReleaseSafe
    suites, the controlled requirement, Testing v2 migration hygiene,
    manifest-owned project test and agent safety check.
