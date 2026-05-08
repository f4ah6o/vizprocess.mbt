# Define Codex App Server process workspace contract for vizprocess.mbt

Created: 2026-05-09
Model: GPT-5 Codex unknown

## Background

`vizprocess.mbt` currently exposes a browser demo with:

- manifest JSON editing
- dataset/chart/artifact manipulation
- validate/render Worker routes
- attachment import
- OPFS-backed local workspaces
- browser-side WebMCP tools

That is useful as a local prototype, but it keeps the application model tied to
browser-local persistence and source resolution. The target architecture for
Codex integration should instead be a durable App Server-managed workspace that
clients can reopen, inspect, mutate, and export.

As of 2026-05-09, Codex App Server is the preferred rich-client integration
surface for Codex. It supports resumable sessions, server notifications,
approval requests, apps/connectors, and tool-based mutation. `vizprocess.mbt`
needs an explicit `process workspace` contract for that model.

## Proposal

Redefine the current editor as an App Server-oriented process workspace.

- Move the conceptual source of truth from browser-local OPFS to an App
  Server-managed workspace/session model.
- Treat OPFS as a reference implementation, not as the target architecture.
- Model manifest source, resolved sources, attachments, diagnostics, preview
  outputs, and selection as durable session state.
- Define validate/render/export/import flows as App Server tools rather than as
  browser-only helper actions.
- Target a future VS Code graph/process editor implemented from a shared repo.

The repo-local responsibility is to define the domain workspace contract and its
approval boundaries. The future shared repo will own the reusable client, but
this issue itself is only about defining the contract and is not blocked on that
repo existing.

## Session Snapshot

The vizprocess session snapshot should use a shape equivalent to:

```json
{
  "workspace": {
    "id": "workspace-20260509",
    "name": "sales dashboard"
  },
  "manifest": {
    "source": "{...}",
    "parsed": {}
  },
  "resolvedSources": [
    { "kind": "csv-file", "path": "sales.csv", "status": "resolved" }
  ],
  "nodes": {
    "datasets": [
      { "id": "sales", "sourceKind": "csv-file", "label": "Sales CSV" }
    ],
    "charts": [
      { "id": "sales-bar", "chartKind": "bar", "datasetId": "sales" }
    ],
    "artifacts": [
      { "id": "artifact-svg", "artifactKind": "svg", "chartId": "sales-bar" }
    ]
  },
  "attachments": [
    { "path": "files/sales.csv", "size": 2048, "mediaType": "text/csv" }
  ],
  "selection": {
    "kind": "dataset",
    "id": "sales",
    "panel": "inspector"
  },
  "preview": {
    "activeArtifactId": "artifact-svg",
    "renderMode": "svg",
    "availableArtifactIds": ["artifact-svg"],
    "resumeKey": "artifact-svg:svg",
    "outputs": [
      { "artifactId": "artifact-svg", "kind": "svg", "previewRef": "artifact://artifact-svg" }
    ]
  },
  "diagnostics": [],
  "lastAction": {
    "kind": "render",
    "completedAt": "2026-05-09T00:00:00Z"
  }
}
```

Required top-level sections are:

- `workspace`
- `manifest`
- `resolvedSources`
- `nodes`
- `attachments`
- `selection`
- `preview`
- `diagnostics`
- `lastAction`

`manifest.parsed` is part of the contract and represents the current parsed
manifest object derived from `manifest.source`.

## Read-only Tools

The read-only App Server tools should cover at least:

- `get_session_snapshot() -> ProcessWorkspaceSnapshot`
- `get_manifest_source() -> { source: string }`
- `get_resolved_sources() -> { resolvedSources: ResolvedSourceSummary[] }`
- `list_attachments() -> { attachments: AttachmentSummary[] }`
- `list_datasets() -> { datasets: DatasetSummary[] }`
- `list_charts() -> { charts: ChartSummary[] }`
- `validate_current_process() -> { diagnostics: Diagnostic[], normalizedManifest?: object }`
- `render_preview() -> { outputs: PreviewOutputSummary[], diagnostics: Diagnostic[] }`
- `get_diagnostics() -> { diagnostics: Diagnostic[] }`
- `list_artifacts() -> { artifacts: ArtifactSummary[] }`

These operations should not require approval.

`list_datasets`, `list_charts`, and `list_artifacts` are flat projections of
`nodes.datasets`, `nodes.charts`, and `nodes.artifacts` from the session
snapshot.

The minimum summary shapes are:

- `ResolvedSourceSummary = { kind: string, path: string, status: string }`
- `AttachmentSummary = { path: string, size: number, mediaType: string }`
- `DatasetSummary = { id: string, sourceKind: string, label: string }`
- `ChartSummary = { id: string, chartKind: string, datasetId: string }`
- `ArtifactSummary = { id: string, artifactKind: string, chartId?: string }`
- `PreviewOutputSummary = { artifactId: string, kind: string, previewRef: string }`
- `SelectionState = { kind: string, id: string, panel?: string }`

## Mutating Tools

The mutating App Server tools should cover at least:

- `replace_manifest_source(source) -> { diagnostics: Diagnostic[], snapshot: ProcessWorkspaceSnapshot }`
- `upsert_dataset_node(node) -> { nodeId: string, snapshot: ProcessWorkspaceSnapshot }`
- `upsert_chart_node(node) -> { nodeId: string, snapshot: ProcessWorkspaceSnapshot }`
- `upsert_artifact_node(node) -> { nodeId: string, snapshot: ProcessWorkspaceSnapshot }`
- `set_selected_node(kind, id, panel?) -> { selection: SelectionState, snapshot: ProcessWorkspaceSnapshot }`
- `import_attachment(path, bytesBase64, mediaType) -> { attachment: AttachmentSummary, snapshot: ProcessWorkspaceSnapshot }`
- `remove_attachment(path) -> { approvalRequired: true, proposal: ApprovalProposal } | { removed: true, snapshot: ProcessWorkspaceSnapshot }`
- `export_process_bundle(format, destination?) -> { artifactRef: string, snapshot: ProcessWorkspaceSnapshot } | { approvalRequired: true, proposal: ApprovalProposal }`
- `validate_and_persist() -> { normalizedManifest?: object, diagnostics: Diagnostic[], snapshot: ProcessWorkspaceSnapshot }`
- `render_and_persist() -> { outputs: PreviewOutputSummary[], diagnostics: Diagnostic[], snapshot: ProcessWorkspaceSnapshot }`

These must be expressed as durable workspace mutations rather than browser tab
actions.

Every approval-required action is also a mutating tool. The approval section
below narrows which mutating tools must stop for confirmation.

## Approval-required Actions

Approval policy should follow the shared cross-repo rule:

- `remove_attachment` is approval-required before destructive delete, and once
  approved returns the normal `{ removed: true, snapshot }` mutation result
- `export_process_bundle` is approval-required only when it writes durable
  artifacts outside the session; in-session export returns the normal
  `{ artifactRef, snapshot }` result
- future external connector or file-system writes are approval-required
- inspect / validate / render-preview / read actions are not approval-required

If future source resolution touches external systems, those boundaries should
also be approval-gated.

## Import / Export Artifact

The contract should define these logical envelopes:

- manifest source bundle
  - JSON object with `workspace`, `manifest`, `selection`
- attachment bundle
  - JSON manifest + binary payloads keyed by stable attachment path
- rendered artifact bundle
  - JSON manifest + referenced artifact payloads
- diagnostic report bundle
  - JSON object with `diagnostics`, `lastAction`, `workspace`

The allowed `format` values for `export_process_bundle(format, destination?)`
are fixed to:

- `manifest-source`
- `attachments`
- `rendered-artifacts`
- `diagnostic-report`

It should also define how preview outputs are referenced in session state so the
future shared repo can render them consistently.

`ApprovalProposal` should carry at least:

- `kind`
- `workspaceId`
- `summary`
- `targetPath?`
- `format?`
- `destination?`
- `estimatedEffects`

## Diagnostic Shape

The App Server contract should expose a structured diagnostic shape with:

- code
- severity
- target
- message
- hint
- context

The shape should cover manifest parse failures, source resolution failures,
validation failures, render failures, and attachment-related failures.

`target` is a string path that points to a stable location in one of:

- `manifest`
- `resolvedSources`
- `nodes.datasets`
- `nodes.charts`
- `nodes.artifacts`
- `attachments`

## Selection / Focus State

The contract should expose:

- selected node kind
- selected node id
- active panel or inspector context when needed

This allows App Server clients to restore graph/process editing context across
sessions.

## Preview / Navigation State

The contract should expose preview state as session state, not only as browser
DOM.

It should support:

- current preview artifact id
- current render mode
- navigation among available artifact outputs
- state needed to reopen the same preview after resume

## Shared Repo Dependency

That future shared repo is expected to own:

- the reusable Codex App Server client
- the VS Code extension shell
- shared approval UX
- cross-repo session restoration and notification handling

`vizprocess.mbt` remains responsible for the process-workspace contract,
including source resolution, attachment lifecycle, artifact preview semantics,
and diagnostics. This issue itself is scoped to contract definition only and is
not blocked on the shared repo being present yet.

## Acceptance Criteria

- [ ] The editor surface is specified as an App Server `process workspace`
      contract rather than an OPFS-first browser demo.
- [ ] A concrete session snapshot shape is defined with named top-level fields.
- [ ] Read-only tools and mutating tools are listed with input/output
      expectations, not just names.
- [ ] The issue explicitly states that approval-required actions are a subset of
      mutating tools.
- [ ] Import/export envelopes, diagnostic shape, selection/focus state, and
      preview/navigation state are all defined as required parts of the
      contract.
- [ ] OPFS is explicitly demoted to a reference implementation.
- [ ] The issue is scoped to contract definition and is not blocked on a shared
      repo already existing.

## Non-goals

- Implementing the shared repo in this issue
- Implementing a VS Code extension in this repo
- Treating the current OPFS demo as the target architecture
- Solving every future storage backend in the first contract draft

## Rationale

`vizprocess.mbt` already has most of the domain ingredients needed by an
agent-friendly application: structured manifest editing, source resolution,
attachment handling, diagnostics, and render artifacts. The missing piece is a
durable workspace contract that a real App Server client can own.

Writing that contract now prevents the future shared repo from inheriting
browser-local assumptions and makes it possible to build a VS Code editor that
can reopen the same process session, inspect nodes, validate, render, and
export without depending on OPFS.
