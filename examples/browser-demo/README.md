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

## Smoke test (no browser)

`node-smoke.mjs` does the same thing from Node:

```bash
moon build --target js --release
node examples/browser-demo/node-smoke.mjs
```

It prints the resulting SVG, which should match
`fixtures/expected/sales-bar.svg`.

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

## Limitations

- OPFS storage is M7.8.
