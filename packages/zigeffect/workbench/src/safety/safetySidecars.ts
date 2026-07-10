export type StaticSafetyFinding = {
  id: string;
  construct: string;
  disposition: "forbidden" | "allowed" | "stale_allowance" | "unmanaged";
  allowance_id: string | null;
  source: { component: string; path: string; declaration: string; line: number; column: number; fingerprint: string; source_digest: string };
};

export type StaticSafetyReport = { schema: "zigeffect.static-safety-report.v1"; verdict: string; truncated: boolean; findings: StaticSafetyFinding[] };
export type SourceMapArtifact = { schema: "zigeffect.source-map.v1"; entries: Array<{ id: number; component: string; file: string; declaration: string; line: number; column: number }> };
export type ScheduleArtifact = { schema: "zigeffect.schedule-exploration.v1"; verdict: string; truncated: boolean; failure: null | { kind: string; schedule: number[]; source_ref_id: number | null; error_name: string } };
export type FuzzArtifact = { schema: "zigeffect.fuzz-artifact.v1"; status: "passed" | "failed" | "incomplete"; seed: number; cases: number; input_artifact: string; replay_command: string };

function object(value: unknown, label: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error(`${label} must be an object`);
  return value as Record<string, unknown>;
}
function string(value: unknown, label: string): string { if (typeof value !== "string") throw new Error(`${label} must be a string`); return value; }
function number(value: unknown, label: string): number { if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) throw new Error(`${label} must be a non-negative integer`); return value; }
function boolean(value: unknown, label: string): boolean { if (typeof value !== "boolean") throw new Error(`${label} must be boolean`); return value; }
function array(value: unknown, label: string): unknown[] { if (!Array.isArray(value)) throw new Error(`${label} must be an array`); return value; }

export function parseStaticSafetyReport(input: string | unknown): StaticSafetyReport {
  const root = object(typeof input === "string" ? JSON.parse(input) : input, "static report");
  if (root.schema !== "zigeffect.static-safety-report.v1") throw new Error("unsupported static safety schema");
  const dispositions = new Set(["forbidden", "allowed", "stale_allowance", "unmanaged"]);
  const findings = array(root.findings, "findings").map((entry, index) => {
    const finding = object(entry, `findings[${index}]`); const source = object(finding.source, "finding source");
    const disposition = string(finding.disposition, "finding disposition");
    if (!dispositions.has(disposition)) throw new Error("invalid finding disposition");
    return {
      id: string(finding.id, "finding id"), construct: string(finding.construct, "finding construct"), disposition: disposition as StaticSafetyFinding["disposition"],
      allowance_id: finding.allowance_id === null ? null : string(finding.allowance_id, "allowance id"),
      source: { component: string(source.component, "source component"), path: string(source.path, "source path"), declaration: string(source.declaration, "source declaration"), line: number(source.line, "source line"), column: number(source.column, "source column"), fingerprint: string(source.fingerprint, "source fingerprint"), source_digest: string(source.source_digest, "source digest") },
    };
  });
  return { schema: "zigeffect.static-safety-report.v1", verdict: string(root.verdict, "verdict"), truncated: boolean(root.truncated, "truncated"), findings };
}

export function parseSourceMapArtifact(input: string | unknown): SourceMapArtifact {
  const root = object(typeof input === "string" ? JSON.parse(input) : input, "source map");
  if (root.schema !== "zigeffect.source-map.v1" || root.schema_version !== 1) throw new Error("unsupported source map schema");
  const entries = array(root.entries, "entries").map((entry) => { const value = object(entry, "source entry"); return { id: number(value.id, "source id"), component: string(value.component, "component"), file: string(value.file, "file"), declaration: string(value.declaration, "declaration"), line: number(value.line, "line"), column: number(value.column, "column") }; });
  return { schema: "zigeffect.source-map.v1", entries };
}

export function parseScheduleArtifact(input: string | unknown): ScheduleArtifact {
  const root = object(typeof input === "string" ? JSON.parse(input) : input, "schedule artifact");
  if (root.schema !== "zigeffect.schedule-exploration.v1" || root.schema_version !== 1) throw new Error("unsupported schedule schema");
  let failure: ScheduleArtifact["failure"] = null;
  if (root.failure !== null) { const value = object(root.failure, "schedule failure"); failure = { kind: string(value.kind, "failure kind"), schedule: array(value.schedule, "schedule").map((item) => number(item, "action")), source_ref_id: value.source_ref_id === null ? null : number(value.source_ref_id, "source ref"), error_name: string(value.error_name, "error name") }; }
  return { schema: "zigeffect.schedule-exploration.v1", verdict: string(root.verdict, "verdict"), truncated: boolean(root.truncated, "truncated"), failure };
}

export function parseFuzzArtifact(input: string | unknown): FuzzArtifact {
  const root = object(typeof input === "string" ? JSON.parse(input) : input, "fuzz artifact");
  if (root.schema !== "zigeffect.fuzz-artifact.v1") throw new Error("unsupported fuzz schema");
  const status = string(root.status, "fuzz status") as FuzzArtifact["status"];
  if (!new Set(["passed", "failed", "incomplete"]).has(status)) throw new Error("invalid fuzz status");
  return { schema: "zigeffect.fuzz-artifact.v1", status, seed: number(root.seed, "seed"), cases: number(root.cases, "cases"), input_artifact: string(root.input_artifact, "input artifact"), replay_command: string(root.replay_command, "replay command") };
}
