// Exercise the duckdb prefetch path without booting DuckDB-Wasm.
//
// Strategy: pass a mock duckdbRunner that pretends to have run the SQL
// and returns the same aggregated CSV the real engine would. The test
// then compares manifest_to_svg's output against the M3 SVG fixture.
// This proves prefetchManifestSources stitches the duckdbRunner result
// into csv-inline correctly, which is the part the browser path can't
// be tested for from here.

import { manifest_to_svg } from "../../_build/js/release/build/wasm/wasm.js";
import { prefetchManifestSources } from "./prefetch.mjs";

const expectedSvg =
  '<svg xmlns="http://www.w3.org/2000/svg" width="480" height="240">' +
  '<g><rect x="42" y="45" width="206" height="175"/>' +
  '<rect x="252" y="20" width="206" height="200"/></g></svg>';

const mockedRunner = async (db, sql, schema) => {
  if (db !== ":memory:") {
    throw new Error(`unexpected db: ${db}`);
  }
  if (!sql.includes("SUM(amount)")) {
    throw new Error(`unexpected sql: ${sql}`);
  }
  if (
    schema.fields.length !== 2 ||
    schema.fields[0].name !== "month" ||
    schema.fields[1].name !== "total"
  ) {
    throw new Error(`unexpected schema: ${JSON.stringify(schema)}`);
  }
  return "month,total\n2026-01,175\n2026-02,200\n";
};

const manifest = {
  id: "monthly-sales-duckdb",
  datasets: [
    {
      id: "monthly_sales",
      source: {
        kind: "duckdb",
        db: ":memory:",
        sql:
          "SELECT month, SUM(amount)::INT AS total FROM (VALUES ('2026-01','JP',100)) AS t(month,region,amount) GROUP BY month",
        schema: {
          fields: [
            { name: "month", dtype: "string" },
            { name: "total", dtype: "int" },
          ],
        },
      },
      pipeline: { steps: [] },
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

const resolved = await prefetchManifestSources(manifest, {
  duckdbRunner: mockedRunner,
});

if (resolved.datasets[0].source.kind !== "csv-inline") {
  throw new Error("prefetch did not rewrite duckdb source to csv-inline");
}

const svg = manifest_to_svg(JSON.stringify(resolved));
if (svg !== expectedSvg) {
  console.error("mismatch:");
  console.error("  expected:", expectedSvg);
  console.error("  actual:  ", svg);
  process.exit(1);
}
console.log("duckdb prefetch smoke ✓");
