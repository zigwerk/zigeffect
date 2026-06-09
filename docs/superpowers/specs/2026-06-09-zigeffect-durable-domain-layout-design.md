# zigeffect Durable Domain Layout Design

Date: 2026-06-09

## Purpose

Milestone 1 creates explicit `workflow` and `cluster` domains in `zigeffect`
without adding workflow or cluster behavior yet. The goal is to reserve the
right module boundaries before journal, actor, shard, and runner types begin to
land.

## Design

Add:

- `packages/zigeffect/src/workflow/root.zig`
- `packages/zigeffect/src/cluster/root.zig`

Expose them through the public facade:

- `fx.workflow`
- `fx.cluster`

Each root module starts with a small stable `domain` string so architecture
tests can verify the namespace is wired without inventing real APIs too early.

## Ownership

`src/workflow/` owns local durable workflow concerns:

- workflow and activity definitions;
- journal events and replay state;
- journal stores;
- durable timers, deferreds, queues, signals, and lifecycle controls;
- workflow inspectors and replay tools.

`src/cluster/` owns Erlang-style distributed runtime concerns:

- entity identity and actor references;
- message envelopes and durable message storage;
- shard ids, runner ids, runner storage, leases, and rebalancing;
- multi-runner transport;
- cluster workflow integration;
- supervision across entities, shards, runners, and transports.

## Non-Goals

- No workflow journal events.
- No workflow engine.
- No actor runtime.
- No cluster transport.
- No root aliases beyond `fx.workflow` and `fx.cluster`.

## Acceptance

- Architecture tests prove `fx.workflow` and `fx.cluster` are exposed.
- Architecture docs define the two domains and import direction.
- Existing deterministic runtime behavior remains unchanged.
- `bun run zigeffect:test`, `cd packages/zigeffect && zig build examples`,
  and `bun run zig:test` pass.
