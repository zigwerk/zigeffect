# zigeffect Test Fixtures Design

## Goal

Add a lightweight fixture/golden-output registry to the test toolkit so agents
can store deterministic expected output near the test environment.

## Chosen Approach

Add `TestFixtureRegistry`, a small owned string map, and include one registry on
`TestEnv`. This keeps fixture storage test-only and avoids mixing it into core
runtime or services.

## Contract

- Fixtures are named string values.
- Setting an existing fixture replaces the old owned value.
- `expect(name, actual)` compares actual text against the stored golden text.
- Missing fixtures return `error.ExpectedFixtureNotFound`.
- `TestEnv.expectGolden` delegates to its registry.

## Tests

- TestEnv can store and assert golden output.
- Replacing a fixture updates the expected value.
- Missing fixture assertions return `ExpectedFixtureNotFound`.
