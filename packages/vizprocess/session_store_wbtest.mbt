///|
test "session snapshot includes durable top-level sections" {
  let snapshot = ProcessWorkspaceSnapshot::empty(
    "workspace-1", "Sales workspace", "2026-05-10T09:00:00Z",
  )
  inspect(snapshot.workspace.id, content="workspace-1")
  inspect(snapshot.manifest.status, content="MsUnparsed")
  inspect(snapshot.resolved_sources.length(), content="0")
  inspect(snapshot.nodes.length(), content="0")
  inspect(snapshot.attachments.length(), content="0")
  inspect(snapshot.selection.node_id, content="None")
  inspect(snapshot.preview.output, content="None")
  inspect(snapshot.diagnostics.length(), content="0")
  inspect(snapshot.last_action, content="None")
}

///|
test "manifest refresh stores flat dataset chart artifact summaries" {
  let process = sample_process()
  let snapshot = ProcessWorkspaceSnapshot::empty(
    "workspace-1", "Sales workspace", "2026-05-10T09:00:00Z",
  ).refresh_manifest("{}", Ok(process), "2026-05-10T09:01:00Z")
  inspect(snapshot.workspace.version, content="2")
  inspect(snapshot.manifest.status, content="MsValid")
  inspect(snapshot.manifest.process_id, content="Some(\"monthly-sales\")")
  inspect(
    snapshot.resolved_sources,
    content=(
      #|[{dataset_id: "monthly_sales", reference: "dataset:monthly_sales", rows: 1}]
    ),
  )
  inspect(
    snapshot.nodes,
    content=(
      #|[{id: "monthly_sales", kind: NkDataset, input_id: None, output_kind: Some("dataset")}, {id: "sales-bar", kind: NkChart, input_id: Some("monthly_sales"), output_kind: Some("chart")}, {id: "svg", kind: NkArtifact, input_id: Some("sales-bar"), output_kind: Some("svg")}]
    ),
  )
  inspect(
    snapshot.last_action,
    content=(
      #|Some({name: "manifest.refresh", at: "2026-05-10T09:01:00Z"})
    ),
  )
}

///|
test "manifest refresh failure clears derived topology but keeps attachments and preview" {
  let attachment : AttachmentSummary = {
    path: "workspace://attachments/sales.csv",
    size: 18L,
    media_type: "text/csv",
  }
  let preview : PreviewOutputReference = {
    artifact_id: "svg",
    kind: AkSvg,
    reference: "workspace://preview/svg",
    media_type: artifact_media_type(AkSvg),
  }
  let snapshot = {
    ..ProcessWorkspaceSnapshot::empty(
      "workspace-1", "Sales workspace", "2026-05-10T09:00:00Z",
    ),
    attachments: [attachment],
    preview: { output: Some(preview) },
  }.refresh_manifest("{", Err("invalid json"), "2026-05-10T09:02:00Z")
  inspect(snapshot.manifest.status, content="MsInvalid")
  inspect(snapshot.manifest.error, content="Some(\"invalid json\")")
  inspect(snapshot.nodes.length(), content="0")
  inspect(snapshot.resolved_sources.length(), content="0")
  inspect(
    snapshot.attachments[0],
    content=(
      #|{path: "workspace://attachments/sales.csv", size: 18, media_type: "text/csv"}
    ),
  )
  inspect(
    snapshot.preview.output,
    content=(
      #|Some({artifact_id: "svg", kind: AkSvg, reference: "workspace://preview/svg", media_type: "image/svg+xml"})
    ),
  )
  inspect(snapshot.diagnostics[0].code, content="MANIFEST_INVALID")
}

///|
test "preview output stores resumable reference" {
  let output : PreviewOutputReference = {
    artifact_id: "model",
    kind: AkRenderModelJson,
    reference: "workspace://preview/model.json",
    media_type: artifact_media_type(AkRenderModelJson),
  }
  let snapshot = ProcessWorkspaceSnapshot::empty(
    "workspace-1", "Sales workspace", "2026-05-10T09:00:00Z",
  ).set_preview_output(output, "2026-05-10T09:03:00Z")
  inspect(
    snapshot.preview.output,
    content=(
      #|Some({artifact_id: "model", kind: AkRenderModelJson, reference: "workspace://preview/model.json", media_type: "application/json"})
    ),
  )
  inspect(
    snapshot.last_action,
    content=(
      #|Some({name: "preview.output.set", at: "2026-05-10T09:03:00Z"})
    ),
  )
}

///|
fn sample_process() -> VizProcess {
  let schema : @pipe.DataSchema = {
    fields: [{ name: "month", dtype: @pipe.TString }],
  }
  let columns : Map[String, Array[@pipe.Value]] = Map::new()
  columns["month"] = [@pipe.VString("2026-01")]
  let dataset : @pipe.Dataset = { schema, columns, n_rows: 1 }
  let pipeline : @pipe.Pipeline = { steps: [] }
  let chart : @viz.ChartSpec = {
    id: "sales-bar",
    mark: @viz.BAR,
    encoding: { x: Some({ field: "month" }), y: None },
    config: @viz.ChartConfig::default(),
  }
  {
    id: "monthly-sales",
    datasets: [{ id: "monthly_sales", source: dataset, pipeline }],
    charts: [{ id: "sales-bar", dataset_id: "monthly_sales", chart }],
    artifacts: [
      { id: "svg", kind: AkSvg, chart_id: "sales-bar", output: OtMemory },
    ],
  }
}
