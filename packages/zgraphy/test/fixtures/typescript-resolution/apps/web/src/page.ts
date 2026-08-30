import { local } from "./local";
import { esm } from "./esm.js";
import { feature } from "./feature";
import { directory } from "./directory";
import { multi } from "./multi.shared";
import { state } from "./state.svelte";
import { exact } from "@exact";
import { shared } from "@shared/shared";
import { fallback } from "@fallback/extra";
import { legacyAlias } from "@legacy/client";
import { child } from "@child/client";
import { parent } from "@array-parent/client";
import { cycle } from "@cycle/client";
import { web } from "@web/local";
import { exact as overridden } from "@override";
import { client as baseUrlClient } from "packages/shared/src/client";
import type { SharedType } from "@acme/shared";
import { client } from "@acme/shared/client";
import { extra } from "@acme/shared/extra";
import { packageFallback } from "@acme/fallback";
import { duplicate } from "@acme/duplicate";
import { escaped } from "@acme/evil";
import colors from "tailwindcss/colors";
import { npmOnly } from "@acme/npm-only";
import { missing } from "./missing";
import legacy = require("./legacy");

export async function loadDeferred(path: string) {
  const lazy = await import("./lazy");
  const computed = await import(path);
  return {
    local, esm, feature, directory, multi, state, exact, shared, fallback,
    legacyAlias, child, parent, cycle, web, overridden, baseUrlClient, client, extra, packageFallback,
    duplicate, escaped, colors, npmOnly, missing, legacy, lazy, computed,
  } satisfies Record<string, unknown>;
}

export type PageContract = SharedType;
