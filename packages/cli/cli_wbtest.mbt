///|
test "build_sales_bar_process consumes inline CSV" {
  let csv =
    #|month,region,amount
    #|2026-01,JP,100
    #|
  let (process, parse_diags) = build_sales_bar_process(csv)
  inspect(parse_diags.length(), content="0")
  inspect(process.id, content="monthly-sales")
  inspect(process.artifacts.length(), content="3")
}

///|
test "golden: success status JSON" {
  let csv =
    #|month,region,amount
    #|2026-01,JP,100
    #|2026-01,US,50
    #|2026-02,JP,200
    #|2026-02,US,150
    #|2026-01,JP,75
    #|
  let (process, _) = build_sales_bar_process(csv)
  let exec = @vizprocess.run_process(process)
  let paths : Map[String, String] = Map::new()
  paths["dataset"] = "out/dataset.dataset.json"
  paths["model"] = "out/model.render-model.json"
  paths["svg"] = "out/svg.svg"
  let json = format_status_json(exec, paths)
  let expected =
    #|{"artifacts":[{"id":"dataset","kind":"dataset-json","path":"out/dataset.dataset.json"},{"id":"model","kind":"render-model-json","path":"out/model.render-model.json"},{"id":"svg","kind":"svg","path":"out/svg.svg"}],"diagnostics":[],"ok":true,"processId":"monthly-sales","status":"success"}
  inspect(json, content=expected)
}

///|
test "artifact_extension covers every kind" {
  inspect(artifact_extension(AkSvg), content=".svg")
  inspect(artifact_extension(AkRenderModelJson), content=".render-model.json")
  inspect(artifact_extension(AkDatasetJson), content=".dataset.json")
}
