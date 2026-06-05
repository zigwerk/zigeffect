# zigeffect Static Requirements Design

## Goal

Add a Zig-native compile-time requirement check for cases where provider and
consumer metadata are both known as types.

## Chosen Approach

Keep runtime `DependencyReport` validation as the general path. Add a small
static helper pair for compile-time known layer/effect types:

- `staticRequirementsSatisfied(ProviderType, ConsumerType) bool`
- `assertStaticRequirementsSatisfied(ProviderType, ConsumerType) void`

Static helpers use wrapper declarations such as `ProvidedServices` and
`RequiredServices`. They do not attempt to inspect dynamic runtime providers.

## Contract

- Consumers without `RequiredServices` are considered satisfied.
- Providers without `ProvidedServices` satisfy only consumers with no static
  requirements.
- `assertStaticRequirementsSatisfied` emits a stable diagnostic naming the
  missing service, provider type, and consumer type.
- Runtime validation remains the source of rich reports and dynamic provider
  checks.

## Tests

- Static helper returns true for a layer type that provides all effect
  requirements.
- Static helper returns false when a provider type is missing a requirement.
- Compile-fail fixture verifies the stable static assertion diagnostic.
