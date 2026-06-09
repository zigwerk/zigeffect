# zigeffect Causal Workbench Read-Only Design

## Context

M0-M5 now produce a rich local artifact trail: causal JSON, text reports, DOT
graphs, snapshot manifests, replay reports, fork proposals, remediation
artifacts, policy decisions, registry readiness, and registry application
records. Developers and agents can inspect these artifacts from the CLI, but
they still need to jump between many files and commands.

M6 starts with a read-only local workbench. The first slice should be useful
immediately for a single causal JSON artifact while leaving room for later graph
and remediation-chain expansion.

## Product Design Brief

- Product: internal zigeffect causal artifact workbench.
- Audience: zigeffect maintainers and development agents diagnosing local
  runtime behavior.
- Visual direction: quiet operational UI, dense but readable, optimized for
  scanning event timelines and evidence. No marketing hero, decorative cards,
  or external visual dependencies.
- Interactivity: local static HTML with functional tabs, search/filter, event
  selection, copyable query commands, and safe-to-share/redaction indicators.
- Boundary: read-only. No source edits, registry edits, policy decisions,
  network calls, secret access, or runtime mutation.

## Goals

- Add a local command:

  ```sh
  zig build causal-workbench -- <artifact.json>
  ```

- Generate `.zig-cache/causal-artifacts/zigeffect-causal-workbench.html`.
- Embed the selected causal artifact JSON into the HTML so the file opens
  offline.
- Render a real first-screen application, not a landing page.
- Provide views for:
  - event timeline;
  - finding/evidence summary;
  - event detail;
  - lightweight relationship view from `parent_id`, `scope_id`, and `fiber_id`;
  - copyable `causal-query` commands;
  - artifact metadata and compatibility posture.
- Keep all actions read-only and local.
- Render degraded-but-useful output for older or partially missing metadata.

## Non-Goals

- No dev server in the first slice.
- No external JS/CSS assets.
- No graph layout library.
- No DOT rendering dependency.
- No mutation controls.
- No policy approval UI.
- No registry application UI.
- No loading directories or multiple artifacts in the first slice.
- No secrets, network calls, or external service dependencies.

## Selected Architecture

Create `packages/zigeffect/tools/causal_workbench.zig` and wire it into
`packages/zigeffect/build.zig` as `zig build causal-workbench`.

The Zig tool will:

1. accept one causal JSON artifact path;
2. read the artifact with a bounded limit;
3. parse enough metadata to validate it has an event list;
4. write a self-contained HTML document to
   `.zig-cache/causal-artifacts/zigeffect-causal-workbench.html`;
5. print the output path.

The generated HTML will include:

- embedded JSON in a `<script type="application/json">` tag;
- CSS scoped to the document;
- vanilla JavaScript for tab switching, filtering, selection, and clipboard;
- no remote resources.

This keeps the command compatible with the rest of the Zig tooling and avoids
introducing a frontend build system for the first read-only slice.

## UI Structure

The first viewport should be the workbench itself:

- top toolbar:
  - artifact path;
  - schema/version/taxonomy chips;
  - event count;
  - finding count;
  - safe-to-share posture;
- left rail:
  - tabs: Timeline, Findings, Graph, Queries, Metadata;
  - search input;
  - kind/status filters;
- main pane:
  - selected tab content;
- right inspector:
  - selected event id, kind, label, status, type;
  - run/scope/fiber/parent links;
  - redacted detail;
  - copyable causal-query commands.

The layout should be dense and stable. It should avoid nested cards and avoid
large hero-scale type. Fixed-format controls such as tabs, counters, and event
rows should have stable dimensions so filtering does not shift the layout
unnecessarily.

## View Behavior

Timeline:

- sorted event rows by `id`;
- filter by text, kind, status;
- click an event to populate the inspector;
- show compact badges for run/scope/fiber ids.

Findings:

- compute the same local finding heuristics already used by snapshot manifests
  where practical:
  - missing service requirement;
  - unfinalized resource;
  - failed finalizer;
  - retry exhaustion;
  - assertion failure;
  - pending fiber after scope close.
- link findings back to event rows.

Graph:

- render a simple relationship list/tree from `parent_id`;
- group by scope and fiber where ids exist;
- no force-directed layout in the first slice.

Queries:

- show copyable commands:
  - `snapshot`;
  - `cause <event_id>`;
  - `lineage <event_id>`;
  - `resources <scope_id>`;
  - `fibers pending`;
  - `requirements <run_id>`;
  - `retries <run_id>`.

Metadata:

- schema and taxonomy values;
- unknown/missing metadata warnings;
- redaction/truncation/safe-share indicators.

## Safety

The workbench must include visible read-only posture:

- "read-only local artifact viewer";
- "no source edits";
- "no network calls";
- "redacted details may still contain sensitive context if upstream redaction
  was bypassed".

It must never add buttons that imply mutation, approval, apply, or automatic
fixes.

## Testing

Unit tests should cover:

- workbench output path is stable;
- generated HTML contains embedded escaped artifact JSON;
- generated HTML includes the workbench title, read-only posture, tabs,
  timeline container, inspector, query commands, and no remote asset URLs;
- usage text accepts a single artifact path.

Manual/browser verification should cover:

- generate a dogfood artifact with `zig build causal-test`;
- generate the workbench HTML;
- open the file locally or via the in-app browser;
- verify the page is nonblank, tabs render, events appear, filtering works, and
  selecting an event updates the inspector.

## Future Slices

- Multi-artifact loader and artifact index.
- DOT/SVG graph rendering.
- Remediation and audit-chain visualization.
- Snapshot/replay/fork proposal comparison inside the workbench.
- Policy-gated action launchers that produce CLI artifacts instead of mutating
  directly.

## Self-Review

- Placeholder scan: no unresolved placeholders remain.
- Internal consistency: the first slice is static, local, offline, and
  read-only throughout.
- Scope check: this branch can deliver a useful single-artifact viewer without
  a frontend framework or server.
- Ambiguity check: "workbench" means generated local HTML viewer in this branch,
  not a hosted app or mutation console.
