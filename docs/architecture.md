# Architecture

`vizprocess.mbt` is a multi-package MoonBit project that treats data
visualization as a reproducible process from a typed data source through to a
visual artifact.

## Packages

- `pipe` — data sources, datasets, transforms, validation, sinks.
- `viz` — chart specs, encoding, scales, render model, renderers (SVG / HTML / JSON).
- `vizprocess` — orchestrates `pipe` and `viz` against a manifest, producing
  artifacts and diagnostics.
- `cli` — command-line entry point.

## Dependency direction

```
cli → vizprocess → pipe
                 → viz
```

`pipe` does not depend on `viz`. `viz` does not depend on `pipe`. They are
joined only via `vizprocess`, which adapts `pipe::Dataset` to the
`DatasetView` trait expected by `viz`.

## Data flow

```
DataSource
  → pipe.Pipeline
  → Dataset
  → viz.ChartSpec + Encoding
  → RenderModel
  → vizprocess.Artifact
  → File / Stdout / Browser / OPFS
```

## Determinism

All artifact output is deterministic:

- JSON keys sorted alphabetically; floats fixed to 4 decimals.
- SVG element IDs derived from a path-stable hash, never random.
- Diagnostics sorted by `(code, target)`.

## Milestones

See [the project plan](../README.md) and `CHANGELOG.md`. M0 ships only the
package skeleton; M1 introduces the first runnable pipeline.
