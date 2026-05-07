// Smoke test: load the js-target wasm bridge from Node and render the
// canonical sales-bar SVG. Should output the same bytes as
// fixtures/expected/sales-bar.svg.

import { manifest_to_svg } from "../../_build/js/release/build/wasm/wasm.js";

const manifest = {
  id: "monthly-sales",
  datasets: [
    {
      id: "monthly_sales",
      source: {
        kind: "csv-inline",
        data:
          "month,region,amount\n" +
          "2026-01,JP,100\n" +
          "2026-01,US,50\n" +
          "2026-02,JP,200\n" +
          "2026-02,US,150\n" +
          "2026-01,JP,75\n",
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

const svg = manifest_to_svg(JSON.stringify(manifest));
console.log(svg);
