export function createInitialState() {
  return {
    workspaceId: "",
    source: "",
    manifest: null,
    resolvedManifest: null,
    diagnostics: [],
    renderResult: null,
    localFiles: [],
    selection: { kind: "dataset", id: "" },
  };
}

export function parseManifestSource(source) {
  return JSON.parse(source);
}

export function serializeManifest(manifest) {
  return `${JSON.stringify(manifest, null, 2)}\n`;
}

export function cloneManifest(manifest) {
  return structuredClone(manifest);
}

export function ensureSelection(state) {
  if (!state.manifest) {
    state.selection = { kind: "dataset", id: "" };
    return;
  }

  const pools = [
    { kind: "dataset", items: state.manifest.datasets ?? [] },
    { kind: "chart", items: state.manifest.charts ?? [] },
    { kind: "artifact", items: state.manifest.artifacts ?? [] },
  ];

  const current = selectionPool(state.manifest, state.selection.kind);
  if (state.selection.id && current.some((item) => item.id === state.selection.id)) {
    return;
  }

  for (const pool of pools) {
    if (pool.items.length > 0) {
      state.selection = { kind: pool.kind, id: pool.items[0].id };
      return;
    }
  }

  state.selection = { kind: "dataset", id: "" };
}

export function selectionPool(manifest, kind) {
  if (!manifest) return [];
  if (kind === "dataset") return manifest.datasets ?? [];
  if (kind === "chart") return manifest.charts ?? [];
  if (kind === "artifact") return manifest.artifacts ?? [];
  return [];
}

export function selectedNode(state) {
  const pool = selectionPool(state.manifest, state.selection.kind);
  return pool.find((item) => item.id === state.selection.id) ?? null;
}

export function updateSelection(state, kind, id) {
  state.selection = { kind, id };
}

export function createDatasetDraft(workspaceId, manifest) {
  const id = uniqueId(manifest?.datasets ?? [], "dataset");
  return {
    id,
    source: {
      kind: "csv-file",
      path: `${workspaceFilesPrefix(workspaceId)}/sales.csv`,
      schema: {
        fields: [
          { name: "month", dtype: "string" },
          { name: "region", dtype: "string" },
          { name: "amount", dtype: "int" },
        ],
      },
    },
    pipeline: { steps: [] },
  };
}

export function createChartDraft(manifest) {
  const id = uniqueId(manifest?.charts ?? [], "chart");
  return {
    id,
    dataset_id: manifest?.datasets?.[0]?.id ?? "dataset",
    spec: {
      id,
      mark: "bar",
      encoding: {
        x: { field: "month" },
        y: { field: "amount" },
      },
      config: { width: 480, height: 240 },
    },
  };
}

export function createArtifactDraft(manifest) {
  const id = uniqueId(manifest?.artifacts ?? [], "artifact");
  return {
    id,
    kind: "svg",
    chart_id: manifest?.charts?.[0]?.id ?? "chart",
  };
}

export function upsertManifestNode(manifest, kind, draft) {
  const key = `${kind}s`;
  const list = manifest[key] ?? [];
  const index = list.findIndex((item) => item.id === draft.id);
  if (index >= 0) {
    list[index] = draft;
  } else {
    list.push(draft);
  }
  manifest[key] = list;
  return draft.id;
}

function uniqueId(items, base) {
  const existing = new Set(items.map((item) => item.id));
  if (!existing.has(base)) return base;
  let counter = 2;
  while (existing.has(`${base}-${counter}`)) counter += 1;
  return `${base}-${counter}`;
}

function workspaceFilesPrefix(workspaceId) {
  return `vizprocess-editor/workspaces/${workspaceId}/files`;
}
