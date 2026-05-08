import assert from "node:assert/strict";
import test from "node:test";

import { handleRequest } from "./worker.mjs";

const manifest = {
  id: "monthly-sales",
  datasets: [
    {
      id: "monthly_sales",
      source: {
        kind: "csv-inline",
        data: "month,region,amount\n2026-01,JP,100\n2026-02,JP,200\n",
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

function createEnv() {
  return {
    ASSETS: {
      fetch: async () => new Response("asset", { status: 200 }),
    },
  };
}

async function postJson(path, body) {
  const response = await handleRequest(
    new Request(`https://example.test/api/editor/${path}`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
    }),
    createEnv(),
  );
  return {
    status: response.status,
    json: JSON.parse(await response.text()),
  };
}

test("validate route returns structured diagnostics", async () => {
  const result = await postJson("validate", { manifest });
  assert.equal(result.status, 200);
  assert.equal(result.json.ok, true);
  assert.deepEqual(result.json.diagnostics, []);
  assert.equal(result.json.processId, "monthly-sales");
});

test("render route returns svg artifacts", async () => {
  const result = await postJson("render", { manifest });
  assert.equal(result.status, 200);
  assert.equal(result.json.ok, true);
  assert.equal(result.json.artifacts[0].kind, "svg");
  assert.match(result.json.artifacts[0].content, /<svg/);
});

test("invalid JSON returns a 400 editor error", async () => {
  const response = await handleRequest(
    new Request("https://example.test/api/editor/render", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{",
    }),
    createEnv(),
  );
  assert.equal(response.status, 400);
  const json = JSON.parse(await response.text());
  assert.equal(json.ok, false);
  assert.equal(json.error.kind, "invalid-json");
});

test("unknown editor route returns 404 without asset fallback", async () => {
  const response = await handleRequest(
    new Request("https://example.test/api/editor/unknown", { method: "GET" }),
    createEnv(),
  );
  assert.equal(response.status, 404);
});
