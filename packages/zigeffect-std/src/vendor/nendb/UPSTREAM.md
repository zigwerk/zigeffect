# Embedded NenDB source

This directory contains the bounded data-oriented `GraphData` engine from
[`Nen-Co/nen-db`](https://github.com/Nen-Co/nen-db), pinned to commit
`c990ef87d74e4dd7e77d3d8d1aafea2d57d12af7` (`0.2.2-beta`). The source is
licensed under Apache-2.0; see `LICENSE`.

The upstream repository currently targets Zig 0.15.1, has no
`build.zig.zon`, and its top-level build does not compile under Zig 0.16. This
vendored port makes the narrow embedded graph layout usable by ZigEffect:

- removes the unused `nen-core` import;
- replaces the upstream filesystem WAL type with ZigEffect's own bounded,
  restart-safe causal WAL;
- replaces the fixed multi-megabyte value with allocator-owned, configured
  node/edge columns so normal thread stacks are safe and applications are not
  capped by the upstream 10,000-node default;
- omits unused embedding and placeholder property blocks from the hot engine;
  complete redacted properties remain in ZigEffect's durable WAL;
- adds allocator-owned node and durable-entry hash indexes so bounded runtime
  insertion and lookup do not inherit the upstream linear-scan growth curve;
- adds exact tail rollback for runtime-owned write transactions;
- preserves NenDB's SoA node/edge topology and graph operations.

`packages/references/nen-db` is the read-only upstream submodule used to review
and update this port. Do not edit the reference checkout as application code.
