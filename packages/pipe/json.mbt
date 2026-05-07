///|
/// Render a `Dataset` as a deterministic JSON string. The shape is:
///
/// ```json
/// {
///   "rows": [
///     {"field_a": ..., "field_b": ...},
///     ...
///   ],
///   "schema": {
///     "fields": [
///       {"dtype": "int", "name": "field_a"},
///       ...
///     ]
///   }
/// }
/// ```
///
/// Object keys are alphabetically sorted at every level so the output is
/// byte-stable across runs. Schema field order is preserved (it is part of
/// the dataset's identity, unlike object key order).
pub fn dataset_to_json(dataset : Dataset) -> String {
  let buf = StringBuilder::new()
  buf.write_string("{\"rows\":[")
  for i in 0..<dataset.n_rows {
    if i > 0 {
      buf.write_char(',')
    }
    write_row(buf, dataset, i)
  }
  buf.write_string("],\"schema\":{\"fields\":[")
  for i in 0..<dataset.schema.fields.length() {
    if i > 0 {
      buf.write_char(',')
    }
    let f = dataset.schema.fields[i]
    buf.write_string("{\"dtype\":\"")
    buf.write_string(f.dtype.name())
    buf.write_string("\",\"name\":\"")
    buf.write_string(f.name)
    buf.write_string("\"}")
  }
  buf.write_string("]}}")
  buf.to_string()
}

///|
fn write_row(buf : StringBuilder, dataset : Dataset, row : Int) -> Unit {
  let names : Array[String] = []
  for f in dataset.schema.fields {
    names.push(f.name)
  }
  sort_strings(names)
  buf.write_char('{')
  for i in 0..<names.length() {
    if i > 0 {
      buf.write_char(',')
    }
    let name = names[i]
    buf.write_char('"')
    buf.write_string(name)
    buf.write_string("\":")
    let v = dataset.columns.get(name).unwrap()[row]
    write_value(buf, v)
  }
  buf.write_char('}')
}

///|
fn write_value(buf : StringBuilder, v : Value) -> Unit {
  match v {
    VString(s) => {
      buf.write_char('"')
      write_json_escaped(buf, s)
      buf.write_char('"')
    }
    VInt(n) => buf.write_string(n.to_string())
    VNull => buf.write_string("null")
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
    while j > 0 && arr[j - 1] > cur {
      arr[j] = arr[j - 1]
      j = j - 1
    }
    arr[j] = cur
  }
}
