let wasmModulePromise;

export default {
  async fetch(request, env) {
    return handleRequest(request, env);
  },
};

export async function handleRequest(request, env) {
  const url = new URL(request.url);

  if (request.method === "POST" && url.pathname === "/api/editor/validate") {
    const body = await readJsonBody(request);
    if (body instanceof Response) return body;
    const wasmModule = await loadWasmModule();
    return jsonText(wasmModule.manifest_to_validation_json(readManifestText(body)));
  }

  if (request.method === "POST" && url.pathname === "/api/editor/render") {
    const body = await readJsonBody(request);
    if (body instanceof Response) return body;
    const wasmModule = await loadWasmModule();
    return jsonText(wasmModule.manifest_to_render_result_json(readManifestText(body)));
  }

  if (url.pathname.startsWith("/api/editor/")) {
    return new Response(JSON.stringify({ ok: false, error: { kind: "not-found", message: "unknown editor route" } }), {
      status: 404,
      headers: { "content-type": "application/json; charset=utf-8" },
    });
  }

  if (!env.ASSETS || typeof env.ASSETS.fetch !== "function") {
    return errorJson(500, "missing-assets", "ASSETS binding is not configured");
  }

  return env.ASSETS.fetch(request);
}

async function loadWasmModule() {
  wasmModulePromise ??= import("../../_build/js/release/build/wasm/wasm.js");
  return wasmModulePromise;
}

async function readJsonBody(request) {
  try {
    return await request.json();
  } catch (error) {
    return errorJson(400, "invalid-json", error instanceof Error ? error.message : "request body must be valid JSON");
  }
}

function readManifestText(body) {
  if (typeof body.source === "string") return body.source;
  if (body.manifest !== undefined) return JSON.stringify(body.manifest);
  return "{}";
}

function jsonText(payload) {
  return new Response(payload, {
    status: 200,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

function errorJson(status, kind, message) {
  return new Response(JSON.stringify({ ok: false, error: { kind, message } }), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}
