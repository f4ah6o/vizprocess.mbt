// Smoke test: run the same manifest the browser demo uses, but resolve
// csv-file sources via fs.readFile instead of fetch. Output should match
// fixtures/expected/sales-bar.svg byte-for-byte.

import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

import { manifest_to_svg } from "../../_build/js/release/build/wasm/wasm.js";
import { prefetchManifestSources } from "./prefetch.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const fsReader = (rel) => readFile(path.resolve(here, rel), "utf8");

const manifest = {
  id: "monthly-sales",
  datasets: [
    {
      id: "monthly_sales",
      source: {
        kind: "csv-file",
        path: "../../fixtures/datasets/sales.csv",
        schema: {
          fields: [
            { name: "month", dtype: "string" },
            { name: "region", dtype: "string" },
            { name: "amount", dtype: "int" },
          ],
        },
      },
      pipeline: {
        steps: [
          {
            type: "filter",
            field: "region",
            op: "eq",
            value: { dtype: "string", v: "JP" },
          },
          {
            type: "aggregate",
            group_by: ["month"],
            measures: [{ field: "amount", op: "sum", as: "total" }],
          },
        ],
      },
    },
  ],
  charts: [
    {
      id: "sales-bar",
      dataset_id: "monthly_sales",
      spec: {
        id: "sales-bar",
        mark: "bar",
        encoding: {
          x: { field: "month" },
          y: { field: "total" },
        },
        config: { width: 480, height: 240 },
      },
    },
  ],
  artifacts: [{ id: "svg", kind: "svg", chart_id: "sales-bar" }],
};

const resolved = await prefetchManifestSources(manifest, fsReader);
const svg = manifest_to_svg(JSON.stringify(resolved));
console.log(svg);
