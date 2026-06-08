# zigeffect Causal PII Redaction Policy Design

Date: 2026-06-08

## Purpose

This is the first production-hardening slice of M3 from the causal agent
runtime roadmap. It expands `CausalStore`'s defensive redaction policy before
app-facing request and job traces are enabled by default.

The goal is to keep causal artifacts useful for agents while reducing the risk
that common application, infrastructure, and HTTP payload shapes leak secrets
or personal data into snapshots, reports, JSON artifacts, DOT output, or
attached backends.

This branch does not try to build a full PII classifier. It adds deterministic,
testable redaction rules for common structured shapes that are likely to appear
in effect labels, statuses, type names, and diagnostic details.

## Current Baseline

`packages/zigeffect/src/services/causal.zig` already redacts causal event
strings at store time through `cloneEvent`. This protects every downstream
consumer because snapshots, reports, query helpers, JSON artifacts, DOT labels,
and backend sinks reuse the stored strings.

The existing policy covers:

- sensitive key/value pairs such as `password=hunter2`, `token: raw`, and
  `database.password=raw`;
- bearer values such as `Authorization: Bearer raw-token`;
- URL credentials such as `postgresql://user:pass@host/db`;
- safe diagnostics such as `attempt=2 delay_ms=null decision=exhausted`.

The gap is breadth. App-facing traces often contain HTTP headers, cookies,
JSON-ish snippets, SQL-ish connection metadata, nested config keys, and
identity fields. The current scanner catches some of these only when they
already look like a simple unquoted key/value pair.

## Design Decision

Extend store-time redaction with a broader deterministic policy.

The policy remains:

- local to `services/causal.zig`;
- allocation-aware and deterministic;
- applied before any backend receives the event;
- compatible with the existing `zigeffect.causal.v1` schema because field
  shape does not change;
- documented as a safety backstop, not permission to record secrets.

### Rule Families

#### 1. Sensitive Security Keys

Expand the key catalog to cover common header, cookie, session, credential, and
connection-string names:

- `authorization`
- `proxy-authorization`
- `cookie`
- `set-cookie`
- `x-api-key`
- `x-auth-token`
- `api_key`
- `apikey`
- `token`
- `access_token`
- `refresh_token`
- `id_token`
- `session`
- `session_id`
- `sessionid`
- `csrf`
- `xsrf`
- `password`
- `passwd`
- `pwd`
- `secret`
- `client_secret`
- `private_key`
- `connection_string`
- `database_url`

The existing suffix behavior remains: `database.password`,
`headers.authorization`, `config.database_url`, and similar dotted or dashed
keys redact by their final sensitive segment.

#### 2. Personal Data Keys

Add a conservative personal-data key catalog for values that are rarely useful
inside causal event diagnostics and are risky in app-facing traces:

- `email`
- `phone`
- `phone_number`
- `ssn`
- `social_security_number`
- `address`
- `street_address`
- `ip`
- `ip_address`
- `user_ip`
- `date_of_birth`
- `dob`

These keys are intentionally key-bound. The scanner should not redact arbitrary
email-shaped, phone-shaped, or IP-shaped strings without a nearby key. That
keeps error messages and type names readable and avoids overclaiming PII
detection.

#### 3. Quoted Key/Value Forms

Support JSON-ish and config-ish quoted keys and values:

```text
"password":"hunter2" -> "password":"<redacted>"
'token': 'raw-token' -> 'token': '<redacted>'
headers.authorization: "Bearer raw" -> headers.authorization: "<redacted>"
```

The scanner does not need to parse JSON. It only needs to recognize a sensitive
key followed by optional whitespace, `:` or `=`, optional whitespace, and an
optional single or double quote. If the value is quoted, redact until the
matching quote or end of string. If unquoted, preserve the existing delimiter
rules.

#### 4. Cookie/Header Payloads

Cookie-style payloads should redact the whole sensitive header value:

```text
Cookie: sid=raw; theme=dark -> Cookie: <redacted>
Set-Cookie: sid=raw; HttpOnly -> Set-Cookie: <redacted>
Proxy-Authorization: Basic raw -> Proxy-Authorization: <redacted>
```

`Authorization`-style keys continue using hard delimiters so values with spaces
are redacted as one header value.

#### 5. URL Query Parameters

The key/value scanner already handles query parameters when the key is
unprefixed, such as `?api_key=raw`. This branch should make that behavior
explicitly tested and keep safe query parameters visible:

```text
https://api.test/v1?api_key=raw&tenant=demo
https://api.test/v1?api_key=<redacted>&tenant=demo
```

#### 6. SQL-ish And Config Map Payloads

SQL-ish and config-map diagnostics are not parsed as SQL. They are covered via
the same deterministic key/value scanner:

```text
user_email='a@example.com' password 'raw'
config={database_url:"postgresql://root:pw@db/app", retry_count:2}
```

This branch should cover the common forms that are safe to scan without a full
parser:

- `key=value`
- `key: value`
- `key 'value'`
- `key "value"`
- `key:"value"`
- `key='value'`

If a SQL string does not include a key from the redaction catalog, it remains
unchanged.

## Approaches Considered

### Recommended: Deterministic Scanner Extension

Extend the current scanner with a richer key catalog and quoted-value support.

Pros:

- preserves the current store-time boundary;
- deterministic and fast;
- easy to test in Zig without optional dependencies;
- no schema bump;
- low risk of hiding causal evidence unrelated to sensitive fields.

Cons:

- does not catch arbitrary free-text PII;
- requires explicit fixtures for new payload shapes.

### Alternative: Parse JSON/Headers/URLs Separately

Add shape-specific parsers for JSON, HTTP headers, URLs, and SQL-like payloads.

Pros:

- more exact for well-formed payloads;
- could preserve more non-sensitive nested data.

Cons:

- substantially more complexity;
- event fields are arbitrary strings, so most values are partial fragments;
- SQL-ish diagnostics still require a fallback scanner;
- higher risk of parser edge cases changing artifact output.

### Alternative: High-Entropy Or Regex-Like PII Detection

Redact values that look like secrets, emails, IPs, phone numbers, or tokens
even without a nearby sensitive key.

Pros:

- catches more accidental leaks.

Cons:

- likely to redact useful type names, effect labels, IDs, and diagnostic
  strings;
- harder to explain deterministically to agents;
- more false positives in tests and docs;
- still incomplete without a real privacy engine.

The recommended scanner extension is the right M3 first slice. It materially
reduces app-trace risk while keeping the runtime graph inspectable.

## Data Flow

```text
caller records CausalEvent
  -> CausalStore.record applies sampling/retention policy
  -> cloneEvent redacts all string fields
  -> in-memory events receive redacted strings
  -> attached backend receives redacted strings
  -> snapshots/reports/JSON/DOT/query helpers reuse redacted strings
```

No downstream formatter should need its own privacy patch for this branch.

## Testing Strategy

Use TDD against `packages/zigeffect/test/services_test.zig`.

Add focused tests for:

- HTTP headers and cookies:
  - `Cookie`
  - `Set-Cookie`
  - `Proxy-Authorization`
  - `X-Api-Key`
- JSON-ish quoted payloads:
  - double-quoted keys and values;
  - single-quoted keys and values;
  - nested dotted keys;
- URL query parameters:
  - secret query parameter redacted;
  - safe query parameter preserved;
- SQL-ish/config payloads:
  - key followed by quoted value without `=` or `:`;
  - nested config key with URL credential value;
- personal-data keys:
  - `email`, `phone_number`, and `ip_address` redacted only when key-bound;
  - ordinary safe retry diagnostics remain unchanged.

Each test should verify store snapshots, backend state where relevant, and at
least one export path for the absence of raw values.

## Documentation Updates

Update:

- `packages/zigeffect/docs/agent-guide.md`
- `packages/zigeffect/README.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

The docs should say:

- causal redaction covers common secret, header, cookie, URL credential,
  query-parameter, JSON-ish, config-ish, SQL-ish, and key-bound personal-data
  forms;
- the redactor is deterministic and key-bound;
- callers must still avoid intentionally recording secrets, prompts, request
  bodies, credentials, or personal data in causal events;
- app-facing adapters should emit compact semantic diagnostics instead of raw
  payloads.

## Out Of Scope

- General natural-language PII detection.
- Redacting arbitrary unkeyed email, phone, IP, or token-looking substrings.
- Parsing full JSON, SQL, HTTP, or URL grammars.
- Schema-version bump for `zigeffect.causal.v1`.
- Retroactive redaction of already-saved artifacts.
- Artifact size truncation metadata.
- Schema/taxonomy drift checks.
- Durable backend storage policy.

Those remaining hardening items stay in later M3 branches.

## Acceptance Criteria

- New tests fail before implementation and pass after the scanner extension.
- Raw sample values for the new header, cookie, JSON-ish, query, config,
  SQL-ish, and key-bound personal-data fixtures do not appear in snapshots,
  backend events, text reports, or JSON exports.
- Safe retry diagnostics remain unchanged.
- Existing redaction behavior remains compatible.
- `zig build test --summary none` passes for `packages/zigeffect`.
- `bun run check` and `bun run zig:test` pass from the repo root before merge.
