# zigeffect Causal Redaction Hardening Design

## Purpose

`zigeffect` now emits versioned and bounded causal artifacts for development
agents. The next hardening gap is secret safety. Today the field name
`redacted_detail` asks callers to pass safe text, but `CausalStore` stores and
exports the supplied value exactly. A command failure, config error, or app
event can still leak secret-shaped text into JSON or text reports.

This slice adds deterministic defensive redaction at the causal store boundary.

## Current Shape

`CausalStore.record` clones event string fields into owned memory. Reports,
findings, snapshots, query helpers, and JSON artifacts later reuse those stored
strings. `formatCausalCiReport` avoids raw detail payloads, but
`formatCausalReport` and `formatCausalJson` export `redacted_detail`.

The safest first change is to sanitize the stored event once before it reaches
any artifact path.

## Design Decision

Redact event strings at store time:

- `label`
- `type_name`
- `status`
- `redacted_detail`

`redacted_detail` remains the normal caller-facing field for safe diagnostics.
The other fields are sanitized as a backstop in case a command or app records
secret-shaped text in the wrong place.

The redaction policy is deterministic and small:

- redact values after sensitive keys followed by `=` or `:`;
- redact bearer token values;
- redact URL credentials between `://` and `@` when the authority contains a
  password separator;
- leave ordinary diagnostic values untouched.

Examples:

```text
database.password=hunter2 -> database.password=<redacted>
api_key: sk-proj-123 -> api_key: <redacted>
Authorization: Bearer abc -> Authorization: <redacted>
postgresql://root:secret@localhost/db -> postgresql://<redacted>@localhost/db
attempt=2 delay_ms=null decision=exhausted -> unchanged
```

## Why Store-Time Redaction

Store-time redaction protects all downstream consumers:

- snapshots;
- findings;
- text reports;
- CI reports;
- JSON artifacts;
- DOT labels when labels contain sensitive key/value text;
- future backend adapters that receive stored events.

Formatter-only redaction would leave raw secrets in snapshots, query helpers,
and backend event sinks.

## Scope

In scope:

- deterministic redaction helper in `services/causal.zig`;
- redaction of stored event string fields;
- tests proving JSON, text reports, snapshots, findings, and backend events do
  not retain common secret-shaped values;
- docs explaining that callers should still avoid passing secrets.

Out of scope:

- full PII detection;
- redacting arbitrary high-entropy strings without a key;
- schema-version bump;
- redacting legacy saved JSON artifacts parsed by query tools.

## Acceptance Criteria

- Causal JSON artifacts do not contain raw values for password, token, API key,
  authorization, bearer, or URL credential examples.
- `CausalStore.snapshot` returns sanitized strings.
- Attached backends receive sanitized stored events.
- Safe diagnostic details such as retry attempts remain unchanged.
- Existing causal examples, package tests, dogfood harness, and dev loop still
  pass.
