// Walk a process manifest and replace every csv-file source with an
// equivalent csv-inline source by fetching the path. The wasm bridge
// stays sync (only csv-inline is supported there); the async I/O lives
// here in JS-land.
//
// `reader(path)` is the host-specific function that turns a manifest
// path into the CSV text (e.g. fetch in the browser, fs.readFile in
// Node). Anything other than `csv-file` is left untouched.

export async function prefetchManifestSources(manifest, reader) {
  const out = { ...manifest, datasets: [] };
  for (const ds of manifest.datasets ?? []) {
    if (ds.source && ds.source.kind === "csv-file") {
      const text = await reader(ds.source.path);
      out.datasets.push({
        ...ds,
        source: {
          kind: "csv-inline",
          data: text,
          schema: ds.source.schema,
        },
      });
    } else {
      out.datasets.push(ds);
    }
  }
  return out;
}

// Convenience reader for browsers: resolve relative paths against
// `baseUrl` (typically the page URL) and fetch them as text.
export function browserReader(baseUrl) {
  return async (path) => {
    const url = new URL(path, baseUrl);
    const res = await fetch(url);
    if (!res.ok) {
      throw new Error(`fetch ${url}: ${res.status} ${res.statusText}`);
    }
    return await res.text();
  };
}
