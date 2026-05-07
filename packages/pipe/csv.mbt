///|
/// Parse a CSV string into a `Dataset` using `schema` to type each column.
/// M1 supports the unquoted comma-separated subset only:
///
/// - first line is the header
/// - each remaining non-empty line is a row
/// - fields are split on `,` (no quote / escape handling)
/// - integer columns go through `parse_int64`; string columns keep the
///   literal text
///
/// Header order does not need to match `schema`; columns are matched by
/// name. A missing schema field, or a row with a different column count,
/// produces a `SCHEMA_MISMATCH` diagnostic and an empty dataset.
pub fn parse_csv(
  text : String,
  schema : DataSchema,
) -> (Dataset, Array[Diagnostic]) {
  let diags : Array[Diagnostic] = []
  let lines = split_lines(text)
  if lines.length() == 0 {
    return (Dataset::empty(schema), diags)
  }
  let header = split_comma(lines[0])
  for f in schema.fields {
    let mut found = false
    for h in header {
      if h == f.name {
        found = true
        break
      }
    }
    if !found {
      diags.push(
        Diagnostic::error(
          code_schema_mismatch,
          "csv.header",
          "header is missing field '" + f.name + "'",
        ),
      )
    }
  }
  if diags.length() > 0 {
    return (Dataset::empty(schema), diags)
  }
  let columns : Map[String, Array[Value]] = Map::new()
  for f in schema.fields {
    columns[f.name] = []
  }
  let mut n_rows = 0
  for i in 1..<lines.length() {
    let line = lines[i]
    if line.length() == 0 {
      continue
    }
    let cells = split_comma(line)
    if cells.length() != header.length() {
      diags.push(
        Diagnostic::error(
          code_schema_mismatch,
          "csv.row[" + i.to_string() + "]",
          "row has " +
          cells.length().to_string() +
          " columns, header has " +
          header.length().to_string(),
        ),
      )
      continue
    }
    for f in schema.fields {
      let mut idx = -1
      for j in 0..<header.length() {
        if header[j] == f.name {
          idx = j
          break
        }
      }
      let raw = cells[idx]
      let value = match f.dtype {
        TString => VString(raw)
        TInt =>
          match parse_int64(raw) {
            Some(n) => VInt(n)
            None => {
              diags.push(
                Diagnostic::error(
                  code_field_type_mismatch,
                  "csv.row[" + i.to_string() + "]." + f.name,
                  "cannot parse '" + raw + "' as int",
                ),
              )
              VNull
            }
          }
      }
      columns.get(f.name).unwrap().push(value)
    }
    n_rows = n_rows + 1
  }
  ({ schema, columns, n_rows }, diags)
}

///|
/// Parse a base-10 signed Int64. Returns None on any non-digit character or
/// empty input. Local helper so `pipe` does not depend on `core/strconv`.
pub fn parse_int64(s : String) -> Int64? {
  if s.length() == 0 {
    return None
  }
  let mut i = 0
  let mut sign = 1L
  if s[0] == '-' {
    sign = -1L
    i = 1
  } else if s[0] == '+' {
    i = 1
  }
  if i >= s.length() {
    return None
  }
  let mut acc = 0L
  while i < s.length() {
    let c = s[i]
    if c >= '0' && c <= '9' {
      acc = acc * 10L + (c.to_int() - '0'.to_int()).to_int64()
    } else {
      return None
    }
    i = i + 1
  }
  Some(acc * sign)
}

///|
fn split_lines(source : String) -> Array[String] {
  let lines : Array[String] = []
  let buf = StringBuilder::new()
  for ch in source {
    if ch == '\n' {
      let line = buf.to_string()
      let trimmed = if line.length() > 0 &&
        line[line.length() - 1].to_int().unsafe_to_char() == '\r' {
        line[:line.length() - 1].to_string()
      } else {
        line
      }
      lines.push(trimmed)
      buf.reset()
    } else {
      buf.write_char(ch)
    }
  }
  let tail = buf.to_string()
  if tail.length() > 0 {
    lines.push(tail)
  }
  lines
}

///|
fn split_comma(line : String) -> Array[String] {
  let parts : Array[String] = []
  let buf = StringBuilder::new()
  for ch in line {
    if ch == ',' {
      parts.push(buf.to_string())
      buf.reset()
    } else {
      buf.write_char(ch)
    }
  }
  parts.push(buf.to_string())
  parts
}
