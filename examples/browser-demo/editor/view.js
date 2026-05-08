import { selectedNode } from "./state.js";

let currentPreviewUrl = null;

export function renderGraph(state) {
  const manifest = state.manifest;
  if (!manifest) {
    return `<p>No manifest loaded.</p>`;
  }

  return `
    ${renderNodeGroup("Datasets", "dataset", manifest.datasets ?? [], state.selection)}
    ${renderNodeGroup("Charts", "chart", manifest.charts ?? [], state.selection)}
    ${renderNodeGroup("Artifacts", "artifact", manifest.artifacts ?? [], state.selection)}
    <div class="graph-group">
      <strong>Local files</strong>
      <ul class="file-list">
        ${
          state.localFiles.length > 0
            ? state.localFiles.map((file) => `<li><code>${escapeHtml(file)}</code></li>`).join("")
            : "<li>No OPFS attachments yet.</li>"
        }
      </ul>
    </div>
  `;
}

export function bindGraph(root, onSelect) {
  root.querySelectorAll("[data-kind][data-id]").forEach((button) => {
    button.addEventListener("click", () => {
      onSelect(button.dataset.kind, button.dataset.id);
    });
  });
}

export function renderInspector(state) {
  const node = selectedNode(state);
  if (!node) {
    return `
      <div class="inspector-form">
        <p>Select a dataset, chart, or artifact from the graph.</p>
      </div>
    `;
  }

  if (state.selection.kind === "dataset") {
    const source = node.source ?? {};
    return `
      <div class="inspector-form">
        <p><strong>Dataset</strong> <code>${escapeHtml(node.id)}</code></p>
        ${textInput("id", node.id)}
        ${selectInput("source.kind", source.kind ?? "csv-file", ["csv-file", "csv-inline", "duckdb"])}
        ${textInput("source.path", source.path ?? "")}
        ${textInput("source.db", source.db ?? ":memory:")}
        ${textareaInput("source.sql", source.sql ?? "")}
        ${textareaInput("source.schema", prettyJson(source.schema ?? { fields: [] }))}
        ${textareaInput("pipeline", prettyJson(node.pipeline ?? { steps: [] }))}
      </div>
    `;
  }

  if (state.selection.kind === "chart") {
    const spec = node.spec ?? {};
    const encoding = spec.encoding ?? {};
    const config = spec.config ?? {};
    return `
      <div class="inspector-form">
        <p><strong>Chart</strong> <code>${escapeHtml(node.id)}</code></p>
        ${textInput("id", node.id)}
        ${textInput("dataset_id", node.dataset_id ?? "")}
        ${textInput("spec.mark", spec.mark ?? "bar")}
        ${textInput("spec.encoding.x.field", encoding.x?.field ?? "")}
        ${textInput("spec.encoding.y.field", encoding.y?.field ?? "")}
        ${textInput("spec.config.width", String(config.width ?? 480))}
        ${textInput("spec.config.height", String(config.height ?? 240))}
      </div>
    `;
  }

  return `
    <div class="inspector-form">
      <p><strong>Artifact</strong> <code>${escapeHtml(node.id)}</code></p>
      ${textInput("id", node.id)}
      ${selectInput("kind", node.kind ?? "svg", ["svg", "render-model-json", "dataset-json"])}
      ${textInput("chart_id", node.chart_id ?? "")}
    </div>
  `;
}

export function bindInspector(root, onPatch) {
  root.querySelectorAll("[data-field]").forEach((input) => {
    const handler = (event) => onPatch(input.dataset.field, input.value, event.type);
    input.addEventListener("change", handler);
    if (input.tagName === "TEXTAREA" || input.tagName === "INPUT") {
      input.addEventListener("input", handler);
    }
  });
}

export function renderPreview(state) {
  const svgArtifact = state.renderResult?.artifacts?.find((artifact) => artifact.kind === "svg");
  if (!svgArtifact && currentPreviewUrl) {
    URL.revokeObjectURL(currentPreviewUrl);
    currentPreviewUrl = null;
  }
  const artifactSummary = state.renderResult?.artifacts?.length
    ? state.renderResult.artifacts
        .map((artifact) => `${artifact.id} (${artifact.kind})`)
        .join(", ")
    : "No artifacts";
  return `
    <div class="preview-block">
      <strong>Diagnostics</strong>
      <pre class="diag ${state.diagnostics.length ? "error" : "ok"}">${escapeHtml(renderDiagnosticsText(state.diagnostics))}</pre>
    </div>
    <div class="preview-block">
      <strong>Artifacts</strong>
      <pre>${escapeHtml(artifactSummary)}</pre>
    </div>
    <div class="preview-block">
      <strong>SVG</strong>
      <div class="preview-svg">${svgArtifact ? renderSvgImage(svgArtifact.content) : "<p>No SVG artifact.</p>"}</div>
    </div>
    <div class="preview-block">
      <strong>Resolved manifest</strong>
      <pre>${escapeHtml(prettyJson(state.resolvedManifest ?? {}))}</pre>
    </div>
  `;
}

function renderSvgImage(svg) {
  if (currentPreviewUrl) {
    URL.revokeObjectURL(currentPreviewUrl);
  }
  currentPreviewUrl = URL.createObjectURL(new Blob([svg], { type: "image/svg+xml" }));
  return `<img class="preview-svg-image" src="${escapeAttr(currentPreviewUrl)}" alt="Rendered SVG preview" />`;
}

export function renderDiagnosticsText(diagnostics) {
  if (!diagnostics?.length) return "No diagnostics.";
  return diagnostics
    .map((diag) => `[${diag.code ?? "INFO"}] ${diag.target ?? "$"}: ${diag.message ?? ""}`)
    .join("\n");
}

function renderNodeGroup(title, kind, items, selection) {
  return `
    <div class="graph-group">
      <strong>${escapeHtml(title)}</strong>
      <ul>
        ${items
          .map(
            (item) => `
              <li>
                <button
                  type="button"
                  class="graph-button ${selection.kind === kind && selection.id === item.id ? "active" : ""}"
                  data-kind="${kind}"
                  data-id="${escapeAttr(item.id)}"
                >
                  <span class="node-kicker">${kind}</span>
                  ${escapeHtml(item.id)}
                </button>
              </li>`,
          )
          .join("")}
      </ul>
    </div>
  `;
}

function textInput(field, value) {
  return `
    <label>
      <span>${escapeHtml(field)}</span>
      <input data-field="${escapeAttr(field)}" value="${escapeAttr(value)}" />
    </label>
  `;
}

function textareaInput(field, value) {
  return `
    <label>
      <span>${escapeHtml(field)}</span>
      <textarea data-field="${escapeAttr(field)}">${escapeHtml(value)}</textarea>
    </label>
  `;
}

function selectInput(field, value, options) {
  return `
    <label>
      <span>${escapeHtml(field)}</span>
      <select data-field="${escapeAttr(field)}">
        ${options
          .map(
            (option) =>
              `<option value="${escapeAttr(option)}" ${option === value ? "selected" : ""}>${escapeHtml(option)}</option>`,
          )
          .join("")}
      </select>
    </label>
  `;
}

function prettyJson(value) {
  return JSON.stringify(value, null, 2);
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function escapeAttr(value) {
  return escapeHtml(value).replaceAll("'", "&#39;");
}
