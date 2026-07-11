import { createSignal } from "solid-js";

// App-global theme + lens state. These are intentionally module-scope singletons:
// the workbench has exactly one theme and one lens at a time, shared by the topbar,
// the trace SVG, and the G6 canvas (which re-reads CSS variables when `theme()`
// changes). All `window`/`document` access is guarded so the module stays import-safe
// under the bun test runner (which loads App.tsx top-level with no DOM).

export type ThemeMode = "dark" | "light";
export type Lens = "execution" | "collaboration";

const THEME_KEY = "zigeffect.theme";
const LENS_KEY = "zigeffect.lens";

function hasWindow(): boolean {
  return typeof window !== "undefined";
}

function searchParam(name: string): string | null {
  if (!hasWindow()) {
    return null;
  }
  return new URLSearchParams(window.location.search).get(name);
}

function storageGet(key: string): string | null {
  if (!hasWindow()) {
    return null;
  }
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function storageSet(key: string, value: string): void {
  if (!hasWindow()) {
    return;
  }
  try {
    window.localStorage.setItem(key, value);
  } catch {
    // private mode / disabled storage — non-fatal, state still lives in the signal.
  }
}

export function initialTheme(): ThemeMode {
  const fromQuery = searchParam("theme");
  if (fromQuery === "dark" || fromQuery === "light") {
    return fromQuery;
  }
  const stored = storageGet(THEME_KEY);
  return stored === "light" ? "light" : "dark";
}

export function initialLens(): Lens {
  const fromQuery = searchParam("lens");
  if (fromQuery === "execution" || fromQuery === "collaboration") {
    return fromQuery;
  }
  const stored = storageGet(LENS_KEY);
  return stored === "collaboration" ? "collaboration" : "execution";
}

const [theme, setThemeSignal] = createSignal<ThemeMode>(initialTheme());
const [lens, setLensSignal] = createSignal<Lens>(initialLens());

export { theme, lens };

/** Apply the active theme to <html data-theme> so the token overrides take effect. */
export function applyThemeToDocument(mode: ThemeMode): void {
  if (!hasWindow() || typeof document === "undefined") {
    return;
  }
  document.documentElement.dataset.theme = mode;
}

export function setTheme(mode: ThemeMode): void {
  setThemeSignal(mode);
  storageSet(THEME_KEY, mode);
  applyThemeToDocument(mode);
}

export function toggleTheme(): void {
  setTheme(theme() === "dark" ? "light" : "dark");
}

export function setLens(next: Lens): void {
  setLensSignal(next);
  storageSet(LENS_KEY, next);
}

export function toggleLens(): void {
  setLens(lens() === "execution" ? "collaboration" : "execution");
}
