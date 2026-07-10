export const SAFETY_RECEIPT_SCHEMA = "zigeffect.safety-receipt.v1" as const;

export type SafetyVerdict = "passed" | "failed" | "incomplete" | "unmanaged";
export type SafetyGateStatus = "passed" | "failed" | "unsupported" | "not_run" | "truncated";

export type SafetyGate = {
  kind: string;
  required: boolean;
  status: SafetyGateStatus;
  command_id: string;
  detail: string;
  artifact_id: string;
  replay_command: string;
};

export type SafetyDiagnostic = {
  severity: "error" | "warning" | "note" | "info";
  file: string;
  line: number;
  column: number;
  message: string;
};

export type SafetyReceipt = {
  schema: typeof SAFETY_RECEIPT_SCHEMA;
  schema_version: 1;
  verdict: SafetyVerdict;
  project: string;
  component: string;
  source_revision: string;
  profile: string;
  toolchain: { zig_version: string; target: string; optimize: string };
  static: { files: number; source_bytes: number; forbidden: number; allowed: number; stale: number; introduced: number; resolved: number };
  memory: { allocations: number; frees: number; live_allocations: number; live_bytes: number; peak_bytes: number; invalid_frees: number; out_of_memory: number };
  completeness: Record<string, number>;
  gates: SafetyGate[];
  diagnostics: SafetyDiagnostic[];
  finding_ids: string[];
  causal_artifact_ids: string[];
};

function object(value: unknown, label: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error(`${label} must be an object`);
  return value as Record<string, unknown>;
}

function string(value: unknown, label: string): string {
  if (typeof value !== "string") throw new Error(`${label} must be a string`);
  return value;
}

function number(value: unknown, label: string): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) throw new Error(`${label} must be a non-negative integer`);
  return value;
}

function stringArray(value: unknown, label: string): string[] {
  if (!Array.isArray(value)) throw new Error(`${label} must be an array`);
  return value.map((entry, index) => string(entry, `${label}[${index}]`));
}

const verdicts = new Set<SafetyVerdict>(["passed", "failed", "incomplete", "unmanaged"]);
const gateStatuses = new Set<SafetyGateStatus>(["passed", "failed", "unsupported", "not_run", "truncated"]);
const diagnosticSeverities = new Set<SafetyDiagnostic["severity"]>(["error", "warning", "note", "info"]);

export function parseSafetyReceipt(input: string | unknown): SafetyReceipt {
  const root = object(typeof input === "string" ? JSON.parse(input) : input, "safety receipt");
  if (root.schema !== SAFETY_RECEIPT_SCHEMA || root.schema_version !== 1) throw new Error("unsupported safety receipt schema");
  const verdict = string(root.verdict, "verdict") as SafetyVerdict;
  if (!verdicts.has(verdict)) throw new Error("invalid safety verdict");
  const toolchain = object(root.toolchain, "toolchain");
  const staticEvidence = object(root.static, "static");
  const memory = object(root.memory, "memory");
  const completeness = object(root.completeness, "completeness");

  const gates = (Array.isArray(root.gates) ? root.gates : (() => { throw new Error("gates must be an array"); })()).map((entry, index) => {
    const gate = object(entry, `gates[${index}]`);
    const status = string(gate.status, `gates[${index}].status`) as SafetyGateStatus;
    if (!gateStatuses.has(status)) throw new Error(`invalid gate status at ${index}`);
    if (typeof gate.required !== "boolean") throw new Error(`gates[${index}].required must be boolean`);
    return {
      kind: string(gate.kind, `gates[${index}].kind`), required: gate.required, status,
      command_id: string(gate.command_id, `gates[${index}].command_id`), detail: string(gate.detail, `gates[${index}].detail`),
      artifact_id: string(gate.artifact_id, `gates[${index}].artifact_id`), replay_command: string(gate.replay_command, `gates[${index}].replay_command`),
    };
  });

  const diagnostics = (Array.isArray(root.diagnostics) ? root.diagnostics : (() => { throw new Error("diagnostics must be an array"); })()).map((entry, index) => {
    const diagnostic = object(entry, `diagnostics[${index}]`);
    const severity = string(diagnostic.severity, `diagnostics[${index}].severity`) as SafetyDiagnostic["severity"];
    if (!diagnosticSeverities.has(severity)) throw new Error(`invalid diagnostic severity at ${index}`);
    return { severity, file: string(diagnostic.file, "diagnostic file"), line: number(diagnostic.line, "diagnostic line"), column: number(diagnostic.column, "diagnostic column"), message: string(diagnostic.message, "diagnostic message") };
  });

  const numericRecord = (value: Record<string, unknown>, fields: string[], label: string) =>
    Object.fromEntries(fields.map((field) => [field, number(value[field], `${label}.${field}`)]));
  const completenessValues: Record<string, number> = {};
  for (const [key, value] of Object.entries(completeness)) completenessValues[key] = number(value, `completeness.${key}`);

  return {
    schema: SAFETY_RECEIPT_SCHEMA, schema_version: 1, verdict,
    project: string(root.project, "project"), component: string(root.component, "component"), source_revision: string(root.source_revision, "source_revision"), profile: string(root.profile, "profile"),
    toolchain: { zig_version: string(toolchain.zig_version, "toolchain.zig_version"), target: string(toolchain.target, "toolchain.target"), optimize: string(toolchain.optimize, "toolchain.optimize") },
    static: numericRecord(staticEvidence, ["files", "source_bytes", "forbidden", "allowed", "stale", "introduced", "resolved"], "static") as SafetyReceipt["static"],
    memory: numericRecord(memory, ["allocations", "frees", "live_allocations", "live_bytes", "peak_bytes", "invalid_frees", "out_of_memory"], "memory") as SafetyReceipt["memory"],
    completeness: completenessValues, gates, diagnostics,
    finding_ids: stringArray(root.finding_ids, "finding_ids"), causal_artifact_ids: stringArray(root.causal_artifact_ids, "causal_artifact_ids"),
  };
}

export function receiptIsComplete(receipt: SafetyReceipt): boolean {
  return Object.values(receipt.completeness).every((count) => count === 0) &&
    receipt.gates.filter((gate) => gate.required).every((gate) => gate.status === "passed");
}

export async function loadSafetyReceipt(): Promise<SafetyReceipt> {
  const params = new URLSearchParams(typeof window === "undefined" ? "" : window.location.search);
  const path = params.get("safety") ?? "sample-safety-receipt.json";
  const response = await fetch(path);
  if (!response.ok) throw new Error(`failed to load safety receipt (${response.status})`);
  return parseSafetyReceipt(await response.text());
}
