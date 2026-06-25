# zigeffect Local Agentic Development Cockpit Plan

Date: 2026-06-25

## Objective

Schedule and implement the local-first agentic development cockpit milestones in
order, starting with the smallest slice that makes zigeffect dogfood sessions
visible to the SolidJS workbench.

## Sequence

1. M72 - Local development session protocol.
2. M73 - Workbench agent cockpit view.
3. M74 - Dogfood session receipt enrichment.
4. M75 - Live agent runtime feed.
5. M76 - Local Codex and Claude Code adapters.
6. M77 - Local reliability gate.

## M72 implementation steps

1. Add failing workbench tests for parsing `zigeffect.causal.dev-session.v1`.
2. Add `LocalDevSessionModel` types in `causalArtifact.ts`.
3. Implement `deriveLocalDevSessionModel(raw, options)`.
4. Normalize required fields, optional agent/check/artifact rows, next actions,
   guardrails, and warnings.
5. Derive fallback agents and checks from command records when older receipts do
   not include them.
6. Verify with focused Bun tests.

## M73 implementation steps

1. Add a failing `App.test.tsx` assertion for the new Agents tab.
2. Add `agents` to the workbench tab model.
3. Wire `deriveLocalDevSessionModel` into `App`.
4. Add `AgentDevelopmentView` with compact operational panels for status,
   agents, checks, artifacts, commands, guardrails, and next actions.
5. Add responsive CSS using existing workbench panel conventions.
6. Verify typecheck and workbench tests.

## M74 implementation steps

1. Add failing Zig tests for agent-aware JSON fields in
   `tools/causal_dev_session.zig`.
2. Extend the receipt output with local session metadata, agent records, and
   check records while keeping the existing `SessionRecord` fields stable.
3. Populate deterministic defaults for `start`, `assess`, missing-baseline, and
   failure paths.
4. Emit the enriched JSON without changing the existing command/artifact fields.
5. Update text receipt output with short local-agent status lines.
6. Wire the dev-session tool tests into `zig build test` and verify the enriched
   receipt contract there.

## M75 implementation steps

1. Add tests for local session frames in `liveAttach.ts`.
2. Define the minimal frame shape needed to update a session model.
3. Reuse collector redaction for all live session labels/details.
4. Let live artifacts accumulate session facts alongside causal events.
5. Add a repeatable local proof command or doc.

## M76 implementation steps

1. Document the local adapter contract under `packages/zigeffect/docs`.
2. Add a tiny JSONL fixture for Codex and Claude Code local activity.
3. Add parser tests for adapter activity.
4. Keep adapter ingestion local-file or stdin based.
5. Avoid background daemons until M75 is stable.

## M77 implementation steps

1. Extend the existing hygiene gate only for checks that guard real local
   session failures.
2. Add regression fixtures for stale session claims and missing local artifacts.
3. Add a single local verification command that runs workbench parse tests,
   dev-session tests, redaction tests, and hygiene checks.
4. Document the handoff ritual for another agent.

## Verification

Run, at minimum:

```sh
bun test --timeout 30000 packages/zigeffect/workbench/src/causalArtifact.test.ts packages/zigeffect/workbench/src/App.test.tsx
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:test
cd packages/zigeffect && zig build test-raw
```
