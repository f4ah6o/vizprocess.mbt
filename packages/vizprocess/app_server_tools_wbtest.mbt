///|
test "manifest replace tool updates source through stable envelope" {
  let result = replace_manifest_source_tool(empty_snapshot(), {
    source: sample_manifest(),
    now: "2026-05-10T09:11:00Z",
  })
  inspect(result.tool.access, content="PtaMutating")
  inspect(result.snapshot.manifest.source, content=sample_manifest())
  inspect(result.snapshot.manifest.status, content="MsUnparsed")
  inspect(result.snapshot.workspace.version, content="2")
  inspect(result.to_json().contains("\"access\":\"mutating\""), content="true")
  inspect(
    result.to_json().contains("\"tool\":\"manifest.source.replace\""),
    content="true",
  )
}

///|
test "validate tool returns diagnostics and refreshed snapshot" {
  let result = validate_current_process_tool(snapshot_with_manifest(), {
    now: "2026-05-10T09:12:00Z",
    csv_reader: test_csv_reader,
    duckdb_runner: test_duckdb_runner,
  })
  inspect(result.tool.access, content="PtaReadOnly")
  inspect(result.snapshot.manifest.status, content="MsValid")
  inspect(result.snapshot.workspace.version, content="1")
  inspect(result.snapshot.nodes.length(), content="3")
  inspect(result.diagnostics.length(), content="0")
  inspect(result.to_json().contains("\"status\":\"valid\""), content="true")
}

///|
test "render preview tool stores resumable output reference" {
  let result = render_preview_tool(snapshot_with_manifest(), {
    artifact_id: Some("svg"),
    now: "2026-05-10T09:13:00Z",
    csv_reader: test_csv_reader,
    duckdb_runner: test_duckdb_runner,
  })
  inspect(result.tool.access, content="PtaReadOnly")
  inspect(result.snapshot.workspace.version, content="1")
  inspect(
    result.snapshot.preview.output.unwrap().reference,
    content="workspace://preview/svg",
  )
  inspect(result.preview.unwrap().reference.artifact_id, content="svg")
  inspect(
    result.preview.unwrap().content_metadata.media_type,
    content="image/svg+xml",
  )
  inspect(result.preview.unwrap().reference.media_type, content="image/svg+xml")
  inspect(result.preview.unwrap().content.contains("<svg"), content="true")
  inspect(
    result.to_json().contains("\"previewRef\":\"workspace://preview/svg\""),
    content="true",
  )
  inspect(result.to_json().contains("\"contentMetadata\":"), content="true")
  inspect(result.diagnostics.length(), content="0")
}

///|
test "render preview missing artifact keeps read only workspace version" {
  let result = render_preview_tool(snapshot_with_manifest(), {
    artifact_id: Some("missing"),
    now: "2026-05-10T09:13:30Z",
    csv_reader: test_csv_reader,
    duckdb_runner: test_duckdb_runner,
  })
  inspect(result.tool.access, content="PtaReadOnly")
  inspect(result.snapshot.workspace.version, content="1")
  inspect(result.diagnostics.length(), content="1")
  inspect(result.preview, content="None")
}

///|
test "node upsert tool inserts and replaces node summaries" {
  let first = upsert_node_tool(empty_snapshot(), {
    node: {
      id: "scratch",
      kind: NkDataset,
      input_id: None,
      output_kind: Some("dataset"),
    },
    now: "2026-05-10T09:14:00Z",
  })
  inspect(first.snapshot.nodes.length(), content="1")
  let second = upsert_node_tool(first.snapshot, {
    node: {
      id: "scratch",
      kind: NkChart,
      input_id: Some("dataset-a"),
      output_kind: Some("chart"),
    },
    now: "2026-05-10T09:15:00Z",
  })
  inspect(second.snapshot.nodes.length(), content="1")
  inspect(second.snapshot.nodes[0].kind, content="NkChart")
  inspect(second.snapshot.nodes[0].input_id, content="Some(\"dataset-a\")")
}

///|
test "attachment import tool upserts durable attachment summary" {
  let first = import_attachment_tool(empty_snapshot(), {
    attachment: {
      path: "workspace://attachments/sales.csv",
      size: 12L,
      media_type: "text/csv",
    },
    now: "2026-05-10T09:16:00Z",
  })
  inspect(first.snapshot.attachments.length(), content="1")
  let second = import_attachment_tool(first.snapshot, {
    attachment: {
      path: "workspace://attachments/sales.csv",
      size: 18L,
      media_type: "text/csv",
    },
    now: "2026-05-10T09:17:00Z",
  })
  inspect(second.snapshot.attachments.length(), content="1")
  inspect(second.snapshot.attachments[0].size, content="18")
}

///|
test "approval required tools propose removal and external export" {
  let snapshot = {
    ..empty_snapshot(),
    attachments: [
      {
        path: "workspace://attachments/sales.csv",
        size: 18L,
        media_type: "text/csv",
      },
    ],
  }
  let removal = remove_attachment_tool(snapshot, {
    path: "workspace://attachments/sales.csv",
    reason: "user requested cleanup",
    now: "2026-05-10T09:18:00Z",
  })
  inspect(removal.tool.access, content="PtaApprovalRequired")
  inspect(removal.approval.unwrap().action, content="attachment.remove")
  inspect(removal.approval.unwrap().workspace_id, content="workspace-1")
  inspect(
    removal.approval.unwrap().path,
    content="Some(\"workspace://attachments/sales.csv\")",
  )
  inspect(removal.approval.unwrap().size, content="Some(18)")
  inspect(removal.approval.unwrap().effects.length(), content="2")
  inspect(removal.snapshot.attachments.length(), content="1")
  inspect(
    removal.to_json().contains("\"access\":\"approval-required\""),
    content="true",
  )
  inspect(
    removal.to_json().contains("\"workspaceId\":\"workspace-1\""),
    content="true",
  )
  let export_result = export_external_tool(snapshot, {
    format: EbfRenderedArtifacts,
    destination: "s3://example-bucket/sales.svg",
    reason: "publish approved report",
    now: "2026-05-10T09:19:00Z",
  })
  inspect(export_result.tool.access, content="PtaApprovalRequired")
  inspect(
    export_result.approval.unwrap().action,
    content="process.export.external",
  )
  inspect(
    export_result.approval.unwrap().format,
    content="Some(EbfRenderedArtifacts)",
  )
  inspect(
    export_result.approval.unwrap().destination,
    content="Some(\"s3://example-bucket/sales.svg\")",
  )
  inspect(
    export_result.approval.unwrap().estimated_effects.length(),
    content="1",
  )
  inspect(
    export_result.approval.unwrap().id,
    content="approval:process.export:rendered-artifacts",
  )
}

///|
test "export bundle envelopes cover all supported formats" {
  let snapshot = {
    ..empty_snapshot(),
    manifest: { ..empty_snapshot().manifest, source: sample_manifest() },
    attachments: [
      {
        path: "workspace://attachments/sales.csv",
        size: 18L,
        media_type: "text/csv",
      },
    ],
    preview: {
      output: Some({
        artifact_id: "svg",
        kind: AkSvg,
        reference: "workspace://preview/svg",
        media_type: "image/svg+xml",
      }),
    },
    diagnostics: [
      Diagnostic::process_error("TEST_DIAG", "$", "fixture diagnostic"),
    ],
  }
  let manifest = export_process_bundle(
    snapshot,
    EbfManifestSource,
    "2026-05-10T09:21:00Z",
  )
  inspect(manifest.schema, content="vizprocess.export-bundle.v1")
  inspect(manifest.payload_refs[0].kind, content="manifest-source")
  inspect(manifest.manifest_source.unwrap(), content=sample_manifest())
  inspect(
    manifest.to_json().contains("\"format\":\"manifest-source\""),
    content="true",
  )
  let attachments = export_process_bundle(
    snapshot,
    EbfAttachments,
    "2026-05-10T09:22:00Z",
  )
  inspect(
    attachments.payload_refs[0].reference,
    content="workspace://attachments/sales.csv",
  )
  inspect(attachments.payload_refs[0].size, content="Some(18)")
  inspect(
    attachments.to_json().contains("\"format\":\"attachments\""),
    content="true",
  )
  let rendered = export_process_bundle(
    snapshot,
    EbfRenderedArtifacts,
    "2026-05-10T09:23:00Z",
  )
  inspect(rendered.payload_refs[0].id, content="svg")
  inspect(
    rendered.to_json().contains("\"format\":\"rendered-artifacts\""),
    content="true",
  )
  let report = export_process_bundle(
    snapshot,
    EbfDiagnosticReport,
    "2026-05-10T09:24:00Z",
  )
  inspect(report.diagnostics.length(), content="1")
  inspect(report.payload_refs[0].kind, content="diagnostic-report")
  inspect(
    report.to_json().contains("\"format\":\"diagnostic-report\""),
    content="true",
  )
}

///|
test "json envelope escapes control characters used in tool strings" {
  let result = remove_attachment_tool(empty_snapshot(), {
    path: "workspace://attachments/quoted\"name.csv",
    reason: "line\ncarriage\rTabbed\tBackspace\bForm\u{0c}Null\u{00}Vtab\u{0b}\\slash",
    now: "2026-05-10T09:20:00Z",
  })
  let json = result.to_json()
  inspect(json.contains("quoted\\\"name.csv"), content="true")
  inspect(
    json.contains(
      "line\\ncarriage\\rTabbed\\tBackspace\\bForm\\fNull\\u0000Vtab\\u000b\\\\slash",
    ),
    content="true",
  )
}

///|
fn empty_snapshot() -> ProcessWorkspaceSnapshot {
  ProcessWorkspaceSnapshot::empty(
    "workspace-1", "Sales workspace", "2026-05-10T09:10:00Z",
  )
}

///|
fn snapshot_with_manifest() -> ProcessWorkspaceSnapshot {
  {
    ..empty_snapshot(),
    manifest: { ..empty_snapshot().manifest, source: sample_manifest() },
  }
}

///|
fn sample_manifest() -> String {
  (
    #|{"artifacts":[{"chart_id":"sales-bar","id":"svg","kind":"svg"}],"charts":[{"dataset_id":"monthly_sales","id":"sales-bar","spec":{"config":{"height":240,"width":480},"encoding":{"x":{"field":"month"},"y":{"field":"amount"}},"id":"sales-bar","mark":"bar"}}],"datasets":[{"id":"monthly_sales","pipeline":{"steps":[]},"source":{"data":"month,amount\nJan,10\n","kind":"csv-inline","schema":{"fields":[{"dtype":"string","name":"month"},{"dtype":"int","name":"amount"}]}}}],"id":"monthly-sales"}
  )
}

///|
fn test_csv_reader(_path : String) -> Result[String, String] {
  Err("file reads are not used by this test")
}

///|
fn test_duckdb_runner(
  _db : String,
  _sql : String,
  _schema : @pipe.DataSchema,
) -> Result[@pipe.Dataset, String] {
  Err("duckdb is not used by this test")
}
