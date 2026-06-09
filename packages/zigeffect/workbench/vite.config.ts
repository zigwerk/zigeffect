import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import solid from "vite-plugin-solid";

const root = fileURLToPath(new URL(".", import.meta.url));

export default defineConfig({
  root,
  base: "./",
  plugins: [solid()],
  build: {
    outDir: "dist",
    emptyOutDir: true,
    target: "es2022",
  },
});
