import { getDuckDbConnection, duckdbQueryToCsv } from "../duckdb-loader.mjs";
import { readOpfsFile } from "../opfs.mjs";
import { browserReader, prefetchManifestSources } from "../prefetch.mjs";
import { postEditorJson, renderLocally, validateLocally } from "./http-client.js";
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
const validateButton = document.getElementById("validate-button");
const renderButton = document.getElementById("render-button");
const resetButton = document.getElementById("reset-button");
const exportManifestButton = document.getElementById("export-manifest");
const exportSvgButton = document.getElementById("export-svg");
const exportArtifactsButton = document.getElementById("export-artifacts");
const sampleCsvButton = document.getElementById("sample-csv");
const sampleDuckDbButton = document.getElementById("sample-duckdb");
const sampleOpfsButton = document.getElementById("sample-opfs");
const seedOpfsButton = document.getElementById("seed-opfs");
const addDatasetButton = document.getElementById("add-dataset");
const addChartButton = document.getElementById("add-chart");
const addArtifactButton = document.getElementById("add-artifact");
let commitInFlight = null;
// One DuckDB connection is shared for the lifetime of this editor tab.
let duckDbConnectionPromise = null;
let activeRequestController = null;
let activeRequestToken = 0;
let renderDebounceTimer = null;
let busyDepth = 0;

const fetchReader = browserReader(import.meta.url);
const disposeWebMcp = registerModelContextTools(createTools());
void disposeWebMcp;

validateButton.addEventListener("click", async () => {
  await validateCurrentSource();
});
renderButton.addEventListener("click", async () => {
  await validateAndRenderCurrentSource();
});
resetButton.addEventListener("click", async () => {
  await loadManifestSource(buildCsvFixtureManifest());
});
exportManifestButton.addEventListener("click", () => {
  downloadText("vizprocess-manifest.json", state.source, "application/json");
  setStatus("Downloaded manifest JSON.");
});
exportSvgButton.addEventListener("click", () => {
  const svgArtifact = state.renderResult?.artifacts?.find((artifact) => artifact.kind === "svg");
  if (!svgArtifact) {
    setStatus("No SVG artifact is available. Render first.");
    return;
  }
  downloadText(`${svgArtifact.id || "vizprocess"}.svg`, svgArtifact.content, "image/svg+xml");
  setStatus("Downloaded SVG artifact.");
});
exportArtifactsButton.addEventListener("click", () => {
  const artifacts = state.renderResult?.artifacts ?? [];
  if (artifacts.length === 0) {
    setStatus("No artifacts are available. Render first.");
    return;
  }
  downloadText("vizprocess-artifacts.json", JSON.stringify(artifacts, null, 2), "application/json");
  setStatus("Downloaded artifact JSON.");
});
sampleCsvButton.addEventListener("click", async () => {
  await loadManifestSource(buildCsvFixtureManifest());
});
sampleDuckDbButton.addEventListener("click", async () => {
  await loadManifestSource(buildDuckdbManifest());
});
sampleOpfsButton.addEventListener("click", async () => {
  await seedWorkspaceFixture();
  await loadManifestSource(buildOpfsManifest());
});
seedOpfsButton.addEventListener("click", async () => {
  await seedWorkspaceFixture();
  await refreshLocalFiles();
  render();
});
addDatasetButton.addEventListener("click", async () => {
  if (commitInFlight) return;
  const manifest = await syncManifestFromSource();
  if (!manifest) return;
  const draft = createDatasetDraft(state.workspaceId, state.manifest);
  const id = upsertManifestNode(state.manifest, "dataset", draft);
  updateSelection(state, "dataset", id);
  await commitVisualEdit();
});
addChartButton.addEventListener("click", async () => {
  if (commitInFlight) return;
  const manifest = await syncManifestFromSource();
  if (!manifest) return;
  const draft = createChartDraft(state.manifest);
  const id = upsertManifestNode(state.manifest, "chart", draft);
  updateSelection(state, "chart", id);
  await commitVisualEdit();
});
addArtifactButton.addEventListener("click", async () => {
  if (commitInFlight) return;
  const manifest = await syncManifestFromSource();
  if (!manifest) return;
  const draft = createArtifactDraft(state.manifest);
  const id = upsertManifestNode(state.manifest, "artifact", draft);
  updateSelection(state, "artifact", id);
  await commitVisualEdit();
});
sourceEl.addEventListener("input", () => {
  state.source = sourceEl.value;
});
fileInputEl.addEventListener("change", async () => {
  const files = Array.from(fileInputEl.files ?? []);
  if (files.length === 0) return;
  const imported = [];
  for (const file of files) {
    const text = await file.text();
    const path = await writeWorkspaceFile(state.workspaceId, file.name, text);
    imported.push(`${file.name} -> ${path}`);
  }
  await refreshLocalFiles();
  setStatus(`Imported ${imported.join(", ")}.`);
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
  clearPendingRenderCommit();
  state.source = typeof source === "string" ? source : serializeManifest(source);
  sourceEl.value = state.source;
  if (options.persist !== false) {
    await saveWorkspaceManifest(state.workspaceId, state.source);
  }
  await validateAndRenderCurrentSource();
}

async function validateCurrentSource() {
  return runLatestRequest("Resolving manifest sources…", async ({ signal, isCurrent }) => {
    const manifest = await syncManifestFromSource();
    if (!manifest || !isCurrent()) return { ok: false, diagnostics: state.diagnostics };
    state.resolvedManifest = await resolveCurrentManifest();
    const validation = await validateResolvedManifest(state.resolvedManifest, { signal });
    if (!isCurrent()) return null;
    state.diagnostics = validation.diagnostics ?? [];
    state.renderResult = null;
    await saveWorkspaceManifest(state.workspaceId, state.source);
    await refreshLocalFiles();
    render();
    setStatus(validation.ok ? "Validation succeeded." : "Validation returned diagnostics.");
    return validation;
  });
}

async function validateAndRenderCurrentSource() {
  return runLatestRequest("Resolving manifest sources…", async ({ signal, isCurrent }) => {
    const manifest = await syncManifestFromSource();
    if (!manifest || !isCurrent()) return { ok: false, diagnostics: state.diagnostics };
    state.resolvedManifest = await resolveCurrentManifest();
    const renderResult = await renderResolvedManifest(state.resolvedManifest, { signal });
    if (!isCurrent()) return null;
    state.diagnostics = renderResult.diagnostics ?? [];
    state.renderResult = renderResult;
    await saveWorkspaceManifest(state.workspaceId, state.source);
    await refreshLocalFiles();
    render();
    setStatus(renderResult.ok ? "Render succeeded." : "Render completed with diagnostics.");
    return renderResult;
  });
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
    setStatus("Manifest JSON is invalid.");
    return null;
  }
}

async function resolveCurrentManifest() {
  const opfsPrefix = workspaceFilesPrefix(state.workspaceId);
  const manifest = cloneManifest(state.manifest);
  return prefetchManifestSources(manifest, {
    csvReader: async (path) => {
      if (resolveCsvSourceMode(path, opfsPrefix) === "fetch") {
        return fetchReader(path);
      }
      return readOpfsFile(path);
    },
    duckdbRunner: async (_db, sql, schema) => {
      duckDbConnectionPromise ??= getDuckDbConnection();
      const conn = await duckDbConnectionPromise;
      return duckdbQueryToCsv(conn.conn, sql, schema);
    },
  });
}

async function validateResolvedManifest(manifest, options = {}) {
  try {
    return await validateLocally(manifest);
  } catch (error) {
    if (options.signal?.aborted) throw error;
    console.warn("browser-local validate failed; falling back to Worker API", error);
    return postEditorJson("validate", { manifest }, options);
  }
}

async function renderResolvedManifest(manifest, options = {}) {
  try {
    return await renderLocally(manifest);
  } catch (error) {
    if (options.signal?.aborted) throw error;
    console.warn("browser-local render failed; falling back to Worker API", error);
    return postEditorJson("render", { manifest }, options);
  }
}

function render() {
  workspaceChipEl.textContent = `Workspace: ${state.workspaceId}`;
  graphEl.innerHTML = renderGraph(state);
  bindGraph(graphEl, (kind, id) => {
    clearPendingRenderCommit();
    updateSelection(state, kind, id);
    render();
  });

  inspectorEl.innerHTML = renderInspector(state);
  bindInspector(inspectorEl, async (field, value, eventType) => {
    try {
      applyInspectorPatch(field, value);
      if (eventType === "change") {
        await commitVisualEdit();
      } else {
        scheduleVisualCommit();
      }
    } catch (error) {
      setStatus(error instanceof Error ? error.message : String(error));
      render();
    }
  });
  previewEl.innerHTML = renderPreview(state);
}

function applyInspectorPatch(field, value) {
  const node = selectedNode(state);
  if (!node) return;
  clearInvalidJsonField(field, { rerender: false });

  if (state.selection.kind === "dataset") {
    if (field === "pipeline") {
      node.pipeline = parseJsonField(field, value);
      return;
    }
    if (field === "source.schema") {
      node.source.schema = parseJsonField(field, value);
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
  if (commitInFlight) return commitInFlight;
  if (!state.manifest) return null;
  clearPendingRenderCommit();
  commitInFlight = (async () => {
    state.source = serializeManifest(state.manifest);
    sourceEl.value = state.source;
    await validateAndRenderCurrentSource();
  })();
  try {
    return await commitInFlight;
  } finally {
    commitInFlight = null;
  }
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
            "('2026-03','JP',175),('2026-01','JP',75)" +
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
      name: "vizprocess-export-artifacts",
      title: "Export vizprocess artifacts",
      description: "Returns rendered artifacts from the current browser-local render result.",
      inputSchema: { type: "object", properties: {} },
      annotations: { readOnlyHint: true },
      execute: async () => ({
        ok: Boolean(state.renderResult?.ok),
        artifacts: state.renderResult?.artifacts ?? [],
        diagnostics: state.diagnostics,
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
        const result = await validateAndRenderCurrentSource();
        return { ok: Boolean(result?.ok), diagnostics: state.diagnostics };
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
          try {
            await navigator.clipboard.writeText(state.source);
            return { ok: true, source: state.source };
          } catch (error) {
            const message = error instanceof Error ? error.message : "Clipboard write failed.";
            setStatus(message);
            return { ok: false, source: state.source, error: message };
          }
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
      execute: async ({ dataset }, client) =>
        runWithUserInteraction(client, async () => {
        const manifest = await syncManifestFromSource();
        if (!manifest) {
          return { ok: false, diagnostics: state.diagnostics };
        }
        const draft = dataset ?? createDatasetDraft(state.workspaceId, state.manifest);
        const id = upsertManifestNode(state.manifest, "dataset", draft);
        updateSelection(state, "dataset", id);
        await commitVisualEdit();
        return { ok: true, datasetId: id, diagnostics: state.diagnostics };
      }),
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
      execute: async ({ chart }, client) =>
        runWithUserInteraction(client, async () => {
        const manifest = await syncManifestFromSource();
        if (!manifest) {
          return { ok: false, diagnostics: state.diagnostics };
        }
        const draft = chart ?? createChartDraft(state.manifest);
        const id = upsertManifestNode(state.manifest, "chart", draft);
        updateSelection(state, "chart", id);
        await commitVisualEdit();
        return { ok: true, chartId: id, diagnostics: state.diagnostics };
      }),
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
      execute: async ({ artifact }, client) =>
        runWithUserInteraction(client, async () => {
        const manifest = await syncManifestFromSource();
        if (!manifest) {
          return { ok: false, diagnostics: state.diagnostics };
        }
        const draft = artifact ?? createArtifactDraft(state.manifest);
        const id = upsertManifestNode(state.manifest, "artifact", draft);
        updateSelection(state, "artifact", id);
        await commitVisualEdit();
        return { ok: true, artifactId: id, diagnostics: state.diagnostics };
      }),
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

function parseJsonField(field, input) {
  try {
    return JSON.parse(input);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    setInvalidJsonField(field, message, { rerender: false });
    throw new Error(`Invalid JSON for ${field}: ${message}`);
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

function scheduleVisualCommit() {
  clearPendingRenderCommit();
  const selectionKey = JSON.stringify(state.selection);
  renderDebounceTimer = setTimeout(() => {
    renderDebounceTimer = null;
    if (selectionKey !== JSON.stringify(state.selection)) {
      return;
    }
    void commitVisualEdit();
  }, 150);
}

function clearPendingRenderCommit() {
  if (renderDebounceTimer != null) {
    clearTimeout(renderDebounceTimer);
    renderDebounceTimer = null;
  }
}

async function runLatestRequest(statusMessage, task) {
  clearPendingRenderCommit();
  const token = ++activeRequestToken;
  activeRequestController?.abort();
  const controller = new AbortController();
  activeRequestController = controller;
  setBusy(true);
  setStatus(statusMessage);
  try {
    return await task({
      signal: controller.signal,
      isCurrent: () => activeRequestToken === token && activeRequestController === controller,
    });
  } catch (error) {
    if (error?.name === "AbortError") {
      return null;
    }
    throw error;
  } finally {
    if (activeRequestController === controller) {
      activeRequestController = null;
    }
    setBusy(false);
  }
}

function setBusy(nextBusy) {
  busyDepth = Math.max(0, busyDepth + (nextBusy ? 1 : -1));
  const disabled = busyDepth > 0;
  for (const element of [
    validateButton,
    renderButton,
    resetButton,
    exportManifestButton,
    exportSvgButton,
    exportArtifactsButton,
    sampleCsvButton,
    sampleDuckDbButton,
    sampleOpfsButton,
    seedOpfsButton,
    addDatasetButton,
    addChartButton,
    addArtifactButton,
  ]) {
    element.disabled = disabled;
  }
}

function downloadText(fileName, text, type) {
  const url = URL.createObjectURL(new Blob([text], { type }));
  const link = document.createElement("a");
  link.href = url;
  link.download = fileName;
  document.body.append(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}

function resolveCsvSourceMode(path, opfsPrefix) {
  if (path.startsWith(opfsPrefix)) {
    return "opfs";
  }
  if (
    path.startsWith("./") ||
    path.startsWith("../") ||
    path.startsWith("/") ||
    path.startsWith("http://") ||
    path.startsWith("https://")
  ) {
    return "fetch";
  }
  return "opfs";
}

function setInvalidJsonField(field, message, options = {}) {
  const diagnostic = {
    code: "INVALID_JSON_FIELD",
    severity: "error",
    target: field,
    message,
  };
  state.diagnostics = [
    ...state.diagnostics.filter((item) => !(item.code === "INVALID_JSON_FIELD" && item.target === field)),
    diagnostic,
  ];
  if (options.rerender !== false) {
    render();
  }
}

function clearInvalidJsonField(field, options = {}) {
  state.diagnostics = state.diagnostics.filter(
    (item) => !(item.code === "INVALID_JSON_FIELD" && item.target === field),
  );
  if (options.rerender !== false) {
    render();
  }
}
