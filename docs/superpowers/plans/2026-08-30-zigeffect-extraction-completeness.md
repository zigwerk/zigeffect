# ZigEffect Extraction Completeness Plan

**Status:** Complete on `main` on 2026-08-30; publication is deferred to the
next immutable ZigEffect release.

## 1. Lock The Omitted-Package Contract

- [x] Extend package-release tests to require the ZigTLS adapter archive and
  preserve explicit `zgraphy` coverage.
- [x] Add a package-native failing test for the public ZigTLS provider shape.

## 2. Implement The ZigTLS Adapter

- [x] Add the package manifest and build graph using ZigEffect Testing v2.
- [x] Vendor the verified ZigTLS `v0.1.3` runtime tree with immutable URL,
  asset SHA-256, Zig content hash, and license provenance.
- [x] Implement scoped provider layers and bounded synchronous connection I/O.
- [x] Port the complete vendored runtime and all 309 upstream tests to Zig
  `0.16` without replacing its TLS engine.
- [x] Add deterministic provider tests and a certificate-verified OpenSSL
  interoperability exchange.

## 3. Integrate Distribution And Documentation

- [x] Add the adapter to deterministic release packaging and CI matrices.
- [x] Document the OpenSSL and ZigTLS adapter selection boundary.
- [x] Update the CLI bootstrap design with the complete dependency rule.

## 4. Qualify

- [x] Pass 2/2 adapter tests and 309/309 vendored ZigTLS tests with complete,
  leak-free Testing v2 receipts.
- [x] Pass 67/67 `zgraphy` tests with complete, leak-free Testing v2 evidence.
- [x] Produce and fetch all 21 release archives with no unresolved sibling
  dependency and both `zgraphy` and ZigTLS in the staged CLI catalog.
- [x] Pass the full CLI generated-project integration matrix.
- [x] Pass Testing v2 migration and tool-hygiene guards.
- [x] Commit and push only the extraction-completeness changes, preserving
  concurrent existing-project adoption work.
