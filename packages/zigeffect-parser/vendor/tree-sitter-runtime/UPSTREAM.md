# tree-sitter C runtime provenance

- Upstream: https://github.com/tree-sitter/tree-sitter
- Tag: `v0.25.10`
- Commit: `208c6cac1453315e979f05ab34b6d4f7cd0340be`
- License: MIT (`LICENSE` in this directory)
- Imported: 2026-07-16
- Upstream source archive SHA-256:
  `ad5040537537012b16ef6e1210a572b927c7cdc2b99d1ee88d44a7dcdc3ff44c`
- Sorted `lib/src` + `lib/include` file-checksum manifest SHA-256:
  `e1e5dc965222c232847edc8f81a759dfdbe0166562fd56a4e70580287620513e`
- License SHA-256:
  `5f9cf9fb6acb1972b35ae29119ce563bb60ec097656bc4b69b9bac2d04c7a147`

Only `lib/src`, `lib/include`, and the upstream license are vendored.
`zigeffect-parser` compiles the individual `lib/src/*.c` runtime translation
units through the upstream build's supported default path. These files must not
be hand-edited; refresh the complete set from one reviewed upstream commit and
update every digest and third-party notice together.
