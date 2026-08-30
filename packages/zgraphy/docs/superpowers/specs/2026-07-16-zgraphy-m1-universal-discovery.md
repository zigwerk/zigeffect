# zgraphy M1 universal discovery design

Status: accepted for implementation on 2026-07-16.

## Objective

Replace the Zig-only repository prefilter with one bounded, deterministic and
security-conscious discovery authority. Every observed input must have one
typed terminal disposition. Every safe included file must retain placement in
the graph even when zgraphy has no deep extractor for its language.

## Identity and root authority

`zgraphy init` creates one opaque `repo-<32 lowercase hex>` identifier using the
runtime's secure randomness source and persists it in owned configuration. The
identifier is independent of checkout path, Git URL and current commit, so a
repository can move without changing graph identity. Build takes an already
opened root directory as its only filesystem authority. Persistent records use
normalised root-relative paths only; absolute host paths are forbidden.

## Discovery pipeline

The walker does not follow symlinks and is bounded by entry, file, byte, path
and depth limits. It applies mandatory exclusions, repository ignore rules and
sensitive-name rules before reading content. Safe regular files are bounded,
read, checked for a binary prefix and SHA-256 fingerprinted. Records are sorted
before their deterministic manifest digest is computed; wall-clock time is not
part of the digest.

Classification has independent language, artifact and role axes. Deep support
is initially Zig. TypeScript, JavaScript, Python, Rust, Go, Proto, configuration,
documentation and unknown safe files are still materialised as file placement
nodes. Language extractors must reuse those file identities.

Terminal dispositions are: deeply indexed, placed unsupported, placed asset,
ignored by rule, mandatory excluded, sensitive excluded, binary excluded,
oversized excluded, unreadable, symlink not followed, unsupported special,
invalid path and limit exhausted. Each record names the responsible policy or
provider. Sensitive paths are represented only by an opaque path digest and
must never be content-opened, content-hashed or emitted as plaintext.

## Graph integration

Discovery first materialises the repository, directory hierarchy and all safe
file nodes. The indexer then performs deep Zig extraction and recognised
manifest extraction against the same identities. Before rereading deep source,
the indexer verifies it still matches the discovery content digest; a changed
or unavailable input aborts the generation rather than mixing observations.

## Configuration and compatibility

M1 introduces config v2 with repository identity, root/discovery limits and
policy fields. Loading v1 performs an idempotent, additive migration which
preserves all user-owned limits and paths, writes atomically, and retains the
previous file until the replacement succeeds. Repeated init does not overwrite
configuration. Snapshot-v1 stays readable while graph schema-v2 migration is a
later explicit generation boundary.

## Acceptance evidence

A mixed Zig/TypeScript/Python/Rust/Go/Proto/docs/config/unknown fixture is
walked twice. The scenario proves equal manifests, disposition reconciliation,
sensitive concealment, ignored accounting, unsupported placement, deep-file
identity reuse and universal `Indexer.buildRepository` integration. Testing v2
must report complete execution, no pending tests, no leaks and no logged errors.

