# tree-sitter-typescript generated grammar provenance

- Upstream: https://github.com/tree-sitter/tree-sitter-typescript
- Tag: `v0.23.2`
- Commit: `f975a621f4e7f532fe322e13c4f79495e0a7b2e7`
- License: MIT (`LICENSE` in this directory)
- Imported: 2026-07-16

Only generated C grammar artifacts are vendored. The two `parser.c` files are
normalized mechanically by removing leading whitespace and blank lines so each
untracked translation unit remains below the agent harness's 8 MiB attestation
limit. This transformation does not change C tokens. All other files are exact
upstream bytes. The artifacts compile against the separately pinned tree-sitter
`v0.25.10` runtime and must not be hand-edited.

| File | Upstream SHA-256 | Local SHA-256 |
| --- | --- | --- |
| `typescript/src/parser.c` | `74fe453edd70f4eae9af0a1050cbd7943d8971d59165b6aaebbaa0a0b716d1aa` | `79106562e54efd64c4ac183c2e6725e79cd24de61e769ec9100fc96ece5a90ca` |
| `typescript/src/scanner.c` | `9125013b42cb888379d9be909f1d73dfb75a37626c2cdbf4122718a2b431a6d3` | same |
| `tsx/src/parser.c` | `1902cb53fa7ff5179df89b2eea863165e84c8cc866226419dc26921d8c055885` | `873c811c4fc245ec4626699adc8d7e453b101cc2701b0610fd676f0d5d500679` |
| `tsx/src/scanner.c` | `d563cd30b2f39718c9ae4292795c5ce03a2ad01954ba3a86ef84c2781a736673` | same |
| `common/scanner.h` | `da66ef2bd14a3f7ea743e25ba068c6c9aae2c3509db200ff80c4a0e6116e564c` | same |
| `typescript/src/tree_sitter/alloc.h` | `b29c1c9fb7cc82f58c84b376df1297d6e2737a1d655fd356db0859e3c29c2fea` | same |
| `typescript/src/tree_sitter/array.h` | `4ff743903dc46f5db6aa54f31c6b4d160a8a9779e5b2ab1ee59ae7ebcd850ea1` | same |
| `typescript/src/tree_sitter/parser.h` | `a1f6ef161fbaf48a0e10fca90ef5290a062462b307b3898aa562993853b9f80a` | same |
| `tsx/src/tree_sitter/alloc.h` | `b29c1c9fb7cc82f58c84b376df1297d6e2737a1d655fd356db0859e3c29c2fea` | same |
| `tsx/src/tree_sitter/array.h` | `4ff743903dc46f5db6aa54f31c6b4d160a8a9779e5b2ab1ee59ae7ebcd850ea1` | same |
| `tsx/src/tree_sitter/parser.h` | `a1f6ef161fbaf48a0e10fca90ef5290a062462b307b3898aa562993853b9f80a` | same |
| `LICENSE` | `49bf33cf78ef5897e4e161ce1517df7de1ae5042a65b6bcfd44401e0fc606559` | same |

Refresh all files from one reviewed upstream commit, recompute every checksum,
run parser conformance and malformed-input tests, and update this record and
`THIRD_PARTY_NOTICES.md` together.
