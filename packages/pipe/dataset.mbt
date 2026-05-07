///|
/// Column-oriented dataset. `columns[name]` has length `n_rows` for every
/// field in `schema`. M1 keeps the structure simple; richer iteration
/// helpers can be added when other packages need them.
pub struct Dataset {
  schema : DataSchema
  columns : Map[String, Array[Value]]
  n_rows : Int
} derive(Eq, Show)

///|
pub fn Dataset::empty(schema : DataSchema) -> Dataset {
  let columns : Map[String, Array[Value]] = Map::new()
  for f in schema.fields {
    columns[f.name] = []
  }
  { schema, columns, n_rows: 0 }
}

///|
/// Pull the value at `(row, field)` if both bounds are valid.
pub fn Dataset::cell(self : Dataset, row : Int, field : String) -> Value? {
  match self.columns.get(field) {
    Some(col) =>
      if row >= 0 && row < col.length() {
        Some(col[row])
      } else {
        None
      }
    None => None
  }
}

///|
/// Result of running a pipeline: the produced dataset and any diagnostics
/// emitted along the way (sorted by code, then target, for determinism).
pub struct PipeResult {
  dataset : Dataset
  diagnostics : Array[Diagnostic]
} derive(Eq, Show)
