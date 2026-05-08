///|
fn render_manifest_parse_error_json(message : String) -> String {
  let builder = StringBuilder::new()
  builder.write_string("{")
  builder.write_string("\"ok\":false,")
  builder.write_string("\"processId\":\"\",")
  builder.write_string("\"status\":\"failed\",")
  builder.write_string("\"diagnostics\":[")
  builder.write_string(render_process_diagnostic_json({
    source: "process",
    code: "INVALID_MANIFEST",
    severity: @vizprocess.ERROR,
    target: "$",
    message,
  }))
  builder.write_string("],\"artifacts\":[]}")
  builder.to_string()
}

///|
fn render_manifest_validation_json(
  execution : @vizprocess.ProcessExecution,
) -> String {
  let builder = StringBuilder::new()
  builder.write_string("{")
  builder.write_string("\"ok\":")
  builder.write_string(if execution.status == @vizprocess.EsSuccess { "true" } else { "false" })
  builder.write_string(",\"processId\":\"")
  write_process_json_escaped(builder, execution.process_id)
  builder.write_string("\",\"status\":\"")
  builder.write_string(render_execution_status(execution.status))
  builder.write_string("\",\"diagnostics\":")
  builder.write_string(render_process_diagnostics_json(execution.diagnostics))
  builder.write_string("}")
  builder.to_string()
}

///|
fn render_process_execution_json(
  execution : @vizprocess.ProcessExecution,
) -> String {
  let builder = StringBuilder::new()
  builder.write_string("{")
  builder.write_string("\"ok\":")
  builder.write_string(if execution.status == @vizprocess.EsSuccess { "true" } else { "false" })
  builder.write_string(",\"processId\":\"")
  write_process_json_escaped(builder, execution.process_id)
  builder.write_string("\",\"status\":\"")
  builder.write_string(render_execution_status(execution.status))
  builder.write_string("\",\"diagnostics\":")
  builder.write_string(render_process_diagnostics_json(execution.diagnostics))
  builder.write_string(",\"artifacts\":")
  builder.write_string(render_artifact_results_json(execution.artifacts))
  builder.write_char('}')
  builder.to_string()
}

///|
fn render_execution_status(status : @vizprocess.ExecutionStatus) -> String {
  match status {
    @vizprocess.EsSuccess => "success"
    @vizprocess.EsFailed => "failed"
  }
}

///|
fn render_process_diagnostics_json(
  diagnostics : Array[@vizprocess.Diagnostic],
) -> String {
  let builder = StringBuilder::new()
  builder.write_char('[')
  for i in 0..<diagnostics.length() {
    if i > 0 {
      builder.write_char(',')
    }
    builder.write_string(render_process_diagnostic_json(diagnostics[i]))
  }
  builder.write_char(']')
  builder.to_string()
}

///|
fn render_process_diagnostic_json(
  diagnostic : @vizprocess.Diagnostic,
) -> String {
  let builder = StringBuilder::new()
  builder.write_string("{\"source\":\"")
  write_process_json_escaped(builder, diagnostic.source)
  builder.write_string("\",\"code\":\"")
  write_process_json_escaped(builder, diagnostic.code)
  builder.write_string("\",\"severity\":\"")
  write_process_json_escaped(builder, render_process_severity(diagnostic.severity))
  builder.write_string("\",\"target\":\"")
  write_process_json_escaped(builder, diagnostic.target)
  builder.write_string("\",\"message\":\"")
  write_process_json_escaped(builder, diagnostic.message)
  builder.write_string("\"}")
  builder.to_string()
}

///|
fn render_process_severity(severity : @vizprocess.Severity) -> String {
  match severity {
    @vizprocess.ERROR => "error"
    @vizprocess.WARNING => "warning"
    @vizprocess.INFO => "info"
  }
}

///|
fn render_artifact_results_json(
  artifacts : Array[@vizprocess.ArtifactResult],
) -> String {
  let builder = StringBuilder::new()
  builder.write_char('[')
  for i in 0..<artifacts.length() {
    if i > 0 {
      builder.write_char(',')
    }
    let artifact = artifacts[i]
    builder.write_string("{\"id\":\"")
    write_process_json_escaped(builder, artifact.id)
    builder.write_string("\",\"kind\":\"")
    write_process_json_escaped(builder, render_artifact_kind(artifact.kind))
    builder.write_string("\",\"content\":\"")
    write_process_json_escaped(builder, artifact.content)
    builder.write_string("\"}")
  }
  builder.write_char(']')
  builder.to_string()
}

///|
fn render_artifact_kind(kind : @vizprocess.ArtifactKind) -> String {
  match kind {
    @vizprocess.AkSvg => "svg"
    @vizprocess.AkRenderModelJson => "render-model-json"
    @vizprocess.AkDatasetJson => "dataset-json"
  }
}

///|
fn write_process_json_escaped(buf : StringBuilder, s : String) -> Unit {
  for ch in s {
    match ch {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      '\u{08}' => buf.write_string("\\b")
      '\u{0c}' => buf.write_string("\\f")
      _ => {
        let code = ch.to_int()
        if code >= 0 && code < 0x20 {
          buf.write_string("\\u")
          buf.write_string(hex_digit((code / 0x1000) % 0x10))
          buf.write_string(hex_digit((code / 0x100) % 0x10))
          buf.write_string(hex_digit((code / 0x10) % 0x10))
          buf.write_string(hex_digit(code % 0x10))
        } else {
          buf.write_char(ch)
        }
      }
    }
  }
}

///|
fn hex_digit(value : Int) -> String {
  let digits = "0123456789abcdef"
  digits[value].to_string()
}
