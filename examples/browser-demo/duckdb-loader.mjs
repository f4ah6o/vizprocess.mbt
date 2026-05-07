// Lazily load DuckDB-Wasm from jsDelivr and return a ready-to-use
// connection. Imported only when a manifest actually contains a
// `duckdb` source so demos that stay on csv-file/csv-inline don't
// pay the network cost.
//
// Pinned to a specific version so behaviour is stable across runs.

const DUCKDB_VERSION = "1.29.0";
const DUCKDB_CDN =
  `https://cdn.jsdelivr.net/npm/@duckdb/duckdb-wasm@${DUCKDB_VERSION}/+esm`;

let cached = null;

export async function getDuckDbConnection() {
  if (cached) {
    return cached;
  }
  cached = (async () => {
    const duckdb = await import(/* @vite-ignore */ DUCKDB_CDN);
    const bundles = duckdb.getJsDelivrBundles();
    const bundle = await duckdb.selectBundle(bundles);
    const workerUrl = URL.createObjectURL(
      new Blob([`importScripts("${bundle.mainWorker}");`], {
        type: "text/javascript",
      }),
    );
    const worker = new Worker(workerUrl);
    const logger = new duckdb.ConsoleLogger();
    const db = new duckdb.AsyncDuckDB(logger, worker);
    await db.instantiate(bundle.mainModule, bundle.pthreadWorker);
    URL.revokeObjectURL(workerUrl);
    const conn = await db.connect();
    return { conn, db, duckdb };
  })();
  return cached;
}

// Run `sql` via DuckDB-Wasm and serialize the result as CSV with the
// columns declared in `schema`. Used by `prefetchManifestSources` to
// rewrite a `duckdb` source into an inline-CSV one before the wasm
// bridge sees it.
export async function duckdbQueryToCsv(conn, sql, schema) {
  const result = await conn.query(sql);
  const rows = result.toArray();
  const fields = schema.fields ?? [];
  const header = fields.map((f) => f.name).join(",");
  const lines = [header];
  for (const row of rows) {
    const cells = fields.map((f) => csvCell(row[f.name], f.dtype));
    lines.push(cells.join(","));
  }
  return lines.join("\n") + "\n";
}

function csvCell(value, dtype) {
  if (value === null || value === undefined) {
    return "";
  }
  if (dtype === "int") {
    // BigInt -> number-ish string; pipe.parse_int64 handles either form.
    return String(typeof value === "bigint" ? value : Math.trunc(value));
  }
  // Strings: pipe's CSV parser is unquoted; reject embedded commas
  // up-front rather than silently corrupt the row.
  const s = String(value);
  if (s.includes(",") || s.includes("\n") || s.includes("\r")) {
    throw new Error(
      `string cell contains a CSV-special character: ${JSON.stringify(s)}`,
    );
  }
  return s;
}
