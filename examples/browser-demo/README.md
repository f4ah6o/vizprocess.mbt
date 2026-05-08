# browser-demo

Cloudflare-targeted browser surfaces for `vizprocess.mbt`.

- `/` is the original manifest textarea demo.
- `/editor/` is the graph/inspector editor backed by OPFS workspaces,
  browser-side source resolution, and WebMCP registration.

The editor talks to experimental internal Worker routes:

- `POST /api/editor/validate`
- `POST /api/editor/render`

Those APIs are browser-editor contracts, not a public persistence API.

## Run

```bash
# from repo root
moon build --target js --release
pnpm install
pnpm run build:cloudflare-demo-assets
wrangler dev --env=""
```

Then open:

- `http://127.0.0.1:8787/` for the original demo
- `http://127.0.0.1:8787/editor/` for the editor

## Smoke tests (no browser)

```bash
moon build --target js --release
npm run test:js

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

The editor stores the current workspace manifest at:

- `vizprocess-editor/workspaces/<workspace-id>/manifest.json`

Imported CSV attachments live under:

- `vizprocess-editor/workspaces/<workspace-id>/files/*`

Path resolution is:

- `./`, `../`, `/`, `http://`, `https://` -> `fetch`
- everything else -> OPFS

Click "Seed OPFS" once to copy the sales fixture into the current
workspace, then switch to the OPFS sample manifest.

OPFS is browser-only (Node has no `navigator.storage`), so there is
no Node smoke test for this path. The reader contract is the same
shape as the fetch / fs.readFile readers, so
`prefetchManifestSources` accepts it without modification.

## WebMCP

The editor registers browser-side `navigator.modelContext` tools with the
`vizprocess-*` prefix, including:

- `vizprocess-get-editor-state`
- `vizprocess-set-source`
- `vizprocess-validate-source`
- `vizprocess-render-preview`
- `vizprocess-export-source`
- `vizprocess-upsert-dataset`
- `vizprocess-upsert-chart`
- `vizprocess-upsert-artifact`
- `vizprocess-list-local-files`
