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

async function postRaw(path, body, headers = {}) {
  const response = await handleRequest(
    new Request(`https://example.test/api/editor/${path}`, {
      method: "POST",
      headers,
      body,
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

test("editor routes return structured invalid json errors", async () => {
  const result = await postRaw("validate", "{", { "content-type": "application/json" });
  assert.equal(result.status, 400);
  assert.equal(result.json.ok, false);
  assert.equal(result.json.error.kind, "invalid-json");
  assert.equal(result.json.diagnostics[0].code, "INVALID_JSON");
});

test("editor routes reject oversized payloads", async () => {
  const result = await postRaw("render", "x".repeat(256 * 1024 + 1), {
    "content-type": "application/json",
  });
  assert.equal(result.status, 413);
  assert.equal(result.json.ok, false);
  assert.equal(result.json.error.kind, "payload-too-large");
});

test("editor routes reject oversized content-length before parsing", async () => {
  const result = await postRaw("render", "{}", {
    "content-length": String(256 * 1024 + 1),
    "content-type": "application/json",
  });
  assert.equal(result.status, 413);
  assert.equal(result.json.ok, false);
  assert.equal(result.json.error.kind, "payload-too-large");
});
