# Define Codex App Server process workspace contract for vizprocess.mbt

- Status: active
- Disposition: proposed
- GitHub Issue: none
- GitHub URL: none
- GitHub State: none
- Created: 2026-05-09T09:32:00Z
- Closed: none
- Author: Codex
- Labels: architecture, app-server, workspace, process
- Assignees: none
- Parent: none
- Depends on: none
- Blocks: future shared App Server client implementation
- Superseded by: none
- Comments: 0
- Source: created in repo

Created: 2026-05-09
Model: GPT-5 Codex unknown

## Summary

Define `vizprocess.mbt` の durable `process workspace` contract for Codex App
Server so a future reusable client can reopen sessions, inspect nodes, validate,
render, and export without depending on OPFS.

## Why

`vizprocess.mbt` currently exposes a browser demo with:

- manifest JSON editing
- dataset/chart/artifact manipulation
- validate/render Worker routes
- attachment import
- OPFS-backed local workspaces
- browser-side WebMCP tools

これは local prototype としては useful だが、application model が browser-local
persistence と source resolution に強く結び付いている。Codex App Server 向け
integration では、clients が reopen / inspect / mutate / export できる durable
session model が必要になる。

## Scope

- editor を App Server-oriented process workspace として再定義する
- OPFS は target architecture ではなく reference implementation として扱う
- manifest source、resolved sources、attachments、diagnostics、preview outputs、
  selection を durable session state として定義する
- validate / render / export / import を App Server tools として定義する

## Repo-local Source Of Truth

- repo-local issue を source of truth にする
- 今回は GitHub issue へ同期しない
- shared repo は consumer であり、この issue の blocker ではない

## Cross-repo Conventions

この issue は `domainprocessschema.mbt` / `papyr.mbt` / shared repo と共通で次を前提にする。

- tool naming は `verb_object` 形式
- read-only tool は snapshot projection か read result を返す
- mutating tool は差分結果だけでなく `snapshot` も返す
- approval が必要な tool は `approvalRequired: true` と proposal payload を返す
- diagnostic shape は `code / severity / target / message / hint / context`
- resumable session / notification / approval request を共通前提にする

## Shared Vocabulary

shared repo へ渡す共通 vocabulary は次。

- session id / snapshot envelope
- approval proposal / approval result
- notification event kind
- structured diagnostics

repo 固有の source resolution、artifact preview semantics、attachment lifecycle は
`vizprocess.mbt` 側に残す。

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

Every approval-required action is also a mutating tool.

## Approval-required Actions

Approval policy should follow the shared cross-repo rule:

- `remove_attachment` is approval-required before destructive delete
- `export_process_bundle` is approval-required only when it writes durable
  artifacts outside the session
- future external connector or file-system writes are approval-required
- inspect / validate / render / read actions are not approval-required

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

Allowed `format` values for `export_process_bundle(format, destination?)` are:

- `manifest-source`
- `attachments`
- `rendered-artifacts`
- `diagnostic-report`

## Diagnostic Shape

The App Server contract should expose a structured diagnostic shape with:

- `code`
- `severity`
- `target`
- `message`
- `hint`
- `context`

## Selection / Focus State

The contract should expose:

- selected node kind
- selected node id
- active panel or inspector context when needed

## Preview / Navigation State

The contract should expose preview state as session state, not only as browser DOM.

- current preview artifact id
- current render mode
- navigation among available artifact outputs
- state needed to reopen the same preview after resume

## Shared Repo Relationship

shared repo は reusable client/core、shared approval UX、cross-repo session
restoration and notification handling を持つ予定だが、この issue 自体は contract
definition のみを扱い、shared repo の存在を blocker にしない。

## Acceptance Criteria

- [ ] The editor surface is specified as an App Server `process workspace`
      contract rather than an OPFS-first browser demo
- [ ] A concrete session snapshot shape is defined with named top-level fields
- [ ] Read-only tools and mutating tools are listed with input/output
      expectations
- [ ] approval-required actions are a subset of mutating tools だと明記されている
- [ ] import/export envelopes, diagnostic shape, selection/focus state, and
      preview/navigation state are defined
- [ ] OPFS is explicitly demoted to a reference implementation
- [ ] The issue is scoped to contract definition and is not blocked on the
      shared repo already existing

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
