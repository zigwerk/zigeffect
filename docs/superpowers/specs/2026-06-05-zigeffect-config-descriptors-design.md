# zigeffect Config Descriptors Design

Date: 2026-06-05

## Goal

Deliver the first roadmap section 9 slice by moving `Config` from raw string map
only to typed descriptors over the existing deterministic provider.

## Contracts

- Existing `Config.set`, `get`, and `require` behavior stays unchanged.
- `Config.string(key)`, `Config.int(key)`, and `Config.boolean(key)` create typed
  descriptors.
- Descriptors can carry defaults and a secret/redaction marker.
- `config.read(descriptor)` returns the typed value or `error.MissingConfig` /
  `error.InvalidConfigValue`.
- `formatConfigError` formats missing/invalid diagnostics without printing
  secret values.

## Non-Goals

- No environment or file providers yet.
- No schema-wide config loading yet.
- No secret storage or decryption; redaction is diagnostic-only.

## Tests

- Typed descriptors read string, integer, and boolean values.
- Descriptor defaults are used when keys are missing.
- Invalid conversion returns `InvalidConfigValue`.
- Secret diagnostics include the key and redaction hint but not raw values.
