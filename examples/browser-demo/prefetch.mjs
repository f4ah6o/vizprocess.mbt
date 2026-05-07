// Walk a process manifest and replace `csv-file` and `duckdb` sources
// with `csv-inline` equivalents using host-supplied async resolvers.
// The wasm bridge only understands `csv-inline`; this function is the
// async / sync boundary.
//
// Resolvers (all optional):
//   - csvReader(path): returns the CSV text behind a `csv-file` source.
//   - duckdbRunner(db, sql, schema): returns CSV text for a `duckdb`
//     source. In the browser this is typically backed by DuckDB-Wasm;
//     in Node it can wrap the native pipe-duckdb binding.

export async function prefetchManifestSources(manifest, resolvers = {}) {
  const csvReader =
    typeof resolvers === "function" ? resolvers : resolvers.csvReader;
  const duckdbRunner = resolvers.duckdbRunner;
  const out = { ...manifest, datasets: [] };
  for (const ds of manifest.datasets ?? []) {
    const src = ds.source;
    if (src?.kind === "csv-file") {
      if (!csvReader) {
        throw new Error(
          `csv-file source on dataset '${ds.id}' needs a csvReader`,
        );
      }
      const text = await csvReader(src.path);
      out.datasets.push({
        ...ds,
        source: { kind: "csv-inline", data: text, schema: src.schema },
      });
    } else if (src?.kind === "duckdb") {
      if (!duckdbRunner) {
        throw new Error(
          `duckdb source on dataset '${ds.id}' needs a duckdbRunner`,
        );
      }
      const text = await duckdbRunner(src.db, src.sql, src.schema);
      out.datasets.push({
        ...ds,
        source: { kind: "csv-inline", data: text, schema: src.schema },
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
