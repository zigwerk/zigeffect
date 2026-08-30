# zgraphy M2.3b2: TypeScript Symbol and Call Resolution

## Problem

M2.3b1 resolves a TypeScript or JavaScript module occurrence to exact repository
files, but a module edge is not yet a symbol edge. Agents still cannot reliably
ask which declaration a named/default import denotes, follow a barrel to its
origin, distinguish namespace members, or connect an imported or receiver-typed
call to the owned callable. Repository-wide label matching would make these
questions look answered while manufacturing cross-package dependencies.

This slice builds symbol and call meaning strictly on the immutable module
identities already proven by `typescript_resolution.zig`.

## Graphify leverage and improvements

The pinned Graphify 0.9.17 reference proves important behavior in
`graphify/extract.py`, `graphify/extractors/resolution.py`,
`graphify/symbol_resolution.py`, `test_js_import_resolution.py`,
`test_ts_receiver_member_calls.py`, `test_phantom_cross_package_call.py`,
`test_import_extension_resolution.py`, and the barrel tests in
`test_extract.py`:

- named, aliased, default, namespace and import-require bindings;
- named, aliased, namespace and star re-exports;
- default declarations and `export default Identifier`;
- long barrel chains, cycles with valid non-cycle branches, and type-only
  symbols;
- imported direct calls and namespace-member calls;
- static class receivers, local `new` bindings, constructor parameter
  properties, fields and bare typed parameters; and
- suppression of unimported cross-package calls, untyped receivers, array or
  chained receivers, and ambiguous receiver types.

zgraphy preserves that useful behavior and tightens the truth model:

- export and receiver evidence are typed shared parser facts, not raw extractor
  dictionaries or a second AST walk in the graph builder;
- symbol resolution consumes the exact M2.3b1 module candidate sets and never
  performs global-name fallback;
- every import, export, alias and call has an owned resolved, ambiguous,
  unresolved, invalid or exhausted result with retained candidates;
- barrel cycles are bounded diagnostics while independent branches continue;
- duplicate export names and duplicate type identities remain ambiguity sets
  rather than proximity-selected winners;
- lexical receiver bindings carry scope spans, so nested shadowing cannot leak;
- default export identity is explicit and never guessed from a filename or
  first declaration;
- origin symbols survive arbitrarily long bounded barrel chains rather than a
  fixed sixteen-hop heuristic; and
- deterministic fingerprints and graph provenance include parser, module
  resolver and symbol resolver versions.

## Shared parser contract v2

`zigeffect-std.Parser` advances to structural-facts schema v2. Existing
declaration, import, import-binding and call fields remain, and two owned fact
families are added.

### Export facts

An export fact contains:

- `target`: source module specifier, empty for local exports;
- `imported`: name in the source module or local scope, `*` for star export;
- `exported`: public name, `default` for default exports;
- `kind`: local named, local default, re-export named, re-export namespace,
  re-export star, CommonJS named or CommonJS default;
- `type_only`;
- complete statement, source-target and exported-name spans.

The TypeScript provider emits facts for:

- `export { Local as Public }` and `export type { ... }`;
- `export { Origin as Public } from "..."`;
- `export * from "..."` and `export * as ns from "..."`;
- `export default function/class Name`, `export default Name`, and named local
  declarations already marked exported; and
- bounded static CommonJS assignments where an exact local name is visible.

Anonymous default expressions remain explicit unsupported/default-expression
facts without an invented declaration identity.

### Type-binding facts

A type-binding fact contains:

- `binding`: receiver expression visible at calls, such as `svc` or
  `this.repository`;
- `type_name`: an exact bare source type name or imported local alias;
- `kind`: parameter, constructor parameter property, field, local annotation,
  or constructor instance;
- `enclosing_declaration`;
- declaration/name/type spans; and
- a lexical `scope_span` in which the binding is valid.

The provider intentionally omits unions, arrays, indexed/chained expressions,
computed properties, generic instantiations that cannot be reduced to one bare
type, and computed constructor targets. Omission is safer than a guessed type.

## Pure symbol resolver

`typescript_symbols.zig` owns a second pure snapshot corpus. During the same
verified-source pass used for module resolution, it copies declarations,
imports, import bindings, exports, type bindings and calls from parser results.
It retains no tree-sitter nodes or filesystem pointers.

`resolve(module_result)` freezes and sorts the corpus, validates that both
results describe the same source paths and module occurrences, builds exact
declaration/export indexes, resolves imports and re-exports, resolves calls,
and returns owned facts, candidate ranges, diagnostics, summaries and a SHA-256
fingerprint.

### Symbol identity

Declaration identity is source path plus lexical owner plus declaration kind
plus exact name. Class methods are owned by their class; nested declarations
and same-name methods do not collapse. A public export name is an alias to one
or more declaration identities, never a replacement identity.

### Export closure

Each module starts with explicit local exports. Named re-exports resolve one
public name through one resolved source module. Star exports contribute every
non-default public name. Namespace re-exports create one owned namespace export
whose members point to the source module's export map.

Traversal uses an explicit stack and configurable depth/work bounds. A cycle
records its exact module chain and stops only that branch. Other named or star
branches continue. Multiple origins for one public name produce an ambiguous
candidate set. Declaration order cannot silently select a winner.

Local export aliases may refer to a local declaration or an imported binding.
This supports `import { Foo as LocalFoo }; export { LocalFoo as PublicFoo }`
without creating a barrel-local phantom declaration.

### Import bindings

A binding is resolved only through its matching source-qualified module
resolution:

- named imports request the module's public exported name;
- default imports request explicit `default`;
- namespace and import-require bindings denote a namespace over the resolved
  module; and
- CommonJS destructuring/named bindings use only parser-proven static names.

Ambiguous module candidates or ambiguous public exports retain all candidates.
External and unresolved modules cannot bind to same-named local declarations.

### Calls

Direct calls resolve in this order:

1. exact same-file lexical callable;
2. exact imported local binding to exported callable;
3. exact local alias whose origin is one of the above.

There is no repository-wide single-name fallback for TypeScript/JavaScript.

Member calls resolve only when the receiver has one supported evidence path:

1. namespace import/re-export member;
2. imported or same-file class used as an explicit static receiver;
3. innermost in-scope type binding from a local `new` expression;
4. innermost bare typed parameter or local annotation; or
5. class field/constructor property represented as `this.field`.

The receiver type itself is resolved through same-file or import/export
evidence. The target class and owned method must each have one candidate;
otherwise the call is ambiguous or unresolved. Untyped, array/indexed,
inherited-only and chained receivers do not gain edges in this slice.

## Graph materialization

Repository indexing becomes a deterministic multi-pass pipeline:

1. parse and copy all source facts;
2. create every file, declaration and class-owned method node;
3. resolve modules;
4. resolve symbols and calls; and
5. materialize only validated results.

New MVP relations map to existing canonical schema-v2 semantics:

- `imports_from`: local import binding or imported symbol to origin module;
- `aliases`: local/public alias to origin symbol;
- `re_exports`: barrel module/public alias to origin symbol or namespace;
- `instantiates`: constructor call to exact class; and
- existing `calls`, `dispatches_to`, `imports`, `resolves_to` and `references`
  retain their current meanings.

Resolved symbol/call edges use resolver provenance; ambiguous candidates use
ambiguous provenance. Parser-observed ownership and export statements remain
extracted. Unresolved facts stay queryable without a target edge.

## Limits and diagnostics

Limits cover files, declarations, exports, bindings, calls, labels, owned
bytes, export names, candidates per fact, total candidates, re-export depth,
re-export work, namespace members, lexical depth, diagnostics and result bytes.
All arithmetic is checked. Diagnostics identify source path, fact span, stable
kind and redacted detail; source bodies are never persisted in diagnostics.

## Acceptance

The controlled fixture and pinned Graphify overlap must prove:

- local named/default exports and explicit default identifiers;
- named/default/aliased/type-only imports to exact origin declarations;
- named aliases, local-import aliases, star and namespace re-exports;
- a barrel chain longer than sixteen hops and a cycle with a valid side branch;
- namespace member access and imported direct/default calls;
- same-file calls without cross-file name fallback;
- imported class static calls, local `new` receivers, constructor properties,
  fields and closure-over-bare-typed-parameter receivers;
- exact class ownership when another class exposes the same method name;
- no call edge for unimported cross-package names, untyped receivers, arrays,
  indexed/chained receivers, duplicate types or unresolved exports;
- deterministic sequential fingerprints and graph identities;
- typed depth, candidate, fact and result exhaustion without leaks; and
- complete Debug/ReleaseSafe Testing v2 receipts with no findings, pending
  fibers, leaks, logged errors, truncation or stale evidence.

## Non-goals

This slice does not implement a TypeScript checker, overload selection,
inheritance dispatch, generic substitution, union narrowing, optional chaining
semantics, JSX component flow, decorators, framework routes, callback
registration, Proto identities or generated-client lineage. Those consume this
symbol spine in later M2 slices.

## Delivered evidence

The slice is implemented in `typescript_symbols.zig` and the repository
indexer. Its controlled fixture covers an eighteen-hop barrel, a cycle with an
independent valid branch, named/default/type-only/namespace/local aliases,
scoped receiver evidence, competing class methods and deliberate phantom-call
suppression. The pinned Graphify 0.9.17 graph digest and overlap ledger retain
nine shared positive facts, three shared negative facts and four classified
improvements. Debug and ReleaseSafe Testing v2 receipts are complete with no
pending tests, logged errors, leaks, findings, stale references or truncated
artifacts.
