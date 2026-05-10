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

## Process Workspace Session Store

The durable process workspace is a top-level App Server workspace session
snapshot, not browser-tab state. Its required sections are `workspace`,
`manifest`, `resolvedSources`, `nodes`, `attachments`, `selection`, `preview`,
`diagnostics`, and `lastAction`.

- `workspace` identifies the durable workspace, including version and update
  time.
- `manifest` stores the raw manifest source plus the last parse / validation
  status.
- `resolvedSources` stores source summaries after manifest resolution.
- `nodes` stores flat dataset / chart / artifact summaries for client
  navigation.
- `attachments` stores stable `path`, `size`, and `mediaType` metadata.
- `selection` stores the current node or attachment selection.
- `preview` stores a resumable output reference for the last render preview.
- `diagnostics` stores the current validation and execution diagnostics.
- `lastAction` records the last state transition applied to the session.

After manifest parse and validation, a valid manifest replaces
`resolvedSources` and `nodes` from the runnable process snapshot and clears
manifest diagnostics. An invalid manifest keeps durable attachments, selection,
and preview output references, but clears derived topology so clients do not
resume against stale nodes.

The browser demo's OPFS workspace is a reference implementation of this shape.
It is not the target architecture or the source of truth. Shared clients such
as VS Code and browser sessions should resume through the App Server workspace
session contract.

## Determinism

All artifact output is deterministic:

- JSON keys sorted alphabetically; floats fixed to 4 decimals.
- SVG element IDs derived from a path-stable hash, never random.
- Diagnostics sorted by `(code, target)`.

## Milestones

See [the project plan](../README.md) and `CHANGELOG.md`. M0 ships only the
package skeleton; M1 introduces the first runnable pipeline.
