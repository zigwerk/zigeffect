import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";

test("interactive terminal lazily mounts xterm with fit, input, resize, and disposal", () => {
  const source = readFileSync(new URL("./LocalAgentTerminalPanel.tsx", import.meta.url), "utf8");

  expect(source).toContain('import("@xterm/xterm")');
  expect(source).toContain('import("@xterm/addon-fit")');
  expect(source).toContain("terminal.onData");
  expect(source).toContain("ResizeObserver");
  expect(source).toContain("fit.fit()");
  expect(source).toContain("local.resize");
  expect(source).toContain("local.dispose()");
  expect(source).toContain("terminal.dispose()");
  expect(source).toContain("transport()?.gap()");
  expect(source).not.toContain("terminal.focus()");
});

test("operator exposes terminal only for retained PTY sessions", () => {
  const source = readFileSync(new URL("./LocalAgentOperatorPanel.tsx", import.meta.url), "utf8");
  const styles = readFileSync(new URL("../styles.css", import.meta.url), "utf8");

  expect(source).toContain("LocalAgentTerminalPanel");
  expect(source).toContain('item.mode === "pty"');
  expect(source).toContain("terminalAvailable");
  expect(source).toContain('["terminal", "Terminal"]');
  expect(source).toContain("operatorRoot.scrollTop");
  expect(source).toContain('window.matchMedia("(max-width: 720px)")');
  expect(styles).toContain(".operator-terminal-host");
  expect(styles).toContain(".operator-terminal-shell");
});
