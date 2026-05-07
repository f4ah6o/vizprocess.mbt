///|
/// Diagnostic severity.
pub enum Severity {
  ERROR
  WARNING
  INFO
} derive(Eq, Show)

///|
/// Structured diagnostic shared across all packages. `code` is a stable
/// machine-readable identifier; `target` points at the offending element
/// (e.g. "steps[2].field"). `message` is human-readable.
pub struct Diagnostic {
  code : String
  severity : Severity
  target : String
  message : String
} derive(Eq, Show)

///|
pub fn Diagnostic::error(
  code : String,
  target : String,
  message : String,
) -> Diagnostic {
  { code, severity: ERROR, target, message }
}

///|
/// Stable diagnostic codes (subset for M1).
pub let code_field_not_found : String = "FIELD_NOT_FOUND"

///|
pub let code_field_type_mismatch : String = "FIELD_TYPE_MISMATCH"

///|
pub let code_invalid_pipeline_step : String = "INVALID_PIPELINE_STEP"

///|
pub let code_schema_mismatch : String = "SCHEMA_MISMATCH"
