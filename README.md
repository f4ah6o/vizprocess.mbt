# vizprocess.mbt

MoonBit monorepo for reproducible data visualization processes.

## Packages

- `pipe` — data pipeline (sources, transforms, validation, sinks)
- `viz` — chart spec, encoding, render model, renderers
- `vizprocess` — orchestration of pipe + viz into a reproducible process
- `cli` — `vizprocess` command-line interface

## Status

Experimental. M0 skeleton.

## Quick Start

```bash
moon check
moon test
moon run packages/cli -- process run examples/simple-csv-bar/process.json
```

## Browser demo / Worker

`examples/browser-demo/` now exposes two browser surfaces:

- `/` keeps the original manifest textarea demo
- `/editor/` adds a graph/inspector editor with OPFS-backed local workspaces and WebMCP registration

The Cloudflare Worker also exposes experimental internal browser-editor APIs:

- `POST /api/editor/validate`
- `POST /api/editor/render`

These APIs only accept browser-resolved manifests. The Worker does not read
OPFS or browser-local files directly.

## Architecture

See [docs/architecture.md](docs/architecture.md).

## Concepts

```
DataSource → pipe → Dataset → viz → RenderModel → vizprocess → SVG / HTML / JSON artifact
```

## License

Apache-2.0
