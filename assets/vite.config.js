import {defineConfig} from "vite"
import vue from "@vitejs/plugin-vue"
import tailwindcss from "@tailwindcss/vite"

// One JS bundle and one CSS file with fixed names, written where Phoenix
// serves static files from. `mix phx.digest` adds the cache-busting hashes.
export default defineConfig(({mode}) => ({
  plugins: [
    vue(),
    tailwindcss(),
  ],
  publicDir: false,
  build: {
    outDir: "../priv/static/assets",
    emptyOutDir: true,
    sourcemap: mode === "development",
    minify: mode !== "development",
    chunkSizeWarningLimit: 1500,
    rollupOptions: {
      input: "src/main.js",
      output: {
        entryFileNames: "js/app.js",
        assetFileNames: (asset) =>
          (asset.names?.[0] ?? asset.name ?? "").endsWith(".css") ? "css/app.css" : "[name][extname]",
        inlineDynamicImports: true,
      },
    },
  },
  test: {environment: "node", include: ["src/**/*.test.js"]},
}))
