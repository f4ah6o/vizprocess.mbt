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

## Limitations (M7.5)

- Only `csv-inline` sources work in this build. `csv-file` and `duckdb`
  sources reject with a friendly error message.
- DuckDB-WASM, OPFS storage, and `fetch`-backed CSV loading are tracked
  for M7.6+.
