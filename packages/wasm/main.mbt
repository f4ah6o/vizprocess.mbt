///|
/// Required main for an `is-main` package; the wasm bridge is exposed
/// through the `pub` exports below, not through a runtime entry point.
fn main {

}

///|
pub fn version() -> String {
  "0.1.0"
}

///|
/// Browser entry point: take a JSON process manifest, run the embedded
/// pipeline + chart, and return the resulting SVG (or a JSON status
/// envelope on error).
///
/// Limitations in M7:
///
/// - Only `csv-inline` sources are supported. `csv-file` requires a
///   browser-side reader (OPFS / fetch); pass it via a future
///   JS-bound reader hook.
/// - `duckdb` sources are not wired in this build. DuckDB-WASM
///   integration is M7.5+.
///
/// Output is a single SVG string for the first artifact whose kind is
/// `svg`. If no SVG artifact is declared, returns the empty string.
pub fn manifest_to_svg(json_text : String) -> String {
  let csv_reader : (String) -> Result[String, String] = fn(_path) {
    Err("csv-file is not supported in this wasm build; use csv-inline")
  }
  let duckdb_runner : (String, String, @pipe.DataSchema) -> Result[
    @pipe.Dataset,
    String,
  ] = fn(_db, _sql, _schema) {
    Err("duckdb sources are not wired in this wasm build (M7.5+)")
  }
  let process = match
    @vizprocess.build_process_from_json(json_text, csv_reader, duckdb_runner) {
    Ok(p) => p
    Err(e) => return error_envelope("invalid manifest: " + e)
  }
  let exec = @vizprocess.run_process(process)
  if exec.diagnostics.length() > 0 {
    return error_envelope("process failed with diagnostics")
  }
  for a in exec.artifacts {
    if a.kind == @vizprocess.AkSvg {
      return a.content
    }
  }
  ""
}

///|
/// Browser/Worker entry point: validate a resolved manifest and return
/// diagnostics without needing browser-local readers in the worker.
pub fn manifest_to_validation_json(json_text : String) -> String {
  let process = match build_inline_process(json_text) {
    Ok(process) => process
    Err(message) => return render_manifest_parse_error_json(message)
  }
  let execution = @vizprocess.run_process(process)
  render_manifest_validation_json(execution)
}

///|
/// Browser/Worker entry point: execute a resolved manifest and return the
/// full structured process result with diagnostics and artifact contents.
pub fn manifest_to_render_result_json(json_text : String) -> String {
  let process = match build_inline_process(json_text) {
    Ok(process) => process
    Err(message) => return render_manifest_parse_error_json(message)
  }
  let execution = @vizprocess.run_process(process)
  render_process_execution_json(execution)
}

///|
/// Legacy single-SVG helper kept for direct wasm embedding. The Worker/editor
/// path uses `manifest_to_validation_json` and `manifest_to_render_result_json`;
/// `error_envelope` remains only for this compatibility surface.
fn error_envelope(message : String) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!-- vizprocess error: ")
  for ch in message {
    if ch == '<' {
      buf.write_string("&lt;")
    } else if ch == '>' {
      buf.write_string("&gt;")
    } else if ch == '&' {
      buf.write_string("&amp;")
    } else {
      buf.write_char(ch)
    }
  }
  buf.write_string(" -->")
  buf.to_string()
}

///|
fn build_inline_process(
  json_text : String,
) -> Result[@vizprocess.VizProcess, String] {
  let csv_reader : (String) -> Result[String, String] = fn(_path) {
    Err(
      "csv-file is not supported in this worker/api path; resolve to csv-inline first",
    )
  }
  let duckdb_runner : (String, String, @pipe.DataSchema) -> Result[
    @pipe.Dataset,
    String,
  ] = fn(_db, _sql, _schema) {
    Err(
      "duckdb sources are not supported in this worker/api path; resolve to csv-inline first",
    )
  }
  @vizprocess.build_process_from_json(json_text, csv_reader, duckdb_runner)
}
