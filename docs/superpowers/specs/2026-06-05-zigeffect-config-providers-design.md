# zigeffect Config Providers Design

## Goal

Move config beyond ad hoc test-map mutation by adding reusable provider loading
and a normal layer-friendly config environment.

## Chosen Approach

Keep provider loading data-oriented and Worker-safe. `Config` will load explicit
entries and dotenv/file text supplied by the caller; it will not read process
environment variables or files directly.

This lets Cloudflare, CLI, tests, or future file loaders decide where bytes come
from while the config service owns parsing, overriding, and typed reads.

## Contract

- `ConfigEntry` represents a raw key/value pair.
- `Config.loadEntries(entries)` loads env-style entries and later values
  override earlier values through existing `set`.
- `Config.loadDotEnv(text)` parses simple file text:
  - blank lines and `#` comments are skipped
  - `key=value` lines are loaded
  - surrounding whitespace is trimmed
  - malformed non-empty lines return `error.InvalidConfigValue`
- Existing typed descriptors and secret-safe diagnostics remain unchanged.
- `ConfigEnv` owns a `Config` and exposes `service(fx.Config)`, so apps can
  provide config through ordinary `Layer.fromEnv(...).provides(.{fx.Config})`.

## Tests

- Loading entries sets and overrides config values.
- Loading dotenv text handles comments, whitespace, booleans, and invalid lines.
- A `ConfigEnv` layer can feed a dependency-injected graph startup builder.
