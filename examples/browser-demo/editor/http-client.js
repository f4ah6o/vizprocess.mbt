let wasmModulePromise = null;

export async function validateLocally(manifest) {
  const wasm = await loadWasmModule();
  return parseEditorJson("local validate", wasm.manifest_to_validation_json(JSON.stringify(manifest)));
}

export async function renderLocally(manifest) {
  const wasm = await loadWasmModule();
  return parseEditorJson("local render", wasm.manifest_to_render_result_json(JSON.stringify(manifest)));
}

export async function postEditorJson(path, body, options = {}) {
  const response = await fetch(`/api/editor/${path}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
    signal: options.signal,
  });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`${path} failed: ${response.status} ${response.statusText}\n${text}`);
  }
  return parseEditorJson(`/api/editor/${path}`, text);
}

async function loadWasmModule() {
  if (!wasmModulePromise) {
    wasmModulePromise = importWasmModule();
  }
  const currentPromise = wasmModulePromise;
  try {
    return await currentPromise;
  } catch (error) {
    if (wasmModulePromise === currentPromise) {
      wasmModulePromise = null;
    }
    throw error;
  }
}

async function importWasmModule() {
  const candidates = [
    "../wasm.js",
    "../../../_build/js/release/build/wasm/wasm.js",
  ];
  let lastError = null;
  for (const path of candidates) {
    try {
      return await import(path);
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError ?? new Error("Failed to load vizprocess wasm module.");
}

function parseEditorJson(label, text) {
  try {
    return JSON.parse(text);
  } catch {
    throw new Error(`Invalid JSON from ${label}: ${text}`);
  }
}
