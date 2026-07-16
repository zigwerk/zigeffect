# zgraphy threat model

Status: M0 baseline; runtime controls retain individual milestone gates

Machine contract: `zgraphy.security-baseline.v1`

Pinned Graphify commit: `cb96bdaa0c367bec8d5c5aee5d7c9ebb727e9780`

## Security posture

zgraphy is local-first and currently performs no network requests and runs no
repository-selected external processes. The ZigEffect manifest denies network
authority, requires approval for process boundaries, does not persist raw
terminal output, and applies Debug, ReleaseSafe, source-policy, leak, and causal
gates.

Repository content is untrusted input. It may influence extracted facts within
declared file/object/resource bounds, but it may not grant filesystem, process,
network, database, model, or external-system authority. Complete graph
generations and evidence provenance are security assets because development
agents can act on their answers.

## Graphify controls retained

The pinned Graphify baseline contributes mature patterns for:

- URL scheme/IP/metadata validation and redirect rechecking;
- streaming download and pre-parse graph size caps;
- output-path containment;
- label and metadata sanitization;
- prompt-sentinel neutralization and untrusted-source delimiters;
- symlink no-follow traversal;
- corrupt graph recovery; and
- focused security regression tests.

zgraphy does not claim parity for surfaces it does not yet have. URL, model,
MCP, HTML/YAML export, and external process controls remain absent or deferred,
with explicit enabling milestones. The baseline binds Graphify's exact local
security files by SHA-256 so an upstream refresh cannot change this reference
silently.

## zgraphy-specific risks

Beyond Graphify's local graph tooling surface, zgraphy must protect:

- typed fact and candidate explosion;
- stale source/provider/config dimensions;
- partial provider reconciliation;
- immutable candidate publication and last-good rollback;
- NenDB snapshot integrity and schema migration;
- bounded ZigEffect causal projection; and
- future self-manager pruning, repair, and garbage collection.

Provider model output remains hypothesis evidence. It cannot overwrite source
facts. Required provider failure yields typed partial/stale health, while
optional provider claims are excluded. A failed update or migration cannot
replace the active complete generation.

## Evidence states

The adversarial index deliberately separates:

- exercised runtime fixtures;
- contract mutation tests;
- planned near-term fixtures;
- deferred fixtures whose product boundary does not exist; and
- not-applicable absence guards.

Only an existing deterministic runtime scenario may be called exercised.
Contract-only policy does not qualify a parser, database, model, MCP server, or
exporter. Planned and deferred fixture paths reserve stable identities but are
not treated as files or evidence.

## Current high-risk assignments

M1 owns universal discovery safety: path/symlink escape, malformed and oversized
inputs, ignore policy, sensitive content, and parser/resource bounds.

M3 owns automatic freshness, generation recovery, rollback, and corruption
qualification. M5 owns process/provider authority and runtime conformance. M7
owns MCP/agent output and exporter path/escaping controls. M8 owns adversarial
causal input. M10 owns URL/model-provider egress, prompt injection, spend, and
unit reconciliation. M11 requalifies all security and compatibility controls
for production.

## Promotion

A threat may move to mitigated only when all referenced controls are
implemented and all fixtures are exercised. Every critical/high threat must
retain controls, fixtures, residual risk, and a milestone owner. The validator
rejects duplicate IDs, stale Graphify digests, broken references, missing
evidence paths, and false promotion.
