# browser-demo

Minimal page that imports `packages/wasm` (built for the `js` target) as
an ES module and renders the SVG returned by `manifest_to_svg`.

## Run

```bash
# from repo root
moon build --target js --release
python3 -m http.server 8080
# open http://localhost:8080/examples/browser-demo/
```

The page edits a JSON manifest in-place and re-renders on click.

## Smoke tests (no browser)

```bash
moon build --target js --release

# csv-file path (fs.readFile reader): prints SVG matching
# fixtures/expected/sales-bar.svg.
node examples/browser-demo/node-smoke.mjs

# duckdb path with a mock runner: validates that
# prefetchManifestSources rewrites a duckdb source into csv-inline
# the wasm bridge accepts. Booting DuckDB-Wasm itself isn't part of
# the test (Node uses the native pipe-duckdb binding for that).
node examples/browser-demo/duckdb-prefetch-smoke.mjs
```

## How sources are resolved

`packages/wasm` only knows `csv-inline`. The `prefetch.mjs` module
walks a manifest, replaces every `csv-file` source with an inline
equivalent (using a host-supplied reader), and the resolved manifest
is what gets passed to `manifest_to_svg`.

- Browser: `browserReader(import.meta.url)` resolves paths against the
  page URL and uses `fetch`.
- Node: `fs.readFile`-backed reader (see `node-smoke.mjs`).

## DuckDB-Wasm

`duckdb` sources are resolved by `duckdb-loader.mjs`, which lazy-loads
[`@duckdb/duckdb-wasm`](https://www.npmjs.com/package/@duckdb/duckdb-wasm)
from jsDelivr the first time a `duckdb` source appears in a manifest.
The bundle pin lives at the top of `duckdb-loader.mjs`.

Limitations of the JS-side path:

- The result is re-encoded as unquoted CSV before reaching the wasm
  bridge, so string columns must not contain `,`, `"`, `\n`, or `\r`.
  The loader throws if it sees one.
- Files referenced inside the SQL (e.g. `read_csv('../../fixtures/...')`)
  resolve against DuckDB-Wasm's virtual filesystem, not the page URL —
  use absolute or page-relative paths and serve the project root.

## OPFS

`opfs.mjs` exposes a small wrapper around the Origin Private File
System: `writeOpfsFile`, `readOpfsFile`, `deleteOpfsFile`,
`listOpfsFiles`, `clearOpfs`, plus `opfsReader()` which returns a
`csvReader`-shaped function that resolves manifest paths against
OPFS instead of the network.

The demo decides per path: anything starting with `./`, `../`, or
`/` is fetched, anything else is read from OPFS. Click the
"Seed sales.csv → OPFS" button once to copy the fixture into
`vizprocess/sales.csv`, then switch to the "OPFS example" manifest
and click Render.

OPFS is browser-only (Node has no `navigator.storage`), so there is
no Node smoke test for this path. The reader contract is the same
shape as the fetch / fs.readFile readers, so
`prefetchManifestSources` accepts it without modification.
