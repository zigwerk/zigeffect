# zgraphy M1 operational baseline design

Status: accepted for implementation on 2026-07-16.

## Publication artifacts

A successful build publishes three independently atomic local artifacts: the
NenDB snapshot, a deterministic content/ownership manifest, and a graph-health
baseline. The content manifest contains no timestamps or absolute paths and is
bound to repository identity, classifier/policy versions, sorted terminal
discovery records, ownership units and both manifest digests. Sensitive records
retain only opaque path digests and never content fingerprints.

The health baseline records the implemented M1 scope. Discovery, ownership,
storage and vector-index integrity may be healthy; deep semantics and the
self-manager explicitly remain partial until their roadmap milestones. A
partial future capability does not make an otherwise complete M1 build stale.

## Effective configuration

Doctor output includes validated config-v2 values and a per-field explanation
of the effective source and maximum authority. M1 has compiled defaults plus a
repository-owned config file; repository values cannot grant process, network,
database or model authority. Secret values and ambient environment are absent.

## Doctor behavior

`zgraphy doctor --json` is read-only after config migration. It loads the last
published manifest and snapshot, rebuilds current source state in memory under
the same bounds, validates graph integrity, and compares discovery and ownership
digests. Clean state is ready. Source drift is stale with a stable diagnostic
code and repair command. Missing evidence is partial; incompatible or corrupt
evidence is reported distinctly. Diagnostics contain root-relative source refs
only and JSON output contains no progress text.

M1 publication is not yet a multi-file transactional generation. Interrupted
publication is detected by digest disagreement and must never be reported as
healthy; generation directories and rollback promotion arrive with the
incremental generation work.

