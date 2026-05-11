import {
  copyFileSync,
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const rootDir = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const outDir = resolve(rootDir, "_build/cloudflare/browser-demo");
const browserDemoDir = resolve(rootDir, "examples/browser-demo");
const editorDir = resolve(browserDemoDir, "editor");
const fixturesDir = resolve(outDir, "fixtures/datasets");
const filesToCopy = [
  [
    resolve(browserDemoDir, "prefetch.mjs"),
    resolve(outDir, "prefetch.mjs"),
  ],
  [
    resolve(browserDemoDir, "duckdb-loader.mjs"),
    resolve(outDir, "duckdb-loader.mjs"),
  ],
  [
    resolve(browserDemoDir, "opfs.mjs"),
    resolve(outDir, "opfs.mjs"),
  ],
  [
    resolve(rootDir, "_build/js/release/build/wasm/wasm.js"),
    resolve(outDir, "wasm.js"),
  ],
  [
    resolve(rootDir, "fixtures/datasets/sales.csv"),
    resolve(fixturesDir, "sales.csv"),
  ],
];

const indexSource = resolve(editorDir, "index.html");

if (!existsSync(indexSource) || !existsSync(editorDir)) {
  throw new Error(`Missing required build input: ${indexSource}`);
}

for (const [src] of filesToCopy) {
  if (!existsSync(src)) {
    throw new Error(`Missing required build input: ${src}`);
  }
}

rmSync(outDir, { recursive: true, force: true });
mkdirSync(fixturesDir, { recursive: true });

for (const [src, dest] of filesToCopy) {
  mkdirSync(dirname(dest), { recursive: true });
  copyFileSync(src, dest);
}
cpSync(editorDir, resolve(outDir, "editor"), { recursive: true });

let indexHtml = readFileSync(indexSource, "utf8");
indexHtml = replaceAllExact(indexHtml, "./main.js", "./editor/main.js");
writeFileSync(resolve(outDir, "index.html"), indexHtml);

function replaceAllExact(source, search, replacement) {
  if (!source.includes(search)) {
    throw new Error(`Expected source snippet not found: ${search}`);
  }
  return source.split(search).join(replacement);
}
