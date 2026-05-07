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
