# ZigEffect compositional developer experience implementation plan

Date: 2026-07-15

1. Add failing kernel tests for fluent composition, inferred service/error
   unions, recovery, semantic causal naming, and runtime reuse.
2. Implement the canonical combinator types and expose the same fluent methods
   from every effect description.
3. Replace manual nested `runIn` calls in the canonical reference application
   with program composition.
4. Add failing causal ownership/allocation tests, then pack owned event strings
   into one backing allocation while preserving redaction and truncation.
5. Add failing CLI template contract tests for the canonical architecture and
   migrate the starter template and its snapshots away from `EffectEnv` and
   `LayerGraph`.
6. Update public architecture and developer documentation with the canonical
   program shape and performance contract.
7. Run package-native ZigEffect, standard-library, CLI, example, downstream,
   Testing v2 receipt, migration, hygiene, and diff verification gates.
