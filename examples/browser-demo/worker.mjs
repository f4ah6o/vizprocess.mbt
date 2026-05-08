let wasmModulePromise;

export default {
  async fetch(request, env) {
    return handleRequest(request, env);
  },
};

export async function handleRequest(request, env) {
  const url = new URL(request.url);
  const wasmModule = url.pathname.startsWith("/api/editor/") ? await loadWasmModule() : null;

  if (request.method === "POST" && url.pathname === "/api/editor/validate") {
    const body = await readJsonBody(request);
    return jsonText(wasmModule.manifest_to_validation_json(readManifestText(body)));
  }

  if (request.method === "POST" && url.pathname === "/api/editor/render") {
    const body = await readJsonBody(request);
    return jsonText(wasmModule.manifest_to_render_result_json(readManifestText(body)));
  }

  if (url.pathname.startsWith("/api/editor/")) {
    return new Response(JSON.stringify({ ok: false, error: { kind: "not-found", message: "unknown editor route" } }), {
      status: 404,
      headers: { "content-type": "application/json; charset=utf-8" },
    });
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
  } catch {
    return {};
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
