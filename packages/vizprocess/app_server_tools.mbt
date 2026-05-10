///|
pub(all) enum ProcessToolAccess {
  PtaReadOnly
  PtaMutating
  PtaApprovalRequired
} derive(Eq, Show)

///|
pub(all) struct ProcessToolCall {
  name : String
  access : ProcessToolAccess
} derive(Eq, Show)

///|
pub(all) struct ManifestSourceReplaceInput {
  source : String
  now : String
} derive(Eq, Show)

///|
pub(all) struct ProcessNodeUpsertInput {
  node : ProcessNodeSummary
  now : String
} derive(Eq, Show)

///|
pub(all) struct NodeSelectionInput {
  node_id : String?
  attachment_path : String?
  now : String
} derive(Eq, Show)

///|
pub(all) struct AttachmentImportInput {
  attachment : AttachmentSummary
  now : String
} derive(Eq, Show)

///|
pub(all) struct AttachmentRemoveInput {
  path : String
  reason : String
  now : String
} derive(Eq, Show)

///|
pub(all) struct ExternalExportInput {
  format : ExportBundleFormat
  destination : String
  reason : String
  now : String
} derive(Eq, Show)

///|
pub(all) enum ExportBundleFormat {
  EbfManifestSource
  EbfAttachments
  EbfRenderedArtifacts
  EbfDiagnosticReport
} derive(Eq, Show)

///|
pub(all) struct ManifestValidationInput {
  now : String
  csv_reader : (String) -> Result[String, String]
  duckdb_runner : (String, String, @pipe.DataSchema) -> Result[
    @pipe.Dataset,
    String,
  ]
}

///|
pub(all) struct RenderPreviewInput {
  artifact_id : String?
  now : String
  csv_reader : (String) -> Result[String, String]
  duckdb_runner : (String, String, @pipe.DataSchema) -> Result[
    @pipe.Dataset,
    String,
  ]
}

///|
pub(all) struct ProcessToolApprovalProposal {
  id : String
  action : String
  description : String
  created_at : String
  workspace_id : String
  path : String?
  size : Int64?
  effects : Array[String]
  format : ExportBundleFormat?
  destination : String?
  estimated_effects : Array[String]
} derive(Eq, Show)

///|
pub(all) struct ProcessToolPreviewOutput {
  reference : PreviewOutputReference
  content : String
  content_metadata : PreviewContentMetadata
} derive(Eq, Show)

///|
pub(all) struct PreviewContentMetadata {
  bytes : Int
  media_type : String
} derive(Eq, Show)

///|
pub(all) struct ExportPayloadReference {
  id : String
  kind : String
  reference : String
  media_type : String
  size : Int64?
} derive(Eq, Show)

///|
pub(all) struct ExportBundleEnvelope {
  schema : String
  format : ExportBundleFormat
  workspace_id : String
  created_at : String
  payload_refs : Array[ExportPayloadReference]
  manifest_source : String?
  diagnostics : Array[Diagnostic]
} derive(Eq, Show)

///|
pub fn ExportBundleEnvelope::to_json(self : ExportBundleEnvelope) -> String {
  let buf = StringBuilder::new()
  write_export_bundle_json(buf, self)
  buf.to_string()
}

///|
pub(all) struct ProcessToolEnvelope {
  tool : ProcessToolCall
  diagnostics : Array[Diagnostic]
  snapshot : ProcessWorkspaceSnapshot
  approval : ProcessToolApprovalProposal?
  preview : ProcessToolPreviewOutput?
} derive(Show)

///|
pub fn ProcessToolEnvelope::to_json(self : ProcessToolEnvelope) -> String {
  let buf = StringBuilder::new()
  buf.write_string("{\"access\":\"")
  buf.write_string(process_tool_access_name(self.tool.access))
  buf.write_string("\",\"approval\":")
  write_approval_json(buf, self.approval)
  buf.write_string(",\"diagnostics\":")
  write_diagnostics_json(buf, self.diagnostics)
  buf.write_string(",\"preview\":")
  write_preview_json(buf, self.preview)
  buf.write_string(",\"snapshot\":")
  write_snapshot_json(buf, self.snapshot)
  buf.write_string(",\"tool\":\"")
  write_json_escaped(buf, self.tool.name)
  buf.write_string("\"}")
  buf.to_string()
}

///|
pub fn snapshot_tool(
  snapshot : ProcessWorkspaceSnapshot,
) -> ProcessToolEnvelope {
  envelope("snapshot", PtaReadOnly, snapshot, snapshot.diagnostics, None, None)
}

///|
pub fn manifest_source_tool(
  snapshot : ProcessWorkspaceSnapshot,
) -> ProcessToolEnvelope {
  envelope(
    "manifest.source",
    PtaReadOnly,
    snapshot,
    snapshot.diagnostics,
    None,
    None,
  )
}

///|
pub fn resolved_sources_tool(
  snapshot : ProcessWorkspaceSnapshot,
) -> ProcessToolEnvelope {
  envelope(
    "resolved_sources",
    PtaReadOnly,
    snapshot,
    snapshot.diagnostics,
    None,
    None,
  )
}

///|
pub fn attachments_tool(
  snapshot : ProcessWorkspaceSnapshot,
) -> ProcessToolEnvelope {
  envelope(
    "attachments",
    PtaReadOnly,
    snapshot,
    snapshot.diagnostics,
    None,
    None,
  )
}

///|
pub fn datasets_tool(
  snapshot : ProcessWorkspaceSnapshot,
) -> ProcessToolEnvelope {
  envelope("datasets", PtaReadOnly, snapshot, snapshot.diagnostics, None, None)
}

///|
pub fn charts_tool(snapshot : ProcessWorkspaceSnapshot) -> ProcessToolEnvelope {
  envelope("charts", PtaReadOnly, snapshot, snapshot.diagnostics, None, None)
}

///|
pub fn artifacts_tool(
  snapshot : ProcessWorkspaceSnapshot,
) -> ProcessToolEnvelope {
  envelope("artifacts", PtaReadOnly, snapshot, snapshot.diagnostics, None, None)
}

///|
pub fn diagnostics_tool(
  snapshot : ProcessWorkspaceSnapshot,
) -> ProcessToolEnvelope {
  envelope(
    "diagnostics",
    PtaReadOnly,
    snapshot,
    snapshot.diagnostics,
    None,
    None,
  )
}

///|
pub fn replace_manifest_source_tool(
  snapshot : ProcessWorkspaceSnapshot,
  input : ManifestSourceReplaceInput,
) -> ProcessToolEnvelope {
  let updated = {
    ..snapshot,
    workspace: {
      ..snapshot.workspace,
      version: snapshot.workspace.version + 1,
      updated_at: input.now,
    },
    manifest: {
      source: input.source,
      status: MsUnparsed,
      process_id: None,
      error: None,
    },
    diagnostics: [],
    last_action: Some({ name: "manifest.source.replace", at: input.now }),
  }
  envelope("manifest.source.replace", PtaMutating, updated, [], None, None)
}

///|
pub fn upsert_node_tool(
  snapshot : ProcessWorkspaceSnapshot,
  input : ProcessNodeUpsertInput,
) -> ProcessToolEnvelope {
  let nodes : Array[ProcessNodeSummary] = []
  let mut replaced = false
  for node in snapshot.nodes {
    if node.id == input.node.id {
      nodes.push(input.node)
      replaced = true
    } else {
      nodes.push(node)
    }
  }
  if !replaced {
    nodes.push(input.node)
  }
  let updated = {
    ..snapshot,
    workspace: {
      ..snapshot.workspace,
      version: snapshot.workspace.version + 1,
      updated_at: input.now,
    },
    nodes,
    last_action: Some({ name: "node.upsert", at: input.now }),
  }
  envelope("node.upsert", PtaMutating, updated, updated.diagnostics, None, None)
}

///|
pub fn select_node_tool(
  snapshot : ProcessWorkspaceSnapshot,
  input : NodeSelectionInput,
) -> ProcessToolEnvelope {
  let updated = {
    ..snapshot,
    workspace: {
      ..snapshot.workspace,
      version: snapshot.workspace.version + 1,
      updated_at: input.now,
    },
    selection: {
      node_id: input.node_id,
      attachment_path: input.attachment_path,
    },
    last_action: Some({ name: "selection.set", at: input.now }),
  }
  envelope(
    "selection.set",
    PtaMutating,
    updated,
    updated.diagnostics,
    None,
    None,
  )
}

///|
pub fn import_attachment_tool(
  snapshot : ProcessWorkspaceSnapshot,
  input : AttachmentImportInput,
) -> ProcessToolEnvelope {
  let attachments : Array[AttachmentSummary] = []
  let mut replaced = false
  for attachment in snapshot.attachments {
    if attachment.path == input.attachment.path {
      attachments.push(input.attachment)
      replaced = true
    } else {
      attachments.push(attachment)
    }
  }
  if !replaced {
    attachments.push(input.attachment)
  }
  let updated = {
    ..snapshot,
    workspace: {
      ..snapshot.workspace,
      version: snapshot.workspace.version + 1,
      updated_at: input.now,
    },
    attachments,
    last_action: Some({ name: "attachment.import", at: input.now }),
  }
  envelope(
    "attachment.import",
    PtaMutating,
    updated,
    updated.diagnostics,
    None,
    None,
  )
}

///|
pub fn validate_current_process_tool(
  snapshot : ProcessWorkspaceSnapshot,
  input : ManifestValidationInput,
) -> ProcessToolEnvelope {
  let projected = validate_snapshot(
    snapshot,
    input.now,
    input.csv_reader,
    input.duckdb_runner,
  )
  let updated = read_only_projection(snapshot, projected)
  envelope(
    "process.validate.current",
    PtaReadOnly,
    updated,
    updated.diagnostics,
    None,
    None,
  )
}

///|
pub fn validate_and_persist_tool(
  snapshot : ProcessWorkspaceSnapshot,
  input : ManifestValidationInput,
) -> ProcessToolEnvelope {
  let updated = validate_snapshot(
    snapshot,
    input.now,
    input.csv_reader,
    input.duckdb_runner,
  )
  envelope(
    "process.validate.persist",
    PtaMutating,
    updated,
    updated.diagnostics,
    None,
    None,
  )
}

///|
pub fn render_preview_tool(
  snapshot : ProcessWorkspaceSnapshot,
  input : RenderPreviewInput,
) -> ProcessToolEnvelope {
  render_snapshot(snapshot, input, PtaReadOnly, "process.render.preview")
}

///|
pub fn render_and_persist_tool(
  snapshot : ProcessWorkspaceSnapshot,
  input : RenderPreviewInput,
) -> ProcessToolEnvelope {
  render_snapshot(snapshot, input, PtaMutating, "process.render.persist")
}

///|
pub fn remove_attachment_tool(
  snapshot : ProcessWorkspaceSnapshot,
  input : AttachmentRemoveInput,
) -> ProcessToolEnvelope {
  let attachment = find_attachment(snapshot.attachments, input.path)
  let size = match attachment {
    None => None
    Some(a) => Some(a.size)
  }
  let proposal : ProcessToolApprovalProposal = {
    id: "approval:attachment.remove:" + input.path,
    action: "attachment.remove",
    description: "Remove attachment '" + input.path + "': " + input.reason,
    created_at: input.now,
    workspace_id: snapshot.workspace.id,
    path: Some(input.path),
    size,
    effects: [
      "remove attachment from workspace session", "clear matching attachment selection if selected",
    ],
    format: None,
    destination: None,
    estimated_effects: [],
  }
  envelope(
    "attachment.remove",
    PtaApprovalRequired,
    snapshot,
    snapshot.diagnostics,
    Some(proposal),
    None,
  )
}

///|
pub fn export_external_tool(
  snapshot : ProcessWorkspaceSnapshot,
  input : ExternalExportInput,
) -> ProcessToolEnvelope {
  let format_name = export_bundle_format_name(input.format)
  let proposal : ProcessToolApprovalProposal = {
    id: "approval:process.export:" + format_name,
    action: "process.export.external",
    description: "Export " +
    format_name +
    " bundle to '" +
    input.destination +
    "': " +
    input.reason,
    created_at: input.now,
    workspace_id: snapshot.workspace.id,
    path: None,
    size: None,
    effects: [],
    format: Some(input.format),
    destination: Some(input.destination),
    estimated_effects: estimated_export_effects(snapshot, input.format),
  }
  envelope(
    "process.export.external",
    PtaApprovalRequired,
    snapshot,
    snapshot.diagnostics,
    Some(proposal),
    None,
  )
}

///|
pub fn export_process_bundle(
  snapshot : ProcessWorkspaceSnapshot,
  format : ExportBundleFormat,
  now : String,
) -> ExportBundleEnvelope {
  let payload_refs = match format {
    EbfManifestSource =>
      [
        {
          id: "manifest.source",
          kind: "manifest-source",
          reference: "workspace://manifest/source",
          media_type: "application/json",
          size: Some(snapshot.manifest.source.length().to_int64()),
        },
      ]
    EbfAttachments => attachment_payload_refs(snapshot.attachments)
    EbfRenderedArtifacts => preview_payload_refs(snapshot.preview)
    EbfDiagnosticReport =>
      [
        {
          id: "diagnostics",
          kind: "diagnostic-report",
          reference: "workspace://diagnostics/report",
          media_type: "application/json",
          size: None,
        },
      ]
  }
  {
    schema: "vizprocess.export-bundle.v1",
    format,
    workspace_id: snapshot.workspace.id,
    created_at: now,
    payload_refs,
    manifest_source: if format == EbfManifestSource {
      Some(snapshot.manifest.source)
    } else {
      None
    },
    diagnostics: if format == EbfDiagnosticReport {
      snapshot.diagnostics
    } else {
      []
    },
  }
}

///|
fn validate_snapshot(
  snapshot : ProcessWorkspaceSnapshot,
  now : String,
  csv_reader : (String) -> Result[String, String],
  duckdb_runner : (String, String, @pipe.DataSchema) -> Result[
    @pipe.Dataset,
    String,
  ],
) -> ProcessWorkspaceSnapshot {
  let result = build_process_from_json(
    snapshot.manifest.source,
    csv_reader,
    duckdb_runner,
  )
  snapshot.refresh_manifest(snapshot.manifest.source, result, now)
}

///|
fn render_snapshot(
  snapshot : ProcessWorkspaceSnapshot,
  input : RenderPreviewInput,
  access : ProcessToolAccess,
  name : String,
) -> ProcessToolEnvelope {
  let result = build_process_from_json(
    snapshot.manifest.source,
    input.csv_reader,
    input.duckdb_runner,
  )
  match result {
    Err(_) => {
      let projected = snapshot.refresh_manifest(
        snapshot.manifest.source,
        result,
        input.now,
      )
      let updated = if access == PtaReadOnly {
        read_only_projection(snapshot, projected)
      } else {
        projected
      }
      envelope(name, access, updated, updated.diagnostics, None, None)
    }
    Ok(process) => {
      let mut updated = snapshot.refresh_manifest(
        snapshot.manifest.source,
        Ok(process),
        input.now,
      )
      let execution = run_process(process)
      let artifact = select_artifact(execution.artifacts, input.artifact_id)
      match artifact {
        None => {
          let diagnostics = execution.diagnostics.copy()
          diagnostics.push(
            Diagnostic::process_error(
              code_unknown_chart, "artifacts", "requested artifact was not produced",
            ),
          )
          updated = { ..updated, diagnostics, }
          let output_snapshot = if access == PtaReadOnly {
            read_only_projection(snapshot, updated)
          } else {
            updated
          }
          envelope(name, access, output_snapshot, diagnostics, None, None)
        }
        Some(a) => {
          let reference : PreviewOutputReference = {
            artifact_id: a.id,
            kind: a.kind,
            reference: "workspace://preview/" + a.id,
            media_type: artifact_media_type(a.kind),
          }
          updated = updated.set_preview_output(reference, input.now)
          updated = { ..updated, diagnostics: execution.diagnostics }
          let preview : ProcessToolPreviewOutput = {
            reference,
            content: a.content,
            content_metadata: {
              bytes: a.content.length(),
              media_type: artifact_media_type(a.kind),
            },
          }
          let output_snapshot = if access == PtaReadOnly {
            read_only_projection(snapshot, updated)
          } else {
            updated
          }
          envelope(
            name,
            access,
            output_snapshot,
            execution.diagnostics,
            None,
            Some(preview),
          )
        }
      }
    }
  }
}

///|
fn read_only_projection(
  original : ProcessWorkspaceSnapshot,
  projected : ProcessWorkspaceSnapshot,
) -> ProcessWorkspaceSnapshot {
  {
    ..projected,
    workspace: original.workspace,
    last_action: original.last_action,
  }
}

///|
fn select_artifact(
  artifacts : Array[ArtifactResult],
  requested : String?,
) -> ArtifactResult? {
  match requested {
    None => if artifacts.length() == 0 { None } else { Some(artifacts[0]) }
    Some(id) => {
      for artifact in artifacts {
        if artifact.id == id {
          return Some(artifact)
        }
      }
      None
    }
  }
}

///|
fn envelope(
  name : String,
  access : ProcessToolAccess,
  snapshot : ProcessWorkspaceSnapshot,
  diagnostics : Array[Diagnostic],
  approval : ProcessToolApprovalProposal?,
  preview : ProcessToolPreviewOutput?,
) -> ProcessToolEnvelope {
  { tool: { name, access }, diagnostics, snapshot, approval, preview }
}

///|
fn process_tool_access_name(access : ProcessToolAccess) -> String {
  match access {
    PtaReadOnly => "read-only"
    PtaMutating => "mutating"
    PtaApprovalRequired => "approval-required"
  }
}

///|
fn manifest_status_name(status : ManifestStatus) -> String {
  match status {
    MsUnparsed => "unparsed"
    MsValid => "valid"
    MsInvalid => "invalid"
  }
}

///|
fn node_kind_name(kind : NodeKind) -> String {
  match kind {
    NkDataset => "dataset"
    NkChart => "chart"
    NkArtifact => "artifact"
  }
}

///|
fn severity_name(severity : Severity) -> String {
  match severity {
    ERROR => "error"
    WARNING => "warning"
    INFO => "info"
  }
}

///|
fn export_bundle_format_name(format : ExportBundleFormat) -> String {
  match format {
    EbfManifestSource => "manifest-source"
    EbfAttachments => "attachments"
    EbfRenderedArtifacts => "rendered-artifacts"
    EbfDiagnosticReport => "diagnostic-report"
  }
}

///|
fn find_attachment(
  attachments : Array[AttachmentSummary],
  path : String,
) -> AttachmentSummary? {
  for attachment in attachments {
    if attachment.path == path {
      return Some(attachment)
    }
  }
  None
}

///|
fn estimated_export_effects(
  snapshot : ProcessWorkspaceSnapshot,
  format : ExportBundleFormat,
) -> Array[String] {
  match format {
    EbfManifestSource =>
      ["write manifest source bundle to external destination"]
    EbfAttachments =>
      [
        "write " +
        snapshot.attachments.length().to_string() +
        " attachment reference(s) to external destination",
      ]
    EbfRenderedArtifacts =>
      ["write rendered artifact reference(s) to external destination"]
    EbfDiagnosticReport =>
      [
        "write " +
        snapshot.diagnostics.length().to_string() +
        " diagnostic(s) to external destination",
      ]
  }
}

///|
fn attachment_payload_refs(
  attachments : Array[AttachmentSummary],
) -> Array[ExportPayloadReference] {
  let refs : Array[ExportPayloadReference] = []
  for attachment in attachments {
    refs.push({
      id: attachment.path,
      kind: "attachment",
      reference: attachment.path,
      media_type: attachment.media_type,
      size: Some(attachment.size),
    })
  }
  refs
}

///|
fn preview_payload_refs(
  preview : PreviewSection,
) -> Array[ExportPayloadReference] {
  match preview.output {
    None => []
    Some(output) =>
      [
        {
          id: output.artifact_id,
          kind: artifact_kind_name(output.kind),
          reference: output.reference,
          media_type: output.media_type,
          size: None,
        },
      ]
  }
}

///|
fn write_snapshot_json(
  buf : StringBuilder,
  snapshot : ProcessWorkspaceSnapshot,
) -> Unit {
  buf.write_string("{\"attachments\":")
  write_attachments_json(buf, snapshot.attachments)
  buf.write_string(",\"diagnostics\":")
  write_diagnostics_json(buf, snapshot.diagnostics)
  buf.write_string(",\"lastAction\":")
  write_last_action_json(buf, snapshot.last_action)
  buf.write_string(",\"manifest\":")
  write_manifest_json(buf, snapshot.manifest)
  buf.write_string(",\"nodes\":")
  write_nodes_json(buf, snapshot.nodes)
  buf.write_string(",\"preview\":")
  write_preview_section_json(buf, snapshot.preview)
  buf.write_string(",\"resolvedSources\":")
  write_resolved_sources_json(buf, snapshot.resolved_sources)
  buf.write_string(",\"selection\":")
  write_selection_json(buf, snapshot.selection)
  buf.write_string(",\"workspace\":")
  write_workspace_json(buf, snapshot.workspace)
  buf.write_char('}')
}

///|
fn write_workspace_json(
  buf : StringBuilder,
  workspace : WorkspaceSection,
) -> Unit {
  buf.write_string("{\"id\":\"")
  write_json_escaped(buf, workspace.id)
  buf.write_string("\",\"title\":\"")
  write_json_escaped(buf, workspace.title)
  buf.write_string("\",\"updatedAt\":\"")
  write_json_escaped(buf, workspace.updated_at)
  buf.write_string("\",\"version\":")
  buf.write_string(workspace.version.to_string())
  buf.write_char('}')
}

///|
fn write_manifest_json(buf : StringBuilder, manifest : ManifestSection) -> Unit {
  buf.write_string("{\"error\":")
  write_optional_string_json(buf, manifest.error)
  buf.write_string(",\"processId\":")
  write_optional_string_json(buf, manifest.process_id)
  buf.write_string(",\"source\":\"")
  write_json_escaped(buf, manifest.source)
  buf.write_string("\",\"status\":\"")
  buf.write_string(manifest_status_name(manifest.status))
  buf.write_string("\"}")
}

///|
fn write_resolved_sources_json(
  buf : StringBuilder,
  sources : Array[ResolvedSourceSummary],
) -> Unit {
  buf.write_char('[')
  for i in 0..<sources.length() {
    if i > 0 {
      buf.write_char(',')
    }
    let source = sources[i]
    buf.write_string("{\"datasetId\":\"")
    write_json_escaped(buf, source.dataset_id)
    buf.write_string("\",\"reference\":\"")
    write_json_escaped(buf, source.reference)
    buf.write_string("\",\"rows\":")
    buf.write_string(source.rows.to_string())
    buf.write_char('}')
  }
  buf.write_char(']')
}

///|
fn write_nodes_json(
  buf : StringBuilder,
  nodes : Array[ProcessNodeSummary],
) -> Unit {
  buf.write_char('[')
  for i in 0..<nodes.length() {
    if i > 0 {
      buf.write_char(',')
    }
    let node = nodes[i]
    buf.write_string("{\"id\":\"")
    write_json_escaped(buf, node.id)
    buf.write_string("\",\"inputId\":")
    write_optional_string_json(buf, node.input_id)
    buf.write_string(",\"kind\":\"")
    buf.write_string(node_kind_name(node.kind))
    buf.write_string("\",\"outputKind\":")
    write_optional_string_json(buf, node.output_kind)
    buf.write_char('}')
  }
  buf.write_char(']')
}

///|
fn write_attachments_json(
  buf : StringBuilder,
  attachments : Array[AttachmentSummary],
) -> Unit {
  buf.write_char('[')
  for i in 0..<attachments.length() {
    if i > 0 {
      buf.write_char(',')
    }
    let attachment = attachments[i]
    buf.write_string("{\"mediaType\":\"")
    write_json_escaped(buf, attachment.media_type)
    buf.write_string("\",\"path\":\"")
    write_json_escaped(buf, attachment.path)
    buf.write_string("\",\"size\":")
    buf.write_string(attachment.size.to_string())
    buf.write_char('}')
  }
  buf.write_char(']')
}

///|
fn write_selection_json(
  buf : StringBuilder,
  selection : SelectionSection,
) -> Unit {
  buf.write_string("{\"attachmentPath\":")
  write_optional_string_json(buf, selection.attachment_path)
  buf.write_string(",\"nodeId\":")
  write_optional_string_json(buf, selection.node_id)
  buf.write_char('}')
}

///|
fn write_preview_section_json(
  buf : StringBuilder,
  preview : PreviewSection,
) -> Unit {
  buf.write_string("{\"output\":")
  write_preview_reference_json(buf, preview.output)
  buf.write_char('}')
}

///|
fn write_last_action_json(
  buf : StringBuilder,
  last_action : LastActionSection?,
) -> Unit {
  match last_action {
    None => buf.write_string("null")
    Some(action) => {
      buf.write_string("{\"at\":\"")
      write_json_escaped(buf, action.at)
      buf.write_string("\",\"name\":\"")
      write_json_escaped(buf, action.name)
      buf.write_string("\"}")
    }
  }
}

///|
fn write_diagnostics_json(
  buf : StringBuilder,
  diagnostics : Array[Diagnostic],
) -> Unit {
  buf.write_char('[')
  for i in 0..<diagnostics.length() {
    if i > 0 {
      buf.write_char(',')
    }
    let diagnostic = diagnostics[i]
    buf.write_string("{\"code\":\"")
    write_json_escaped(buf, diagnostic.code)
    buf.write_string("\",\"message\":\"")
    write_json_escaped(buf, diagnostic.message)
    buf.write_string("\",\"severity\":\"")
    buf.write_string(severity_name(diagnostic.severity))
    buf.write_string("\",\"source\":\"")
    write_json_escaped(buf, diagnostic.source)
    buf.write_string("\",\"target\":\"")
    write_json_escaped(buf, diagnostic.target)
    buf.write_string("\"}")
  }
  buf.write_char(']')
}

///|
fn write_approval_json(
  buf : StringBuilder,
  approval : ProcessToolApprovalProposal?,
) -> Unit {
  match approval {
    None => buf.write_string("null")
    Some(a) => {
      buf.write_string("{\"action\":\"")
      write_json_escaped(buf, a.action)
      buf.write_string("\",\"createdAt\":\"")
      write_json_escaped(buf, a.created_at)
      buf.write_string("\",\"description\":\"")
      write_json_escaped(buf, a.description)
      buf.write_string("\",\"destination\":")
      write_optional_string_json(buf, a.destination)
      buf.write_string(",\"effects\":")
      write_string_array_json(buf, a.effects)
      buf.write_string(",\"estimatedEffects\":")
      write_string_array_json(buf, a.estimated_effects)
      buf.write_string(",\"format\":")
      write_optional_export_format_json(buf, a.format)
      buf.write_string(",\"id\":\"")
      write_json_escaped(buf, a.id)
      buf.write_string("\",\"path\":")
      write_optional_string_json(buf, a.path)
      buf.write_string(",\"size\":")
      write_optional_int64_json(buf, a.size)
      buf.write_string(",\"workspaceId\":\"")
      write_json_escaped(buf, a.workspace_id)
      buf.write_string("\"}")
    }
  }
}

///|
fn write_preview_json(
  buf : StringBuilder,
  preview : ProcessToolPreviewOutput?,
) -> Unit {
  match preview {
    None => buf.write_string("null")
    Some(p) => {
      buf.write_string("{\"content\":\"")
      write_json_escaped(buf, p.content)
      buf.write_string("\",\"contentMetadata\":")
      write_preview_content_metadata_json(buf, p.content_metadata)
      buf.write_string(",\"reference\":")
      write_preview_reference_value_json(buf, p.reference)
      buf.write_char('}')
    }
  }
}

///|
fn write_preview_content_metadata_json(
  buf : StringBuilder,
  metadata : PreviewContentMetadata,
) -> Unit {
  buf.write_string("{\"bytes\":")
  buf.write_string(metadata.bytes.to_string())
  buf.write_string(",\"mediaType\":\"")
  write_json_escaped(buf, metadata.media_type)
  buf.write_string("\"}")
}

///|
fn write_preview_reference_json(
  buf : StringBuilder,
  reference : PreviewOutputReference?,
) -> Unit {
  match reference {
    None => buf.write_string("null")
    Some(r) => write_preview_reference_value_json(buf, r)
  }
}

///|
fn write_preview_reference_value_json(
  buf : StringBuilder,
  reference : PreviewOutputReference,
) -> Unit {
  buf.write_string("{\"artifactId\":\"")
  write_json_escaped(buf, reference.artifact_id)
  buf.write_string("\",\"kind\":\"")
  buf.write_string(artifact_kind_name(reference.kind))
  buf.write_string("\",\"mediaType\":\"")
  write_json_escaped(buf, reference.media_type)
  buf.write_string("\",\"previewRef\":\"")
  write_json_escaped(buf, reference.reference)
  buf.write_string("\"}")
}

///|
fn write_optional_string_json(buf : StringBuilder, value : String?) -> Unit {
  match value {
    None => buf.write_string("null")
    Some(s) => {
      buf.write_char('"')
      write_json_escaped(buf, s)
      buf.write_char('"')
    }
  }
}

///|
fn write_optional_int64_json(buf : StringBuilder, value : Int64?) -> Unit {
  match value {
    None => buf.write_string("null")
    Some(n) => buf.write_string(n.to_string())
  }
}

///|
fn write_optional_export_format_json(
  buf : StringBuilder,
  value : ExportBundleFormat?,
) -> Unit {
  match value {
    None => buf.write_string("null")
    Some(format) => {
      buf.write_char('"')
      buf.write_string(export_bundle_format_name(format))
      buf.write_char('"')
    }
  }
}

///|
fn write_export_bundle_json(
  buf : StringBuilder,
  bundle : ExportBundleEnvelope,
) -> Unit {
  buf.write_string("{\"createdAt\":\"")
  write_json_escaped(buf, bundle.created_at)
  buf.write_string("\",\"diagnostics\":")
  write_diagnostics_json(buf, bundle.diagnostics)
  buf.write_string(",\"format\":\"")
  buf.write_string(export_bundle_format_name(bundle.format))
  buf.write_string("\",\"manifestSource\":")
  write_optional_string_json(buf, bundle.manifest_source)
  buf.write_string(",\"payloadRefs\":")
  write_payload_refs_json(buf, bundle.payload_refs)
  buf.write_string(",\"schema\":\"")
  write_json_escaped(buf, bundle.schema)
  buf.write_string("\",\"workspaceId\":\"")
  write_json_escaped(buf, bundle.workspace_id)
  buf.write_string("\"}")
}

///|
fn write_payload_refs_json(
  buf : StringBuilder,
  refs : Array[ExportPayloadReference],
) -> Unit {
  buf.write_char('[')
  for i in 0..<refs.length() {
    if i > 0 {
      buf.write_char(',')
    }
    let payload_ref = refs[i]
    buf.write_string("{\"id\":\"")
    write_json_escaped(buf, payload_ref.id)
    buf.write_string("\",\"kind\":\"")
    write_json_escaped(buf, payload_ref.kind)
    buf.write_string("\",\"mediaType\":\"")
    write_json_escaped(buf, payload_ref.media_type)
    buf.write_string("\",\"reference\":\"")
    write_json_escaped(buf, payload_ref.reference)
    buf.write_string("\",\"size\":")
    write_optional_int64_json(buf, payload_ref.size)
    buf.write_char('}')
  }
  buf.write_char(']')
}

///|
fn write_string_array_json(buf : StringBuilder, values : Array[String]) -> Unit {
  buf.write_char('[')
  for i in 0..<values.length() {
    if i > 0 {
      buf.write_char(',')
    }
    buf.write_char('"')
    write_json_escaped(buf, values[i])
    buf.write_char('"')
  }
  buf.write_char(']')
}

///|
fn write_json_escaped(buf : StringBuilder, s : String) -> Unit {
  for ch in s {
    match ch {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\u{00}' => buf.write_string("\\u0000")
      '\u{01}' => buf.write_string("\\u0001")
      '\u{02}' => buf.write_string("\\u0002")
      '\u{03}' => buf.write_string("\\u0003")
      '\u{04}' => buf.write_string("\\u0004")
      '\u{05}' => buf.write_string("\\u0005")
      '\u{06}' => buf.write_string("\\u0006")
      '\u{07}' => buf.write_string("\\u0007")
      '\b' => buf.write_string("\\b")
      '\u{0c}' => buf.write_string("\\f")
      '\u{0b}' => buf.write_string("\\u000b")
      '\u{0e}' => buf.write_string("\\u000e")
      '\u{0f}' => buf.write_string("\\u000f")
      '\u{10}' => buf.write_string("\\u0010")
      '\u{11}' => buf.write_string("\\u0011")
      '\u{12}' => buf.write_string("\\u0012")
      '\u{13}' => buf.write_string("\\u0013")
      '\u{14}' => buf.write_string("\\u0014")
      '\u{15}' => buf.write_string("\\u0015")
      '\u{16}' => buf.write_string("\\u0016")
      '\u{17}' => buf.write_string("\\u0017")
      '\u{18}' => buf.write_string("\\u0018")
      '\u{19}' => buf.write_string("\\u0019")
      '\u{1a}' => buf.write_string("\\u001a")
      '\u{1b}' => buf.write_string("\\u001b")
      '\u{1c}' => buf.write_string("\\u001c")
      '\u{1d}' => buf.write_string("\\u001d")
      '\u{1e}' => buf.write_string("\\u001e")
      '\u{1f}' => buf.write_string("\\u001f")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(ch)
    }
  }
}
