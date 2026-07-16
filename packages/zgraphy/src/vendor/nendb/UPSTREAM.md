# NenDB source notice

This directory contains zgraphy's bounded Zig 0.16 adaptation of the
data-oriented graph layout from
[`Nen-Co/nen-db`](https://github.com/Nen-Co/nen-db), pinned to commit
`c990ef87d74e4dd7e77d3d8d1aafea2d57d12af7` (`0.2.2-beta`).

The upstream project is Apache-2.0 licensed. zgraphy's adaptation keeps the
struct-of-arrays topology but uses allocator-owned configured bounds, a node ID
index, and a contiguous fixed-width feature-vector column. zgraphy owns snapshot
durability and exact cosine search because those upstream APIs are not complete
at the pinned revision.
