# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- M0: monorepo bootstrap. Skeleton for `pipe`, `viz`, `vizprocess`, `cli` packages.
- CI workflow for native target.
- M1 (`pipe`): minimal pipeline with `parse_csv`, `Pipeline` (Select / Filter /
  Aggregate), `validate_pipeline`, `run_pipeline`, deterministic
  `dataset_to_json` sink. Int and String columns only. Local `parse_int64`
  helper avoids a `core/strconv` dependency. Golden white-box test covers
  CSV → select → filter → aggregate → JSON.
- M1 fixtures: `fixtures/datasets/sales.csv`,
  `fixtures/specs/monthly-sales.pipeline.json`,
  `fixtures/expected/monthly-sales.dataset.json` (loader and CLI integration
  arrive in M5).
- M2 (`viz`): `ChartSpec`, `Encoding`, `Mark` (Bar / Line), `RenderModel`,
  and a `compile_chart` that lowers a chart spec plus a row-oriented
  `VizDataset` to a deterministic, integer-pixel render model. Includes
  `validate_chart` and a JSON renderer (`render_json`). `viz` does not
  depend on `pipe`; M4's `vizprocess` adapts `pipe.Dataset` to
  `VizDataset`. Golden white-box tests cover bar JSON output and line
  point counts.
- M2 fixtures: `fixtures/specs/sales-bar.chart.json`,
  `fixtures/expected/sales-bar.render-model.json`.
- M3 (`viz`): `render_svg` produces a deterministic single-line SVG document
  from a `RenderModel`. Rect and polyline output only; axes, legends, and
  per-mark styling deferred. Golden white-box tests cover the bar and line
  cases.
- M3 fixture: `fixtures/expected/sales-bar.svg`.
- M5a (`cli`): runnable command line `vizprocess process-run <csv-path>
  <output-dir>` that reads a CSV from disk, runs the hardcoded sales-bar
  process, writes SVG / render-model JSON / dataset JSON artifacts to
  the output directory, and prints a deterministic status JSON to
  stdout. Exit codes follow the project spec (§20). The full manifest
  JSON loader is deferred to M5b.
- Note: MoonBit's `<` / `>` on `String` compares by length rather than
  lexicographically. The CLI now uses an explicit `lex_compare` helper
  for byte-stable artifact ordering.
- M5b (`vizprocess` + `cli`): full process-manifest JSON loader.
  `vizprocess.build_process_from_json(json_text, csv_reader)` parses a
  manifest covering datasets (csv-file or csv-inline source +
  pipeline), charts, and artifacts, returning a runnable `VizProcess`.
  Errors carry `$.path.to.field`-style path prefixes. The CLI now reads
  a manifest file (`process-run <manifest.json> <output-dir>`) and
  resolves csv-file paths relative to the manifest's directory.
- M5b fixture: `fixtures/specs/sales-bar.process.json`. End-to-end CLI
  smoke run reproduces the M1/M2/M3 goldens byte-equal.
- M6 (`pipe-duckdb`): new sibling package providing
  `query_to_dataset(db_path, sql, schema)` that runs SQL against DuckDB
  (`:memory:` or a path) and decodes the result into a `pipe.Dataset`.
  Schema inference is intentionally deferred — the caller passes an
  explicit `DataSchema`. A second helper `read_csv_sql(path, schema)`
  composes a `SELECT … FROM read_csv(...)` query so tests can swap the
  pure-MoonBit pipeline for a SQL-backed one. Native-only target gates
  keep the `js` / `wasm-gc` builds free of the duckdb dependency.
- M6 deps: adds `f4ah6o/duckdb@0.6.3`. CI installs `libduckdb` via
  `brew` (macOS) / DuckDB release zip (Ubuntu).
- M6 fixture: golden test reuses `fixtures/datasets/sales.csv` and
  matches the M1 dataset JSON byte-equal.
- M6.5: manifest loader now recognizes `"kind": "duckdb"` sources
  (`{"db": "...", "sql": "...", "schema": {...}}`).
  `build_process_from_json` takes a `duckdb_runner` injection so
  `vizprocess` stays target-agnostic; the CLI passes a
  `pipe-duckdb`-backed runner. `:memory:` is recognized verbatim;
  other db paths are resolved relative to the manifest directory.
- M6.5 fixture: `fixtures/specs/sales-bar-duckdb.process.json`. CLI
  smoke run reproduces the M3 SVG byte-equal via DuckDB SQL.
- Note: paths inside SQL strings (e.g. `read_csv('...')`) resolve
  against the CLI's working directory, not the manifest directory —
  unlike `csv-file` paths which use the manifest directory. Document
  per-fixture or migrate to absolute paths.
- API change: `pub` structs and enums in `pipe` and `viz` are now `pub(all)`
  so external consumers (notably `vizprocess`) can construct and destructure
  them. Functions remain `pub`.
- M4 (`vizprocess`): manifest types (`VizProcess`, `DatasetNode`,
  `ChartNode`, `ArtifactNode`, `ArtifactKind`, `OutputTarget`), a
  `pipe.Dataset → viz.VizDataset` adapter (`dataset_to_viz`), and
  `run_process` orchestrating dataset pipelines, chart compilation, and
  artifact rendering. Diagnostics from every layer are aggregated and
  sorted by `(source, code, target)`. Artifacts (`AkSvg`,
  `AkRenderModelJson`, `AkDatasetJson`) currently land in memory only;
  file / stdout output arrives in M5. Golden white-box test runs the full
  pipeline → chart → SVG/JSON path and matches every M1–M3 golden.
