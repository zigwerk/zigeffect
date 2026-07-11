export const TEST_RECEIPT_SCHEMA = "zigeffect.test-receipt.v1" as const;
export const TEST_RUN_SCHEMA = "zigeffect.test-run.v1" as const;

export type TestStatus = "passed" | "failed" | "incomplete" | "unsupported" | "skipped" | "canceled";
export type AssertionStatus = "passed" | "failed" | "skipped";
export type EvidenceKind = "model" | "schedule" | "differential" | "virtual_world" | "mutation" | "performance" | "sandbox";

export type CoverageTarget = { id: string; label: string; dimension: string; required: boolean; repair_hint: string; next_command: string };
export type CoverageHit = { target_id: string; evidence_id: string };
export type Evidence = { kind: EvidenceKind; summary: { attempted: boolean; status: TestStatus; planned: number; executed: number; passed: number; failed: number; unsupported: number; truncated: boolean; artifact: string; replay_token: string } };

export type TestAssertion = {
  id: string;
  label: string;
  status: AssertionStatus;
  source: { id: string; path: string; line: number; column: number };
  causal_event_ids: number[];
  expected: string;
  actual: string;
  detail: string;
  repair_hint: string;
};

export type TestReceipt = {
  schema: typeof TEST_RECEIPT_SCHEMA;
  schema_version: 1;
  status: TestStatus;
  project: string;
  suite: string;
  scenario: {
    id: string; label: string; requirement: string; acceptance_check: string;
    component: string; command: string; source_roots: string[]; tags: string[];
    default_seed: number; fault_profile: string; required: boolean;
  };
  source_revision: string;
  zig_version: string;
  seed: number;
  executor: string;
  execution: { tool_version: string; target: string; optimize: string; command_digest: string; worktree_dirty: boolean; native_receipt: boolean };
  coverage_targets: CoverageTarget[];
  coverage_hits: CoverageHit[];
  coverage: { targets: number; hits: number; required_gaps: number; advisory_gaps: number; truncated: boolean };
  evidence: Evidence[];
  fault_kind: string;
  fault_index: number | null;
  schedule_choices: number[];
  assertions: TestAssertion[];
  minimal_case: null | { kind: string; input: string; seed: number; case_index: number; shrink_steps: number; shrink_path: string; schedule_choices: number[]; artifact: string };
  memory: Record<string, number>;
  causal: Record<string, number>;
  completeness: Record<string, number>;
  replay_command: string;
  limitations: string[];
  detail: string;
};

export type TestRunReceipt = {
  schema: typeof TEST_RUN_SCHEMA;
  schema_version: 1;
  status: TestStatus;
  project: string;
  source_revision: string;
  selection: string;
  selection_value: string;
  discovered: number;
  selected: number;
  passed: number;
  failed: number;
  incomplete: number;
  unsupported: number;
  skipped: number;
  canceled: number;
  introduced_failures: number;
  resolved_failures: number;
  completeness: Record<string, number>;
  receipts: TestReceipt[];
  limitations: string[];
};

function object(value: unknown, label: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error(`${label} must be an object`);
  return value as Record<string, unknown>;
}
function string(value: unknown, label: string): string {
  if (typeof value !== "string") throw new Error(`${label} must be a string`);
  return value;
}
function boolean(value: unknown, label: string): boolean {
  if (typeof value !== "boolean") throw new Error(`${label} must be boolean`);
  return value;
}
function number(value: unknown, label: string): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) throw new Error(`${label} must be a non-negative safe integer`);
  return value;
}
function array(value: unknown, label: string): unknown[] {
  if (!Array.isArray(value)) throw new Error(`${label} must be an array`);
  return value;
}
function strings(value: unknown, label: string): string[] { return array(value, label).map((item, index) => string(item, `${label}[${index}]`)); }
function numbers(value: unknown, label: string): number[] { return array(value, label).map((item, index) => number(item, `${label}[${index}]`)); }
function numericRecord(value: unknown, label: string): Record<string, number> {
  const input = object(value, label);
  return Object.fromEntries(Object.entries(input).map(([key, item]) => [key, number(item, `${label}.${key}`)]));
}
function optionalObject(value: unknown, label: string): Record<string, unknown> { return value === undefined ? {} : object(value, label); }

const statuses = new Set<TestStatus>(["passed", "failed", "incomplete", "unsupported", "skipped", "canceled"]);
const assertionStatuses = new Set<AssertionStatus>(["passed", "failed", "skipped"]);

function parseStatus(value: unknown, label: string): TestStatus {
  const status = string(value, label) as TestStatus;
  if (!statuses.has(status)) throw new Error(`${label} is invalid`);
  return status;
}

export function parseTestReceipt(input: unknown, label = "test receipt"): TestReceipt {
  const root = object(input, label);
  if (root.schema !== TEST_RECEIPT_SCHEMA || root.schema_version !== 1) throw new Error("unsupported test receipt schema");
  const scenario = object(root.scenario, `${label}.scenario`);
  const assertions = array(root.assertions, `${label}.assertions`).map((item, index) => {
    const assertion = object(item, `${label}.assertions[${index}]`);
    const source = object(assertion.source, `${label}.assertions[${index}].source`);
    const status = string(assertion.status, "assertion status") as AssertionStatus;
    if (!assertionStatuses.has(status)) throw new Error(`invalid assertion status at ${index}`);
    return {
      id: string(assertion.id, "assertion id"), label: string(assertion.label, "assertion label"), status,
      source: { id: string(source.id, "source id"), path: string(source.path, "source path"), line: number(source.line, "source line"), column: number(source.column, "source column") },
      causal_event_ids: numbers(assertion.causal_event_ids, "causal event ids"), expected: string(assertion.expected, "expected"), actual: string(assertion.actual, "actual"),
      detail: string(assertion.detail, "detail"), repair_hint: string(assertion.repair_hint, "repair hint"),
    };
  });
  const minimalRaw = root.minimal_case;
  const minimal = minimalRaw === null ? null : (() => {
    const item = object(minimalRaw, "minimal case");
    return { kind: string(item.kind, "minimal kind"), input: string(item.input, "minimal input"), seed: number(item.seed, "minimal seed"), case_index: number(item.case_index, "case index"), shrink_steps: number(item.shrink_steps, "shrink steps"), shrink_path: item.shrink_path === undefined ? "" : string(item.shrink_path, "shrink path"), schedule_choices: numbers(item.schedule_choices, "schedule choices"), artifact: string(item.artifact, "minimal artifact") };
  })();
  const execution = optionalObject(root.execution, `${label}.execution`);
  const coverageTargets = (root.coverage_targets === undefined ? [] : array(root.coverage_targets, "coverage targets")).map((raw, index) => {
    const item = object(raw, `coverage targets[${index}]`);
    return { id: string(item.id, "coverage id"), label: string(item.label, "coverage label"), dimension: string(item.dimension, "coverage dimension"), required: boolean(item.required, "coverage required"), repair_hint: string(item.repair_hint, "coverage repair hint"), next_command: string(item.next_command, "coverage next command") };
  });
  const coverageHits = (root.coverage_hits === undefined ? [] : array(root.coverage_hits, "coverage hits")).map((raw, index) => {
    const item = object(raw, `coverage hits[${index}]`);
    return { target_id: string(item.target_id, "coverage target id"), evidence_id: string(item.evidence_id, "coverage evidence id") };
  });
  const coverageRaw = optionalObject(root.coverage, `${label}.coverage`);
  const evidence = (root.evidence === undefined ? [] : array(root.evidence, "evidence")).map((raw, index) => {
    const item = object(raw, `evidence[${index}]`);
    const summary = object(item.summary, `evidence[${index}].summary`);
    return { kind: string(item.kind, "evidence kind") as EvidenceKind, summary: { attempted: boolean(summary.attempted, "evidence attempted"), status: parseStatus(summary.status, "evidence status"), planned: number(summary.planned, "evidence planned"), executed: number(summary.executed, "evidence executed"), passed: number(summary.passed, "evidence passed"), failed: number(summary.failed, "evidence failed"), unsupported: number(summary.unsupported, "evidence unsupported"), truncated: boolean(summary.truncated, "evidence truncated"), artifact: string(summary.artifact, "evidence artifact"), replay_token: string(summary.replay_token, "evidence replay") } };
  });
  return {
    schema: TEST_RECEIPT_SCHEMA, schema_version: 1, status: parseStatus(root.status, "status"),
    project: string(root.project, "project"), suite: string(root.suite, "suite"),
    scenario: {
      id: string(scenario.id, "scenario id"), label: string(scenario.label, "scenario label"), requirement: string(scenario.requirement, "scenario requirement"), acceptance_check: string(scenario.acceptance_check, "acceptance check"), component: string(scenario.component, "component"), command: string(scenario.command, "command"), source_roots: strings(scenario.source_roots, "source roots"), tags: strings(scenario.tags, "tags"), default_seed: number(scenario.default_seed, "default seed"), fault_profile: string(scenario.fault_profile, "fault profile"), required: boolean(scenario.required, "scenario required"),
    },
    source_revision: string(root.source_revision, "source revision"), zig_version: string(root.zig_version, "zig version"), seed: number(root.seed, "seed"), executor: string(root.executor, "executor"),
    execution: { tool_version: execution.tool_version === undefined ? "" : string(execution.tool_version, "tool version"), target: execution.target === undefined ? "" : string(execution.target, "execution target"), optimize: execution.optimize === undefined ? "" : string(execution.optimize, "execution optimize"), command_digest: execution.command_digest === undefined ? "" : string(execution.command_digest, "command digest"), worktree_dirty: execution.worktree_dirty === undefined ? false : boolean(execution.worktree_dirty, "worktree dirty"), native_receipt: execution.native_receipt === undefined ? false : boolean(execution.native_receipt, "native receipt") },
    coverage_targets: coverageTargets, coverage_hits: coverageHits,
    coverage: { targets: coverageRaw.targets === undefined ? coverageTargets.length : number(coverageRaw.targets, "coverage targets count"), hits: coverageRaw.hits === undefined ? coverageHits.length : number(coverageRaw.hits, "coverage hits count"), required_gaps: coverageRaw.required_gaps === undefined ? 0 : number(coverageRaw.required_gaps, "required gaps"), advisory_gaps: coverageRaw.advisory_gaps === undefined ? 0 : number(coverageRaw.advisory_gaps, "advisory gaps"), truncated: coverageRaw.truncated === undefined ? false : boolean(coverageRaw.truncated, "coverage truncated") }, evidence,
    fault_kind: string(root.fault_kind, "fault kind"), fault_index: root.fault_index === null ? null : number(root.fault_index, "fault index"), schedule_choices: numbers(root.schedule_choices, "schedule choices"), assertions, minimal_case: minimal, memory: numericRecord(root.memory, "memory"), causal: numericRecord(root.causal, "causal"), completeness: numericRecord(root.completeness, "completeness"), replay_command: string(root.replay_command, "replay command"), limitations: strings(root.limitations, "limitations"), detail: string(root.detail, "detail"),
  };
}

export function parseTestRunReceipt(input: string | unknown): TestRunReceipt {
  const root = object(typeof input === "string" ? JSON.parse(input) : input, "test run");
  if (root.schema !== TEST_RUN_SCHEMA || root.schema_version !== 1) throw new Error("unsupported test run schema");
  const receipt = {
    schema: TEST_RUN_SCHEMA, schema_version: 1 as const, status: parseStatus(root.status, "status"), project: string(root.project, "project"), source_revision: string(root.source_revision, "source revision"), selection: string(root.selection, "selection"), selection_value: string(root.selection_value, "selection value"), discovered: number(root.discovered, "discovered"), selected: number(root.selected, "selected"), passed: number(root.passed, "passed"), failed: number(root.failed, "failed"), incomplete: number(root.incomplete, "incomplete"), unsupported: number(root.unsupported, "unsupported"), skipped: number(root.skipped, "skipped"), canceled: number(root.canceled, "canceled"), introduced_failures: number(root.introduced_failures, "introduced failures"), resolved_failures: number(root.resolved_failures, "resolved failures"), completeness: numericRecord(root.completeness, "completeness"), receipts: array(root.receipts, "receipts").map((item, index) => parseTestReceipt(item, `receipts[${index}]`)), limitations: strings(root.limitations, "limitations"),
  };
  const total = receipt.passed + receipt.failed + receipt.incomplete + receipt.unsupported + receipt.skipped + receipt.canceled;
  if (total !== receipt.selected || receipt.receipts.length !== receipt.selected) throw new Error("test run counts do not match selected receipts");
  if (new Set(receipt.receipts.map((item) => item.scenario.id)).size !== receipt.receipts.length) throw new Error("duplicate scenario receipt");
  return receipt;
}

export function testRunIsComplete(run: TestRunReceipt): boolean {
  return Object.values(run.completeness).every((value) => value === 0) && run.receipts.every((receipt) => Object.values(receipt.completeness).every((value) => value === 0));
}

export async function loadTestRunReceipt(): Promise<TestRunReceipt> {
  const params = new URLSearchParams(typeof window === "undefined" ? "" : window.location.search);
  const path = params.get("tests") ?? "sample-test-run.json";
  const response = await fetch(path);
  if (!response.ok) throw new Error(`failed to load test receipt (${response.status})`);
  return parseTestRunReceipt(await response.text());
}
