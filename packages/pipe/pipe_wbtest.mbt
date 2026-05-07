///|
/// Round-trip golden test: parse a sales CSV, run a select → filter →
/// aggregate pipeline, and compare the JSON encoding of the result against
/// a literal expected string. Drives every M1 building block.
test "golden: csv → select → filter → aggregate → json" {
  let csv =
    #|month,region,amount
    #|2026-01,JP,100
    #|2026-01,US,50
    #|2026-02,JP,200
    #|2026-02,US,150
    #|2026-01,JP,75
    #|
  let schema : DataSchema = {
    fields: [
      { name: "month", dtype: TString },
      { name: "region", dtype: TString },
      { name: "amount", dtype: TInt },
    ],
  }
  let (dataset, parse_diags) = parse_csv(csv, schema)
  inspect(parse_diags.length(), content="0")
  inspect(dataset.n_rows, content="5")
  let pipeline : Pipeline = {
    steps: [
      Select(["month", "region", "amount"]),
      Filter("region", EQ, VString("JP")),
      Aggregate({
        group_by: ["month"],
        measures: [{ field: "amount", op: SUM, as_: "total" }],
      }),
    ],
  }
  let result = run_pipeline(dataset, pipeline)
  inspect(result.diagnostics.length(), content="0")
  let json = dataset_to_json(result.dataset)
  let expected =
    #|{"rows":[{"month":"2026-01","total":175},{"month":"2026-02","total":200}],"schema":{"fields":[{"dtype":"string","name":"month"},{"dtype":"int","name":"total"}]}}
  inspect(json, content=expected)
}

///|
test "validate_pipeline reports missing field" {
  let schema : DataSchema = { fields: [{ name: "month", dtype: TString }] }
  let pipeline : Pipeline = { steps: [Select(["region"])] }
  let diags = validate_pipeline(schema, pipeline)
  inspect(diags.length(), content="1")
  inspect(diags[0].code, content="FIELD_NOT_FOUND")
}

///|
test "validate_pipeline reports filter type mismatch" {
  let schema : DataSchema = { fields: [{ name: "amount", dtype: TInt }] }
  let pipeline : Pipeline = { steps: [Filter("amount", EQ, VString("oops"))] }
  let diags = validate_pipeline(schema, pipeline)
  inspect(diags.length(), content="1")
  inspect(diags[0].code, content="FIELD_TYPE_MISMATCH")
}

///|
test "parse_int64" {
  inspect(parse_int64("0"), content="Some(0)")
  inspect(parse_int64("42"), content="Some(42)")
  inspect(parse_int64("-7"), content="Some(-7)")
  inspect(parse_int64(""), content="None")
  inspect(parse_int64("12a"), content="None")
}
