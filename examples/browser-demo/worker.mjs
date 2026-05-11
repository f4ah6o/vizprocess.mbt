let wasmModulePromise;
const MAX_EDITOR_BODY_BYTES = 256 * 1024;

export default {
  async fetch(request, env) {
    return handleRequest(request, env);
  },
};

export async function handleRequest(request, env) {
  const url = new URL(request.url);
  const wasmModule = url.pathname.startsWith("/api/editor/") ? await loadWasmModule() : null;

  if (request.method === "POST" && url.pathname === "/api/editor/validate") {
    const result = await readJsonBody(request);
    if (!result.ok) return result.response;
    return jsonText(wasmModule.manifest_to_validation_json(readManifestText(result.body)));
  }

  if (request.method === "POST" && url.pathname === "/api/editor/render") {
    const result = await readJsonBody(request);
    if (!result.ok) return result.response;
    return jsonText(wasmModule.manifest_to_render_result_json(readManifestText(result.body)));
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
  const length = Number(request.headers.get("content-length") ?? "0");
  if (length > MAX_EDITOR_BODY_BYTES) {
    return {
      ok: false,
      response: editorError("payload-too-large", `editor payload must be <= ${MAX_EDITOR_BODY_BYTES} bytes`, 413),
    };
  }
  try {
    const text = await request.text();
    if (new TextEncoder().encode(text).byteLength > MAX_EDITOR_BODY_BYTES) {
      return {
        ok: false,
        response: editorError("payload-too-large", `editor payload must be <= ${MAX_EDITOR_BODY_BYTES} bytes`, 413),
      };
    }
    return { ok: true, body: text ? JSON.parse(text) : {} };
  } catch (error) {
    return {
      ok: false,
      response: editorError("invalid-json", error instanceof Error ? error.message : "invalid JSON request body", 400),
    };
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

function editorError(kind, message, status) {
  return new Response(
    JSON.stringify({
      ok: false,
      error: { kind, message },
      diagnostics: [
        {
          source: "worker",
          code: kind.toUpperCase().replaceAll("-", "_"),
          severity: "error",
          target: "$",
          message,
        },
      ],
    }),
    {
      status,
      headers: {
        "content-type": "application/json; charset=utf-8",
        "cache-control": "no-store",
      },
    },
  );
}
