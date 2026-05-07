///|
test "build_process_from_json: full sales-bar manifest with inline csv" {
  let manifest =
    #|{
    #|  "id": "monthly-sales",
    #|  "datasets": [
    #|    {
    #|      "id": "monthly_sales",
    #|      "source": {
    #|        "kind": "csv-inline",
    #|        "data": "month,region,amount\n2026-01,JP,100\n2026-01,US,50\n2026-02,JP,200\n2026-02,US,150\n2026-01,JP,75\n",
    #|        "schema": {
    #|          "fields": [
    #|            {"name": "month", "dtype": "string"},
    #|            {"name": "region", "dtype": "string"},
    #|            {"name": "amount", "dtype": "int"}
    #|          ]
    #|        }
    #|      },
    #|      "pipeline": {
    #|        "steps": [
    #|          {"type": "select", "fields": ["month", "region", "amount"]},
    #|          {"type": "filter", "field": "region", "op": "eq",
    #|           "value": {"dtype": "string", "v": "JP"}},
    #|          {"type": "aggregate", "group_by": ["month"],
    #|           "measures": [{"field": "amount", "op": "sum", "as": "total"}]}
    #|        ]
    #|      }
    #|    }
    #|  ],
    #|  "charts": [
    #|    {"id": "sales-bar", "dataset_id": "monthly_sales",
    #|     "spec": {"id": "sales-bar", "mark": "bar",
    #|              "encoding": {"x": {"field": "month"},
    #|                           "y": {"field": "total"}},
    #|              "config": {"width": 480, "height": 240}}}
    #|  ],
    #|  "artifacts": [
    #|    {"id": "svg", "kind": "svg", "chart_id": "sales-bar"}
    #|  ]
    #|}
  let reader : (String) -> Result[String, String] = fn(_p) {
    Err("csv-file not used in this test")
  }
  let runner : (String, String, @pipe.DataSchema) -> Result[
    @pipe.Dataset,
    String,
  ] = fn(_db, _sql, _schema) { Err("duckdb not used in this test") }
  let process = match build_process_from_json(manifest, reader, runner) {
    Ok(p) => p
    Err(e) => abort("parse failed: " + e)
  }
  inspect(process.id, content="monthly-sales")
  inspect(process.datasets.length(), content="1")
  inspect(process.charts.length(), content="1")
  inspect(process.artifacts.length(), content="1")
  let exec = run_process(process)
  inspect(exec.diagnostics.length(), content="0")
  let svg = exec.artifacts[0].content
  let expected =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="480" height="240"><g><rect x="42" y="45" width="206" height="175"/><rect x="252" y="20" width="206" height="200"/></g></svg>
  inspect(svg, content=expected)
}

///|
test "build_process_from_json reports unknown filter op" {
  let manifest =
    #|{
    #|  "id": "x",
    #|  "datasets": [{
    #|    "id": "d",
    #|    "source": {"kind": "csv-inline", "data": "a\n",
    #|               "schema": {"fields": [{"name": "a", "dtype": "string"}]}},
    #|    "pipeline": {"steps": [{"type": "filter", "field": "a", "op": "lt",
    #|      "value": {"dtype": "string", "v": "x"}}]}
    #|  }],
    #|  "charts": [],
    #|  "artifacts": []
    #|}
  let reader : (String) -> Result[String, String] = fn(_) { Err("unused") }
  let runner : (String, String, @pipe.DataSchema) -> Result[
    @pipe.Dataset,
    String,
  ] = fn(_db, _sql, _schema) { Err("unused") }
  let result = build_process_from_json(manifest, reader, runner)
  match result {
    Err(e) => inspect(e.contains("unknown filter op 'lt'"), content="true")
    Ok(_) => abort("expected Err")
  }
}

///|
test "build_process_from_json invokes duckdb runner for duckdb source" {
  let manifest =
    #|{
    #|  "id": "x",
    #|  "datasets": [{
    #|    "id": "d",
    #|    "source": {"kind": "duckdb", "db": "file.db",
    #|               "sql": "SELECT 1 AS x",
    #|               "schema": {"fields": [{"name": "x", "dtype": "int"}]}},
    #|    "pipeline": {"steps": []}
    #|  }],
    #|  "charts": [],
    #|  "artifacts": []
    #|}
  let captured_db : Ref[String] = { val: "" }
  let captured_sql : Ref[String] = { val: "" }
  let reader : (String) -> Result[String, String] = fn(_) { Err("unused") }
  let runner : (String, String, @pipe.DataSchema) -> Result[
    @pipe.Dataset,
    String,
  ] = fn(db, sql, schema) {
    captured_db.val = db
    captured_sql.val = sql
    let cols : Map[String, Array[@pipe.Value]] = Map::new()
    cols["x"] = [@pipe.VInt(42L)]
    Ok({ schema, columns: cols, n_rows: 1 })
  }
  let result = build_process_from_json(manifest, reader, runner)
  match result {
    Ok(p) => {
      inspect(captured_db.val, content="file.db")
      inspect(captured_sql.val, content="SELECT 1 AS x")
      inspect(p.datasets[0].source.n_rows, content="1")
    }
    Err(e) => abort("parse failed: " + e)
  }
}

///|
test "build_process_from_json invokes csv reader for csv-file source" {
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
  let captured : Ref[String] = { val: "" }
  let reader : (String) -> Result[String, String] = fn(p) {
    captured.val = p
    Ok("x\nhello\n")
  }
  let runner : (String, String, @pipe.DataSchema) -> Result[
    @pipe.Dataset,
    String,
  ] = fn(_db, _sql, _schema) { Err("unused") }
  let result = build_process_from_json(manifest, reader, runner)
  match result {
    Ok(_) => inspect(captured.val, content="data.csv")
    Err(e) => abort("parse failed: " + e)
  }
}
