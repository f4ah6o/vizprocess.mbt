///|
/// End-to-end golden: build a VizProcess in memory, run it, and verify
/// every artifact byte-matches the M1/M2/M3 goldens. Drives the entire
/// pipe → viz adapter → run_process flow.
test "golden: end-to-end CSV -> dataset -> chart -> artifacts" {
  let csv =
    #|month,region,amount
    #|2026-01,JP,100
    #|2026-01,US,50
    #|2026-02,JP,200
    #|2026-02,US,150
    #|2026-01,JP,75
    #|
  let schema : @pipe.DataSchema = {
    fields: [
      { name: "month", dtype: @pipe.TString },
      { name: "region", dtype: @pipe.TString },
      { name: "amount", dtype: @pipe.TInt },
    ],
  }
  let (raw_dataset, parse_diags) = @pipe.parse_csv(csv, schema)
  inspect(parse_diags.length(), content="0")
  let pipeline : @pipe.Pipeline = {
    steps: [
      Select(["month", "region", "amount"]),
      Filter("region", @pipe.EQ, @pipe.VString("JP")),
      Aggregate({
        group_by: ["month"],
        measures: [{ field: "amount", op: @pipe.SUM, as_: "total" }],
      }),
    ],
  }
  let chart : @viz.ChartSpec = {
    id: "sales-bar",
    mark: @viz.BAR,
    encoding: { x: Some({ field: "month" }), y: Some({ field: "total" }) },
    config: @viz.ChartConfig::default(),
  }
  let process : VizProcess = {
    id: "monthly-sales",
    datasets: [{ id: "monthly_sales", source: raw_dataset, pipeline }],
    charts: [{ id: "sales-bar", dataset_id: "monthly_sales", chart }],
    artifacts: [
      {
        id: "dataset",
        kind: AkDatasetJson,
        chart_id: "sales-bar",
        output: OtMemory,
      },
      {
        id: "model",
        kind: AkRenderModelJson,
        chart_id: "sales-bar",
        output: OtMemory,
      },
      { id: "svg", kind: AkSvg, chart_id: "sales-bar", output: OtMemory },
    ],
  }
  let exec = run_process(process)
  inspect(exec.diagnostics.length(), content="0")
  inspect(exec.status, content="EsSuccess")
  inspect(exec.artifacts.length(), content="3")
  let dataset_json = artifact_by_id(exec, "dataset")
  let expected_dataset =
    #|{"rows":[{"month":"2026-01","total":175},{"month":"2026-02","total":200}],"schema":{"fields":[{"dtype":"string","name":"month"},{"dtype":"int","name":"total"}]}}
  inspect(dataset_json, content=expected_dataset)
  let model_json = artifact_by_id(exec, "model")
  let expected_model =
    #|{"height":240,"id":"sales-bar","layers":[{"kind":"rect","marks":[{"height":175,"label":"2026-01","width":206,"x":42,"y":45},{"height":200,"label":"2026-02","width":206,"x":252,"y":20}]}],"width":480}
  inspect(model_json, content=expected_model)
  let svg = artifact_by_id(exec, "svg")
  let expected_svg =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="480" height="240"><g><rect x="42" y="45" width="206" height="175"/><rect x="252" y="20" width="206" height="200"/></g></svg>
  inspect(svg, content=expected_svg)
}

///|
test "run_process surfaces unknown dataset" {
  let chart : @viz.ChartSpec = {
    id: "c",
    mark: @viz.BAR,
    encoding: { x: Some({ field: "x" }), y: Some({ field: "y" }) },
    config: @viz.ChartConfig::default(),
  }
  let process : VizProcess = {
    id: "broken",
    datasets: [],
    charts: [{ id: "c", dataset_id: "missing", chart }],
    artifacts: [],
  }
  let exec = run_process(process)
  inspect(exec.status, content="EsFailed")
  inspect(exec.diagnostics.length(), content="1")
  inspect(exec.diagnostics[0].code, content="UNKNOWN_DATASET")
}

///|
fn artifact_by_id(exec : ProcessExecution, id : String) -> String {
  for a in exec.artifacts {
    if a.id == id {
      return a.content
    }
  }
  abort("artifact not found: " + id)
}
