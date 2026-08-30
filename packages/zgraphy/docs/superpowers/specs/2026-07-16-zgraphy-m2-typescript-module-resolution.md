# zgraphy M2.3b1: TypeScript Module Resolution

## Problem

The native parser now emits exact TypeScript, TSX, JavaScript, and JSX imports,
but raw module specifiers are not repository identities. Real frontend projects
use extensionless imports, TypeScript ESM `.js` spellings, directory indexes,
JSONC tsconfig aliases, inherited `baseUrl` and `paths`, workspace package
names, conditional package exports, dynamic imports, and CommonJS require.

Without a deterministic repository resolver, zgraphy either drops these
relationships or risks inventing edges from names. Proto and generated-client
linkage must not begin until source modules resolve without global-name guesses.

## Graphify leverage and improvements

The pinned Graphify implementation proves useful behavior in
`graphify/extractors/resolution.py`, `test_import_extension_resolution.py`,
`test_js_import_resolution.py`, and `test_phantom_external_import.py`:

- exact-file, `.js` to `.ts`, `.jsx` to `.tsx`, extension, and directory-index
  resolution with file-before-directory precedence;
- multi-dot and Svelte rune source files;
- JSONC tsconfig parsing, `baseUrl`, path patterns, multiple targets, recursive
  string/array `extends`, cycle tolerance, and specificity ordering;
- pnpm and package-json workspaces, package names, root/subpath/wildcard
  `exports`, condition priority, entry fallbacks, and containment checks; and
- namespaced unresolved externals that cannot collide with local files.

zgraphy preserves those behaviors and improves the evidence model:

- resolution runs against the immutable, content-hashed discovery inventory
  rather than repeated filesystem existence probes;
- every import has a typed resolved, external, unresolved, ambiguous, invalid,
  or exhausted outcome instead of a nullable path;
- all candidates and the rule that produced them are retained deterministically;
- duplicate workspace package names are ambiguous rather than last-writer-wins;
- malformed or cyclic config is a bounded diagnostic, never a silent skip of
  the importing source file;
- repository-relative identities never depend on cwd or absolute temp paths;
- dynamic imports remain deferred relationships and cannot manufacture static
  dependency cycles; and
- path traversal, absolute paths, backslashes, export targets outside package
  roots, excessive wildcard expansion, and resource exhaustion fail closed.

## Boundary

`typescript_resolution.zig` owns a pure repository-snapshot resolver. A corpus
is populated with:

- every safe placed file path from discovery;
- verified tsconfig, package-json, and pnpm-workspace document bytes; and
- import facts copied from `zigeffect-parser` results.

It retains no parser-tree or filesystem pointers. `resolve` freezes and sorts
the corpus, validates bounds, derives configuration and workspace indexes, and
returns owned resolutions, candidates, diagnostics, summary counts, and a
SHA-256 fingerprint.

The indexer reads every source/config document through the existing discovery
digest check before adding it. Resolution therefore describes exactly the
generation being built. A file changed after discovery aborts publication.

## Module rules

Resolution order is explicit:

1. A relative specifier is normalized against the importing file directory.
2. An exact safe inventory path wins.
3. `.js` and `.jsx` spellings try `.ts` and `.tsx` source substitutions.
4. Source extensions are appended to the full name in this order: `.ts`,
   `.tsx`, `.mts`, `.cts`, `.svelte`, `.js`, `.jsx`, `.mjs`, `.cjs`.
5. Only after file candidates lose, directory indexes are tried in the declared
   source-first order.
6. A non-relative specifier tries the nearest effective tsconfig alias set.
7. If no alias matches, it tries the nearest containing workspace package map.
8. A syntactically valid unmatched bare specifier is external; a relative,
   alias, or workspace target that should be local but is missing is unresolved.

One-star tsconfig and export patterns are supported. Exact aliases outrank
wildcards; wildcards use longest prefix and then longest suffix; the existing
directory-prefix compatibility form is last. Targets retain declaration order.
The first existing target wins. Config inheritance processes parents in order,
then child aliases override by exact key. Parent targets remain rooted at the
parent config directory and its own `baseUrl`.

Workspace membership is established by safe glob matching over discovered
package directories. Pnpm workspace declarations take authority over root
package-json workspaces when both exist. Package exports support strings,
condition objects, bounded arrays, exact and one-star subpaths. Target paths
must remain inside the package directory. Root fallback order is `source`,
`types`, `svelte`, `module`, `browser`, `main`, then `src/index` and `index`.

## Parser additions

The shared parser contract adds explicit dynamic-import and CommonJS-require
import kinds. The native TypeScript provider emits module import facts from
`import("...")` and `require("...")` only when the first argument is a static
string literal. Computed arguments remain calls without fabricated targets.

## Graph materialization

Each import occurrence becomes a source-qualified `module_reference` node.
The importing file points to it with `imports` or `deferred_imports`. The
reference points to every retained local candidate with `resolves_to`; one
resolved candidate is extracted provenance, multiple candidates are ambiguous.
External outcomes point to a namespaced `external_module` identity that cannot
collide with a local node. Unresolved, invalid, and exhausted references remain
queryable but never point to an invented local target.

## Limits and diagnostics

Limits cover files, imports, configs, manifests, workspaces, packages, aliases,
targets per alias, config inheritance depth, config bytes, candidates per
import, path bytes, workspace patterns, package-export depth and alternatives,
wildcard expansions, resolutions, diagnostics, and total owned result bytes.
Arithmetic is checked. Config diagnostics carry stable kind, source path, and
redacted detail; document contents are never logged.

## Acceptance

The controlled monorepo fixture must prove:

- exact, extensionless, multi-dot, ESM rewrite, Svelte rune, and directory-index
  resolution with source/file precedence;
- static, type-only, import-require, dynamic, and CommonJS import kinds;
- JSONC comments/trailing commas, `baseUrl`, exact/wildcard/directory aliases,
  multiple targets, string and array inheritance, override order, and cycles;
- pnpm authority, npm workspace fallback, scoped package roots and subpaths,
  exact/wildcard/conditional/array exports, entry fallbacks, and containment;
- duplicate package ambiguity and deterministic candidate retention;
- external package names never collide with same-stem local Python or TS files;
- dangling local paths remain unresolved rather than external or invented;
- dynamic imports do not become static cycle edges;
- repeated sequential builds have identical resolutions and fingerprints;
- source, path, config, recursion, candidate, and total limits fail with typed
  outcomes; and
- Testing v2 reports no findings, pending fibers, leaks, logged errors,
  truncation, or stale evidence in Debug and ReleaseSafe.

The fixture also runs through the canonical zgraphy adapter and compares the
overlapping module facts with a pinned Graphify 0.9.17 AST-only result. Every
source-valid Graphify local module edge must remain reachable through zgraphy's
module-reference projection. Divergences are classified rather than blindly
copied: duplicate-package collapse is expanded to both candidates, an export
target escaping its package is rejected, and a dangling relative import stays
unresolved instead of becoming a phantom local path.

## Non-goals

This slice does not resolve exported symbols through barrels, default exports,
receiver types, decorators, generated Proto identities, JSX component usage,
or framework route semantics. Those consume these module identities in M2.3b2
and M2.4.
