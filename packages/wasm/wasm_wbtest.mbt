///|
test "manifest_to_svg returns svg from csv-inline manifest" {
  let manifest =
    #|{
    #|  "id": "x",
    #|  "datasets": [{
    #|    "id": "d",
    #|    "source": {"kind": "csv-inline",
    #|               "data": "month,region,amount\n2026-01,JP,100\n2026-01,US,50\n2026-02,JP,200\n2026-02,US,150\n2026-01,JP,75\n",
    #|               "schema": {"fields": [
    #|                 {"name": "month", "dtype": "string"},
    #|                 {"name": "region", "dtype": "string"},
    #|                 {"name": "amount", "dtype": "int"}]}},
    #|    "pipeline": {"steps": [
    #|      {"type": "filter", "field": "region", "op": "eq",
    #|       "value": {"dtype": "string", "v": "JP"}},
    #|      {"type": "aggregate", "group_by": ["month"],
    #|       "measures": [{"field": "amount", "op": "sum", "as": "total"}]}
    #|    ]}
    #|  }],
    #|  "charts": [{
    #|    "id": "c", "dataset_id": "d",
    #|    "spec": {"id": "sales-bar", "mark": "bar",
    #|             "encoding": {"x": {"field": "month"},
    #|                          "y": {"field": "total"}},
    #|             "config": {"width": 480, "height": 240}}
    #|  }],
    #|  "artifacts": [{"id": "svg", "kind": "svg", "chart_id": "c"}]
    #|}
  let svg = manifest_to_svg(manifest)
  let expected =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="480" height="240"><g><rect x="42" y="45" width="206" height="175"/><rect x="252" y="20" width="206" height="200"/></g></svg>
  inspect(svg, content=expected)
}

///|
test "manifest_to_svg embeds error in HTML comment on bad manifest" {
  let svg = manifest_to_svg("{}")
  inspect(svg.contains("vizprocess error"), content="true")
}

///|
test "manifest_to_svg rejects csv-file with helpful message" {
  let manifest =
    #|{
    #|  "id": "x",
    #|  "datasets": [{
    #|    "id": "d",
    #|    "source": {"kind": "csv-file", "path": "data.csv",
    #|               "schema": {"fields": [{"name": "x", "dtype": "string"}]}},
    #|    "pipeline": {"steps": []}
    #|  }],
    #|  "charts": [],
    #|  "artifacts": []
    #|}
  let svg = manifest_to_svg(manifest)
  inspect(svg.contains("csv-file is not supported"), content="true")
}
