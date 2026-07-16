# zgraphy M1 universal discovery implementation plan

## Task 1: executable acceptance contract

- Add `req-m1-universal-discovery`, its check and controlled Testing v2 scenario.
- Add a mixed-language fixture with ignored and sensitive examples.
- Capture the expected red result before runtime implementation.

## Task 2: deterministic universal discovery

- Add bounded, non-following root-relative traversal.
- Add independent language, artifact and role classification.
- Add terminal disposition accounting and deterministic fingerprints.
- Conceal sensitive names and verify complete manifest reconciliation.
- Materialise repository, directories and safe files.

## Task 3: indexer integration

- Replace the Zig-only prefilter with the discovery result.
- Reuse file placement identities during Zig and manifest extraction.
- Verify source content against the observed digest before deep indexing.
- Expose discovery summary and manifest digest in build evidence.

## Task 4: persistent identity and root/config contract

- Generate and persist an opaque repository identifier at init.
- Add config-v2 discovery limits and validate effective configuration.
- Implement idempotent v1-to-v2 migration without losing user values.
- Thread configured identity and bounds through the CLI build command.

## Task 5: workspace ownership and adapters

- Discover nested repositories, worktrees, submodules and monorepo roots.
- Parse Zig, JS/TS, Python, Cargo, Go and Proto ownership/build manifests.
- Assign every safe file to repository, package or explicit unowned context.
- Add first application, package, library and build-target placement nodes.

## Task 6: diagnostics and M1 exit audit

- Persist/explain the deterministic content manifest.
- Add machine-readable effective-config and graph-health output.
- Implement `zgraphy doctor` with typed, clean JSON diagnostics.
- Exercise binary, oversized, symlink, unreadable, nested-ignore and limit cases.
- Run the M1 scenario, full Debug and ReleaseSafe suites, safety policy and
  project agent check; inspect complete Testing v2 receipts before promotion.

