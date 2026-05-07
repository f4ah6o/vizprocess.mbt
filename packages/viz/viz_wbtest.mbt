///|
test "golden: bar chart RenderModel JSON" {
  let dataset : VizDataset = {
    fields: ["month", "total"],
    rows: [
      [VsString("2026-01"), VsInt(175L)],
      [VsString("2026-02"), VsInt(200L)],
    ],
  }
  let spec : ChartSpec = {
    id: "sales-bar",
    mark: BAR,
    encoding: { x: Some({ field: "month" }), y: Some({ field: "total" }) },
    config: ChartConfig::default(),
  }
  let result = compile_chart(spec, dataset)
  inspect(result.diagnostics.length(), content="0")
  let json = render_json(result.model)
  let expected =
    #|{"height":240,"id":"sales-bar","layers":[{"kind":"rect","marks":[{"height":175,"label":"2026-01","width":206,"x":42,"y":45},{"height":200,"label":"2026-02","width":206,"x":252,"y":20}]}],"width":480}
  inspect(json, content=expected)
}

///|
test "validate_chart reports missing field" {
  let dataset : VizDataset = { fields: ["month"], rows: [] }
  let spec : ChartSpec = {
    id: "x",
    mark: BAR,
    encoding: { x: Some({ field: "month" }), y: Some({ field: "missing" }) },
    config: ChartConfig::default(),
  }
  let diags = validate_chart(spec, dataset)
  inspect(diags.length(), content="1")
  inspect(diags[0].code, content="FIELD_NOT_FOUND")
}

///|
test "line mark places one point per row" {
  let dataset : VizDataset = {
    fields: ["t", "v"],
    rows: [
      [VsString("a"), VsInt(0L)],
      [VsString("b"), VsInt(50L)],
      [VsString("c"), VsInt(100L)],
    ],
  }
  let spec : ChartSpec = {
    id: "trend",
    mark: LINE,
    encoding: { x: Some({ field: "t" }), y: Some({ field: "v" }) },
    config: { width: 220, height: 120 },
  }
  let result = compile_chart(spec, dataset)
  inspect(result.diagnostics.length(), content="0")
  match result.model.layers[0] {
    LineLayer(points) => inspect(points.length(), content="3")
    _ => abort("expected LineLayer")
  }
}
