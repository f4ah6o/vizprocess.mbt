import assert from "node:assert/strict";
import test from "node:test";

import { registerModelContextTools, runWithUserInteraction } from "./editor/webmcp.js";

test("registerModelContextTools is a no-op when modelContext is absent", () => {
  const priorNavigator = globalThis.navigator;
  Object.defineProperty(globalThis, "navigator", {
    configurable: true,
    value: {},
  });
  const dispose = registerModelContextTools([{ name: "noop" }]);
  assert.equal(typeof dispose, "function");
  dispose();
  Object.defineProperty(globalThis, "navigator", {
    configurable: true,
    value: priorNavigator,
  });
});

test("registerModelContextTools wires abort disposal", () => {
  const registrations = [];
  const aborted = [];
  const priorNavigator = globalThis.navigator;

  Object.defineProperty(globalThis, "navigator", {
    configurable: true,
    value: {
      modelContext: {
        registerTool(tool, { signal }) {
          registrations.push(tool.name);
          signal.addEventListener("abort", () => aborted.push(tool.name));
        },
      },
    },
  });

  const dispose = registerModelContextTools([{ name: "vizprocess-render-preview" }]);
  assert.deepEqual(registrations, ["vizprocess-render-preview"]);
  dispose();
  assert.deepEqual(aborted, ["vizprocess-render-preview"]);

  Object.defineProperty(globalThis, "navigator", {
    configurable: true,
    value: priorNavigator,
  });
});

test("runWithUserInteraction falls back to direct execution", async () => {
  const result = await runWithUserInteraction(null, async () => "ok");
  assert.equal(result, "ok");
});
