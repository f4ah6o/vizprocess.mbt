///|
/// End-to-end native DuckDB roundtrip: read_csv + aggregation in SQL,
/// decode into a `pipe.Dataset`. The result must match the M1 golden
/// (computed there in pure MoonBit) byte-equal once serialized via
/// `pipe.dataset_to_json`, proving the SQL backend is interchangeable.
test "golden: duckdb read_csv + aggregate matches M1 dataset" {
  let schema : @pipe.DataSchema = {
    fields: [
      { name: "month", dtype: @pipe.TString },
      { name: "total", dtype: @pipe.TInt },
    ],
  }
  let sql = "SELECT month, SUM(amount)::INT AS total " +
    "FROM read_csv('fixtures/datasets/sales.csv', header=true) " +
    "WHERE region = 'JP' " +
    "GROUP BY month " +
    "ORDER BY month"
  let (dataset, diags) = query_to_dataset(":memory:", sql, schema)
  inspect(diags.length(), content="0")
  inspect(dataset.n_rows, content="2")
  let json = @pipe.dataset_to_json(dataset)
  let expected =
    #|{"rows":[{"month":"2026-01","total":175},{"month":"2026-02","total":200}],"schema":{"fields":[{"dtype":"string","name":"month"},{"dtype":"int","name":"total"}]}}
  inspect(json, content=expected)
}

///|
test "read_csv_sql renders the expected SELECT" {
  let schema : @pipe.DataSchema = {
    fields: [
      { name: "month", dtype: @pipe.TString },
      { name: "amount", dtype: @pipe.TInt },
    ],
  }
  inspect(
    read_csv_sql("data.csv", schema),
    content="SELECT month, amount FROM read_csv('data.csv', header=true)",
  )
}

///|
test "query_to_dataset surfaces DuckDB errors as diagnostics" {
  let schema : @pipe.DataSchema = { fields: [{ name: "x", dtype: @pipe.TInt }] }
  let (_, diags) = query_to_dataset(
    ":memory:", "SELECT FROM does_not_exist", schema,
  )
  inspect(diags.length() >= 1, content="true")
}
