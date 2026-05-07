///|
/// Exit codes per the project spec (§20). Kept as separate `let`s so
/// callers can reference them by name and tests can assert against them.
pub let exit_ok : Int = 0

///|
pub let exit_unexpected : Int = 1

///|
pub let exit_invalid_input : Int = 2

///|
pub let exit_validation_failed : Int = 3

///|
pub let exit_source_read_failed : Int = 4

///|
pub let exit_artifact_write_failed : Int = 5

///|
/// Build the M4 hardcoded sales-bar process from a CSV string. Until the
/// full manifest JSON loader lands (M5b), this is the one process the
/// CLI knows how to drive.
pub fn build_sales_bar_process(
  csv_text : String,
) -> (@vizprocess.VizProcess, Array[@pipe.Diagnostic]) {
  let schema : @pipe.DataSchema = {
    fields: [
      { name: "month", dtype: @pipe.TString },
      { name: "region", dtype: @pipe.TString },
      { name: "amount", dtype: @pipe.TInt },
    ],
  }
  let (raw_dataset, parse_diags) = @pipe.parse_csv(csv_text, schema)
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
  let process : @vizprocess.VizProcess = {
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
  (process, parse_diags)
}

///|
/// File extension matching each `ArtifactKind`. Used to build output
/// paths under the user's `<output-dir>`.
pub fn artifact_extension(kind : @vizprocess.ArtifactKind) -> String {
  match kind {
    AkSvg => ".svg"
    AkRenderModelJson => ".render-model.json"
    AkDatasetJson => ".dataset.json"
  }
}

///|
/// Render the CLI status JSON. Keys are sorted alphabetically so output
/// is byte-stable. `artifact_paths` maps artifact id → path-on-disk that
/// the CLI wrote (or the literal "memory" if the artifact stayed in
/// memory).
pub fn format_status_json(
  exec : @vizprocess.ProcessExecution,
  artifact_paths : Map[String, String],
) -> String {
  let buf = StringBuilder::new()
  buf.write_string("{\"artifacts\":[")
  let ids : Array[String] = []
  for a in exec.artifacts {
    ids.push(a.id)
  }
  sort_strings(ids)
  for i in 0..<ids.length() {
    if i > 0 {
      buf.write_char(',')
    }
    let id = ids[i]
    let kind = artifact_kind_by_id(exec, id).unwrap()
    let path = match artifact_paths.get(id) {
      Some(p) => p
      None => "memory"
    }
    buf.write_string("{\"id\":\"")
    write_json_escaped(buf, id)
    buf.write_string("\",\"kind\":\"")
    buf.write_string(artifact_kind_name(kind))
    buf.write_string("\",\"path\":\"")
    write_json_escaped(buf, path)
    buf.write_string("\"}")
  }
  buf.write_string("],\"diagnostics\":[")
  for i in 0..<exec.diagnostics.length() {
    if i > 0 {
      buf.write_char(',')
    }
    let d = exec.diagnostics[i]
    buf.write_string("{\"code\":\"")
    write_json_escaped(buf, d.code)
    buf.write_string("\",\"message\":\"")
    write_json_escaped(buf, d.message)
    buf.write_string("\",\"severity\":\"")
    buf.write_string(severity_name(d.severity))
    buf.write_string("\",\"source\":\"")
    write_json_escaped(buf, d.source)
    buf.write_string("\",\"target\":\"")
    write_json_escaped(buf, d.target)
    buf.write_string("\"}")
  }
  buf.write_string("],\"ok\":")
  buf.write_string(
    if exec.status == @vizprocess.EsSuccess {
      "true"
    } else {
      "false"
    },
  )
  buf.write_string(",\"processId\":\"")
  write_json_escaped(buf, exec.process_id)
  buf.write_string("\",\"status\":\"")
  buf.write_string(execution_status_name(exec.status))
  buf.write_string("\"}")
  buf.to_string()
}

///|
fn artifact_kind_by_id(
  exec : @vizprocess.ProcessExecution,
  id : String,
) -> @vizprocess.ArtifactKind? {
  for a in exec.artifacts {
    if a.id == id {
      return Some(a.kind)
    }
  }
  None
}

///|
fn artifact_kind_name(kind : @vizprocess.ArtifactKind) -> String {
  match kind {
    AkSvg => "svg"
    AkRenderModelJson => "render-model-json"
    AkDatasetJson => "dataset-json"
  }
}

///|
fn execution_status_name(status : @vizprocess.ExecutionStatus) -> String {
  match status {
    EsSuccess => "success"
    EsFailed => "failed"
  }
}

///|
fn severity_name(s : @vizprocess.Severity) -> String {
  match s {
    ERROR => "error"
    WARNING => "warning"
    INFO => "info"
  }
}

///|
fn write_json_escaped(buf : StringBuilder, s : String) -> Unit {
  for ch in s {
    match ch {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(ch)
    }
  }
}

///|
fn sort_strings(arr : Array[String]) -> Unit {
  let n = arr.length()
  for i in 1..<n {
    let cur = arr[i]
    let mut j = i
    while j > 0 && lex_compare(arr[j - 1], cur) > 0 {
      arr[j] = arr[j - 1]
      j = j - 1
    }
    arr[j] = cur
  }
}

///|
/// Compare two strings lexicographically by code unit. Returns -1, 0, or 1.
/// MoonBit's `<` / `>` on String compares by length, not lexicographically.
fn lex_compare(a : String, b : String) -> Int {
  let la = a.length()
  let lb = b.length()
  let mut i = 0
  while i < la && i < lb {
    let ca = a[i].to_int()
    let cb = b[i].to_int()
    if ca < cb {
      return -1
    }
    if ca > cb {
      return 1
    }
    i = i + 1
  }
  if la < lb {
    return -1
  }
  if la > lb {
    return 1
  }
  0
}
