///|
/// Durable workspace identity owned by the App Server workspace session.
pub(all) struct WorkspaceSection {
  id : String
  title : String
  version : Int
  updated_at : String
} derive(Eq, Show)

///|
pub(all) enum ManifestStatus {
  MsUnparsed
  MsValid
  MsInvalid
} derive(Eq, Show)

///|
/// The raw manifest text and the last parse / validation status. The manifest
/// source stays in the session so every client resumes from the same input.
pub(all) struct ManifestSection {
  source : String
  status : ManifestStatus
  process_id : String?
  error : String?
} derive(Eq, Show)

///|
/// A source after manifest resolution. The `reference` is intentionally stable:
/// file-like sources use their manifest path, inline sources use their dataset
/// id, and adapters can map it to a backend-specific object later.
pub(all) struct ResolvedSourceSummary {
  dataset_id : String
  reference : String
  rows : Int
} derive(Eq, Show)

///|
pub(all) enum NodeKind {
  NkDataset
  NkChart
  NkArtifact
} derive(Eq, Show)

///|
/// Flat node projection for process browsers and shared clients.
pub(all) struct ProcessNodeSummary {
  id : String
  kind : NodeKind
  input_id : String?
  output_kind : String?
} derive(Eq, Show)

///|
/// Stable attachment contract. `path` is the durable workspace path, not a
/// browser object URL or OPFS implementation detail.
pub(all) struct AttachmentSummary {
  path : String
  size : Int64
  media_type : String
} derive(Eq, Show)

///|
pub(all) struct SelectionSection {
  node_id : String?
  attachment_path : String?
} derive(Eq, Show)

///|
/// Resumable reference to the last render output. Content can live in any
/// backend as long as the reference can be dereferenced by the session owner.
pub(all) struct PreviewOutputReference {
  artifact_id : String
  kind : ArtifactKind
  reference : String
  resume_key : String
  media_type : String
} derive(Eq, Show)

///|
pub(all) struct PreviewSection {
  output : PreviewOutputReference?
} derive(Eq, Show)

///|
pub(all) struct LastActionSection {
  name : String
  at : String
} derive(Eq, Show)

///|
/// Top-level durable process workspace snapshot. OPFS can implement this
/// shape locally, but the target architecture treats the App Server workspace
/// session as the source of truth.
pub(all) struct ProcessWorkspaceSnapshot {
  workspace : WorkspaceSection
  manifest : ManifestSection
  resolved_sources : Array[ResolvedSourceSummary]
  nodes : Array[ProcessNodeSummary]
  attachments : Array[AttachmentSummary]
  selection : SelectionSection
  preview : PreviewSection
  diagnostics : Array[Diagnostic]
  last_action : LastActionSection?
} derive(Eq, Show)

///|
pub fn ProcessWorkspaceSnapshot::empty(
  workspace_id : String,
  title : String,
  now : String,
) -> ProcessWorkspaceSnapshot {
  {
    workspace: { id: workspace_id, title, version: 1, updated_at: now },
    manifest: { source: "", status: MsUnparsed, process_id: None, error: None },
    resolved_sources: [],
    nodes: [],
    attachments: [],
    selection: { node_id: None, attachment_path: None },
    preview: { output: None },
    diagnostics: [],
    last_action: None,
  }
}

///|
/// Apply manifest parse / validation output to the session. A valid manifest
/// replaces the derived source and node projections; an invalid manifest keeps
/// durable attachments, selection, and preview, but clears derived projections
/// so clients do not act on stale process topology.
pub fn ProcessWorkspaceSnapshot::refresh_manifest(
  self : ProcessWorkspaceSnapshot,
  source : String,
  result : Result[VizProcess, String],
  now : String,
) -> ProcessWorkspaceSnapshot {
  match result {
    Ok(process) => {
      let nodes = node_summaries(process)
      let resolved_sources = resolved_source_summaries(process)
      {
        ..self,
        workspace: {
          ..self.workspace,
          version: self.workspace.version + 1,
          updated_at: now,
        },
        manifest: {
          source,
          status: MsValid,
          process_id: Some(process.id),
          error: None,
        },
        resolved_sources,
        nodes,
        diagnostics: [],
        last_action: Some({ name: "manifest.refresh", at: now }),
      }
    }
    Err(message) =>
      {
        ..self,
        workspace: {
          ..self.workspace,
          version: self.workspace.version + 1,
          updated_at: now,
        },
        manifest: {
          source,
          status: MsInvalid,
          process_id: None,
          error: Some(message),
        },
        resolved_sources: [],
        nodes: [],
        diagnostics: [
          Diagnostic::process_error(
            "MANIFEST_INVALID", "$", "manifest parse or validation failed",
          ),
        ],
        last_action: Some({ name: "manifest.refresh", at: now }),
      }
  }
}

///|
pub fn ProcessWorkspaceSnapshot::set_preview_output(
  self : ProcessWorkspaceSnapshot,
  output : PreviewOutputReference,
  now : String,
) -> ProcessWorkspaceSnapshot {
  {
    ..self,
    workspace: {
      ..self.workspace,
      version: self.workspace.version + 1,
      updated_at: now,
    },
    preview: { output: Some(output) },
    last_action: Some({ name: "preview.output.set", at: now }),
  }
}

///|
pub fn node_summaries(process : VizProcess) -> Array[ProcessNodeSummary] {
  let nodes : Array[ProcessNodeSummary] = []
  for dataset in process.datasets {
    nodes.push({
      id: dataset.id,
      kind: NkDataset,
      input_id: None,
      output_kind: Some("dataset"),
    })
  }
  for chart in process.charts {
    nodes.push({
      id: chart.id,
      kind: NkChart,
      input_id: Some(chart.dataset_id),
      output_kind: Some("chart"),
    })
  }
  for artifact in process.artifacts {
    nodes.push({
      id: artifact.id,
      kind: NkArtifact,
      input_id: Some(artifact.chart_id),
      output_kind: Some(artifact_kind_name(artifact.kind)),
    })
  }
  nodes
}

///|
pub fn resolved_source_summaries(
  process : VizProcess,
) -> Array[ResolvedSourceSummary] {
  let sources : Array[ResolvedSourceSummary] = []
  for dataset in process.datasets {
    sources.push({
      dataset_id: dataset.id,
      reference: "dataset:" + dataset.id,
      rows: dataset.source.n_rows,
    })
  }
  sources
}

///|
pub fn artifact_kind_name(kind : ArtifactKind) -> String {
  match kind {
    AkSvg => "svg"
    AkRenderModelJson => "render-model-json"
    AkDatasetJson => "dataset-json"
  }
}

///|
pub fn artifact_media_type(kind : ArtifactKind) -> String {
  match kind {
    AkSvg => "image/svg+xml"
    AkRenderModelJson | AkDatasetJson => "application/json"
  }
}
