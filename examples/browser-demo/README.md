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

## Limitations

- `duckdb` sources still report a friendly error in this build.
  DuckDB-WASM is M7.7.
- OPFS storage is M7.8.
