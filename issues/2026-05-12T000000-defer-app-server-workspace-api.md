# Defer App Server workspace/API for browser-local Cloudflare preview v1

## Status

Open

## Context

The v1 Cloudflare app is intentionally a browser-local artifact workspace. CSV imports, seeded fixtures, manifest persistence, validation, rendering, preview, and export run in the browser using OPFS/localStorage plus the MoonBit JS/WASM build. This keeps local CSV contents in the user's browser and stays inside Workers Free Plan-friendly static asset plus Worker API usage.

The Worker keeps `/api/editor/validate` and `/api/editor/render` for compatibility and smoke tests, but these routes accept resolved manifests only. They do not own sessions, uploaded CSVs, artifact bundles, or shared process workspaces.

## Deferred Work

- Server-owned process workspace sessions.
- App Server APIs for saved manifests, datasets, artifact history, approvals, or collaboration.
- Cloudflare storage bindings such as KV, D1, R2, Queues, Workflows, or AI.
- Production custom-domain rollout beyond the existing preview `workers.dev` deployment path.

## Acceptance Notes

Future App Server work should start from a separate issue and explicitly justify any paid-risk Cloudflare resource. Until then, the preview app should continue to preserve browser-local data handling as the default path.
