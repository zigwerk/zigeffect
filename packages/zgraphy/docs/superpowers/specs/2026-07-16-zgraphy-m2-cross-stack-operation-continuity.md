# zgraphy M2.5 Cross-stack Operation Continuity

## Outcome

zgraphy proves that a TypeScript frontend callsite and a Zig backend handler
participate in the same canonical Proto operation. The proof is assembled from
source syntax, exact import resolution, strict generated-code lineage and a
known ZigEffect gRPC registration recipe. No relationship is promoted from a
shared spelling alone.

The first supported path is:

1. a TypeScript variable receives `createClient(ServiceDescriptor, transport)`;
2. a function calls a method on that exact client binding;
3. the imported service descriptor and method are generator-proven
   Protobuf-ES bindings;
4. both map to one canonical Proto service and operation;
5. a Zig `GeneratedDriverBinding(GeneratedService, Implementation)` imports a
   generator-proven protoc-gen-zig service descriptor; and
6. the generated operation field maps by the ZigEffect adapter contract to the
   same-named method inside the exact implementation container.

The result supports the agent question “what Zig handler implements this
frontend call?” with a directed source-grounded proof path.

## Shared parser contract

`zigeffect-std.Parser` advances to structural-facts v4 with two general facts:

- `CallArgument` records the containing call span, zero-based argument index,
  expression kind, compact source expression and exact argument span.
- `CallBinding` records a variable binding whose initializer is a direct call,
  including its lexical scope, declaration/name spans and exact call span.

Arguments are syntax facts, not evaluated values. Expressions are bounded by
the existing label budget. The TypeScript provider emits them from named
tree-sitter children, preserves source order and includes them in ownership,
validation, summaries and fingerprints. Proto results carry empty arrays.

This contract is intentionally framework-neutral. Connect recognition belongs
to zgraphy’s operation-continuity resolver, not the parser package.

## Protobuf-ES method identity

Strict generated lineage continues to require the exact protoc-gen-es header,
source-file marker and generated path classification. For RPC markers, the
lineage provider also extracts the adjacent descriptor property identifier from
the generated syntax. This preserves real JavaScript method spelling such as
`getOrder` instead of guessing it from canonical `GetOrder` casing.

An RPC marker without one unambiguous descriptor property remains unresolved.
Comments in ordinary or deceptive generated-looking files never become
lineage evidence.

## Frontend proof recipe

For each `CallBinding`, the resolver requires all of the following:

- the call callee resolves lexically to an import binding whose imported name
  is `createClient` and whose exact package is `@connectrpc/connect`;
- argument zero is a bare identifier bound by an explicit static import;
- immutable TypeScript module resolution yields exactly one generated file;
- strict lineage resolves that imported symbol to one canonical Proto service;
- a member call uses the exact call result binding in the same valid lexical
  scope; and
- an operation lineage record in that same generated file has a generated
  symbol exactly equal to the called member.

The frontend source endpoint is the enclosing function/method declaration. A
member call without an enclosing callable is not emitted as an observation or
promoted to a graph invocation edge until a dedicated callsite node kind
exists.

Shadowed client variables, computed members, dynamic service descriptors,
ambiguous modules, barrels with multiple viable origins, missing markers and
name-only matches remain unresolved or ambiguous.

## Backend proof recipe

The first backend adapter recognises ZigEffect gRPC’s public
`GeneratedDriverBinding` recipe. It requires:

- the factory callee is rooted in a binding imported from the exact
  `zigeffect-grpc` package and ends in `.Typed.GeneratedDriverBinding`;
- factory argument zero is a generated service type expression rooted in one
  explicit Zig import;
- factory argument one is a bare implementation-container binding;
- the generated import resolves to one repository file with strict
  protoc-gen-zig service and operation lineage;
- the implementation binding’s initializer is a container declaration; and
- the operation’s generated symbol names exactly one function declaration
  whose span is contained by that implementation container.

The adapter relies on the checked-in ZigEffect recipe contract: generated
service fields are reflected and `@field(Implementation, field.name)` selects
the handler. The adapter version is part of the result fingerprint. Merely
declaring `getOrder`, calling `registerAll`, or sharing a service name is not
evidence.

The initial adapter recognises direct nested factory construction only when the
bound factory result later receives an exact `registerAll` call in the same
enclosing declaration. Low-level literal `Registry.register` support is
deferred to an additional backend recipe.

## Result contract

`rpc_continuity.zig` emits bounded immutable records:

- frontend invocation observations;
- backend handler observations;
- candidate canonical Proto operations;
- status (`resolved` or `ambiguous`) for source observations that have at least
  one canonical candidate;
- evidence paths and exact source spans;
- recipe/provider identity; and
- one deterministic interaction record for every operation with at least one
  resolved frontend and backend participant.

Non-matching or exhausted recipes do not manufacture observations; their
absence is asserted with controlled negative fixtures. Candidates refer to
canonical Proto entity indexes and are ordered independently of source
ingestion order. Duplicate observations are deduplicated by source path, span,
role and canonical operation. Validation recomputes summaries, candidate
ranges, interaction endpoints and fingerprints.

## Graph projection

The MVP graph adds ontology-aligned relations:

- `invokes_operation`: frontend callable to canonical operation;
- `handles_operation`: exact Zig handler to canonical operation.

The canonical operation retains its `uses_request` and `uses_response` edges,
so normal traversal already reaches the shared messages. The resolver’s
interaction record is the single source for the native request-path hyperedge
and feature supernode implemented in M2.6; those structures must not re-infer
continuity from names.

## Benchmark and Graphify comparison

The controlled `fullstack-orders` fixture gains realistic generated
Protobuf-ES and protoc-gen-zig files plus a ZigEffect generated binding. The
fixture includes deceptive clients, shadowed variables, ordinary generated-like
files, a same-named unrelated handler and a binding that is constructed but not
registered.

The pinned Graphify 0.9.17 adapter receipt records whether it can recover the
canonical frontend-to-backend operation path. zgraphy quality is measured on
exact invocation, handler and complete-interaction facts. Performance and
memory are reported, not assumed superior.

## Safety and limits

- no network, model or API key is required;
- all inputs and emitted facts are bounded;
- parser and recipe versions invalidate fingerprints;
- source paths remain canonical repository-relative paths;
- no source body is persisted in continuity results;
- malformed syntax fails through the parser boundary;
- exhausted candidate budgets never become resolved edges; and
- ambiguous candidates remain visible and cannot be silently selected.

## Acceptance

The required deterministic scenario proves:

- TypeScript call arguments and call-result bindings have exact spans,
  ownership, validation and stable fingerprints;
- aliased `createClient` imports and service imports resolve correctly;
- a real generated descriptor member maps to the canonical operation without
  case guessing;
- the exact frontend callable receives `invokes_operation`;
- the exact generated-driver implementation method receives
  `handles_operation` only when `registerAll` is present;
- both observations form one interaction with the canonical request/response
  spine;
- deceptive, shadowed, ambiguous and unregistered examples create no confident
  edge;
- reversed source ingestion produces identical result and graph identities;
- configured fact, candidate and expression bounds fail closed; and
- parser, standard-library and zgraphy Debug/ReleaseSafe Testing v2 receipts
  are complete with no pending tests, leaks, logged errors or truncated proof.

## Non-goals

This slice does not yet persist native hyperedges or supernodes, trace UI
components through wrappers to the client callable, infer response-field use,
support arbitrary Connect factories, low-level manual registry entries,
OpenAPI/HTTP routes, effect/layer/store boundaries or runtime observations.
Those extend the same interaction fact in M2.6 and later M2 slices.
