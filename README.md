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

## Architecture

See [docs/architecture.md](docs/architecture.md).

## Concepts

```
DataSource → pipe → Dataset → viz → RenderModel → vizprocess → SVG / HTML / JSON artifact
```

## License

Apache-2.0
