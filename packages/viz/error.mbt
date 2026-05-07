///|
pub enum Severity {
  ERROR
  WARNING
  INFO
} derive(Eq, Show)

///|
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
pub let code_field_not_found : String = "FIELD_NOT_FOUND"

///|
pub let code_field_type_mismatch : String = "FIELD_TYPE_MISMATCH"

///|
pub let code_invalid_encoding : String = "INVALID_ENCODING"

///|
pub let code_invalid_mark : String = "INVALID_MARK"
