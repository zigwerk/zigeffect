import TerminalSquare from "lucide-solid/icons/square-terminal";
import { Show, createSignal, onCleanup, onMount } from "solid-js";
import type { LocalAgentControlClient } from "../localAgentControlClient";
import { createLocalAgentTerminal, type LocalAgentTerminal } from "./localAgentTerminal";
import "@xterm/xterm/css/xterm.css";

export function LocalAgentTerminalPanel(props: {
  client: LocalAgentControlClient;
  sessionId: string;
}) {
  let host!: HTMLDivElement;
  const [transport, setTransport] = createSignal<LocalAgentTerminal | null>(null);
  const [loadError, setLoadError] = createSignal<string | null>(null);
  let disposeRuntime = () => {};

  onMount(() => {
    let disposed = false;
    void Promise.all([
      import("@xterm/xterm"),
      import("@xterm/addon-fit"),
    ]).then(([{ Terminal }, { FitAddon }]) => {
      if (disposed) return;
      const terminal = new Terminal({
        allowProposedApi: false,
        convertEol: false,
        cursorBlink: true,
        cursorStyle: "bar",
        fontFamily: '"SFMono-Regular", Consolas, "Liberation Mono", monospace',
        fontSize: 12,
        letterSpacing: 0,
        lineHeight: 1.25,
        scrollback: 10_000,
        theme: {
          background: "#101315",
          foreground: "#e6e9e8",
          cursor: "#6fd6bc",
          selectionBackground: "#315f58",
          black: "#101315",
          red: "#f07a73",
          green: "#72c995",
          yellow: "#e0bd66",
          blue: "#74a9dd",
          magenta: "#c897d8",
          cyan: "#69c5ca",
          white: "#e6e9e8",
          brightBlack: "#687371",
          brightRed: "#ff9b95",
          brightGreen: "#92dfae",
          brightYellow: "#efd58b",
          brightBlue: "#9ac3ec",
          brightMagenta: "#deb1ea",
          brightCyan: "#91dce0",
          brightWhite: "#ffffff",
        },
      });
      const fit = new FitAddon();
      terminal.loadAddon(fit);
      terminal.open(host);
      const local = createLocalAgentTerminal(props.client, props.sessionId, {
        onData(data) { terminal.write(data); },
      });
      setTransport(() => local);
      const input = terminal.onData((data) => { void local.write(data); });
      const resize = () => {
        if (disposed || host.clientWidth === 0 || host.clientHeight === 0) return;
        fit.fit();
        local.resize(terminal.cols, terminal.rows);
      };
      const observer = new ResizeObserver(resize);
      observer.observe(host);
      const frame = requestAnimationFrame(() => {
        resize();
      });
      void local.start();
      disposeRuntime = () => {
        cancelAnimationFrame(frame);
        observer.disconnect();
        input.dispose();
        local.dispose();
        terminal.dispose();
      };
    }).catch(() => {
      if (!disposed) setLoadError("Terminal renderer failed to load");
    });
    onCleanup(() => {
      disposed = true;
      disposeRuntime();
    });
  });

  return (
    <div class="operator-terminal-shell">
      <div class="operator-terminal-head">
        <TerminalSquare size={15} />
        <strong>Interactive terminal</strong>
        <span>{transport()?.status() ?? "loading"}</span>
        <Show when={transport()}>
          {(value) => <small>{value().cols()} x {value().rows()}</small>}
        </Show>
      </div>
      <Show when={transport()?.gap()}>
        <div class="operator-terminal-warning" role="status">
          Earlier output expired from local memory ({transport()?.droppedFrames()} frames, {transport()?.droppedBytes()} bytes)
        </div>
      </Show>
      <Show when={loadError() ?? transport()?.error()?.message}>
        {(message) => <div class="operator-terminal-warning fail" role="alert">{message()}</div>}
      </Show>
      <div ref={host} class="operator-terminal-host" aria-label={`Interactive terminal for ${props.sessionId}`} />
    </div>
  );
}
