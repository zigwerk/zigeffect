import { fileURLToPath } from "node:url";
import type { Plugin } from "vite";
import { defineConfig } from "vite";
import solid from "vite-plugin-solid";

const root = fileURLToPath(new URL(".", import.meta.url));

function webuiDevShim(): Plugin {
  return {
    name: "zigeffect-webui-dev-shim",
    configureServer(server) {
      server.middlewares.use((request, response, next) => {
        const path = request.url?.split("?")[0];
        if (path !== "/webui.js") {
          next();
          return;
        }

        response.statusCode = 200;
        response.setHeader("Content-Type", "application/javascript");
        response.end("window.__zigeffectWebuiDevShim = true;");
      });
    },
  };
}

export default defineConfig({
  root,
  base: "./",
  plugins: [webuiDevShim(), solid()],
  build: {
    outDir: "dist",
    emptyOutDir: true,
    target: "es2022",
  },
});
