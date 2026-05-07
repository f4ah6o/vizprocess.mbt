///|
/// Parse a JSON manifest and resolve every `csv-file` source via
/// `csv_reader`, returning a runnable `VizProcess`. Errors carry a
/// human-readable path-prefixed message ("datasets[0].pipeline.steps[1]:
/// unknown filter op 'foo'").
///
/// Manifest shape (M5b minimum):
///
/// ```json
/// {
///   "id": "monthly-sales",
///   "datasets": [
///     {
///       "id": "monthly_sales",
///       "source": {
///         "kind": "csv-file",   // or "csv-inline"
///         "path": "fixtures/datasets/sales.csv",
///         "schema": {
///           "fields": [
///             {"name": "month", "dtype": "string"},
///             {"name": "amount", "dtype": "int"}
///           ]
///         }
///       },
///       "pipeline": {
///         "steps": [
///           {"type": "select", "fields": ["month", "amount"]},
///           {"type": "filter", "field": "region", "op": "eq",
///            "value": {"dtype": "string", "v": "JP"}},
///           {"type": "aggregate", "group_by": ["month"],
///            "measures": [{"field": "amount", "op": "sum", "as": "total"}]}
///         ]
///       }
///     }
///   ],
///   "charts": [
///     {"id": "sales-bar", "dataset_id": "monthly_sales",
///      "spec": {"id": "sales-bar", "mark": "bar",
///               "encoding": {"x": {"field": "month"},
///                            "y": {"field": "total"}},
///               "config": {"width": 480, "height": 240}}}
///   ],
///   "artifacts": [
///     {"id": "svg", "kind": "svg", "chart_id": "sales-bar"}
///   ]
/// }
/// ```
pub fn build_process_from_json(
  json_text : String,
  csv_reader : (String) -> Result[String, String],
) -> Result[VizProcess, String] {
  let parsed : Result[Json, _] = try? @json.parse(json_text)
  let root = match parsed {
    Ok(j) => j
    Err(e) => return Err("invalid json: " + e.to_string())
  }
  let obj = match root {
    Json::Object(m) => m
    _ => return Err("$: expected object")
  }
  let id = match expect_string(obj, "id", "$.id") {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let datasets : Array[DatasetNode] = []
  let raw_datasets = match expect_array(obj, "datasets", "$.datasets") {
    Ok(a) => a
    Err(e) => return Err(e)
  }
  for i in 0..<raw_datasets.length() {
    let prefix = "$.datasets[" + i.to_string() + "]"
    match parse_dataset_node(raw_datasets[i], prefix, csv_reader) {
      Ok(node) => datasets.push(node)
      Err(e) => return Err(e)
    }
  }
  let charts : Array[ChartNode] = []
  let raw_charts = match expect_array(obj, "charts", "$.charts") {
    Ok(a) => a
    Err(e) => return Err(e)
  }
  for i in 0..<raw_charts.length() {
    let prefix = "$.charts[" + i.to_string() + "]"
    match parse_chart_node(raw_charts[i], prefix) {
      Ok(node) => charts.push(node)
      Err(e) => return Err(e)
    }
  }
  let artifacts : Array[ArtifactNode] = []
  let raw_artifacts = match expect_array(obj, "artifacts", "$.artifacts") {
    Ok(a) => a
    Err(e) => return Err(e)
  }
  for i in 0..<raw_artifacts.length() {
    let prefix = "$.artifacts[" + i.to_string() + "]"
    match parse_artifact_node(raw_artifacts[i], prefix) {
      Ok(node) => artifacts.push(node)
      Err(e) => return Err(e)
    }
  }
  Ok({ id, datasets, charts, artifacts })
}

///|
fn parse_dataset_node(
  json : Json,
  prefix : String,
  csv_reader : (String) -> Result[String, String],
) -> Result[DatasetNode, String] {
  let obj = match json {
    Json::Object(m) => m
    _ => return Err(prefix + ": expected object")
  }
  let id = match expect_string(obj, "id", prefix + ".id") {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let source_json = match obj.get("source") {
    Some(j) => j
    None => return Err(prefix + ".source: missing")
  }
  let (csv_text, schema) = match
    parse_source(source_json, prefix + ".source", csv_reader) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (raw_dataset, parse_diags) = @pipe.parse_csv(csv_text, schema)
  if parse_diags.length() > 0 {
    return Err(
      prefix +
      ".source: csv parse produced " +
      parse_diags.length().to_string() +
      " diagnostic(s); first: " +
      parse_diags[0].message,
    )
  }
  let pipeline_json = match obj.get("pipeline") {
    Some(j) => j
    None => return Err(prefix + ".pipeline: missing")
  }
  let pipeline = match parse_pipeline(pipeline_json, prefix + ".pipeline") {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  Ok({ id, source: raw_dataset, pipeline })
}

///|
fn parse_source(
  json : Json,
  prefix : String,
  csv_reader : (String) -> Result[String, String],
) -> Result[(String, @pipe.DataSchema), String] {
  let obj = match json {
    Json::Object(m) => m
    _ => return Err(prefix + ": expected object")
  }
  let kind = match expect_string(obj, "kind", prefix + ".kind") {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let schema_json = match obj.get("schema") {
    Some(j) => j
    None => return Err(prefix + ".schema: missing")
  }
  let schema = match parse_schema(schema_json, prefix + ".schema") {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  match kind {
    "csv-file" => {
      let path = match expect_string(obj, "path", prefix + ".path") {
        Ok(s) => s
        Err(e) => return Err(e)
      }
      match csv_reader(path) {
        Ok(text) => Ok((text, schema))
        Err(e) => Err(prefix + ".path: cannot read '" + path + "': " + e)
      }
    }
    "csv-inline" => {
      let data = match expect_string(obj, "data", prefix + ".data") {
        Ok(s) => s
        Err(e) => return Err(e)
      }
      Ok((data, schema))
    }
    _ => Err(prefix + ".kind: unknown source kind '" + kind + "'")
  }
}

///|
fn parse_schema(
  json : Json,
  prefix : String,
) -> Result[@pipe.DataSchema, String] {
  let obj = match json {
    Json::Object(m) => m
    _ => return Err(prefix + ": expected object")
  }
  let raw_fields = match expect_array(obj, "fields", prefix + ".fields") {
    Ok(a) => a
    Err(e) => return Err(e)
  }
  let fields : Array[@pipe.FieldSchema] = []
  for i in 0..<raw_fields.length() {
    let field_prefix = prefix + ".fields[" + i.to_string() + "]"
    let field_obj = match raw_fields[i] {
      Json::Object(m) => m
      _ => return Err(field_prefix + ": expected object")
    }
    let name = match expect_string(field_obj, "name", field_prefix + ".name") {
      Ok(s) => s
      Err(e) => return Err(e)
    }
    let dtype_str = match
      expect_string(field_obj, "dtype", field_prefix + ".dtype") {
      Ok(s) => s
      Err(e) => return Err(e)
    }
    let dtype = match dtype_str {
      "string" => @pipe.TString
      "int" => @pipe.TInt
      _ =>
        return Err(
          field_prefix + ".dtype: unsupported dtype '" + dtype_str + "'",
        )
    }
    fields.push({ name, dtype })
  }
  Ok({ fields, })
}

///|
fn parse_pipeline(
  json : Json,
  prefix : String,
) -> Result[@pipe.Pipeline, String] {
  let obj = match json {
    Json::Object(m) => m
    _ => return Err(prefix + ": expected object")
  }
  let raw_steps = match expect_array(obj, "steps", prefix + ".steps") {
    Ok(a) => a
    Err(e) => return Err(e)
  }
  let steps : Array[@pipe.PipeStep] = []
  for i in 0..<raw_steps.length() {
    let step_prefix = prefix + ".steps[" + i.to_string() + "]"
    match parse_step(raw_steps[i], step_prefix) {
      Ok(s) => steps.push(s)
      Err(e) => return Err(e)
    }
  }
  Ok({ steps, })
}

///|
fn parse_step(json : Json, prefix : String) -> Result[@pipe.PipeStep, String] {
  let obj = match json {
    Json::Object(m) => m
    _ => return Err(prefix + ": expected object")
  }
  let ty = match expect_string(obj, "type", prefix + ".type") {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  match ty {
    "select" => {
      let raw = match expect_array(obj, "fields", prefix + ".fields") {
        Ok(a) => a
        Err(e) => return Err(e)
      }
      let names : Array[String] = []
      for i in 0..<raw.length() {
        match raw[i] {
          Json::String(s) => names.push(s)
          _ =>
            return Err(
              prefix + ".fields[" + i.to_string() + "]: expected string",
            )
        }
      }
      Ok(Select(names))
    }
    "filter" => {
      let field = match expect_string(obj, "field", prefix + ".field") {
        Ok(s) => s
        Err(e) => return Err(e)
      }
      let op_str = match expect_string(obj, "op", prefix + ".op") {
        Ok(s) => s
        Err(e) => return Err(e)
      }
      let op = match op_str {
        "eq" => @pipe.EQ
        "ne" => @pipe.NE
        _ => return Err(prefix + ".op: unknown filter op '" + op_str + "'")
      }
      let value_json = match obj.get("value") {
        Some(j) => j
        None => return Err(prefix + ".value: missing")
      }
      let value = match parse_typed_value(value_json, prefix + ".value") {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(Filter(field, op, value))
    }
    "aggregate" => {
      let raw_groups = match
        expect_array(obj, "group_by", prefix + ".group_by") {
        Ok(a) => a
        Err(e) => return Err(e)
      }
      let group_by : Array[String] = []
      for i in 0..<raw_groups.length() {
        match raw_groups[i] {
          Json::String(s) => group_by.push(s)
          _ =>
            return Err(
              prefix + ".group_by[" + i.to_string() + "]: expected string",
            )
        }
      }
      let raw_measures = match
        expect_array(obj, "measures", prefix + ".measures") {
        Ok(a) => a
        Err(e) => return Err(e)
      }
      let measures : Array[@pipe.Measure] = []
      for i in 0..<raw_measures.length() {
        let m_prefix = prefix + ".measures[" + i.to_string() + "]"
        let m_obj = match raw_measures[i] {
          Json::Object(m) => m
          _ => return Err(m_prefix + ": expected object")
        }
        let m_field = match expect_string(m_obj, "field", m_prefix + ".field") {
          Ok(s) => s
          Err(e) => return Err(e)
        }
        let m_op = match expect_string(m_obj, "op", m_prefix + ".op") {
          Ok(s) => s
          Err(e) => return Err(e)
        }
        let op = match m_op {
          "sum" => @pipe.SUM
          "count" => @pipe.COUNT
          _ => return Err(m_prefix + ".op: unknown aggregate op '" + m_op + "'")
        }
        let m_as = match expect_string(m_obj, "as", m_prefix + ".as") {
          Ok(s) => s
          Err(e) => return Err(e)
        }
        measures.push({ field: m_field, op, as_: m_as })
      }
      Ok(Aggregate({ group_by, measures }))
    }
    _ => Err(prefix + ".type: unknown step type '" + ty + "'")
  }
}

///|
/// Parse `{"dtype": "...", "v": ...}` into a `pipe.Value`.
fn parse_typed_value(
  json : Json,
  prefix : String,
) -> Result[@pipe.Value, String] {
  let obj = match json {
    Json::Object(m) => m
    _ => return Err(prefix + ": expected object")
  }
  let dtype = match expect_string(obj, "dtype", prefix + ".dtype") {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let v_json = match obj.get("v") {
    Some(j) => j
    None => return Err(prefix + ".v: missing")
  }
  match dtype {
    "string" =>
      match v_json {
        Json::String(s) => Ok(@pipe.VString(s))
        _ => Err(prefix + ".v: expected string")
      }
    "int" =>
      match v_json {
        Json::Number(n) => Ok(@pipe.VInt(n.to_int64()))
        _ => Err(prefix + ".v: expected number")
      }
    _ => Err(prefix + ".dtype: unsupported value dtype '" + dtype + "'")
  }
}

///|
fn parse_chart_node(json : Json, prefix : String) -> Result[ChartNode, String] {
  let obj = match json {
    Json::Object(m) => m
    _ => return Err(prefix + ": expected object")
  }
  let id = match expect_string(obj, "id", prefix + ".id") {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let dataset_id = match
    expect_string(obj, "dataset_id", prefix + ".dataset_id") {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let spec_json = match obj.get("spec") {
    Some(j) => j
    None => return Err(prefix + ".spec: missing")
  }
  let spec = match parse_chart_spec(spec_json, prefix + ".spec") {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  Ok({ id, dataset_id, chart: spec })
}

///|
fn parse_chart_spec(
  json : Json,
  prefix : String,
) -> Result[@viz.ChartSpec, String] {
  let obj = match json {
    Json::Object(m) => m
    _ => return Err(prefix + ": expected object")
  }
  let id = match expect_string(obj, "id", prefix + ".id") {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let mark_str = match expect_string(obj, "mark", prefix + ".mark") {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let mark = match mark_str {
    "bar" => @viz.BAR
    "line" => @viz.LINE
    _ => return Err(prefix + ".mark: unknown mark '" + mark_str + "'")
  }
  let enc_json = match obj.get("encoding") {
    Some(j) => j
    None => return Err(prefix + ".encoding: missing")
  }
  let encoding = match parse_encoding(enc_json, prefix + ".encoding") {
    Ok(e) => e
    Err(e) => return Err(e)
  }
  let config_json = match obj.get("config") {
    Some(j) => j
    None => return Err(prefix + ".config: missing")
  }
  let config = match parse_chart_config(config_json, prefix + ".config") {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  Ok({ id, mark, encoding, config })
}

///|
fn parse_encoding(
  json : Json,
  prefix : String,
) -> Result[@viz.Encoding, String] {
  let obj = match json {
    Json::Object(m) => m
    _ => return Err(prefix + ": expected object")
  }
  let x = match obj.get("x") {
    None => None
    Some(j) =>
      match parse_channel(j, prefix + ".x") {
        Ok(c) => Some(c)
        Err(e) => return Err(e)
      }
  }
  let y = match obj.get("y") {
    None => None
    Some(j) =>
      match parse_channel(j, prefix + ".y") {
        Ok(c) => Some(c)
        Err(e) => return Err(e)
      }
  }
  Ok({ x, y })
}

///|
fn parse_channel(json : Json, prefix : String) -> Result[@viz.Channel, String] {
  let obj = match json {
    Json::Object(m) => m
    _ => return Err(prefix + ": expected object")
  }
  let field = match expect_string(obj, "field", prefix + ".field") {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  Ok({ field, })
}

///|
fn parse_chart_config(
  json : Json,
  prefix : String,
) -> Result[@viz.ChartConfig, String] {
  let obj = match json {
    Json::Object(m) => m
    _ => return Err(prefix + ": expected object")
  }
  let width = match expect_int(obj, "width", prefix + ".width") {
    Ok(n) => n
    Err(e) => return Err(e)
  }
  let height = match expect_int(obj, "height", prefix + ".height") {
    Ok(n) => n
    Err(e) => return Err(e)
  }
  Ok({ width, height })
}

///|
fn parse_artifact_node(
  json : Json,
  prefix : String,
) -> Result[ArtifactNode, String] {
  let obj = match json {
    Json::Object(m) => m
    _ => return Err(prefix + ": expected object")
  }
  let id = match expect_string(obj, "id", prefix + ".id") {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let kind_str = match expect_string(obj, "kind", prefix + ".kind") {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let kind = match kind_str {
    "svg" => AkSvg
    "render-model-json" => AkRenderModelJson
    "dataset-json" => AkDatasetJson
    _ => return Err(prefix + ".kind: unknown kind '" + kind_str + "'")
  }
  let chart_id = match expect_string(obj, "chart_id", prefix + ".chart_id") {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  Ok({ id, kind, chart_id, output: OtMemory })
}

///|
fn expect_string(
  obj : Map[String, Json],
  key : String,
  path : String,
) -> Result[String, String] {
  match obj.get(key) {
    Some(Json::String(s)) => Ok(s)
    Some(_) => Err(path + ": expected string")
    None => Err(path + ": missing")
  }
}

///|
fn expect_array(
  obj : Map[String, Json],
  key : String,
  path : String,
) -> Result[Array[Json], String] {
  match obj.get(key) {
    Some(Json::Array(a)) => Ok(a)
    Some(_) => Err(path + ": expected array")
    None => Err(path + ": missing")
  }
}

///|
fn expect_int(
  obj : Map[String, Json],
  key : String,
  path : String,
) -> Result[Int, String] {
  match obj.get(key) {
    Some(Json::Number(n)) => Ok(n.to_int())
    Some(_) => Err(path + ": expected number")
    None => Err(path + ": missing")
  }
}
