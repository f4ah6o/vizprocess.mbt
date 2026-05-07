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
test "golden: bar chart SVG" {
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
  let svg = render_svg(result.model)
  let expected =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="480" height="240"><g><rect x="42" y="45" width="206" height="175"/><rect x="252" y="20" width="206" height="200"/></g></svg>
  inspect(svg, content=expected)
}

///|
test "golden: line chart SVG" {
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
  let svg = render_svg(result.model)
  // The line spans the plot area: 3 points evenly across a 160px-wide
  // band (220 - 40 - 20 = 160), heights scaled against y_max=100 over the
  // 80px-tall plot (120 - 20 - 20 = 80).
  let expected =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="220" height="120"><g><polyline points="40,100 120,60 200,20" fill="none" stroke="black"/></g></svg>
  inspect(svg, content=expected)
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
