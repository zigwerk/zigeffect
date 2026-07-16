# ZigEffect Standard Library Architecture Implementation Plan

**Design:** `docs/superpowers/specs/2026-07-15-zigeffect-standard-library-architecture.md`

1. Add failing canonical tests for default-service requirements, FileSystem
   and Process layer substitution, application topology, semantic causal
   lineage, and redaction.
2. Extend RuntimeAspect with a semantic causal-event hook and add context-level
   causal recording that inherits runtime lineage.
3. Fan semantic events through logger, metrics, tracer, custom aspects, and the
   runtime-owned causal store.
4. Add default-service effect facades for Clock, Console, Randomness, and
   Config with deterministic overrides.
5. Add stable FileSystem and Process service tags, typed driver APIs,
   canonical effects, and memory/local or fake/local layer constructors.
6. Update the standard-library facade, README, and migration roadmap to name
   the canonical API and explicitly identify remaining legacy surfaces.
7. Run package-native tests for `zigeffect` and `zigeffect-std`, inspect Testing
   v2 suite receipts, then run affected downstream package gates and the
   Testing v2 migration/tool-hygiene guards.
