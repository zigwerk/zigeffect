# zgraphy M3.5: Repository Context and Exact Change Lineage

## Outcome

zgraphy treats repository context as part of freshness and preserves
evidence-backed rename and move continuity without retaining a stale live
source identity. A branch, detached-HEAD, or worktree-context change publishes
a new immutable generation before a query even when every indexed source byte
is unchanged. A unique exact-content path transition publishes a typed
`renamed_from` or `moved_from` lineage record while the predecessor file node is
absent from the active canonical graph.

This slice keeps the M3.3 clean-full equivalence invariant: the current source
graph remains reconstructible from the current repository alone. Historical
lineage is a generation-owned graph-change overlay, not a synthetic live file
node and not an in-place stable-ID rewrite. M9 can project the validated overlay
into historical graph queries without changing current-source semantics.

## Graphify leverage and deliberate improvements

M3.5 retains the useful behavior behind the pinned Graphify manifest,
replacement-over-delete, worktree-ignore, linked-worktree Git-dir, and hook
regressions. Graphify's incremental merge removes prior rows for re-extracted
sources, prunes genuinely deleted sources, and preserves untouched hyperedges.
Its Git support correctly resolves linked worktree metadata, while its rebuild
hooks deliberately skip linked worktrees and therefore do not provide a
branch/worktree-aware pre-query freshness barrier.

zgraphy improves this boundary by:

- making Git repository context a digest-bound input to every active generation;
- inspecting `.git` directories and linked-worktree `.git` files locally,
  without spawning Git or consulting the network;
- assigning the shared common Git directory and each worktree opaque digest
  identities without persisting absolute paths;
- forcing an atomic zero-parse successor for a context-only change;
- distinguishing a unique exact-content rename from a cross-directory move;
- retaining ambiguous duplicate-content transitions as bounded ambiguity
  evidence rather than manufacturing lineage; and
- binding lineage into generation identity, validation, status, doctor, and
  delta provenance while preserving a clean current graph.

## Repository-context contract

`zgraphy.repository-context.v1` records only bounded, redacted metadata:

- presence: `absent` or `git`;
- worktree kind: `none`, `primary`, or `linked`;
- HEAD kind: `none`, `symbolic`, `detached`, or `unborn`;
- a validated symbolic ref when present;
- a validated hexadecimal object ID when resolvable;
- an opaque common-repository ID;
- an opaque worktree ID; and
- a canonical SHA-256 fingerprint over those fields.

Absolute root, Git-dir, and common-dir paths are used only transiently to open
metadata. They must never appear in the context artifact, active pointer,
generation metadata, status, doctor output, or causal evidence.

Primary repositories read `.git/HEAD`. Linked worktrees parse one bounded
`gitdir:` record, resolve a bounded `commondir`, and read the worktree-specific
HEAD plus shared loose or packed refs. Malformed, oversized, path-escaping
relative metadata, invalid refs, and invalid object IDs fail closed. A
non-Git repository has one deterministic absent context and remains fully
supported.

The context fingerprint is included in generation identity and same-generation
checks. `ensureFresh` compares it before accepting an otherwise matching
discovery/ownership manifest. A mismatch uses the explicit
`changed_repository_context` trigger. If source manifests are unchanged, the
build reuses all extraction facts and the canonical delta may contain zero row
changes, but a distinct context-bound generation must still activate.

## Lineage overlay

`zgraphy.change-lineage.v1` is a complete, immutable generation-owned artifact.
It contains sorted lineage records, sorted ambiguity groups, a summary, and a
canonical fingerprint. Every record binds:

- predecessor and successor generation IDs;
- predecessor and successor relative paths and file-node IDs;
- `renamed_from` when the parent directory is unchanged, otherwise
  `moved_from`;
- the exact content digest and compatible discovery classification;
- `exact_content_unique` evidence and inferred provenance; and
- a deterministic record identity.

Detection compares graph-bearing records missing from the current manifest
with graph-bearing records absent from the predecessor manifest. Only a group
with exactly one predecessor and one successor, equal content digest, and equal
classification can produce a confident relation. One-to-many, many-to-one, and
many-to-many groups produce one bounded ambiguity record and no confident
relation. Ordinary copies, delete-and-recreate uncertainty, modified renames,
and Git similarity heuristics are not promoted in M3.5.

Prior validated lineage records are carried into a successor so chains survive
subsequent generations. The artifact is bounded by configured repository limits
and later M3 retention policy. Current live graph validation still requires zero
stale nodes, dangling endpoints, and true orphans; a predecessor file node is
never reinserted merely to host history.

## Delta and publication integration

The canonical delta source-change causes add `renamed` and `moved`. When one
confident lineage relation consumes a missing predecessor, its tombstones use
that cause. Ambiguous and unmatched removals remain `deleted` or `excluded` as
proven by the filesystem reconciliation. Replacement still wins over deletion
for a path present in both old and new manifests.

Generation schema v5 binds repository-context and lineage schema, artifact,
fingerprint, and summary into metadata and the active pointer. Candidate
validation independently decodes both artifacts, recomputes their fingerprints,
checks generation/repository identities, verifies every current successor node
exists, verifies every predecessor live node is absent unless that path exists
again as a distinct current source, and rejects conflicting duplicate lineage.
The sole active-pointer rename remains the publication commit point.

`status` and `doctor` expose bounded context identity, stored/current context
agreement, lineage counts, ambiguity counts, and typed diagnostics. They do not
expose absolute metadata paths or source bodies.

## Acceptance gates

The deterministic M3.5 scenario must prove:

1. a primary Git repository publishes validated symbolic-HEAD context;
2. a unique same-directory exact-content rename emits one `renamed_from`
   record and a `renamed` tombstone cause while the old live node is absent;
3. a unique cross-directory transition emits `moved_from` and preserves the
   previous lineage record as a chain;
4. duplicate-content ambiguity emits no confident relation;
5. changing HEAD/ref with unchanged files activates a distinct generation with
   zero reparses and a zero-row canonical graph delta;
6. primary and linked contexts share one opaque common-repository identity but
   have distinct opaque worktree identities;
7. active, metadata, context, lineage, status, and doctor artifacts contain no
   absolute root/Git path or source body;
8. current-source graph and secondary-index fingerprints remain equal to a
   cache-disabled clean build after rename/move churn; and
9. prior M3 generation, recovery, pruning, and interruption scenarios remain
   green.

## Claim boundary

M3.5 earns exact unique-content rename/move lineage and branch/worktree-aware
pre-query freshness. It does not claim Git similarity rename detection,
cross-branch historical graph federation, cross-worktree shared mutation,
background watch, automatic repair, bounded retention, compaction, garbage
collection, or one-file performance superiority. Those remain M3.6+, M9, and
M11 gates.
