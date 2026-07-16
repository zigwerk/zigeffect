# zgraphy M2.3a Implementation Plan

1. Register `req-m2-typescript-parser-boundary`, its check, and one required
   Testing v2 scenario in `zigeffect.project.json`; load agent context by the
   stable requirement ID.
2. Create the reusable `zigeffect-std.Parser` contract and
   `zigeffect-parser` native provider package; vendor tree-sitter `v0.25.10`
   runtime sources and generated
   tree-sitter-typescript `v0.23.2` TypeScript/TSX parser and scanner files with
   immutable checksums, upstream licenses, and notices; wire static libraries
   into the executable and native test artifact.
3. Add a comprehensive TSX fixture and a controlled failing test that defines
   the typed parser API, exact facts, deterministic fingerprint, false-positive
   exclusions, language modes, and failure limits.
4. Implement the scoped C-ABI parser/tree boundary and named-node traversal in
   `packages/zigeffect-parser/src/typescript.zig`; expose a thin zgraphy
   compatibility adapter and retain no tree-sitter pointers in returned facts.
5. Extract and validate declaration, import, import-binding, and call facts with
   exact spans, enclosing declarations, receiver/member evidence, sorting,
   ownership, checked limits, and deterministic fingerprinting.
6. Run the focused scenario, inspect its Testing v2 and process receipts, then
   run M2.1/M2.2 and Graphify parity regressions.
7. Run the package-native Debug and ReleaseSafe suites, inspect complete Testing
   v2 counts and memory/log evidence, then run `project check --agent` and mark
   M2.3a satisfied only with zero new governed-source findings.
