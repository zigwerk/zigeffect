# zigeffect Causal Schema And Taxonomy Fixture Design

Date: 2026-06-08

## Purpose

This is the second M3 production-hardening slice after broader causal
redaction. The goal is to make causal artifact consumers more explicit about
schema and taxonomy compatibility so agents can keep using saved artifacts
without silently overclaiming what a tool understands.

The existing tools already accept legacy artifacts and warn when
`event_taxonomy_version` is newer than the local tool. This branch strengthens
that contract with shared schema warnings, unknown-event-kind warnings, and
fixtures that prove the warning posture across query, compare, dev-loop query
reports, and advice reports.

## Current Baseline

Generated causal JSON includes:

- `schema: "zigeffect.causal.v1"`
- `schema_version: 1`
- `event_taxonomy_version: 1`
- retention metadata
- sampling metadata
- `events`

Local saved-artifact tools parse root metadata as optional fields so older
artifacts containing only `events` continue to work. `causal_artifact.zig`
currently exposes one shared compatibility helper:

```zig
appendTaxonomyVersionWarning(output, allocator, label, event_taxonomy_version)
```

This helper warns when `event_taxonomy_version` is greater than the supported
taxonomy version. It does not warn about:

- a future `schema_version`;
- an unexpected `schema` family;
- an event kind string that no local tool knows how to classify.

## Design Decision

Keep parsing permissive and make compatibility posture visible.

This branch should not reject legacy or future artifacts by default. Instead it
adds shared warning helpers in `packages/zigeffect/tools/causal_artifact.zig`
and uses them in the existing saved-artifact tools.

Agents can then treat output like this:

- no warnings: local tool understands the declared artifact shape and event-kind
  vocabulary;
- schema warning: artifact can be inspected, but root or event fields may be
  incomplete for the local tool;
- taxonomy warning: event-kind role semantics may be incomplete;
- unknown event-kind warning: exact event citations remain usable, but role,
  advice, query, and finding interpretation may be incomplete.

## Compatibility Rules

### Legacy Artifacts

Artifacts without `schema`, `schema_version`, or `event_taxonomy_version`
remain accepted with no warning. These are known old local fixtures, not future
artifacts.

### Current Artifacts

Artifacts with:

```json
{
  "schema": "zigeffect.causal.v1",
  "schema_version": 1,
  "event_taxonomy_version": 1
}
```

produce no compatibility warnings.

### Future Schema Versions

Artifacts with current schema family but `schema_version > 1` produce:

```text
warning: <artifact> schema_version=2 newer than supported=1; artifact shape may be incomplete
```

The tool continues to parse known fields with `ignore_unknown_fields = true`.

### Unexpected Schema Families

Artifacts with a present schema that is not `zigeffect.causal.v1` produce:

```text
warning: <artifact> schema=<name> unsupported; expected zigeffect.causal.v1
```

The tool continues if the JSON still matches the local parse struct.

### Future Taxonomy Versions

Existing warning behavior remains:

```text
warning: <artifact> event_taxonomy_version=2 newer than supported=1; event-kind role semantics may be incomplete
```

### Unknown Event Kinds

If an artifact contains an event kind string that is not in the local
`CausalEventKind` vocabulary, tools should warn once per unknown kind per
artifact:

```text
warning: <artifact> event kind effect_suspended unknown to supported taxonomy=1; query/advice role semantics may be incomplete
```

This warning is useful even when `event_taxonomy_version` is omitted, because an
unknown event kind in a legacy-looking artifact is still a compatibility risk.

## Shared Helper Shape

Add to `causal_artifact.zig`:

```zig
pub const supported_causal_schema = "zigeffect.causal.v1";
pub const supported_causal_schema_version: u32 = 1;
pub const supported_event_taxonomy_version: u32 = 1;

pub const ArtifactMetadata = struct {
    schema: ?[]const u8 = null,
    schema_version: ?u32 = null,
    event_taxonomy_version: ?u32 = null,
};

pub fn appendArtifactCompatibilityWarnings(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    artifact_label: []const u8,
    metadata: ArtifactMetadata,
) std.mem.Allocator.Error!void;

pub fn isKnownCausalEventKind(kind: []const u8) bool;

pub fn appendUnknownEventKindWarning(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    artifact_label: []const u8,
    kind: []const u8,
) std.mem.Allocator.Error!void;
```

`appendTaxonomyVersionWarning` may remain as a thin compatibility wrapper or be
rewired through `appendArtifactCompatibilityWarnings`.

## Tool Integration

Update:

- `causal-query`
- `causal-compare`
- `causal-loop` query reports
- `causal-advice`

Each tool should:

1. parse optional schema metadata;
2. append shared artifact compatibility warnings near the top of the report;
3. scan parsed events and warn once per unknown event kind;
4. keep existing query, compare, and advice behavior unchanged.

## Testing Strategy

Use TDD with tool-local Zig tests.

Add fixtures for:

- future schema version (`schema_version: 2`);
- unsupported schema family (`schema: "zigeffect.causal.v2"`);
- unknown event kind (`effect_suspended`);
- future taxonomy plus unknown kind to prove both warnings can coexist;
- legacy artifact without metadata to prove no warning churn.

Target test files:

- `packages/zigeffect/tools/causal_artifact.zig`
- `packages/zigeffect/tools/causal_query.zig`
- `packages/zigeffect/tools/causal_compare.zig`
- `packages/zigeffect/tools/causal_loop.zig`
- `packages/zigeffect/tools/causal_advice.zig`

## Documentation Updates

Update:

- `packages/zigeffect/docs/agent-guide.md`
- `packages/zigeffect/README.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

Docs should tell agents:

- compatibility warnings do not make event ids unusable;
- schema warnings mean the tool may ignore future shape fields;
- taxonomy warnings mean role semantics may be incomplete;
- unknown-kind warnings mean query/advice/finding interpretation may be
  incomplete for that event kind.

## Out Of Scope

- Rejecting future schema versions.
- Rejecting unknown event kinds.
- Publishing a full JSON Schema document.
- Adding new causal event kinds.
- Changing artifact schema version numbers.
- Centralizing every remediation/audit artifact schema in this branch.
- CI drift checks for every schema-producing tool.

Those are reserved for future M3/M9 governance work. This branch is fixture and
warning hardening for core causal saved-artifact consumers.

## Acceptance Criteria

- Legacy artifacts without metadata still parse without compatibility warnings.
- Current `zigeffect.causal.v1` artifacts with schema and taxonomy version `1`
  produce no compatibility warnings.
- Future schema versions warn in query, compare, loop query report, and advice
  outputs.
- Unsupported schema names warn in at least query and compare outputs.
- Unknown event kinds warn once per kind per artifact.
- Existing future taxonomy warnings remain present.
- `zig build test --summary none`, `zig build causal-test-matrix`,
  `zig build examples`, `bun run check`, and `bun run zig:test` pass before
  merge.
