# Codex App Server 向け process workspace 契約を定義する

- Status: closed
- Disposition: implemented
- GitHub Issue: none
- GitHub URL: none
- GitHub State: none
- Created: 2026-05-09T09:32:00Z
- Closed: 2026-05-10
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
Model: GPT-5 Codex (version unknown)

## Summary

`vizprocess.mbt` の browser demo を、Codex App Server が reopen / notify /
request approval できる durable `process workspace` contract として定義する。
将来の reusable client は OPFS に依存せず、同じ session を reopen して node の
inspect、validate、render、export を継続できる状態を目指す。

## Why

`vizprocess.mbt` にはすでに次の surface がある。

- manifest JSON editing
- dataset / chart / artifact manipulation
- validate / render Worker routes
- attachment import
- OPFS-backed local workspaces
- browser-side WebMCP tools

これは local prototype としては十分だが、application model が browser-local
persistence と source resolution に強く結び付いている。Codex App Server 向けの
integration では、client が reopen / inspect / mutate / export できる durable
session model を先に契約として定義する必要がある。

## Scope

- editor を App Server 向け process workspace として再定義する
- OPFS は target architecture ではなく reference implementation として扱う
- manifest source、resolved sources、attachments、diagnostics、preview outputs、
  selection を durable session state として定義する
- validate / render / export / import を App Server tool として定義する

## Repo-local Source Of Truth

- repo-local issue を source of truth にする
- 今回は GitHub issue へ同期しない
- shared repo は consumer であり、この issue の blocker ではない

## Cross-repo Conventions

この issue は `domainprocessschema.mbt` / `papyr.mbt` / shared repo と共通で次を
前提にする。

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
`vizprocess.mbt` 側に残す。shared repo の正式名称は現時点では
`codex-app-server-shared` を仮ではなく作業名として固定する。

## Session Snapshot

process workspace snapshot は少なくとも次の shape を持つ。

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
    "kind": "render_and_persist",
    "completedAt": "2026-05-09T00:00:00Z"
  }
}
```

必須の top-level section は次。

- `workspace`
- `manifest`
- `resolvedSources`
- `nodes`
- `attachments`
- `selection`
- `preview`
- `diagnostics`
- `lastAction`

`preview.resumeKey` は `"{artifactId}:{renderMode}"` 形式の stable key とし、
同じ artifact と render mode を reopen した時に同じ key を返す。

## Read-only Tools

read-only tool は少なくとも次を含む。

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

これらは approval 不要とする。

## Mutating Tools

mutating tool は少なくとも次を含む。

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

approval-required action はすべて mutating tool の subset とする。

## Approval-required Actions

approval 方針は次。

- `remove_attachment` は destructive delete の前に approval-required
- `export_process_bundle` は `destination` が unset の時は session 内 export と
  みなし approval 不要、`destination` が set の時は session 外 durable write と
  みなし approval-required
- future external connector / file-system write は approval-required
- inspect / validate / render-preview / read は approval 不要

## Attachment Lifecycle

attachment persistence backend は OPFS 固定にしない。初期 demo では OPFS を使っても、
contract 上は次を差し替え可能な boundary として扱う。

- browser-local OPFS
- in-memory temporary store
- remote object store

`import_attachment` と `remove_attachment` は backend 固有 API ではなく、stable な
attachment path と media type を contract の surface とする。

## Import / Export Artifact

artifact contract は少なくとも次の logical envelope を持つ。

- manifest source bundle
  - JSON object with `workspace`, `manifest`, `selection`
- attachment bundle
  - JSON manifest + binary payloads keyed by stable attachment path
- rendered artifact bundle
  - JSON manifest + referenced artifact payloads
- diagnostic report bundle
  - JSON object with `diagnostics`, `lastAction`, `workspace`

`export_process_bundle(format, destination?)` の `format` は次に固定する。

- `manifest-source`
- `attachments`
- `rendered-artifacts`
- `diagnostic-report`

## Diagnostic Shape

diagnostic は少なくとも次の field を持つ structured shape とする。

- `code`
- `severity`
- `target`
- `message`
- `hint`
- `context`

manifest parse、source resolution、validation、render、attachment failure を同じ shape
で報告する。

## Selection / Focus State

session resume 用に次を保持する。

- selected node kind
- selected node id
- active panel or inspector context

## Preview / Navigation State

preview state は browser DOM ではなく session state として持つ。

- current preview artifact id
- current render mode
- navigation among available artifact outputs
- reopen 後に同じ preview を復元する state

## Shared Repo Relationship

shared repo `codex-app-server-shared` は reusable client/core、shared approval UX、
cross-repo session restoration、notification handling を持つ予定だが、この issue
自体は contract definition のみを扱い、shared repo の存在を blocker にしない。

## Acceptance Criteria

- [x] editor surface が OPFS-first browser demo ではなく App Server 向け
      `process workspace` contract として定義されている
- [x] session snapshot shape と `resumeKey` 形式が named field として定義されている
- [x] read-only tool と mutating tool が input / output expectation 付きで定義
      されている
- [x] approval-required action が mutating tool の subset であり、`destination`
      による export 判定主体が明記されている
- [x] attachment lifecycle、import/export envelope、diagnostic shape、
      selection/focus state、preview/navigation state が定義されている
- [x] OPFS が reference implementation として明示的に格下げされている
- [x] shared repo relationship が `codex-app-server-shared` の名前付きで説明されている

## Resolution

Child PRs #3、#4、#5 で `packages/vizprocess/session_store.mbt` と
`packages/vizprocess/app_server_tools.mbt` に durable process workspace snapshot、
read-only / mutating / approval-required tool envelope、attachment import/remove
approval、external export approval、manifest / attachment / rendered artifact /
diagnostic report bundle を追加した。

Closeout では parent contract の `resumeKey` を concrete session field と JSON
envelope に追加し、`docs/architecture.md` に `<artifact-id>:<artifact-kind>` 形式を
明記した。OPFS は引き続き browser demo の reference implementation であり、App
Server workspace session を source of truth とする。

## Non-goals

- shared repo 自体をこの issue で実装すること
- VS Code extension をこの repo で実装すること
- current OPFS demo を target architecture として固定すること
- すべての将来 backend を初回契約で解き切ること

## Rationale

`vizprocess.mbt` は structured manifest editing、source resolution、attachment
handling、diagnostics、render artifacts をすでに持っている。不足しているのは
durable workspace contract だけであり、ここを先に定義すれば将来の App Server
client が browser-local 前提を引きずらずに same session を reopen できる。
