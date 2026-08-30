# ZigEffect Extraction Completeness Design

## Problem

The first standalone ZigEffect extraction selected packages primarily by the
`zigeffect-*` prefix. That rule is not a valid dependency boundary. Generated
applications also depend on `zgraphy`, which in turn depends on `zgdb` and
`zgroach`. The HTTP provider family also names a ZigTLS adapter boundary that
was never tracked in Yachdee; only an ignored Zig package cache remained at
`packages/zigeffect-http-tls-zigtls`.

A standalone release is complete only when its generated projects and public
adapter families can be fetched, built, and tested without Yachdee.

## Decisions

### Graph Packages

`zgdb`, `zgroach`, and `zgraphy` remain first-class ZigEffect monorepo packages.
They keep their own public modules, tests, manifests, release archives, and
generated-project qualification. This work is already shipped and must remain
covered by release checks instead of relying on package-name conventions.

### ZigTLS Adapter

Create `packages/zigeffect-http-tls-zigtls` as a first-party adapter package.
It implements the public `zigeffect-http` `Tls.Provider` contract. The verified
runtime `src/` tree from upstream ZigTLS `v0.1.3` is vendored with its license,
release URL, asset SHA-256, and Zig content hash because the upstream build DSL
does not evaluate under Zig `0.16`. Cached Yachdee source is not copied into the
repository.

The initial adapter is a synchronous TLS 1.3 HTTP/1.1 server provider. It owns
credential decoding, the ZigTLS connection and event-loop adapter, bounded
handshake/read/write pumping, and scoped cleanup. It uses Ed25519 PKCS#8 server
credentials, matching ZigTLS's production-oriented credential path. Its
capability remains `local_development` until a checked-in live interoperability
receipt qualifies a higher maturity.

### Distribution

Release packaging uses an explicit package inventory. The ZigTLS adapter joins
that inventory and the production package matrix. Package-boundary tests must
assert that graph packages and both HTTP TLS adapters are present, contain no
monorepo-relative dependencies, and can be fetched by Zig from their archives.

## Acceptance

- `packages/zgraphy` builds independently and remains in the release catalog.
- `packages/zigeffect-http-tls-zigtls` builds and tests independently.
- The adapter composes through the public `zigeffect-http` TLS provider type.
- Its upstream ZigTLS source records an immutable release URL, asset SHA-256,
  Zig content hash, and license.
- Deterministic package release output contains a ZigTLS adapter archive whose
  manifest has no sibling path dependencies.
- CI covers the adapter and the generated external-project bootstrap path.
