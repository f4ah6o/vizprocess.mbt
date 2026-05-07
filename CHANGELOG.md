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
