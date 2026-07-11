import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { deriveProjectDevelopmentModel } from "./projectDevelopment";

test("project development panel renders requirements sessions artifacts and application facts", () => {
  const raw = JSON.parse(readFileSync(
    new URL("../../public/sample-project-development.json", import.meta.url),
    "utf8",
  )) as unknown;
  const model = deriveProjectDevelopmentModel(raw);
  const source = readFileSync(new URL("./ProjectDevelopmentPanel.tsx", import.meta.url), "utf8");

  expect(model.project).toBe("invoice-system");
  expect(model.requirements.some((item) => item.summary === "Serve Schema-validated invoices")).toBe(true);
  expect(model.sessions.some((item) => item.id === "codex-session-12")).toBe(true);
  expect(model.artifacts.some((item) => item.path === ".zigeffect/receipts/check.json")).toBe(true);
  expect(source).toContain("Session comparison");
  expect(source).toContain("Application facts");
  expect(source).toContain("Capability gaps");
  expect(source).toContain("onSelectEvent(fact.eventId)");
});
