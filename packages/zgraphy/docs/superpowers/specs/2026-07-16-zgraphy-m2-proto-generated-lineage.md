# zgraphy M2.4: Canonical Proto and Generated-Binding Lineage

## Problem

zgraphy currently places `.proto` files but does not parse their contracts.
Generated Protobuf-ES and protoc-gen-zig files are parsed as ordinary source,
so same-named generated types cannot be proven to originate from one canonical
schema. This prevents exact frontend-to-backend reasoning and causes the
`fullstack-orders` benchmark to miss its service, RPC and message identities.

M2.4 creates the canonical contract spine. Application callsites and concrete
handler registrations consume this spine in M2.5; they are not inferred by
name in this slice.

## Graphify leverage and measured gap

The pinned Graphify 0.9.17 extractor provides useful generated-file detection
and keeps generated stubs separate from rationale extraction. Its controlled
`fullstack-orders` graph contains the Zig and TypeScript files but omits the
`.proto` file and therefore has no canonical service, RPC, message, field or
generated-lineage identities.

zgraphy preserves Graphify's generated-file caution and improves the truth
model:

- canonical identity comes from parsed Proto syntax, never generated labels;
- generated lineage requires a recognized generator marker plus package/file
  evidence and an exact canonical entity match;
- field identity is message identity plus immutable field number, with the
  current source name retained as evidence;
- duplicate definitions and ambiguous source-path suffixes retain candidates;
- unresolved type references and generated markers remain explicit outcomes;
- no repository-wide name-only fallback is permitted; and
- parser, resolver and lineage fingerprints are deterministic and bounded.

## Shared parser contract v3

`zigeffect-std.Parser` advances to structural-facts schema v3. Existing facts
remain source-compatible and four owned Proto fact families are added.

### Proto package

A package fact contains the dotted package name plus complete statement and
name spans. Package-less files remain valid and derive file-scoped declaration
identity; no synthetic global package is invented.

### Proto field

A field fact contains its lexical message owner, field name, declared type,
immutable positive field number, cardinality, optional oneof owner, map key and
value types, complete span, and exact name/type/number spans. Normal, map and
oneof fields are distinguished. Field options are skipped structurally after
the identity-bearing grammar is validated.

### Proto enum value

An enum-value fact contains its lexical enum owner, source name, signed numeric
value and exact spans. Aliases remain distinct source facts even when numeric
values repeat.

### Proto RPC

An RPC fact contains its lexical service owner, method name, request and
response type references, client/server streaming flags and exact method,
request and response spans.

Generic declaration facts use the existing `message`, `service`, `rpc`,
`field`, and `enumeration` kinds. Proto imports use generic static import facts.

## Native Proto provider

`zigeffect-parser.ProtocolBuffers` is an offline hand-written lexer and parser
for identity-bearing Proto2, Proto3 and Editions syntax. A dedicated parser is
preferred here to another C grammar because it keeps the supported grammar,
bounds and error behavior reviewable in Zig and avoids a runtime dependency.

The lexer recognizes identifiers, dotted names, integers, strings, punctuation
and comments while retaining exact byte/line/column spans. It enforces source,
token, recursion, fact and label bounds. Comments and string contents cannot
become declarations.

The parser supports syntax/edition declarations, packages, normal/public/weak
imports, nested messages and enums, services, unary and streaming RPCs, normal,
optional, required, repeated, map and oneof fields, enum values, options,
reserved declarations and structurally skipped extension/custom-option bodies.
Malformed identity-bearing constructs fail closed. Unsupported constructs are
reported rather than partially promoted.

## Pure Proto semantic resolver

`protobuf_resolution.zig` owns parsed snapshots and emits immutable entities,
references, candidates, diagnostics, summary counts and a SHA-256 fingerprint.

Canonical names are:

- package: the dotted package name;
- message/enum: `<package>.<lexical-name>`;
- service: `<package>.<service>`;
- operation: `<package>.<service>/<rpc>`;
- field: `<message>#<field-number>` with source label `<message>.<name>`; and
- enum value: `<enum>.<name>`.

Type references resolve by Proto lexical rules: leading-dot absolute names,
innermost enclosing message prefixes, current package, then exact imported
definitions. Only inventory files matching a validated Proto import path may
contribute imported candidates. Duplicate canonical definitions remain
ambiguous. Well-known or absent external definitions remain unresolved/external
and cannot bind to a local same-named type.

Operations own exact request/response candidate sets. Fields own exact type
candidate sets for message/enum references; scalar types require no candidate.

## Generated binding lineage

`generated_lineage.zig` accepts generated source only when discovery marks it
generated and a strict generator header is present.

### Protobuf-ES

The provider consumes exact comments emitted by protoc-gen-es:

- `@generated from file ... (package ..., syntax ...)`;
- `@generated from message <fqn>`;
- `@generated from enum <fqn>`;
- `@generated from service <fqn>`; and
- `@generated from rpc <service>.<method>`.

The source-file marker is resolved by exact repository path or unique safe
suffix. Entity markers must match the canonical Proto result and declaration
kind. RPC dot notation is normalized to the canonical service-slash-method
identity.

### protoc-gen-zig

The provider requires `// Code generated by protoc-gen-zig` and the exact
`///! package <name>` marker. Generated top-level structs/enums and service
factory functions are matched within that package. Service function fields are
matched to canonical RPCs. Package evidence plus generated shape is required;
a same-named ordinary Zig declaration is never lineage evidence.

Generated files link to their exact source Proto candidates. Generated message,
enum, service and operation symbols link to canonical entities. Ambiguity is
retained with all candidates and generated artifacts never replace source
truth.

## Graph materialization

Repository discovery promotes Proto files to deep indexing. The graph adds
runtime node kinds for type, service, operation, message and field and uses the
existing canonical schema-v2 names.

Relations added to the MVP compatibility layer are:

- `has_field`: message to immutable-number field;
- `uses_request` / `uses_response`: operation to message candidates;
- `references_type`: field to message/enum candidate;
- `generated_from`: generated file or binding to canonical source/entity;
- `generated_client_for`: Protobuf-ES service binding to Proto service; and
- `generated_server_for`: generated Zig service binding to Proto service.

Canonical entities use source-qualified IDs; field IDs use canonical message
plus field number. Generated binding IDs include generated path, declaration
kind and canonical identity. Resolved and ambiguous provenance is preserved.

## Acceptance

The controlled fixture and real generator samples must prove:

- package, imports, nested messages/enums, fields, oneofs, maps, enum values,
  services and all four RPC streaming shapes parse with exact spans;
- field-number identity survives source-name differences and duplicate numbers
  are rejected within one message;
- request, response and field type references resolve without global fallback;
- duplicate canonical definitions and ambiguous import suffixes retain all
  candidates;
- Protobuf-ES and protoc-gen-zig files and symbols link to exact canonical
  source entities only with strict generator evidence;
- ordinary same-shaped TS/Zig source receives no generated lineage;
- the `fullstack-orders` fixture gains canonical service, RPC, request and
  response entities that Graphify 0.9.17 omits;
- sequential fingerprints and graph identities are deterministic;
- malformed input and every configured bound fail with typed outcomes; and
- Debug/ReleaseSafe Testing v2 receipts are complete with zero pending tests,
  leaks, logged errors, findings, stale references or truncated evidence.

## Non-goals

M2.4 does not infer that an application client call invokes an RPC or that a
Zig handler implements it. It does not build request-path hyperedges,
supernodes, schema compatibility impact, descriptor-set decoding, reflection
registries, OpenAPI identities or runtime confirmation. Those consume this
canonical spine in M2.5 and later slices.
