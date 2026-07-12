# ZigEffect System-Building Story

Date: 2026-07-12

## Problem

The marketing site explains the runtime, causal evidence, Testing v2, and the
agent loop, but under-represents the features that let an agent assemble a
complete production system:

- the broad `zigeffect_std` service and boundary library;
- durable workflow primitives such as activities, signals, queues, timers,
  deferred values, compensation, journals, and recovery;
- typed statecharts, actors, hierarchy/parallelism, analysis, simulation,
  coverage, versioning, migration, and governed control.

This leaves the product sounding like an observability and testing runtime
instead of an integrated application platform.

## Product thesis

ZigEffect's differentiator is the assembly. Agents receive one coherent model
for declaring intent, generating explicit Zig, using conventional system
capabilities, running long-lived processes, observing causes, repairing
failures, and publishing deterministic proof. Individual ideas have precedents;
their agent-readable integration is the product.

## Experience changes

1. Add a dedicated `/standard-library` chapter organized around the jobs an
   agent must perform, not an undifferentiated API inventory.
2. Expand `/workflows` from a short statechart introduction into the durable
   execution story: primitives, recovery, actors, hierarchical/parallel states,
   analysis, versioning, migration, storage, and honest external guarantees.
3. Add a homepage section between the runtime explanation and product proof
   that introduces the system-building layer and links to both chapters.
4. Add the Standard Library to shared navigation, prerendering, sitemap, route
   metadata, and the connected chapter journey.

## Content constraints

- Use claims supported by public exports in `packages/zigeffect-std/src/root.zig`,
  `packages/zigeffect/src/workflow/root.zig`, and
  `packages/zigeffect/src/statechart/root.zig`.
- Say “40+ modules” rather than freezing marketing copy to an exact count.
- Explain mechanisms in plain language before naming APIs.
- Do not imply external side effects are magically exactly once. Describe
  journaled decision acceptance, idempotency keys, and adapter obligations.
- Present the standard library as a coherent typed boundary surface, not as a
  claim that every production adapter has identical maturity.

## Acceptance

- `/standard-library` is independently navigable, prerendered, indexed, and has
  unique SEO/social metadata.
- The page explains the core, data, integration, reliability, operations, and
  agent-development module families with concrete Zig examples.
- `/workflows` names durable activities, signals, queues, timers, deferred
  values, compensation, actors, hierarchical/parallel states, simulation,
  coverage, versioning, migration, and recovery.
- The homepage clearly states that agents can assemble whole systems from the
  library and durable control-flow layer.
- Existing responsive, accessibility, test, typecheck, and build contracts pass.
