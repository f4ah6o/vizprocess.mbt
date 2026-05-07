///|
pub(all) enum Severity {
  ERROR
  WARNING
  INFO
} derive(Eq, Show)

///|
/// vizprocess diagnostics carry the originating layer in `source` so the
/// final report can surface where each issue came from. M4 source values
/// are "pipe", "viz", and "process".
pub(all) struct Diagnostic {
  source : String
  code : String
  severity : Severity
  target : String
  message : String
} derive(Eq, Show)

///|
pub fn Diagnostic::process_error(
  code : String,
  target : String,
  message : String,
) -> Diagnostic {
  { source: "process", code, severity: ERROR, target, message }
}

///|
pub fn Diagnostic::from_pipe(d : @pipe.Diagnostic) -> Diagnostic {
  let sev = match d.severity {
    @pipe.ERROR => ERROR
    @pipe.WARNING => WARNING
    @pipe.INFO => INFO
  }
  {
    source: "pipe",
    code: d.code,
    severity: sev,
    target: d.target,
    message: d.message,
  }
}

///|
pub fn Diagnostic::from_viz(d : @viz.Diagnostic) -> Diagnostic {
  let sev = match d.severity {
    @viz.ERROR => ERROR
    @viz.WARNING => WARNING
    @viz.INFO => INFO
  }
  {
    source: "viz",
    code: d.code,
    severity: sev,
    target: d.target,
    message: d.message,
  }
}

///|
pub let code_unknown_dataset : String = "UNKNOWN_DATASET"

///|
pub let code_unknown_chart : String = "UNKNOWN_CHART"

///|
pub let code_pipeline_failed : String = "PIPELINE_FAILED"

///|
pub let code_chart_compile_failed : String = "CHART_COMPILE_FAILED"
