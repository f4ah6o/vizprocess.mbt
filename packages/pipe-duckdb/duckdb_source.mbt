///|
/// Run `sql` against the DuckDB database at `db_path` (use `:memory:` for
/// an ephemeral in-process database) and decode the result into a
/// `pipe.Dataset` with the supplied `schema`.
///
/// Schema is supplied explicitly rather than inferred so M6 stays focused
/// on the binding mechanics; schema inference can layer on top by reading
/// `QueryResult.column_count` / column type ids.
///
/// The DuckDB `connect` / `query` / `close` callbacks are invoked
/// synchronously by the native binding, so this function returns once the
/// query is finished.
pub fn query_to_dataset(
  db_path : String,
  sql : String,
  schema : @pipe.DataSchema,
) -> (@pipe.Dataset, Array[@pipe.Diagnostic]) {
  let diags : Array[@pipe.Diagnostic] = []
  let columns : Map[String, Array[@pipe.Value]] = Map::new()
  for f in schema.fields {
    columns[f.name] = []
  }
  let mut n_rows = 0
  let result_box : Ref[@duckdb.QueryResult?] = { val: None }
  let error_box : Ref[String?] = { val: None }
  @duckdb.connect(path=db_path, on_ready=fn(conn_result) {
    match conn_result {
      Err(@duckdb.DuckDBError::Message(msg)) =>
        error_box.val = Some("connect failed: " + msg)
      Ok(conn) => {
        conn.query(sql, on_done=fn(query_result) {
          match query_result {
            Ok(qr) => result_box.val = Some(qr)
            Err(@duckdb.DuckDBError::Message(msg)) =>
              error_box.val = Some("query failed: " + msg)
          }
        })
        conn.close(on_done=fn(_) {  })
      }
    }
  })
  match error_box.val {
    Some(msg) => {
      diags.push(
        @pipe.Diagnostic::error(@pipe.code_schema_mismatch, "duckdb", msg),
      )
      return (@pipe.Dataset::empty(schema), diags)
    }
    None => ()
  }
  let qr = match result_box.val {
    Some(r) => r
    None => {
      diags.push(
        @pipe.Diagnostic::error(
          @pipe.code_schema_mismatch, "duckdb", "no result produced",
        ),
      )
      return (@pipe.Dataset::empty(schema), diags)
    }
  }
  let column_indices : Map[String, Int] = Map::new()
  let column_names : Array[String] = qr.columns
  for j in 0..<column_names.length() {
    column_indices[column_names[j]] = j
  }
  for f in schema.fields {
    if column_indices.get(f.name) is None {
      diags.push(
        @pipe.Diagnostic::error(
          @pipe.code_schema_mismatch,
          "duckdb.column",
          "result is missing column '" + f.name + "'",
        ),
      )
    }
  }
  if diags.length() > 0 {
    return (@pipe.Dataset::empty(schema), diags)
  }
  let row_count = qr.row_count()
  for row in 0..<row_count {
    for f in schema.fields {
      let col = column_indices.get(f.name).unwrap()
      let value = match f.dtype {
        @pipe.TString =>
          match qr.get_string(row, col) {
            Some(s) => @pipe.VString(s)
            None => @pipe.VNull
          }
        @pipe.TInt =>
          match qr.get_int(row, col) {
            Some(n) => @pipe.VInt(n.to_int64())
            None => @pipe.VNull
          }
      }
      columns.get(f.name).unwrap().push(value)
    }
    n_rows = n_rows + 1
  }
  ({ schema, columns, n_rows }, diags)
}

///|
/// Convenience helper for tests: load a CSV file via DuckDB's `read_csv`
/// table function. Returns the SQL string that, when given `path`, yields
/// every row of the CSV with the columns declared in `schema`. The caller
/// pipes this through `query_to_dataset`.
pub fn read_csv_sql(path : String, schema : @pipe.DataSchema) -> String {
  let buf = StringBuilder::new()
  buf.write_string("SELECT ")
  for i in 0..<schema.fields.length() {
    if i > 0 {
      buf.write_string(", ")
    }
    buf.write_string(schema.fields[i].name)
  }
  buf.write_string(" FROM read_csv('")
  buf.write_string(path)
  buf.write_string("', header=true)")
  buf.to_string()
}

///|
/// Documents that this package targets `native` only. Other packages can
/// import `pipe-duckdb` without breaking the `js` / `wasm-gc` builds
/// because every duckdb-touching function lives behind native target gates
/// in `moon.pkg`.
pub fn version() -> String {
  "0.1.0"
}
