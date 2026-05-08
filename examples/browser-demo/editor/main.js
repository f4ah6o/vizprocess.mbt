import { getDuckDbConnection, duckdbQueryToCsv } from "../duckdb-loader.mjs";
import { readOpfsFile } from "../opfs.mjs";
import { browserReader, prefetchManifestSources } from "../prefetch.mjs";
import { postEditorJson } from "./http-client.js";
import {
  createWorkspaceId,
  listWorkspaceFiles,
  loadCurrentWorkspaceId,
  loadWorkspaceManifest,
  saveCurrentWorkspaceId,
  saveWorkspaceManifest,
  workspaceFilesPrefix,
  writeWorkspaceFile,
} from "./persistence.js";
import {
  cloneManifest,
  createArtifactDraft,
  createChartDraft,
  createDatasetDraft,
  createInitialState,
  ensureSelection,
  parseManifestSource,
  selectedNode,
  serializeManifest,
  updateSelection,
  upsertManifestNode,
} from "./state.js";
import { bindGraph, bindInspector, renderGraph, renderInspector, renderPreview } from "./view.js";
import { registerModelContextTools, runWithUserInteraction } from "./webmcp.js";

const state = createInitialState();

const sourceEl = document.getElementById("source");
const statusEl = document.getElementById("status");
const graphEl = document.getElementById("graph");
const inspectorEl = document.getElementById("inspector");
const previewEl = document.getElementById("preview");
const workspaceChipEl = document.getElementById("workspace-chip");
const fileInputEl = document.getElementById("file-input");

const fetchReader = browserReader(import.meta.url);
const disposeWebMcp = registerModelContextTools(createTools());
void disposeWebMcp;

document.getElementById("validate-button").addEventListener("click", async () => {
  await validateCurrentSource();
});
document.getElementById("render-button").addEventListener("click", async () => {
  await validateAndRenderCurrentSource();
});
document.getElementById("reset-button").addEventListener("click", async () => {
  await loadManifestSource(buildCsvFixtureManifest());
});
document.getElementById("export-button").addEventListener("click", async () => {
  await navigator.clipboard.writeText(state.source);
  setStatus("Copied manifest JSON to clipboard.");
});
document.getElementById("sample-csv").addEventListener("click", async () => {
  await loadManifestSource(buildCsvFixtureManifest());
});
document.getElementById("sample-duckdb").addEventListener("click", async () => {
  await loadManifestSource(buildDuckdbManifest());
});
document.getElementById("sample-opfs").addEventListener("click", async () => {
  await seedWorkspaceFixture();
  await loadManifestSource(buildOpfsManifest());
});
document.getElementById("seed-opfs").addEventListener("click", async () => {
  await seedWorkspaceFixture();
  await refreshLocalFiles();
  render();
});
document.getElementById("add-dataset").addEventListener("click", async () => {
  await syncManifestFromSource();
  const draft = createDatasetDraft(state.workspaceId, state.manifest);
  const id = upsertManifestNode(state.manifest, "dataset", draft);
  updateSelection(state, "dataset", id);
  await commitVisualEdit();
});
document.getElementById("add-chart").addEventListener("click", async () => {
  await syncManifestFromSource();
  const draft = createChartDraft(state.manifest);
  const id = upsertManifestNode(state.manifest, "chart", draft);
  updateSelection(state, "chart", id);
  await commitVisualEdit();
});
document.getElementById("add-artifact").addEventListener("click", async () => {
  await syncManifestFromSource();
  const draft = createArtifactDraft(state.manifest);
  const id = upsertManifestNode(state.manifest, "artifact", draft);
  updateSelection(state, "artifact", id);
  await commitVisualEdit();
});
sourceEl.addEventListener("input", () => {
  state.source = sourceEl.value;
});
fileInputEl.addEventListener("change", async () => {
  const file = fileInputEl.files?.[0];
  if (!file) return;
  const text = await file.text();
  const path = await writeWorkspaceFile(state.workspaceId, file.name, text);
  await refreshLocalFiles();
  setStatus(`Imported ${file.name} to ${path}.`);
  fileInputEl.value = "";
  render();
});

boot().catch((error) => {
  setStatus(error instanceof Error ? error.message : String(error));
});

async function boot() {
  state.workspaceId = loadCurrentWorkspaceId();
  if (!state.workspaceId) {
    state.workspaceId = createWorkspaceId();
    saveCurrentWorkspaceId(state.workspaceId);
  }
  workspaceChipEl.textContent = `Workspace: ${state.workspaceId}`;

  const saved = await loadWorkspaceManifest(state.workspaceId);
  if (saved) {
    await loadManifestSource(saved, { persist: false });
  } else {
    await loadManifestSource(buildCsvFixtureManifest(), { persist: true });
  }
  await refreshLocalFiles();
}

async function loadManifestSource(source, options = {}) {
  state.source = typeof source === "string" ? source : serializeManifest(source);
  sourceEl.value = state.source;
  if (options.persist !== false) {
    await saveWorkspaceManifest(state.workspaceId, state.source);
  }
  await validateAndRenderCurrentSource();
}

async function validateCurrentSource() {
  await syncManifestFromSource();
  state.resolvedManifest = await resolveCurrentManifest();
  const validation = await postEditorJson("validate", { manifest: state.resolvedManifest });
  state.diagnostics = validation.diagnostics ?? [];
  state.renderResult = null;
  await saveWorkspaceManifest(state.workspaceId, state.source);
  await refreshLocalFiles();
  render();
  setStatus(validation.ok ? "Validation succeeded." : "Validation returned diagnostics.");
  return validation;
}

async function validateAndRenderCurrentSource() {
  await syncManifestFromSource();
  setStatus("Resolving manifest sources…");
  state.resolvedManifest = await resolveCurrentManifest();
  const validation = await postEditorJson("validate", { manifest: state.resolvedManifest });
  const renderResult = await postEditorJson("render", { manifest: state.resolvedManifest });
  state.diagnostics = mergeDiagnostics(validation.diagnostics, renderResult.diagnostics);
  state.renderResult = renderResult;
  await saveWorkspaceManifest(state.workspaceId, state.source);
  await refreshLocalFiles();
  render();
  setStatus(renderResult.ok ? "Render succeeded." : "Render completed with diagnostics.");
  return renderResult;
}

async function syncManifestFromSource() {
  try {
    state.manifest = cloneManifest(parseManifestSource(state.source));
    ensureSelection(state);
    return state.manifest;
  } catch (error) {
    state.manifest = null;
    state.resolvedManifest = null;
    state.renderResult = null;
    state.diagnostics = [
      {
        code: "INVALID_JSON",
        severity: "error",
        target: "$",
        message: error instanceof Error ? error.message : String(error),
      },
    ];
    render();
    throw error;
  }
}

async function resolveCurrentManifest() {
  const conn = await getDuckDbConnection();
  const opfsPrefix = workspaceFilesPrefix(state.workspaceId);
  const manifest = cloneManifest(state.manifest);
  return prefetchManifestSources(manifest, {
    csvReader: async (path) => {
      if (path.startsWith("./") || path.startsWith("../") || path.startsWith("/") || path.startsWith("http://") || path.startsWith("https://")) {
        return fetchReader(path);
      }
      if (!path.startsWith(opfsPrefix) && path.includes("/files/")) {
        return fetchReader(path);
      }
      return readOpfsFile(path);
    },
    duckdbRunner: async (_db, sql, schema) => duckdbQueryToCsv(conn.conn, sql, schema),
  });
}

function render() {
  workspaceChipEl.textContent = `Workspace: ${state.workspaceId}`;
  graphEl.innerHTML = renderGraph(state);
  bindGraph(graphEl, (kind, id) => {
    updateSelection(state, kind, id);
    render();
  });

  inspectorEl.innerHTML = renderInspector(state);
  bindInspector(inspectorEl, async (field, value) => {
    applyInspectorPatch(field, value);
    await commitVisualEdit();
  });
  previewEl.innerHTML = renderPreview(state);
}

function applyInspectorPatch(field, value) {
  const node = selectedNode(state);
  if (!node) return;

  if (state.selection.kind === "dataset") {
    if (field === "pipeline") {
      node.pipeline = parseJsonField(value, node.pipeline);
      return;
    }
    if (field === "source.schema") {
      node.source.schema = parseJsonField(value, node.source.schema);
      return;
    }
  }

  if (field === "spec.config.width" || field === "spec.config.height") {
    setNested(node, field, Number(value));
    return;
  }

  setNested(node, field, value);
}

async function commitVisualEdit() {
  if (!state.manifest) return;
  state.source = serializeManifest(state.manifest);
  sourceEl.value = state.source;
  await validateAndRenderCurrentSource();
}

async function refreshLocalFiles() {
  state.localFiles = await listWorkspaceFiles(state.workspaceId);
}

async function seedWorkspaceFixture() {
  const text = await loadFixtureCsvText();
  const path = await writeWorkspaceFile(state.workspaceId, "sales.csv", text);
  setStatus(`Seeded ${path}.`);
}

function buildCsvFixtureManifest() {
  return serializeManifest({
    id: "monthly-sales",
    datasets: [
      {
        id: "monthly_sales",
        source: {
          kind: "csv-file",
          path: "../fixtures/datasets/sales.csv",
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
  });
}

function buildDuckdbManifest() {
  return serializeManifest({
    id: "monthly-sales-duckdb",
    datasets: [
      {
        id: "monthly_sales",
        source: {
          kind: "duckdb",
          db: ":memory:",
          sql:
            "SELECT month, SUM(amount)::INT AS total FROM (VALUES " +
            "('2026-01','JP',100),('2026-01','US',50)," +
            "('2026-02','JP',200),('2026-02','US',150)," +
            "('2026-01','JP',75)" +
            ") AS t(month, region, amount) " +
            "WHERE region = 'JP' GROUP BY month ORDER BY month",
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
  });
}

function buildOpfsManifest() {
  return serializeManifest({
    id: "monthly-sales-opfs",
    datasets: [
      {
        id: "monthly_sales",
        source: {
          kind: "csv-file",
          path: `${workspaceFilesPrefix(state.workspaceId)}/sales.csv`,
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
  });
}

async function loadFixtureCsvText() {
  const candidates = [
    "../fixtures/datasets/sales.csv",
    "../../../fixtures/datasets/sales.csv",
  ];
  let lastError = null;
  for (const path of candidates) {
    try {
      return await fetchReader(path);
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError ?? new Error("Failed to load sales.csv fixture.");
}

function createTools() {
  return [
    {
      name: "vizprocess-get-editor-state",
      title: "Get vizprocess editor state",
      description: "Returns the current manifest source, selection, diagnostics, and workspace files.",
      inputSchema: { type: "object", properties: {} },
      annotations: { readOnlyHint: true },
      execute: async () => ({
        workspaceId: state.workspaceId,
        source: state.source,
        selection: state.selection,
        diagnostics: state.diagnostics,
        resolvedManifest: state.resolvedManifest,
        renderResult: state.renderResult,
        localFiles: state.localFiles,
      }),
    },
    {
      name: "vizprocess-set-source",
      title: "Set vizprocess manifest source",
      description: "Replace the current manifest JSON source and rerender the preview.",
      inputSchema: {
        type: "object",
        properties: { source: { type: "string" } },
        required: ["source"],
      },
      execute: async ({ source }) => {
        state.source = source;
        sourceEl.value = source;
        await validateAndRenderCurrentSource();
        return { ok: true, diagnostics: state.diagnostics };
      },
    },
    {
      name: "vizprocess-validate-source",
      title: "Validate vizprocess source",
      description: "Resolve sources and validate the current manifest without returning rendered SVG.",
      inputSchema: { type: "object", properties: {} },
      execute: async () => validateCurrentSource(),
    },
    {
      name: "vizprocess-render-preview",
      title: "Render vizprocess preview",
      description: "Resolve sources, execute the process, and return diagnostics and artifact payloads.",
      inputSchema: { type: "object", properties: {} },
      execute: async () => validateAndRenderCurrentSource(),
    },
    {
      name: "vizprocess-export-source",
      title: "Export vizprocess source",
      description: "Copies the current source JSON to the clipboard and returns it.",
      inputSchema: { type: "object", properties: {} },
      execute: async (_args, client) =>
        runWithUserInteraction(client, async () => {
          await navigator.clipboard.writeText(state.source);
          return { source: state.source };
        }),
    },
    {
      name: "vizprocess-upsert-dataset",
      title: "Upsert dataset",
      description: "Create or replace a dataset node in the manifest and rerender the preview.",
      inputSchema: {
        type: "object",
        properties: {
          dataset: { type: "object" },
        },
      },
      execute: async ({ dataset }) => {
        await syncManifestFromSource();
        const draft = dataset ?? createDatasetDraft(state.workspaceId, state.manifest);
        const id = upsertManifestNode(state.manifest, "dataset", draft);
        updateSelection(state, "dataset", id);
        await commitVisualEdit();
        return { ok: true, datasetId: id };
      },
    },
    {
      name: "vizprocess-upsert-chart",
      title: "Upsert chart",
      description: "Create or replace a chart node in the manifest and rerender the preview.",
      inputSchema: {
        type: "object",
        properties: {
          chart: { type: "object" },
        },
      },
      execute: async ({ chart }) => {
        await syncManifestFromSource();
        const draft = chart ?? createChartDraft(state.manifest);
        const id = upsertManifestNode(state.manifest, "chart", draft);
        updateSelection(state, "chart", id);
        await commitVisualEdit();
        return { ok: true, chartId: id };
      },
    },
    {
      name: "vizprocess-upsert-artifact",
      title: "Upsert artifact",
      description: "Create or replace an artifact node in the manifest and rerender the preview.",
      inputSchema: {
        type: "object",
        properties: {
          artifact: { type: "object" },
        },
      },
      execute: async ({ artifact }) => {
        await syncManifestFromSource();
        const draft = artifact ?? createArtifactDraft(state.manifest);
        const id = upsertManifestNode(state.manifest, "artifact", draft);
        updateSelection(state, "artifact", id);
        await commitVisualEdit();
        return { ok: true, artifactId: id };
      },
    },
    {
      name: "vizprocess-list-local-files",
      title: "List local OPFS files",
      description: "Returns the files available under the current editor workspace.",
      inputSchema: { type: "object", properties: {} },
      annotations: { readOnlyHint: true },
      execute: async () => {
        await refreshLocalFiles();
        render();
        return {
          workspaceId: state.workspaceId,
          files: state.localFiles,
        };
      },
    },
  ];
}

function mergeDiagnostics(validationDiagnostics, renderDiagnostics) {
  const merged = [];
  for (const list of [validationDiagnostics ?? [], renderDiagnostics ?? []]) {
    for (const item of list) {
      const key = JSON.stringify([item.code, item.target, item.message]);
      if (!merged.some((candidate) => candidate._key === key)) {
        merged.push({ ...item, _key: key });
      }
    }
  }
  return merged.map(({ _key, ...rest }) => rest);
}

function parseJsonField(input, fallback) {
  try {
    return JSON.parse(input);
  } catch {
    return fallback;
  }
}

function setNested(target, field, value) {
  const parts = field.split(".");
  let current = target;
  for (let index = 0; index < parts.length - 1; index += 1) {
    const key = parts[index];
    current[key] ??= {};
    current = current[key];
  }
  current[parts.at(-1)] = value;
}

function setStatus(message) {
  statusEl.textContent = message;
}
