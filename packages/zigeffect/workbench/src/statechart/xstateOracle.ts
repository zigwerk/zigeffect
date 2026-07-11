import { createActor, createMachine } from "xstate";
import type { StatechartDefinitionArtifact, StatechartExecution, StatechartStateNode } from "./statechartModel";

export type XStatePathStep = {
  event: string;
  expected: string[];
  actual: string[];
  equivalent: boolean;
};

export type XStatePathReport = {
  equivalent: boolean;
  steps: XStatePathStep[];
};

type MachineConfig = Record<string, unknown> & { states: Record<string, StateConfig> };
type StateConfig = Record<string, unknown> & {
  states?: Record<string, StateConfig>;
  on?: Record<string, TransitionConfig | TransitionConfig[]>;
  always?: TransitionConfig | TransitionConfig[];
};
type TransitionConfig = Record<string, unknown>;

export function toXStateConfig(definition: StatechartDefinitionArtifact): MachineConfig {
  const children = new Map<string | null, StatechartStateNode[]>();
  for (const state of definition.states) {
    const siblings = children.get(state.parent) ?? [];
    siblings.push(state);
    children.set(state.parent, siblings);
  }
  const byId = new Map<string, StateConfig>();

  const build = (state: StatechartStateNode): StateConfig => {
    const config: StateConfig = { id: state.id };
    if (state.kind === "final") config.type = "final";
    if (state.kind === "parallel") config.type = "parallel";
    if (state.kind === "history_shallow" || state.kind === "history_deep") {
      config.type = "history";
      config.history = state.kind === "history_deep" ? "deep" : "shallow";
    }
    if (state.kind === "compound" && state.initial) config.initial = state.initial;
    const nested = children.get(state.id) ?? [];
    if (nested.length > 0) config.states = Object.fromEntries(nested.map((child) => [child.id, build(child)]));
    byId.set(state.id, config);
    return config;
  };

  const config: MachineConfig = {
    id: definition.id,
    initial: definition.initial,
    states: Object.fromEntries((children.get(null) ?? []).map((state) => [state.id, build(state)])),
  };
  for (const transition of definition.transitions) {
    const source = byId.get(transition.source);
    if (!source) continue;
    const projected: TransitionConfig = {
      ...(transition.target ? { target: `#${transition.target}` } : {}),
      ...(transition.reenter ? { reenter: true } : {}),
      ...(transition.guard ? { guard: transition.guard } : {}),
      meta: { transitionId: transition.id },
    };
    if (transition.event === null) {
      source.always = appendTransition(source.always, projected);
    } else {
      source.on ??= {};
      source.on[transition.event] = appendTransition(source.on[transition.event], projected);
    }
  }
  return config;
}
export function comparePathWithXState(
  definition: StatechartDefinitionArtifact,
  executions: StatechartExecution[],
): XStatePathReport {
  let executionIndex = 0;
  const guardNames = new Set(definition.transitions.flatMap((transition) => transition.guard ? [transition.guard] : []));
  const guards = Object.fromEntries([...guardNames].map((guardId) => [guardId, () => {
    const result = executions[executionIndex]?.guards.find((guard) => guard.id === guardId);
    return result?.accepted ?? true;
  }]));
  const machine = createMachine(toXStateConfig(definition) as never, { guards } as never);
  const actor = createActor(machine).start();
  const steps: XStatePathStep[] = [];
  for (const execution of executions) {
    actor.send({ type: execution.event });
    const actual = activeAtomicStateIds(actor.getSnapshot().value).sort();
    const expected = [...execution.toConfiguration].sort();
    steps.push({
      event: execution.event,
      expected,
      actual,
      equivalent: arraysEqual(expected, actual),
    });
    executionIndex += 1;
  }
  actor.stop();
  return { equivalent: steps.every((step) => step.equivalent), steps };
}

function appendTransition(
  existing: TransitionConfig | TransitionConfig[] | undefined,
  transition: TransitionConfig,
): TransitionConfig | TransitionConfig[] {
  if (!existing) return transition;
  return Array.isArray(existing) ? [...existing, transition] : [existing, transition];
}

function activeAtomicStateIds(value: unknown): string[] {
  if (typeof value === "string") return [value];
  if (!value || typeof value !== "object" || Array.isArray(value)) return [];
  const result: string[] = [];
  for (const [state, nested] of Object.entries(value)) {
    const children = activeAtomicStateIds(nested);
    if (children.length === 0) result.push(state);
    else result.push(...children);
  }
  return result;
}

function arraysEqual(left: string[], right: string[]): boolean {
  return left.length === right.length && left.every((value, index) => value === right[index]);
}
